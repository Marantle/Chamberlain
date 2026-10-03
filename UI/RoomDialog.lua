local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room editor: name, colour, yapper, sounds and banner of one room
-- ─────────────────────────────────────────────────────────────────────
-- It lives in the house map, in the rail's place (3.33.0, a window of its
-- own before that), and the map holds still while it's open. The name and
-- colour sit on top with a live copy of the banner under them. The rest
-- sits on four tabs, Room, Yapper, Sound and Banner. The Banner tab puts the
-- style list where the map is.

local FP = CH.FP
local W, H = FP.EDIT_W, FP.RAIL_H
local LABEL_W = 90 -- the label column, the controls start after it
local PANE_W = W - 24
local PANE_TOP, PANE_BOTTOM = -142, 40
local PANE_H = H + PANE_TOP - PANE_BOTTOM

local dialog = FP.MakePanel("RD_TITLE_EDIT_ROOM")

local renameTarget = nil -- the zone in the editor
local renameHouseGUID = nil -- house the renamed zone belongs to (nil = current)
local pendingColor = nil -- color for the room being named; nil = default gold
local pendingHeadID = nil -- talking-head index for the room; nil/1 = default
local pendingVoice = nil -- TTS voice NAME for the room; nil = silent. Local-only.
local pendingAmbience = nil -- index into CH.AMBIENCE, nil = none
local pendingMusic = nil -- music file id, nil = none
local pendingSfx = nil -- file id of the sound on entry, nil = none
local pendingSfxPlays = nil -- see SetPendingSfx
local pendingEcho = nil -- how far the others hear the sound on entry, see CH.SendEcho
local pendingTapering = nil -- the sound plays as its kit and its echo fades, see CH.TAPERING
local pendingBannerStyle = nil -- the room's own banner style, nil for the house's

-- Which floor the room sits on, and whether it doubles as a stair anchor.
-- pendingSetFloor / pendingFloorDelta are mutually exclusive and both nil for an
-- ordinary room. The floor row is hidden unless the house has multiple floors.
local pendingFloor = 1
local pendingSetFloor = nil
local pendingFloorDelta = nil

-- The house this dialog is acting on: the renamed zone's house in edit mode, or
-- the house we're standing in when creating.
local function DialogGUID()
    return renameTarget and (renameHouseGUID or CH.currentHouseGUID) or CH.currentHouseGUID
end

local function DialogHouse()
    local guid = DialogGUID()
    return guid and ChamberlainDB.houses[guid]
end

-- ── Name, colour and the banner preview ─────────────────────────────

local mainSwatch = CH.MakeSwatch(dialog, 22)
mainSwatch:SetPoint("TOPLEFT", 12, -36)
CH.Tip(mainSwatch, "RD_TT_PICK_COLOR")

-- Copy from takes another room's settings, everything but the name, the
-- floor and the place, for a room that swaps looks with another.
local copyBtn = CH.MakeButton(dialog, "RD_COPY_FROM", 80, 22)
copyBtn:SetPoint("TOPRIGHT", -12, -36)
CH.Tip(copyBtn, "RD_TT_COPY_FROM")

local editBox = CreateFrame("EditBox", "ChamberlainEditBox", dialog, "InputBoxTemplate")
editBox:SetHeight(22)
editBox:SetPoint("LEFT", mainSwatch, "RIGHT", 12, 0)
editBox:SetPoint("RIGHT", copyBtn, "LEFT", -8, 0)
editBox:SetAutoFocus(false)
editBox:SetMaxLetters(48)

-- The real banner (Housing/Banner.lua) in the style the room will show,
-- shrunk to fit, so a colour pick shows what walking in will look like.
local preview = CreateFrame("Frame", nil, dialog)
preview:SetPoint("TOPLEFT", 12, -66)
preview:SetPoint("TOPRIGHT", -12, -66)
preview:SetHeight(38)
local previewBanner = CH.MakeBanner(preview)
previewBanner:SetPoint("CENTER")

-- Paint b at up to scale, smaller for a long name in a wide style or a tall
-- style so it stays inside its frame.
local function PaintPreview(b, scale)
    local style = pendingBannerStyle or CH.RoomBannerStyle(DialogGUID())
    CH.PaintBanner(b, editBox:GetText(), pendingColor, false, style)
    local f = b:GetParent()
    CH.FitBanner(b, scale, f:GetHeight(), f:GetWidth())
end

local UpdateBannerTab -- set once the Banner tab exists
local function UpdatePreview()
    PaintPreview(previewBanner, 0.62)
    UpdateBannerTab()
end
editBox:HookScript("OnTextChanged", UpdatePreview)

local function SetPendingColor(c)
    pendingColor = c and { c[1], c[2], c[3] } or nil
    if pendingColor then
        mainSwatch:SetBackdropColor(pendingColor[1], pendingColor[2], pendingColor[3], 1)
    else
        mainSwatch:SetBackdropColor(CH.RGBA(CH.COLORS.grey, 1)) -- "default" grey
    end
    UpdatePreview()
end

mainSwatch:SetScript("OnClick", function()
    local old = pendingColor
    ColorPickerFrame:SetupColorPickerAndShow({
        r = old and old[1] or 1,
        g = old and old[2] or 0.85,
        b = old and old[3] or 0.25,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SetPendingColor({ r, g, b })
        end,
        cancelFunc = function()
            SetPendingColor(old)
        end,
    })
end)

-- ── Tabs ─────────────────────────────────────────────────────────────

