local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Story pieces: the face switch, the decor slot and Find decor
-- ─────────────────────────────────────────────────────────────────────
-- A room's card shows a head, a decor from the housing catalog or the words
-- alone (3.42.0). The room editor's Story tab and the Tour panel both build
-- their face with CH.MakeStoryFace, and both open the same Find decor list,
-- which takes the map's place like the banner list does. Only the decor's
-- record is stored. Its name and model come from the catalog on every client.

local FP = CH.FP

-- How far down the switch pushes everything under it.
CH.STORY_SWITCH_H = 28

-- What a story saves for its face: the decor only while Decor is picked and
-- the flag only for words alone. Hands back decor, noPortrait.
function CH.StoryFields(state)
    return state.mode == "decor" and state.decor or nil, state.mode == "text" or nil
end

-- ── The switch ───────────────────────────────────────────────────────

local MODES = { { "head", "SY_HEAD" }, { "decor", "SY_DECOR" }, { "text", "SY_TEXT" } }
local MODE_STEP = 84

-- Three buttons side by side, the picked one lit. onPick(mode) hears a
-- click, while row:Set(mode) only lights one.
local function Switch(parent, onPick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(#MODES * MODE_STEP, 22)
    local buttons = {}
    function row.Set(_, mode)
        for m, b in pairs(buttons) do
            CH.SetButtonActive(b, m == mode)
        end
    end
    for i, e in ipairs(MODES) do
        local b = CH.MakeButton(row, e[2], MODE_STEP - 4, 22)
        b:SetPoint("LEFT", (i - 1) * MODE_STEP, 0)
        b:SetScript("OnClick", function()
            row:Set(e[1])
            onPick(e[1])
        end)
        buttons[e[1]] = b
    end
    return row
end

-- ── The slot ─────────────────────────────────────────────────────────

-- The picked decor in a small case, its name beside it and Find decor
-- under the name. h is the slot's height, the head grid's in both editors.
-- slot:Set(record) shows a pick, nil for none yet.
local function Slot(parent, h, onFind)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetHeight(h)
    local box = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    box:SetSize(h - 4, h - 4)
    box:SetPoint("TOPLEFT")
    box:SetBackdrop(CH.BACKDROP_THIN)
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.8))
    local model = CH.MakeDecorModel(box)
    model:SetPoint("TOPLEFT", 2, -2)
    model:SetPoint("BOTTOMRIGHT", -2, 2)

    local name = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, -2)
    name:SetPoint("RIGHT")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local hint = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT")
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    local find = CH.MakeButton(slot, "SY_FIND_DECOR", 110, 22)
    find:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 10, 0)
    find:SetScript("OnClick", onFind)

    -- set on every show, since a model let go while hidden comes back blank
    local record
    function slot.Set(_, r)
        record = r
        local info = model:SetDecor(r)
        name:SetText(info and info.name or CH.L[r and "SY_DECOR_UNKNOWN" or "SY_NO_DECOR"])
        hint:SetText(CH.L[info and "SY_DECOR_NAME_HINT" or "SY_FIND_HINT"])
    end
    slot:SetScript("OnShow", function()
        slot:Set(record)
    end)
    return slot
end

-- ── The face ─────────────────────────────────────────────────────────

-- Builds the switch, the decor slot and the words alone hint for an editor,
-- with head the layer of head controls the switch hides. face:Load(state)
-- points it at a { mode, decor } table that the picks write to.
function CH.MakeStoryFace(parent, head, headH, guid, changed)
    local face, pick = {}, {}
    local function Find(record)
        pick.record = record
        CH.ShowDecorPicker(guid(), pick)
    end

    local slot = Slot(parent, headH, function()
        Find(face.state.decor)
    end)
    slot:SetPoint("TOPLEFT", 0, -CH.STORY_SWITCH_H)
    slot:SetPoint("RIGHT")
    function pick.done(record)
        face.state.decor = record
        slot:Set(record)
        changed()
    end

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 2, -CH.STORY_SWITCH_H - 6)
    hint:SetPoint("RIGHT")
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    hint:SetText(CH.L["SY_TEXT_HINT"])

    local function Refresh()
        local mode = face.state.mode
        head:SetShown(mode == "head")
        slot:SetShown(mode == "decor")
        hint:SetShown(mode == "text")
    end

    -- Decor with nothing picked yet goes straight to the list.
    face.switch = Switch(parent, function(mode)
        face.state.mode = mode
        Refresh()
        changed()
        if mode ~= "decor" then
            CH.HideDecorPicker()
        elseif not face.state.decor then
            Find(nil)
        end
    end)
    parent:HookScript("OnHide", CH.HideDecorPicker)

    function face.Load(_, state)
        face.state = state
        face.switch:Set(state.mode)
        slot:Set(state.decor)
        Refresh()
    end
    return face
end

-- ── Find decor ───────────────────────────────────────────────────────

local COLS, ROWS = 4, 3
local TILE, GAP, NAME_H = 104, 8, 18
local PER_PAGE = COLS * ROWS

