local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room dialog: create and edit (name, color, head, description)
-- ─────────────────────────────────────────────────────────────────────

local dialog = CreateFrame("Frame", "ChamberlainNameDialog", UIParent, "BackdropTemplate")
dialog:SetSize(376, 414)
dialog:SetFrameStrata("DIALOG")
dialog:SetToplevel(true) -- clicking/showing lifts it above other windows, like the rest
dialog:SetPoint("CENTER")
CH.MakeDraggable(dialog) -- blocks click-through and lets the player drag it
CH.SkinWindow(dialog, CH.L["RD_TITLE_NAME_ROOM"])
dialog:Hide()

local renameTarget = nil -- zone being renamed; nil means create mode
local renameHouseGUID = nil -- house the renamed zone belongs to (nil = current)
local pendingColor = nil -- color for the room being named; nil = default gold
local pendingHeadID = nil -- talking-head index for the room; nil/1 = default
local pendingVoice = nil -- TTS voice NAME for the room; nil = silent. Local-only.

-- Which floor the room sits on, and whether it doubles as a stair anchor.
-- pendingSetFloor / pendingFloorDelta are mutually exclusive and both nil for an
-- ordinary room. The floor row is hidden unless the house has multiple floors.
local pendingFloor = 1
local pendingSetFloor = nil
local pendingFloorDelta = nil

-- The house this dialog is acting on: the renamed zone's house in edit mode, or
-- the house we're standing in when creating.
local function DialogHouse()
    local guid = renameTarget and (renameHouseGUID or CH.currentHouseGUID) or CH.currentHouseGUID
    return guid and ChamberlainDB.houses[guid]
end

local editBox = CreateFrame("EditBox", "ChamberlainEditBox", dialog, "InputBoxTemplate")
editBox:SetSize(300, 20)
editBox:SetPoint("TOP", dialog, "TOP", 0, -34)
editBox:SetAutoFocus(false)
editBox:SetMaxLetters(48)

-- Color row: main swatch opens the picker, small swatches are recent colors
local colorLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
colorLabel:SetPoint("TOPLEFT", 24, -64)
colorLabel:SetText(CH.L["RD_COLOR"])

local mainSwatch = CH.MakeSwatch(dialog, 18)
mainSwatch:SetPoint("TOPLEFT", 62, -60)

local function UpdateMainSwatch()
    if pendingColor then
        mainSwatch:SetBackdropColor(pendingColor[1], pendingColor[2], pendingColor[3], 1)
    else
        mainSwatch:SetBackdropColor(CH.RGBA(CH.COLORS.grey, 1)) -- "default" grey
    end
end

mainSwatch:SetScript("OnClick", function()
    local old = pendingColor
    ColorPickerFrame:SetupColorPickerAndShow({
        r = old and old[1] or 1,
        g = old and old[2] or 0.85,
        b = old and old[3] or 0.25,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            pendingColor = { r, g, b }
            UpdateMainSwatch()
        end,
        cancelFunc = function()
            pendingColor = old
            UpdateMainSwatch()
        end,
    })
end)

local clearSwatch = CH.MakeSwatch(dialog, 18)
clearSwatch:SetPoint("LEFT", mainSwatch, "RIGHT", 4, 0)
clearSwatch:SetBackdropColor(0, 0, 0, 0.6)
local clearX = clearSwatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
clearX:SetPoint("CENTER")
clearX:SetText("x")
clearX:SetTextColor(0.6, 0.6, 0.6, 1)
clearSwatch:SetScript("OnClick", function()
    pendingColor = nil
    UpdateMainSwatch()
end)

local historySwatches = {}
for i = 1, 5 do
    local s = CH.MakeSwatch(dialog, 14)
    s:SetPoint("LEFT", clearSwatch, "RIGHT", 10 + (i - 1) * 18, 0)
    s:SetScript("OnClick", function(self)
        pendingColor = { self.color[1], self.color[2], self.color[3] }
        UpdateMainSwatch()
    end)
    s:Hide()
    historySwatches[i] = s
