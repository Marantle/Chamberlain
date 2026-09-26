local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Banner style picker
-- ─────────────────────────────────────────────────────────────────────
-- Every banner style in one list, each drawn as a small banner, with the
-- picked one big at the top. The House panel opens it for one of
-- your houses. Choose style in Settings and What's New opens it for the house
-- you stand in when it's yours, and for your own style anywhere else.

local W, H = 440, 640
local LIST_W = W - 34 -- the window minus side margins and the scrollbar
local ROW_H, SHOW_W = 64, 300

local win, hero, nameFS, noteFS
local rows = {}
local long = false -- which sample name the banners show
local houseGUID -- the house being picked for, nil while picking your own style

local function SampleName()
    return CH.L[long and "BP_SAMPLE_LONG" or "SET_BANNER_SAMPLE"]
end

local function Picked()
    if houseGUID then
        return ChamberlainDB.houses[houseGUID].bannerStyle
    end
    return ChamberlainDB.settings.bannerStyle
end

-- Visitor's own (nil) is drawn in your style, since that's what you'd see.
local function Drawn(style)
    return style or ChamberlainDB.settings.bannerStyle
end

local function Label(style)
    return style and CH.BannerStyleName(style) or CH.L["BP_EACH_OWN"]
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
    row.label:SetText(Label(style))
    row.tick = CH.MakeIcon(row, "icon-check", 14, "OVERLAY")
    row.tick:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -6)
    row.tick:SetVertexColor(CH.RGBA(CH.COLORS.gold, 1))

    function row:Mark(hot)
        local on = Picked() == style
        self:SetBackdropColor(0.36, 0.29, 0.07, on and 0.35 or 0)
        self:SetBackdropBorderColor(CH.RGBA(CH.COLORS.frame, on and 1 or hot and 0.45 or 0))
        self.label:SetTextColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.muted, 1))
        self.tick:SetShown(on)
    end
    function row:Paint()
        CH.PaintBanner(self.banner, SampleName(), nil, false, Drawn(style))
    end
    row:SetScript("OnEnter", function(self)
        self:Mark(true)
    end)
    row:SetScript("OnLeave", function(self)
        self:Mark()
    end)
    row:SetScript("OnClick", function()
        if houseGUID then
            CH.SetHouseBanner(houseGUID, style)
        else
            CH.SetBannerStyle(style)
        end
        win.Refresh()
    end)
    rows[#rows + 1] = row
    return y - ROW_H - 4, row
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
    -- a house's list starts with each visitor's own, which pushes the rest down
    local _, ownRow = StyleRow(list, nil, -4)
    local body = CreateFrame("Frame", nil, list)
    body:SetSize(LIST_W, 1)
    local y = -4
    for _, group in ipairs(CH.BANNER_GROUPS) do
        y = GroupHeader(body, group, y)
        for _, style in ipairs(group.styles) do
            y = StyleRow(body, style, y)
        end
        y = y - 10
    end

    function win.SetMode()
        local top = houseGUID and ROW_H + 4 or 0
        ownRow:SetShown(houseGUID ~= nil)
        body:SetPoint("TOPLEFT", 0, -top)
        list:SetHeight(top - y)
        CH.SetWindowTitle(win, houseGUID and "BP_TITLE_HOUSE" or "BP_TITLE", true)
    end

    -- after a pick, only the marks and the big banner change
    function win.Refresh()
        local style = Picked()
        for _, row in ipairs(rows) do
            row:Mark(row:IsMouseOver())
        end
        CH.PaintBanner(hero, SampleName(), nil, true, Drawn(style))
        nameFS:SetText(Label(style))
        noteFS:SetText(CH.L[style and CH.BannerStyleNote(style) or "BP_NOTE_EACH_OWN"])
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

-- guid picks the style of that house of yours, nil your own.
function CH.OpenBannerPicker(guid)
    houseGUID = guid
    if not win then
        Build()
    end
    win.SetMode()
    win:Show()
    win:Raise()
    win.Repaint()
end
