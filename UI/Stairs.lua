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
-- single point and grown into a ~4 yd box so the 0.25s ticker reliably catches it.
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
    CH.SkinWindow(intro, "|cffFFD700Chamberlain|r  " .. CH.L["ST_TITLE_FLOORS"])

    local body = intro:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 18, -38)
    body:SetPoint("TOPRIGHT", -18, -38)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    body:SetText(CH.L["ST_INTRO_BODY"])

    local setup = CH.MakeButton(intro, CH.L["ST_SET_UP_STAIRS"], 130, 24)
    setup:SetPoint("BOTTOMRIGHT", intro, "BOTTOM", -4, 12)
    setup:SetScript("OnClick", function()
        intro:Hide()
        CH.OpenStairsWizard()
    end)

    local later = CH.MakeButton(intro, CH.L["ST_LATER"], 90, 24)
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
    CH.SkinWindow(wiz, "|cffFFD700Chamberlain|r  " .. CH.L["ST_TITLE_ADD_STAIRS"])

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
    local botBtn = CH.MakeButton(wiz, CH.L["ST_MARK_BOTTOM"], 150, 24)
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
    local topBtn = CH.MakeButton(wiz, CH.L["ST_MARK_TOP"], 150, 24)
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

    local save = CH.MakeButton(wiz, CH.L["ST_SAVE_STAIRS"], 130, 24)
    save:SetPoint("BOTTOMRIGHT", wiz, "BOTTOM", -4, 12)
    wiz.save = save
    save:SetScript("OnClick", CH.SaveStairs)

    local cancel = CH.MakeButton(wiz, CH.L["ST_CANCEL"], 90, 24)
    cancel:SetPoint("BOTTOMLEFT", wiz, "BOTTOM", 4, 12)
    cancel:SetScript("OnClick", function()
        wiz:Hide()
    end)

    -- Grow the window to fit however much hint text there is, leaving room for the
    -- buttons below it. Recomputed on show, when layout is fully realized.
    local function FitHeight()
        local hh = hint:GetStringHeight()
        if hh and hh > 1 then
            wiz:SetHeight(HINT_TOP + hh + 52)
        end
    end
    wiz:SetScript("OnShow", FitHeight)
    FitHeight()

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
    h.updatedAt = GetServerTime()

    if wiz then
        wiz:Hide()
    end
    if CH.RebuildFloorPlan then
        CH.RebuildFloorPlan()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
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
-- stepping there always sets that floor (from anywhere). Useful for a lift, a
-- balcoy drop, or any spot the stair pair can't cover. Keep these from sitting
-- directly above or below each other, or they'll fight over the floor.

local marker
local markerFloor = 1
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
    CH.SkinWindow(marker, "|cffFFD700Chamberlain|r  " .. CH.L["ST_TITLE_FLOOR_MARKER"])

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

    local spotBtn = CH.MakeButton(marker, CH.L["ST_MARK_THIS_SPOT"], 150, 24)
    spotBtn:SetPoint("TOPLEFT", 18, -84)
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

    local hint = marker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, -120)
    hint:SetPoint("TOPRIGHT", -18, -120)
    hint:SetJustifyH("LEFT")
    hint:SetText(CH.L["ST_MARKER_HINT"])

    local save = CH.MakeButton(marker, CH.L["ST_SAVE_MARKER"], 130, 24)
    save:SetPoint("BOTTOMRIGHT", marker, "BOTTOM", -4, 12)
    marker.save = save
    save:SetScript("OnClick", CH.SaveFloorMarker)

    local cancel = CH.MakeButton(marker, CH.L["ST_CANCEL"], 90, 24)
    cancel:SetPoint("BOTTOMLEFT", marker, "BOTTOM", 4, 12)
    cancel:SetScript("OnClick", function()
        marker:Hide()
    end)

    return marker
end

function CH.RefreshFloorMarker()
    if not marker then
        return
    end
    marker.floorLabel:SetText(string.format(CH.L["ST_SENDS_TO_FLOOR_X"], markerFloor))
    marker.spotState:SetText(markerSpot and CH.L["ST_READY"] or CH.L["ST_NOT_SET"])
    marker.save:SetEnabled(markerSpot ~= nil)
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

    -- Absolute anchor with no fromFloor: fires from any floor. Walk onto it from
    -- anywhere and it sets you to this floor.
    local z = AnchorBox(markerSpot)
    z.name = string.format(CH.L["ST_DEFAULT_TO_FLOOR_X"], markerFloor)
    z.floor, z.setFloor = markerFloor, markerFloor

    table.insert(h.zones, z)
    h.owner = CH.currentHouseOwner or h.owner
    h.updatedAt = GetServerTime()

    if marker then
        marker:Hide()
    end
    if CH.RebuildFloorPlan then
        CH.RebuildFloorPlan()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
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
    BuildMarker():Show()
    CH.RefreshFloorMarker()