end

local function RefreshHistorySwatches()
    local list = ChamberlainDB.recentColors or {}
    for i, s in ipairs(historySwatches) do
        local c = list[i]
        if c then
            s.color = c
            s:SetBackdropColor(c[1], c[2], c[3], 1)
            s:Show()
        else
            s:Hide()
        end
    end
end

-- Head picker: a row of small 3D heads. Clicking one sets the room's headID.
-- The model is rendered locally from CH.HEADS, so only the index is stored.
local headLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
headLabel:SetPoint("TOPLEFT", 24, -90)
headLabel:SetText(CH.L["RD_YAPPER"])

local headButtons = {}
local UpdateSpeakerHint -- defined once the speaker box exists; refreshes its placeholder
local function UpdateHeadSelection()
    for i, b in ipairs(headButtons) do
        if i == (pendingHeadID or 1) then
            b:SetBackdropBorderColor(0.95, 0.80, 0.25, 1)
        else
            b:SetBackdropBorderColor(0.40, 0.35, 0.20, 0.7)
        end
    end
    if UpdateSpeakerHint then
        UpdateSpeakerHint()
    end
end

local function BuildHeadPicker()
    for i, head in ipairs(CH.HEADS) do
        local b = headButtons[i]
        if not b then
            b = CreateFrame("Button", nil, dialog, "BackdropTemplate")
            b:SetSize(34, 34)
            b:SetBackdrop(CH.BACKDROP_THIN)
            b:SetBackdropColor(0, 0, 0, 0.6)
            b:SetPoint("TOPLEFT", 62 + (i - 1) * 38, -82)
            b.model = CreateFrame("PlayerModel", nil, b)
            b.model:SetPoint("TOPLEFT", 2, -2)
            b.model:SetPoint("BOTTOMRIGHT", -2, 2)
            b.model:SetScript("OnModelLoaded", function(self)
                self:SetPortraitZoom(1)
            end)
            b:SetScript("OnClick", function()
                pendingHeadID = i
                UpdateHeadSelection()
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(head.name, 1, 0.85, 0.25)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            headButtons[i] = b
        end
        b.model:SetDisplayInfo(head.display)
        b.model:SetPortraitZoom(1)
        b:Show()
    end
end

-- "Use my head when I'm home": flags the room to show the house owner's own
-- character (when the owner is present) instead of a curated head.
local ownerCheck = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
ownerCheck:SetSize(24, 24)
ownerCheck:SetPoint("TOPLEFT", 22, -120)
local ownerCheckLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ownerCheckLabel:SetPoint("LEFT", ownerCheck, "RIGHT", 2, 0)
ownerCheckLabel:SetText(CH.L["RD_USE_MY_HEAD"])

-- Spell out the limits on hover so they aren't a surprise: it follows the
-- character you tick it on (not your account), and visitors need to be grouped
-- with you and nearby to see it.
ownerCheck:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(CH.L["RD_USE_MY_HEAD"], 1, 0.82, 0)
    GameTooltip:AddLine(CH.L["RD_USE_MY_HEAD_TT1"], 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(CH.L["RD_USE_MY_HEAD_TT2"], 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(CH.L["RD_USE_MY_HEAD_TT3"], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
ownerCheck:HookScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- "Secret": keeps the room off visitors' floor plans and room lists, while still
-- sharing it so the banner and yapper fire when they walk in.
local secretCheck = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
secretCheck:SetSize(24, 24)
secretCheck:SetPoint("TOPLEFT", 232, -120)
local secretCheckLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secretCheckLabel:SetPoint("LEFT", secretCheck, "RIGHT", 2, 0)
secretCheckLabel:SetText(CH.L["RD_SECRET"])
secretCheck:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(CH.L["RD_SECRET_TT_TITLE"], 1, 0.82, 0)
    GameTooltip:AddLine(CH.L["RD_SECRET_TT1"], 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(CH.L["RD_SECRET_TT2"], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
secretCheck:HookScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Append a grey "(?)" to a field label and show an explanatory tooltip on hover.
-- FontStrings take no mouse events, so an invisible button is laid over the label
-- to catch the hover. Each extra argument is a wrapped body line.
local function AddFieldHelp(label, title, ...)
    label:SetText((label:GetText():gsub(":%s*$", "")) .. " |cff808080(?)|r:")
    local hot = CreateFrame("Button", nil, dialog)
    hot:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
    hot:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, -2)
    local lines = { ... }
    hot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        for _, ln in ipairs(lines) do
            GameTooltip:AddLine(ln, 0.9, 0.9, 0.9, true)
        end
        GameTooltip:Show()
    end)
    hot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Quick custom display-ID box (testing): if filled, it overrides the picked head.
-- Sits on its own row below the head picker so the picker can use the full width.
local headIdLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
headIdLabel:SetPoint("TOPLEFT", 24, -150)
headIdLabel:SetText(CH.L["RD_CUSTOM_ID"])
AddFieldHelp(headIdLabel, CH.L["RD_CUSTOM_ID_TT_TITLE"], CH.L["RD_CUSTOM_ID_TT1"], CH.L["RD_CUSTOM_ID_TT2"])

local headIdBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
headIdBox:SetSize(140, 20)
headIdBox:SetPoint("LEFT", headIdLabel, "RIGHT", 8, 0)
headIdBox:SetAutoFocus(false)
headIdBox:SetNumeric(true)
headIdBox:SetMaxLetters(8)
headIdBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

-- Grey placeholder while empty and unfocused
local headIdHint = headIdBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
headIdHint:SetPoint("LEFT", headIdBox, "LEFT", 6, 0)
headIdHint:SetPoint("RIGHT", headIdBox, "RIGHT", -6, 0)
headIdHint:SetJustifyH("LEFT")
headIdHint:SetText(CH.L["RD_CUSTOM_ID_HINT"])
local function UpdateHeadIdHint()
    headIdHint:SetShown(headIdBox:GetText() == "" and not headIdBox:HasFocus())
end
headIdBox:HookScript("OnEditFocusGained", UpdateHeadIdHint)
headIdBox:HookScript("OnEditFocusLost", UpdateHeadIdHint)
headIdBox:HookScript("OnTextChanged", UpdateHeadIdHint)
UpdateHeadIdHint()

-- Custom display ID from the box, or nil when empty/zero.
local function GetHeadDisplay()
    local n = tonumber(headIdBox:GetText())
    return (n and n > 0) and n or nil
end

-- Speaker name shown on the yapper (like the NPC name on Blizzard's box). When
-- set, it overides the picked head's name, useful with a custom display ID,
-- which has no name we can look up.
local speakerLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
speakerLabel:SetPoint("TOPLEFT", 24, -178)
speakerLabel:SetText(CH.L["RD_SPEAKER"])
AddFieldHelp(speakerLabel, CH.L["RD_SPEAKER_TT_TITLE"], CH.L["RD_SPEAKER_TT1"], CH.L["RD_SPEAKER_TT2"])

local speakerBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
speakerBox:SetSize(250, 20)
speakerBox:SetPoint("LEFT", speakerLabel, "RIGHT", 8, 0)
speakerBox:SetAutoFocus(false)
speakerBox:SetMaxLetters(40)
speakerBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

-- Trimmed speaker name, or nil when empty.
local function GetSpeaker()
    local s = speakerBox:GetText():match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end

-- Placeholder showing the selected head's name (the fallback the yapper uses),
-- hidden once the user types an override. Refreshed when the head changes.
local speakerHint = speakerBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
speakerHint:SetPoint("LEFT", speakerBox, "LEFT", 6, 0)
speakerHint:SetPoint("RIGHT", speakerBox, "RIGHT", -6, 0)
speakerHint:SetJustifyH("LEFT")
speakerHint:SetWordWrap(false)

UpdateSpeakerHint = function()
    if speakerBox:GetText() == "" and not speakerBox:HasFocus() then
        local head = CH.HEADS[pendingHeadID or 1]
        speakerHint:SetText(head and head.name or "")
        speakerHint:Show()
    else
        speakerHint:Hide()
    end
end
speakerBox:HookScript("OnEditFocusGained", UpdateSpeakerHint)
speakerBox:HookScript("OnEditFocusLost", UpdateSpeakerHint)
speakerBox:HookScript("OnTextChanged", UpdateSpeakerHint)

-- Description box: multi-line, capped, scrollable. Built on UIPanelScrollFrame
-- (not InputScrollFrameTemplate) so it gets the same slim gold scrollbar as the
-- rest of the addon. InputScrollFrameTemplate ships the newer MinimalScrollBar
-- that CH.SkinScrollBar can't style.
local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
descLabel:SetPoint("TOPLEFT", 24, -234)
descLabel:SetText(CH.L["RD_DESCRIPTION"])

local DESC_MAX = 500
local descScroll = CreateFrame("ScrollFrame", "ChamberlainDescScroll", dialog, "UIPanelScrollFrameTemplate")
descScroll:SetSize(320, 104)
descScroll:SetPoint("TOPLEFT", 28, -250)
CH.SkinScrollBar(descScroll)

local descBg = descScroll:CreateTexture(nil, "BACKGROUND")
descBg:SetPoint("TOPLEFT", -2, 2)
descBg:SetPoint("BOTTOMRIGHT", 2, -2)
descBg:SetColorTexture(0, 0, 0, 0.30)

local descBox = CreateFrame("EditBox", nil, descScroll)
descBox:SetMultiLine(true)
descBox:SetMaxLetters(DESC_MAX)
descBox:SetAutoFocus(false)
descBox:SetFontObject("ChatFontNormal")
descBox:SetWidth(312)
descBox:SetJustifyH("LEFT")
descBox:SetTextInsets(4, 4, 4, 4)
descBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
descScroll:SetScrollChild(descBox)

-- Click anywhere in the box to start editing
descScroll:EnableMouse(true)
descScroll:SetScript("OnMouseDown", function()
    descBox:SetFocus()
end)

-- Keep the caret in view while typing past the bottom edge
descBox:SetScript("OnCursorChanged", function(_, _, cy, _, ch)
    local top, bottom = -cy, -cy + ch
    local off, h = descScroll:GetVerticalScroll(), descScroll:GetHeight()
    if top < off then
        descScroll:SetVerticalScroll(top)
    elseif bottom > off + h then
        descScroll:SetVerticalScroll(bottom - h)
    end
end)

-- Placeholder, shown while the box is empty and unfocused
local descHint = descScroll:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
descHint:SetPoint("TOPLEFT", 6, -6)
descHint:SetWidth(300)
descHint:SetJustifyH("LEFT")
descHint:SetWordWrap(true)
descHint:SetText(CH.L["RD_DESC_HINT"])
local function UpdateDescHint()
    descHint:SetShown(descBox:GetText() == "" and not descBox:HasFocus())
end
descBox:HookScript("OnEditFocusGained", UpdateDescHint)
descBox:HookScript("OnEditFocusLost", UpdateDescHint)
descBox:HookScript("OnTextChanged", UpdateDescHint)

local btnOK = CH.MakeButton(dialog, CH.L["RD_SAVE"], 82, 22)
local btnCancel = CH.MakeButton(dialog, CH.L["RD_CANCEL"], 82, 22)
btnOK:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -2, 6)
btnCancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 2, 6)

-- Trimmed description text, or nil when the box is empty.
local function GetDescText()
    local t = descBox:GetText():match("^%s*(.-)%s*$")
    return t ~= "" and t or nil
end

-- Voice picker: which OS text-to-speech voice reads this room's description in the
-- yapper. Stored per room as a name string (zone.voice) and kept local. It is
-- never written to CH.ExportLayout or sent over the share protocol, so it stays on
-- this client only. "Default (silent)" means no narration. See Core/Voice.lua.
local voiceLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
voiceLabel:SetPoint("TOPLEFT", 24, -206)
voiceLabel:SetText(CH.L["RD_VOICE"])

local voiceBtn = CH.MakeButton(dialog, CH.L["RD_DEFAULT_SILENT"], 198, 22)
voiceBtn:SetPoint("LEFT", voiceLabel, "RIGHT", 8, 0)
-- Keep the selected-voice label on one line. Long OS voice names get an ellipsis
-- instead of spilling over the Test button. CH.ShortVoiceName compacts the name.
local voiceBtnFS = voiceBtn:GetFontString()
if voiceBtnFS then
    voiceBtnFS:SetWidth(186)
    voiceBtnFS:SetWordWrap(false)
end

local function SetPendingVoice(name)
    pendingVoice = name
    voiceBtn:SetText(CH.ShortVoiceName(name) or CH.L["RD_DEFAULT_SILENT"])
end

voiceBtn:SetScript("OnClick", function(self)
    if not MenuUtil then
        return
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(CH.L["RD_READ_ALOUD"])
        root:CreateRadio(CH.L["RD_DEFAULT_SILENT"], function()
            return pendingVoice == nil
        end, function()
            SetPendingVoice(nil)
        end)
        local voices = CH.GetVoices()
        if #voices == 0 then
            root:CreateButton(CH.L["SKIN_NO_VOICES"]):SetEnabled(false)
        end
        for _, v in ipairs(voices) do
            local name = v.name
            root:CreateRadio(name, function()
                return pendingVoice == name
            end, function()
                SetPendingVoice(name)
            end)
        end
    end)
end)

local voiceTest = CH.MakeButton(dialog, CH.L["RD_TEST"], 72, 22)
voiceTest:SetPoint("LEFT", voiceBtn, "RIGHT", 6, 0)

-- Test toggles play/stop: it reads the description with the picked voice, and
-- flips to "Stop test" while audio is playing so it can be cut short.
local testing = false
local function SetTesting(on)
    testing = on
    voiceTest:SetText(on and CH.L["RD_STOP_TEST"] or CH.L["RD_TEST"])
end

voiceTest:SetScript("OnClick", function()
    if testing then
        CH.StopSpeaking()
        SetTesting(false)
        return
    end
    if not pendingVoice then
        CH.Print(CH.L["RD_PICK_VOICE"])
        return
    end
    CH.Speak(GetDescText() or CH.L["RD_TEST_SAMPLE"], pendingVoice)
    SetTesting(true)
end)

-- Reset the button when playback ends, whether it finished on its own or was
-- stopped elsewhere. This event also fires for the yapper's narration, which is
-- harmless: it only sets the button back to "Test".
local ttsWatcher = CreateFrame("Frame")
ttsWatcher:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
ttsWatcher:SetScript("OnEvent", function()
    SetTesting(false)
end)

-- Info "?" on the voice row: spell out that the voice is personal and never
-- shared, since we can't know which TTS voices another player's PC has.
local voiceInfo = CreateFrame("Button", nil, dialog)
voiceInfo:SetSize(16, 16)
voiceInfo:SetPoint("LEFT", voiceTest, "RIGHT", 4, 0)
local voiceInfoText = voiceInfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
voiceInfoText:SetAllPoints()
voiceInfoText:SetText("|cffFFD700?|r")
voiceInfo:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(CH.L["RD_VOICE_TT_TITLE"], 1, 0.85, 0.25)
    GameTooltip:AddLine(CH.L["RD_VOICE_TT1"], 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(CH.L["RD_VOICE_TT2"], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
voiceInfo:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ── Floor row (multi-floor houses only) ──────────────────────────────
-- A "Floor N" dropdown that scopes the room to a floor, plus a "Stairs"
-- dropdown that turns the room into a stair anchor (absolute "Go to floor N" or
-- relative "Up/Down one"). Hidden entirely on single-floor houses. The dialog
-- grows by one row when it's shown so nothing overlaps the description box.
local DIALOG_BASE_H = 414
local FLOOR_ROW_H = 30

local floorRow = CreateFrame("Frame", nil, dialog)
floorRow:SetPoint("TOPLEFT", descScroll, "BOTTOMLEFT", -4, -8)
floorRow:SetPoint("TOPRIGHT", descScroll, "BOTTOMRIGHT", 4, -8)
floorRow:SetHeight(22)
floorRow:Hide()

local floorLabel = floorRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
floorLabel:SetPoint("LEFT", 0, 0)
floorLabel:SetText(CH.L["RD_FLOOR"])

local floorBtn = CH.MakeButton(floorRow, string.format(CH.L["RD_FLOOR_X"], 1), 84, 22)
floorBtn:SetPoint("LEFT", floorLabel, "RIGHT", 8, 0)

local stairsLabel = floorRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stairsLabel:SetPoint("LEFT", floorBtn, "RIGHT", 14, 0)
stairsLabel:SetText(CH.L["RD_STAIRS"])

local stairsBtn = CH.MakeButton(floorRow, CH.L["RD_NOT_STAIRS"], 132, 22)
stairsBtn:SetPoint("LEFT", stairsLabel, "RIGHT", 8, 0)

-- Label for the current stair link state.
local function StairsText()
    if pendingSetFloor then
        return string.format(CH.L["RD_GO_TO_FLOOR_X"], pendingSetFloor)
    elseif pendingFloorDelta == 1 then
        return CH.L["RD_UP_ONE_FLOOR"]
    elseif pendingFloorDelta == -1 then
        return CH.L["RD_DOWN_ONE_FLOOR"]
    end
    return CH.L["RD_NOT_STAIRS"]
end

local function RefreshFloorButtons()
    floorBtn:SetText(string.format(CH.L["RD_FLOOR_X"], pendingFloor or 1))
    stairsBtn:SetText(StairsText())
end

floorBtn:SetScript("OnClick", function(self)
    if not MenuUtil then
        return
    end
    local h = DialogHouse()
    local count = (h and h.floorCount) or 1
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(CH.L["RD_WHICH_FLOOR"])
        for n = 1, count do
            root:CreateRadio(string.format(CH.L["RD_FLOOR_X"], n), function()
                return (pendingFloor or 1) == n
            end, function()
                pendingFloor = n
                RefreshFloorButtons()
            end)
        end
    end)
end)

stairsBtn:SetScript("OnClick", function(self)
    if not MenuUtil then
        return
    end
    local h = DialogHouse()
    local count = (h and h.floorCount) or 1
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(CH.L["RD_STAIR_LINK"])
        root:CreateRadio(CH.L["RD_NOT_STAIRS"], function()
            return not pendingSetFloor and not pendingFloorDelta
        end, function()
            pendingSetFloor, pendingFloorDelta = nil, nil
            RefreshFloorButtons()
        end)
        root:CreateRadio(CH.L["RD_UP_ONE_FLOOR"], function()
            return pendingFloorDelta == 1
        end, function()
            pendingSetFloor, pendingFloorDelta = nil, 1
            RefreshFloorButtons()
        end)
        root:CreateRadio(CH.L["RD_DOWN_ONE_FLOOR"], function()
            return pendingFloorDelta == -1
        end, function()
            pendingSetFloor, pendingFloorDelta = nil, -1
            RefreshFloorButtons()
        end)
        for n = 1, count do
            root:CreateRadio(string.format(CH.L["RD_GO_TO_FLOOR_X"], n), function()
                return pendingSetFloor == n
            end, function()
                pendingSetFloor, pendingFloorDelta = n, nil
                RefreshFloorButtons()
            end)
        end
    end)
end)

-- Show the floor row only for multi-floor houses and resize the dialog to fit.
local function RefreshFloorRow()
    local h = DialogHouse()
    if h and (h.floorCount or 1) > 1 then
        floorRow:Show()
        dialog:SetHeight(DIALOG_BASE_H + FLOOR_ROW_H)
        RefreshFloorButtons()
    else
        floorRow:Hide()
        dialog:SetHeight(DIALOG_BASE_H)
    end
end

local function CloseDialog()
    editBox:ClearFocus()
    descBox:ClearFocus()
    headIdBox:ClearFocus()
    speakerBox:ClearFocus()
    if testing then
        CH.StopSpeaking()
    end -- don't keep narrating after the dialog closes
    SetTesting(false)
    dialog:Hide()
    renameTarget = nil
    renameHouseGUID = nil
end

-- Opens the dialog to edit an existing zone (name, color, head, description).
-- Used by the floor plan and the room manager. houseGUID is optional: when the
-- zone belongs to a house you aren't standing in, pass it so the edit lands on
-- the right house. nil falls back to the current house.
function CH.OpenRenameDialog(zone, houseGUID)
    -- Stair anchors get a stripped editor (name, floor, behaviour) instead of the
    -- full room dialog, which has yapper/description/voice/secret they never use.
    if (zone.setFloor ~= nil or zone.floorDelta ~= nil) and CH.OpenAnchorEditor then
        CH.OpenAnchorEditor(zone, houseGUID)
        return
    end
    renameTarget = zone
    renameHouseGUID = houseGUID
    pendingColor = zone.color and { zone.color[1], zone.color[2], zone.color[3] } or nil
    pendingHeadID = zone.headID or 1
    pendingFloor = zone.floor or 1
    pendingSetFloor = zone.setFloor
    pendingFloorDelta = zone.floorDelta
    dialog.title:SetText(CH.L["RD_TITLE_EDIT_ROOM"])
    editBox:SetText(zone.name)
    descBox:SetText(zone.rpText or "")
    headIdBox:SetText(zone.headDisplay and tostring(zone.headDisplay) or "")
    speakerBox:SetText(zone.speaker or "")
    ownerCheck:SetChecked(zone.useOwnerHead)
    secretCheck:SetChecked(zone.secret)
    SetPendingVoice(zone.voice)
    UpdateMainSwatch()
    RefreshHistorySwatches()
    BuildHeadPicker()
    UpdateHeadSelection()
    RefreshFloorRow()
    dialog:Show()
    editBox:SetFocus()
    editBox:HighlightText()
end

local function ConfirmZone()
    local name = editBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then
        CH.Print(CH.L["RD_ENTER_NAME"])
        return
    end

    -- Rename mode: the dialog was opened for an existing zone
    if renameTarget then
        local guid = renameHouseGUID or CH.currentHouseGUID
        local h = guid and ChamberlainDB.houses[guid]
        if h then
            -- Carry the room's time stats over to the new name
            if h.stats and h.stats[renameTarget.name] then
                h.stats[name] = (h.stats[name] or 0) + h.stats[renameTarget.name]
                h.stats[renameTarget.name] = nil
            end
            renameTarget.name = name
            renameTarget.color = pendingColor
            renameTarget.headID = pendingHeadID or 1
            renameTarget.headDisplay = GetHeadDisplay()
            renameTarget.speaker = GetSpeaker()
            renameTarget.useOwnerHead = ownerCheck:GetChecked() or nil
            -- Stamp our current character GUID once on the house (not per room) so
            -- visitors can match us in their party even on an alt whose name differs
            -- from the stored buyer name. Only when we own the house we're standing in.
            if renameTarget.useOwnerHead and CH.isOwnHouse then
                h.ownerGUID = UnitGUID("player")
            end
            renameTarget.rpText = GetDescText()
            renameTarget.secret = secretCheck:GetChecked() or nil
            renameTarget.voice = pendingVoice -- local-only; not shared
            renameTarget.floor = pendingFloor or 1
            renameTarget.setFloor = pendingSetFloor
            renameTarget.floorDelta = pendingFloorDelta
            CH.PushRecentColor(pendingColor)
            h.updatedAt = GetServerTime()
            CH.RebuildFloorPlan()
            if CH.RefreshMyRoomsTab then
                CH.RefreshMyRoomsTab()
            end
            CH.QueueBroadcast(guid)
        end
        CloseDialog()
        return
    end

    if not CH.pendingA or not CH.pendingB then
        return
    end
    if CH.pendingA.mapID ~= CH.pendingB.mapID then
        CH.Print(CH.L["RD_DIFFERENT_MAPS"])
        return
    end
    if not CH.currentHouseGUID then
        CH.Print(CH.L["RD_HOUSE_NOT_IDENTIFIED"])
        return
    end
    local z = {
        name = name,
        mapID = CH.pendingA.mapID,
        minX = math.min(CH.pendingA.x, CH.pendingB.x),
        maxX = math.max(CH.pendingA.x, CH.pendingB.x),
        minY = math.min(CH.pendingA.y, CH.pendingB.y),
        maxY = math.max(CH.pendingA.y, CH.pendingB.y),
        color = pendingColor,
        headID = pendingHeadID or 1,
        headDisplay = GetHeadDisplay(),
        speaker = GetSpeaker(),
        useOwnerHead = ownerCheck:GetChecked() or nil,
        rpText = GetDescText(),
        secret = secretCheck:GetChecked() or nil,
        voice = pendingVoice, -- local-only; not shared (excluded from ExportLayout)
        floor = pendingFloor or 1,
        setFloor = pendingSetFloor,
        floorDelta = pendingFloorDelta,
    }
    CH.PushRecentColor(pendingColor)
    if not ChamberlainDB.houses[CH.currentHouseGUID] then
        ChamberlainDB.houses[CH.currentHouseGUID] = { owner = CH.currentHouseOwner, zones = {} }
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    h.owner = CH.currentHouseOwner or h.owner
    h.updatedAt = GetServerTime()
    -- Owner identity is per house: stamp our current character GUID once so
    -- visitors can match us among their party even on an alt (see OpenRenameDialog).
    if z.useOwnerHead and CH.isOwnHouse then
        h.ownerGUID = UnitGUID("player")
    end
    table.insert(h.zones, z)
    CH.pendingA = nil
    CH.pendingB = nil
    CH.RefreshCornerLabels()
    CloseDialog()
    CH.RebuildFloorPlan()
    CH.QueueBroadcast(CH.currentHouseGUID)
    CH.Print(CH.L["RD_ROOM_SAVED_X"], name, z.maxX - z.minX, z.maxY - z.minY)
end

-- Opens the dialog in create mode for the two marked corners. Wired to the
-- HUD's Create Zone button.
function CH.OpenCreateDialog()
    renameTarget = nil
    renameHouseGUID = nil
    pendingColor = nil
    pendingHeadID = 1
    -- New rooms default to the floor the player is currently viewing on the floor
    -- plan (which tracks the active floor), so marking a room upstairs files it
    -- upstairs without an extra step.
    pendingFloor = CH.fpViewedFloor or CH.activeFloor or 1
    pendingSetFloor = nil
    pendingFloorDelta = nil
    dialog.title:SetText(CH.L["RD_TITLE_NAME_ROOM"])
    editBox:SetText("")
    descBox:SetText("")
    headIdBox:SetText("")
    speakerBox:SetText("")
    ownerCheck:SetChecked(false)
    secretCheck:SetChecked(false)
    SetPendingVoice(nil)
    UpdateMainSwatch()
    RefreshHistorySwatches()
    BuildHeadPicker()
    UpdateHeadSelection()
    RefreshFloorRow()
    dialog:Show()
    editBox:SetFocus()
end

btnOK:SetScript("OnClick", ConfirmZone)
btnCancel:SetScript("OnClick", CloseDialog)
editBox:SetScript("OnEnterPressed", ConfirmZone)
editBox:SetScript("OnEscapePressed", CloseDialog)
