local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Music picker: search the game's music, hear a track, pick it
-- ─────────────────────────────────────────────────────────────────────
-- The window sits on a screen-wide invisible button, so a click anywhere
-- outside it closes the picker without picking. Clicking a track plays it over
-- whatever the house has on, and closing hands the music back.
--
-- For a room there is a second tab with the sound list under its headers, where
-- a typed number is offered as a sound by file id. Plays sets whether the pick
-- loops or runs one to five times on walking in.

local ROW_H = 18
local MAX_ROWS = 200

local catcher = CreateFrame("Button", "ChamberlainMusicPicker", UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
table.insert(UISpecialFrames, "ChamberlainMusicPicker")

local win = CreateFrame("Frame", nil, catcher, "BackdropTemplate")
win:SetSize(440, 498)
win:SetPoint("CENTER")
win:EnableMouse(true) -- or clicks on the window would reach the catcher under it
CH.SkinWindow(win, "MP_TITLE")

local selected -- id of the clicked track, what Use this track hands back
local plays -- 1 to 5, nil loops
local forRoom
local onPick
local soundPreview -- a custom sound of ours is on the preview slot
local results = {}
local rows = {}

-- Tabs like the Rooms window has them, the open one disabled. Sound effects is
-- only offered when picking for a room, a floor or the house takes music only.
local tab = "music"
local tabMusic = CH.MakeButton(win, "MP_TAB_MUSIC", 80, 22)
local tabSounds = CH.MakeButton(win, "MP_TAB_SOUNDS", 140, 22)
tabMusic:SetPoint("TOPLEFT", 12, -30)
tabSounds:SetPoint("LEFT", tabMusic, "RIGHT", 2, 0)

local tabSep = win:CreateTexture(nil, "ARTWORK")
tabSep:SetHeight(1)
tabSep:SetPoint("TOPLEFT", 12, -54)
tabSep:SetPoint("TOPRIGHT", -12, -54)
tabSep:SetColorTexture(CH.RGBA(CH.COLORS.sep, 0.8))

local searchBox = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
searchBox:SetSize(404, 20)
searchBox:SetPoint("TOPLEFT", 20, -62)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(60)

local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 6, 0)

local status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 16, -90)
status:SetPoint("RIGHT", -16, 0)
status:SetJustifyH("LEFT")
status:SetWordWrap(false)
status:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local scroll, list = CH.MakeScrollList(win, "ChamberlainMusicScroll")
scroll:SetPoint("TOPLEFT", 12, -108)
scroll:SetPoint("BOTTOMRIGHT", -30, 42)
list:SetWidth(396)

local btnUse = CH.MakeButton(win, "MP_USE", 110, 22)
local btnNone = CH.MakeButton(win, "MP_NONE", 80, 22)
local btnCancel = CH.MakeButton(win, "RD_CANCEL", 70, 22)
btnUse:SetPoint("BOTTOMLEFT", 12, 10)
btnNone:SetPoint("LEFT", btnUse, "RIGHT", 4, 0)
btnCancel:SetPoint("BOTTOMRIGHT", -12, 10)

local function PlaysLabel(n)
    return n == 1 and CH.L["MP_PLAYS_ONCE"] or string.format(CH.L["MP_PLAYS_X"], n)
end

local btnPlays = CH.MakeMenuButton(win, 120, "MP_LOOPS", function()
    return plays and PlaysLabel(plays)
end, function(root, btn)
    root:CreateRadio(CH.L["MP_LOOPS"], function()
        return plays == nil
    end, function()
        plays = nil
        btn:Refresh()
    end)
    for n = 1, 5 do
        root:CreateRadio(PlaysLabel(n), function()
            return plays == n
        end, function()
            plays = n
            btn:Refresh()
        end)
    end
end)
btnPlays:SetPoint("RIGHT", btnCancel, "LEFT", -4, 0)
CH.Tip(btnPlays, "MP_TT_PLAYS")
-- "No music" on this button got read as Silence, which is the opposite
CH.Tip(btnNone, "MP_TT_NONE")

-- A listed track goes on the music slot like it will in the room. Anything
-- else can't, so it plays as a plain sound.
local function Preview(id)
    local listed = id and CH.MusicPath(id)
    CH.PreviewMusic(listed and id or nil)
    if soundPreview or (id and not listed) then
        soundPreview = id and not listed
        CH.PreviewSound(soundPreview and id or nil, "SFX")
    end
end