end

-- ── Anchor editor (minimal) ──────────────────────────────────────────
-- Stair anchors don't need the room dialog's yapper, description, voice, colour
-- and secret controls. This is a stripped editor: name, which floor it sits on,
-- and what it does. The floor plan's Edit button (via OpenRenameDialog) routes
-- anchors here instead of the full room dialog.

local editor
local aeZone, aeGuid -- zone being edited and its house
local aeFloor -- floor it sits on
local aeSetFloor, aeFloorDelta -- current behaviour
local aeFromFloor -- live pairing: the paired floor while it acts as a staircase (nil = one-way)
local aeOrigSet, aeOrigFrom, aeOrigFloor -- the staircase's setFloor/fromFloor/floor at open, to restore it

local function AnchorEditorHouse()
    return aeGuid and ChamberlainDB.houses[aeGuid]
end

local function AeLinkText()
    -- A staircase landing links its own floor and its paired floor. Show that link
    -- rather than a one-way "go to floor N", which for a landing would just restate
    -- the floor it sits on. Choosing any one-way behaviour clears aeFromFloor, so
    -- this falls through to the plain text below.
    if aeFromFloor and aeSetFloor then
        local a = math.min(aeFromFloor, aeSetFloor)
        local b = math.max(aeFromFloor, aeSetFloor)
        return string.format(CH.L["ST_LINK_STAIRS_X"], a, b)
    end
    if aeSetFloor then
        return string.format(CH.L["ST_GO_TO_FLOOR_X"], aeSetFloor)
    elseif aeFloorDelta == 1 then
        return CH.L["ST_UP_ONE_FLOOR"]
    elseif aeFloorDelta == -1 then
        return CH.L["ST_DOWN_ONE_FLOOR"]
    end
    return CH.L["ST_NOT_STAIRS"]
end

local function RefreshAnchorEditor()
    if not editor then
        return
    end
    editor.floorLabel:SetText(string.format(CH.L["ST_ON_FLOOR_X"], aeFloor or 1))
    editor.linkBtn:SetText(AeLinkText())
    -- A paired staircase landing sits on a floor fixed by the staircase, so lock the
    -- floor selector while it's paired. Convert it to a one-way anchor to move it.
    local locked = aeFromFloor ~= nil
    if editor.fMore then
        editor.fMore:SetEnabled(not locked)
    end
    if editor.fLess then
        editor.fLess:SetEnabled(not locked)
    end
end

