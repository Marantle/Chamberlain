local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Banner style picker
-- ─────────────────────────────────────────────────────────────────────
-- Every banner style drawn as a small banner, with the picked one big at the
-- top. The groups run down the left under a search box, and the right side
-- lists one group, or every match while something is typed in. A family is
-- one row with a chip for each colour. There are two pickers. The window
-- picks for a house or for you. The House panel opens it for one of your
-- houses. Choose style in Settings and What's New open it for the house you
-- stand in if it's yours, else for your own style. The other one sits in the
-- map's place while the room editor is on its Banner tab.

local W, H = 640, 660
local ROW_H = 64
local SIDE_ROW_H = 22
local CHIP, CHIP_GAP = 12, 3

-- The sizes of the window's picker. The one in the map is narrower.
local WIDE = { w = W - 24, side = 150, show = 290, top = -34, bottom = 44, scroll = "ChamberlainBannerPickerScroll" }
local NARROW = { w = 480, side = 120, show = 200, top = -10, bottom = 10, scroll = "ChamberlainRoomBannerScroll" }

local win, inMap -- the window and the map's pane, built when first shown
local long = false -- which sample name the banners show, the same in both

local function SampleName()
    return CH.L[long and "BP_SAMPLE_LONG" or "SET_BANNER_SAMPLE"]
end

-- A group's entry is a style's name or a family's table.
local function EntryStyles(entry)
    return type(entry) == "table" and entry.styles or { entry }
end