local pane -- built when first shown
local pick -- { record, done } from the editor that opened it
local houseGUID
local searcher
local results = {} -- the records listed now
local page = 1
local filter = "all" -- "all", "house", "placed" or "owned"
local category -- a catalog category id, nil for all
local searchTimer

local Render -- the page drawn again

local function LastPage()
    return math.max(1, math.ceil(#results / PER_PAGE))
end

-- The decor records the house's rooms wear, each once.
local function HouseDecor(out)
    wipe(out)
    local seen = {}
    local h = houseGUID and ChamberlainDB.houses[houseGUID]
    for _, z in ipairs(h and h.zones or {}) do
        if z.decor and not seen[z.decor] then
            seen[z.decor] = true
            out[#out + 1] = z.decor
        end
    end
    return out
end

local function OnResults()
    if filter == "house" then
        return
    end
    wipe(results)
    -- the editor mode is what keeps rooms out, so they're checked for too.
    -- Placed counts every house and plot of yours, since the list of what
    -- stands in one house is closed to addons
    for _, id in ipairs(searcher:GetCatalogSearchResults()) do
        if id.entryType == Enum.HousingCatalogEntryType.Decor then
            local info = filter == "placed" and C_HousingCatalog.GetCatalogEntryInfo(id)
            if filter ~= "placed" or info and info.totalNumPlaced > 0 then
                results[#results + 1] = id.recordID
            end
        end
    end
    page = 1
    Render()
end

-- Blizzard's catalog sets its searcher up the same way, with every decor
-- once and the rooms left out.
local function Searcher()
    if not searcher then
        searcher = C_HousingCatalog.CreateCatalogSearcher()
        searcher:SetResultsUpdatedCallback(OnResults)
        searcher:SetAutoUpdateOnParamChanges(false)
        searcher:SetStoredOnly(false)
        searcher:SetBaseVariantOnly(true)
        searcher:SetEditorModeContext(Enum.HouseEditorMode.BasicDecor)
    end
    return searcher
end

local function Search()
    if filter == "house" then
        HouseDecor(results)
        page = 1
        Render()
        return
    end
    local s = Searcher()
    local text = pane.searchBox:GetText():match("^%s*(.-)%s*$")
    s:SetSearchText(text ~= "" and text or nil)
    s:SetCollected(true)
    s:SetUncollected(filter == "all")
    s:SetFilteredCategoryID(category)
    s:RunSearch()
end

-- Typing waits for a short pause befor it searches.
local function SearchSoon()
    if searchTimer then
        searchTimer:Cancel()
    end
    searchTimer = C_Timer.NewTimer(0.3, Search)
end

local function Tile(n)
    local t = CreateFrame("Button", nil, pane, "BackdropTemplate")
    t:SetSize(TILE, TILE + NAME_H)
    t:SetBackdrop(CH.BACKDROP_THIN)
    t:SetBackdropColor(0, 0, 0, 0.6)
    local col, row = (n - 1) % COLS, math.floor((n - 1) / COLS)
    t:SetPoint("TOPLEFT", 16 + col * (TILE + GAP), -100 - row * (TILE + NAME_H + GAP))
    t.model = CH.MakeDecorModel(t)
    t.model:SetPoint("TOPLEFT", 2, -2)
    t.model:SetPoint("BOTTOMRIGHT", -2, NAME_H)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.name:SetPoint("BOTTOMLEFT", 4, 4)
    t.name:SetPoint("BOTTOMRIGHT", -4, 4)
    t.name:SetWordWrap(false)
    t:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 0.9)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.name:GetText(), 1, 0.85, 0.25)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self)
        self:Mark()
        GameTooltip:Hide()
    end)
    t:SetScript("OnClick", function(self)
        pick.record = self.record
        pick.done(self.record)
        CH.HideDecorPicker()
    end)
    function t.Mark(self)
        local on = self.record == pick.record
        self:SetBackdropBorderColor(CH.RGBA(on and CH.COLORS.gold or CH.COLORS.border, on and 1 or 0.6))
    end
    return t
end

local function PageButton(glyph, by)
    local b = CH.MakeButton(pane, "", 26, 22)
    b:SetText(glyph)
    b:SetScript("OnClick", function()
        page = page + by
        Render()
    end)
    return b
end

local function FilterButton(key, value, tip)
    local b = CH.MakeButton(pane, key, 84, 22)
    if tip then
        CH.Tip(b, tip)
    end
    b:SetScript("OnClick", function()
        filter = value
        Search()
    end)
    return b
end

-- The categories the catalog sorts decor into, as a menu.
local function CategoryMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateRadio(CH.L["SY_ALL_CATEGORIES"], function()
            return category == nil
        end, function()
            category = nil
            Search()
        end)
        local ids = C_HousingCatalog.SearchCatalogCategories({
            withStoredEntriesOnly = false,
            includeFeaturedCategory = false,
            editorModeContext = Enum.HouseEditorMode.BasicDecor,
        })
        for _, id in ipairs(ids) do
            local info = C_HousingCatalog.GetCatalogCategoryInfo(id)
            if info and info.name then
                root:CreateRadio(info.name, function()
                    return category == id
                end, function()
                    category = id
                    Search()
                end)
            end
        end
    end)
