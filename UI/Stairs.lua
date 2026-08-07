local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Stairs wizard + one-time floor explainer
-- ─────────────────────────────────────────────────────────────────────
-- There is no elevation API, so Chamberlain can't tell which floor a player is
-- on. The fix is to mark the staircases: a pair of small "anchor" zones, one at
-- the bottom and one at the top, each set to its floor. Walking onto one sets the
-- active floor (see Housing/Housing.lua). This wizard hides the words
-- "anchor / absolute / relative" and asks the player to mark their stairs.

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

-- ── Stairs wizard ────────────────────────────────────────────────────

local wiz
local lowerFloor = 1 -- the staircase connects lowerFloor <-> lowerFloor+1
local markBottom, markTop -- captured { x, y, mapID } for each landing

local function HouseFloorCount()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return (h and h.floorCount) or 1
end

-- Grow a window to fit however much hint text it carries, leaving room for the
-- buttons below it. Recomputed on show, when layout is fully realized.
local function FitToHint(frame, hint, hintTop)
    local function fit()
        local hh = hint:GetStringHeight()
        if hh and hh > 1 then
            frame:SetHeight(hintTop + hh + 52)
        end
    end
    frame:SetScript("OnShow", fit)
    fit()
end

local function BuildWizard()
    if wiz then
        return wiz
    end
    wiz = CreateFrame("Frame", "ChamberlainStairsWizard", UIParent, "BackdropTemplate")
    wiz:SetSize(380, 250)
    wiz:SetFrameStrata("FULLSCREEN_DIALOG")
    wiz:SetToplevel(true)
    wiz:SetPoint("CENTER")
    CH.MakeDraggable(wiz)
    CH.SkinWindow(wiz, "ST_TITLE_ADD_STAIRS", true)

    -- Floor selector: which two floors this staircase joins.
    local floorLabel = wiz:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    floorLabel:SetPoint("TOPLEFT", 18, -40)
    wiz.floorLabel = floorLabel

    local less = CH.MakeButton(wiz, "-", 22, 20)
    local more = CH.MakeButton(wiz, "+", 22, 20)
    more:SetPoint("TOPRIGHT", wiz, "TOPRIGHT", -18, -38)
    less:SetPoint("RIGHT", more, "LEFT", -4, 0)
    less:SetScript("OnClick", function()
        lowerFloor = math.max(1, lowerFloor - 1)
        CH.RefreshStairsWizard()
    end)
    more:SetScript("OnClick", function()
        lowerFloor = math.min(HouseFloorCount() - 1, lowerFloor + 1)
        CH.RefreshStairsWizard()
    end)

    -- Bottom-landing capture.
    local botBtn = CH.MakeButton(wiz, "ST_MARK_TOP", 150, 24)
    botBtn:SetPoint("TOPLEFT", 18, -88)
    wiz.botBtn = botBtn
    local botState = wiz:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    botState:SetPoint("LEFT", botBtn, "RIGHT", 10, 0)
    wiz.botState = botState
    botBtn:SetScript("OnClick", function()
        local x, y, mapID = CH.GetWorldPos()
        if not x then
            return
        end
        markBottom = { x = x, y = y, mapID = mapID }
        CH.RefreshStairsWizard()
    end)

    -- Top-landing capture.
    local topBtn = CH.MakeButton(wiz, "ST_MARK_BOTTOM", 150, 24)
    topBtn:SetPoint("TOPLEFT", 18, -124)
    wiz.topBtn = topBtn
    local topState = wiz:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    topState:SetPoint("LEFT", topBtn, "RIGHT", 10, 0)
    wiz.topState = topState
    topBtn:SetScript("OnClick", function()
        local x, y, mapID = CH.GetWorldPos()
        if not x then
            return
        end
        markTop = { x = x, y = y, mapID = mapID }
        CH.RefreshStairsWizard()
    end)

    local HINT_TOP = 160
    local hint = wiz:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, -HINT_TOP)
    hint:SetWidth(344) -- fixed width so the wrapped height is measurable
    hint:SetJustifyH("LEFT")
    hint:SetText(CH.L["ST_WIZARD_HINT"])

    local save = CH.MakeButton(wiz, "ST_SAVE_STAIRS", 130, 24)
    save:SetPoint("BOTTOMRIGHT", wiz, "BOTTOM", -4, 12)
    wiz.save = save
    save:SetScript("OnClick", CH.SaveStairs)

    local cancel = CH.MakeButton(wiz, "ST_CANCEL", 90, 24)
    cancel:SetPoint("BOTTOMLEFT", wiz, "BOTTOM", 4, 12)
    cancel:SetScript("OnClick", function()
        wiz:Hide()
    end)

    FitToHint(wiz, hint, HINT_TOP)

    return wiz
