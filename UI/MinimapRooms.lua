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
-- The real minimap's steps don't matter with its picture gone, these are picked
-- so the widest shows a whole house and the tightest a single room.
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
bg:SetColorTexture(0.025, 0.02, 0.015, 1)

-- Round cut matching the stock minimap, put on every texture (labels can't be
-- masked, they hide near the rim instead). Left off for square minimaps, where
-- the frame's clipping does the job.
local rim = overlay:CreateMaskTexture()
rim:SetAllPoints()
rim:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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
me:Show() -- blips start hidden, this one never moves or goes away

local function MakeTile(i)
    local f = FP.MakeTile(overlay)
    SetRim(f.fill, round)
    SetRim(f.border, round)
    tiles[i] = f
    return f
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
    for _, f in ipairs(tiles) do
        SetRim(f.fill, round)
        SetRim(f.border, round)
    end
    for _, bf in ipairs(blips) do
        SetRim(bf.tex, round)
    end
end

local shown = 0 -- tiles in use, dense from 1
local lastX, lastY, lastScale, lastFloor, lastGuid

-- Pick the rooms of the active floor and paint them. Placing them is left to
-- the update loop, which runs right after with its position cache cleared.
local function Rebuild()
    local h = FP.CurrentHouse()
    shown = 0
    if h and h.zones then
        for i, zone in ipairs(h.zones) do
            if FP.ZoneOnFloor(h, zone, CH.activeFloor) then
                shown = shown + 1
                local f = tiles[shown] or MakeTile(shown)
                FP.StyleTile(f, zone, i, false)
                f.zone = zone
                f.labelW = f.label:GetStringWidth()
                f:Show()
            end
        end
    end
    for i = shown + 1, #tiles do
        tiles[i]:Hide()
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
    local s = w / YARDS_ACROSS[math.min(Minimap:GetZoom(), 5) + 1]
    -- How far out from the centre a label or blip may sit and still clear the
    -- ring. Square minimaps clip at the edge instead.
    local reach = round and (w * 0.5 - 6) or math.huge

    -- The tiles only move when we do (or the zoom changes), so standing still
    -- costs nothing. Group blips move on their own and are placed every frame.
    if px ~= lastX or py ~= lastY or s ~= lastScale then
        lastX, lastY, lastScale = px, py, s
        for i = 1, shown do
            local f = tiles[i]
            local z = f.zone
            -- Like the house map: higher world X to the left, higher Y up.
            local ox = (px - (z.minX + z.maxX) * 0.5) * s
            local oy = ((z.minY + z.maxY) * 0.5 - py) * s
            local tw = math.max((z.maxX - z.minX) * s, 4)
            f:ClearAllPoints()
            f:SetPoint("CENTER", overlay, "CENTER", ox, oy)
            f:SetSize(tw, math.max((z.maxY - z.minY) * s, 4))
            -- The label shows while the far corner of its text box is still inside
            -- the ring. A long name is already clipped to its tile, so the tile
            -- width caps the box.
            local hw = math.min(f.labelW, tw) * 0.5 + math.abs(ox)
            local hh = 7 + math.abs(oy)
            f.label:SetShown(hw * hw + hh * hh <= reach * reach)
        end
    end

    local units, numUnits = FP.GroupUnits()
    for i = 1, numUnits do
        local unit = units[i]
        local bf = blips[i] or MakeBlip(i)
        local uy, ux = UnitPosition(unit)
        local ox, oy
        -- UnitIsVisible keeps a friend standing in their own house off ours, all
        -- houses share a map id and reuse similar coordinates.
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
    local on = ChamberlainDB.settings.minimapRooms and C_Housing.IsInsideHouse()
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
