local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Position HUD  (coordinates + zone-creation controls)
-- ─────────────────────────────────────────────────────────────────────

CH.hud = CreateFrame("Frame", "ChamberlainHUDFrame", UIParent, "BackdropTemplate")
local hud = CH.hud
hud:SetSize(232, 196)
hud:SetFrameStrata("MEDIUM")
CH.SkinWindow(hud, "|cffFFD700Chamberlain|r")
hud:Hide()

CH.ApplyHUDPos = CH.MakeMovablePersistent(hud, "hudX", "hudY")

local hudHelp = CreateFrame("Button", nil, hud)
hudHelp:SetSize(16, 16)
hudHelp:SetPoint("TOPRIGHT", -8, -4)
local hudHelpText = hudHelp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hudHelpText:SetAllPoints()
hudHelpText:SetText("|cffFFD700?|r")
hudHelp:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Chamberlain", 1, 0.85, 0.25)
    GameTooltip:AddLine(CH.L["HUD_TT_NAME_ROOM"], 1, 1, 1)
    GameTooltip:AddLine(CH.L["HUD_TT_STEP1"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(CH.L["HUD_TT_STEP2"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(CH.L["HUD_TT_STEP3"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(CH.L["HUD_TT_BANNER"], 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(CH.L["HUD_TT_FLOORPLAN"], 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(CH.L["HUD_TT_SHARE"], 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(CH.L["HUD_TT_COMMANDS"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
hudHelp:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

CH.coordLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.coordLabel:SetPoint("TOPLEFT", 10, -30)
CH.coordLabel:SetText(CH.L["HUD_COORD_PLACEHOLDER"])

CH.zoneLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
CH.zoneLabel:SetPoint("TOPLEFT", 10, -44)
CH.zoneLabel:SetText("-")
CH.zoneLabel:SetTextColor(0.75, 0.75, 0.75, 1)

local labelA = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
labelA:SetPoint("TOPLEFT", 10, -60)
labelA:SetText(CH.L["HUD_CORNER_A_NONE"])
labelA:SetTextColor(0.40, 0.90, 1.00, 1)

local labelB = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
labelB:SetPoint("TOPLEFT", 10, -74)
labelB:SetText(CH.L["HUD_CORNER_B_NONE"])
labelB:SetTextColor(0.40, 0.90, 1.00, 1)

local btnMarkA = CH.MakeButton(hud, CH.L["HUD_MARK_A"], 96, 22)
local btnMarkB = CH.MakeButton(hud, CH.L["HUD_MARK_B"], 96, 22)
local btnCreate = CH.MakeButton(hud, CH.L["HUD_CREATE_ROOM"], 220, 22)
local btnStairs = CH.MakeButton(hud, CH.L["HUD_ADD_STAIRS"], 220, 22)
local btnMarker = CH.MakeButton(hud, CH.L["HUD_FLOOR_MARKER"], 220, 22)
local btnManage = CH.MakeButton(hud, CH.L["HUD_MANAGE_ROOMS"], 220, 22)
local btnFloor = CH.MakeButton(hud, CH.L["HUD_FLOOR_PLAN"], 220, 22)
btnCreate:Disable()

btnManage:SetScript("OnClick", function()
    CH.OpenRoomManager()
end)
btnFloor:SetScript("OnClick", function()
    CH.OpenFloorPlan()
end)
btnStairs:SetScript("OnClick", function()
    CH.OpenStairsWizard()
end)
btnMarker:SetScript("OnClick", function()
    CH.OpenFloorMarkerWizard()
end)

-- Thin rule under Create Room, dividing the room-marking controls (Mark A and
-- Mark B feed Create Room) from the floor and management buttons below it. Only
-- shown in your own house, repositioned with the stack in RefreshHUDMode.
local hudSep = hud:CreateTexture(nil, "ARTWORK")
hudSep:SetHeight(1)
hudSep:SetColorTexture(CH.RGBA(CH.COLORS.sep, 0.5))
hudSep:Hide()

function CH.RefreshHUDMode()
    if ChamberlainDB.settings.hudHidden then
        hud:Hide()
        return
    end
    btnMarkA:ClearAllPoints()
    btnMarkB:ClearAllPoints()
    btnCreate:ClearAllPoints()
    btnStairs:ClearAllPoints()
    btnMarker:ClearAllPoints()
    btnManage:ClearAllPoints()
    btnFloor:ClearAllPoints()
    if not CH.isOwnHouse then
        -- In someone else's house: shrink to the Manage Rooms button. If we hold
        -- a layout for this house, add the Floor Plan button so it can be viewed.
        CH.coordLabel:Hide()
        CH.zoneLabel:Hide()
        labelA:Hide()
        labelB:Hide()
        btnMarkA:Hide()
        btnMarkB:Hide()
        btnCreate:Hide()
        btnStairs:Hide()
        btnMarker:Hide()
        hudSep:Hide()
        local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
        if h and h.zones and #h.zones > 0 then
            hud:SetHeight(86)
            btnManage:SetPoint("BOTTOM", hud, "BOTTOM", 0, 30)
            btnFloor:SetPoint("BOTTOM", hud, "BOTTOM", 0, 6)
            btnFloor:Show()
        else
            hud:SetHeight(60)
            btnManage:SetPoint("BOTTOM", hud, "BOTTOM", 0, 6)
            btnFloor:Hide()
        end
        btnManage:Show()
        hud:Show()
        return
    end

    -- Own house. The Add stairs button only appears once the house has more than
    -- one floor (same gate as the floor plan's button); when it does the stack
    -- gains a row and the window grows to fit.
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local showStairs = h and (h.floorCount or 1) > 1
    btnManage:SetPoint("BOTTOM", hud, "BOTTOM", 0, 30)
    btnFloor:SetPoint("BOTTOM", hud, "BOTTOM", 0, 5)
    hudSep:ClearAllPoints()
    if showStairs then
        hud:SetHeight(254)
        btnMarker:SetPoint("BOTTOM", hud, "BOTTOM", 0, 55)
        btnStairs:SetPoint("BOTTOM", hud, "BOTTOM", 0, 80)
        hudSep:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 8, 107)
        hudSep:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -8, 107)
        btnCreate:SetPoint("BOTTOM", hud, "BOTTOM", 0, 113)
        btnMarkA:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 6, 138)
        btnMarkB:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -6, 138)
        btnStairs:Show()
        btnMarker:Show()
    else
        hud:SetHeight(204)
        hudSep:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 8, 57)
        hudSep:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -8, 57)
        btnCreate:SetPoint("BOTTOM", hud, "BOTTOM", 0, 63)
        btnMarkA:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 6, 88)
        btnMarkB:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -6, 88)
        btnStairs:Hide()
        btnMarker:Hide()
    end
    hudSep:Show()
    CH.coordLabel:Show()
    CH.zoneLabel:Show()
    labelA:Show()
    labelB:Show()
    btnMarkA:Show()
    btnMarkB:Show()
    btnCreate:Show()
    btnManage:Show()
    btnFloor:Show()
    hud:Show()
end

-- Hide or show the position HUD. The choice persists, so the HUD stays hidden
-- across houses and sessions until shown again. Returns the new hidden state.
function CH.ToggleHud()
    ChamberlainDB.settings.hudHidden = not ChamberlainDB.settings.hudHidden
    if C_Housing.IsInsideHouse() then
        CH.RefreshHUDMode()
    end
    return ChamberlainDB.settings.hudHidden
end

-- ─────────────────────────────────────────────────────────────────────
-- Corner marking
-- ─────────────────────────────────────────────────────────────────────

---@class ChCorner
---@field x number
---@field y number
---@field mapID number

function CH.RefreshCornerLabels()
    labelA:SetText(
        CH.pendingA and string.format(CH.L["HUD_CORNER_A_X"], CH.pendingA.x, CH.pendingA.y) or CH.L["HUD_CORNER_A_NONE"]
    )
    labelB:SetText(
        CH.pendingB and string.format(CH.L["HUD_CORNER_B_X"], CH.pendingB.x, CH.pendingB.y) or CH.L["HUD_CORNER_B_NONE"]
    )
    if CH.pendingA and CH.pendingB then
        btnCreate:Enable()
    else
        btnCreate:Disable()
    end
end

btnMarkA:SetScript("OnClick", function()
    local x, y, mapID = CH.GetWorldPos()
    if not x then
        return
    end
    CH.pendingA = { x = x, y = y, mapID = mapID }
    CH.RefreshCornerLabels()
end)

btnMarkB:SetScript("OnClick", function()
    local x, y, mapID = CH.GetWorldPos()
    if not x then
        return
    end
    CH.pendingB = { x = x, y = y, mapID = mapID }
    CH.RefreshCornerLabels()
end)

-- The room dialog itself lives in RoomDialog.lua. The button just opens it.
btnCreate:SetScript("OnClick", function()
    CH.OpenCreateDialog()
end)
