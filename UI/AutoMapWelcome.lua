local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Welcome home  (Auto map offered in your own house with no rooms yet)
-- ─────────────────────────────────────────────────────────────────────
-- A first walk into a house of yours with an empty map gets a word from the
-- Chamberlain in the middle of the screen: stand in the entrance and
-- start Auto map from here. The window stays up while Auto map runs, so
-- there is always a way to stop it, and it goes away with it. Closing it
-- stops Auto map too, and says where to start it again. Once a visit, on
-- every walk in while the map is empty, and never on a locked map, where Auto
-- map can't place anything.

-- The first steps guide (3.45.0) lives in the same window. A house whose map
-- was empty when the window first opened gets a step in ChamberlainDB.guide,
-- kept per house so a logout picks up where you left off. The steps tick
-- themselves as you play. DONE is the page after the last step, and false a
-- guide that's over. Houses mapped before only get one through Show again or
-- /rooms guide.

local W = 400
local STEPS = 5
local DONE = STEPS + 1

local win = CreateFrame("Frame", "ChamberlainWelcome", UIParent, "BackdropTemplate")
win:SetWidth(W)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:SetPoint("CENTER", 0, 60)
CH.MakeDraggable(win)
CH.SkinWindow(win, "AM_TITLE", true)
win:Hide()
-- Kept off UISpecialFrames: Hide UI closed it along with the Escape ones,
-- and Auto map went with it. Close and the x are the way out.
CH.autoMapGuide = win

local closeBtn = CH.MakeGlyphButton(win, "x")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    win:Hide()
end)

-- Widths, not a right anchor: a RIGHT point pins the text's middle to the
-- window's middle as well and squeezes it into a "..." line.
local TEXT_W = W - 36
local ROW_H = 20

-- One line per step of the guide, and a band behind the one you're on.
local current = win:CreateTexture(nil, "ARTWORK")
current:SetHeight(ROW_H)
current:SetColorTexture(CH.RGBA(CH.COLORS.border, 0.35))
local rows = {}
for i = 1, STEPS do
    local fs = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 18, -16 - i * ROW_H)
    fs:SetWidth(TEXT_W)
    fs:SetJustifyH("LEFT")
    rows[i] = fs
end

local body = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body:SetWidth(TEXT_W)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")
body:SetSpacing(3)

-- A word about the room Auto map put down last, when there's something to do
-- in it: walk an L or a T so its turn comes right, take a stairwell up.
local hint = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hint:SetWidth(TEXT_W)
hint:SetJustifyH("LEFT")
hint:SetSpacing(2)
local hintKey, hintArg

local note = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
note:SetWidth(TEXT_W)
note:SetJustifyH("LEFT")
note:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
note:SetText(CH.L["AM_NOTE"])

-- a guide that's over reads as none
local function GuideStep()
    return ChamberlainDB.guide[CH.currentHouseGUID] or nil
end

local function SetGuide(step)
    ChamberlainDB.guide[CH.currentHouseGUID] = step
end

local function RoomsHere()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return h and CH.RoomCount(h.zones) or 0
end

-- The guide's button for each step. Without a guide, and on step 2, it's the
-- plain Auto map switch. Step 5 is walking only, so false hides it.
local JOBS = { "AM_DROP", nil, "AM_DONE_WALKING", "AM_OPEN_MAP", false, "AM_OPEN_HOUSE" }

local startBtn = CH.MakeButton(win, "AM_START", 130, 24)
CH.SetButtonActive(startBtn, true)
startBtn:SetScript("OnClick", function(self)
    local job = self.job
    if job == "AM_DROP" then
        CH.SmartDrop()
        if RoomsHere() > 0 then
            CH.SetAutoMap(true)
        end
    elseif job == "AM_DONE_WALKING" then
        SetGuide(4)
        CH.SetAutoMap(false)
    elseif job == "AM_OPEN_MAP" then
        win:Hide()
        CH.OpenToolbox()
    elseif job == "AM_OPEN_HOUSE" then
        win:Hide()
        CH.ToggleHousePanel()
    else
        CH.SetAutoMap(not CH.autoMap)
    end
end)

local laterBtn = CH.MakeButton(win, "AM_CLOSE", 90, 24)
laterBtn:SetScript("OnClick", function()
    win:Hide()
end)