local function Render()
    for i, track in ipairs(results) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", nil, list)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("RIGHT")
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 6, 0)
            row.text:SetPoint("RIGHT", -6, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self)
                -- Moving to another row puts Plays where that kind of pick
                -- usually wants it. A track loops on the music slot. A scream
                -- on a loop is rarely the idea, so a sound plays once unless a
                -- count was already set, with Loops in the menu for a heartbeat.
                if forRoom and self.id ~= selected then
                    if CH.MusicPath(self.id) then
                        plays = nil
                    else
                        plays = plays or 1
                    end
                    btnPlays:Refresh()
                end
                selected = self.id
                Preview(selected)
                Render()
            end)
            rows[i] = row
        end
        row.id = track.id
        row.text:SetText(track.path)
        -- a row without an id is a section header
        row:EnableMouse(track.id ~= nil)
        if not track.id then
            row.text:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
        elseif track.id == selected then
            row.text:SetTextColor(CH.RGBA(CH.COLORS.tipGold, 1))
        else
            row.text:SetTextColor(1, 1, 1)
        end
        row:Show()
    end
    for i = #results + 1, #rows do
        rows[i]:Hide()
    end
    list:SetHeight(math.max(#results, 1) * ROW_H)
    btnUse:SetEnabled(selected ~= nil)
end

-- Does text hold every one of the words, in any order.
local function Matches(text, words)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then
            return false
        end
    end
    return true
end

-- The Music tab keeps Silence on top, then the track that is set or, with
-- words typed, every track whose path holds them.
local function ListMusic(words)
    results[1] = { id = CH.SILENCE, path = CH.L["MP_SILENCE"] }
    if #words == 0 then
        if selected and selected ~= CH.SILENCE and CH.MusicPath(selected) then
            results[2] = { id = selected, path = CH.SoundName(selected) }
        end
        return
    end
    for id, path in CH.MUSIC_LIST:gmatch("(%d+);([^\n]+)") do
        if Matches(path, words) then
            results[#results + 1] = { id = tonumber(id), path = path }
            if #results == MAX_ROWS then
                break
            end
        end
    end
    return #results - 1 -- less the Silence row
end

-- The Sound effects tab has the listed sounds under their headers, or the ones
-- whose name holds the typed words. A number is offered as a file of its own.
local function ListSounds(words, text)
    if #words == 0 then
        if selected and selected ~= CH.SILENCE and not CH.MusicPath(selected) then
            results[1] = { id = selected, path = CH.SoundName(selected) }
        end
        for _, cat in ipairs(CH.SOUND_CATS) do
            results[#results + 1] = { path = CH.L[cat] }
            for _, sound in ipairs(CH.SOUNDS) do
                if sound.cat == cat then
                    results[#results + 1] = { id = sound.id, path = "   " .. CH.L[sound.key] }
                end
            end
        end
        return
    end
    local typedID = tonumber(text)
    if CH.IsFileID(typedID) then
        results[1] = { id = typedID, path = CH.SoundName(typedID) }
    end
    for _, sound in ipairs(CH.SOUNDS) do
        if Matches(CH.L[sound.key]:lower(), words) then
            results[#results + 1] = { id = sound.id, path = CH.L[sound.key] }
        end
    end
    return #results
end

local function Search(text)
    wipe(results)
    local words = {}
    for word in text:lower():gmatch("%S+") do
        words[#words + 1] = word
    end
    local found
    if tab == "music" then
        found = ListMusic(words)
    else
        found = ListSounds(words, text)
    end
    if found then
        status:SetText(string.format(CH.L[#results == MAX_ROWS and "MP_FIRST_X" or "MP_FOUND_X"], found))
    else
        status:SetText(CH.L[tab == "music" and "MP_EMPTY_HINT" or "MP_EMPTY_HINT_SOUNDS"])
    end
    scroll:SetVerticalScroll(0)
    Render()
end

local function ShowTab(which)
    tab = which
    tabMusic:SetEnabled(tab ~= "music")
    tabSounds:SetEnabled(tab ~= "sounds")
    searchHint:SetText(CH.L[tab == "music" and "MP_SEARCH_HINT" or "MP_SEARCH_HINT_SOUNDS"])
    -- SetText only fires OnTextChanged when the text changes, so search by hand
    searchBox:SetText("")
    Search("")
end
tabMusic:SetScript("OnClick", function()
    ShowTab("music")
end)
tabSounds:SetScript("OnClick", function()
    ShowTab("sounds")
end)

local function Close()
    catcher:Hide()
end

searchBox:SetScript("OnTextChanged", function(self)
    searchHint:SetShown(self:GetText() == "")
    Search(self:GetText())
end)
searchBox:SetScript("OnEscapePressed", Close)
searchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

catcher:SetScript("OnClick", Close)
catcher:SetScript("OnHide", function()
    searchBox:ClearFocus()
    Preview(nil)
end)
btnCancel:SetScript("OnClick", Close)

-- Hands back done(id, plays), plays as in ReadRoomMusic (Sharing/Share.lua).
local function Pick(id)
    local done = onPick
    local count
    -- silence only means something on the music slot, so it never gets a count
    if id and id ~= CH.SILENCE then
        count = plays
        if not count and not CH.MusicPath(id) then
            count = 0
        end
    end
    Close()
    done(id, count)
end
btnUse:SetScript("OnClick", function()
    Pick(selected)
end)
btnNone:SetScript("OnClick", function()
    Pick(nil)
end)

-- current is the id set right now or nil. done gets the new pick, nil for no
-- music, and closing any other way calls nothing.
function CH.OpenMusicPicker(current, done, room, currentPlays)
    selected = current
    onPick = done
    forRoom = room
    plays = currentPlays and currentPlays > 0 and currentPlays or nil
    btnPlays:SetShown(room == true)
    btnPlays:Refresh()
    tabSounds:SetShown(room == true)
    catcher:Show()
    -- open on the tab the current pick lives on
    local isSound = current and current ~= CH.SILENCE and not CH.MusicPath(current)
    ShowTab(room and isSound and "sounds" or "music")
    searchBox:SetFocus()
end
