local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Build rail  (the tools for making and fitting rooms)
-- ─────────────────────────────────────────────────────────────────────
-- The left column of the house map window, shown on a map you can edit. It
-- holds the tools for adding a room where you stand and the pad that moves and
-- resizes the picked one. The coords sit at the bottom. The map to its right is the
-- bird's-eye editor. Fold the map away (the « in the header, or the bar's
-- Build button) and the window shrinks to just this column, for walking the
-- house with the tools up. The house card (UI/FloorPlan/HouseCard.lua) takes
-- the same spot on any map you can't edit.

local FP = CH.FP
local PAD = 10

local tb = CreateFrame("Frame", nil, FP.rail)
tb:SetAllPoints()
tb:Hide()
CH.toolbox = tb

-- The room these fit controls act on, and the house it lives in. Set when you
-- drop a room or pick one from the dropdown. Kept on CH so the rest of the addon
-- can read the current build target later.
CH.tbSelZone = nil
CH.tbSelGuid = nil

local function Header(key, y)
    local fs = CH.MakeSectionHeader(tb, key, y)
    fs:SetPoint("TOPLEFT", PAD, y)
    return fs
end

-- ── Add tools ────────────────────────────────────────────────────────
Header("TB_ADD_HEADER", -10)

-- A tall button with its icon over the label. Without svg support it's the
-- label alone, centred as usual.
local function AddTile(key, icon, col, row)
    local b = CH.MakeButton(tb, key, 91, 40)
    b:SetPoint("TOPLEFT", PAD + col * 97, -28 - row * 46)
    local art = CH.AddButtonIcon(b, icon, 14)
    if art then
        art:SetPoint("TOP", 0, -6)
        local fs = b:GetFontString()
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", 4, 6)
        fs:SetPoint("BOTTOMRIGHT", -4, 6)
    end
    return b
end

local addSquare = AddTile("TB_ADD_SQUARE", "icon-square", 0, 0)
local addCircle = AddTile("TB_ADD_CIRCLE", "icon-circle", 1, 0)
local addStairs = AddTile("TB_ADD_STAIRS", "icon-stairs", 0, 1)
local addMarker = AddTile("TB_ADD_MARKER", "icon-pin", 1, 1)

local sep = CH.MakeRule(tb)
sep:SetPoint("TOPLEFT", PAD, -124)
sep:SetPoint("TOPRIGHT", -PAD, -124)

-- ── Selected room ────────────────────────────────────────────────────
Header("TB_SELECTED_HEADER", -132)

-- Picks the room from a list, and names the one picked with its size and a chip
-- in its map colour.
local selDrop = CH.MakeButton(tb, "TB_SELECT_ROOM", 188, 26)
selDrop:SetPoint("TOPLEFT", PAD, -150)
local selDropFS = selDrop:GetFontString()
selDropFS:ClearAllPoints()
selDropFS:SetPoint("LEFT", 22, 0)
selDropFS:SetPoint("RIGHT", -6, 0)
selDropFS:SetJustifyH("LEFT")
local selChip = selDrop:CreateTexture(nil, "OVERLAY")
selChip:SetSize(10, 10)
selChip:SetPoint("LEFT", 7, 0)

-- Move, Grow and Shrink set what the arrows do. The deltas go by screen
-- direction on the map, where X runs mirrored: screen-left is world +X and
-- screen-up world +Y. Each is steps for minX, maxX, minY, maxY, and "all" is
-- the middle of the pad, every wall at once.
-- stylua: ignore
local MODES = {
    { key = "FP_MOVE", hint = "TB_HINT_MOVE",
      left = { 1, 1, 0, 0 },  up = { 0, 0, 1, 1 },  down = { 0, 0, -1, -1 }, right = { -1, -1, 0, 0 } },
    { key = "FP_GROW", hint = "TB_HINT_GROW", all = { -1, 1, -1, 1 },
      left = { 0, 1, 0, 0 },  up = { 0, 0, 0, 1 },  down = { 0, 0, -1, 0 },  right = { -1, 0, 0, 0 } },
    { key = "FP_SHRINK", hint = "TB_HINT_SHRINK", all = { 1, -1, 1, -1 },
      left = { 0, -1, 0, 0 }, up = { 0, 0, 0, -1 }, down = { 0, 0, 1, 0 },   right = { 1, 0, 0, 0 } },
}
local MOVE, GROW = MODES[1], MODES[2]
local mode = MOVE
for i, m in ipairs(MODES) do
    m.btn = CH.MakeButton(tb, m.key, 63, 22)
    m.btn:SetPoint("TOPLEFT", PAD + (i - 1) * 62, -182)
    m.btn:SetScript("OnClick", function()
        mode = m
        CH.RefreshToolbox()
    end)
end