-- How far the map of the house you stand in has come. It has no rooms, rooms
-- but no entrance yet or the entrance. The entrance is the game's Entry linked
-- by Smart drop, or the one Add default entrance puts in the game's own spot.
-- With it any room will do to go on. Without it the guide sends you there.
local function Progress()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or CH.RoomCount(h.zones) == 0 then
        return "AM_BODY_OFF"
    end
    for _, z in ipairs(h.zones) do
        local record = CH.RoomRecord(z.gameRoom)
        local home = (z.floor or 1) == 1 and CH.ZoneContains(z, CH.ENTRANCE_X, CH.ENTRANCE_Y)
        if CH.IsRoom(z) and (record == CH.ENTRY_ROOM or home) then
            return "AM_BODY_OFF_ROOMS"
        end
    end
    return "AM_BODY_OFF_ENTRY"
end

-- New words blink a few times so they're noticed while you walk, made once
-- per text. An animation, so it costs nothing once it's done.
local function MakeBlink(fs)
    local ag = fs:CreateAnimationGroup()
    for i = 1, 3 do
        local out = ag:CreateAnimation("Alpha")
        out:SetFromAlpha(1)
        out:SetToAlpha(0.2)
        out:SetDuration(0.25)
        out:SetOrder(2 * i - 1)
        local back = ag:CreateAnimation("Alpha")
        back:SetFromAlpha(0.2)
        back:SetToAlpha(1)
        back:SetDuration(0.25)
        back:SetOrder(2 * i)
    end
    return ag
end
local blinks = { [body] = MakeBlink(body), [hint] = MakeBlink(hint) }

-- Sets the text and blinks it when it's another one than before.
local function Say(fs, text)
    if fs:GetText() ~= text then
        fs:SetText(text)
        if win:IsShown() then
            blinks[fs]:Restart()
        end
    end
end

local DONE_MARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t  "

-- The step lines, ticked up to the one you're on. Returns where the text
-- under them starts.
local function PaintSteps(step)
    local listed = step and step < DONE
    current:SetShown(listed)
    for i, fs in ipairs(rows) do
        fs:SetShown(listed)
        if listed then
            local label = CH.L["AM_STEP_" .. i]
            fs:SetText((i < step and DONE_MARK or i .. ".  ") .. label)
            if i < step then
                fs:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
            elseif i == step then
                fs:SetTextColor(1, 1, 1)
            else
                fs:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
            end
        end
    end
    if not listed then
        return 38
    end
    current:ClearAllPoints()
    current:SetPoint("LEFT", win, "LEFT", 10, 0)
    current:SetPoint("RIGHT", win, "RIGHT", -10, 0)
    current:SetPoint("TOP", rows[step], "TOP", 0, 4)
    return 38 + STEPS * ROW_H + 12
end

-- The map moves the guide on as rooms go down, however they got there, Smart
-- drop or Add default entrance included.
local function GuideNow()
    local step = GuideStep()
    if step == 1 and RoomsHere() > 0 then
        step = 2
    end
    if step == 2 and RoomsHere() > 1 then
        step = 3
    end
    if step and step ~= GuideStep() then
        SetGuide(step)
    end
    return step
end

-- The words and the button for the guide's step or for Auto map on or off,
-- and the height to hold them.
local function Paint()
    local on = CH.autoMap
    local off = Progress()
    local step = GuideNow()
    local job = step and JOBS[step]
    CH.SetWindowTitle(win, (step or off == "AM_BODY_OFF") and "AM_TITLE" or "AM_TITLE_AGAIN", true)
    local y = PaintSteps(step)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", 18, -y)
    Say(body, CH.L[step and "AM_GUIDE_" .. step or on and "AM_BODY_ON" or off])
    startBtn:SetShown(job ~= false)
    startBtn.job = job
    if job then
        startBtn:SetText(CH.L[job])
        CH.SetButtonActive(startBtn, true)
    else
        startBtn:SetText(CH.L[on and "AM_STOP" or "AM_START"])
        CH.SetButtonActive(startBtn, not on)
    end
    y = y + body:GetStringHeight() + 12
    local shown = on and hintKey ~= nil
    hint:SetShown(shown)
    if shown then
        Say(hint, string.format(CH.L[hintKey], hintArg))
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", 18, -y)
        y = y + hint:GetStringHeight() + 12
    else
        -- so the same word after another room blinks again
        hint:SetText("")
    end
    -- once Auto map is done with, closing stops nothing worth a word
    local noted = not step or step <= 3
    note:SetShown(noted)
    if noted then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", 18, -y)
        y = y + note:GetStringHeight() + 12
    end
    startBtn:ClearAllPoints()
    startBtn:SetPoint("TOPLEFT", 18, -y)
    laterBtn:ClearAllPoints()
    if job == false then
        laterBtn:SetPoint("TOPLEFT", 18, -y)
    else
        laterBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
    end
    win:SetHeight(y + 24 + 16)
