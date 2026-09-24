local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Settings window  (pages down the side, a switch per setting)
-- ─────────────────────────────────────────────────────────────────────
-- Opened by the gear on the bar or /rooms settings. Each page is a column of
-- rows. A row is the setting's name with a line of help under it and its
-- switch or slider on the right. Moved out of RoomManager.lua in 3.17.0, when
-- one long column of ON/OFF buttons got too tall for small screens.

local W, H = 500, 460
local NAV_W = 128
local PAGE_W = W - NAV_W - 33

local win = CreateFrame("Frame", "ChamberlainSettings", UIParent, "BackdropTemplate")
win:SetSize(W, H)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:SetPoint("CENTER")
CH.MakeDraggable(win)
CH.SkinWindow(win, "SET_WINDOW_TITLE")
win:Hide()
table.insert(UISpecialFrames, "ChamberlainSettings")

local closeBtn = CH.MakeGlyphButton(win, "x")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    win:Hide()
end)

local nav = CreateFrame("Frame", nil, win)
nav:SetPoint("TOPLEFT", 1, -26)
nav:SetPoint("BOTTOMLEFT", 1, 1)
nav:SetWidth(NAV_W)

local navLine = nav:CreateTexture(nil, "ARTWORK")
navLine:SetWidth(1)
navLine:SetPoint("TOPRIGHT")
navLine:SetPoint("BOTTOMRIGHT")
navLine:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.35))

-- A word from the author, tucked down here so it never nags anyone. It stays
-- invisible until the mouse finds it.
local thanksBtn = CH.MakeButton(nav, "CT_BUTTON", NAV_W - 20, 22)
thanksBtn:SetPoint("BOTTOMLEFT", 10, 10)
thanksBtn:SetAlpha(0)
thanksBtn:HookScript("OnEnter", function(self)
    self:SetAlpha(1)
end)
thanksBtn:HookScript("OnLeave", function(self)
    self:SetAlpha(0)
end)
thanksBtn:SetScript("OnClick", function()
    win:Hide()
    CH.OpenCreatorThanks()
end)

-- ── Pieces ───────────────────────────────────────────────────────────

-- Every row's refresh, run when the window opens.
local refreshers = {}

-- svg art with a flat white square for 12.0, both tinted the same way.
local function Art(parent, file, w, h, layer)
    local a = CH.MakeIcon(parent, file, w, layer)
    if not a then
        a = parent:CreateTexture(nil, layer)
        a:SetColorTexture(1, 1, 1, 1)
    end
    a:SetSize(w, h)
    return a
end

-- The on/off switch, a track with the knob on the right while on.
local function MakeSwitch(parent)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(30, 16)
    s:SetHitRectInsets(-6, -6, -6, -6)
    s.track = Art(s, "switch-track", 30, 16, "ARTWORK")
    s.track:SetPoint("CENTER")
    s.knob = Art(s, "switch-knob", 12, 12, "OVERLAY")
    function s:SetOn(on)
        self.knob:ClearAllPoints()
        if on then
            self.track:SetVertexColor(CH.RGBA(CH.COLORS.border, 1))
            self.knob:SetVertexColor(1, 1, 1)
            self.knob:SetPoint("RIGHT", -2, 0)
        else
            self.track:SetVertexColor(0.16, 0.14, 0.09)
            self.knob:SetVertexColor(0.47, 0.47, 0.47)
            self.knob:SetPoint("LEFT", 2, 0)
        end
    end
    return s
end

