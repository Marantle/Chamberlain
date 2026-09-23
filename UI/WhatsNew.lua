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
-- (title, buttons) is still localized. A block may also carry `toggles`, a list of
-- { label key, settings key } pairs drawn as toggle buttons under its notes, plus
-- an `onToggle` run after any of them flips.
CH.WHATS_NEW = {
    {
        v = "3.15.0",
        notes = {
            "Whole house and floor sounds changes now reaches your group even when their map is older "
                .. "than yours. Pick an ambience or a track for the whole house, or for one "
                .. "floor, and everyone who has your map hears it.",
            "A room's own sound still needs their map to match yours. Send yours again with "
                .. "Share My Houses after you add, move or delete a room.",
        },
    },
    {
        v = "3.14.0",
        notes = {
            "Echoes. A room's sound on entry can carry through the house, so the bell on "
                .. "your front door rings for you in the cellar when a guest walks in. Click "
                .. "Entry sound in the room dialog and drag the Echo slider.",
            "The house can have an arrival sound, picked with the Arrival button on the "
                .. "house map. It rings for everyone inside with your map when somebody with "
                .. "Chamberlain walks in.",
            "Everyone in the house with your map hears an echo, if they share a group or a "
                .. "guild with whoever walked in. Each person rings a room for you once in 30 "
                .. "seconds, or as often as you set.",
            "An entry sound set to play once or a few times plays to the end even if you've "
                .. "left the room, so a thin trigger across a doorway rings in full.",
            "The sound list got a shop door bell and a ding dong doorbell. Knocks, dinner "
                .. "bells, chimes, alarms, war horns and a foghorn came with them.",
            "The bar has a Sharing button, with a gold dot when your group has a map of the "
                .. "house you're in. Settings and Sound are the gear and the speaker in its title.",
            "Right click the speaker to mute one kind of house sound. The "
                .. "arrival sound has a tick for group members and one for guildmates.",
            "Two sliders in the settings set how soon the same person or room rings for you again.",
            "Share My Houses and Export ask which house when you have more than one.",
            "Import shows what a string holds before you accept it, and says so in red when "
                .. "the string is aimed at your own house.",
        },
        toggles = { { "HUD_KIND_ECHOES", "echoes" } },
        -- the bar's speaker greys while a kind is off
        onToggle = function()
            CH.RefreshHudSound()
        end,
    },
    {
        v = "3.12.0",
        notes = {
            "Now playing. The Chamberlain bar's title names the music and ambience the "
                .. "house has on. Hover it for the full track path. Guests see it too.",
            "A room's sound on entry has its own row in the room dialog now, Entry sound, "
                .. "so a room can have music and a sound. Rooms that had one keep it.",
            "When the owner changes a sound while you're in their house, chat tells you "
                .. "the name of the new track or ambience.",
            "The music window lists the tracks your house already uses before you type "
                .. "anything, so reusing one takes a click.",
        },
    },
    {
        v = "3.11.0",
        notes = {
            "78 more ambience loops for your rooms. Naxxramas and Frostmourne are in, so "
                .. "are a dozen cities and the Darkmoon Faire. The Ambience menu is split "
                .. "into short categories now.",
            "Click a sound in the Ambience menu and it plays while the menu stays open, "
                .. "so you can compare a few before you settle on one.",
        },
    },
    {
        v = "3.10.0",
        notes = {
            "Music. Give a room, a floor or the whole house a track from the game's own "
                .. "music and it plays in place of the usual music while you're there. "
                .. "Music is in the room dialog and on the house map. Search, click a "
                .. "track to hear it and press Use this track. The Sound button on the "
                .. "Chamberlain bar mutes it along with the ambience, in any house.",
            "Silence is one of the picks, for a room that should have no music. A room "
                .. "can also play a laugh, a bell or a murloc as you walk in, from the "
                .. "Fun sound effects tab.",
            "Change an ambience or a track while grouped and everyone who has your map "
                .. "hears it right away, so the weather can turn mid scene.",
        },
    },
    {
        v = "3.9.0",
        notes = {
            "Ambience for the whole house and for each floor. The Ambience button is in "
                .. "the top left corner of your house map. A room's own sound plays "
                .. "instead of the floor's, and the floor's instead of the house's.",
        },
    },
    {
        v = "3.8.0",
        notes = {
            "Room ambience. Edit a room and pick an Ambience for it from 45 of the game's "
                .. "own loops, a crowded tavern or a slow river for instance. It fades in as "
                .. "you walk in and visitors with your shared map hear it too.",
            "Untick Banner on a small room to make a sound spot, a fire by the hearth or "
                .. "a fountain in the corner, that plays on top of the room around it.",
        },
        toggles = { { "RM_TOGGLE_AMBIENCE", "ambienceEnabled" } },
        onToggle = function()
            CH.RefreshHudSound()
        end,
    },
    {
        v = "3.7.0",
        notes = {
            "The Archive. Store the room map of your house under a name before you "
                .. "reset the house or load another blueprint, and bring it back later. "
                .. "Keep as many maps per house as you like and switch between them. "
                .. "Archive is in the Rooms window and at /rooms archive, and the launcher "
                .. "bar shows it while the house is empty and a stored map is waiting.",
            "Stored maps stay on your computer. Sharing and export only ever send the map that is in the house.",
            "Pick a blueprint when storing and the map takes its name. Save a full "
                .. "layout or interior blueprint and it offers to store the map with it. "
                .. "Load one and its map comes back. Reset the house and it asks whether "
                .. "to store or clear the map that's still there.",
        },
    },
    {
        v = "3.6.0",
        notes = {
            "Rooms on the minimap. Indoors the game shows a still picture of a house "
                .. "where the minimap was. Turn on Rooms on the minimap in Settings and "
                .. "the rooms of your floor take its place, you in the middle, with the "
                .. "zoom buttons setting how much of the house fits. If an addon squares "
                .. "your minimap, flip Square minimap too.",
        },
        -- Same buttons as Settings, so it can be tried straight from the note.
        toggles = {
            { "RM_TOGGLE_MINIMAP_ROOMS", "minimapRooms" },
            { "RM_TOGGLE_MINIMAP_SQUARE", "minimapSquare" },
        },
        onToggle = function()
            CH.RefreshMinimapRooms()
        end,
    },
    {
        v = "3.5.0",
        notes = {
            "The Floor pin now asks which floor it works from. It starts on the floor "
                .. "you are standing on, so it fires only from there and the map shows "
                .. "it only there. Step the selector down past floor 1 to get the old "
                .. "kind that works from every floor.",
            "Pins can build custom stairs now. Two of them pointing at each other work "
                .. "exactly like a stair pair, and a single one covers a one-way trip, "
                .. "like a ladder up or a balcony jump down.",
            "The house map draws floor markers where they actually live. A lone pin or "
                .. "a one-floor hop shows only on its own floor now, while a stair pair "
                .. "still shows on both floors it connects.",
            "Editing stairs got simpler. The edit window shows the same two rows as "
                .. "the pin, which floor it works from and which floor it sends you to, "
                .. "and any combination can be set directly.",
        },
    },
    {
        v = "3.4.0",
        notes = {
            "There is a small thank-you waiting in Settings, behind a From the creator "
                .. "button. Give it a minute when you have one to spare.",
            "Sharing got a sibling switch, Receiving. Turn it off and other people's "
                .. "houses never reach you, no catalogs, no popups. Sharing off now also "
                .. "ignores requests for your houses instead of asking you to decline them.",
        },
    },
    {
        v = "3.3.0",
        notes = {
            "The build toolbox now docks to the house map, so Build opens them as one "
                .. "window. Drag the toolbox away to float it on its own again, and the « "
                .. "button in its header glues it back.",
            "If you moved your house to a new neighborhood and the addon no longer knows which rooms "
                .. "belong to it, so the map comes up empty. It now offers a Fix house button "
                .. "there, which opens a window listing your saved houses. Pick the one that is "
                .. "really the house you are standing in and its rooms come back.",
        },
    },
    {
        v = "3.1.0",
        notes = {
            "Moved your house to another neighborhood? It gets a new internal id and owner name, so "
                .. "the rooms stayed parked on the old one and the new house came up empty. Stand in "
                .. "your house and run /rooms fixer, then pick the saved house that is really this "
                .. "one. It only works in a house you own.",
            "Share My Houses stays disabled while a share is still sending, and a Request button "
                .. "waits a few seconds after you click it, so neither can be spammed.",
        },
    },
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
local togglePool = {} -- by settings key so each block's toggles are built once
local shownThisSession = false

local function AcquireToggle(block, labelKey, key)
    local b = togglePool[key]
    if not b then
        b = CH.MakeToggleButton(scrollChild, labelKey, key)
        if block.onToggle then
            b:HookScript("OnClick", block.onToggle)
        end
        togglePool[key] = b
    end
    b:Refresh()
    return b
end

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
    CH.SkinWindow(win, "WN_TITLE", true)
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
    subtitle:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

    local scroll, child = CH.MakeScrollList(win, "ChamberlainWhatsNewScroll")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", -14, 44)
    scrollChild = child
    scrollChild:SetWidth(CONTENT_W)

    local closeBtn = CH.MakeButton(win, "WN_CLOSE", 110, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    closeBtn:SetScript("OnClick", function()
        win:Hide()
    end)

    local neverBtn = CH.MakeButton(win, "WN_NEVER", 170, 24)
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
    for _, b in pairs(togglePool) do
        b:Hide()
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
        for _, t in ipairs(block.toggles or {}) do
            local b = AcquireToggle(block, t[1], t[2])
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 12, y)
            b:Show()
            y = y - 24
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
        -- doesn't dump notes the player already lived through. unreadSince keeps
        -- where they left off, for the note icon on the bar, and holds on to the
        -- oldest of a run of skipped updates.
        ChamberlainDB.unreadSince = ChamberlainDB.unreadSince or last
        ChamberlainDB.lastSeenVersion = CH.VERSION
        CH.RefreshHUDMode()
        return
    end

    -- whoever turned the window back on gets what they skipped along with it
    local blocks = CollectBlocks(ChamberlainDB.unreadSince or last)
    ChamberlainDB.unreadSince = nil
    CH.RefreshHUDMode()
    shownThisSession = true
    ChamberlainDB.lastSeenVersion = CH.VERSION -- won't reappear next entry or login
    if #blocks == 0 then
        return
    end
    Build():Show()
    Populate(blocks)
end

-- Manual path: /rooms whatsnew and the bar's note icon. Ignores the opt-out and
-- the last-seen marker so a silenced player can re-read the latest notes on
-- demand. Notes the icon was waving about count as read from here.
function CH.OpenWhatsNew()
    local blocks = CollectBlocks(ChamberlainDB.unreadSince or ChamberlainDB.lastSeenVersion)
    ChamberlainDB.unreadSince = nil
    CH.RefreshHUDMode()
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
