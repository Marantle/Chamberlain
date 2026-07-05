local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- What's New popup
-- ─────────────────────────────────────────────────────────────────────
-- A one-time notice that pops the first time you step indoors after updating.
-- It lists the changes since the version you last ran, with a Close button and a
-- "Don't show again" button that silences all future update notes. The auto path
-- is CH.MaybeShowWhatsNew, wired into house entry in Housing/Housing.lua; the
-- manual path is CH.OpenWhatsNew (/rooms whatsnew), which ignores the opt-out so a
-- silenced player can still read the notes.

-- Release notes shown in-game, newest first. Keep in step with CHANGELOG.md, but
-- trimmed to the lines worth surfacing in a popup. Only versions strictly newer
-- than the player's last-seen version are shown, so a release just appends a new
-- block at the top. The changelog is authored in English and other locales fall
-- back to it, so these are plain strings rather than CH.L keys; the window chrome
-- (title, buttons) is still localized.
CH.WHATS_NEW = {
    {
        v = "3.0.0",
        notes = {
            "The HUD is now a small launcher: Build, Map, Rooms, Settings.",
            "Build opens a toolbox with your live coordinates and the room tools.",
            "No more Mark A / Mark B. Stand where you want a room and click Square "
                .. "room or Round room; it drops at your feet and the name box opens.",
            "Fit a room while standing in it: pick it on the map or the dropdown, walk to a wall and press Snap "
                .. "nearest edge, or use Grow and Shrink.",
            "Rooms can be round, and a Floor pin sets which floor you're on from any spot.",
            "Settings moved into their own window (Settings button or /chamberlain settings).",
            "A Room banners switch turns the gold name banner off for map-only players.",
        },
    },
}

-- Compare dotted numeric versions. Returns true when a < b. Missing segments read
-- as 0, so "3" < "3.0.1", and a nil/garbage version parses to all-zero (older than
-- anything real).
local function VersionLess(a, b)
    local pa, pb = {}, {}
    for n in string.gmatch(a or "", "%d+") do
        pa[#pa + 1] = tonumber(n)
    end
    for n in string.gmatch(b or "", "%d+") do
        pb[#pb + 1] = tonumber(n)
    end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return x < y
        end
    end
    return false
end

-- The note blocks newer than `last`. With no marker (an upgrade from before this
-- feature existed) we return just the newest block, so an upgrader gets this
-- release's notes rather than the whole history the table might one day hold.
local function CollectBlocks(last)
    if not last then
        return CH.WHATS_NEW[1] and { CH.WHATS_NEW[1] } or {}
    end
    local blocks = {}
    for _, block in ipairs(CH.WHATS_NEW) do
        if VersionLess(last, block.v) then
            blocks[#blocks + 1] = block
        end
    end
    return blocks
end

local WIN_W, WIN_H = 380, 430
local CONTENT_W = WIN_W - 46 -- frame minus side margins and the scrollbar

local win, scrollChild
local linePool = {}
local shownThisSession = false

local function AcquireLine(i)
    local fs = linePool[i]
    if not fs then
        fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        linePool[i] = fs
    end
    return fs
end

local function Build()
    if win then
        return win
    end
    win = CreateFrame("Frame", "ChamberlainWhatsNew", UIParent, "BackdropTemplate")
    win:SetSize(WIN_W, WIN_H)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "|cffFFD700Chamberlain|r  " .. CH.L["WN_TITLE"])
    table.insert(UISpecialFrames, "ChamberlainWhatsNew")

    -- Close button in the header corner, the same gold x as the toolbox.
    local closeX = CreateFrame("Button", nil, win)
    closeX:SetSize(18, 18)
    closeX:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    local xFS = closeX:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xFS:SetAllPoints()
    xFS:SetText("|cffFFD700x|r")
    closeX:SetScript("OnEnter", function()
        xFS:SetText("|cffFFFFFFx|r")
    end)
    closeX:SetScript("OnLeave", function()
        xFS:SetText("|cffFFD700x|r")
    end)
    closeX:SetScript("OnClick", function()
        win:Hide()
    end)

    local subtitle = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 16, -30)
    subtitle:SetPoint("TOPRIGHT", -16, -30)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(CH.L["WN_SUBTITLE"])
    subtitle:SetTextColor(0.75, 0.75, 0.75, 1)

    local scroll, child = CH.MakeScrollList(win, "ChamberlainWhatsNewScroll")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", -14, 44)
    scrollChild = child
    scrollChild:SetWidth(CONTENT_W)

    local closeBtn = CH.MakeButton(win, CH.L["WN_CLOSE"], 110, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    closeBtn:SetScript("OnClick", function()
        win:Hide()
    end)

    local neverBtn = CH.MakeButton(win, CH.L["WN_NEVER"], 170, 24)
    neverBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 12)
    neverBtn:SetScript("OnClick", function()
        ChamberlainDB.settings.showUpdateNotes = false
        win:Hide()
        CH.Print(CH.L["WN_DISABLED"])
    end)

    return win
end

local function Populate(blocks)
    for _, fs in ipairs(linePool) do
        fs:Hide()
    end
    local y, i = -4, 0
    for _, block in ipairs(blocks) do
        i = i + 1
        local head = AcquireLine(i)
        head:SetFontObject("GameFontNormal")
        head:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
        head:SetWidth(CONTENT_W)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 4, y)
        head:SetText(string.format(CH.L["WN_VERSION_HEADER"], block.v))
        head:Show()
        y = y - head:GetStringHeight() - 6

        for _, line in ipairs(block.notes) do
            i = i + 1
            local fs = AcquireLine(i)
            fs:SetFontObject("GameFontHighlightSmall")
            fs:SetTextColor(0.85, 0.85, 0.85, 1)
            fs:SetWidth(CONTENT_W - 12)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 12, y)
            fs:SetText("|cffFFD700\226\128\162|r " .. line) -- gold bullet + note
            fs:Show()
            y = y - fs:GetStringHeight() - 6
        end
        y = y - 8
    end
    scrollChild:SetHeight(math.max(-y + 8, 1))
end

-- Auto path: called on house entry. Shows once per session and only when there's
-- something newer than the last-seen version, unless the player has opted out.
-- Either way the last-seen marker is advanced so the notice doesn't re-fire.
function CH.MaybeShowWhatsNew()
    if shownThisSession then
        return
    end
    if not (ChamberlainDB and ChamberlainDB.settings) then
        return
    end
    local last = ChamberlainDB.lastSeenVersion
    -- Already current: nothing new to say.
    if last and not VersionLess(last, CH.VERSION) then
        return
    end

    if ChamberlainDB.settings.showUpdateNotes == false then
        -- Opted out: stay silent, but move the marker forward so re-enabling later
        -- doesn't dump notes the player already lived through.
        ChamberlainDB.lastSeenVersion = CH.VERSION
        return
    end

    local blocks = CollectBlocks(last)
    shownThisSession = true
    ChamberlainDB.lastSeenVersion = CH.VERSION -- won't reappear next entry or login
    if #blocks == 0 then
        return
    end
    Build():Show()
    Populate(blocks)
end

-- Manual path: /rooms whatsnew. Ignores the opt-out and the last-seen marker so a
-- silenced player can re-read the latest notes on demand.
function CH.OpenWhatsNew()
    local blocks = CollectBlocks(ChamberlainDB.lastSeenVersion)
    if #blocks == 0 then
        blocks = CH.WHATS_NEW[1] and { CH.WHATS_NEW[1] } or {}
    end
    if #blocks == 0 then
        return
    end
    Build():Show()
    win:Raise()
    Populate(blocks)
end
