local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Banner style picker
-- ─────────────────────────────────────────────────────────────────────
-- Every banner style in one list, each drawn as a small banner, with the
-- picked one big at the top. Opened by the Choose style button in Settings
-- and in What's New.

local W, H = 440, 640
local LIST_W = W - 34 -- the window minus side margins and the scrollbar
local ROW_H, SHOW_W = 64, 300

local win, hero, nameFS, noteFS
local rows = {}
local long = false -- which sample name the banners show

local function SampleName()
    return CH.L[long and "BP_SAMPLE_LONG" or "SET_BANNER_SAMPLE"]
end

-- A grey backdrop behind a banner, a stand-in for the world it shows over.
local function Scene(f)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(1, 1, 1, 1)
    t:SetGradient("VERTICAL", CreateColor(0.15, 0.16, 0.15, 1), CreateColor(0.23, 0.24, 0.23, 1))
    f:SetClipsChildren(true)
end

-- A group's gold title with its line of help, at y in the list. Hands back
-- the y under it.
local function GroupHeader(parent, group, y)
    local title = CH.MakeSectionHeader(parent, group.key, y)
    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    hint:SetText(CH.L[group.hint])
    hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    return y - title:GetStringHeight() - hint:GetStringHeight() - 8
end

local function StyleRow(parent, style, y)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(LIST_W, ROW_H)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetBackdrop(CH.BACKDROP_THIN)

    local show = CreateFrame("Frame", nil, row)
    show:SetPoint("TOPLEFT", 3, -3)
    show:SetSize(SHOW_W, ROW_H - 6)
    Scene(show)
    row.banner = CH.MakeBanner(show)
    row.banner:SetPoint("CENTER")
    row.banner:SetScale(0.75)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", show, "TOPRIGHT", 10, -12)
    row.label:SetText(CH.BannerStyleName(style))
    row.tick = CH.MakeIcon(row, "icon-check", 14, "OVERLAY")
    row.tick:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -6)
    row.tick:SetVertexColor(CH.RGBA(CH.COLORS.gold, 1))

    function row:Mark(hot)
        local on = ChamberlainDB.settings.bannerStyle == style
        self:SetBackdropColor(0.36, 0.29, 0.07, on and 0.35 or 0)
        self:SetBackdropBorderColor(CH.RGBA(CH.COLORS.frame, on and 1 or hot and 0.45 or 0))
        self.label:SetTextColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.muted, 1))
        self.tick:SetShown(on)
    end
    function row:Paint()
        CH.PaintBanner(self.banner, SampleName(), nil, false, style)
    end
    row:SetScript("OnEnter", function(self)
        self:Mark(true)
    end)
    row:SetScript("OnLeave", function(self)
        self:Mark()
    end)
    row:SetScript("OnClick", function()
        CH.SetBannerStyle(style)
        win.Refresh()
    end)
    rows[#rows + 1] = row
    return y - ROW_H - 4
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

local function Build()
    win = CreateFrame("Frame", "ChamberlainBannerPicker", UIParent, "BackdropTemplate")
    win:SetSize(W, H)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "BP_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainBannerPicker")

    local closeBtn = CH.MakeGlyphButton(win, "x")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        win:Hide()
    end)

    local stage = CreateFrame("Frame", nil, win)
    stage:SetPoint("TOPLEFT", 12, -34)
    stage:SetPoint("TOPRIGHT", -12, -34)
    stage:SetHeight(96)
    Scene(stage)
    hero = CH.MakeBanner(stage)
    hero:SetPoint("CENTER")
    hero:SetScale(0.9) -- the widest art with a long name stil fits

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

    local scroll, list = CH.MakeScrollList(win, "ChamberlainBannerPickerScroll")
    scroll:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -22, 12)
    list:SetWidth(LIST_W)
    local y = -4
    for _, group in ipairs(CH.BANNER_GROUPS) do
        y = GroupHeader(list, group, y)
        for _, style in ipairs(group.styles) do
            y = StyleRow(list, style, y)
        end
        y = y - 10
    end
    list:SetHeight(-y)

    -- after a pick, only the marks and the big banner change
    function win.Refresh()
        local style = ChamberlainDB.settings.bannerStyle
        for _, row in ipairs(rows) do
            row:Mark(row:IsMouseOver())
        end
        CH.PaintBanner(hero, SampleName(), nil, true, style)
        nameFS:SetText(CH.BannerStyleName(style))
        noteFS:SetText(CH.L[CH.BannerStyleNote(style)])
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

function CH.OpenBannerPicker()
    if not win then
        Build()
    end
    win:Show()
    win:Raise()
    win.Repaint()
end
