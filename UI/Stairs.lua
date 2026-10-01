local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Stairs: Add stairs, Floor pin, the stair editor and the floor explainer
-- ─────────────────────────────────────────────────────────────────────
-- There is no elevation API, so Chamberlain can't tell which floor a player is
-- on. The fix is to mark the staircases: a pair of small "anchor" zones, one at
-- the bottom and one at the top, each set to its floor. Walking onto one sets the
-- active floor (see Housing/Housing.lua). Add stairs hides the words
-- "anchor / absolute / relative" and asks the player to mark their stairs.
-- All three are side panels in the house map (3.33.0, windows of their own
-- before that), built from the same few rows.

local FP = CH.FP
local PAD = 14

-- Half-extent of a stair anchor footprint, in yards. The landing is captured as a
-- single point and grown into a ~4 yd box so the zone ticker reliably catches it.
local ANCHOR_HALF = 2.0

-- ── One-time explainer ───────────────────────────────────────────────

local intro
local function BuildIntro()
    if intro then
        return intro
    end
    intro = CreateFrame("Frame", "ChamberlainFloorIntro", UIParent, "BackdropTemplate")
    intro:SetSize(380, 196)
    intro:SetFrameStrata("FULLSCREEN_DIALOG")
    intro:SetToplevel(true)
    intro:SetPoint("CENTER")
    CH.MakeDraggable(intro)
    CH.SkinWindow(intro, "ST_TITLE_FLOORS", true)

    local body = intro:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 18, -38)
    body:SetPoint("TOPRIGHT", -18, -38)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    body:SetText(CH.L["ST_INTRO_BODY"])

    local setup = CH.MakeButton(intro, "ST_SET_UP_STAIRS", 130, 24)
    setup:SetPoint("BOTTOMRIGHT", intro, "BOTTOM", -4, 12)
    setup:SetScript("OnClick", function()
        intro:Hide()
        CH.OpenStairsWizard()
    end)

    local later = CH.MakeButton(intro, "ST_LATER", 90, 24)
    later:SetPoint("BOTTOMLEFT", intro, "BOTTOM", 4, 12)
    later:SetScript("OnClick", function()
        intro:Hide()
    end)

    return intro
end

-- Shown the first time a player adds a second floor. Flagged in settings so it
-- only ever appears once.
function CH.MaybeShowFloorIntro()
    if ChamberlainDB.settings.seenFloorIntro then
        return
    end
    ChamberlainDB.settings.seenFloorIntro = true
    BuildIntro():Show()
end

-- ── Rows the panels share ────────────────────────────────────────────

-- A line of text with - and + at the right end, y down from the top.
local function Stepper(parent, y, onLess, onMore)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", PAD, y)
    local more = CH.MakeButton(parent, "", 22, 20)
    more:SetText("+")
    more:SetPoint("TOPRIGHT", -PAD, y + 2)
    more:SetScript("OnClick", onMore)
    local less = CH.MakeButton(parent, "", 22, 20)
    less:SetText("-")
    less:SetPoint("RIGHT", more, "LEFT", -4, 0)
    less:SetScript("OnClick", onLess)
    return label
end

-- A Mark button that takes the spot you stand on, with whether it's set
-- beside it. got(spot) hears the spot.
local function MarkRow(parent, y, key, got)
    local btn = CH.MakeButton(parent, key, 150, 24)
    btn:SetPoint("TOPLEFT", PAD, y)
    local state = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    state:SetPoint("LEFT", btn, "RIGHT", 10, 0)
    btn:SetScript("OnClick", function()
        local x, yy, mapID = CH.GetWorldPos()
        if x then
            got({ x = x, y = yy, mapID = mapID })
        end
    end)
    return state
end