local function BuildAnchorEditor()
    if editor then
        return editor
    end
    editor = CreateFrame("Frame", "ChamberlainAnchorEditor", UIParent, "BackdropTemplate")
    editor:SetSize(340, 196)
    -- DIALOG (not FULLSCREEN_DIALOG) so the "Does" context menu, which renders just
    -- above DIALOG, sits in front of this window instead of behind it. Matches the
    -- room dialog, whose MenuUtil dropdowns work the same way. SetToplevel still
    -- lifts it above the floor plan / room manager (also DIALOG) on show.
    editor:SetFrameStrata("DIALOG")
    editor:SetToplevel(true)
    editor:SetPoint("CENTER")
    CH.MakeDraggable(editor)
    CH.SkinWindow(editor, "|cffFFD700Chamberlain|r  " .. CH.L["ST_TITLE_EDIT_STAIRS"])

    local nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    nameBox:SetSize(250, 20)
    nameBox:SetPoint("TOP", editor, "TOP", 0, -38)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editor.nameBox = nameBox

    -- Floor selector
    local floorLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    floorLabel:SetPoint("TOPLEFT", 20, -76)
    editor.floorLabel = floorLabel
    local fMore = CH.MakeButton(editor, "+", 22, 20)
    local fLess = CH.MakeButton(editor, "-", 22, 20)
    editor.fMore, editor.fLess = fMore, fLess
    fMore:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -18, -74)
    fLess:SetPoint("RIGHT", fMore, "LEFT", -4, 0)
    fLess:SetScript("OnClick", function()
        aeFloor = math.max(1, (aeFloor or 1) - 1)
        RefreshAnchorEditor()
    end)
    fMore:SetScript("OnClick", function()
        local h = AnchorEditorHouse()
        aeFloor = math.min((h and h.floorCount) or 1, (aeFloor or 1) + 1)
        RefreshAnchorEditor()
    end)

    -- Behaviour dropdown
    local linkLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    linkLabel:SetPoint("TOPLEFT", 20, -108)
    linkLabel:SetText(CH.L["ST_DOES"])
    local linkBtn = CH.MakeButton(editor, CH.L["ST_NOT_STAIRS"], 150, 22)
    linkBtn:SetPoint("LEFT", linkLabel, "RIGHT", 10, 0)
    editor.linkBtn = linkBtn
    linkBtn:SetScript("OnClick", function(self)
        if not MenuUtil then
            return
        end
        local h = AnchorEditorHouse()
        local count = (h and h.floorCount) or 1
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(CH.L["ST_WHEN_STEPPED_ON"])
            -- Staircase pairing, offered only for landings that came from the stairs
            -- wizard (aeOrigFrom). Selecting it restores the link. Every one-way
            -- option below clears aeFromFloor, so the pairing is an explicit choice.
            if aeOrigFrom then
                -- The two floors the staircase links are its original setFloor and
                -- fromFloor, independent of the (possibly edited) "On floor".
                local lo = math.min(aeOrigSet or aeOrigFloor or 1, aeOrigFrom)
                local hi = math.max(aeOrigSet or aeOrigFloor or 1, aeOrigFrom)
                root:CreateRadio(string.format(CH.L["ST_LINK_STAIRS_X"], lo, hi), function()
                    return aeFromFloor ~= nil
                end, function()
                    -- Restore the original staircase: its floor, target, and pairing.
                    aeFloor = aeOrigFloor or aeFloor
                    aeSetFloor, aeFloorDelta, aeFromFloor = aeOrigSet, nil, aeOrigFrom
                    RefreshAnchorEditor()
                end)
            end
            root:CreateRadio(CH.L["ST_UP_ONE_FLOOR"], function()
                return aeFloorDelta == 1
            end, function()
                aeSetFloor, aeFloorDelta, aeFromFloor = nil, 1, nil
                RefreshAnchorEditor()
            end)
            root:CreateRadio(CH.L["ST_DOWN_ONE_FLOOR"], function()
                return aeFloorDelta == -1
            end, function()
                aeSetFloor, aeFloorDelta, aeFromFloor = nil, -1, nil
                RefreshAnchorEditor()
            end)
            for n = 1, count do
                root:CreateRadio(string.format(CH.L["ST_GO_TO_FLOOR_X"], n), function()
                    return aeSetFloor == n and not aeFromFloor
                end, function()
                    aeSetFloor, aeFloorDelta, aeFromFloor = n, nil, nil
                    RefreshAnchorEditor()
                end)
            end
        end)
    end)

    local save = CH.MakeButton(editor, CH.L["ST_SAVE"], 100, 24)
    save:SetPoint("BOTTOMRIGHT", editor, "BOTTOM", -4, 12)
    save:SetScript("OnClick", CH.SaveAnchorEdit)
    local cancel = CH.MakeButton(editor, CH.L["ST_CANCEL"], 100, 24)
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
    z.floor = aeFloor or 1
    z.setFloor = aeSetFloor
    z.floorDelta = aeFloorDelta
    -- aeFromFloor is the live pairing: set while it's a staircase, cleared the moment
    -- a one-way behaviour is chosen. Persist it straight through.
    z.fromFloor = aeFromFloor
    local h = AnchorEditorHouse()
    if h then
        h.updatedAt = GetServerTime()
    end
    editor:Hide()
    if CH.RebuildFloorPlan then
        CH.RebuildFloorPlan()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    if aeGuid then
        CH.QueueBroadcast(aeGuid)
    end
end

function CH.OpenAnchorEditor(zone, houseGUID)
    aeZone = zone
    aeGuid = houseGUID or CH.currentHouseGUID
    aeFloor = zone.floor or 1
    aeSetFloor = zone.setFloor
    aeFloorDelta = zone.floorDelta
    aeFromFloor = zone.fromFloor
    aeOrigSet, aeOrigFrom, aeOrigFloor = zone.setFloor, zone.fromFloor, zone.floor or 1
    BuildAnchorEditor()
    editor.nameBox:SetText(zone.name or "")
    RefreshAnchorEditor()
    editor:Show()
    editor.nameBox:SetFocus()
    editor.nameBox:HighlightText()
end