end

-- Smart drop placed z, by hand or by Auto map. Any other room clears the
-- word about the last one.
function CH.AutoMapPlaced(z)
    local def = z.shape and CH.SHAPES[z.shape]
    if def and def.stack then
        hintKey = "AM_HINT_STAIRS"
    elseif z.shape == "L" or z.shape == "T" then
        hintKey = "AM_HINT_TURN"
    else
        hintKey = nil
    end
    hintArg = nil
    -- a second L in a row is a new room too, so its word blinks again
    hint:SetText("")
    CH.RefreshAutoMapWelcome()
end

-- Auto map couldn't place the room you stand in: no open door in reach, or
-- with key AM_HINT_UNKNOWN_X a room whose size it doesn't know, named by arg.
-- A no fit tries again every yard you walk, so this comes often, and blinks
-- only the first time since the words stay the same.
function CH.AutoMapStuck(key, arg)
    hintKey, hintArg = key or "AM_HINT_NO_FIT", arg
    CH.RefreshAutoMapWelcome()
end

-- Every way out stops Auto map, leaving the house included. Hide UI is no
-- way out.
win:SetScript("OnHide", function(self)
    if CH.OnlyParentHid(self) then
        return
    end
    if CH.autoMap then
        CH.SetAutoMap(false)
    end
    -- the done page shows once and then the gudie is over
    if GuideStep() == DONE then
        SetGuide(false)
    end
end)

-- Auto map was turned on or off here or on the map. Off, the word about the
-- last room goes with it.
function CH.RefreshAutoMapWelcome()
    if not CH.autoMap then
        hintKey = nil
    end
    if win:IsShown() then
        Paint()
    end
end

-- The house welcomed on this visit. The house info can come again in the
-- middle of a visit, and a window closed once stays closed until you leave.
local greeted

-- From the house info on the way in, once the house is known.
function CH.MaybeWelcomeHome(guid)
    if not CH.isOwnHouse or not guid or greeted == guid or CH.LayoutLocked() then
        return
    end
    local h = ChamberlainDB.houses[guid]
    if h and CH.RoomCount(h.zones) > 0 then
        return
    end
    greeted = guid
    if ChamberlainDB.guide[guid] == nil then
        ChamberlainDB.guide[guid] = 1
    end
    CH.OpenAutoMap()
end

-- Steps 4 and 5 happen away from the window, in the room editor and on a
-- banner. The last one brings the window back for the done page.
function CH.GuideReached(guid, step)
    if ChamberlainDB.guide[guid] ~= step then
        return
    end
    ChamberlainDB.guide[guid] = step + 1
    if step == STEPS then
        win:Show()
        win:Raise()
        Paint()
    else
        CH.RefreshAutoMapWelcome()
    end
end

-- The guide again whenever you want it: /rooms automap opens it, and the
-- map's Auto map button opens it with start set, so the window that stops
-- Auto map is there whichever way it began.
function CH.OpenAutoMap(start)
    if not CH.isOwnHouse or not CH.currentHouseGUID then
        CH.Print(CH.L["AM_OWN_HOUSE"])
        return
    end
    if CH.RefuseLocked() then
        return
    end
    win:Show()
    win:Raise()
    if start and not CH.autoMap then
        CH.SetAutoMap(true)
    else
        Paint()
    end
end

-- Settings and /rooms guide run the guide again in a house of yours. A house
-- with rooms already ticks the first two steps off and starts walking.
function CH.RestartGuide()
    if not CH.isOwnHouse or not CH.currentHouseGUID then
        CH.Print(CH.L["AM_GUIDE_OWN_HOUSE"])
        return
    end
    if CH.RefuseLocked() then
        return
    end
    ChamberlainDB.guide[CH.currentHouseGUID] = 1
    CH.OpenAutoMap(true)
end

-- Leaving the house, so the next walk in can welcome you again.
function CH.HideWelcomeHome()
    greeted = nil
    win:Hide()
end
