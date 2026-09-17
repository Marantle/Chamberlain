local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: floor navigation and add/remove floor
-- ─────────────────────────────────────────────────────────────────────

local FP = CH.FP
local fp = FP.win
local canvas = FP.canvas

-- Floor navigation row, top-right of the window. Hidden on single-floor houses.
local floorHeader = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
floorHeader:SetPoint("TOPRIGHT", fp, "TOPRIGHT", -62, -27)
floorHeader:SetTextColor(0.85, 0.78, 0.55, 1)

local floorUp = CH.MakeButton(fp, "+", 20, 18)
local floorDown = CH.MakeButton(fp, "-", 20, 18)
floorUp:SetPoint("RIGHT", fp, "TOPRIGHT", -10, -36)
floorDown:SetPoint("RIGHT", floorUp, "LEFT", -2, 0)
floorHeader:SetPoint("RIGHT", floorDown, "LEFT", -6, 0)

-- Override: when you're browsing a floor you're not standing on, this tells
-- Chamberlain you've actually moved there. Shown only when the viewed floor and
-- the active floor disagree.
local moveBtn = CH.MakeButton(fp, "FP_MOVE_HERE", 110, 18)
moveBtn:SetPoint("TOPRIGHT", floorUp, "BOTTOMRIGHT", 0, -4)
moveBtn:Hide()
moveBtn:SetScript("OnClick", function()
    CH.SetActiveFloor(CH.fpViewedFloor)
end)

-- These three sit over the canvas's top-right corner, which is mouse-enabled and
-- clips its children. Without lifting them above the canvas (as resetBtn does),
-- the canvas swallows their clicks even though they draw on top. moveBtn sits
-- fully inside the canvas region. The +/- buttons overlap its top edge.
floorUp:SetFrameLevel(canvas:GetFrameLevel() + 20)
floorDown:SetFrameLevel(canvas:GetFrameLevel() + 20)
moveBtn:SetFrameLevel(canvas:GetFrameLevel() + 20)

-- Floor / stair management lives at the bottom-left, own house only.
local addFloorBtn = CH.MakeButton(fp, "FP_ADD_FLOOR", 76, 22)
addFloorBtn:SetPoint("BOTTOMLEFT", fp, "BOTTOMLEFT", 10, 10)
addFloorBtn:Hide()

local removeFloorBtn = CH.MakeButton(fp, "FP_REMOVE_FLOOR", 86, 22)
removeFloorBtn:SetPoint("LEFT", addFloorBtn, "RIGHT", 4, 0)
removeFloorBtn:Hide()
removeFloorBtn:SetScript("OnClick", function()
    if CH.RemoveTopFloor then
        CH.RemoveTopFloor()
    end
end)

-- Stairs are placed from the HUD (where you stand); the floor plan only manages
-- structure (floors) and the map view, so the only stair control here is whether
-- they're drawn. Checked by default, and the setting persists.
-- A "show this kind of thing on the map" checkbox over a settings key. The
-- label is parented to the check so the pair shows and hides as one.
local function MakeMapCheck(key, labelKey, titleKey, bodyKey)
    local check = CreateFrame("CheckButton", nil, fp, "UICheckButtonTemplate")
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

local stairsCheck =
    MakeMapCheck("showStairsOnMap", "FP_SHOW_STAIRS", "FP_SHOW_STAIRS_TT_TITLE", "FP_SHOW_STAIRS_TT_BODY")
stairsCheck:SetPoint("LEFT", removeFloorBtn, "RIGHT", 16, 0)
stairsCheck.label:SetPoint("LEFT", stairsCheck, "RIGHT", 2, 0)

-- Bannerless rooms, the sound spots. They pile up over the real rooms on a map
-- that uses a lot of them. The bottom row is full on a multi-floor house so
-- this one sits in the map's corner, label to its left.
local spotsCheck = MakeMapCheck("showSpotsOnMap", "FP_SHOW_SPOTS", "FP_SHOW_SPOTS_TT_TITLE", "FP_SHOW_SPOTS_TT_BODY")
spotsCheck:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -2, 2)
spotsCheck:SetFrameLevel(canvas:GetFrameLevel() + 20)
spotsCheck.label:SetPoint("RIGHT", spotsCheck, "LEFT", -2, 0)

-- One line of the ambience menu, the whole house when floor is nil. What is
-- set shows in gold after the label, so the menu reads as an overview before
-- anything is opened.
local function AddAmbienceEntry(root, guid, label, floor)
    local function get()
        return CH.GetHouseAmbience(guid, floor)
    end
    local picked = CH.AMBIENCE[get()]
    if picked then
        label = label .. "  |cffFFD700" .. CH.L[picked.key] .. "|r"
    end
    CH.FillAmbienceMenu(root:CreateButton(label), get, function(index)
        CH.SetHouseAmbience(guid, floor, index)
    end)
end