end

function CH.RefreshStairsWizard()
    if not wiz then
        return
    end
    local upper = lowerFloor + 1
    wiz.floorLabel:SetText(string.format(CH.L["ST_CONNECTING_X"], lowerFloor, upper))
    wiz.botState:SetText(markBottom and CH.L["ST_READY"] or CH.L["ST_NOT_SET"])
    wiz.topState:SetText(markTop and CH.L["ST_READY"] or CH.L["ST_NOT_SET"])
    wiz.save:SetEnabled(markBottom ~= nil and markTop ~= nil)
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

function CH.SaveStairs()
    if not markBottom or not markTop then
        return
    end
    if not CH.currentHouseGUID then
        CH.Print(CH.L["ST_STAND_IN_HOUSE_STAIRS"])
        return
    end
    if markBottom.mapID ~= markTop.mapID then
        CH.Print(CH.L["ST_DIFFERENT_MAPS"])
        return
    end
    local upper = lowerFloor + 1
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    if not h then
        h = { owner = CH.currentHouseOwner, zones = {}, floorCount = 1 }
        ChamberlainDB.houses[CH.currentHouseGUID] = h
    end
    -- The staircase can't connect to a floor that doesn't exist yet.
    if upper > (h.floorCount or 1) then
        h.floorCount = upper
    end

    -- A matched pair scoped to these two floors. Each landing lives on the floor
    -- you leave and is named for the floor it takes you to: the lower landing
    -- carries you up (lives on lowerFloor, sets upper), the upper one carries you
    -- down (lives on upper, sets lowerFloor). fromFloor keeps the pair inert on
    -- every other floor, so a spiral's stacked landings don't cross-fire. Both are
    -- drawn on the two linked floors (visibility keys off setFloor + fromFloor) so
    -- the pair can be aligned from either floor.
    local bottom = AnchorBox(markBottom)
    bottom.name, bottom.floor = string.format(CH.L["ST_DEFAULT_STAIRS_UP"], upper), lowerFloor
    bottom.setFloor, bottom.fromFloor = upper, lowerFloor
    local top = AnchorBox(markTop)
    top.name, top.floor = string.format(CH.L["ST_DEFAULT_STAIRS_DOWN"], lowerFloor), upper
    top.setFloor, top.fromFloor = lowerFloor, upper

    table.insert(h.zones, bottom)
    table.insert(h.zones, top)
    h.owner = CH.currentHouseOwner or h.owner

    if wiz then
        wiz:Hide()
    end
    CH.TouchHouse(CH.currentHouseGUID)
    CH.Print(CH.L["ST_STAIRS_ADDED_X"], lowerFloor, upper)
end

function CH.OpenStairsWizard()
    if not CH.isOwnHouse then
        CH.Print(CH.L["ST_ONLY_OWN_HOUSE_STAIRS"])
        return
    end
    -- A staircase needs two floors, so make sure there's an upper floor to reach.
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or (h.floorCount or 1) < 2 then
        CH.Print(CH.L["ST_ADD_SECOND_FLOOR_FIRST"])
        return
    end
    markBottom, markTop = nil, nil
    lowerFloor = math.min(CH.fpViewedFloor or CH.activeFloor or 1, (h.floorCount or 2) - 1)
    if lowerFloor < 1 then
        lowerFloor = 1
    end
    BuildWizard():Show()
    CH.RefreshStairsWizard()
