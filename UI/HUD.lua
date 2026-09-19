local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Launcher  (compact in-house bar that opens the real tools)
-- ─────────────────────────────────────────────────────────────────────
-- The old position HUD tried to do three jobs at once: show live coords, create
-- rooms (Mark A / Mark B / Create), and launch the windows. That stacked up to
-- seven buttons. It is now just a small launcher. Build opens the toolbox, Rooms
-- the manager, Settings the options. The coordinate readout and the make/fit
-- tools moved to the toolbox (UI/Toolbox.lua). The map has its own button when
-- you're visiting a house you hold a layout for.

CH.hud = CreateFrame("Frame", "ChamberlainHUDFrame", UIParent, "BackdropTemplate")
local hud = CH.hud
hud:SetSize(184, 58)
hud:SetFrameStrata("MEDIUM")
CH.SkinWindow(hud, "HUD_TITLE")
hud:Hide()

CH.ApplyHUDPos = CH.MakeMovablePersistent(hud, "hudX", "hudY")

local btnBuild = CH.MakeButton(hud, "HUD_BUILD", 60, 22)
local btnRooms = CH.MakeButton(hud, "HUD_ROOMS", 60, 22)
local btnMap = CH.MakeButton(hud, "HUD_MAP", 56, 22)
local btnArchive = CH.MakeButton(hud, "HUD_ARCHIVE", 66, 22)
local btnSettings = CH.MakeButton(hud, "HUD_SETTINGS", 72, 22)

btnBuild:SetScript("OnClick", function()
    CH.ToggleToolbox()
end)
btnRooms:SetScript("OnClick", function()
    CH.ToggleRoomManager()
end)
btnMap:SetScript("OnClick", function()
    CH.ToggleFloorPlan()
end)
btnArchive:SetScript("OnClick", function()
    CH.ToggleArchive()
end)
btnSettings:SetScript("OnClick", function()
    CH.ToggleSettings()
end)

-- Quick mute for room ambience, the same switch as the one in Settings. Only
-- on the bar in a house whose map has a sound somewhere.
local btnSound = CH.MakeButton(hud, "HUD_SOUND", 56, 22)

local function RefreshSound()
    btnSound:SetText(CH.L[ChamberlainDB.settings.ambienceEnabled and "HUD_SOUND" or "HUD_MUTED"])
end
CH.RefreshHudSound = RefreshSound

btnSound:SetScript("OnClick", function()
    ChamberlainDB.settings.ambienceEnabled = not ChamberlainDB.settings.ambienceEnabled
    RefreshSound()
    CH.RefreshSettingsTab()
end)

local function HasAmbience(h)
    if h.ambience or h.music then
        return true
    end
    for _, z in ipairs(h.zones) do
        if z.ambience or z.music or z.sfx then
            return true
        end
    end
end

-- Now playing: the header strip right of the title names what the house has
-- on, since the game won't say. Three bars bounce like a level meter and the
-- names slide back and forth when they don't fit. All of it is animatons the
-- client runs, so nothing here ticks.
local playing = CreateFrame("Frame", nil, hud)
playing:SetPoint("LEFT", hud.title, "RIGHT", 10, 0)
playing:SetPoint("RIGHT", hud, "TOPRIGHT", -8, -13)
playing:SetHeight(16)
playing:Hide()
-- It takes the mouse for its hover, which would leave this part of the header
-- dead for dragging, so a drag here is handed on to the bar.
playing:EnableMouse(true)
playing:RegisterForDrag("LeftButton")
playing:SetScript("OnDragStart", function()
    hud:StartMoving()
end)
playing:SetScript("OnDragStop", function()
    hud:GetScript("OnDragStop")(hud)
end)

local meter = {}
for i, beat in ipairs({ 0.38, 0.52, 0.44 }) do
    local bar = playing:CreateTexture(nil, "OVERLAY")
    bar:SetSize(2, 10)
    bar:SetPoint("BOTTOMLEFT", (i - 1) * 4, 3)
    bar:SetColorTexture(CH.RGBA(CH.COLORS.tipGold, 0.9))
    meter[i] = bar:CreateAnimationGroup()
    meter[i]:SetLooping("BOUNCE")
    local grow = meter[i]:CreateAnimation("Scale")
    grow:SetOrigin("BOTTOM", 0, 0)
    grow:SetScaleFrom(1, 0.25)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(beat)
    grow:SetSmoothing("IN_OUT")