local function Hint(parent, y, key)
    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", PAD, y)
    hint:SetPoint("RIGHT", -PAD, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(CH.L[key])
    return hint
end

local function Ready(mark)
    return CH.L[mark and "ST_READY" or "ST_NOT_SET"]
end

-- The two new panels only work in your own house, standing in it, once it
-- has a second floor. Hands back the house, or nil with the reason in chat.
local function OwnHouseWithFloors(notOwnKey)
    if not CH.isOwnHouse then
        CH.Print(CH.L[notOwnKey])
        return
    end
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or (h.floorCount or 1) < 2 then
        CH.Print(CH.L["ST_ADD_SECOND_FLOOR_FIRST"])
        return
    end
    return h
end

-- The map on your own house, where the new panels go. A panel open for
-- another one lets go first, asking if it has to, and open() runs after.
local function OnOwnMap(open)
    if FP.panel then
        FP.LeavePanel(open)
        return false
    end
    if not FP.win:IsShown() or FP.viewGUID then
        CH.OpenFloorPlan()
    end
    return true
end

-- A new panel closes when the map stops showing your house.
local function StillHome()
    if FP.HouseGUID() ~= CH.currentHouseGUID or not CH.isOwnHouse then
        FP.ClosePanel(true)
    end
end

-- Build a small axis-aligned box around a captured landing point.
local function AnchorBox(mark)
    return {
        mapID = mark.mapID,
        minX = mark.x - ANCHOR_HALF,
        maxX = mark.x + ANCHOR_HALF,
        minY = mark.y - ANCHOR_HALF,
        maxY = mark.y + ANCHOR_HALF,
    }
end

-- ── Add stairs ───────────────────────────────────────────────────────

local lowerFloor = 1 -- the staircase connects lowerFloor <-> lowerFloor+1
local upMark, downMark -- captured { x, y, mapID }, the mark that sends you up and the one down

local wiz = { frame = FP.MakePanel("ST_TITLE_ADD_STAIRS"), check = StillHome }
local RefreshWizard -- set once the rows exist

local function HouseFloorCount()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return (h and h.floorCount) or 1
end

local function SaveStairs()
    if not upMark or not downMark then
        return
    end
    if not CH.currentHouseGUID then
        CH.Print(CH.L["ST_STAND_IN_HOUSE_STAIRS"])
        return
    end
    if upMark.mapID ~= downMark.mapID then
        CH.Print(CH.L["ST_DIFFERENT_MAPS"])
        return
    end
    local upper = lowerFloor + 1
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    -- The staircase can't connect to a floor that doesn't exist yet.
    if upper > (h.floorCount or 1) then
        h.floorCount = upper
    end

    -- A matched pair scoped to these two floors. Each mark lives on the floor
    -- you leave and is named for the floor it takes you to: the up mark lives
    -- on lowerFloor and sets upper, the down mark lives on upper and sets
    -- lowerFloor. fromFloor keeps the pair inert on every other floor, so a
    -- spiral's stacked landings don't cross-fire. Both are drawn on the two
    -- linked floors (visibility keys off setFloor + fromFloor) so the pair can
    -- be aligned from either floor.
    local up = AnchorBox(upMark)
    up.name, up.floor = string.format(CH.L["ST_DEFAULT_STAIRS_UP"], upper), lowerFloor
    up.setFloor, up.fromFloor = upper, lowerFloor
    local down = AnchorBox(downMark)
    down.name, down.floor = string.format(CH.L["ST_DEFAULT_STAIRS_DOWN"], lowerFloor), upper
    down.setFloor, down.fromFloor = lowerFloor, upper

    table.insert(h.zones, up)
    table.insert(h.zones, down)
    h.owner = CH.currentHouseOwner or h.owner

    FP.ClosePanel(true)
    CH.TouchHouse(CH.currentHouseGUID)
    CH.Print(CH.L["ST_STAIRS_ADDED_X"], lowerFloor, upper)
end

do
    local f = wiz.frame
    local floors = Stepper(f, -44, function()
        lowerFloor = math.max(1, lowerFloor - 1)
        RefreshWizard()
    end, function()
        lowerFloor = math.min(HouseFloorCount() - 1, lowerFloor + 1)
        RefreshWizard()
    end)
    -- Mark top, on a high step, is the one that sends you up and Mark bottom,
    -- on a low step, the one down. Each only fires from its own floor, so
    -- walking up you pass the down mark quietly and switch near the top, and
    -- the same the other way. The other way round, the second mark you walk
    -- over sends you straight back.
    local upState = MarkRow(f, -76, "ST_MARK_TOP", function(spot)
        upMark = spot
        RefreshWizard()
    end)
    local downState = MarkRow(f, -108, "ST_MARK_BOTTOM", function(spot)
        downMark = spot
        RefreshWizard()
    end)
    Hint(f, -146, "ST_WIZARD_HINT")
    local _, save = FP.PanelFooter(f, "ST_SAVE_STAIRS", SaveStairs)

    RefreshWizard = function()
        floors:SetText(string.format(CH.L["ST_CONNECTING_X"], lowerFloor, lowerFloor + 1))
        upState:SetText(Ready(upMark))
        downState:SetText(Ready(downMark))
        save:SetEnabled(upMark ~= nil and downMark ~= nil)
    end
end

function CH.OpenStairsWizard()
    local h = OwnHouseWithFloors("ST_ONLY_OWN_HOUSE_STAIRS")
    if not h or not OnOwnMap(CH.OpenStairsWizard) then
        return
    end
    upMark, downMark = nil, nil
    -- A staircase needs two floors, so it starts no higher than one under the top.
    lowerFloor = math.max(1, math.min(CH.MapFloor(), (h.floorCount or 2) - 1))
    RefreshWizard()
    FP.OpenPanel(wiz)
end

-- ── Floor pin (single "go to floor N" anchor) ────────────────────────
-- A simpler one-shot anchor than a staircase: stand somewhere, pick a floor, and
-- stepping there sets that floor. The works-from selector scopes it to a single
-- starting floor, by default the one you're on. That's just a stair landing
-- without the mate, so it rides the same fromFloor field the sharing blob
-- already carries. Set to any floor instead, it fires from wherever you are,
-- handy for a lift, a balcoy drop, or any spot the stair pair can't cover, but
-- keep those from sitting directly above or below each other, or they'll fight
-- over the floor.

local markerFloor = 1
local markerFrom -- nil = fires from any floor
local markerSpot -- captured { x, y, mapID }

local pin = { frame = FP.MakePanel("ST_TITLE_FLOOR_MARKER"), check = StillHome }
local RefreshPin -- set once the rows exist

local function SavePin()
    if not markerSpot then
        return
    end
    if not CH.currentHouseGUID then
        CH.Print(CH.L["ST_STAND_IN_HOUSE_MARKER"])
        return
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    if markerFloor > (h.floorCount or 1) then
        h.floorCount = markerFloor
    end

    -- Works from any floor: an absolute anchor with no fromFloor, walk onto it
    -- from anywhere and it sets you to this floor. Scoped to one starting floor:
    -- a lone stair landing, living on that floor and firing only from it.
    local z = AnchorBox(markerSpot)
    z.name = string.format(CH.L["ST_DEFAULT_TO_FLOOR_X"], markerFloor)
    z.setFloor = markerFloor
    z.floor = markerFrom or markerFloor
    z.fromFloor = markerFrom

    table.insert(h.zones, z)
    h.owner = CH.currentHouseOwner or h.owner

    FP.ClosePanel(true)
    CH.TouchHouse(CH.currentHouseGUID)
    CH.Print(CH.L["ST_MARKER_ADDED_X"], markerFloor)
end

-- Where a pin sends you and which floor it works from, the same two rows in
-- the Floor pin panel and the stair editor. Stepping the works-from row below
-- floor 1 lands on "any floor" (nil), so the whole range sits on one pair of
-- buttons. get() and set(from, to) reach the panel's own two values, and
-- count() is how many floors there are.
local function FloorRows(f, y, get, set, count, refresh)
    local fromLabel = Stepper(f, y, function()
        local from, to = get()
        if from then
            set(from > 1 and from - 1 or nil, to)
            refresh()
        end
    end, function()
        local from, to = get()
        set(math.min(count(), (from or 0) + 1), to)
        refresh()
    end)
    local toLabel = Stepper(f, y - 32, function()
        local from, to = get()
        set(from, math.max(1, to - 1))
        refresh()
    end, function()
        local from, to = get()
        set(from, math.min(count(), to + 1))
        refresh()
    end)
    -- Firing only from the floor it already sends to would never do anyhing,
    -- so the caller keeps Save off for that.
    return function()
        local from, to = get()
        fromLabel:SetText(from and string.format(CH.L["ST_WORKS_FROM_X"], from) or CH.L["ST_WORKS_FROM_ANY"])
        toLabel:SetText(string.format(CH.L["ST_SENDS_TO_FLOOR_X"], to))
        return from ~= to
    end
end

do
    local f = pin.frame
    local rows
    local spotState = MarkRow(f, -108, "ST_MARK_THIS_SPOT", function(spot)
        markerSpot = spot
        RefreshPin()
    end)
    Hint(f, -146, "ST_MARKER_HINT")
    local _, save = FP.PanelFooter(f, "ST_SAVE_MARKER", SavePin)

    RefreshPin = function()
        local differ = rows()
        spotState:SetText(Ready(markerSpot))
        save:SetEnabled(markerSpot ~= nil and differ)
    end
    rows = FloorRows(f, -44, function()
        return markerFrom, markerFloor
    end, function(from, to)
        markerFrom, markerFloor = from, to
    end, HouseFloorCount, RefreshPin)
end

function CH.OpenFloorMarkerWizard()
    local h = OwnHouseWithFloors("ST_ONLY_OWN_HOUSE_MARKER")
    if not h or not OnOwnMap(CH.OpenFloorMarkerWizard) then
        return
    end
    markerSpot = nil
    markerFloor = math.max(1, math.min(CH.MapFloor(), h.floorCount or 1))
    -- Scoped to the floor you're on by default. Save stays off until the
    -- destination differs, so picking it is the natural next click.
    markerFrom = markerFloor
    RefreshPin()
    FP.OpenPanel(pin)
end

-- ── Stair editor ─────────────────────────────────────────────────────
-- Stair anchors don't need the room editor's yapper, description, voice, colour
-- and secret controls. This is a stripped editor: name, which floor the anchor
-- works from, and where it sends you. The same two rows as the Floor pin
-- panel, so creating and editing look the same. A stair landing reads as
-- from its own floor to its mate's, an old-style pin as from any floor. The
-- floor plan's Edit button (via OpenRenameDialog) routes anchors here instead
-- of the room editor. Make it a room turns one back into a room.

local aeZone, aeGuid -- zone being edited and its house
local aeFrom -- floor it works from (nil = any floor)
local aeTo -- floor it sends you to

local anchor = { frame = FP.MakePanel("ST_TITLE_EDIT_STAIRS") }
local nameBox, RefreshAnchor

local function AeFloorCount()
    local h = aeGuid and ChamberlainDB.houses[aeGuid]
    return (h and h.floorCount) or 1
end

function anchor.check()
    local h = ChamberlainDB.houses[aeGuid]
    if aeGuid ~= FP.HouseGUID() or not (h and tIndexOf(h.zones, aeZone)) then
        FP.ClosePanel(true)
    end
end

-- The name as typed, or nil with a line in chat when there is none.
local function TypedName()
    local name = nameBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then
        CH.Print(CH.L["ST_ENTER_NAME_FIRST"])
        return
    end
    return name
end

local function SaveAnchor()
    local z, name = aeZone, TypedName()
    if not name then
        return
    end
    z.name = name
    z.setFloor = aeTo
    z.fromFloor = aeFrom
    z.floor = aeFrom or aeTo
    -- Old relative hops fold into the from/to form on save. The engine still
    -- reads floorDelta from old data and shared layouts, the editor just stops
    -- producing it.
    z.floorDelta = nil
    FP.ClosePanel(true)
    CH.TouchHouse(aeGuid)
end

-- Back to a room: the stair fields go and the box stays on the floor it
-- works from, and the room editor takes over for a shape and a size.
local function MakeRoom()
    local z, guid, name = aeZone, aeGuid, TypedName()
    if not name then
        return
    end
    z.name = name
    z.floor = aeFrom or aeTo
    z.setFloor, z.fromFloor, z.floorDelta = nil, nil, nil
    FP.ClosePanel(true)
    CH.TouchHouse(guid)
    CH.OpenRenameDialog(z, guid)
end

do
    local f = anchor.frame
    nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameBox:SetHeight(22)
    nameBox:SetPoint("TOPLEFT", PAD + 6, -38)
    nameBox:SetPoint("TOPRIGHT", -PAD, -38)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)
    nameBox:SetScript("OnEnterPressed", SaveAnchor)
    nameBox:SetScript("OnEscapePressed", function()
        FP.LeavePanel()
    end)
    f:SetScript("OnHide", function()
        nameBox:ClearFocus()
    end)

    local rows
    local _, save = FP.PanelFooter(f, "ST_SAVE", SaveAnchor)
    RefreshAnchor = function()
        -- Same rule as the Floor pin: sending to the floor it already works
        -- from would never do anything.
        save:SetEnabled(rows())
    end
    rows = FloorRows(f, -80, function()
        return aeFrom, aeTo
    end, function(from, to)
        aeFrom, aeTo = from, to
    end, AeFloorCount, RefreshAnchor)

    local roomBtn = CH.MakeButton(f, "ST_MAKE_ROOM", 150, 24)
    roomBtn:SetPoint("TOPLEFT", PAD, -154)
    CH.Tip(roomBtn, "ST_TT_MAKE_ROOM")
    roomBtn:SetScript("OnClick", MakeRoom)
