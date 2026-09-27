local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Banner style picker
-- ─────────────────────────────────────────────────────────────────────
-- Every banner style drawn as a small banner, with the picked one big at the
-- top. The groups run down the left under a search box, and the right side
-- lists one group, or every match while something is typed in. A family is
-- one row with a chip for each colour. The House panel opens it for one of
-- your houses and the room editor for a room. Choose style in Settings and
-- What's New opens it for the house you stand in when it's yours, and for your
-- own style anywhere else.

local W, H = 640, 660
local SIDE_W = 150
local LIST_W = W - SIDE_W - 56 -- the margins, the gap to the sidebar and the scrollbar
local ROW_H, SHOW_W = 64, 290
local SIDE_ROW_H = 22
local CHIP, CHIP_GAP = 12, 3

local win, hero, nameFS, noteFS, hintFS, list
local rows = {} -- every row, Visitor's own first
local sideRows = {}
local groupOf = {} -- a style's group, by its index in CH.BANNER_GROUPS
local long = false -- which sample name the banners show
local houseGUID -- the house being picked for, nil while picking your own style
local room -- the room editor's pick, { style, done }, nil outside it
local current = 1 -- the group listed while the search box is empty
local query = ""

local function SampleName()
    return CH.L[long and "BP_SAMPLE_LONG" or "SET_BANNER_SAMPLE"]
end

local function Picked()
    if room then
        return room.style
    elseif houseGUID then
        return ChamberlainDB.houses[houseGUID].bannerStyle
    end
    return ChamberlainDB.settings.bannerStyle
end

-- Visitor's own (nil) is drawn in your style, since that's what you'd see. For
-- a room nil is the house's style.
local function Drawn(style)
    if room then
        return style or CH.RoomBannerStyle(houseGUID)
    end
    return style or ChamberlainDB.settings.bannerStyle
end

local function Label(style)
    return (CH.BannerPickText(style, room))
end

-- A group's entry is a style's name or a family's table.
local function EntryStyles(entry)
    return type(entry) == "table" and entry.styles or { entry }
end

local function Pick(style)
    if room then
        room.style = style
        room.done(style)
    elseif houseGUID then
        CH.SetHouseBanner(houseGUID, style)
    else
        CH.SetBannerStyle(style)
    end
    win.Refresh()
end

-- One colour of a family. Under the mouse it shows in the row's sample, and a
-- click picks it.
local function Chip(row, style, c)
    local chip = CH.MakeSwatch(row, CHIP)
    chip:SetBackdropColor(c[1], c[2], c[3], 1)
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(CH.BannerStyleName(style), 1, 1, 1, 1, true)
        GameTooltip:Show()
        row:Paint(style)
    end)
    chip:SetScript("OnLeave", function()
        GameTooltip:Hide()
        row:Paint()
    end)
    chip:SetScript("OnClick", function()
        row.shown = style
        Pick(style)
    end)
    function chip:Mark(on)
        self:SetBackdropBorderColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.border, on and 1 or 0.8))
    end
    return chip
end

