local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: floor navigation and add/remove floor
-- ─────────────────────────────────────────────────────────────────────

local FP = CH.FP
local map = FP.map
local canvas = FP.canvas

-- Floor tabs, one small button per floor in the map's top right corner, with
-- + and - after them on your own house to add or remove the top floor. Tabs
-- are pooled since a house can gain floors while the map is open.
local SetViewedFloor -- defined below the buttons

local floorTabs = {}
local function FloorTab(n)
    local tab = floorTabs[n]
    if not tab then
        tab = CH.MakeButton(map, "", 22, 20)
        tab:SetText(tostring(n))
        tab:SetScript("OnClick", function()
            SetViewedFloor(n)
        end)
        floorTabs[n] = tab
    end
    return tab
end

local addFloorBtn = CH.MakeButton(map, "", 22, 20)
addFloorBtn:SetText("+")
CH.Tip(addFloorBtn, "FP_ADD_FLOOR")

local removeFloorBtn = CH.MakeButton(map, "", 22, 20)
removeFloorBtn:SetText("-")
CH.Tip(removeFloorBtn, "FP_TT_REMOVE_FLOOR")
removeFloorBtn:SetScript("OnClick", function()
    CH.RemoveTopFloor()
end)

-- Override: when you're browsing a floor you're not standing on, this tells
-- Chamberlain you've actually moved there. Shown only when the viewed floor and
-- the active floor disagree.
local moveBtn = CH.MakeButton(map, "FP_MOVE_HERE", 110, 18)
moveBtn:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, -4)
moveBtn:Hide()
moveBtn:SetScript("OnClick", function()
    CH.SetActiveFloor(CH.fpViewedFloor)
end)
-- The canvas is mouse-enabled and clips its children, so a button over it has
-- to sit above it or the canvas swallows the clicks.
moveBtn:SetFrameLevel(FP.Level("buttons"))