end

function CH.OpenAnchorEditor(zone, houseGUID)
    houseGUID = houseGUID or CH.currentHouseGUID
    if zone == aeZone and FP.panel == anchor then
        return
    elseif FP.panel then
        FP.LeavePanel(function()
            CH.OpenAnchorEditor(zone, houseGUID)
        end)
        return
    end
    if not FP.win:IsShown() or FP.HouseGUID() ~= houseGUID then
        CH.OpenFloorPlan(houseGUID)
    end
    aeZone, aeGuid = zone, houseGUID
    -- Fold whatever shape the box has into the two rows. A relative hop reads as
    -- from its own floor to the neighbouring one, which can collapse to from ==
    -- to for a hop already clamped at the top or bottom of the house (a box that
    -- fires as a no-op today, and the disabled Save surfaces that).
    if zone.floorDelta then
        aeFrom = zone.floor or 1
        aeTo = math.max(1, math.min(AeFloorCount(), aeFrom + zone.floorDelta))
    else
        aeFrom = zone.fromFloor
        aeTo = zone.setFloor or zone.floor or 1
    end
    nameBox:SetText(zone.name or "")
    RefreshAnchor()
    CH.fpViewedFloor = zone.floor or 1
    FP.OpenPanel(anchor, zone)
    nameBox:SetFocus()
    nameBox:HighlightText()
end
