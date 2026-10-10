local _, CH = ...
local K = CH.LockKit

-- ─────────────────────────────────────────────────────────────────────
-- Lock style 3: the Talking Board
-- ─────────────────────────────────────────────────────────────────────
-- A spirit board. A click on a number sends the planchette gliding to it
-- and the number joins the line the spirits spell. Asked, the planchette
-- goes to Yes for the right code. For a wrong one it goes to No, then
-- drifts back to Good bye and the board forgets.

local Group, Fade, Move, Tint = K.Group, K.Fade, K.Move, K.Tint

local ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }
local GLIDE = 0.65

local LAND_SOUND = SOUNDKIT.UI_PROFESSION_SPEC_PIP_LOCKIN
local OPEN_SOUND = SOUNDKIT.UI_EVENT_SCHEDULER_CHIME
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

local C = K.Colors({
    wood = "4a2f18",
    ink = "2e1d10",
    hint = "5a4128",
    sepia = "8f6b3a",
    hover = "8f3a10",
    lit = "b4481a",
    glow = "ff9a3c",
    grim = "5a1408",
    cream = "f0e2c4",
})

-- Where the planchette's glass goes, in page units from the top left. The
-- glass sits 42, 44 into the planchette.
local GLASS_X, GLASS_Y = 42, 44
local YES, NO, REST = { 103, 226 }, { 430, 226 }, { 292, 561 }

local page, board, plan, glass, yes, no, bat
local ledger = {}
local typed, result, busy = "", "idle", false
local at = REST
local later -- the drift back to Good bye after a wrong answer

local function NumSpot(k)
    return { 30 + (k - 1) * 46 + 23, 328 }
end

local function Place(spot)
    plan:ClearAllPoints()
    plan:SetPoint("TOPLEFT", spot[1] - GLASS_X, -(spot[2] - GLASS_Y))
end

-- A translation there, then the planchette is put down for real where it
-- stopped, at a slight angle like a hand left it.
local function Glide(to, done)
    busy = true
    plan.to, plan.done = to, done
    plan.move:SetOffset(to[1] - at[1], at[2] - to[2])
    plan.glide:Play()
end

local function Spell()
    for i, fs in ipairs(ledger) do
        fs:SetText(typed:sub(i, i))
    end
end

-- ── Open and wrong ───────────────────────────────────────────────────
local function Reset()
    if later then
        later:Cancel()
        later = nil
    end
    plan.glide:Stop()
    busy = false
    at = REST
    Place(at)
    glass:SetRotation(0)
    yes:SetTextColor(CH.RGBA(C.ink, 1))
    no:SetTextColor(CH.RGBA(C.ink, 1))
    yes.glow.on:Stop()
    yes.glow:SetAlpha(0)
    board.jolt:Stop()
    bat.flee:Stop()
    bat:SetAlpha(1)
    bat:Show()
    bat.drift:Play()
    typed, result = "", "idle"
    Spell()
end

local function PlayOpen()
    result = "open"
    PlaySound(OPEN_SOUND, "SFX")
    yes:SetTextColor(CH.RGBA(C.lit, 1))
    yes.glow:SetAlpha(1)
    yes.glow.on:Play()
    bat.drift:Stop()
    bat.flee:Play()
end

-- A wrong answer ends the seance. The planchette drifts back to Good bye
-- and the board forgets.
local function PlayWrong()
    result = "wrong"
    PlaySound(WRONG_SOUND, "SFX")
    no:SetTextColor(CH.RGBA(C.grim, 1))
    board.jolt:Play()
    later = C_Timer.NewTimer(1.1, function()
        later = nil
        Glide(REST, function()
            typed = ""
            Spell()
        end)
    end)
end

local function Ask()
    if busy or result ~= "idle" or #typed < CH.LOCK_CODE_MIN then
        return
    end
    -- the name waits for the glide to Yes as well
    local right = K.Try(typed, 0.9 + GLIDE)
    Glide(right and YES or NO, right and PlayOpen or PlayWrong)
end

-- ── Input ────────────────────────────────────────────────────────────
local function Press(k)
    if busy or result == "open" then
        return
    elseif result == "wrong" then
        Reset()
    end
    if #typed >= CH.LOCK_CODE_MAX then
        return
    end
    Glide(NumSpot(k), function()
        typed = typed .. ORDER[k]
        Spell()
        PlaySound(LAND_SOUND, "SFX")
    end)
end

-- ── Page ─────────────────────────────────────────────────────────────
local function Word(key, size)
    local fs = board:CreateFontString(nil, "OVERLAY")
    K.Font(fs, size)
    fs:SetText(CH.L[key])
    fs:SetTextColor(CH.RGBA(C.ink, 1))
    return fs
end