end

local clip = CreateFrame("Frame", nil, playing)
clip:SetPoint("TOPLEFT", 16, 0)
clip:SetPoint("BOTTOMRIGHT")
clip:SetClipsChildren(true)

local names = clip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
names:SetPoint("LEFT")

local slide = names:CreateAnimationGroup()
slide:SetLooping("BOUNCE")
local move = slide:CreateAnimation("Translation")
move:SetSmoothing("IN_OUT")
move:SetStartDelay(2)
move:SetEndDelay(2)

local fadeIn = clip:CreateAnimationGroup()
local fade = fadeIn:CreateAnimation("Alpha")
fade:SetFromAlpha(0)
fade:SetToAlpha(1)
fade:SetDuration(0.6)

local SLIDE_SPEED = 20 -- pixels a second

-- The names slide only when they are wider than the strip, and how wide that
-- is goes with the buttons the bar has on.
local function FitNames()
    slide:Stop()
    local over = names:GetUnboundedStringWidth() - clip:GetWidth()
    if over > 0 then
        move:SetOffset(-over, 0)
        move:SetDuration(over / SLIDE_SPEED)
        slide:Play()
    end
end

playing:SetScript("OnShow", function()
    for _, bounce in ipairs(meter) do
        bounce:Play()
    end
    FitNames()
end)
playing:SetScript("OnHide", function()
    for _, bounce in ipairs(meter) do
        bounce:Stop()
    end
    slide:Stop()
end)

playing:SetScript("OnEnter", function(self)
    local musicID, files = CH.NowPlaying()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(CH.L["HUD_NOW_PLAYING"], unpack(CH.COLORS.tipGold))
    if musicID then
        GameTooltip:AddLine(CH.SoundName(musicID), 1, 1, 1)
    end
    for _, file in ipairs(files) do
        GameTooltip:AddLine(CH.SoundName(file), 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end)
playing:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local shown -- the text on the strip, so only a real change fades in

-- Called from Housing/Ambience.lua whenever a slot gets another file. The
-- track goes first in gold by the last piece of its path and the hover has all
-- of it.
function CH.RefreshNowPlaying()
    local musicID, files = CH.NowPlaying()
    local pieces = {}
    if musicID then
        pieces[1] = "|cffFFD700" .. CH.SoundName(musicID, true) .. "|r"
    end
    for _, file in ipairs(files) do
        pieces[#pieces + 1] = CH.SoundName(file)
    end
    local text = table.concat(pieces, "   ")
    if text ~= shown then
        shown = text
        names:SetText(text)
        fadeIn:Stop()
        fadeIn:Play()
        FitNames()
    end
    playing:SetShown(text ~= "")
end

CH.Tip(btnBuild, "HUD_TT_BUILD")
CH.Tip(btnRooms, "HUD_TT_ROOMS")
CH.Tip(btnMap, "HUD_TT_MAP")
CH.Tip(btnArchive, "HUD_TT_ARCHIVE")
CH.Tip(btnSettings, "HUD_TT_SETTINGS")
CH.Tip(btnSound, "HUD_TT_SOUND")

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
-- Archive joins the bar only while a stored map is waiting for a house that has
-- no rooms yet. Otherwise it lives in the Rooms window and behind /rooms archive.
function CH.RefreshHUDMode()
    if ChamberlainDB.settings.hudHidden then
        hud:Hide()
        return
    end
    for _, b in ipairs({ btnBuild, btnRooms, btnMap, btnArchive, btnSettings, btnSound }) do
        b:Hide()
    end
    local guid = CH.currentHouseGUID
    local h = guid and ChamberlainDB.houses[guid]
    local buttons
    if CH.isOwnHouse then
        if CH.ArchiveWaiting(guid) then
            buttons = { btnBuild, btnMap, btnRooms, btnArchive, btnSettings }
        else
            buttons = { btnBuild, btnMap, btnRooms, btnSettings }
        end
    elseif h and h.zones and #h.zones > 0 then
        buttons = { btnRooms, btnMap, btnSettings }
    else
        buttons = { btnRooms, btnSettings }
    end
    if h and h.zones and HasAmbience(h) then
        buttons[#buttons + 1] = btnSound
        RefreshSound()
    end
    Layout(buttons)
    hud:Show()
    FitNames()
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
