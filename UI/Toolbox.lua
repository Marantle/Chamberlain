local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Build toolbox  (the floating palette for making and fitting rooms)
-- ─────────────────────────────────────────────────────────────────────
-- A small movable window you open from the launcher's Build button or the
-- minimap. It holds the live coordinate readout (moved off the old HUD), the
-- "add a room where I stand" tools, and quick fitting for the picked room. The
-- house map stays the bird's-eye editor. This is the build-while-standing-in-it
-- companion.
--
-- By default it docks to the map's right edge, so Build opens the pair and they
-- move as one window. Dragging the toolbox tears it off into a free float for
-- walking the house with just the small palette up, and the « button in the
-- header glues it back. Opening the map alone never brings the toolbox with it,
-- and closing the toolbox leaves the map alone.

CH.toolbox = CreateFrame("Frame", "ChamberlainToolbox", UIParent, "BackdropTemplate")
local tb = CH.toolbox
tb:SetSize(210, 292)
tb:SetFrameStrata("DIALOG")
tb:SetToplevel(true)
CH.SkinWindow(tb, "TB_TITLE")
tb:Hide()
table.insert(UISpecialFrames, "ChamberlainToolbox")

CH.ApplyToolboxPos = CH.MakeMovablePersistent(tb, "toolboxX", "toolboxY")

-- Close button in the header corner, the same gold x as the talking head.
local tbClose = CreateFrame("Button", nil, tb)
tbClose:SetSize(18, 18)
tbClose:SetPoint("TOPRIGHT", tb, "TOPRIGHT", -4, -4)
local tbCloseX = tbClose:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tbCloseX:SetAllPoints()
tbCloseX:SetText("|cffFFD700x|r")
tbClose:SetScript("OnEnter", function()
    tbCloseX:SetText("|cffFFFFFFx|r")
end)
tbClose:SetScript("OnLeave", function()
    tbCloseX:SetText("|cffFFD700x|r")
end)
tbClose:SetScript("OnClick", function()
    tb:Hide()
end)