local panes = {}
local function Pane()
    local p = CreateFrame("Frame", nil, dialog)
    p:SetPoint("TOPLEFT", 12, PANE_TOP)
    p:SetPoint("BOTTOMRIGHT", -12, PANE_BOTTOM)
    p:Hide()
    panes[#panes + 1] = p
    return p
end
local paneRoom, paneYapper, paneSound, paneBanner = Pane(), Pane(), Pane(), Pane()

local function ShowPane(i)
    for n, p in ipairs(panes) do
        p:SetShown(n == i)
    end
end

local tabs = CH.MakeTabs(dialog, { "RD_TAB_ROOM", "RD_TAB_YAPPER", "RD_TAB_SOUND", "RD_TAB_BANNER" }, ShowPane)
tabs:SetPoint("TOPLEFT", 12, -110)
tabs:SetPoint("TOPRIGHT", -12, -110)

-- The help on a field's hover: the gold title, a white lead line when there
-- is one and the finer print in grey under it.
local function AttachHelp(owner, titleKey, leadKey, keys)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CH.L[titleKey], unpack(CH.COLORS.tipGold))
        if leadKey then
            GameTooltip:AddLine(CH.L[leadKey], 1, 1, 1, true)
            GameTooltip:AddLine(" ")
        end
        for _, k in ipairs(keys) do
            GameTooltip:AddLine(CH.L[k], 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- A field label in the left column. With help keys it gets a faint line under
-- it and the help on hover. FontStrings take no mouse events, so an invisible
-- button over the label catches the hover.
local function Label(parent, key, y, titleKey, ...)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 0, y)
    label:SetWidth(LABEL_W - 6)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(CH.L[key])
    label:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
    if titleKey then
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
        line:SetWidth(math.min(label:GetStringWidth(), LABEL_W - 6))
        line:SetColorTexture(CH.RGBA(CH.COLORS.border, 0.6))
        local hot = CreateFrame("Button", nil, parent)
        hot:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
        hot:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, -3)
        AttachHelp(hot, titleKey, nil, { ... })
    end
    return label
end

-- A tick box with its label, a grey line under it and the long help on hover.
local function MakeCheck(parent, labelKey, hintKey, titleKey, leadKey, ...)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", check, "TOPRIGHT", 2, -5)
    label:SetText(CH.L[labelKey])
    if hintKey then
        local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
        hint:SetWidth(PANE_W - 30)
        hint:SetJustifyH("LEFT")
        hint:SetText(CH.L[hintKey])
        hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    end
    AttachHelp(check, titleKey, leadKey, { ... })
    return check
end