-- A style's row, or a family's (fam) with its chips under the name. A family
-- shows the colour that's picked, else the one clicked last, else its first.
-- No style and no family is the Visitor's own row.
local function StyleRow(parent, style, fam)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(LIST_W, ROW_H)
    row:SetBackdrop(CH.BACKDROP_THIN)
    row.shown = fam and fam.styles[1] or style

    local show = CreateFrame("Frame", nil, row)
    show:SetPoint("TOPLEFT", 3, -3)
    show:SetSize(SHOW_W, ROW_H - 6)
    CH.BannerScene(show)
    row.banner = CH.MakeBanner(show)
    row.banner:SetPoint("CENTER")
    row.banner:SetScale(0.75)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", show, "TOPRIGHT", 10, -10)
    row.label:SetText(fam and CH.L[fam.family] or Label(style))
    row.tick = CH.MakeIcon(row, "icon-check", 14, "OVERLAY")
    row.tick:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
    row.tick:SetVertexColor(CH.RGBA(CH.COLORS.gold, 1))

    -- what the search box matches, a family by its own name and its colours'
    local words = { row.label:GetText() }
    if fam then
        row.chips = {}
        local across = math.floor((LIST_W - SHOW_W - 16) / (CHIP + CHIP_GAP))
        for i, s in ipairs(fam.styles) do
            local chip = Chip(row, s, CH.BannerChip(fam, i))
            local col, line = (i - 1) % across, math.floor((i - 1) / across)
            chip:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", col * (CHIP + CHIP_GAP), -6 - line * (CHIP + CHIP_GAP))
            row.chips[s] = chip
            words[#words + 1] = CH.BannerStyleName(s)
        end
    end
    row.words = table.concat(words, " "):lower()

    function row:Has(s)
        return self.chips and self.chips[s] ~= nil or s == self.shown
    end
    function row:Mark(hot)
        local picked = Picked()
        local on = self:Has(picked)
        if on and self.shown ~= picked then
            self.shown = picked
            self:Paint()
        end
        self:SetBackdropColor(0.36, 0.29, 0.07, on and 0.35 or 0)
        self:SetBackdropBorderColor(CH.RGBA(CH.COLORS.frame, on and 1 or hot and 0.45 or 0))
        self.label:SetTextColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.muted, 1))
        self.tick:SetShown(on)
        for s, chip in pairs(self.chips or {}) do
            chip:Mark(s == picked)
        end
    end
    -- s draws a colour while the mouse is on its chip
    function row:Paint(s)
        CH.PaintBanner(self.banner, SampleName(), nil, false, Drawn(s or self.shown))
    end
    row:SetScript("OnEnter", function(self)
        self:Mark(true)
    end)
    row:SetScript("OnLeave", function(self)
        self:Mark()
    end)
    row:SetScript("OnClick", function(self)
        Pick(self.shown)
    end)
    rows[#rows + 1] = row
    return row
end

-- A group in the sidebar, its name and how many styles it holds.
local function SideRow(parent, i, group)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(SIDE_W, SIDE_ROW_H)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.22))

    local n = 0
    for _, entry in ipairs(group.styles) do
        n = n + #EntryStyles(entry)
    end
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -6, 0)
    row.count:SetText(n)
    row.count:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetText(CH.L[group.key])

    function row:Mark()
        local on = query == "" and current == i
        self.sel:SetShown(on)
        self.label:SetTextColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.muted, 1))
    end
    row:SetScript("OnClick", function()
        current = i
        win.searchBox:SetText("")
        win.searchBox:ClearFocus()
        win.Layout()
    end)
    sideRows[i] = row
    return row
end

local sampleButtons = {}
local function SampleButton(key, isLong)
    local b = CH.MakeButton(win, key, 84, 20)
    b:SetScript("OnClick", function()
        long = isLong
        win.Repaint()
    end)
    sampleButtons[b] = isLong
    return b
end