-- Dock toggle next to the x. « pulls the toolbox onto the map's right edge
-- (opening the map if it's closed), » pops it back out to its floating spot.
-- Dragging the toolbox while docked tears it off the same way.
local tbDock = CreateFrame("Button", nil, tb)
tbDock:SetSize(18, 18)
tbDock:SetPoint("RIGHT", tbClose, "LEFT", -2, 0)
local tbDockGlyph = tbDock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tbDockGlyph:SetAllPoints()
tbDockGlyph:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
tbDock:SetScript("OnEnter", function(self)
    tbDockGlyph:SetTextColor(1, 1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local key = ChamberlainDB.settings.toolboxDocked and "TB_TT_UNDOCK" or "TB_TT_DOCK"
    GameTooltip:SetText(CH.L[key], 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
tbDock:SetScript("OnLeave", function()
    tbDockGlyph:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    GameTooltip:Hide()
end)

-- The room these fit controls act on, and the house it lives in. Set when you
-- drop a room or pick one from the dropdown. Kept on CH so the rest of the addon
-- can read the current build target later.
CH.tbSelZone = nil
CH.tbSelGuid = nil

-- ── Readout: live coords + current room/house (lives here now, not the HUD) ──
CH.coordLabel = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.coordLabel:SetPoint("TOPLEFT", 12, -30)
CH.coordLabel:SetText(CH.L["HUD_COORD_PLACEHOLDER"])

CH.zoneLabel = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.zoneLabel:SetPoint("TOPLEFT", 12, -44)
CH.zoneLabel:SetText("-")
CH.zoneLabel:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

CH.MakeSep(tb, -56)

-- ── Add tools ────────────────────────────────────────────────────────
CH.MakeSectionHeader(tb, "TB_ADD_HEADER", -62)

local addSquare = CH.MakeButton(tb, "TB_ADD_SQUARE", 91, 22)
addSquare:SetPoint("TOPLEFT", 12, -80)
local addCircle = CH.MakeButton(tb, "TB_ADD_CIRCLE", 91, 22)
addCircle:SetPoint("LEFT", addSquare, "RIGHT", 4, 0)

local addStairs = CH.MakeButton(tb, "TB_ADD_STAIRS", 91, 22)
addStairs:SetPoint("TOPLEFT", 12, -104)
local addMarker = CH.MakeButton(tb, "TB_ADD_MARKER", 91, 22)
addMarker:SetPoint("LEFT", addStairs, "RIGHT", 4, 0)

CH.MakeSep(tb, -132)

-- ── Selected room ────────────────────────────────────────────────────
CH.MakeSectionHeader(tb, "TB_SELECTED_HEADER", -138)

local selDrop = CH.MakeButton(tb, "TB_SELECT_ROOM", 186, 22)
selDrop:SetPoint("TOPLEFT", 12, -156)
local selDropFS = selDrop:GetFontString()
if selDropFS then
    selDropFS:SetWidth(172)
    selDropFS:SetWordWrap(false)
end

local snapBtn = CH.MakeButton(tb, "TB_SNAP_EDGE", 186, 22)
snapBtn:SetPoint("TOPLEFT", 12, -180)

local growBtn = CH.MakeButton(tb, "TB_GROW", 91, 22)
growBtn:SetPoint("TOPLEFT", 12, -204)
local shrinkBtn = CH.MakeButton(tb, "TB_SHRINK", 91, 22)
shrinkBtn:SetPoint("LEFT", growBtn, "RIGHT", 4, 0)

local editBtn = CH.MakeButton(tb, "TB_EDIT", 91, 22)
editBtn:SetPoint("TOPLEFT", 12, -228)
local delBtn = CH.MakeButton(tb, "TB_DELETE", 91, 22)
delBtn:SetPoint("LEFT", editBtn, "RIGHT", 4, 0)

-- The Show map row only exists while floating; docked, the map is right there.
local mapSep = CH.MakeSep(tb, -256)

local mapBtn = CH.MakeButton(tb, "TB_SHOW_MAP", 186, 22)
mapBtn:SetPoint("TOPLEFT", 12, -262)

-- ── Behaviour ────────────────────────────────────────────────────────

-- Push a fit edit out to the map, list, and party, then resync our own labels.
local function AfterEdit()
    CH.TouchHouse(CH.tbSelGuid)
    CH.RefreshToolbox()
end

-- The current house's room list, or nil if we have nothing for this house yet.
local function HouseRooms()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return h and h.zones or nil
end

function CH.RefreshToolbox()
    local own = CH.isOwnHouse
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

    addSquare:SetEnabled(own)
    addCircle:SetEnabled(own)
    addStairs:SetEnabled(own)
    addMarker:SetEnabled(own)
    selDrop:SetEnabled(own and zones ~= nil)

    local hasSel = own and CH.tbSelZone ~= nil
    snapBtn:SetEnabled(hasSel)
    growBtn:SetEnabled(hasSel)
    shrinkBtn:SetEnabled(hasSel)
    editBtn:SetEnabled(hasSel)
    delBtn:SetEnabled(hasSel)

    local z = CH.tbSelZone
    if z then
        selDrop:SetText(string.format(CH.L["FMT_NAME_DIM_X"], z.name, CH.ZoneDimText(z)))
        -- A circle has no edges to snap, so the same button sets its radius instead.
        snapBtn:SetText(z.shape == "circle" and CH.L["TB_SET_RADIUS"] or CH.L["TB_SNAP_EDGE"])
    else
        selDrop:SetText(CH.L["TB_SELECT_ROOM"])
        snapBtn:SetText(CH.L["TB_SNAP_EDGE"])
    end
end

-- One place to set the selected room so the toolbox and the house map always
-- agree. Either side calls this and the other resyncs. The guard stops the two
-- refreshes from bouncing the call back and forth.
-- revealFloor switches the map to the room's floor so it can be seen. Only the
-- toolbox's room list passes it: picking a room there may mean one on another
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
    CH.RefreshToolbox()
    if CH.FloorPlanSelect then
        CH.FloorPlanSelect(zone, revealFloor)
    end
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
        AfterEdit()
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
    AfterEdit()
end)

-- Grow/shrink all four edges by half a yard, keeping at least 1 yard across.
local function Resize(d)
    local z = CH.tbSelZone
    if not z then
        return
    end
    z.minX, z.maxX = z.minX - d, z.maxX + d
    z.minY, z.maxY = z.minY - d, z.maxY + d
    if z.maxX - z.minX < 1 then
        local cx = (z.minX + z.maxX) * 0.5
        z.minX, z.maxX = cx - 0.5, cx + 0.5
    end
    if z.maxY - z.minY < 1 then
        local cy = (z.minY + z.maxY) * 0.5
        z.minY, z.maxY = cy - 0.5, cy + 0.5
    end
    AfterEdit()
end
growBtn:SetScript("OnClick", function()
    Resize(0.5)
end)
shrinkBtn:SetScript("OnClick", function()
    Resize(-0.5)
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

mapBtn:SetScript("OnClick", function()
    CH.OpenFloorPlan()
end)

-- Put the toolbox where the docked flag says it belongs. Docked, it becomes a
-- child of the map anchored to its right edge, so dragging the map carries it
-- along and hiding the map hides it too. Floating, it goes back to being its
-- own toplevel window at the saved offset. The Show map row is dropped while
-- docked and the frame shortened to match.
function CH.ApplyToolboxLayout()
    local fp = CH.floorPlan
    if ChamberlainDB.settings.toolboxDocked and fp then
        tb:SetParent(fp)
        tb:ClearAllPoints()
        tb:SetPoint("TOPLEFT", fp, "TOPRIGHT", 4, 0)
        tb:SetToplevel(false)
        mapSep:Hide()
        mapBtn:Hide()
        tb:SetHeight(262)
        tbDockGlyph:SetText("»")
    else
        tb:SetParent(UIParent)
        tb:SetFrameStrata("DIALOG")
        tb:SetToplevel(true)
        mapSep:Show()
        mapBtn:Show()
        tb:SetHeight(292)
        tbDockGlyph:SetText("«")
        CH.ApplyToolboxPos()
    end
end

tbDock:SetScript("OnClick", function()
    ChamberlainDB.settings.toolboxDocked = not ChamberlainDB.settings.toolboxDocked
    if ChamberlainDB.settings.toolboxDocked and CH.floorPlan and not CH.floorPlan:IsShown() then
        CH.OpenFloorPlan()
    end
    CH.ApplyToolboxLayout()
end)

-- Tear-off: dragging a docked toolbox sets it loose. The persistent-position
-- handler has already saved the drop point by the time this hook runs, so the
-- relayout leaves it right where it was let go.
tb:HookScript("OnDragStop", function()
    if ChamberlainDB.settings.toolboxDocked then
        ChamberlainDB.settings.toolboxDocked = false
        CH.ApplyToolboxLayout()
    end
end)

-- Docked, the toolbox gives up its own toplevel flag, so clicking it has to
-- lift the map's subtree by hand for the pair to rise above other windows.
tb:HookScript("OnMouseDown", function()
    if CH.floorPlan and tb:GetParent() == CH.floorPlan then
        CH.floorPlan:Raise()
    end
end)

function CH.OpenToolbox()
    if ChamberlainDB.settings.toolboxDocked then
        CH.OpenFloorPlan()
    end
    CH.ApplyToolboxLayout()
    tb:Show()
    tb:Raise()
    CH.RefreshToolbox()
end

-- Launcher/minimap toggle: open if closed, close if already open.
function CH.ToggleToolbox()
    if tb:IsShown() then
        tb:Hide()
    else
        CH.OpenToolbox()
    end
end
