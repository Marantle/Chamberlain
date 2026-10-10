local _, CH = ...
local K = CH.LockKit

-- ─────────────────────────────────────────────────────────────────────
-- Lock style 4: the Witch's Kite
-- ─────────────────────────────────────────────────────────────────────
-- A witch on a jack-o'-lantern holds the reins of a kite of bats. Each
-- number sends out a bat with that number on its tag, tied on with a
-- string to her hand, and a click on a bat cuts it loose. On the right
-- code the bats pull her off the card to the west. On a wrong one the
-- strings snap and the bats tumble away.

local Group, Fade, Move, Spin = K.Group, K.Fade, K.Move, K.Spin

local LAND_SOUND = SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE
local OPEN_SOUND = SOUNDKIT.UI_WORLDQUEST_COMPLETE
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

local C = K.Colors({
    edge = "e3a03a",
    ink = "3b2a1c",
    hint = "6b5539",
    sepia = "8f6b3a",
    spent = "b9a27e",
    orange = "c4561c",
    rust = "8f3a10",
    cream = "fbf3e4",
    tag = "f3e8cf",
    key = "fbf6ec",
})

-- where she holds the reins, measured on the cut-out
local HAND = { 318, 252 }
-- bat middles in the sky, in the order they get tied on
local SPOTS =
    { { 86, 262 }, { 176, 240 }, { 254, 262 }, { 64, 338 }, { 154, 322 }, { 240, 342 }, { 104, 420 }, { 204, 410 } }
local BATS = { "kbat1", "kbat2", "kbat3" }

local page, flight, witch, lock
local spots = {}

local function BatArt(i)
    return BATS[(i - 1) % 3 + 1]
end

-- ── Bats ─────────────────────────────────────────────────────────────
local function Empty(s)
    s.on:Stop()
    s.flap:Stop()
    s.tumble:Stop()
    s.spin:Stop()
    s:SetAlpha(0)
    s.string:Hide()
end

local function Light(s, d)
    s.digit:SetText(d)
    -- an Alpha animation may be multiplied into the frame's own, so that
    -- goes to 1 first
    s:SetAlpha(1)
    s.on:Play()
    s.flap:Play()
    s.string:Show()
    PlaySound(LAND_SOUND, "SFX")
end

local function MakeSpot(i)
    local x, y = SPOTS[i][1], SPOTS[i][2]
    local s = CreateFrame("Button", nil, flight)
    s:SetSize(64, 62)
    s:SetPoint("TOPLEFT", x - 32, -(y - 20))
    s:SetFrameLevel(flight:GetFrameLevel() + 10)
    -- an empty spot stays shown at no alpha, so a bat has somewhere to fly to
    s:SetAlpha(0)
    -- the bats take turns among the card's three
    s.bat = K.Pic(s, BatArt(i), 60, 38)
    s.bat:SetPoint("TOP")
    -- the tag is png like the bat, an svg wouldn't fall or fly with it
    local disc = K.Pic(s, "disc", 20, 20, "BORDER")
    disc:SetPoint("TOP", s.bat, "BOTTOM", 0, -2)
    K.Tint(disc, C.tag)
    local rim = K.Pic(s, "ring", 20, 20)
    rim:SetAllPoints(disc)
    K.Tint(rim, C.sepia)
    s.digit = s:CreateFontString(nil, "OVERLAY")
    K.Font(s.digit, 15)
    s.digit:SetPoint("CENTER", disc, 0, 1)
    s.digit:SetTextColor(CH.RGBA(C.ink, 1))

    -- a little sag would read better, but a line is straight
    s.string = flight:CreateLine(nil, "ARTWORK")
    s.string:SetThickness(1)
    s.string:SetColorTexture(CH.RGBA(C.ink, 1))
    s.string:SetStartPoint("TOPLEFT", flight, HAND[1], -HAND[2])
    s.string:SetEndPoint("TOPLEFT", flight, x, -(y + 4))
    s.string:Hide()

    -- A frame that scales while the bat in it flaps blows the texture up,
    -- so the bat fades in where it lands instead.
    s.on = Group(s, function()
        s:SetAlpha(1)
    end)
    Fade(s.on, 1, 0.2, 0, 1)
    s.flap = Group(s.bat)
    s.flap:SetLooping("BOUNCE")
    local flap = K.Anim(s.flap, "Scale", 1, 0.25, nil, "IN_OUT")
    flap:SetScaleFrom(1, 1)
    flap:SetScaleTo(1, 0.82)
    s.tumble = Group(s, function()
        s:SetAlpha(0)
    end)
    Move(s.tumble, 1, 1.1, -40, -420, nil, "IN")
    Fade(s.tumble, 1, 1.1, 1, 0)
    s.spin = Group(s.bat)
    Spin(s.spin, 1, 1.1, 200, nil, "IN")
    return s
