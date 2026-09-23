local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Launcher  (compact in-house bar that opens the real tools)
-- ─────────────────────────────────────────────────────────────────────
-- The old position HUD tried to do three jobs at once: show live coords, create
-- rooms (Mark A / Mark B / Create), and launch the windows. That stacked up to
-- seven buttons. It is now just a small launcher. Build opens the toolbox and
-- Sharing the Rooms window, which holds your houses and the maps of everybody
-- else. The coordinate readout and the make/fit tools moved to the toolbox
-- (UI/Toolbox.lua). The map has its own
-- button when you're visiting a house you hold a layout for.
--
-- The row is for the windows you work in. Settings and the mute are icons in
-- the header, where they cost no width, or the bar grows a button with every
-- feature (3.13.0).

CH.hud = CreateFrame("Frame", "ChamberlainHUDFrame", UIParent, "BackdropTemplate")
local hud = CH.hud
-- Never narrower than this, or a visitor's bar with one or two buttons leaves
-- the now playing strip in the header next to no room.
local MIN_WIDTH = 220
hud:SetSize(MIN_WIDTH, 58)
hud:SetFrameStrata("MEDIUM")
CH.SkinWindow(hud, "HUD_TITLE")
hud:Hide()

CH.ApplyHUDPos = CH.MakeMovablePersistent(hud, "hudX", "hudY")

local btnBuild = CH.MakeButton(hud, "HUD_BUILD", 60, 22)
local btnMap = CH.MakeButton(hud, "HUD_MAP", 56, 22)
local btnArchive = CH.MakeButton(hud, "HUD_ARCHIVE", 66, 22)
local btnSharing = CH.MakeButton(hud, "HUD_SHARING", 66, 22)
local rowButtons = { btnBuild, btnMap, btnArchive, btnSharing }
-- Layout stretches them, so each keeps the width it was made with.
for _, b in ipairs(rowButtons) do
    b.baseWidth = b:GetWidth()
end

local function MakeHeaderIcon(texture)
    local b = CreateFrame("Button", nil, hud)
    b:SetSize(16, 16)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(texture)
    b:SetHighlightTexture(texture, "ADD")
    return b
end

local btnSettings = MakeHeaderIcon("Interface\\Buttons\\UI-OptionsButton")
btnSettings:SetPoint("RIGHT", hud, "TOPRIGHT", -8, -13)