-- A page on the right, filled top down. y is how far down the next row goes.
-- navKey names it in the side column, when that's shorter than its title.
local pages = {}
local function Page(titleKey, navKey)
    local p = CreateFrame("Frame", nil, win)
    p.navKey = navKey or titleKey
    p:SetPoint("TOPLEFT", NAV_W + 17, -36)
    p:SetPoint("BOTTOMRIGHT", -16, 10)
    p:Hide()
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT")
    title:SetText(CH.L[titleKey])
    title:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    p.y = 22
    pages[#pages + 1] = p
    return p
end

-- A setting's name with its line of help and a faint rule under the row.
-- controlW is the room kept on the right for the switch or slider, and indent
-- tucks the row under the one it belongs to.
local function Row(page, labelKey, hintKey, controlW, indent)
    local x = indent and 16 or 0
    local textW = PAGE_W - x - controlW - 10
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", x, -page.y)
    row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -page.y)

    local label = row:CreateFontString(nil, "OVERLAY", hintKey and "GameFontHighlight" or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 0, -8)
    label:SetWidth(textW)
    label:SetJustifyH("LEFT")
    label:SetText(CH.L[labelKey])
    local h = 26
    if hintKey then
        local hint = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
        hint:SetWidth(textW)
        hint:SetJustifyH("LEFT")
        hint:SetText(CH.L[hintKey])
        hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
        h = 8 + label:GetStringHeight() + 3 + hint:GetStringHeight() + 8
    end
    row:SetHeight(h)

    local rule = CH.MakeRule(row, 0.18)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    page.y = page.y + h
    return row
end