-- One picker built into parent. p.houseGUID is the house being picked for,
-- nil while picking your own style, and p.room the room editor's pick,
-- { style, done }, nil outside it.
local function Build(parent, size)
    local p = { rows = {}, sideRows = {}, groupOf = {}, current = 1, query = "" }
    local listW = size.w - size.side - 32 -- the gap to the sidebar and the scrollbar
    local sampleButtons = {}
    local hero, nameFS, noteFS, hintFS, list

    local function Picked()
        if p.room then
            return p.room.style
        elseif p.houseGUID then
            return ChamberlainDB.houses[p.houseGUID].bannerStyle
        end
        return ChamberlainDB.settings.bannerStyle
    end

    -- Visitor's own (nil) is drawn in your style, since that's what you'd see.
    -- For a room nil is the house's style.
    local function Drawn(style)
        if p.room then
            return style or CH.RoomBannerStyle(p.houseGUID)
        end
        return style or ChamberlainDB.settings.bannerStyle
    end

    local function Label(style)
        return (CH.BannerPickText(style, p.room))
    end

    local function Pick(style)
        if p.room then
            p.room.style = style
            p.room.done(style)
        elseif p.houseGUID then
            CH.SetHouseBanner(p.houseGUID, style)
        else
            CH.SetBannerStyle(style)
        end
        p.Refresh()
    end

    -- One colour of a family. Under the mouse it shows in the row's sample,
    -- and a click picks it.
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

    -- A style's row, or a family's (fam) with its chips under the name. A
    -- family shows the colour that's picked, else the one clicked last, else
    -- its first. No style and no family is the Visitor's own row.
    local function StyleRow(style, fam)
        local row = CreateFrame("Button", nil, list, "BackdropTemplate")
        row:SetSize(listW, ROW_H)
        row:SetBackdrop(CH.BACKDROP_THIN)
        row.shown = fam and fam.styles[1] or style

        local show = CreateFrame("Frame", nil, row)
        show:SetPoint("TOPLEFT", 3, -3)
        show:SetSize(size.show, ROW_H - 6)
        CH.BannerScene(show)
        row.banner = CH.MakeBanner(show)
        row.banner:SetPoint("CENTER")
        row.banner:SetScale(0.75 * size.show / WIDE.show)

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
            local across = math.floor((listW - size.show - 16) / (CHIP + CHIP_GAP))
            for i, s in ipairs(fam.styles) do
                local chip = Chip(row, s, CH.BannerChip(fam, i))
                local col, line = (i - 1) % across, math.floor((i - 1) / across)
                chip:SetPoint(
                    "TOPLEFT",
                    row.label,
                    "BOTTOMLEFT",
                    col * (CHIP + CHIP_GAP),
                    -6 - line * (CHIP + CHIP_GAP)
                )
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
        p.rows[#p.rows + 1] = row
        return row
    end

    -- A group in the sidebar, its name and how many styles it holds.
    local function SideRow(i, group)
        local row = CreateFrame("Button", nil, parent)
        row:SetSize(size.side, SIDE_ROW_H)
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
            local on = p.query == "" and p.current == i
            self.sel:SetShown(on)
            self.label:SetTextColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.muted, 1))
        end
        row:SetScript("OnClick", function()
            p.current = i
            p.searchBox:SetText("")
            p.searchBox:ClearFocus()
            p.Layout()
        end)
        p.sideRows[i] = row
        return row
    end

    local function SampleButton(key, isLong)
        local b = CH.MakeButton(parent, key, 84, 20)
        b:SetScript("OnClick", function()
            long = isLong
            p.Repaint()
        end)
        sampleButtons[b] = isLong
        return b
    end

    local function SearchBox()
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(size.side - 6, 20)
        box:SetAutoFocus(false)
        box:SetMaxLetters(40)
        local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("LEFT", 6, 0)
        hint:SetText(CH.L["BP_SEARCH_HINT"])
        box:SetScript("OnTextChanged", function(self)
            hint:SetShown(self:GetText() == "")
            p.query = string.lower(string.match(self:GetText(), "^%s*(.-)%s*$"))
            p.Layout()
        end)
        box:SetScript("OnEnterPressed", box.ClearFocus)
        return box
    end

    local stage = CreateFrame("Frame", nil, parent)
    stage:SetPoint("TOPLEFT", 12, size.top)
    stage:SetPoint("TOPRIGHT", -12, size.top)
    stage:SetHeight(110)
    CH.BannerScene(stage)
    hero = CH.MakeBanner(stage)
    hero:SetPoint("CENTER")
    hero:SetScale(0.9 * size.w / WIDE.w)

    nameFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFS:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 2, -8)
    noteFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -3)
    noteFS:SetWidth(size.w - 196)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    local longBtn = SampleButton("BP_LONG", true)
    longBtn:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -10)
    SampleButton("BP_SHORT", false):SetPoint("RIGHT", longBtn, "LEFT", -6, 0)

    local rule = CH.MakeRule(parent, 0.5)
    rule:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -46)
    rule:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -46)

    p.searchBox = SearchBox()
    p.searchBox:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 6, -10)
    for i, group in ipairs(CH.BANNER_GROUPS) do
        SideRow(i, group):SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -36 - (i - 1) * SIDE_ROW_H)
    end

    local scroll
    scroll, list = CH.MakeScrollList(parent, size.scroll)
    scroll:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", size.side + 12, -8)
    scroll:SetPoint("BOTTOMRIGHT", -22, size.bottom)
    list:SetWidth(listW)

    hintFS = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintFS:SetPoint("TOPLEFT", 2, -2)
    hintFS:SetWidth(listW - 4)
    hintFS:SetJustifyH("LEFT")
    hintFS:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    -- a house's list starts with each visitor's own, a room's with the house's
    local own = StyleRow(nil)
    for i, group in ipairs(CH.BANNER_GROUPS) do
        for _, entry in ipairs(group.styles) do
            local fam = type(entry) == "table" and entry or nil
            local row = StyleRow(not fam and entry or nil, fam)
            row.group = i
            for _, s in ipairs(EntryStyles(entry)) do
                p.groupOf[s] = i
            end
        end
    end

    -- The rows for the group, or every match while something is typed, with
    -- the own row on top of either for a house or a room.
    function p.Layout()
        local found = 0
        for _, row in ipairs(p.rows) do
            if row == own then
                row.fits = p.houseGUID ~= nil
            elseif p.query ~= "" then
                row.fits = row.words:find(p.query, 1, true) ~= nil
                found = row.fits and found + 1 or found
            else
                row.fits = row.group == p.current
            end
        end
        if p.query == "" then
            hintFS:SetText(CH.L[CH.BANNER_GROUPS[p.current].hint])
        else
            hintFS:SetText(CH.L[found > 0 and "BP_SEARCH_FOUND" or "BP_SEARCH_NONE"])
        end
        local y = -4 - hintFS:GetStringHeight() - 8
        for _, row in ipairs(p.rows) do
            row:SetShown(row.fits)
            if row.fits then
                row:SetPoint("TOPLEFT", 0, y)
                y = y - ROW_H - 4
            end
        end
        list:SetHeight(-y)
        scroll:SetVerticalScroll(0)
        for _, side in ipairs(p.sideRows) do
            side:Mark()
        end
    end

    -- after a pick, only the marks and the big banner change
    function p.Refresh()
        local style = Picked()
        p.marked = style
        for _, row in ipairs(p.rows) do
            row:Mark(row:IsMouseOver())
        end
        CH.PaintBanner(hero, SampleName(), nil, true, Drawn(style))
        local name, note = CH.BannerPickText(style, p.room)
        nameFS:SetText(name)
        noteFS:SetText(note)
    end

    -- the sample name changed, so every row repaints too
    function p.Repaint()
        for b, isLong in pairs(sampleButtons) do
            CH.SetButtonActive(b, isLong == long)
        end
        for _, row in ipairs(p.rows) do
            row:Paint()
        end
        p.Refresh()
    end

    -- Aim it at a house, your own style or a room, and open on the group of
    -- the style in use.
    function p.Open(guid, room)
        p.houseGUID, p.room = guid, room
        own.label:SetText(Label(nil))
        p.current = p.groupOf[Drawn(Picked())] or 1
        p.query = ""
        p.searchBox:SetText("")
        p.Layout()
        p.Repaint()
    end

    return p