-- Grey placeholder text in an edit box while it's empty and unfocused. text()
-- gives the words, looked up again on every change.
local function AddPlaceholder(box, text)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "LEFT", 6, 0)
    hint:SetPoint("RIGHT", box, "RIGHT", -6, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    local function update()
        hint:SetText(text())
        hint:SetShown(box:GetText() == "" and not box:HasFocus())
    end
    box:HookScript("OnEditFocusGained", update)
    box:HookScript("OnEditFocusLost", update)
    box:HookScript("OnTextChanged", update)
    return update
end

local function MakeBox(parent, w, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return box
end

-- ── Room tab ─────────────────────────────────────────────────────────

Label(paneRoom, "RD_COLOR", -2)

-- The map's own palette comes first, then your last colours and the clear swatch.
local SWATCH = 16
local paletteSwatches, historySwatches = {}, {}
local function PickSwatch(self)
    SetPendingColor(self.color)
end
for i = 1, 8 do
    local s = CH.MakeSwatch(paneRoom, SWATCH)
    s:SetPoint("TOPLEFT", (i - 1) * (SWATCH + 4), -18)
    s:SetScript("OnClick", PickSwatch)
    paletteSwatches[i] = s
end
local swatchDivider = paneRoom:CreateTexture(nil, "ARTWORK")
swatchDivider:SetSize(1, 14)
swatchDivider:SetPoint("LEFT", paletteSwatches[8], "RIGHT", 5, 0)
swatchDivider:SetColorTexture(CH.RGBA(CH.COLORS.border, 0.6))
for i = 1, 5 do
    local s = CH.MakeSwatch(paneRoom, SWATCH)
    s:SetPoint("LEFT", paletteSwatches[8], "RIGHT", 10 + (i - 1) * (SWATCH + 4), 0)
    s:SetScript("OnClick", PickSwatch)
    s:Hide()
    historySwatches[i] = s
end

local clearSwatch = CH.MakeSwatch(paneRoom, SWATCH)
clearSwatch:SetBackdropColor(0, 0, 0, 0.6)
local clearX = clearSwatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
clearX:SetPoint("CENTER")
clearX:SetText("x")
clearX:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
clearSwatch:SetScript("OnClick", function()
    SetPendingColor(nil)
end)
CH.Tip(clearSwatch, "RD_TT_CLEAR_COLOR")

local function RefreshSwatches()
    for i, s in ipairs(paletteSwatches) do
        s.color = CH.FP.PALETTE[i]
        s:SetBackdropColor(s.color[1], s.color[2], s.color[3], 1)
    end
    local list = ChamberlainDB.recentColors or {}
    local last = paletteSwatches[8]
    for i, s in ipairs(historySwatches) do
        local c = list[i]
        s.color = c
        if c then
            s:SetBackdropColor(c[1], c[2], c[3], 1)
            last = s
        end
        s:SetShown(c ~= nil)
    end
    clearSwatch:ClearAllPoints()
    clearSwatch:SetPoint("LEFT", last, "RIGHT", 10, 0)
end

-- ── Shape row ────────────────────────────────────────────────────────
-- The same shapes as the build rail, in one row here. Picking another one rebuilds the
-- room at the game's size around its middle on Save, keeping everything else,
-- for a room whose real one got swapped.
local shapeRow = CreateFrame("Frame", nil, paneRoom)
shapeRow:SetPoint("TOPLEFT", 0, -48)
shapeRow:SetPoint("TOPRIGHT", 0, -48)
shapeRow:SetHeight(26)
Label(shapeRow, "RD_SHAPE", -7, "RD_SHAPE_TT_TITLE", "RD_SHAPE_TT1", "RD_SHAPE_TT2")

local pendingShape = nil -- a CH.SHAPES key, nil for a plain room
local shapeBtns = {}
local function RefreshShapeButtons()
    for i, e in ipairs(CH.SHAPE_LIST) do
        CH.SetButtonActive(shapeBtns[i], e.shape == pendingShape)
    end
end
for i, e in ipairs(CH.SHAPE_LIST) do
    local b = CH.MakeShapeButton(shapeRow, e, 26)
    b:SetPoint("TOPLEFT", LABEL_W + (i - 1) * 30, 0)
    b:SetScript("OnClick", function()
        pendingShape = e.shape
        RefreshShapeButtons()
    end)
    shapeBtns[i] = b
end

-- Give a room another shape: the game's box for it around the room's old
-- middle, facing the default way. A plain room keeps the box it had.
local function ChangeShape(zone, shape)
    zone.shape = shape
    zone.rot = nil
    if shape then
        local cx, cy = CH.ZoneCentre(zone)
        CH.BoxAbout(zone, cx, cy, CH.ShapeSize(shape))
    end
end

-- ── Floor row (multi-floor houses only) ──────────────────────────────
-- A "Floor N" dropdown that scopes the room to a floor, plus a "Stairs"
-- dropdown that turns the room into a stair anchor (absolute "Go to floor N" or
-- relative "Up/Down one").
local floorRow = CreateFrame("Frame", nil, paneRoom)
floorRow:SetPoint("TOPLEFT", 0, -84)
floorRow:SetPoint("TOPRIGHT", 0, -84)
floorRow:SetHeight(22)
floorRow:Hide()

Label(floorRow, "RD_FLOOR", -5)
local floorBtn = CH.MakeButton(floorRow, "", 100, 22)
floorBtn:SetPoint("TOPLEFT", LABEL_W, 0)
local stairsLabel = floorRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stairsLabel:SetPoint("LEFT", floorBtn, "RIGHT", 10, 0)
stairsLabel:SetText(CH.L["RD_STAIRS"])
stairsLabel:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
local stairsBtn = CH.MakeButton(floorRow, "RD_NOT_STAIRS", 100, 22)
stairsBtn:SetPoint("LEFT", stairsLabel, "RIGHT", 8, 0)
stairsBtn:SetPoint("RIGHT", floorRow, "RIGHT", 0, 0)

-- Floor check (Housing/FloorCheck.lua): the game room this room is linked
-- to. Under the floor row, or in its place in a house of one floor, so the
-- link is there before a second floor is.
local pendingGameRoom = nil
local linkRow = CreateFrame("Frame", nil, paneRoom)
linkRow:SetHeight(22)
Label(
    linkRow,
    "RD_FLOOR_CHECK",
    -5,
    "RD_FLOOR_CHECK_TT_TITLE",
    "RD_FLOOR_CHECK_TT1",
    "RD_FLOOR_CHECK_TT2",
    "RD_FLOOR_CHECK_TT3"
)
local linkBtn = CH.MakeButton(linkRow, "RD_LINK_ROOM", PANE_W - LABEL_W, 22)
linkBtn:SetPoint("TOPLEFT", LABEL_W, 0)

-- Remembered, it names the floor the floor check puts you on, which is the
-- room's own floor and follows the Floor button.
local function RefreshLinkText()
    linkBtn:SetText(pendingGameRoom and string.format(CH.L["RD_LINKED_X"], pendingFloor or 1) or CH.L["RD_LINK_ROOM"])
end

local function SetPendingGameRoom(room)
    pendingGameRoom = room
    RefreshLinkText()
end

-- The room is read on the click, so walking about with the dialog open is fine.
linkBtn:SetScript("OnClick", function()
    if pendingGameRoom then
        SetPendingGameRoom(nil)
        return
    end
    local room, stairwell
    if DialogGUID() == CH.currentHouseGUID then
        room, stairwell = CH.GameRoomHere()
    end
    if not room then
        CH.Print(CH.L["RD_LINK_NOT_HERE"])
        return
    end
    SetPendingGameRoom(room)
    if stairwell then
        CH.Print(CH.L["RD_LINK_STAIRWELL"])
    end
end)

local roomSep = CH.MakeRule(paneRoom)

-- "Banner": unticked, walking in shows nothing and the room stops counting as
-- the room you're in. With Secret and an ambience that makes a sound-only
-- spot, a hearth or a fountain, laid over a real room.
local bannerCheck = MakeCheck(
    paneRoom,
    "RD_BANNER",
    "RD_BANNER_TT1",
    "RD_BANNER_TT_TITLE",
    "RD_BANNER_TT1",
    "RD_BANNER_TT2",
    "RD_BANNER_TT3",
    "RD_BANNER_TT4"
)
bannerCheck:SetPoint("TOPLEFT", roomSep, "BOTTOMLEFT", -3, -8)

-- "Secret": keeps the room off visitors' floor plans and room lists, while still
-- sharing it so the banner and yapper fire when they walk in.
local secretCheck =
    MakeCheck(paneRoom, "RD_SECRET", "RD_SECRET_TT1", "RD_SECRET_TT_TITLE", "RD_SECRET_TT1", "RD_SECRET_TT2")
secretCheck:SetPoint("TOPLEFT", bannerCheck, "BOTTOMLEFT", 0, -30)

-- ── Yapper tab ───────────────────────────────────────────────────────

-- Head picker: a row of small 3D heads. Clicking one sets the room's headID.
-- The model is rendered locally from CH.HEADS, so only the index is stored.
local headButtons = {}
local UpdateSpeakerHint -- set once the speaker box exists
local function UpdateHeadSelection()
    for i, b in ipairs(headButtons) do
        if i == (pendingHeadID or 1) then
            b:SetBackdropBorderColor(0.95, 0.80, 0.25, 1)
        else
            b:SetBackdropBorderColor(0.40, 0.35, 0.20, 0.7)
        end
    end
    UpdateSpeakerHint()
end

local HEAD = 34
local HEADS_PER_ROW = 9
local function BuildHeadPicker()
    for i, head in ipairs(CH.HEADS) do
        local b = headButtons[i]
        if not b then
            b = CreateFrame("Button", nil, paneYapper, "BackdropTemplate")
            b:SetSize(HEAD, HEAD)
            b:SetBackdrop(CH.BACKDROP_THIN)
            b:SetBackdropColor(0, 0, 0, 0.6)
            local col, row = (i - 1) % HEADS_PER_ROW, math.floor((i - 1) / HEADS_PER_ROW)
            b:SetPoint("TOPLEFT", col * (HEAD + 5), -row * (HEAD + 5))
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

-- Everything under the heads starts below however many rows they take.
local yapperTop = -math.ceil(#CH.HEADS / HEADS_PER_ROW) * (HEAD + 5) - 2

-- "Use my head when I'm home": flags the room to show the house owner's own
-- character (when the owner is present) instead of a curated head. The tooltip
-- spells out the limits so they aren't a surprise: it follows the character you
-- tick it on (not your account), and visitors need to be grouped with you and
-- nearby to see it.
local ownerCheck = MakeCheck(
    paneYapper,
    "RD_USE_MY_HEAD",
    nil,
    "RD_USE_MY_HEAD",
    "RD_USE_MY_HEAD_TT1",
    "RD_USE_MY_HEAD_TT2",
    "RD_USE_MY_HEAD_TT3"
)
ownerCheck:SetPoint("TOPLEFT", -3, yapperTop)

-- Speaker name shown on the yapper (like the NPC name on Blizzard's box). When
-- set, it overides the picked head's name, useful with a custom display ID,
-- which has no name we can look up.
Label(paneYapper, "RD_SPEAKER", yapperTop - 34, "RD_SPEAKER_TT_TITLE", "RD_SPEAKER_TT1", "RD_SPEAKER_TT2")
local speakerBox = MakeBox(paneYapper, PANE_W - LABEL_W - 4, 40)
speakerBox:SetPoint("TOPLEFT", LABEL_W + 4, yapperTop - 30)

-- Trimmed speaker name, or nil when empty.
local function GetSpeaker()
    local s = speakerBox:GetText():match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end

-- The placeholder is the picked head's name, the fallback the yapper uses.
UpdateSpeakerHint = AddPlaceholder(speakerBox, function()
    local head = CH.HEADS[pendingHeadID or 1]
    return head and head.name or ""
end)

-- Voice picker: which OS text-to-speech voice reads this room's description in the
-- yapper. Stored per room as zone.voice and never exported or sent, since we
-- can't know which TTS voices another player's PC has. "Default (silent)"
-- means no narration. See Core/Voice.lua.
Label(paneYapper, "RD_VOICE", yapperTop - 62, "RD_VOICE_TT_TITLE", "RD_VOICE_TT1", "RD_VOICE_TT2")
local voiceTest = CH.MakeButton(paneYapper, "RD_TEST", 72, 22)
voiceTest:SetPoint("TOPRIGHT", 0, yapperTop - 57)
local voiceBtn = CH.MakeButton(paneYapper, "RD_DEFAULT_SILENT", 100, 22)
voiceBtn:SetPoint("TOPLEFT", LABEL_W, yapperTop - 57)
voiceBtn:SetPoint("TOPRIGHT", voiceTest, "TOPLEFT", -6, 0)

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

-- Description box: multi-line, capped, scrollable.
local DESC_MAX = 500
local descScroll, descBox = CH.MakeTextArea(paneYapper, "ChamberlainDescScroll", PANE_W - 24)
descScroll:SetPoint("TOPLEFT", 2, yapperTop - 90)
descScroll:SetPoint("BOTTOMRIGHT", -14, 42)
descBox:SetMaxLetters(DESC_MAX)
descBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

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
descHint:SetPoint("TOPRIGHT", -6, -6)
descHint:SetJustifyH("LEFT")
descHint:SetWordWrap(true)
descHint:SetText(CH.L["RD_DESC_HINT"])
local function UpdateDescHint()
    descHint:SetShown(descBox:GetText() == "" and not descBox:HasFocus())
end
descBox:HookScript("OnEditFocusGained", UpdateDescHint)
descBox:HookScript("OnEditFocusLost", UpdateDescHint)
descBox:HookScript("OnTextChanged", UpdateDescHint)

-- Trimmed description text, or nil when the box is empty.
local function GetDescText()
    local t = descBox:GetText():match("^%s*(.-)%s*$")
    return t ~= "" and t or nil
end

-- Quick custom display-ID box (testing): if filled, it overrides the picked
-- head. Most never need it, so it sits last.
local idRow = -(PANE_H - 30) -- the bottom row, under the description box
Label(paneYapper, "RD_CUSTOM_ID", idRow - 4, "RD_CUSTOM_ID_TT_TITLE", "RD_CUSTOM_ID_TT1", "RD_CUSTOM_ID_TT2")
local headIdBox = MakeBox(paneYapper, 140, 8)
headIdBox:SetPoint("TOPLEFT", LABEL_W + 4, idRow)
headIdBox:SetNumeric(true)
local UpdateHeadIdHint = AddPlaceholder(headIdBox, function()
    return CH.L["RD_CUSTOM_ID_HINT"]
end)

-- Custom display ID from the box, or nil when empty/zero.
local function GetHeadDisplay()
    local n = tonumber(headIdBox:GetText())
    return (n and n > 0) and n or nil
end

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

-- ── Sound tab ────────────────────────────────────────────────────────

-- Ambience picker: one of the game's own ambience loops for the room, stored
-- and shared as an index into CH.AMBIENCE. Test plays the pick until stopped.
Label(paneSound, "RD_AMBIENCE", -5, "RD_AMBIENCE_TT_TITLE", "RD_AMBIENCE_TT1", "RD_AMBIENCE_TT2")

local previewing = false
local ambienceTest = CH.MakeButton(paneSound, "RD_TEST", 72, 22)
ambienceTest:SetPoint("TOPRIGHT", 0, 0)

local function MarkPreviewing(on)
    previewing = on
    ambienceTest:SetText(on and CH.L["RD_STOP_TEST"] or CH.L["RD_TEST"])
end

local function SetPreviewing(on)
    MarkPreviewing(on)
    CH.PreviewAmbience(on and pendingAmbience or nil)
end

-- The open menu plays what gets clicked in it, so this only keeps the Test
-- button's label honest. Closing the menu ends the preview.
local function PickAmbience(btn, index)
    pendingAmbience = index
    btn:Refresh()
    MarkPreviewing(index ~= nil)
end

local ambienceBtn = CH.MakeMenuButton(paneSound, 100, "RD_AMBIENCE_NONE", function()
    return pendingAmbience and CH.L[CH.AMBIENCE[pendingAmbience].key]
end, function(root, btn)
    root:CreateTitle(CH.L["RD_AMBIENCE_PICK"])
    CH.FillAmbienceMenu(root, function()
        return pendingAmbience
    end, function(index)
        PickAmbience(btn, index)
    end)
end, function()
    SetPreviewing(false)
end)
ambienceBtn:SetPoint("TOPLEFT", LABEL_W, 0)
ambienceBtn:SetPoint("TOPRIGHT", ambienceTest, "TOPLEFT", -6, 0)

ambienceTest:SetScript("OnClick", function()
    if not previewing and not pendingAmbience then
        CH.Print(CH.L["RD_PICK_AMBIENCE"])
        return
    end
    SetPreviewing(not previewing)
end)

-- Music picker: a track that takes over from the game's music while you're in
-- the room. Only the file id is stored and shared. The button opens the search
-- window (UI/MusicPicker.lua), which has the preview.
--
-- The sound on entry is its own pick on the row under it. Any game sound goes
-- by file id, played on the effects channel once or a few times as you walk
-- in or looped over the music. Same window, opened for sounds.
local function MakeSoundRow(y, labelKey, ttKey)
    Label(paneSound, labelKey, y - 5, ttKey .. "_TITLE", ttKey .. "1", ttKey .. "2")
    local btn = CH.MakeButton(paneSound, "RD_AMBIENCE_NONE", PANE_W - LABEL_W, 22)
    btn:SetPoint("TOPLEFT", LABEL_W, y)
    return btn
end

local musicBtn = MakeSoundRow(-30, "RD_MUSIC", "RD_MUSIC_TT")
local sfxBtn = MakeSoundRow(-60, "RD_SFX", "RD_SFX_TT")

local function SetPendingMusic(id)
    pendingMusic = id
    musicBtn:SetText(id and CH.SoundName(id, true) or CH.L["RD_AMBIENCE_NONE"])
end

-- plays as in ReadRoomSounds (Sharing/Share.lua). The button shows a count as
-- "x3" and an echo behind it.
local function SetPendingSfx(id, plays, echo, tapering)
    pendingSfx, pendingSfxPlays, pendingEcho = id, plays, id and echo
    pendingTapering = id and tapering or nil
    local text = CH.L["RD_AMBIENCE_NONE"]
    if id then
        text = CH.SoundName(id, true)
        if pendingTapering then
            text = string.format(CH.L["MP_TAPERING_X"], text)
        end
        if plays > 0 then
            text = text .. "  x" .. plays
        end
        if echo then
            text = text .. "  " .. CH.EchoText(echo)
        end
    end
    sfxBtn:SetText(text)
end

musicBtn:SetScript("OnClick", function()
    CH.OpenMusicPicker(pendingMusic, SetPendingMusic, DialogHouse())
end)
sfxBtn:SetScript("OnClick", function()
    CH.OpenMusicPicker(pendingSfx, SetPendingSfx, DialogHouse(), true, pendingSfxPlays, pendingEcho, pendingTapering)
end)

-- ── Banner tab ───────────────────────────────────────────────────────

-- The room's own banner style, over the house's. It goes out with the map
-- onyl, never as a patch of its own. The list of styles takes the map's
-- place while this tab is open (UI/BannerPicker.lua). A room with Banner
-- unticked on the Room tab shows none, so the list stays away for it.
local styleName = paneBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
styleName:SetPoint("TOPLEFT", 2, -6)
local styleNote = paneBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
styleNote:SetPoint("TOPLEFT", styleName, "BOTTOMLEFT", 0, -3)
styleNote:SetWidth(PANE_W - 4)
styleNote:SetJustifyH("LEFT")
styleNote:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local bannerHint = paneBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bannerHint:SetPoint("TOPLEFT", styleNote, "BOTTOMLEFT", 0, -14)
bannerHint:SetWidth(PANE_W - 4)
bannerHint:SetJustifyH("LEFT")
bannerHint:SetSpacing(2)
bannerHint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local roomPick = {
    done = function(style)
        pendingBannerStyle = style
        UpdatePreview()
    end,
}

UpdateBannerTab = function()
    local on = bannerCheck:GetChecked()
    local name, note = CH.BannerPickText(pendingBannerStyle, true)
    styleName:SetText(name)
    styleNote:SetText(note)
    bannerHint:SetText(CH.L[on and "RD_BANNER_STYLE_HINT" or "RD_BANNER_STYLE_OFF"])
    if on and paneBanner:IsVisible() then
        roomPick.style = pendingBannerStyle
        CH.ShowRoomBannerPicker(DialogGUID(), roomPick)
    else
        CH.HideRoomBannerPicker()
    end
end
bannerCheck:HookScript("OnClick", UpdateBannerTab)
paneBanner:SetScript("OnShow", UpdateBannerTab)
paneBanner:SetScript("OnHide", UpdateBannerTab)

-- ── Floor row behaviour ──────────────────────────────────────────────

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
    RefreshLinkText()
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

-- The line and the ticks follow whichever row is last.
local function RefreshFloorRow()
    local h = DialogHouse()
    local multi = h and (h.floorCount or 1) > 1
    floorRow:SetShown(multi)
    if multi then
        RefreshFloorButtons()
    end
    local gap = multi and -8 or 0
    local edge = multi and "BOTTOM" or "TOP"
    linkRow:ClearAllPoints()
    linkRow:SetPoint("TOPLEFT", floorRow, edge .. "LEFT", 0, gap)
    linkRow:SetPoint("TOPRIGHT", floorRow, edge .. "RIGHT", 0, gap)
    roomSep:ClearAllPoints()
    roomSep:SetPoint("TOPLEFT", linkRow, "BOTTOMLEFT", 0, -12)
    roomSep:SetWidth(PANE_W)
end

-- ── Footer ───────────────────────────────────────────────────────────

-- The row of buttons, and the question that takes its place when you try to
-- leave with changes that aren't saved.
local ConfirmZone -- set below
local foot = FP.PanelFooter(dialog, "RD_SAVE", function()
    ConfirmZone()
end)

-- The same delete as the Build toolbox's trash, so Undo delete works after it.
-- Any unsaved edit goes with the room.
local deleteBtn = CH.MakeButton(foot, "RD_DELETE_ROOM", 100, 22)
deleteBtn:SetPoint("LEFT")
deleteBtn:SetScript("OnClick", function()
    local z, guid = renameTarget, DialogGUID()
    FP.ClosePanel()
    CH.DeleteRoom(z, guid)
end)

local ask = CreateFrame("Frame", nil, dialog)
ask:SetAllPoints(foot)
ask:Hide()
local askSave = CH.MakeButton(ask, "RD_SAVE", 60, 22)
local askStay = CH.MakeButton(ask, "RD_KEEP_EDITING", 90, 22)
local askDrop = CH.MakeButton(ask, "RD_DISCARD", 80, 22)
askSave:SetPoint("RIGHT")
askStay:SetPoint("RIGHT", askSave, "LEFT", -6, 0)
askDrop:SetPoint("RIGHT", askStay, "LEFT", -6, 0)
CH.SetButtonActive(askSave, true)
local askText = ask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
askText:SetPoint("LEFT")
askText:SetPoint("RIGHT", askDrop, "LEFT", -6, 0)
askText:SetJustifyH("LEFT")
askText:SetText(CH.L["RD_LEAVE_ASK"])

local function Asking(on)
    ask:SetShown(on)
    foot:SetShown(not on)
end

-- Fill the fields with a room's settings: its colour, its yapper, its sounds
-- and its ticks. The name, the shape, the floor and the stairs are its own
-- and stay, so Copy from can use this too.
local function FillSettings(zone)
    pendingHeadID = zone.headID or 1
    pendingBannerStyle = zone.bannerStyle
    descBox:SetText(zone.rpText or "")
    headIdBox:SetText(zone.headDisplay and tostring(zone.headDisplay) or "")
    speakerBox:SetText(zone.speaker or "")
    ownerCheck:SetChecked(zone.useOwnerHead)
    secretCheck:SetChecked(zone.secret)
    bannerCheck:SetChecked(not zone.noBanner)
    SetPendingColor(zone.color) -- repaints both banners, so it comes after the Banner tick
    pendingAmbience = zone.ambience
    ambienceBtn:Refresh()
    SetPendingMusic(zone.music)
    SetPendingSfx(zone.sfx, zone.sfxPlays, zone.echo, zone.tapering)
    SetPendingVoice(zone.voice)
    UpdateHeadSelection()
    UpdateHeadIdHint()
    UpdateDescHint()
end

-- What Save writes onto the room, as the fields stand now. The name and the
-- shape need more than a copy on Save, so they sit outside SAVED.
local SAVED = {
    "color",
    "headID",
    "headDisplay",
    "speaker",
    "useOwnerHead",
    "rpText",
    "secret",
    "noBanner",
    "bannerStyle",
    "ambience",
    "music",
    "sfx",
    "sfxPlays",
    "echo",
    "tapering",
    "voice",
    "floor",
    "setFloor",
    "floorDelta",
    "gameRoom",
}

local function Pending()
    return {
        name = editBox:GetText():match("^%s*(.-)%s*$"),
        shape = pendingShape,
        color = pendingColor,
        headID = pendingHeadID or 1,
        headDisplay = GetHeadDisplay(),
        speaker = GetSpeaker(),
        useOwnerHead = ownerCheck:GetChecked() or nil,
        rpText = GetDescText(),
        secret = secretCheck:GetChecked() or nil,
        noBanner = not bannerCheck:GetChecked() or nil,
        bannerStyle = pendingBannerStyle,
        ambience = pendingAmbience,
        music = pendingMusic,
        sfx = pendingSfx,
        sfxPlays = pendingSfxPlays,
        echo = pendingEcho,
        tapering = pendingTapering,
        voice = pendingVoice,
        floor = pendingFloor or 1,
        setFloor = pendingSetFloor,
        floorDelta = pendingFloorDelta,
        gameRoom = pendingGameRoom,
    }
end

-- The fields as they were when the room opened, to tell whether leaving
-- throws somthing away.
local opened

local function Changed()
    return not tCompare(Pending(), opened, 2) -- 2 reaches into the colour
end

-- Whichever way the editor closes, the tests stop and the boxes let go.
dialog:SetScript("OnHide", function()
    editBox:ClearFocus()
    descBox:ClearFocus()
    headIdBox:ClearFocus()
    speakerBox:ClearFocus()
    if testing then
        CH.StopSpeaking()
    end -- don't keep narrating after the dialog closes
    SetTesting(false)
    SetPreviewing(false)
    Asking(false)
    renameTarget = nil
    renameHouseGUID = nil
end)

local leaveAfter -- what to do once the question is answered

local panel = { frame = dialog }

-- A map build checks the room is still there to edit: a delete somewhere
-- else, or the map moving to another house, ends the edit unsaved.
function panel.check()
    local h = DialogHouse()
    if DialogGUID() ~= FP.HouseGUID() or not (h and tIndexOf(h.zones, renameTarget)) then
        FP.ClosePanel(true)
    end
end

-- Leaving asks first when something changed.
function panel.leave(after)
    if Changed() then
        leaveAfter = after
        Asking(true)
        return
    end
    FP.ClosePanel()
    if after then
        after()
    end
end

local function Answer(save)
    local after = leaveAfter
    leaveAfter = nil
    if save then
        ConfirmZone()
        if renameTarget then
            return -- the save was refused and chat says why
        end
    else
        FP.ClosePanel()
    end
    if after then
        after()
    end
end

askSave:SetScript("OnClick", function()
    Answer(true)
end)
askDrop:SetScript("OnClick", function()
    Answer(false)
end)
askStay:SetScript("OnClick", function()
    leaveAfter = nil
    Asking(false)
end)

-- Opens a room in the editor, in the map of its house. Used by the floor plan
-- and the room manager. houseGUID is optional: when the zone belongs to a
-- house you aren't standing in, pass it so the edit lands on the right house.
-- nil falls back to the current house.
function CH.OpenRenameDialog(zone, houseGUID)
    -- Stair anchors get a stripped editor (name, floor, behaviour) instead of the
    -- full room dialog, which has yapper/description/voice/secret they never use.
    if CH.IsAnchor(zone) and CH.OpenAnchorEditor then
        if not CH.RefuseLocked() then
            CH.OpenAnchorEditor(zone, houseGUID)
        end
        return
    end
    houseGUID = houseGUID or CH.currentHouseGUID
    if zone == renameTarget then
        return
    elseif FP.panel then
        FP.LeavePanel(function()
            CH.OpenRenameDialog(zone, houseGUID)
        end)
        return
    end
    if not FP.win:IsShown() or FP.HouseGUID() ~= houseGUID then
        CH.OpenFloorPlan(houseGUID)
    end
    renameTarget = zone
    renameHouseGUID = houseGUID
    pendingFloor = zone.floor or 1
    pendingSetFloor = zone.setFloor
    pendingFloorDelta = zone.floorDelta
    pendingShape = zone.shape
    SetPendingGameRoom(zone.gameRoom)
    editBox:SetText(zone.name)
    RefreshSwatches()
    BuildHeadPicker()
    FillSettings(zone)
    RefreshShapeButtons()
    RefreshFloorRow()
    opened = Pending()
    -- Locked, the dialog is the Sound tab (3) alone, so a save can only change
    -- what goes to the group as a patch.
    local locked = CH.LayoutLocked()
    local tab = locked and 3 or 1
    tabs:SetShown(not locked)
    tabs:Select(tab)
    ShowPane(tab)
    editBox:SetEnabled(not locked)
    mainSwatch:SetShown(not locked)
    copyBtn:SetShown(not locked)
    deleteBtn:SetShown(not locked)
    Asking(false)
    -- the map shows the floor the room is on and holds there
    CH.fpViewedFloor = pendingFloor
    FP.OpenPanel(panel, zone)
    if not locked then
        editBox:SetFocus()
        editBox:HighlightText()
    end
end

-- The rooms of this house Copy from can take settings from: every room but
-- this one and the stairs.
copyBtn:SetScript("OnClick", function(self)
    if not MenuUtil then
        return
    end
    local h = DialogHouse()
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(CH.L["RD_COPY_FROM_TITLE"])
        local any = false
        for _, z in ipairs(h and h.zones or {}) do
            if z ~= renameTarget and not CH.IsAnchor(z) then
                any = true
                root:CreateButton(z.name, function()
                    FillSettings(z)
                end)
            end
        end
        if not any then
            root:CreateButton(CH.L["TB_NO_ROOMS"]):SetEnabled(false)
        end
    end)
end)

ConfirmZone = function()
    local p = Pending()
    local name = p.name
    if name == "" then
        CH.Print(CH.L["RD_ENTER_NAME"])
        return
    end

    if renameTarget then
        local guid = renameHouseGUID or CH.currentHouseGUID
        local h = guid and ChamberlainDB.houses[guid]
        if h then
            local before = CopyTable(renameTarget)
            local baseTs, ownerGUID = h.updatedAt, h.ownerGUID
            -- Carry the room's time stats over to the new name
            if h.stats and h.stats[renameTarget.name] then
                h.stats[name] = (h.stats[name] or 0) + h.stats[renameTarget.name]
                h.stats[renameTarget.name] = nil
            end
            renameTarget.name = name
            -- the banner style has no patch, so a new one makes the group pull
            -- the map, and the voice never leaves this client
            for _, k in ipairs(SAVED) do
                renameTarget[k] = p[k]
            end
            -- Stamp our current character GUID once on the house (not per room) so
            -- visitors can match us in their party even on an alt whose name differs
            -- from the stored buyer name. Only when we own the house we're standing in.
            if renameTarget.useOwnerHead and CH.isOwnHouse then
                h.ownerGUID = UnitGUID("player")
            end
            if pendingShape ~= renameTarget.shape then
                ChangeShape(renameTarget, pendingShape)
            end
            CH.PushRecentColor(pendingColor)
            CH.TouchHouse(guid)
            -- A save that changed the sounds and nothing else goes to the group
            -- as a patch. Anything more and they have to pull the map, since a
            -- patch would stamp their copy current with the old name still on it.
            -- voice never leaves this client so it doesn't count as a change.
            -- The sound on entry goes first. A client from before 3.12.0 skips
            -- that patch, so the ones behind it no longer fit its copy and it
            -- pulls the whole map, where last in line it would have been
            -- stamped current without the sound.
            local changed = {}
            if
                before.sfx ~= pendingSfx
                or before.sfxPlays ~= pendingSfxPlays
                or before.echo ~= pendingEcho
                or before.tapering ~= pendingTapering
            then
                changed[#changed + 1] = "sfx"
            end
            if before.ambience ~= pendingAmbience then
                changed[#changed + 1] = "ambience"
            end
            if before.music ~= pendingMusic then
                changed[#changed + 1] = "music"
            end
            before.ambience, before.voice = pendingAmbience, pendingVoice
            before.music = pendingMusic
            before.sfx, before.sfxPlays, before.echo = pendingSfx, pendingSfxPlays, pendingEcho
            before.tapering = pendingTapering
            if #changed > 0 and h.ownerGUID == ownerGUID and tCompare(before, renameTarget, 2) then
                local target = "R" .. tIndexOf(h.zones, renameTarget)
                for i, kind in ipairs(changed) do
                    local sfx = kind == "sfx"
                    CH.SendSoundPatch(
                        guid,
                        kind,
                        baseTs,
                        target,
                        renameTarget[kind],
                        i > 1,
                        sfx and pendingSfxPlays or nil,
                        sfx and pendingEcho or nil,
                        sfx and pendingTapering or nil
                    )
                    -- the next patch builds on this one
                    baseTs = h.updatedAt
                end
            end
        end
    end
    FP.ClosePanel()
end

-- Drop a new room at a world position. This is the build rail's "add room
-- here": it makes a room centred on (x, y) at the game's own size for its
-- shape (the smallest square for a plain room), moves it onto the nearest
-- open door in DROP_REACH when Snap is on (CH.FitToOpenDoor), files it under
-- the current house, and returns the zone and its house guid so the caller can select it
-- and open this dialog to name it. shape is a CH.SHAPES key or nil for a
-- rectangle. Without a name it's named after its shape. Replaces the old
-- Mark A/B flow. Past the reach it lands at your feet, since a door across
-- the house is hardly ever the one you meant.
local DROP_REACH = 50

function CH.CreateZoneAt(x, y, mapID, shape, name)
    if not CH.currentHouseGUID then
        CH.Print(CH.L["RD_HOUSE_NOT_IDENTIFIED"])
        return
    end
    local h = CH.CurrentHouse()
    local z = CH.NewZone(h, x, y, mapID, shape, name)
    if ChamberlainDB.settings.snapRooms and not CH.FitToOpenDoor(h, z, x, y, nil, DROP_REACH) then
        CH.SnapToGrid(z)
    end
    table.insert(h.zones, z)
    CH.TouchHouse(CH.currentHouseGUID)
    return z, CH.currentHouseGUID
end

-- A fresh room for house h centred on (x, y), not filed yet. size is the side
-- of a square box and overrides the shape's own.
function CH.NewZone(h, x, y, mapID, shape, name, size)
    local def = CH.SHAPES[shape]
    local bw, bh = CH.SQUARE_SIZES[1][2], CH.SQUARE_SIZES[1][2]
    if size then
        bw, bh = size, size
    elseif def then
        bw, bh = def.w, def.h
    end
    -- Named after its shape and how many of that shape the hosue has, so the
    -- third round room is Round room 3. Stairs don't count.
    local nth = 1
    for _, z in ipairs(h.zones) do
        if z.shape == shape and not CH.IsAnchor(z) then
            nth = nth + 1
        end
    end
    -- New rooms land on the floor the player is viewing (which tracks the active
    -- floor), so dropping one upstairs files it upstairs.
    local z = {
        name = name and CH.FreeName(h, name) or CH.FreeName(h, CH.ShapeName(shape), nth),
        mapID = mapID,
        shape = def and shape or nil,
        floor = CH.MapFloor(),
    }
    CH.BoxAbout(z, x, y, bw, bh)
    return z
end

editBox:SetScript("OnEnterPressed", ConfirmZone)
editBox:SetScript("OnEscapePressed", function()
    FP.LeavePanel()
end)
