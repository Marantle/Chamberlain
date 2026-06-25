local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Minimap button  (left-click: room manager, right-click: floor plan)
-- ─────────────────────────────────────────────────────────────────────

local btn = CreateFrame("Button", "ChamberlainMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

local icon = btn:CreateTexture(nil, "BACKGROUND")
-- The tracking-border ring is not centered within its own 53x53 texture, so a
-- CENTER anchor drops the icon up and to the left where it clips the rim.
-- TOPLEFT (7, -6) at 19x19 lands it dead-center in the ring. These are the
-- mesured values LibDBIcon uses for a 31x31 button with this border.
icon:SetSize(19, 19)
icon:SetPoint("TOPLEFT", 7, -6)
-- High Society Top Hat (item 54451); resolved by ID since the icon's file
-- name is not what Wowhead displays
icon:SetTexture(C_Item.GetItemIconByID(54451) or "Interface/Icons/INV_Misc_QuestionMark")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")

local function ApplyPosition()
    local angle = math.rad(ChamberlainDB.minimapAngle or 220)
    -- Radius from the minimap's actual size so the button sits on the edge
    -- regardless of how large the player's minimap is (matches LibDBIcon).
    local rx = (Minimap:GetWidth() / 2) + 5
    local ry = (Minimap:GetHeight() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * rx, math.sin(angle) * ry)
end

local function UpdateDrag()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ChamberlainDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    ApplyPosition()
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", UpdateDrag)
end)
btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

btn:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        CH.OpenRoomManager()
    elseif mouseButton == "MiddleButton" then
        CH.OpenFloorPlan()
    else
        -- Left-click always toggles the position HUD. Outside your house there
        -- is nothing to show right then, so it just sets the preference.
        local hidden = CH.ToggleHud()
        if hidden then
            CH.Print(CH.L["MM_HUD_HIDDEN"])
        elseif C_Housing.IsInsideHouse() then
            CH.Print(CH.L["CMD_HUD_SHOWN"])
        else
            CH.Print(CH.L["CMD_HUD_WILL_SHOW"])
        end
    end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Chamberlain", 1, 0.85, 0.25)
    GameTooltip:AddLine(CH.L["MM_TT_LEFT"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(CH.L["MM_TT_RIGHT"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(CH.L["MM_TT_MIDDLE"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ChamberlainDB is not available until ADDON_LOADED
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", ApplyPosition)