-- One cell of the 3x3 pad. The arrows are svgs and a 12.0 client gets the old
-- letters instead.
local function PadButton(dir, col, row, fallback)
    local b = CH.MakeButton(tb, "", 26, 22)
    b:SetPoint("TOPLEFT", PAD + col * 29, -212 - row * 25)
    local art = dir ~= "all" and CH.AddButtonIcon(b, "arrow-" .. dir, 10)
    if art then
        art:SetPoint("CENTER")
    else
        b:SetText(fallback)
    end
    b:SetScript("OnClick", function()
        local d = mode[dir]
        FP.AdjustSelected(d[1], d[2], d[3], d[4])
    end)
    return b
end

local padBtns = {
    PadButton("up", 1, 0, "^"),
    PadButton("left", 0, 1, "<"),
    PadButton("right", 2, 1, ">"),
    PadButton("down", 1, 2, "v"),
}
local padAll = PadButton("all", 1, 1, "")
CH.Tip(padAll, function()
    return mode == GROW and "TB_TT_GROW_ALL" or "TB_TT_SHRINK_ALL"
end)

local padHint = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
padHint:SetPoint("TOPLEFT", PAD + 96, -214)
padHint:SetWidth(92)
padHint:SetJustifyH("LEFT")
padHint:SetSpacing(2)
padHint:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local snapBtn = CH.MakeButton(tb, "TB_SNAP_EDGE", 188, 22)
snapBtn:SetPoint("TOPLEFT", PAD, -294)

local editBtn = CH.MakeButton(tb, "TB_EDIT", 91, 22)
editBtn:SetPoint("TOPLEFT", PAD, -322)
local delBtn = CH.MakeButton(tb, "TB_DELETE", 91, 22)
delBtn:SetPoint("LEFT", editBtn, "RIGHT", 6, 0)

