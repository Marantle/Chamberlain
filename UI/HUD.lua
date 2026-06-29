local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Launcher  (compact in-house bar that opens the real tools)
-- ─────────────────────────────────────────────────────────────────────
-- The old position HUD tried to do three jobs at once: show live coords, create
-- rooms (Mark A / Mark B / Create), and launch the windows. That stacked up to
-- seven buttons. It is now just a small launcher. Build opens the toolbox, Rooms
-- the manager, Settings the options. The coordinate readout and the make/fit
-- tools moved to the toolbox (UI/Toolbox.lua); the map has its own button when
-- you're visiting a house you hold a layout for.

CH.hud = CreateFrame("Frame", "ChamberlainHUDFrame", UIParent, "BackdropTemplate")
local hud = CH.hud
hud:SetSize(184, 58)
hud:SetFrameStrata("MEDIUM")
CH.SkinWindow(hud, CH.L["HUD_TITLE"])
hud:Hide()

CH.ApplyHUDPos = CH.MakeMovablePersistent(hud, "hudX", "hudY")

local btnBuild = CH.MakeButton(hud, CH.L["HUD_BUILD"], 60, 22)
local btnRooms = CH.MakeButton(hud, CH.L["HUD_ROOMS"], 60, 22)
local btnMap = CH.MakeButton(hud, CH.L["HUD_MAP"], 56, 22)
local btnSettings = CH.MakeButton(hud, CH.L["HUD_SETTINGS"], 72, 22)

btnBuild:SetScript("OnClick", function()
    CH.ToggleToolbox()
end)
btnRooms:SetScript("OnClick", function()
    CH.ToggleRoomManager()
end)
btnMap:SetScript("OnClick", function()
    CH.ToggleFloorPlan()
end)
btnSettings:SetScript("OnClick", function()
    CH.ToggleSettings()
end)

local function Tip(btn, text)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end
Tip(btnBuild, CH.L["HUD_TT_BUILD"])
Tip(btnRooms, CH.L["HUD_TT_ROOMS"])
Tip(btnMap, CH.L["HUD_TT_MAP"])
Tip(btnSettings, CH.L["HUD_TT_SETTINGS"])

-- Lay the visible buttons left to right under the header and size the bar to fit.
local function Layout(buttons)
    local x = 8
    for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", hud, "TOPLEFT", x, -28)
        b:Show()
        x = x + b:GetWidth() + 4
    end
    hud:SetWidth(x + 4)
end

-- Pick the launcher's buttons for where we are: full set in your own house, a
-- viewer set when visiting (no building, plus the map if you hold the layout).
function CH.RefreshHUDMode()
    if ChamberlainDB.settings.hudHidden then
        hud:Hide()
        return
    end
    for _, b in ipairs({ btnBuild, btnRooms, btnMap, btnSettings }) do
        b:Hide()
    end
    if CH.isOwnHouse then
        Layout({ btnBuild, btnMap, btnRooms, btnSettings })
    else
        local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
        if h and h.zones and #h.zones > 0 then
            Layout({ btnRooms, btnMap, btnSettings })
        else
            Layout({ btnRooms, btnSettings })
        end
    end
    hud:Show()
end

-- Hide or show the launcher. The choice persists, so it stays hidden across
-- houses and sessions until shown again. Returns the new hidden state.
function CH.ToggleHud()
    ChamberlainDB.settings.hudHidden = not ChamberlainDB.settings.hudHidden
    if C_Housing.IsInsideHouse() then
        CH.RefreshHUDMode()
    end
    return ChamberlainDB.settings.hudHidden
end