end

-- ── Floor marker (single "go to floor N" anchor) ─────────────────────
-- A simpler one-shot anchor than a staircase: stand somewhere, pick a floor, and
-- stepping there sets that floor. The works-from selector scopes it to a single
-- starting floor, by default the one you're on. That's just a stair landing
-- without the mate, so it rides the same fromFloor field the sharing blob
-- already carries. Set to any floor instead, it fires from wherever you are,
-- handy for a lift, a balcoy drop, or any spot the stair pair can't cover, but
-- keep those from sitting directly above or below each other, or they'll fight
-- over the floor.

local marker
local markerFloor = 1
local markerFrom -- nil = fires from any floor
local markerSpot -- captured { x, y, mapID }

local function BuildMarker()
    if marker then
        return marker
    end
    marker = CreateFrame("Frame", "ChamberlainFloorMarker", UIParent, "BackdropTemplate")
    marker:SetSize(380, 210)
    marker:SetFrameStrata("FULLSCREEN_DIALOG")
    marker:SetToplevel(true)
    marker:SetPoint("CENTER")
    CH.MakeDraggable(marker)
    CH.SkinWindow(marker, "ST_TITLE_FLOOR_MARKER", true)

    local floorLabel = marker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    floorLabel:SetPoint("TOPLEFT", 18, -40)
    marker.floorLabel = floorLabel

    local less = CH.MakeButton(marker, "-", 22, 20)
    local more = CH.MakeButton(marker, "+", 22, 20)
    more:SetPoint("TOPRIGHT", marker, "TOPRIGHT", -18, -38)
    less:SetPoint("RIGHT", more, "LEFT", -4, 0)
    less:SetScript("OnClick", function()
        markerFloor = math.max(1, markerFloor - 1)
        CH.RefreshFloorMarker()
    end)
    more:SetScript("OnClick", function()
        markerFloor = math.min(HouseFloorCount(), markerFloor + 1)
        CH.RefreshFloorMarker()
    end)

    -- Works-from selector. Stepping below floor 1 lands on "any floor" (nil), so
    -- the whole range sits on one pair of buttons.
    local fromLabel = marker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fromLabel:SetPoint("TOPLEFT", 18, -72)
    marker.fromLabel = fromLabel

    local fLess = CH.MakeButton(marker, "-", 22, 20)
    local fMore = CH.MakeButton(marker, "+", 22, 20)
    fMore:SetPoint("TOPRIGHT", marker, "TOPRIGHT", -18, -70)
    fLess:SetPoint("RIGHT", fMore, "LEFT", -4, 0)
    fLess:SetScript("OnClick", function()
        if markerFrom then
            markerFrom = markerFrom > 1 and markerFrom - 1 or nil
            CH.RefreshFloorMarker()
        end
    end)
    fMore:SetScript("OnClick", function()
        markerFrom = math.min(HouseFloorCount(), (markerFrom or 0) + 1)
        CH.RefreshFloorMarker()
    end)

    local spotBtn = CH.MakeButton(marker, "ST_MARK_THIS_SPOT", 150, 24)
    spotBtn:SetPoint("TOPLEFT", 18, -108)
    local spotState = marker:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    spotState:SetPoint("LEFT", spotBtn, "RIGHT", 10, 0)
    marker.spotState = spotState
    spotBtn:SetScript("OnClick", function()
        local x, y, mapID = CH.GetWorldPos()
        if not x then
            return
        end
        markerSpot = { x = x, y = y, mapID = mapID }
        CH.RefreshFloorMarker()
    end)

    local HINT_TOP = 144
    local hint = marker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, -HINT_TOP)
    hint:SetWidth(344) -- fixed width so the wrapped height is measurable
    hint:SetJustifyH("LEFT")
    hint:SetText(CH.L["ST_MARKER_HINT"])

    local save = CH.MakeButton(marker, "ST_SAVE_MARKER", 130, 24)
    save:SetPoint("BOTTOMRIGHT", marker, "BOTTOM", -4, 12)
    marker.save = save
    save:SetScript("OnClick", CH.SaveFloorMarker)

    local cancel = CH.MakeButton(marker, "ST_CANCEL", 90, 24)
    cancel:SetPoint("BOTTOMLEFT", marker, "BOTTOM", 4, 12)
    cancel:SetScript("OnClick", function()
        marker:Hide()
    end)

    FitToHint(marker, hint, HINT_TOP)

    return marker