-- A "show this kind of thing on the map" checkbox over a settings key. The
-- label is parented to the check so the pair shows and hides as one.
local function MakeMapCheck(key, labelKey, titleKey, bodyKey)
    local check = CreateFrame("CheckButton", nil, map, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.label:SetText(CH.L[labelKey])
    check:Hide()
    check:SetScript("OnClick", function(self)
        ChamberlainDB.settings[key] = self:GetChecked() and true or false
        FP.Build()
    end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(CH.L[titleKey], unpack(CH.COLORS.tipGold))
        GameTooltip:AddLine(CH.L[bodyKey], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return check
end

-- Bannerless rooms, the sound spots, pile up over the real rooms on a map that
-- uses a lot of them. Stairs are placed from the build rail where you stand, so
-- the only stair control here is box or icon. Both sit on the row
-- under the map and persist.
local spotsCheck = MakeMapCheck("showSpotsOnMap", "FP_SHOW_SPOTS", "FP_SHOW_SPOTS_TT_TITLE", "FP_SHOW_SPOTS_TT_BODY")
spotsCheck:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 6, 6)
spotsCheck.label:SetPoint("LEFT", spotsCheck, "RIGHT", 2, 0)

local stairsCheck =
    MakeMapCheck("showStairsOnMap", "FP_SHOW_STAIRS", "FP_SHOW_STAIRS_TT_TITLE", "FP_SHOW_STAIRS_TT_BODY")
stairsCheck.label:SetPoint("LEFT", stairsCheck, "RIGHT", 2, 0)

-- One line of a sound menu, the whole house when floor is nil. What is set
-- shows in gold after the label, so the menu reads as an overview before
-- anything is opened. An ambience line opens the sound list as a submenu.
local function AddAmbienceEntry(root, guid, label, floor)
    local function get()
        return CH.GetHouseSound(guid, "ambience", floor)
    end
    local picked = CH.AMBIENCE[get()]
    if picked then
        label = label .. "  |cffFFD700" .. CH.L[picked.key] .. "|r"
    end
    CH.FillAmbienceMenu(root:CreateButton(label), get, function(index)
        CH.SetHouseSound(guid, "ambience", floor, index)
    end)
end

-- A music line opens the picker since there are too many tracks for a menu,
-- and so does the arrival sound. forSounds as in CH.OpenMusicPicker.
local function AddPickerEntry(root, guid, label, kind, floor, forSounds)
    local id = CH.GetHouseSound(guid, kind, floor)
    if id then
        label = label .. "  |cffFFD700" .. CH.SoundName(id, true) .. "|r"
    end
    root:CreateButton(label, function()
        CH.OpenMusicPicker(id, function(picked)
            CH.SetHouseSound(guid, kind, floor, picked)
        end, ChamberlainDB.houses[guid], forSounds)
    end)
end

local function AddMusicEntry(root, guid, label, floor)
    AddPickerEntry(root, guid, label, "music", floor)
end

local function AddArrivalEntry(root, guid, label)
    AddPickerEntry(root, guid, label, "arrival", nil, "arrival")
end

-- A button on the row under the map whose menu lists the whole house and then
-- each floor, own house only. The button's own label never changes. houseOnly
-- is for a sound that has no floors.
local function MakeSoundButton(labelKey, tipKey, addEntry, onClose, houseOnly)
    local btn = CH.MakeMenuButton(map, 72, labelKey, function() end, function(root)
        local guid = CH.currentHouseGUID
        addEntry(root, guid, CH.L["FP_AMBIENCE_HOUSE"])
        -- one floor is the whole house, no point offering it twice
        local count = FP.CurrentHouse().floorCount or 1
        if count == 1 or houseOnly then
            return
        end
        for floor = 1, count do
            addEntry(root, guid, string.format(CH.L["FP_AMBIENCE_FLOOR_X"], floor), floor)
        end
    end, onClose)
    btn:Hide()
    CH.Tip(btn, tipKey)
    return btn
end

local arrivalBtn = MakeSoundButton("FP_ARRIVAL", "FP_TT_ARRIVAL", AddArrivalEntry, nil, true)
arrivalBtn:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -10, 7)
local musicBtn = MakeSoundButton("FP_MUSIC", "FP_TT_MUSIC", AddMusicEntry)
musicBtn:SetPoint("RIGHT", arrivalBtn, "LEFT", -4, 0)
local ambienceBtn = MakeSoundButton("FP_AMBIENCE", "FP_TT_AMBIENCE", AddAmbienceEntry, CH.StopAmbiencePreview)
ambienceBtn:SetPoint("RIGHT", musicBtn, "LEFT", -4, 0)

local soundsLabel = map:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
soundsLabel:SetPoint("RIGHT", ambienceBtn, "LEFT", -8, 0)
soundsLabel:SetText(CH.L["FP_SOUNDS"])
soundsLabel:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local function HasSpots(h)
    for _, zone in ipairs(h.zones) do
        if zone.noBanner and FP.ZoneVisible(zone) then
            return true
        end
    end
end

SetViewedFloor = function(n)
    local h = FP.CurrentHouse()
    local count = (h and h.floorCount) or 1
    CH.fpViewedFloor = math.max(1, math.min(count, n))
    FP.Build()
end

addFloorBtn:SetScript("OnClick", function()
    local h = FP.CurrentHouse()
    if not h or not FP.CanEdit() then
        return
    end
    h.floorCount = (h.floorCount or 1) + 1
    h.updatedAt = GetServerTime()
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end -- reveal the HUD's Add stairs button
    if CH.MaybeShowFloorIntro then
        CH.MaybeShowFloorIntro()
    end
    SetViewedFloor(h.floorCount) -- jump to the new top floor
end)

-- Actually delete the top floor: every zone on it, plus any stair anchor that
-- links to it (the anchor's other landing sits a floor below and would otherwise
-- dangle). Floors below keep their numbers, so nothing has to be renumbered.
local DoRemoveTopFloor -- forward declaration; the confirm dialog calls it

-- Confirm dialog for removing a populated top floor. Custom-skinned to match the
-- rest of the addon rather than a Blizzard StaticPopup.
local removeConfirm
local function ShowRemoveConfirm(msg)
    if not removeConfirm then
        removeConfirm = CreateFrame("Frame", "ChamberlainRemoveFloorConfirm", UIParent, "BackdropTemplate")
        removeConfirm:SetSize(380, 200)
        removeConfirm:SetFrameStrata("FULLSCREEN_DIALOG")
        removeConfirm:SetToplevel(true)
        removeConfirm:SetPoint("CENTER")
        CH.MakeDraggable(removeConfirm)
        CH.SkinWindow(removeConfirm, "FP_REMOVE_FLOOR_TITLE", true)
        local body = removeConfirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", 18, -38)
        body:SetPoint("TOPRIGHT", -18, -38)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(3)
        removeConfirm.body = body
        local yes = CH.MakeButton(removeConfirm, "FP_REMOVE_ANYWAY", 130, 24)
        yes:SetPoint("BOTTOMRIGHT", removeConfirm, "BOTTOM", -4, 12)
        yes:SetScript("OnClick", function()
            removeConfirm:Hide()
            DoRemoveTopFloor()
        end)
        local no = CH.MakeButton(removeConfirm, "FP_CANCEL", 90, 24)
        no:SetPoint("BOTTOMLEFT", removeConfirm, "BOTTOM", 4, 12)
        no:SetScript("OnClick", function()
            removeConfirm:Hide()
        end)
    end
    removeConfirm.body:SetText(msg)
    removeConfirm:Show()
end

DoRemoveTopFloor = function()
    local h = FP.CurrentHouse()
    if not h or not FP.CanEdit() then
        return
    end
    local count = h.floorCount or 1
    if count <= 1 then
        return
    end
    for i = #h.zones, 1, -1 do
        local z = h.zones[i]
        if (z.floor or 1) == count or z.setFloor == count or z.fromFloor == count then
            local removed = table.remove(h.zones, i)
            CH.DropZoneStats(h, removed and removed.name)
        end
    end
    CH.StoreHouseSound(h, "ambience", count, nil)
    CH.StoreHouseSound(h, "music", count, nil)
    h.floorCount = count - 1
    h.updatedAt = GetServerTime()
    if (CH.activeFloor or 1) > h.floorCount and CH.SetActiveFloor then
        CH.SetActiveFloor(h.floorCount)
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end
    if CH.RefreshRoomList then
        CH.RefreshRoomList()
    end
    SetViewedFloor(math.min(CH.fpViewedFloor, h.floorCount))
    CH.Print(CH.L["FP_REMOVED_FLOOR_X"], count)
end

-- Entry from the Remove floor button. Removes only the top floor. An empty one
-- goes quietly, a populated one asks first.
function CH.RemoveTopFloor()
    local h = FP.CurrentHouse()
    if not h or not FP.CanEdit() then
        return
    end
    local count = h.floorCount or 1
    if count <= 1 then
        return
    end -- can't remove the only floor

    local onTop = 0
    for _, z in ipairs(h.zones or {}) do
        if (z.floor or 1) == count then
            onTop = onTop + 1
        end
    end

    if onTop > 0 then
        local fmt = onTop == 1 and CH.L["FP_REMOVE_CONFIRM_ONE_X"] or CH.L["FP_REMOVE_CONFIRM_MANY_X"]
        ShowRemoveConfirm(string.format(fmt, count, onTop, count - 1, count))
    else
        DoRemoveTopFloor()
    end
end

-- Clamps the viewed floor and lays out the tabs and the owner's controls for
-- a build pass. Returns floorCount so the build doesn't recount. Called from
-- FP.Build.
function FP.RefreshFloorControls(h)
    local floorCount = (h and h.floorCount) or 1
    if CH.fpViewedFloor > floorCount then
        CH.fpViewedFloor = floorCount
    end
    if CH.fpViewedFloor < 1 then
        CH.fpViewedFloor = 1
    end
    local tools = FP.CanEdit() and h ~= nil

    -- Right to left from the corner: -, +, then the tabs from the top floor down.
    local row = {}
    local canRemove = tools and floorCount > 1
    if canRemove then
        row[#row + 1] = removeFloorBtn
    end
    removeFloorBtn:SetShown(canRemove)
    if tools then
        row[#row + 1] = addFloorBtn
    end
    addFloorBtn:SetShown(tools)
    for n, tab in pairs(floorTabs) do
        tab:SetShown(floorCount > 1 and n <= floorCount)
    end
    if floorCount > 1 then
        for n = floorCount, 1, -1 do
            local tab = FloorTab(n)
            CH.SetButtonActive(tab, n == CH.fpViewedFloor)
            row[#row + 1] = tab
        end
    end
    for i, b in ipairs(row) do
        b:ClearAllPoints()
        if i == 1 then
            b:SetPoint("TOPRIGHT", map, "TOPRIGHT", -10, -7)
        else
            b:SetPoint("RIGHT", row[i - 1], "LEFT", -2, 0)
        end
    end

    -- Offer the override only while browsing a floor you're not standing on,
    -- in the house you're standing in.
    if floorCount > 1 and not FP.viewGUID and CH.fpViewedFloor ~= (CH.activeFloor or 1) then
        moveBtn:SetText(string.format(CH.L["FP_MOVE_TO_FLOOR_X"], CH.fpViewedFloor))
        moveBtn:Show()
    else
        moveBtn:Hide()
    end

    ambienceBtn:SetShown(tools)
    musicBtn:SetShown(tools)
    arrivalBtn:SetShown(tools)
    soundsLabel:SetShown(tools)

    local spots = h ~= nil and h.zones ~= nil and HasSpots(h)
    spotsCheck:SetShown(spots)
    spotsCheck:SetChecked(ChamberlainDB.settings.showSpotsOnMap)
    -- Show stairs only matters once there's a second floor to have stairs to.
    stairsCheck:SetShown(floorCount > 1)
    stairsCheck:SetChecked(ChamberlainDB.settings.showStairsOnMap)
    stairsCheck:ClearAllPoints()
    if spots then
        stairsCheck:SetPoint("LEFT", spotsCheck.label, "RIGHT", 10, 0)
    else
        stairsCheck:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 6, 6)
    end
    return floorCount
end

-- Called from Housing when the player's active floor changes (took the stairs):
-- snap the viewed floor to follow them, so the map shows where they now are.
function CH.OnActiveFloorChanged()
    -- the bar's header names the floor
    if CH.hud:IsShown() then
        CH.RefreshHUDMode()
    end
    -- your stairs say nothing about the floors of a house picked in the Rooms window
    if FP.viewGUID then
        return
    end
    CH.fpViewedFloor = CH.activeFloor or 1
    if FP.win:IsShown() then
        FP.Build()
    end
end
