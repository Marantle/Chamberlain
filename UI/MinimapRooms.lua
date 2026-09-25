local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Rooms on the minimap
-- ─────────────────────────────────────────────────────────────────────
-- Inside a house the game swaps the minimap for a still house picture
-- (MinimapBackdrop.StaticOverlayTexture, flipped by Minimap:UpdateStaticOverlayTexture
-- off C_Housing.IsInsideHouse). With the setting on that picture is hidden and
-- the rooms of the active floor are drawn in its place: you sit at the centre
-- and the rooms slide past as you walk, the way the real minimap does outdoors.
-- Same orientation as the house map. The Minimap widget still renders under
-- the picture, so the overlay carries an opaque backgorund of its own. Nothing
-- here takes the mouse, so clicks and the wheel (zoom) reach the minimap as
-- before.

local FP = CH.FP

-- Yards across the minimap at each zoom step (Minimap:GetZoom() runs 0 to 5).
-- The real minimap's steps don't matter with its picture gone, so these are
-- picked to show a whole house at the widest and a single room at the tightest.
local YARDS_ACROSS = { 120, 100, 80, 65, 50, 35 }

local overlay = CreateFrame("Frame", nil, Minimap)
overlay:SetAllPoints()
-- Over the backdrop (level 4, where the house picture lives) and under the
-- addon buttons that sit on the minimap at level 8.
overlay:SetFrameLevel(Minimap:GetFrameLevel() + 2)
overlay:SetClipsChildren(true)
overlay:Hide()

local bg = overlay:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(FP.GROUND[1], FP.GROUND[2], FP.GROUND[3], 1)