end

local function Build()
    pane = CreateFrame("Frame", nil, FP.win)
    pane:SetPoint("TOPLEFT", FP.rail, "TOPRIGHT", 1, 0)
    pane:SetPoint("BOTTOMRIGHT")
    pane:Hide()

    CH.MakeSectionHeader(pane, "SY_FIND_TITLE", -12):SetPoint("TOPLEFT", 16, -12)
    local close = CH.MakeGlyphButton(pane, "x")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", CH.HideDecorPicker)

    local box = CH.MakeBox(pane, 220, 40)
    box:SetPoint("TOPLEFT", 20, -38)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:HookScript("OnTextChanged", function(_, typed)
        if typed then
            SearchSoon()
        end
    end)
    CH.AddPlaceholder(box, function()
        return CH.L["SY_SEARCH_HINT"]
    end)
    pane.searchBox = box

    pane.count = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.count:SetPoint("LEFT", box, "RIGHT", 12, 0)
    pane.count:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    pane.filters = {
        all = FilterButton("SY_FILTER_ALL", "all"),
        house = FilterButton("SY_FILTER_HOUSE", "house", "SY_FILTER_HOUSE_TT"),
        placed = FilterButton("SY_FILTER_PLACED", "placed", "SY_FILTER_PLACED_TT"),
        owned = FilterButton("SY_FILTER_OWNED", "owned"),
    }
    pane.filters.all:SetPoint("TOPLEFT", 16, -66)
    pane.filters.house:SetPoint("LEFT", pane.filters.all, "RIGHT", 6, 0)
    pane.filters.placed:SetPoint("LEFT", pane.filters.house, "RIGHT", 6, 0)
    pane.filters.owned:SetPoint("LEFT", pane.filters.placed, "RIGHT", 6, 0)
    local cat = CH.MakeButton(pane, "SY_CATEGORY", 100, 22)
    cat:SetPoint("LEFT", pane.filters.owned, "RIGHT", 6, 0)
    cat:SetScript("OnClick", CategoryMenu)
    pane.category = cat

    pane.tiles = {}
    for n = 1, PER_PAGE do
        pane.tiles[n] = Tile(n)
    end
    pane.none = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.none:SetPoint("TOPLEFT", 18, -104)
    pane.none:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    pane.next = PageButton(">", 1)
    pane.next:SetPoint("BOTTOMRIGHT", -16, 12)
    pane.pageText = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.pageText:SetPoint("RIGHT", pane.next, "LEFT", -8, 0)
    pane.prev = PageButton("<", -1)
    pane.prev:SetPoint("RIGHT", pane.pageText, "LEFT", -8, 0)

    pane:EnableMouseWheel(true)
    pane:SetScript("OnMouseWheel", function(_, d)
        local to = math.max(1, math.min(LastPage(), page - d))
        if to ~= page then
            page = to
            Render()
        end
    end)
    pane:SetScript("OnHide", function()
        if searchTimer then
            searchTimer:Cancel()
        end
        box:ClearFocus()
    end)
end

function Render()
    local last = LastPage()
    page = math.max(1, math.min(last, page))
    for n, t in ipairs(pane.tiles) do
        local record = results[(page - 1) * PER_PAGE + n]
        t.record = record
        local info = record and t.model:SetDecor(record)
        t:SetShown(info ~= nil)
        if info then
            t.name:SetText(info.name)
            t:Mark()
        end
    end
    pane.none:SetText(#results == 0 and CH.L["SY_NONE_FOUND"] or "")
    pane.count:SetText(string.format(CH.L["SY_FOUND_X"], #results))
    pane.pageText:SetText(string.format(CH.L["SY_PAGE_X"], page, last))
    pane.prev:SetEnabled(page > 1)
    pane.next:SetEnabled(page < last)
    for value, b in pairs(pane.filters) do
        CH.SetButtonActive(b, value == filter)
    end
    pane.category:SetEnabled(filter ~= "house")
end

-- The list over the map of house guid, for the editor's pick, which is
-- { record, done }: pick.record the decor so far and pick.done(record) hears
-- the click that picks one. The list closes on a pick.
function CH.ShowDecorPicker(guid, p)
    if not pane then
        Build()
    end
    pick, houseGUID = p, guid
    -- a room wearing decor already opens on the house's own
    filter = #HouseDecor(results) > 0 and "house" or "all"
    pane.searchBox:SetText("")
    CH.HideRoomBannerPicker()
    FP.map:Hide()
    pane:Show()
    Search()
end

function CH.HideDecorPicker()
    if pane and pane:IsShown() then
        pane:Hide()
        FP.map:Show()
    end
end
