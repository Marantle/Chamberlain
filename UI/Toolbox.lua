local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Build rail  (the tools for making and fitting rooms)
-- ─────────────────────────────────────────────────────────────────────
-- The left column of the house map window, shown on a map you can edit. It
-- holds the tools for adding a room where you stand, the quick sizes and the
-- pad that move and resize the picked one, and the fit tools that line it up
-- with the wall you stand at. The coords sit at the bottom. The map to its
-- right is the bird's-eye editor. Build in the header or on the bar shows and
-- hides this column, and the bar's Map opens the map without it. The house card
-- (UI/FloorPlan/HouseCard.lua) takes the same spot on any map you can't edit.

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

local ROW_W = 188 -- the rail's inner width, what a full row spans

-- Lay a row's buttons out left to right, sharing the width, and hide the
-- rest of the row's set. A row changes with the picked room's shape.
local function LayoutRow(shown, all, y)
    for _, b in ipairs(all) do
        b:Hide()
    end
    local w = (ROW_W - (#shown - 1) * 6) / math.max(#shown, 1)
    for i, b in ipairs(shown) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 6), y)
        b:SetWidth(w)
        b:Show()
    end
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

-- ── Add tools ────────────────────────────────────────────────────────
Header("TB_ADD_HEADER", -10)

-- The game's room shapes four to a row, an icon each with the name on hover.
-- A click drops that room at your feet at the game's size.
local SHAPE_W = (ROW_W - 3 * 6) / 4
for i, e in ipairs(CH.SHAPE_LIST) do
    local b = CH.MakeShapeButton(tb, e, 28)
    b:SetWidth(SHAPE_W)
    b:SetPoint("TOPLEFT", PAD + (i - 1) % 4 * (SHAPE_W + 6), -28 - math.floor((i - 1) / 4) * 34)
    b:SetScript("OnClick", function()
        DropRoom(e.shape)
    end)
end

-- A tall button with its icon over the label.
local function AddTile(key, icon, col)
    local b = CH.MakeButton(tb, key, 91, 40)
    b:SetPoint("TOPLEFT", PAD + col * 97, -96)
    CH.AddButtonIcon(b, icon, 14):SetPoint("TOP", 0, -6)
    local fs = b:GetFontString()
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOMLEFT", 4, 6)
    fs:SetPoint("BOTTOMRIGHT", -4, 6)
    return b
end

local addStairs = AddTile("TB_ADD_STAIRS", "icon-stairs", 0)
local addMarker = AddTile("TB_ADD_MARKER", "icon-pin", 1)

local sep = CH.MakeRule(tb)
sep:SetPoint("TOPLEFT", PAD, -144)
sep:SetPoint("TOPRIGHT", -PAD, -144)

-- ── Selected room ────────────────────────────────────────────────────
Header("TB_SELECTED_HEADER", -152)

-- Picks the room from a list, and names the one picked with its size and a chip
-- in its map colour.
local selDrop = CH.MakeButton(tb, "TB_SELECT_ROOM", ROW_W, 26)
selDrop:SetPoint("TOPLEFT", PAD, -170)
local selDropFS = selDrop:GetFontString()
selDropFS:ClearAllPoints()
selDropFS:SetPoint("LEFT", 22, 0)
selDropFS:SetPoint("RIGHT", -6, 0)
selDropFS:SetJustifyH("LEFT")
local selChip = selDrop:CreateTexture(nil, "OVERLAY")
selChip:SetSize(10, 10)
selChip:SetPoint("LEFT", 7, 0)

-- Quick resize: the game's sizes as chips for a square or an octagon, with
-- the one the room is at lit. An L or a T turns instead, and every shaped
-- room can go back to the game's size after a hand resize.
local quickLabel = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
quickLabel:SetPoint("TOPLEFT", PAD, -201)
quickLabel:SetText(CH.L["TB_QUICK_RESIZE"])
quickLabel:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local chips = {}
for i = 1, #CH.SQUARE_SIZES do
    local b = CH.MakeButton(tb, "", 40, 22)
    b:SetScript("OnClick", function()
        FP.SetSelectedBox(b.size, b.size)
    end)
    chips[i] = b
