local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: room tiles and the build pass
-- ─────────────────────────────────────────────────────────────────────

local FP = CH.FP
local canvas = FP.canvas

local PALETTE = {
    { 0.40, 0.70, 1.00 },
    { 0.40, 1.00, 0.65 },
    { 1.00, 0.80, 0.25 },
    { 1.00, 0.45, 0.45 },
    { 0.75, 0.45, 1.00 },
    { 0.35, 1.00, 1.00 },
    { 1.00, 0.65, 0.25 },
    { 0.65, 1.00, 0.35 },
}
-- the room dialog offers these as quick picks
FP.PALETTE = PALETTE

-- A room's colour: its own, or a palette pick by zone index for rooms without one.
function FP.ZoneColor(zone, i)
    local c = zone.color or PALETTE[((i - 1) % #PALETTE) + 1]
    return c[1], c[2], c[3]
end

-- Another anchor pointing the opposite way, meaning this box is one landing of
-- a staircase rather than a lone floor switch. By direction, not by wizard,
-- since the data doesn't record which one built the box.
local function HasMate(h, zone)
    for _, z in ipairs(h.zones) do
        if z ~= zone and z.setFloor == zone.fromFloor and z.fromFloor == zone.setFloor then
            return true
        end
    end
    return false
end

-- Anchors show on every floor they actually reach, not just the one they sit on,
-- so the map matches how they fire: a floor marker (no fromFloor) triggers from
-- anywhere, and a staircase connects two floors.
local function AnchorOnFloor(h, zone, floor)
    if zone.setFloor and zone.fromFloor then
        -- Its own floor always. The floor it sends to only when a mate points
        -- back, so a staircase pair can still be aligned from either floor
        -- while a lone switch stays off the map of the floor it lands on.
        if floor == zone.fromFloor then
            return true
        end
        return floor == zone.setFloor and HasMate(h, zone)
    elseif zone.setFloor then
        return true -- floor marker: fires from any floor
    end
    -- Relative hops (floorDelta) and anything else sit on one floor and show
    -- only there. A hop has no mate to align against, so it stays off the
    -- floor it sends to.
    return floor == (zone.floor or 1)
end

-- A zone is drawn on a floor when it's visible to us (secret rooms hide from
-- visitors) and belongs on that floor. Stairs always draw. Show stairs only
-- picks box or icon (3.18.0). The floor plan asks about the floor it's
-- viewing, the minimap about the active one. ownerView lets the secret rooms
-- in. Each caller passes its own, because the map can show another house than
-- the minimap does.
function FP.ZoneOnFloor(h, zone, floor, ownerView)
    if zone.secret and not ownerView then
        return false
    end
    if zone.noBanner and not ChamberlainDB.settings.showSpotsOnMap then
        return false
    end
    if CH.IsAnchor(zone) then
        return AnchorOnFloor(h, zone, floor)
    end
    return (zone.floor or 1) == floor
end

-- A house map room tile, with the border texture under the fill so the fill's
-- inset shows it as an edge. GetZoneFrame adds the mouse handling on top. The
-- minimap draws its rooms as bare textures instead (UI/MinimapRooms.lua).
local function MakeTile(parent)
    local f = CreateFrame("Frame", nil, parent)

    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()

    f.fill = f:CreateTexture(nil, "BORDER")
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    -- A round alpha mask, off by default. Circle rooms switch it on (see
    -- FP.SetTileRound) so the square tile draws as a disc. The box is square for
    -- a circle, so the inscribed mask matches the room exactly.
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints(f)
    f.mask:SetTexture(FP.ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.masked = false

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.label:SetAllPoints()
    f.label:SetJustifyH("CENTER")
    f.label:SetJustifyV("MIDDLE")
    f.label:SetWordWrap(false)
    return f
end

-- Toggle a pooled tile between a square room and a round one by masking its fill
-- and border. Tracked on t so a rebuild doesn't stack masks, and so a pooled
-- tile reused for a rectangle drops the mask again. The minimap's tiles too.
function FP.SetTileRound(t, round)
    if round == t.masked then
        return
    end
    t.masked = round
    local apply = round and "AddMaskTexture" or "RemoveMaskTexture"
    t.border[apply](t.border, t.mask)
    t.fill[apply](t.fill, t.mask)
end

-- Stairs and sound spots aren't rooms you stand in, so they draw as an icon
-- instead of a filled, named box. Show stairs on the house map brings the
-- stairs' boxes back, with the icon on top, for lining them up.
local MARKERS = {
    stairs = { icon = "icon-stairs", color = { 0.40, 0.85, 1.00 } },
    spot = { icon = "icon-sound", color = { 1.00, 0.69, 0.29 } },
}

local function MarkerOf(zone)
    if CH.IsAnchor(zone) then
        return MARKERS.stairs
    elseif zone.noBanner then
        return MARKERS.spot
    end
end

-- A room's fill is its colour mixed into the ground and kept opaque, since the
-- border is a whole rectangle under the fill and any see-through fill shows it
-- at full strength.
local GROUND = FP.GROUND

local function Wash(r, g, b, t)
    return GROUND[1] + (r - GROUND[1]) * t, GROUND[2] + (g - GROUND[2]) * t, GROUND[3] + (b - GROUND[3]) * t, 1
end

-- Colour a tile's border and fill textures for its zone. The fill is a dark
-- wash of the room's colour inside a crisp edge. stairBoxes draws the stairs
-- as boxes and the minimap leaves it off. Returns the marker, whether it's drawn
-- as a box, and the room colour. Both maps paint through this.
function FP.PaintTile(border, fill, zone, i, selected, stairBoxes)
    local r, g, b = FP.ZoneColor(zone, i)
    local marker = MarkerOf(zone)
    local boxed = stairBoxes and marker == MARKERS.stairs
    if selected then
        border:SetColorTexture(1, 0.82, 0.10, 1)
        local c = marker and marker.color or { r, g, b }
        fill:SetColorTexture(Wash(c[1], c[2], c[3], 0.4))
    elseif boxed then
        local c = marker.color
        border:SetColorTexture(c[1], c[2], c[3], 0.9)
        fill:SetColorTexture(Wash(c[1], c[2], c[3], 0.25))
    elseif marker then
        -- nothing but the icon, so it never hides the room it sits in
        border:SetColorTexture(0, 0, 0, 0)
        fill:SetColorTexture(0, 0, 0, 0)
    else
        border:SetColorTexture(r, g, b, 0.9)
        fill:SetColorTexture(Wash(r, g, b, 0.25))
    end
    return marker, boxed, r, g, b
end

-- The stairs or sound icon for a tile t, made on owner the first time and
-- centred on at. t keeps the icon and the svg it holds.
function FP.SetTileIcon(t, owner, at, marker)
    if marker and not t.icon then
        t.icon = CH.MakeIcon(owner, marker.icon, 12, "OVERLAY")
        t.icon:SetPoint("CENTER", at)
    end
    if t.icon then
        t.icon:SetShown(marker ~= nil)
        -- a build repaints every tile, so the svg only reloads on a change
        if marker and t.iconFile ~= marker.icon then
            t.iconFile = marker.icon
            CH.SetIconFile(t.icon, marker.icon)
            t.icon:SetVertexColor(marker.color[1], marker.color[2], marker.color[3])
        end
    end
end

-- Paint a house map tile for its zone and set its label. Returns the room
-- colour so the caller can keep it for tooltips. The name is pale so it reads
-- on any colour. f.iconOnly says the tile is an icon and nothing more.
local function StyleTile(f, zone, i, selected, stairBoxes)
    FP.SetTileRound(f, zone.shape == "circle")
    -- A selected tile gets a 2px gold ring. The fill sits 2px in so the border
    -- texture shows through. The pool reuses frames, so the inset goes back to
    -- 1px otherwise.
    local inset = selected and 2 or 1
    f.fill:ClearAllPoints()
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    local marker, boxed, r, g, b = FP.PaintTile(f.border, f.fill, zone, i, selected, stairBoxes)
    f.iconOnly = marker ~= nil and not boxed
    FP.SetTileIcon(f, f, f, marker)

    -- a marker's name is in its tooltip
    f.label:SetText(marker and "" or zone.name)
    f.label:SetTextColor(0.95, 0.92, 0.85, 1)
    return r, g, b
end

-- The zones drawn on a floor, biggest first so a smaller room always sits on
-- top of the one around it, and the markers above them all. Fills and hands
-- back out, which the caller keeps to save making a table per draw.
local sortZones -- the zones DrawOrder is sorting, read by ZoneBefore

local function ZoneBefore(a, b)
    local za, zb = sortZones[a], sortZones[b]
    local ma, mb = MarkerOf(za) ~= nil, MarkerOf(zb) ~= nil
    if ma ~= mb then
        return mb
    end
    local sa = (za.maxX - za.minX) * (za.maxY - za.minY)
    local sb = (zb.maxX - zb.minX) * (zb.maxY - zb.minY)
    if sa ~= sb then
        return sa > sb
    end
    return a < b
end

function FP.DrawOrder(h, floor, ownerView, out)
    wipe(out)
    for i, zone in ipairs(h.zones) do
        if FP.ZoneOnFloor(h, zone, floor, ownerView) then
            out[#out + 1] = i
        end
    end
    sortZones = h.zones
    table.sort(out, ZoneBefore)
    return out
end

-- Zone frame pool, one tile per drawn zone. Their labels live on labelLayer.
local zonePool = {}

-- The room names sit on one layer over every tile, so a smaller room drawn on
-- top of a big one can't cover the big one's name. Under the drag grips.
local labelLayer = CreateFrame("Frame", nil, canvas)
labelLayer:SetAllPoints()
labelLayer:SetFrameLevel(FP.Level("labels"))

-- Zone indices whose rectangle is under the cursor, topmost first (later frames
-- draw on top). Used to cycle selection through overlapping rooms.
local function ZonesAtCursor()
    local cx, cy = GetCursorPosition()
    local s = canvas:GetEffectiveScale()
    if not s or s == 0 then
        return {}
    end
    cx, cy = cx / s, cy / s
    local hits = {}
    for i = #zonePool, 1, -1 do
        local f = zonePool[i]
        if f:IsShown() and f.zoneIdx then
            local l, b, w, ht = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
            -- a marker only answers over its icon, see PlaceTile
            local il, ir, it, ib = f:GetHitRectInsets()
            l, b, w, ht = l and l + il, b and b + ib, w - il - ir, ht - it - ib
            if l and b and cx >= l and cx <= l + w and cy >= b and cy <= b + ht then
                hits[#hits + 1] = f.zoneIdx
            end
        end
    end
    return hits
end

-- Fill GameTooltip with a room's name, dimensions, and dwell time. Shared by the
-- hover handler and the click-to-cycle handler so both show the same room.
local function ShowZoneTooltip(owner, name, w, ht, timeSpent, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(name, r, g, b)
    GameTooltip:AddLine(string.format(CH.L["FP_DIM_X"], w, ht), 0.7, 0.7, 0.7)
    if timeSpent and timeSpent >= 1 then
        GameTooltip:AddLine(string.format(CH.L["FP_TIME_HERE_X"], CH.FormatDuration(timeSpent)), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- The visible pooled frame currently drawing a given zone index, or nil.
function FP.ZoneFrameByIdx(idx)
    for _, fr in pairs(zonePool) do
        if fr:IsShown() and fr.zoneIdx == idx then
            return fr
        end
    end
end

local function GetZoneFrame(i)
    if zonePool[i] then
        zonePool[i]:Show()
        return zonePool[i]
    end
    local f = MakeTile(canvas)
    f.label:SetParent(labelLayer)

    -- Tooltip on hover, the only place a room shows a name that was left off
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        -- If the highlighted room is also under the cursor, describe it rather than
        -- this (topmost) frame, so the tooltip tracks the highlight as you click
        -- through a stack. The preference has to live here, not just in the click
        -- handler: FP.Build re-shows the frames under a stationary cursor,
        -- which fires a fresh OnEnter that would otherwise overwrite the tooltip
        -- with whatever frame sits on top.
        local target = self
        local selectedIdx = FP.selectedIdx
        if selectedIdx and selectedIdx ~= self.zoneIdx then
            for _, idx in ipairs(ZonesAtCursor()) do
                if idx == selectedIdx then
                    target = FP.ZoneFrameByIdx(selectedIdx) or self
                    break
                end
            end
        end
        ShowZoneTooltip(
            self,
            target.zoneName,
            target.zoneW,
            target.zoneH,
            target.zoneTime,
            target.cr,
            target.cg,
            target.cb
        )
        FP.ShowCardRoom(target.zoneIdx)
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click selects for editing. Where rooms overlap, repeated clicks cycle
    -- through every room under the cursor (topmost first), then deselect.
    f:SetScript("OnMouseDown", function(self)
        if not FP.CanEdit() then
            return
        end
        local hits = ZonesAtCursor()
        if #hits == 0 then
            return
        end
        local pos
        for k, idx in ipairs(hits) do
            if idx == FP.selectedIdx then
                pos = k
                break
            end
        end
        local newIdx
        if not pos then
            newIdx = hits[1]
        elseif pos < #hits then
            newIdx = hits[pos + 1] -- cycle to the next room under the cursor
        else
            newIdx = nil -- cycled past the last room: deselect
        end
        -- Route through the shared setter so the build toolbox follows along. It
        -- sets FP.selectedIdx (via CH.FloorPlanSelect) and rebuilds.
        local house = FP.CurrentHouse()
        CH.SetSelection(newIdx and house and house.zones[newIdx] or nil, CH.currentHouseGUID)
        -- Refresh the tooltip to the room we just cycled to (OnEnter only fires on
        -- mouse motion or a frame re-show, so a click alone wouldn't update it).
        local sel = FP.selectedIdx and FP.ZoneFrameByIdx(FP.selectedIdx)
        if sel then
            ShowZoneTooltip(self, sel.zoneName, sel.zoneW, sel.zoneH, sel.zoneTime, sel.cr, sel.cg, sel.cb)
        else
            GameTooltip:Hide() -- nothing selected
        end
    end)

    zonePool[i] = f
    return f
end

local lastBuiltGuid
local order = {} -- FP.DrawOrder's list, kept between builds
local drawnCount = 0
local labelsAtK -- the zoom the labels were last laid out for

-- Put a tile over its zone at the current zoom. With X flipped, zone.maxX maps
-- to the left canvas edge and zone.maxY to the top. The spot is kept on the
-- frame for the lables.
local function PlaceTile(f, z, k)
    local px, py = FP.WorldToCanvas(z.maxX, z.maxY)
    local zw = math.max((z.maxX - z.minX) * k, 4)
    local zh = math.max((z.maxY - z.minY) * k, 4)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", canvas, "TOPLEFT", px, -py)
    f:SetSize(zw, zh)
    f.px, f.py, f.pw, f.ph = px, py, zw, zh
    -- A marker is only its icon, so only the icon takes the mouse. Otherwise
    -- an unseen stair box would catch clicks meant for the room under it.
    if f.iconOnly then
        local ix, iy = math.max(0, (zw - 16) * 0.5), math.max(0, (zh - 16) * 0.5)
        f:SetHitRectInsets(ix, ix, iy, iy)
    else
        f:SetHitRectInsets(0, 0, 0, 0)
    end
end

-- Names go where they fit and never on top of each other. Bigger rooms
-- were drawn first, so they pick first. A name sits in the middle of its
-- room, or in the top left corner when a smaller room covers the middle. One
-- too long for its room is cut short, down to a few letters, and past that
-- it's left off. The tooltip still has it. The labels ride their tiles, so a
-- pan moves them for free and only a zoom or a resize lays them out again.
local LABEL_H = 12
local MIN_H = 10 -- a room this tall still gets its name
local MIN_W = 24 -- about four letters, the least worth cutting a name to
local taken = {} -- label boxes placed so far, four numbers each

local function Overlaps(x, y, w, n)
    for j = 1, n, 4 do
        if
            x < taken[j] + taken[j + 2]
            and taken[j] < x + w
            and y < taken[j + 1] + LABEL_H
            and taken[j + 1] < y + LABEL_H
        then
            return true
        end
    end
    return false
end

-- Whether a room drawn over tile i sits on this box. A tile that's only its
-- small icon doesn't count.
local function Covered(x, y, w, i)
    for j = i + 1, drawnCount do
        local o = zonePool[j]
        if not o.iconOnly and x < o.px + o.pw and o.px < x + w and y < o.py + o.ph and o.py < y + LABEL_H then
            return true
        end
    end
    return false
end

local function LayoutLabels()
    local n = 0
    for i = 1, drawnCount do
        local f = zonePool[i]
        local label = f.label
        local tw = f.labelW
        local w = math.min(tw, f.pw - 6)
        local x, y
        if tw > 0 and f.ph >= MIN_H and (w == tw or w >= MIN_W) then
            x, y = (f.pw - w) * 0.5, (f.ph - LABEL_H) * 0.5
            if Covered(f.px + x, f.py + y, w, i) then
                -- a round room's corner is off the disc, so the name goes further in
                local inset = f.round and f.pw * 0.15 or 3
                x, y = inset, inset - 1
                if Covered(f.px + x, f.py + y, w, i) then
                    x = nil
                end
            end
            if x and Overlaps(f.px + x, f.py + y, w, n) then
                x = nil
            end
        end
        label:ClearAllPoints()
        if x then
            -- One anchor, and a width only to cut a long name short. Never a
            -- height, since a FontString shorter than its font draws nothing.
            label:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
            label:SetWidth(w < tw and w or 0)
            taken[n + 1], taken[n + 2], taken[n + 3] = f.px + x, f.py + y, w
            n = n + 4
        end
        label:SetShown(x ~= nil)
    end
end

-- A faint line every GRID yards behind the rooms, and a bar in the corner to
-- measure them by. Both follow the zoom.
local GRID = 8
local SCALE_STEPS = { 1, 2, 5, 10, 20, 50 }
local gridLines = {}

local function GridLine(i)
    local t = gridLines[i]
    if not t then
        t = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetColorTexture(1, 1, 1, 0.035)
        gridLines[i] = t
    end
    return t
end

-- on the label layer, so a room in the corner can't cover it
local scaleBar = CH.MakeRule(labelLayer, 0.8)
scaleBar:SetColorTexture(0.75, 0.72, 0.65, 0.6)
local scaleText = labelLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
scaleText:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -8, 6)
scaleText:SetTextColor(0.75, 0.72, 0.65, 0.8)
scaleBar:SetPoint("RIGHT", scaleText, "LEFT", -5, 0)

-- The lines every GRID yards between world a and b on one axis, top to
-- bottom when vertical and left to right otherwise. Hands back how many of
-- the pool are now in use.
local function GridLines(used, a, b, vertical)
    for wv = math.ceil(math.min(a, b) / GRID) * GRID, math.max(a, b), GRID do
        used = used + 1
        local t = GridLine(used)
        local px, py = FP.WorldToCanvas(wv, wv)
        -- whole pixels, or a 1px line shimmers as the map pans
        local at = math.floor((vertical and px or py) + 0.5)
        t:ClearAllPoints()
        if vertical then
            t:SetPoint("TOPLEFT", canvas, "TOPLEFT", at, 0)
            t:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", at, 0)
            t:SetWidth(1)
        else
            t:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -at)
            t:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -at)
            t:SetHeight(1)
        end
        t:Show()
    end
    return used
end

local function LayoutGrid(k)
    local used = 0
    if k then
        -- mirrored X and upward Y, so the corners come out swapped, which
        -- GridLines doesn't mind
        local x1, y1 = FP.CanvasToWorld(0, 0)
        local x2, y2 = FP.CanvasToWorld(canvas:GetWidth(), canvas:GetHeight())
        used = GridLines(used, x1, x2, true)
        used = GridLines(used, y1, y2, false)
        -- the longest round length that stays under 90px
        local step = SCALE_STEPS[1]
        for _, s in ipairs(SCALE_STEPS) do
            if s * k <= 90 then
                step = s
            end
        end
        scaleBar:SetWidth(step * k)
        if step ~= scaleText.step then
            scaleText.step = step
            scaleText:SetText(string.format(CH.L["FP_SCALE_X"], step))
        end
    end
    for i = used + 1, #gridLines do
        gridLines[i]:Hide()
    end
    scaleBar:SetShown(k ~= nil)
    scaleText:SetShown(k ~= nil)
end

function FP.Build()
    -- The minimap draws the same rooms and redraws them when this runs, whatever
    -- the reason (edit, drag step, floor change). See UI/MinimapRooms.lua.
    FP.minimapDirty = true
    -- pairs, not ipairs: frames are pooled in draw order, but a rebuild can leave
    -- the pool with holes, and ipairs would stop at the first one, leaving stale
    -- tiles (e.g. a just-deleted floor's rooms) visible. pairs hides every frame.
    for _, f in pairs(zonePool) do
        f:Hide()
        f.label:Hide() -- on labelLayer, so the tile doesn't take it along
    end
    FP.HideBlips()
    FP.empty:Hide()
    FP.fixHint:Hide()
    FP.fixBtn:Hide()
    FP.archiveHint:Hide()
    FP.archiveBtn:Hide()
    -- NB: do NOT invalidate the fit here. The transform persists across builds and
    -- is only invalidated by the explicit reframe events (open, house change,
    -- canvas resize, reset, zone changes). Nulling it every build would make the
    -- lazy EnsureFit below refit on every redraw, including each Grow/Move/Shrink
    -- and every drag step, which is exactly the feedback loop this design removes.

    local h = FP.CurrentHouse()

    if h and h.owner then
        FP.sub:SetText(string.format(CH.L["FP_X_HOUSE"], h.owner))
    elseif FP.HouseGUID() then
        FP.sub:SetText(CH.L["FP_HOME_INTERIOR"])
    else
        FP.sub:SetText(CH.L["FP_NOT_IN_HOUSE"])
    end
    FP.RefreshRail(h)
    -- The rail's pick is the one selection. The index is only where that room
    -- sits right now, which a delete anywhere can shift.
    FP.selectedIdx = not FP.viewGUID and h and h.zones and CH.tbSelZone and tIndexOf(h.zones, CH.tbSelZone) or nil

    -- A different house reframes to its own bounds and resets the zoom and pan.
    -- Switching floors keeps the shared house-wide frame and your current zoom and
    -- pan, so the view stays put when you take the stairs or page through floors.
    -- A plain rebuild (room edit, dot refresh) leaves everything untouched, which
    -- keeps a dragged handle from chasing a refitting map.
    if FP.HouseGUID() ~= lastBuiltGuid then
        FP.ResetView()
        FP.InvalidateFit() -- new house: reframe via EnsureFit below
    end
    lastBuiltGuid = FP.HouseGUID()

    -- Lazily (re)establish the house-wide fit. Only the reframe events invalidate
    -- it (house change above, plus open, reset, canvas resize, and zone changes
    -- elsewhere). A geometry edit never does, so the transform stays frozen while
    -- you drag.
    FP.EnsureFit()

    local floorCount = FP.RefreshFloorControls(h)
    local viewedFloor = CH.fpViewedFloor
    local ownerView = FP.OwnerView()

    -- The rooms we'll draw on this floor. A floor with none shows the empty
    -- state, same as a house with none.
    drawnCount = 0
    if h and h.zones then
        FP.DrawOrder(h, viewedFloor, ownerView, order)
    else
        wipe(order)
    end

    if #order == 0 then
        LayoutGrid(nil)
        FP.empty:SetText(
            floorCount > 1 and string.format(CH.L["FP_NO_ROOMS_ON_FLOOR_X"], viewedFloor) or CH.L["FP_NO_ROOMS"]
        )
        FP.empty:Show()
        -- Only for a house with nothing saved at all. An empty floor in a house that
        -- does have rooms is just an empty floor, nothing to repair.
        local suggestFix = FP.FixerCandidate()
        FP.fixHint:SetShown(suggestFix)
        FP.fixBtn:SetShown(suggestFix)
        -- Likewise only for a house with nothing in it, when the archive holds a
        -- map for it. Goes under the fixer nudge if both apply.
        local suggestArchive = not FP.viewGUID and CH.ArchiveWaiting(CH.currentHouseGUID)
        FP.archiveHint:ClearAllPoints()
        FP.archiveHint:SetPoint("TOP", suggestFix and FP.fixBtn or FP.empty, "BOTTOM", 0, -16)
        FP.archiveHint:SetShown(suggestArchive)
        FP.archiveBtn:SetShown(suggestArchive)
        FP.PositionHandles()
        return
    end

    -- The transform is the shared house-wide fit established by EnsureFit above.
    -- The draw loop maps world to canvas through it. Nothing here recomputes it,
    -- so editing a room never reframes.
    local k = FP.ZoomedScale()
    LayoutGrid(k)
    if not k then
        FP.PositionHandles()
        return -- nothing framed (e.g. all rooms secret to a visitor)
    end

    local selectedIdx = FP.selectedIdx
    local stairBoxes = ChamberlainDB.settings.showStairsOnMap
    local zones = h.zones
    local low, high = FP.Level("tiles"), FP.Level("tilesMax")

    -- Draw order, not zone index, keys the frame pool, so the pool stays dense
    -- (the top-of-build hide and the cursor hit test walk it in order). The real
    -- zone index rides on f.zoneIdx for selection and editing.
    for n, i in ipairs(order) do
        local zone = zones[i]
        local f = GetZoneFrame(n)
        -- its own level, or the game may draw it under a bigger room
        f:SetFrameLevel(math.min(low + n - 1, high))
        -- styled first, PlaceTile reads f.iconOnly
        local r, g, b = StyleTile(f, zone, i, i == selectedIdx, stairBoxes)
        PlaceTile(f, zone, k)
        -- Store for tooltip and click selection
        f.zone = zone
        f.zoneIdx = i
        f.zoneName = zone.name
        f.zoneW = zone.maxX - zone.minX
        f.zoneH = zone.maxY - zone.minY
        f.zoneTime = h.stats and h.stats[zone.name] or 0
        f.cr, f.cg, f.cb = r, g, b
        f.labelW = f.label:GetUnboundedStringWidth()
        f.round = zone.shape == "circle"
    end
    drawnCount = #order
    LayoutLabels()
    labelsAtK = k

    if not FP.viewGUID then
        FP.ShowPlayerDot()
    end
    FP.UpdateResetButton()
    FP.PositionHandles()
end

-- Reposition the room tiles for the current zoom/pan. The dots, corner markers and
-- player blip follow automatically through the OnUpdate transform, so only the
-- otherwise-static tiles need touching here.
function FP.TileReposition()
    FP.UpdateResetButton()
    local k = FP.ZoomedScale()
    if not k then
        return
    end
    local h = FP.CurrentHouse()
    if not h then
        return
    end
    for i = 1, drawnCount do
        local f = zonePool[i]
        PlaceTile(f, h.zones[f.zoneIdx], k)
    end
    -- a pan carries the labels along. A zoom or a resize changes what fits
    -- where.
    if k ~= labelsAtK or CH.editingLayout then
        LayoutLabels()
        labelsAtK = k
    end
    LayoutGrid(k)
    FP.PositionHandles()
end

-- Called from RoomManager when zones change so the floor plan stays in sync
function CH.RebuildFloorPlan()
    FP.minimapDirty = true -- the map may be closed but the minimap still has to know
    -- a house's first room, or its last one going, swaps the minimap picture
    CH.RefreshMinimapRooms()
    if FP.win:IsShown() then
        FP.InvalidateFit() -- zones changed (create/delete/share): reframe to new bounds
        FP.Build()
    end
end

-- Sync the map's selection to a room picked elsewhere (the build toolbox). Pass
-- nil to clear. revealFloor switches the map to the room's floor first, which the
-- toolbox room list wants but a map click does not (you can only click what's
-- shown, and stairs draw on both floors they link). Called through CH.SetSelection,
-- so it never calls back into it.
function CH.FloorPlanSelect(zone, revealFloor)
    local h = FP.CurrentHouse()
    local idx = zone and h and tIndexOf(h.zones, zone) or nil
    local otherFloor = revealFloor and idx and zone.floor and zone.floor ~= CH.fpViewedFloor
    if otherFloor then
        CH.fpViewedFloor = zone.floor
    end
    local old = FP.selectedIdx
    FP.selectedIdx = idx
    if not FP.win:IsShown() then
        CH.RefreshToolbox()
        return
    end
    -- A pick only changes how two tiles look. A full build would hide and show
    -- every tile under the mouse, and the tooltip would jump about with them.
    -- A delete or an archive swap clears the pick after the zones already
    -- moved, and then the tiles are out of date and only a build wil do.
    local oldF = old and FP.ZoneFrameByIdx(old)
    local newF = idx and FP.ZoneFrameByIdx(idx)
    local zones = h and h.zones or {}
    if otherFloor or (oldF and zones[old] ~= oldF.zone) or (newF and zones[idx] ~= newF.zone) then
        FP.Build()
        return
    end
    local stairBoxes = ChamberlainDB.settings.showStairsOnMap
    if oldF then
        StyleTile(oldF, oldF.zone, old, old == idx, stairBoxes)
    end
    if newF and newF ~= oldF then
        StyleTile(newF, newF.zone, idx, true, stairBoxes)
    end
    CH.RefreshToolbox()
    FP.PositionHandles()
end