-- Everything that acts on the picked room, greyed out while there is none.
local needsRoom = { snapBtn, editBtn, delBtn, padAll }
for _, b in ipairs(padBtns) do
    needsRoom[#needsRoom + 1] = b
end
for _, m in ipairs(MODES) do
    needsRoom[#needsRoom + 1] = m.btn
end

-- ── Readout: live coords and the house you're in ──────────────────────
local footLine = CH.MakeRule(tb)
footLine:SetPoint("BOTTOMLEFT", PAD, 42)
footLine:SetPoint("BOTTOMRIGHT", -PAD, 42)

CH.coordLabel = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.coordLabel:SetPoint("BOTTOMLEFT", PAD, 24)
CH.coordLabel:SetText(CH.L["HUD_COORD_PLACEHOLDER"])

CH.zoneLabel = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.zoneLabel:SetPoint("BOTTOMLEFT", PAD, 10)
CH.zoneLabel:SetText("-")
CH.zoneLabel:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

-- The window's heigth when folded to this column: the header, the tools
-- above and the readout.
FP.foldedHeight = 26 + 344 + 12 + 48

-- ── Behaviour ────────────────────────────────────────────────────────

-- The current house's room list, or nil if we have nothing for this house yet.
local function HouseRooms()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return h and h.zones or nil
end

function CH.RefreshToolbox()
    local zones = HouseRooms()

    -- Drop a stale selection (room deleted, or we changed houses).
    if CH.tbSelZone then
        local stillHere = false
        if zones then
            for _, z in ipairs(zones) do
                if z == CH.tbSelZone then
                    stillHere = true
                    break
                end
            end
        end
        if not stillHere then
            CH.tbSelZone, CH.tbSelGuid = nil, nil
        end
    end

    selDrop:SetEnabled(zones ~= nil)

    local z = CH.tbSelZone
    for _, b in ipairs(needsRoom) do
        b:SetEnabled(z ~= nil)
    end
    for _, m in ipairs(MODES) do
        CH.SetButtonActive(m.btn, m == mode)
    end
    padAll:SetShown(mode ~= MOVE)
    padAll:SetText(mode == GROW and "+" or "-")

    if z then
        local i = tIndexOf(zones, z)
        selChip:SetColorTexture(FP.ZoneColor(z, i))
        selChip:Show()
        selDrop:SetText(string.format(CH.L["FMT_NAME_DIM_X"], z.name, CH.ZoneDimText(z)))
        padHint:SetText(CH.L[mode.hint])
        -- A circle has no edges to snap, so the same button sets its radius instead.
        snapBtn:SetText(z.shape == "circle" and CH.L["TB_SET_RADIUS"] or CH.L["TB_SNAP_EDGE"])
    else
        selChip:Hide()
        selDrop:SetText(CH.L["TB_SELECT_ROOM"])
        padHint:SetText(CH.L["FP_EDIT_HINT"])
        snapBtn:SetText(CH.L["TB_SNAP_EDGE"])
    end
end

-- One place to set the selected room so the rail and the map always agree.
-- Either side calls this and the other resyncs. The guard stops the two
-- refreshes from bouncing the call back and forth.
-- revealFloor switches the map to the room's floor so it can be seen. Only the
-- rail's room list passes it: picking a room there may mean one on another
-- floor. A map click never sets it, since you can only click what's already shown
-- (and a staircase is drawn on both floors it links, so switching would jump you).
local syncing = false
function CH.SetSelection(zone, guid, revealFloor)
    if syncing then
        return
    end
    syncing = true
    CH.tbSelZone = zone
    CH.tbSelGuid = guid
    CH.FloorPlanSelect(zone, revealFloor) -- refreshes the rail on its way
    syncing = false
end

-- Drop a fresh room of the given shape where the player stands, select it, and
-- open the editor so it can be named right away.
local function DropRoom(shape)
    local x, y, mapID = CH.GetWorldPos()
    if not x then
        CH.Print(CH.L["TB_NO_POSITION"])
        return
    end
    local z, guid = CH.CreateZoneAt(x, y, mapID, shape)
    if z then
        CH.SetSelection(z, guid)
        CH.OpenRenameDialog(z, guid)
    end
end
addSquare:SetScript("OnClick", function()
    DropRoom(nil)
end)
addCircle:SetScript("OnClick", function()
    DropRoom("circle")
end)

addStairs:SetScript("OnClick", function()
    CH.OpenStairsWizard()
end)
addMarker:SetScript("OnClick", function()
    CH.OpenFloorMarkerWizard()
end)

selDrop:SetScript("OnClick", function(self)
    if not MenuUtil then
        return
    end
    local zones = HouseRooms()
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(CH.L["TB_PICK_ROOM"])
        local any = false
        if zones then
            for _, z in ipairs(zones) do
                -- skip stair anchors: they have their own editor on the map
                if z.setFloor == nil and z.floorDelta == nil then
                    any = true
                    root:CreateRadio(z.name, function()
                        return CH.tbSelZone == z
                    end, function()
                        CH.SetSelection(z, CH.currentHouseGUID, true)
                    end)
                end
            end
        end
        if not any then
            root:CreateButton(CH.L["TB_NO_ROOMS"]):SetEnabled(false)
        end
    end)
end)

-- For a rectangle, snap the nearest edge to where the player stands. Walking the
-- perimeter and tapping at each wall fits the room without marking corners. For a
-- circle, set the radius to the player's distance from the centre instead.
snapBtn:SetScript("OnClick", function()
    local z = CH.tbSelZone
    if not z then
        return
    end
    local x, y = CH.GetWorldPos()
    if not x then
        CH.Print(CH.L["TB_NO_POSITION"])
        return
    end
    if z.shape == "circle" then
        local cx = (z.minX + z.maxX) * 0.5
        local cy = (z.minY + z.maxY) * 0.5
        local r = math.max(0.5, math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)))
        z.minX, z.maxX = cx - r, cx + r
        z.minY, z.maxY = cy - r, cy + r
        CH.TouchHouse(CH.tbSelGuid)
        return
    end
    -- Distance to each wall as a finite segment, not an infinite line. Standing off
    -- to one side, the top and bottom walls are only reachable at their corner, so
    -- the side wall you're actually next to wins (squared distance, no sqrt needed).
    local function vDist(ex) -- a vertical wall at X = ex, spanning the room's Y
        local dy = 0
        if y < z.minY then
            dy = y - z.minY
        elseif y > z.maxY then
            dy = y - z.maxY
        end
        local dx = x - ex
        return dx * dx + dy * dy
    end
    local function hDist(ey) -- a horizontal wall at Y = ey, spanning the room's X
        local dx = 0
        if x < z.minX then
            dx = x - z.minX
        elseif x > z.maxX then
            dx = x - z.maxX
        end
        local dy = y - ey
        return dx * dx + dy * dy
    end
    local dMinX, dMaxX = vDist(z.minX), vDist(z.maxX)
    local dMinY, dMaxY = hDist(z.minY), hDist(z.maxY)
    local m = math.min(dMinX, dMaxX, dMinY, dMaxY)
    if m == dMinX then
        z.minX = math.min(x, z.maxX - 1)
    elseif m == dMaxX then
        z.maxX = math.max(x, z.minX + 1)
    elseif m == dMinY then
        z.minY = math.min(y, z.maxY - 1)
    else
        z.maxY = math.max(y, z.minY + 1)
    end
    CH.TouchHouse(CH.tbSelGuid)
end)

editBtn:SetScript("OnClick", function()
    if CH.tbSelZone then
        CH.OpenRenameDialog(CH.tbSelZone, CH.tbSelGuid)
    end
end)

delBtn:SetScript("OnClick", function()
    local z = CH.tbSelZone
    local guid = CH.tbSelGuid
    local h = guid and ChamberlainDB.houses[guid]
    if not z or not h then
        return
    end
    for i, zone in ipairs(h.zones) do
        if zone == z then
            table.remove(h.zones, i)
            break
        end
    end
    CH.DropZoneStats(h, z.name)
    CH.SetSelection(nil, nil) -- clear it on the map too
    CH.TouchHouse(guid)
end)