end

local function BuildWindow()
    local frame = CreateFrame("Frame", "ChamberlainBannerPicker", UIParent, "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetPoint("CENTER")
    CH.MakeDraggable(frame)
    CH.SkinWindow(frame, "BP_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainBannerPicker")

    local function Close()
        frame:Hide()
    end
    local glyph = CH.MakeGlyphButton(frame, "x")
    glyph:SetPoint("TOPRIGHT", -4, -4)
    glyph:SetScript("OnClick", Close)
    local foot = CH.MakeRule(frame)
    foot:SetPoint("BOTTOMLEFT", 1, 36)
    foot:SetPoint("BOTTOMRIGHT", -1, 36)
    local closeBtn = CH.MakeButton(frame, "BP_CLOSE", 90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    closeBtn:SetScript("OnClick", Close)

    win = Build(frame, WIDE)
    win.frame = frame
end

-- guid picks the style of that house of yours, nil your own.
function CH.OpenBannerPicker(guid)
    if not win then
        BuildWindow()
    end
    CH.SetWindowTitle(win.frame, guid and "BP_TITLE_HOUSE" or "BP_TITLE", true)
    win.Open(guid)
    win.frame:Show()
    win.frame:Raise()
end

-- The room editor's Banner tab: the list over the map of house guid. pick is
-- { style, done }, pick.style the room's style so far and pick.done(style)
-- hears every click. Showing it again for the same pick only moves the marks,
-- and only when the style changed some other way (Copy from).
function CH.ShowRoomBannerPicker(guid, pick)
    local FP = CH.FP
    if not inMap then
        local pane = CreateFrame("Frame", nil, FP.win)
        pane:SetPoint("TOPLEFT", FP.rail, "TOPRIGHT", 1, 0)
        pane:SetPoint("BOTTOMRIGHT")
        pane:Hide()
        inMap = Build(pane, NARROW)
        inMap.frame = pane
    end
    if inMap.frame:IsShown() and inMap.room == pick then
        if pick.style ~= inMap.marked then
            inMap.Refresh()
        end
        return
    end
    inMap.Open(guid, pick)
    FP.map:Hide()
    inMap.frame:Show()
end

function CH.HideRoomBannerPicker()
    if inMap and inMap.frame:IsShown() then
        inMap.frame:Hide()
        CH.FP.map:Show()
    end
end