-- Round cut matching the stock minimap, put on every texture (the icons can't
-- be masked so they hide near the rim instead). Left off for square minimaps,
-- where the frame's clipping does the job.
local rim = overlay:CreateMaskTexture()
rim:SetAllPoints()
rim:SetTexture(FP.ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
local round = false

local function SetRim(tex, on)
    if on then
        tex:AddMaskTexture(rim)
    else
        tex:RemoveMaskTexture(rim)
    end
end

local tiles, blips = {}, {}
local me = FP.MakeBlip(overlay, overlay:GetFrameLevel() + 2)
me:SetPoint("CENTER")
me:Show() -- blips start hidden but this one never moves or goes away

-- A room here is two textures and a round mask right on the overlay, with the
-- same fields as a house map tile so FP.SetTileRound works on both. Frames
-- on one level stack in no set order, and there's no room for a level per
-- room under the minimap's own buttons. Textures on one frame do stack by
-- draw layer and sublevel, which Rebuild sets from how deep each room sits.
-- No names at this size since the house map has them (3.18.0).
local function MakeTile(i)
    local t = {}
    t.border = overlay:CreateTexture()
    t.fill = overlay:CreateTexture()
    t.fill:SetPoint("TOPLEFT", t.border, "TOPLEFT", 1, -1)
    t.fill:SetPoint("BOTTOMRIGHT", t.border, "BOTTOMRIGHT", -1, 1)
    t.mask = overlay:CreateMaskTexture()
    t.mask:SetAllPoints(t.border)
    t.mask:SetTexture(FP.ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    SetRim(t.fill, round)
    SetRim(t.border, round)
    tiles[i] = t
    return t
end

local function ShowTile(t, on)
    t.border:SetShown(on)
    t.fill:SetShown(on)
    if t.icon and not on then
        t.icon:Hide()
    end
end

-- Draw slots from the bottom up, two per depth (the border and then the fill
-- over it), through BORDER and ARTWORK's sublevels -8 to 7. That makes 16
-- depths, far more than rooms in rooms ever nest.
local MAX_DEPTH = 16

local function SetDepth(t, d)
    local s = d * 2 - 1
    t.border:SetDrawLayer(s <= 16 and "BORDER" or "ARTWORK", (s - 1) % 16 - 8)
    s = s + 1
    t.fill:SetDrawLayer(s <= 16 and "BORDER" or "ARTWORK", (s - 1) % 16 - 8)
end

local function Overlap(a, b)
    return a.minX < b.maxX and b.minX < a.maxX and a.minY < b.maxY and b.minY < a.maxY
end

local function MakeBlip(i)
    local bf = FP.MakeBlip(overlay, overlay:GetFrameLevel() + 2)
    SetRim(bf.tex, round)
    blips[i] = bf
    return bf
end

local function ApplyShape()
    local want = not ChamberlainDB.settings.minimapSquare
    if want == round then
        return
    end
    round = want
    SetRim(bg, round)
    for _, t in ipairs(tiles) do
        SetRim(t.fill, round)
        SetRim(t.border, round)
    end
    for _, bf in ipairs(blips) do
        SetRim(bf.tex, round)
    end
end

local shown = 0 -- tiles in use, dense from 1
local order = {} -- FP.DrawOrder's list, kept between rebuilds
local depth = {} -- each drawn room's depth, by draw order
local lastX, lastY, lastScale, lastFloor, lastGuid

-- Pick the rooms of the active floor and paint them. Placing them is left to
-- the update loop, which runs right after with its position cache cleared.
-- The draw order is biggest first, so a room sits one step over the deepest
-- room it overlaps that came before it.
local function Rebuild()
    -- the house you stand in, whatever house the floor plan is showing
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    shown = 0
    if h and h.zones then
        local zones = h.zones
        for n, i in ipairs(FP.DrawOrder(h, CH.activeFloor, CH.isOwnHouse, order)) do
            local t = tiles[n] or MakeTile(n)
            local zone = zones[i]
            local d = 1
            for m = 1, n - 1 do
                if depth[m] >= d and Overlap(zone, zones[order[m]]) then
                    d = depth[m] + 1
                end
            end
            depth[n] = math.min(d, MAX_DEPTH)
            SetDepth(t, depth[n])
            FP.SetTileRound(t, zone.shape == "circle")
            t.marker = FP.PaintTile(t.border, t.fill, zone, i, false, false)
            FP.SetTileIcon(t, overlay, t.border, t.marker)
            t.zone = zone
            ShowTile(t, true)
            shown = n
        end
    end
    for i = shown + 1, #tiles do
        ShowTile(tiles[i], false)
    end
    FP.PaintBlip(me, "player")
    FP.minimapDirty = false
    lastX = nil
end

overlay:SetScript("OnUpdate", function()
    local guid, floor = CH.currentHouseGUID, CH.activeFloor
    if FP.minimapDirty or guid ~= lastGuid or floor ~= lastFloor then
        lastGuid, lastFloor = guid, floor
        Rebuild()
    end

    local px, py = CH.GetWorldPos()
    if not px then
        return
    end
    local w = Minimap:GetWidth()
    local s = w / YARDS_ACROSS[Minimap:GetZoom() + 1]
    -- How far out from the centre an icon or blip may sit and still clear the
    -- ring. Square minimaps clip at the edge instead.
    local reach = round and (w * 0.5 - 6) or math.huge

    -- The tiles only move when we do (or the zoom changes), so standing still
    -- costs nothing. Group blips move on their own and are placed every frame.
    if px ~= lastX or py ~= lastY or s ~= lastScale then
        lastX, lastY, lastScale = px, py, s
        for i = 1, shown do
            local t = tiles[i]
            local z = t.zone
            -- Like the house map: higher world X to the left, higher Y up. The
            -- fill, the mask and the icon all hang off the border.
            local ox = (px - (z.minX + z.maxX) * 0.5) * s
            local oy = ((z.minY + z.maxY) * 0.5 - py) * s
            t.border:ClearAllPoints()
            t.border:SetPoint("CENTER", overlay, "CENTER", ox, oy)
            t.border:SetSize(math.max((z.maxX - z.minX) * s, 4), math.max((z.maxY - z.minY) * s, 4))
            -- A stairs or sound icon shows while its far corner is still inside
            -- the ring.
            if t.icon and t.marker then
                local d = math.abs(ox) + 8
                local e = math.abs(oy) + 8
                t.icon:SetShown(d * d + e * e <= reach * reach)
            end
        end
    end

    local units, numUnits = FP.GroupUnits()
    for i = 1, numUnits do
        local unit = units[i]
        local bf = blips[i] or MakeBlip(i)
        local uy, ux = UnitPosition(unit)
        local ox, oy
        -- UnitIsVisible keeps a friend standing in their own house off ours, since
        -- all houses share a map id and reuse similar coordinates.
        if ux and UnitIsVisible(unit) and not UnitIsUnit(unit, "player") then
            ox, oy = (px - ux) * s, (uy - py) * s
            if math.sqrt(ox * ox + oy * oy) + 7 > reach then
                ox = nil
            end
        end
        if ox then
            FP.PaintBlip(bf, unit)
            bf:ClearAllPoints()
            bf:SetPoint("CENTER", overlay, "CENTER", ox, oy)
            bf:Show()
        else
            bf:Hide()
        end
    end
    for i = numUnits + 1, #blips do
        blips[i]:Hide()
    end
end)

-- The picture comes and goes with C_Housing.IsInsideHouse, so the overlay rides
-- the same call: hide the picture and show ourselves, or stay out of the way.
local function Apply()
    if not ChamberlainDB then
        return -- another addon poking the minimap during load, before our SavedVariables are in
    end
    -- A house we hold no rooms for keeps the game's picture, or a visitor
    -- without the map would get an empty circle.
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local on = ChamberlainDB.settings.minimapRooms
        and C_Housing.IsInsideHouse()
        and h ~= nil
        and h.zones ~= nil
        and #h.zones > 0
    if on then
        MinimapBackdrop.StaticOverlayTexture:Hide()
        ApplyShape()
        FP.minimapDirty = true
    end
    overlay:SetShown(on)
end

hooksecurefunc(Minimap, "UpdateStaticOverlayTexture", Apply)

-- The Settings toggles call this. Going through Blizzard's own update brings the
-- picture back when the setting turns off, and the hook above ends in Apply.
function CH.RefreshMinimapRooms()
    Minimap:UpdateStaticOverlayTexture()
end
