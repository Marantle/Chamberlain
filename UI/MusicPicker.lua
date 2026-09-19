local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Music picker: search the game's music, hear a track, pick it
-- ─────────────────────────────────────────────────────────────────────
-- The window sits on a screen-wide invisible button, so a click anywhere
-- outside it closes the picker without picking. Clicking a track plays it over
-- whatever the house has on, and closing hands the music back.
--
-- A room's sound on entry is picked here as well. Opened for sounds the list
-- is the sound list under its headers and a typed number is offered as a sound
-- by file id. Plays sets whether the pick loops or runs one to five times on
-- walking in.

local ROW_H = 18
local MAX_ROWS = 200

local catcher = CreateFrame("Button", "ChamberlainMusicPicker", UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
table.insert(UISpecialFrames, "ChamberlainMusicPicker")

local win = CreateFrame("Frame", nil, catcher, "BackdropTemplate")
win:SetSize(440, 472)
win:SetPoint("CENTER")
win:EnableMouse(true) -- or clicks on the window would reach the catcher under it
CH.SkinWindow(win, "MP_TITLE")

local selected -- id of the clicked row, what the Use button hands back
local sounds -- picking a sound on entry, music otherwise
local plays -- 1 to 5, nil loops, sounds only
local house -- the house entry being picked for
local onPick
local results = {}
local rows = {}

local searchBox = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
searchBox:SetSize(404, 20)
searchBox:SetPoint("TOPLEFT", 20, -36)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(60)

local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 6, 0)

local status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 16, -64)
status:SetPoint("RIGHT", -16, 0)
status:SetJustifyH("LEFT")
status:SetWordWrap(false)
status:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local scroll, list = CH.MakeScrollList(win, "ChamberlainMusicScroll")
scroll:SetPoint("TOPLEFT", 12, -82)
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
CH.Tip(btnNone, function()
    return sounds and "MP_TT_NONE_SOUND" or "MP_TT_NONE"
end)

-- On the slot and channel the pick will play on in the room.
local function Preview(id)
    if sounds then
        CH.PreviewSound(id, "SFX")
    else
        CH.PreviewMusic(id)
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
                -- A scream on a loop is rarely the idea, so moving to another
                -- sound sets it to play once unless a count was already set,
                -- with Loops in the menu for a heartbeat.
                if sounds and self.id ~= selected then
                    plays = plays or 1
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

-- With nothing typed the list opens on the pick that is set, then on what the
-- house already plays somewhere under a header of its own, so the track from
-- the hall is one click away for the next room.
local function ListInUse()
    if selected and selected ~= CH.SILENCE then
        results[#results + 1] = { id = selected, path = CH.SoundName(selected) }
    end
    local header
    for _, id in ipairs(CH.HousePicks(house, sounds and "sfx" or "music")) do
        if id ~= selected then
            if not header then
                header = true
                results[#results + 1] = { path = CH.L["MP_IN_HOUSE"] }
            end
            results[#results + 1] = { id = id, path = "   " .. CH.SoundName(id) }
        end
    end
end

-- Music keeps Silence on top. With words typed it lists every track whose path
-- holds them.
local function ListMusic(words)
    results[1] = { id = CH.SILENCE, path = CH.L["MP_SILENCE"] }
    if #words == 0 then
        ListInUse()
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

-- Sounds has the listed ones under their headers, or those whose name holds the
-- typed words. A number is offered as a file of its own.
local function ListSounds(words, text)
    if #words == 0 then
        ListInUse()
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
    if sounds then
        found = ListSounds(words, text)
    else
        found = ListMusic(words)
    end
    if found then
        status:SetText(string.format(CH.L[#results == MAX_ROWS and "MP_FIRST_X" or "MP_FOUND_X"], found))
    else
        status:SetText(CH.L[sounds and "MP_EMPTY_HINT_SOUNDS" or "MP_EMPTY_HINT"])
    end
    scroll:SetVerticalScroll(0)
    Render()
end

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

-- Hands back done(id), and for a sound done(id, plays) with plays as in
-- ReadRoomSounds (Sharing/Share.lua).
local function Pick(id)
    local done = onPick
    Close()
    done(id, sounds and id and (plays or 0) or nil)
end
btnUse:SetScript("OnClick", function()
    Pick(selected)
end)
btnNone:SetScript("OnClick", function()
    Pick(nil)
end)

-- current is the id set right now or nil. done gets the new pick, nil for
-- none, and closing any other way calls nothing. h is the house entry the pick
-- is for. forSounds opens it for a room's sound on entry and currentPlays is
-- its count.
function CH.OpenMusicPicker(current, done, h, forSounds, currentPlays)
    selected = current
    onPick = done
    house = h
    sounds = forSounds
    plays = currentPlays and currentPlays > 0 and currentPlays or nil
    CH.SetWindowTitle(win, sounds and "MP_TITLE_SOUNDS" or "MP_TITLE")
    btnUse:SetText(CH.L[sounds and "MP_USE_SOUND" or "MP_USE"])
    searchHint:SetText(CH.L[sounds and "MP_SEARCH_HINT_SOUNDS" or "MP_SEARCH_HINT"])
    btnPlays:SetShown(sounds == true)
    btnPlays:Refresh()
    catcher:Show()
    -- SetText only fires OnTextChanged when the text changes, so search by hand
    searchBox:SetText("")
    Search("")
    searchBox:SetFocus()
end