local function SearchBox(parent)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(SIDE_W - 6, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText(CH.L["BP_SEARCH_HINT"])
    box:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        query = string.lower(string.match(self:GetText(), "^%s*(.-)%s*$"))
        win.Layout()
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function Build()
    win = CreateFrame("Frame", "ChamberlainBannerPicker", UIParent, "BackdropTemplate")
    win:SetSize(W, H)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "BP_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainBannerPicker")

    local function Close()
        win:Hide()
    end
    local glyph = CH.MakeGlyphButton(win, "x")
    glyph:SetPoint("TOPRIGHT", -4, -4)
    glyph:SetScript("OnClick", Close)
    local foot = CH.MakeRule(win)
    foot:SetPoint("BOTTOMLEFT", 1, 36)
    foot:SetPoint("BOTTOMRIGHT", -1, 36)
    local closeBtn = CH.MakeButton(win, "BP_CLOSE", 90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    closeBtn:SetScript("OnClick", Close)

    local stage = CreateFrame("Frame", nil, win)
    stage:SetPoint("TOPLEFT", 12, -34)
    stage:SetPoint("TOPRIGHT", -12, -34)
    stage:SetHeight(110)
    CH.BannerScene(stage)
    hero = CH.MakeBanner(stage)
    hero:SetPoint("CENTER")
    hero:SetScale(0.9)

    nameFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFS:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 2, -8)
    noteFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -3)
    noteFS:SetWidth(W - 220)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    local longBtn = SampleButton("BP_LONG", true)
    longBtn:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -10)
    SampleButton("BP_SHORT", false):SetPoint("RIGHT", longBtn, "LEFT", -6, 0)

    local rule = CH.MakeRule(win, 0.5)
    rule:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -46)
    rule:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -46)

    win.searchBox = SearchBox(win)
    win.searchBox:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 6, -10)
    for i, group in ipairs(CH.BANNER_GROUPS) do
        SideRow(win, i, group):SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -36 - (i - 1) * SIDE_ROW_H)
    end

    local scroll
    scroll, list = CH.MakeScrollList(win, "ChamberlainBannerPickerScroll")
    scroll:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", SIDE_W + 12, -8)
    scroll:SetPoint("BOTTOMRIGHT", -22, 44)
    list:SetWidth(LIST_W)
    win.scroll = scroll

    hintFS = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintFS:SetPoint("TOPLEFT", 2, -2)
    hintFS:SetWidth(LIST_W - 4)
    hintFS:SetJustifyH("LEFT")
    hintFS:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    -- a house's list starts with each visitor's own, a room's with the house's
    local own = StyleRow(list, nil)
    win.own = own
    for i, group in ipairs(CH.BANNER_GROUPS) do
        for _, entry in ipairs(group.styles) do
            local fam = type(entry) == "table" and entry or nil
            local row = StyleRow(list, not fam and entry or nil, fam)
            row.group = i
            for _, s in ipairs(EntryStyles(entry)) do
                groupOf[s] = i
            end
        end
    end

    -- The rows for the group, or every match while something is typed, with
    -- Visitor's own on top of either in a house's list.
    function win.Layout()
        local found = 0
        for _, row in ipairs(rows) do
            if row == own then
                row.fits = houseGUID ~= nil
            elseif query ~= "" then
                row.fits = row.words:find(query, 1, true) ~= nil
                found = row.fits and found + 1 or found
            else
                row.fits = row.group == current
            end
        end
        if query == "" then
            hintFS:SetText(CH.L[CH.BANNER_GROUPS[current].hint])
        else
            hintFS:SetText(CH.L[found > 0 and "BP_SEARCH_FOUND" or "BP_SEARCH_NONE"])
        end
        local y = -4 - hintFS:GetStringHeight() - 8
        for _, row in ipairs(rows) do
            row:SetShown(row.fits)
            if row.fits then
                row:SetPoint("TOPLEFT", 0, y)
                y = y - ROW_H - 4
            end
        end
        list:SetHeight(-y)
        win.scroll:SetVerticalScroll(0)
        for _, side in ipairs(sideRows) do
            side:Mark()
        end
    end

    -- after a pick, only the marks and the big banner change
    function win.Refresh()
        local style = Picked()
        for _, row in ipairs(rows) do
            row:Mark(row:IsMouseOver())
        end
        CH.PaintBanner(hero, SampleName(), nil, true, Drawn(style))
        local name, note = CH.BannerPickText(style, room)
        nameFS:SetText(name)
        noteFS:SetText(note)
    end
    -- the sample name changed, so every row repaints too
    function win.Repaint()
        for b, isLong in pairs(sampleButtons) do
            CH.SetButtonActive(b, isLong == long)
        end
        for _, row in ipairs(rows) do
            row:Paint()
        end
        win.Refresh()
    end
end

-- guid picks the style of that house of yours, nil your own. With pick it's
-- for a room of that house instead: pick.style is the room's style so far and
-- pick.done(style) hears every click. It opens on the group of the style in
-- use.
function CH.OpenBannerPicker(guid, pick)
    houseGUID = guid
    room = pick
    if not win then
        Build()
    end
    CH.SetWindowTitle(win, room and "BP_TITLE_ROOM" or houseGUID and "BP_TITLE_HOUSE" or "BP_TITLE", true)
    win.own.label:SetText(Label(nil))
    current = groupOf[Drawn(Picked())] or 1
    query = ""
    win.searchBox:SetText("")
    win.Layout()
    win:Show()
    win:Raise()
    win.Repaint()
end

-- The room editor closing takes a room's picker with it, or its clicks would
-- land on a dialog that's gone.
function CH.CloseRoomBannerPicker()
    if room then
        win:Hide()
    end
end