end

function CH.RefreshFloorMarker()
    if not marker then
        return
    end
    marker.floorLabel:SetText(string.format(CH.L["ST_SENDS_TO_FLOOR_X"], markerFloor))
    marker.fromLabel:SetText(
        markerFrom and string.format(CH.L["ST_WORKS_FROM_X"], markerFrom) or CH.L["ST_WORKS_FROM_ANY"]
    )
    marker.spotState:SetText(markerSpot and CH.L["ST_READY"] or CH.L["ST_NOT_SET"])
    -- Firing only from the floor it already sends to would never do anyhing, so
    -- block that combination. Both floors sit right above the button.
    marker.save:SetEnabled(markerSpot ~= nil and markerFrom ~= markerFloor)
end

function CH.SaveFloorMarker()
    if not markerSpot then
        return
    end
    if not CH.currentHouseGUID then
        CH.Print(CH.L["ST_STAND_IN_HOUSE_MARKER"])
        return
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    if not h then
        h = { owner = CH.currentHouseOwner, zones = {}, floorCount = 1 }
        ChamberlainDB.houses[CH.currentHouseGUID] = h
    end
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

    if marker then
        marker:Hide()
    end
    CH.TouchHouse(CH.currentHouseGUID)
    CH.Print(CH.L["ST_MARKER_ADDED_X"], markerFloor)
end

function CH.OpenFloorMarkerWizard()
    if not CH.isOwnHouse then
        CH.Print(CH.L["ST_ONLY_OWN_HOUSE_MARKER"])
        return
    end
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or (h.floorCount or 1) < 2 then
        CH.Print(CH.L["ST_ADD_SECOND_FLOOR_FIRST"])
        return
    end
    markerSpot = nil
    markerFloor = math.min(CH.fpViewedFloor or CH.activeFloor or 1, h.floorCount or 1)
    if markerFloor < 1 then
        markerFloor = 1
    end
    -- Scoped to the floor you're on by default. Save stays off until the
    -- destination differs, so picking it is the natural next click.
    markerFrom = markerFloor
    BuildMarker():Show()
    CH.RefreshFloorMarker()
end

-- ── Anchor editor (minimal) ──────────────────────────────────────────
-- Stair anchors don't need the room dialog's yapper, description, voice, colour
-- and secret controls. This is a stripped editor: name, which floor the anchor
-- works from, and where it sends you. The same two rows as the floor pin wizard,
-- so creating and editing speak one language. A stair landing reads as from its
-- own floor to its mate's, an old-style pin as from any floor. The floor plan's
-- Edit button (via OpenRenameDialog) routes anchors here instead of the full
-- room dialog.

local editor
local aeZone, aeGuid -- zone being edited and its house
local aeFrom -- floor it works from (nil = any floor)
local aeTo -- floor it sends you to

local function AeFloorCount()
    local h = aeGuid and ChamberlainDB.houses[aeGuid]
    return (h and h.floorCount) or 1
end