local function MakeBoard()
    local rim = CreateFrame("Frame", nil, board, "BackdropTemplate")
    rim:SetPoint("TOPLEFT", 14, -14)
    rim:SetPoint("BOTTOMRIGHT", -14, 14)
    rim:SetBackdrop(CH.BACKDROP_THIN)
    rim:SetBackdropColor(0, 0, 0, 0)
    rim:SetBackdropBorderColor(CH.RGBA(C.wood, 1))

    local moon = K.Pic(page, "moon", 150, 88, "BORDER")
    moon:SetPoint("TOPLEFT", 34, -34)
    bat = K.Pic(page, "kbat2", 100, 62, "BORDER")
    bat:SetPoint("TOPLEFT", 372, -44)
    bat.drift = Group(bat)
    bat.drift:SetLooping("BOUNCE")
    Move(bat.drift, 1, 1.8, -5, 7, nil, "IN_OUT")
    bat.flee = Group(bat, function()
        bat:Hide()
    end)
    Move(bat.flee, 1, 1.2, 120, 120, 0.6, "IN")
    Fade(bat.flee, 1, 1.2, 1, 0, 0.6)

    yes = Word("LOCK_BOARD_YES", 44)
    yes:SetPoint("TOPLEFT", 67, -203)
    yes.glow = K.Pic(board, "glow", 140, 90, "ARTWORK")
    yes.glow:SetPoint("CENTER", yes)
    yes.glow:SetBlendMode("ADD")
    Tint(yes.glow, C.glow)
    yes.glow:SetAlpha(0)
    yes.glow.on = Group(yes.glow, function()
        yes.glow:SetAlpha(0.45)
    end)
    Fade(yes.glow.on, 1, 0.4, 0, 0.45)
    no = Word("LOCK_BOARD_NO", 44)
    no:SetPoint("TOPLEFT", 398, -204)

    local bye = Word("LOCK_BOARD_BYE", 32)
    bye:SetPoint("TOP", 0, -502)

    local spell = Word("LOCK_BOARD_SPELL", 15)
    spell:SetTextColor(CH.RGBA(C.hint, 1))
    spell:SetPoint("TOP", 0, -408)
    for i = 1, CH.LOCK_CODE_MAX do
        local x = 81 + (i - 1) * 46
        local fs = board:CreateFontString(nil, "OVERLAY")
        K.Font(fs, 32)
        fs:SetTextColor(CH.RGBA(C.ink, 1))
        fs:SetSize(36, 44)
        fs:SetPoint("TOPLEFT", x, -432)
        local line = board:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(CH.RGBA(C.hint, 1))
        line:SetSize(36, 1)
        line:SetPoint("TOPLEFT", x, -476)
        ledger[i] = fs
    end
end

local function MakeNumbers()
    for k, d in ipairs(ORDER) do
        local b = CreateFrame("Button", nil, board)
        b:SetSize(46, 64)
        b:SetPoint("TOPLEFT", 30 + (k - 1) * 46, -296)
        local fs = b:CreateFontString(nil, "OVERLAY")
        K.Font(fs, 36)
        fs:SetPoint("CENTER")
        fs:SetText(d)
        fs:SetTextColor(CH.RGBA(C.ink, 1))
        b:SetScript("OnEnter", function()
            fs:SetTextColor(CH.RGBA(C.hover, 1))
        end)
        b:SetScript("OnLeave", function()
            fs:SetTextColor(CH.RGBA(C.ink, 1))
        end)
        b:SetScript("OnClick", function()
            Press(k)
        end)
    end

    local clear = K.Button(board, CH.L["LOCK_CLEAR"], 196, 40, { 0, 0, 0, 0 }, C.sepia, C.hint)
    K.Font(clear.label, 17)
    clear:SetPoint("TOPLEFT", 60, -664)
    clear:SetScript("OnClick", function()
        if result == "open" or busy then
            return
        end
        if later then
            later:Cancel()
            later = nil
        end
        Glide(REST, function()
            typed, result = "", "idle"
            no:SetTextColor(CH.RGBA(C.ink, 1))
            Spell()
        end)
    end)
    local ask = K.Button(board, CH.L["LOCK_BOARD_GO"], 196, 40, C.ink, C.ink, C.cream)
    K.Font(ask.label, 17)
    ask:SetPoint("TOPRIGHT", -60, -664)
    ask:SetScript("OnClick", Ask)
end

local function MakePlanchette()
    plan = CreateFrame("Frame", nil, page)
    plan:SetSize(84, 96)
    plan:SetFrameLevel(page:GetFrameLevel() + 20)
    glass = K.Pic(plan, "planchette", 84, 96)
    glass:SetAllPoints()
    plan.glide = Group(plan, function()
        at = plan.to
        Place(at)
        glass:SetRotation(math.rad(math.random(-8, 8)))
        busy = false
        if plan.done then
            plan.done()
        end
    end)
    plan.move = Move(plan.glide, 1, GLIDE, 0, 0, nil, "IN_OUT")
end

K.Register("board", {
    w = 520,
    h = 724,
    back = { 0.85, 0.75, 0.58, 1 },
    edge = C.wood,
    title = C.ink,
    hint = C.hint,
    hintKey = "LOCK_BOARD_HINT",
    Build = function(p)
        page = p
        K.Paper(page, 0.9, 0.83, 0.7)
        -- What shakes on a wrong code. The bat and the planchette move on
        -- their own and stay off it: a bat drifting inside a frame that
        -- shook was knocked off the card for good.
        board = CreateFrame("Frame", nil, page)
        board:SetAllPoints()
        board.jolt = board:CreateAnimationGroup()
        K.Chain(board.jolt, "Translation", { -8, 14, -10, 6, -2 }, 0.08)
        MakeBoard()
        MakeNumbers()
        MakePlanchette()
        return {
            Reset = Reset,
            Stop = function()
                if later then
                    later:Cancel()
                    later = nil
                end
                bat.drift:Stop()
            end,
        }
    end,
})