-- Background sound for the whole house and for each floor, own house only. The
-- button's own label never changes.
local ambienceBtn = CH.MakeMenuButton(fp, 80, "FP_AMBIENCE", function() end, function(root)
    local guid = CH.currentHouseGUID
    AddAmbienceEntry(root, guid, CH.L["FP_AMBIENCE_HOUSE"])
    -- one floor is the whole house, no point offering it twice
    local count = FP.CurrentHouse().floorCount or 1
    if count == 1 then
        return
    end
    for floor = 1, count do
        AddAmbienceEntry(root, guid, string.format(CH.L["FP_AMBIENCE_FLOOR_X"], floor), floor)
    end
end)
ambienceBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 4, -4)
ambienceBtn:SetFrameLevel(canvas:GetFrameLevel() + 20)
ambienceBtn:Hide()
CH.Tip(ambienceBtn, "FP_TT_AMBIENCE")

local function HasSpots(h)
    for _, zone in ipairs(h.zones) do
        if zone.noBanner and FP.ZoneVisible(zone) then
            return true
        end
    end
end

local function SetViewedFloor(n)
    local h = FP.CurrentHouse()
    local count = (h and h.floorCount) or 1
    CH.fpViewedFloor = math.max(1, math.min(count, n))
    FP.selectedIdx = nil -- a selection on the old floor would no longer be visible
    FP.Build()
end

floorUp:SetScript("OnClick", function()
    SetViewedFloor(CH.fpViewedFloor + 1)
end)
floorDown:SetScript("OnClick", function()
    SetViewedFloor(CH.fpViewedFloor - 1)
end)

addFloorBtn:SetScript("OnClick", function()
    local h = FP.CurrentHouse()
    if not h or not CH.isOwnHouse then
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
    if not h or not CH.isOwnHouse then
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
    -- the setter rebuilds the map, no need for that on a house without sounds
    if h.ambience then
        CH.SetHouseAmbience(CH.currentHouseGUID, count, nil)
    end
    h.floorCount = count - 1
    h.updatedAt = GetServerTime()
    if (CH.activeFloor or 1) > h.floorCount and CH.SetActiveFloor then
        CH.SetActiveFloor(h.floorCount)
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    SetViewedFloor(math.min(CH.fpViewedFloor, h.floorCount))
    CH.Print(CH.L["FP_REMOVED_FLOOR_X"], count)
end

-- Entry from the Remove floor button. Removes only the top floor. An empty one
-- goes quietly, a populated one asks first.
function CH.RemoveTopFloor()
    local h = FP.CurrentHouse()
    if not h or not CH.isOwnHouse then
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

-- Drive the whole floor row for a build pass: clamp the viewed floor to the
-- current count, show the +/- arrows and "Floor N / M" label on multi-floor
-- houses, and the owner-only add/remove/stairs controls. Returns floorCount so
-- the build doesn't recount. Called from FP.Build.
function FP.RefreshFloorControls(h)
    local floorCount = (h and h.floorCount) or 1
    if CH.fpViewedFloor > floorCount then
        CH.fpViewedFloor = floorCount
    end
    if CH.fpViewedFloor < 1 then
        CH.fpViewedFloor = 1
    end

    if floorCount > 1 then
        floorHeader:SetText(string.format(CH.L["FP_FLOOR_COUNT_X"], CH.fpViewedFloor, floorCount))
        floorHeader:Show()
        floorUp:Show()
        floorDown:Show()
        floorUp:SetEnabled(CH.fpViewedFloor < floorCount)
        floorDown:SetEnabled(CH.fpViewedFloor > 1)
        -- Offer the override only while browsing a floor you're not standing on.
        if CH.fpViewedFloor ~= (CH.activeFloor or 1) then
            moveBtn:SetText(string.format(CH.L["FP_MOVE_TO_FLOOR_X"], CH.fpViewedFloor))
            moveBtn:Show()
        else
            moveBtn:Hide()
        end
    else
        floorHeader:Hide()
        floorUp:Hide()
        floorDown:Hide()
        moveBtn:Hide()
    end
    addFloorBtn:SetShown(CH.isOwnHouse and h ~= nil)
    ambienceBtn:SetShown(CH.isOwnHouse and h ~= nil)
    -- Removing the top floor only makes sense once there are 2+ floors.
    removeFloorBtn:SetShown(CH.isOwnHouse and h ~= nil and floorCount > 1)
    -- The Show stairs toggle appears whenever the house has stairs to show/hide.
    stairsCheck:SetShown(floorCount > 1)
    stairsCheck:SetChecked(ChamberlainDB.settings.showStairsOnMap)
    spotsCheck:SetShown(h ~= nil and h.zones ~= nil and HasSpots(h))
    spotsCheck:SetChecked(ChamberlainDB.settings.showSpotsOnMap)
    return floorCount
end

-- Called from Housing when the player's active floor changes (took the stairs):
-- snap the viewed floor to follow them, so the map shows where they now are.
function CH.OnActiveFloorChanged()
    CH.fpViewedFloor = CH.activeFloor or 1
    if fp:IsShown() then
        FP.Build()
    end
end