-- Update notes nobody has read, for players who turned the What's New window
-- off (UI/WhatsNew.lua keeps ChamberlainDB.unreadSince for it). The blink is an
-- animation the client runs and only while the icon is up. Where it sits is
-- decided in CH.RefreshHUDMode with the other icons.
local btnNotes = MakeHeaderIcon("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
btnNotes:Hide()
btnNotes:SetScript("OnClick", function()
    CH.OpenWhatsNew()
end)

local blink = btnNotes:CreateAnimationGroup()
blink:SetLooping("BOUNCE")
local dim = blink:CreateAnimation("Alpha")
dim:SetFromAlpha(1)
dim:SetToAlpha(0.25)
dim:SetDuration(0.7)
dim:SetSmoothing("IN_OUT")
btnNotes:SetScript("OnShow", function()
    blink:Play()
end)
btnNotes:SetScript("OnHide", function()
    blink:Stop()
end)

btnBuild:SetScript("OnClick", function()
    CH.ToggleToolbox()
end)
btnSharing:SetScript("OnClick", function()
    CH.ToggleRoomManager()
end)

-- Lit while somebody in the group offers a map of this house, see
-- CH.RefreshSharingDot in UI/RoomManager.lua.
local sharingDot = btnSharing:CreateTexture(nil, "OVERLAY")
sharingDot:SetSize(6, 6)
sharingDot:SetPoint("TOPRIGHT", -3, -3)
sharingDot:SetColorTexture(CH.RGBA(CH.COLORS.tipGold, 1))
sharingDot:Hide()

function CH.SetSharingDot(on)
    sharingDot:SetShown(on)
end

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
-- on the bar in a house whose map has a sound somewhere. The game's own mute
-- mark goes over the speaker while it's off.
local btnSound = MakeHeaderIcon("Interface\\Common\\VoiceChat-Speaker")
btnSound:SetPoint("RIGHT", btnSettings, "LEFT", -4, 0)

local muteMark = btnSound:CreateTexture(nil, "OVERLAY")
muteMark:SetAllPoints()
muteMark:SetTexture("Interface\\Common\\VoiceChat-Muted")

-- The kinds a player can mute one by one, label key and settings key. Either
-- click on the speaker opens these, under a Mute all that throws the master
-- switch.
CH.SOUND_KINDS = {
    { "HUD_KIND_AMBIENCE", "soundAmbience" },
    { "HUD_KIND_MUSIC", "soundMusic" },
    { "HUD_KIND_ROOMS", "soundRooms" },
    { "HUD_KIND_ECHOES", "echoes" },
    { "HUD_KIND_ARRIVAL_GROUP", "arrivalGroup" },
    { "HUD_KIND_ARRIVAL_GUILD", "arrivalGuild" },
}

-- Plain with everything on, the red mark on the master mute, grey when only
-- some kind is off.
local function RefreshSound()
    local s = ChamberlainDB.settings
    local all = s.ambienceEnabled
    for _, kind in ipairs(CH.SOUND_KINDS) do
        all = all and s[kind[2]]
    end
    muteMark:SetShown(not s.ambienceEnabled)
    btnSound.icon:SetDesaturated(not all)
end
CH.RefreshHudSound = RefreshSound

-- Also behind the button in Settings. The zone ticker reads the settings, so a
-- tick takes hold within a tenth of a second.
function CH.FillSoundMenu(root)
    root:CreateTitle(CH.L["HUD_SOUND_KINDS"])
    for _, kind in ipairs(CH.SOUND_KINDS) do
        local key = kind[2]
        root:CreateCheckbox(CH.L[kind[1]], function()
            return ChamberlainDB.settings[key]
        end, function()
            ChamberlainDB.settings[key] = not ChamberlainDB.settings[key]
            RefreshSound()
        end)
    end
end

-- Both buttons open the menu (3.16.0). The master mute used to be a left click
-- and nothing on screen said so, so people never found the kinds behind the
-- right one. Mute all names what the click does instead of holding a tick,
-- which would have meant the opposite of the six under it.
btnSound:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btnSound:SetScript("OnClick", function(self)
    MenuUtil.CreateContextMenu(self, function(_, root)
        local muted = not ChamberlainDB.settings.ambienceEnabled
        root:CreateButton(muted and CH.L["HUD_UNMUTE_ALL"] or CH.L["HUD_MUTE_ALL"], function()
            ChamberlainDB.settings.ambienceEnabled = not ChamberlainDB.settings.ambienceEnabled
            RefreshSound()
            CH.RefreshSettingsTab()
        end)
        CH.FillSoundMenu(root)
    end)
end)

local function HasAmbience(h)
    if h.ambience or h.music or h.arrival then
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
-- its right end is set in CH.RefreshHUDMode, by the icons the header has on
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
CH.Tip(btnMap, "HUD_TT_MAP")
CH.Tip(btnArchive, "HUD_TT_ARCHIVE")
CH.Tip(btnSharing, "HUD_TT_SHARING")
CH.Tip(btnNotes, "HUD_TT_NOTES")
CH.Tip(btnSettings, "HUD_TT_SETTINGS")
CH.Tip(btnSound, "HUD_TT_SOUND")

-- Lay the visible buttons left to right under the header and size the bar to fit.
-- A row too short for MIN_WIDTH shares out the rest between its buttons, so it
-- never ends in a gap.
local function Layout(buttons)
    local natural = 4 * (#buttons - 1)
    for _, b in ipairs(buttons) do
        natural = natural + b.baseWidth
    end
    local extra = math.max(0, (MIN_WIDTH - 16 - natural) / #buttons)
    local x = 8
    for _, b in ipairs(buttons) do
        b:SetWidth(b.baseWidth + extra)
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
    -- A map coming in from the group lands here as well, wherever you stand,
    -- and would put the bar up in the middle of Stormwind.
    if ChamberlainDB.settings.hudHidden or not C_Housing.IsInsideHouse() then
        hud:Hide()
        return
    end
    for _, b in ipairs(rowButtons) do
        b:Hide()
    end
    local guid = CH.currentHouseGUID
    local h = guid and ChamberlainDB.houses[guid]
    local buttons
    if CH.isOwnHouse then
        if CH.ArchiveWaiting(guid) then
            buttons = { btnBuild, btnMap, btnSharing, btnArchive }
        else
            buttons = { btnBuild, btnMap, btnSharing }
        end
    elseif h and h.zones and #h.zones > 0 then
        buttons = { btnMap, btnSharing }
    else
        buttons = { btnSharing }
    end
    -- The header's icons run from the right. The gear is always up, the speaker
    -- joins in a house with sounds and the note while update notes are unread.
    -- Now playing ends at whichever is leftmost.
    local sounds = h and h.zones and HasAmbience(h)
    btnSound:SetShown(sounds == true)
    if sounds then
        RefreshSound()
    end
    local leftmost = sounds and btnSound or btnSettings
    local unread = ChamberlainDB.unreadSince ~= nil
    btnNotes:SetShown(unread)
    if unread then
        btnNotes:SetPoint("RIGHT", leftmost, "LEFT", -4, 0)
        leftmost = btnNotes
    end
    playing:SetPoint("RIGHT", leftmost, "LEFT", -6, 0)
    Layout(buttons)
    CH.RefreshSharingDot()
    hud:Show()
    FitNames()
end

-- Hide or show the launcher. The choice persists, so it stays hidden across
-- houses and sessions until shown again. Returns the new hidden state.
function CH.ToggleHud()
    ChamberlainDB.settings.hudHidden = not ChamberlainDB.settings.hudHidden
    CH.RefreshHUDMode()
    return ChamberlainDB.settings.hudHidden
end