end

-- ── Open and wrong ───────────────────────────────────────────────────
local function Reset()
    flight.away:Stop()
    flight:Show()
    witch.jolt:Stop()
    for _, s in ipairs(spots) do
        Empty(s)
    end
end

local function PlayOpen()
    PlaySound(OPEN_SOUND, "SFX")
    flight.away:Play()
end

local function PlayWrong()
    PlaySound(WRONG_SOUND, "SFX")
    witch.jolt:Play()
    for i = 1, lock.landed do
        local s = spots[i]
        s.string:Hide()
        s.flap:Stop()
        s.tumble:Play()
        s.spin:Play()
    end
end

-- ── Page ─────────────────────────────────────────────────────────────
local function MakeSky()
    local moon = K.Pic(page, "moon", 170, 100, "BORDER")
    moon:SetPoint("TOPLEFT", 24, -124)

    -- the witch, her strings and her bats go as one
    flight = CreateFrame("Frame", nil, page)
    flight:SetAllPoints()
    flight.away = Group(flight, function()
        flight:Hide()
    end)
    -- leans back as the bats take up the slakc, then off west, climbing
    Move(flight.away, 1, 0.28, 8, -4, 0.3, "OUT")
    Move(flight.away, 2, 1.6, -628, 144, nil, "IN")
    witch = K.Pic(flight, "witch", 190, 216)
    witch:SetPoint("TOPLEFT", 300, -160)
    witch.jolt = Group(witch)
    K.Chain(witch.jolt, "Translation", { -9, 16, -11, 6, -2 }, 0.08)
    for i = 1, CH.LOCK_CODE_MAX do
        spots[i] = MakeSpot(i)
    end
end

K.Register("kite", {
    w = 520,
    h = 724,
    back = { 0.9, 0.84, 0.7, 1 },
    edge = C.edge,
    title = C.ink,
    hint = C.hint,
    hintKey = "LOCK_KITE_HINT",
    Build = function(p)
        page = p
        K.Paper(page, 0.96, 0.93, 0.84)
        K.CardEdge(page, C.edge, 10)
        MakeSky()
        local o = {
            slots = spots,
            Fly = K.Flyers(page, function(fl)
                fl:SetSize(60, 38)
                local bat = K.Pic(fl, "kbat1", 60, 38, "OVERLAY")
                bat:SetPoint("CENTER")
                return bat
            end, function(bat, i)
                bat:SetTexture(CH.MEDIA .. "lock-" .. BatArt(i) .. ".png")
            end),
            -- the bat that flies is the one its spot shows
            value = function(_, i)
                return i
            end,
            s1 = 0.6,
            s2 = 1,
            delay = 1.9,
            light = Light,
            empty = Empty,
            reset = Reset,
            open = PlayOpen,
            wrong = PlayWrong,
        }
        lock = K.Slots(o)
        o.keys = K.PostcardKeys(page, C, "LOCK_KITE_GO", lock)
        return {
            Reset = lock.Reset,
            Stop = function()
                for _, s in ipairs(spots) do
                    s.flap:Stop()
                end
            end,
        }
    end,
})