local function RefreshAnchorEditor()
    if not editor then
        return
    end
    editor.fromLabel:SetText(aeFrom and string.format(CH.L["ST_WORKS_FROM_X"], aeFrom) or CH.L["ST_WORKS_FROM_ANY"])
    editor.toLabel:SetText(string.format(CH.L["ST_SENDS_TO_FLOOR_X"], aeTo))
    -- Same rule as the wizard: sending to the floor it already works from would
    -- never do anything.
    editor.save:SetEnabled(aeFrom ~= aeTo)
end

local function BuildAnchorEditor()
    if editor then
        return editor
    end
    editor = CreateFrame("Frame", "ChamberlainAnchorEditor", UIParent, "BackdropTemplate")
    editor:SetSize(340, 196)
    -- DIALOG strata to match the room dialog. SetToplevel lifts it above the
    -- floor plan / room manager (also DIALOG) on show.
    editor:SetFrameStrata("DIALOG")
    editor:SetToplevel(true)
    editor:SetPoint("CENTER")
    CH.MakeDraggable(editor)
    CH.SkinWindow(editor, "ST_TITLE_EDIT_STAIRS", true)

    local nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    nameBox:SetSize(250, 20)
    nameBox:SetPoint("TOP", editor, "TOP", 0, -38)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editor.nameBox = nameBox

    -- Works-from selector, same shape as the wizard's: stepping below floor 1
    -- lands on "any floor" (nil).
    local fromLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fromLabel:SetPoint("TOPLEFT", 20, -76)
    editor.fromLabel = fromLabel
    local fMore = CH.MakeButton(editor, "+", 22, 20)
    local fLess = CH.MakeButton(editor, "-", 22, 20)
    fMore:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -18, -74)
    fLess:SetPoint("RIGHT", fMore, "LEFT", -4, 0)
    fLess:SetScript("OnClick", function()
        if aeFrom then
            aeFrom = aeFrom > 1 and aeFrom - 1 or nil
            RefreshAnchorEditor()
        end
    end)
    fMore:SetScript("OnClick", function()
        aeFrom = math.min(AeFloorCount(), (aeFrom or 0) + 1)
        RefreshAnchorEditor()
    end)

    -- Destination selector
    local toLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toLabel:SetPoint("TOPLEFT", 20, -108)
    editor.toLabel = toLabel
    local tMore = CH.MakeButton(editor, "+", 22, 20)
    local tLess = CH.MakeButton(editor, "-", 22, 20)
    tMore:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -18, -106)
    tLess:SetPoint("RIGHT", tMore, "LEFT", -4, 0)
    tLess:SetScript("OnClick", function()
        aeTo = math.max(1, aeTo - 1)
        RefreshAnchorEditor()
    end)
    tMore:SetScript("OnClick", function()
        aeTo = math.min(AeFloorCount(), aeTo + 1)
        RefreshAnchorEditor()
    end)

    local save = CH.MakeButton(editor, "ST_SAVE", 100, 24)
    save:SetPoint("BOTTOMRIGHT", editor, "BOTTOM", -4, 12)
    editor.save = save
    save:SetScript("OnClick", CH.SaveAnchorEdit)
    local cancel = CH.MakeButton(editor, "ST_CANCEL", 100, 24)
    cancel:SetPoint("BOTTOMLEFT", editor, "BOTTOM", 4, 12)
    cancel:SetScript("OnClick", function()
        editor:Hide()
    end)
    editor:SetScript("OnHide", function()
        nameBox:ClearFocus()
    end)

    return editor
end

function CH.SaveAnchorEdit()
    local z = aeZone
    if not z then
        return
    end
    local name = editor.nameBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then
        CH.Print(CH.L["ST_ENTER_NAME_FIRST"])
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
    editor:Hide()
    CH.TouchHouse(aeGuid)
end

function CH.OpenAnchorEditor(zone, houseGUID)
    aeZone = zone
    aeGuid = houseGUID or CH.currentHouseGUID
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
    BuildAnchorEditor()
    editor.nameBox:SetText(zone.name or "")
    RefreshAnchorEditor()
    editor:Show()
    editor.nameBox:SetFocus()
    editor.nameBox:HighlightText()
end