end
local rotateBtn = CH.MakeButton(tb, "TB_ROTATE", 91, 22)
rotateBtn:SetScript("OnClick", FP.RotateSelected)
local gameBtn = CH.MakeButton(tb, "TB_GAME_SIZE", 91, 22)
CH.Tip(gameBtn, "TB_TT_GAME_SIZE")
gameBtn:SetScript("OnClick", function()
    local z = CH.tbSelZone
    FP.SetSelectedBox(CH.ShapeSize(z.shape, z.rot))
end)
local quickAll = { rotateBtn, gameBtn }
for _, b in ipairs(chips) do
    quickAll[#quickAll + 1] = b
end
local quick = {} -- the quick row for the picked room, filled per refresh

-- Move, Grow and Shrink set what the arrows do. The deltas go by screen
-- direction on the map, where X runs mirrored: screen-left is world +X and
-- screen-up world +Y. Each is steps for minX, maxX, minY, maxY, and "all" is
-- the middle of the pad, every wall at once. A shaped room reads the same
-- deltas as grow or shrink and scales as a whole, so it gets its own hint.
-- stylua: ignore
local MODES = {
    { key = "FP_MOVE", hint = "TB_HINT_MOVE", wholeHint = "TB_HINT_MOVE",
      left = { 1, 1, 0, 0 },  up = { 0, 0, 1, 1 },  down = { 0, 0, -1, -1 }, right = { -1, -1, 0, 0 } },
    { key = "FP_GROW", hint = "TB_HINT_GROW", wholeHint = "TB_HINT_GROW_WHOLE", all = { -1, 1, -1, 1 },
      left = { 0, 1, 0, 0 },  up = { 0, 0, 0, 1 },  down = { 0, 0, -1, 0 },  right = { -1, 0, 0, 0 } },
    { key = "FP_SHRINK", hint = "TB_HINT_SHRINK", wholeHint = "TB_HINT_SHRINK_WHOLE", all = { 1, -1, 1, -1 },
      left = { 0, -1, 0, 0 }, up = { 0, 0, 0, -1 }, down = { 0, 0, 1, 0 },   right = { 1, 0, 0, 0 } },
}
local MOVE, GROW = MODES[1], MODES[2]
local mode = MOVE
for i, m in ipairs(MODES) do
    m.btn = CH.MakeButton(tb, m.key, 63, 22)
    m.btn:SetPoint("TOPLEFT", PAD + (i - 1) * 62, -242)
    m.btn:SetScript("OnClick", function()
        mode = m
        CH.RefreshToolbox()
    end)
end

-- One cell of the 3x3 pad, an arrow on all but the middle one.
local function PadButton(dir, col, row)
    local b = CH.MakeButton(tb, "", 26, 22)
    b:SetPoint("TOPLEFT", PAD + col * 29, -272 - row * 25)
    if dir ~= "all" then
        CH.AddButtonIcon(b, "arrow-" .. dir, 10):SetPoint("CENTER")
    end
    b:SetScript("OnClick", function()
        local d = mode[dir]
        FP.AdjustSelected(d[1], d[2], d[3], d[4])
    end)
    return b
end

local padBtns = {
    PadButton("up", 1, 0),
    PadButton("left", 0, 1),
    PadButton("right", 2, 1),
    PadButton("down", 1, 2),
}
local padAll = PadButton("all", 1, 1)
CH.Tip(padAll, function()
    return mode == GROW and "TB_TT_GROW_ALL" or "TB_TT_SHRINK_ALL"
end)

local padHint = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
padHint:SetPoint("TOPLEFT", PAD + 96, -274)
padHint:SetWidth(92)
padHint:SetJustifyH("LEFT")
padHint:SetSpacing(2)
padHint:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

-- The fit tools work on the wall nearest you. Slide moves the whole room to
-- it and suits every shape. A plain room can also stretch that one wall, and
-- a round room sets its radius.
local slideBtn = CH.MakeButton(tb, "TB_SLIDE_EDGE", 91, 22)
CH.Tip(slideBtn, "TB_TT_SLIDE_EDGE")
local snapBtn = CH.MakeButton(tb, "TB_SNAP_EDGE", 91, 22)
CH.Tip(snapBtn, "TB_TT_SNAP_EDGE")
local radiusBtn = CH.MakeButton(tb, "TB_SET_RADIUS", 91, 22)
local fitAll = { slideBtn, snapBtn, radiusBtn }
local fit = {}

local editBtn = CH.MakeButton(tb, "TB_EDIT", 91, 22)
editBtn:SetPoint("TOPLEFT", PAD, -382)
local delBtn = CH.MakeButton(tb, "TB_DELETE", 91, 22)
delBtn:SetPoint("LEFT", editBtn, "RIGHT", 6, 0)

-- Everything that acts on the picked room, greyed out while there is none.
local needsRoom = { editBtn, delBtn, padAll }
for _, list in ipairs({ padBtns, quickAll, fitAll }) do
    for _, b in ipairs(list) do
        needsRoom[#needsRoom + 1] = b
    end
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

    wipe(quick)
    wipe(fit)
    if z then
        local i = tIndexOf(zones, z)
        selChip:SetColorTexture(FP.ZoneColor(z, i))
        selChip:Show()
        selDrop:SetText(string.format(CH.L["FMT_NAME_DIM_X"], z.name, CH.ZoneDimText(z)))
        padHint:SetText(CH.L[z.shape and mode.wholeHint or mode.hint])

        local def = z.shape and CH.SHAPES[z.shape]
        local w, h = z.maxX - z.minX, z.maxY - z.minY
        local sizes = def and def.sizes or (not z.shape and CH.SQUARE_SIZES)
        if sizes then
            for n, size in ipairs(sizes) do
                local b = chips[n]
                b.size = size[2]
                b:SetText(CH.L[size[1]])
                -- lit while the room is at that size, so a hand resize lights none
                CH.SetButtonActive(b, math.abs(w - size[2]) < 0.05 and (z.shape or math.abs(h - size[2]) < 0.05))
                quick[n] = b
            end
        else
            if def.rotates then
                quick[#quick + 1] = rotateBtn
            end
            quick[#quick + 1] = gameBtn
            local gw, gh = CH.ShapeSize(z.shape, z.rot)
            gameBtn:SetEnabled(math.abs(w - gw) > 0.05 or math.abs(h - gh) > 0.05)
        end

        fit[1] = slideBtn
        if not z.shape then
            fit[2] = snapBtn
        elseif z.shape == "circle" then
            fit[2] = radiusBtn
        end
    else
        selChip:Hide()
        selDrop:SetText(CH.L["TB_SELECT_ROOM"])
        padHint:SetText(CH.L["FP_EDIT_HINT"])
        fit[1] = slideBtn
    end
    quickLabel:SetShown(#quick > 0)
    LayoutRow(quick, quickAll, -214)
    LayoutRow(fit, fitAll, -354)
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

-- The wall of the box nearest where the player stands: its bound's key, the
-- bound of the wall across from it, and which way is out (-1 for a min
-- wall, 1 for a max wall). Distance to each wall as a finite segment, not an
-- infinite line. Standing off to one side, the top and bottom walls are only
-- reachable at their corner, so the side wall you're actually next to wins
-- (squared distance, no sqrt needed).
local function NearestWall(z, x, y)
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
        return "minX", "maxX", -1
    elseif m == dMaxX then
        return "maxX", "minX", 1
    elseif m == dMinY then
        return "minY", "maxY", -1
    end
    return "maxY", "minY", 1
end

-- A fit tool gets the picked room and where you stand, and its edit is saved.
local function FitTool(btn, fn)
    btn:SetScript("OnClick", function()
        local z = CH.tbSelZone
        if not z then
            return
        end
        local x, y = CH.GetWorldPos()
        if not x then
            CH.Print(CH.L["TB_NO_POSITION"])
            return
        end
        fn(z, x, y)
        CH.TouchHouse(CH.tbSelGuid)
    end)
end

-- Where the wall you stand at really is: CH.WALL past you, away from the
-- room. Hands back the wall's key, the wall across from it, and the
-- coordinate to put it at.
local function WallAt(z, x, y)
    local wall, across, out = NearestWall(z, x, y)
    local pos = (wall == "minX" or wall == "maxX") and x or y
    return wall, across, pos + out * CH.WALL
end

-- Move the whole room so its nearest wall is where you stand. Two walls, one
-- each way, line a room of a set size up with the real one.
FitTool(slideBtn, function(z, x, y)
    local wall, across, at = WallAt(z, x, y)
    local d = at - z[wall]
    z[wall], z[across] = z[wall] + d, z[across] + d
end)

-- Pull the nearest wall to where you stand, no closer than a yard to the wall
-- across. Walking the perimeter and tapping at each wall fits a plain room
-- without marking corners.
FitTool(snapBtn, function(z, x, y)
    local wall, across, at = WallAt(z, x, y)
    if wall == "minX" or wall == "minY" then
        z[wall] = math.min(at, z[across] - 1)
    else
        z[wall] = math.max(at, z[across] + 1)
    end
end)

-- A round room: its radius is your distance from the centre, plus the wall.
FitTool(radiusBtn, function(z, x, y)
    local cx, cy = CH.ZoneCentre(z)
    local r = math.max(0.5, math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) + CH.WALL)
    CH.BoxAbout(z, cx, cy, r * 2, r * 2)
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