-- A row with a switch over the boolean settings[key]. onChange runs after a flip.
local function SwitchRow(page, labelKey, hintKey, key, onChange, indent, tipKey)
    local row = Row(page, labelKey, hintKey, 30, indent)
    local sw = MakeSwitch(row)
    sw:SetPoint("RIGHT")
    row.Refresh = function()
        sw:SetOn(ChamberlainDB.settings[key])
    end
    sw:SetScript("OnClick", function()
        ChamberlainDB.settings[key] = not ChamberlainDB.settings[key]
        row.Refresh()
        if onChange then
            onChange()
        end
    end)
    if tipKey then
        CH.Tip(sw, tipKey)
    end
    refreshers[#refreshers + 1] = row.Refresh
    return row
end

-- A row with a slider for a number of seconds kept in settings[s.key], from
-- s.min to s.max in steps of s.step. s.off is the text for zero.
local function SecondsRow(page, s)
    local row = Row(page, s.label, s.hint, 156, s.indent)
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT")
    value:SetWidth(58)
    value:SetJustifyH("LEFT")
    value:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
    local slider = CH.MakeSlider(row, 90, s.min, s.max, s.step)
    slider:SetPoint("RIGHT", value, "LEFT", -8, 0)
    if s.tip then
        CH.Tip(slider, s.tip)
    end

    local function show(v)
        value:SetText(v <= 0 and CH.L[s.off] or string.format(CH.L["RM_SECONDS_X"], v))
    end
    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        ChamberlainDB.settings[s.key] = v
        show(v)
    end)
    refreshers[#refreshers + 1] = function()
        local v = ChamberlainDB.settings[s.key]
        slider:SetValue(v)
        show(v)
    end
    return row
end

-- ── Rooms ────────────────────────────────────────────────────────────
local pageRooms = Page("RM_SECTION_ROOMS")

-- Turns the gold banner off for players who only want the map. It stays on
-- this client. Flipping it off drops any banner that's up.
SwitchRow(pageRooms, "RM_TOGGLE_SHOW_BANNERS", "SET_HINT_BANNERS", "bannerEnabled", CH.OnBannerSettingChanged)
SecondsRow(pageRooms, {
    label = "RM_BANNER_FADE_OUT",
    hint = "SET_HINT_FADE",
    key = "bannerTimeout",
    min = 0,
    max = 20,
    step = 1,
    off = "RM_BANNER_OFF_STAYS",
    indent = true,
})
SwitchRow(pageRooms, "RM_TOGGLE_ROOM_DESCRIPTIONS", "SET_HINT_DESCRIPTIONS", "showRoomText")

-- ── Sound ────────────────────────────────────────────────────────────
local pageSound = Page("SET_PAGE_SOUND")

-- The kinds hang under the master switch and fade wiht it, since it silences
-- all of them whatever their own switch says.
local kindRows = {}
local function SoundChanged()
    CH.RefreshHudSound()
    for _, r in ipairs(kindRows) do
        r:SetAlpha(ChamberlainDB.settings.ambienceEnabled and 1 or 0.5)
    end
end

SwitchRow(pageSound, "RM_TOGGLE_AMBIENCE", "SET_HINT_AMBIENCE", "ambienceEnabled", SoundChanged, nil, "RM_TT_AMBIENCE")
for _, kind in ipairs(CH.SOUND_KINDS) do
    kindRows[#kindRows + 1] = SwitchRow(pageSound, kind[1], nil, kind[2], CH.RefreshHudSound, true)
end
refreshers[#refreshers + 1] = SoundChanged

-- What you send, where the switches above are what you hear. Not under the
-- master switch, which only mutes your own speakers.
SwitchRow(pageSound, "SET_ARRIVAL_SEND_GROUP", "SET_HINT_ARRIVAL_SEND_GROUP", "arrivalSendGroup")
SwitchRow(pageSound, "SET_ARRIVAL_SEND_GUILD", "SET_HINT_ARRIVAL_SEND_GUILD", "arrivalSendGuild")

-- How soon an echo or the front door rings for you again, one row for the
-- same person and one for anybody at all. The first stops at 5, the wait every
-- sender keeps between two echoes of a room (ECHO_SEND_WAIT in Share.lua).
SecondsRow(pageSound, {
    label = "RM_ECHO_PERSON_WAIT",
    key = "echoPersonWait",
    min = 5,
    max = 180,
    step = 5,
    tip = "RM_TT_ECHO_PERSON_WAIT",
})
SecondsRow(pageSound, {
    label = "RM_ECHO_ROOM_WAIT",
    key = "echoRoomWait",
    min = 0,
    max = 60,
    step = 5,
    off = "RM_ECHO_ROOM_OFF",
    tip = "RM_TT_ECHO_ROOM_WAIT",
})

-- ── Map and bar ──────────────────────────────────────────────────────
local pageMap = Page("SET_PAGE_MAP")

-- Positions are read locally, so the others don't need the addon.
SwitchRow(pageMap, "RM_TOGGLE_GROUP_ON_MAP", "SET_HINT_GROUP_DOTS", "showGroupDots")
-- The active floor's rooms drawn on the minimap in place of the still house
-- picture the game shows indoors (UI/MinimapRooms.lua). Square is for addons
-- that square the minimap, since the shape can't be read back.
SwitchRow(pageMap, "RM_TOGGLE_MINIMAP_ROOMS", "SET_HINT_MINIMAP", "minimapRooms", CH.RefreshMinimapRooms)
SwitchRow(pageMap, "RM_TOGGLE_MINIMAP_SQUARE", "SET_HINT_SQUARE", "minimapSquare", CH.RefreshMinimapRooms, true)
SwitchRow(pageMap, "RM_TOGGLE_SLIM_BAR", "SET_HINT_SLIM_BAR", "hudStrip", CH.RefreshHUDMode)

-- ── Voices ───────────────────────────────────────────────────────────
local pageVoices = Page("RM_SECTION_ROOM_NARRATION", "SET_PAGE_VOICES")

-- When on, your personal voices read rooms shared to you that carry no voice
-- (your own rooms always use the per-room voice you set in the room dialog).
SwitchRow(pageVoices, "RM_TOGGLE_USE_DEFAULT_VOICES", "SET_HINT_DEFAULT_VOICES", "voiceDefaultsEnabled")

-- One default voice with its dropdown and a Test button that reads a line in it.
local function VoiceRow(labelKey, key, sampleKey, pickFirstKey)
    local row = Row(pageVoices, labelKey, nil, 196)
    local test = CH.MakeButton(row, "RM_TEST", 50, 22)
    test:SetPoint("RIGHT")
    local drop = CH.MakeVoiceDropdown(row, 140, "RM_VOICE_NONE", function()
        return ChamberlainDB.settings[key]
    end, function(n)
        ChamberlainDB.settings[key] = n
    end)
    drop:SetPoint("RIGHT", test, "LEFT", -6, 0)
    test:SetScript("OnClick", function()
        local v = ChamberlainDB.settings[key]
        if v then
            CH.Speak(CH.L[sampleKey], v)
        else
            CH.Print(CH.L[pickFirstKey])
        end
    end)
    refreshers[#refreshers + 1] = function()
        drop:Refresh()
    end
end
VoiceRow("RM_FEMININE", "voiceFemale", "RM_VOICE_TEST_FEMININE", "RM_PICK_FEMININE_FIRST")
VoiceRow("RM_MASCULINE", "voiceMale", "RM_VOICE_TEST_MASCULINE", "RM_PICK_MASCULINE_FIRST")

local voiceNote = pageVoices:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
voiceNote:SetPoint("TOPLEFT", 0, -(pageVoices.y + 10))
voiceNote:SetWidth(PAGE_W)
voiceNote:SetJustifyH("LEFT")
voiceNote:SetSpacing(2)
voiceNote:SetText(CH.L["RM_VOICE_NOTE"])
voiceNote:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

-- ── Sharing ──────────────────────────────────────────────────────────
local pageSharing = Page("RM_SECTION_SHARING")

SwitchRow(pageSharing, "RM_TOGGLE_SHARING", "SET_HINT_SHARING", "shareEnabled")
-- Receiving lever, separate from sharing. Flipping it off also drops anything
-- already collected (party catalogs, half-finished transfers) so the house list
-- doesn't keep offering maps that can no longer arrive.
SwitchRow(pageSharing, "RM_TOGGLE_RECEIVING", "SET_HINT_RECEIVING", "receiveEnabled", function()
    if not ChamberlainDB.settings.receiveEnabled then
        wipe(CH.partyCatalogs)
        wipe(CH.pendingLayouts)
        CH.HideReceiveProgress()
        CH.RefreshGroupMaps()
    end
end)

-- ── People ───────────────────────────────────────────────────────────
local pagePeople = Page("RM_SECTION_TRUSTED_BLOCKED", "SET_PAGE_PEOPLE")

local blockDesc = pagePeople:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
blockDesc:SetPoint("TOPLEFT", 0, -pagePeople.y)
blockDesc:SetWidth(PAGE_W)
blockDesc:SetJustifyH("LEFT")
blockDesc:SetText(CH.L["RM_TRUST_BLOCK_DESC"])
blockDesc:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local blockScroll, blockScrollChild = CH.MakeScrollList(pagePeople, "ChamberlainBlockScroll")
blockScroll:SetPoint("TOPLEFT", blockDesc, "BOTTOMLEFT", 0, -8)
blockScroll:SetPoint("BOTTOMRIGHT", pagePeople, "BOTTOMRIGHT", -14, 0)

local blockEmpty = blockScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
blockEmpty:SetPoint("TOP", 0, -12)
blockEmpty:SetText(CH.L["RM_NO_TRUST_OR_BLOCKS"])
blockEmpty:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
blockEmpty:Hide()

local BLOCK_ROW_H = 26
local blockRowPool = {}

local function PopulateBlockList()
    for _, row in ipairs(blockRowPool) do
        row:Hide()
    end

    local entries = {}
    local blocks = ChamberlainDB.blocks
    for playerName, _ in pairs(ChamberlainDB.trusted) do
        entries[#entries + 1] = { kind = "trusted", key = playerName, label = playerName }
    end
    for guid, ownerOrBool in pairs(blocks.houses) do
        local label = type(ownerOrBool) == "string" and string.format(CH.L["RM_X_HOUSE"], ownerOrBool)
            or CH.L["RM_UNKNOWN_HOUSE"]
        entries[#entries + 1] = { kind = "house", key = guid, label = label }
    end
    for playerName, _ in pairs(blocks.players) do
        entries[#entries + 1] = { kind = "player", key = playerName, label = playerName }
    end
    table.sort(entries, function(a, b)
        return a.label < b.label
    end)

    local w = PAGE_W - 14
    blockScrollChild:SetWidth(w)

    for i, entry in ipairs(entries) do
        local row = blockRowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, blockScrollChild)
            row:SetHeight(BLOCK_ROW_H)

            row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameLabel:SetPoint("LEFT", 4, 0)
            row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -130, 0)
            row.nameLabel:SetJustifyH("LEFT")
            row.nameLabel:SetWordWrap(false)

            row.kindLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.kindLabel:SetPoint("RIGHT", row, "RIGHT", -74, 0)

            row.unblockBtn = CH.MakeButton(row, "RM_UNBLOCK", 64, 20)
            row.unblockBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

            local rule = CH.MakeRule(row, 0.18)
            rule:SetPoint("BOTTOMLEFT")
            rule:SetPoint("BOTTOMRIGHT")

            blockRowPool[i] = row
        end

        row:SetWidth(w)
        row:SetPoint("TOPLEFT", blockScrollChild, "TOPLEFT", 0, -(i - 1) * BLOCK_ROW_H)
        row:Show()
        row.nameLabel:SetText(entry.label)
        local kindText = entry.kind == "house" and CH.L["RM_KIND_HOUSE"]
            or entry.kind == "trusted" and CH.L["RM_KIND_TRUSTED"]
            or CH.L["RM_KIND_PLAYER"]
        row.kindLabel:SetText(kindText)
        row.unblockBtn:SetText(entry.kind == "trusted" and CH.L["RM_UNTRUST"] or CH.L["RM_UNBLOCK"])

        local kind, key = entry.kind, entry.key
        row.unblockBtn:SetScript("OnClick", function()
            if kind == "house" then
                ChamberlainDB.blocks.houses[key] = nil
            elseif kind == "trusted" then
                ChamberlainDB.trusted[key] = nil
            else
                ChamberlainDB.blocks.players[key] = nil
            end
            PopulateBlockList()
        end)
    end

    blockScrollChild:SetHeight(math.max(#entries * BLOCK_ROW_H, 1))
    blockEmpty:SetShown(#entries == 0)
end
refreshers[#refreshers + 1] = PopulateBlockList

-- ── Side column ──────────────────────────────────────────────────────

local navButtons = {}
local current = 1

local function ShowPage(i)
    current = i
    for n, p in ipairs(pages) do
        p:SetShown(n == i)
        local b = navButtons[n]
        b.bar:SetShown(n == i)
        b.fill:SetShown(n == i)
        if n == i then
            b.label:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
        else
            b.label:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
        end
    end
end

-- A page's entry in the side column. The page that's showing gets a gold bar
-- and a warm fill.
for i, page in ipairs(pages) do
    local b = CreateFrame("Button", nil, nav)
    b:SetSize(NAV_W - 1, 28)
    b:SetPoint("TOPLEFT", 0, -10 - (i - 1) * 28)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetColorTexture(0.45, 0.36, 0.08, 0.25)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetWidth(2)
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetColorTexture(CH.RGBA(CH.COLORS.frame, 1))
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.04)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", 12, 0)
    b.label:SetText(CH.L[page.navKey])
    b:SetScript("OnClick", function()
        ShowPage(i)
    end)
    navButtons[i] = b
end

-- ── Public ───────────────────────────────────────────────────────────

local function Refresh()
    for _, fn in ipairs(refreshers) do
        fn()
    end
end

-- Exposed so the trust list refreshes when "Always accept from X" is ticked,
-- and the switches follow the bar's sound menu.
function CH.RefreshSettingsTab()
    if win:IsShown() then
        Refresh()
    end
end

function CH.OpenSettings()
    ShowPage(current)
    win:Show()
    win:Raise()
    Refresh()
end

function CH.ToggleSettings()
    if win:IsShown() then
        win:Hide()
    else
        CH.OpenSettings()
    end
end
