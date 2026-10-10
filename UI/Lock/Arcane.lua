local _, CH = ...
local K = CH.LockKit

-- ─────────────────────────────────────────────────────────────────────
-- Lock style 1: the Arcane Ward
-- ─────────────────────────────────────────────────────────────────────
-- Stones put glyphs into the ring, a socket sends its glyph back, and
-- Unlock tries the code.
--
-- Things learned building it in game:
-- svg (VectorGraphics) has no CreateAnimationGroup, so whatever moves is a
-- png texture and only the still art is svg. Two rotations on one texture
-- fight, so the idle spin pauses while the bite plays. A frame scaling while
-- a texture in it scales too blows the texture up to fill the screen, so
-- those never overlap. An additive glow with a pale tint at full alpha burns
-- out white.

local Anim, Group, Fade, Grow, Spin, Wait, Chain, Tint =
    K.Anim, K.Group, K.Fade, K.Grow, K.Spin, K.Wait, K.Chain, K.Tint

local ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }

-- The game's own sounds, picked by ear in game. A landing glyph takes one of
-- the two runecarver picks at random so a row of them doesn't drone.
local LAND_SOUNDS = { SOUNDKIT.UI_RUNECARVING_SELECT_UPPER_RUNE, SOUNDKIT.UI_RUNECARVING_SELECT_LOWER_RUNE }
local OPEN_SOUND = SOUNDKIT.UI_72_ARTIFACT_FORGE_FINAL_TRAIT_UNLOCKED
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

-- The ward's own colours, violet and pink.
local C = K.Colors({
    void = "160e28", -- the dark under the crystal and in the sockets
    frame = "3b2a5e",
    stone = "1a1230",
    ink = "4a3878", -- an empty socket, a stone's edge
    pink = "ff6bd6",
    glyph = "ff9ae4",
    bright = "ffd6f4",
    mote = "ffb3ec",
    wrong = "ff3d63",
    burnt = "4a2038",
    outer = "a77bff",
    inner = "c39bff",
    text = "e6dcf5",
    title = "f1e6ff",
    hint = "a99bc4",
})

local function SetArt(r, name)
    if r.isSvg then
        r:SetSVG(CH.MEDIA .. "lock-" .. name .. ".svg")
    else
        r:SetTexture(CH.MEDIA .. "lock-" .. name .. ".png")
    end
end

-- One layer of art, centred on its parent. moving says it gets animations
-- of its own, which takes a texture.
local function Art(parent, name, size, c, layer, moving)
    local r
    if moving then
        r = parent:CreateTexture(nil, layer or "ARTWORK")
    else
        r = parent:CreateVectorGraphics(nil, layer or "ARTWORK")
        r.isSvg = true
    end
    SetArt(r, name)
    r:SetSize(size, size)
    r:SetPoint("CENTER")
    if c then
        Tint(r, c)
    end
    return r
end

local page, stage, ringA, ringB, crystal, halo, glow, lock
local sockets, keys, motes = {}, {}, {}

-- ── Sockets ──────────────────────────────────────────────────────────
local function Empty(s)
    s.land:Stop()
    s.flare:Stop()
    s.burn:Stop()
    s.glyph:Hide()
    s.glyph:SetAlpha(1)
    Tint(s.glyph, C.glyph)
    Tint(s.edge, C.ink)
end

local function Light(s, d)
    SetArt(s.glyph, "glyph" .. d)
    s.glyph:Show()
    Tint(s.edge, C.pink)
    s.land:Play()
    PlaySound(LAND_SOUNDS[math.random(#LAND_SOUNDS)], "SFX")
end

local function MakeSocket(i)
    local a = math.rad((i - 1) * 45 - 90)
    local s = CreateFrame("Button", nil, stage)
    s:SetSize(40, 40)
    s:SetPoint("CENTER", stage, "CENTER", 176 * math.cos(a), -176 * math.sin(a))
    s:SetFrameLevel(stage:GetFrameLevel() + 10)
    Art(s, "circle", 40, C.void, "BACKGROUND")
    s.edge = Art(s, "ringThin", 40, C.ink, "BORDER")
    s.glyph = Art(s, "glyph1", 24, C.glyph, "ARTWORK", true)
    s.glyph:Hide()
    s.land = s:CreateAnimationGroup()
    Grow(s.land, 1, 0.35, 1.3, 1, nil, "OUT")
    -- flares one after another round the ring on open
    s.flare = Group(s.glyph, function()
        Tint(s.glyph, C.bright)
    end)
    Grow(s.flare, 1, 0.2, 1, 1.35, (i - 1) * 0.07, "OUT")
    Grow(s.flare, 2, 0.3, 1.35, 1, nil, "IN")
    s.burn = Group(s.glyph, function()
        s.glyph:SetAlpha(0.3)
        Tint(s.glyph, C.burnt)
    end)
    Fade(s.burn, 1, 0.9, 1, 0.3)
    return s
end

-- ── Open and wrong ───────────────────────────────────────────────────
local function Reset()
    for _, r in ipairs({ ringA, ringB }) do
        r.open:Stop()
        r:Show()
        r.idle:Play()
    end
    ringB.bite:Stop()
    crystal.burst:Stop()
    crystal.hit:Stop()
    crystal:Show()
    halo:Show()
    Tint(crystal, C.glyph)
    glow.bloom:Stop()
    glow:Hide()
    for _, m in ipairs(motes) do
        m.ag:Stop()
        m:Hide()
    end
    stage.jolt:Stop()
    for _, s in ipairs(sockets) do
        Empty(s)
    end
end

-- Motes burst out of the crystal on open and sparks spit on a wrong code.
-- The same eight textures do both.
local function Motes(from, dist, dur, delay, c)
    for i, m in ipairs(motes) do
        local a = math.rad((i - 1) * 45)
        m:ClearAllPoints()
        m:SetPoint("CENTER", from * math.cos(a), from * math.sin(a))
        Tint(m, c)
        m.move:SetOffset(dist * math.cos(a), dist * math.sin(a))
        m.wait:SetDuration(math.max(delay, 0.01))
        m.move:SetDuration(dur)
        m.fade:SetDuration(dur)
        m:Show()
        m.ag:Play()
    end
end

local function PlayOpen()
    PlaySound(OPEN_SOUND, "SFX")
    for i = 1, lock.landed do
        sockets[i].land:Stop()
        sockets[i].flare:Play()
    end
    ringA.idle:Stop()
    ringB.idle:Stop()
    ringA.open:Play()
    ringB.open:Play()
    crystal.burst:Play()
    halo:Hide()
    glow:SetAlpha(1)
    glow:Show()
    glow.bloom:Play()
    Motes(0, 190, 0.9, 1.5, C.mote)
end

local function PlayWrong()
    PlaySound(WRONG_SOUND, "SFX")
    for i = 1, lock.landed do
        Tint(sockets[i].glyph, C.wrong)
        sockets[i].burn:Play()
    end
    stage.jolt:Play()
    ringB.idle:Pause()
    ringB.bite:Play()
    Tint(crystal, C.wrong)
    crystal.hit:Play()
    Motes(36, 74, 0.55, 0, C.wrong)
end

-- ── Page ─────────────────────────────────────────────────────────────
local function TextButton(label, w, h, border)
    return K.Button(page, label, w, h, C.stone, border or C.ink, C.text)
end

-- The two rings, each with an idle spin, a way out on open and, for the
-- inner one, a bite on a wrong code.
local function MakeRings()
    ringA = Art(stage, "ringA", 400, C.outer, "BORDER", true)
    ringB = Art(stage, "ringB", 400, C.inner, "BORDER", true)
    -- ring, seconds per idle turn, its way round, then turn, growth and
    -- delay on open
    for _, e in ipairs({ { ringA, 40, -1, -300, 1.5, 0.35 }, { ringB, 26, 1, 260, 1.3, 0.25 } }) do
        local r, period, way, degrees, size, delay = unpack(e)
        r.idle = Group(r)
        r.idle:SetLooping("REPEAT")
        Spin(r.idle, 1, period, way * 360, nil, "NONE")
        r.open = Group(r, function()
            r:Hide()
        end)
        Spin(r.open, 1, 1.1, degrees, delay, "IN")
        Grow(r.open, 1, 1.1, 1, size, delay, "IN")
        Fade(r.open, 1, 1.1, 1, 0, delay)
    end
    -- the idle spin waits paused at its angle and picks up again after
    ringB.bite = Group(ringB, function()
        ringB.idle:Play()
    end)
    Chain(ringB.bite, "Rotation", { -16, 23, -9, 2 }, 0.12)
end

-- The crystal in the middle, its light and the motes. Nothing here scales.
local function MakeCore()
    Art(stage, "circle", 124, C.void, "ARTWORK")
    Art(stage, "ringThin", 124, C.pink, "ARTWORK")
    halo = Art(stage, "circle", 92, C.pink, "OVERLAY")
    halo:SetAlpha(0.16)
    crystal = Art(stage, "crystal", 68, C.glyph, "OVERLAY", true)
    crystal.burst = Group(crystal, function()
        crystal:Hide()
    end)
    Spin(crystal.burst, 1, 0.5, -540, 1.1, "IN")
    Fade(crystal.burst, 1, 0.5, 1, 0, 1.1)
    crystal.hit = Group(crystal, function()
        Tint(crystal, C.glyph)
    end)
    -- a shake with a flicker, dim on every other step
    Chain(crystal.hit, "Rotation", { -14, 24, -16, 6 }, 0.07)
    for i = 1, 4 do
        local dim = i % 2 == 1
        Fade(crystal.hit, i, 0.07, dim and 1 or 0.35, dim and 0.35 or 1)
    end

    glow = Art(stage, "glow", 140, C.pink, "OVERLAY", true)
    glow:SetBlendMode("ADD")
    glow.bloom = Group(glow, function()
        glow:SetAlpha(0.3)
    end)
    Wait(glow.bloom, 1.45)
    Fade(glow.bloom, 2, 0.5, 0, 0.45)
    Fade(glow.bloom, 3, 0.6, 0.45, 0.3)

    for i = 1, 8 do
        local m = Art(stage, "glow", 12, nil, "OVERLAY", true)
        m:SetBlendMode("ADD")
        m:Hide()
        m.ag = Group(m, function()
            m:Hide()
        end)
        m.wait = Wait(m.ag, 0.01)
        m.move = Anim(m.ag, "Translation", 2, 0.9, nil, "OUT")
        m.fade = Fade(m.ag, 2, 0.9, 1, 0)
        motes[i] = m
    end
end

local function MakeStones()
    for k, d in ipairs(ORDER) do
        local b = TextButton("", 73.6, 60)
        b:SetPoint("TOPLEFT", 60 + ((k - 1) % 5) * 81.6, -518 - math.floor((k - 1) / 5) * 68)
        local g = Art(b, "glyph" .. d, 26, C.inner)
        g:SetPoint("CENTER", 0, 6)
        local n = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        n:SetPoint("BOTTOM", 0, 5)
        n:SetText(d)
        b:SetScript("OnClick", function()
            lock.Press(d)
        end)
        keys[k] = b
    end
    local clear = TextButton(CH.L["LOCK_CLEAR"], 196, 40)
    clear:SetPoint("TOPLEFT", 60, -664)
    clear:SetScript("OnClick", function()
        lock.Clear()
    end)
    local unlock = TextButton(CH.L["LOCK_UNLOCK"], 196, 40, C.pink)
    unlock:SetPoint("TOPRIGHT", -60, -664)
    unlock:SetScript("OnClick", function()
        lock.Submit()
    end)
end

K.Register("arcane", {
    w = 520,
    h = 724,
    back = { 0.06, 0.04, 0.1, 0.96 },
    edge = C.frame,
    title = C.title,
    hint = C.hint,
    hintKey = "LOCK_ENTER_CODE",
    Build = function(p)
        page = p
        stage = CreateFrame("Frame", nil, page)
        stage:SetSize(400, 400)
        stage:SetPoint("TOP", 0, -100)
        stage.jolt = stage:CreateAnimationGroup()
        Chain(stage.jolt, "Translation", { -9, 16, -11, 6, -2 }, 0.08)

        MakeRings()
        MakeCore()
        for i = 1, 8 do
            sockets[i] = MakeSocket(i)
        end
        lock = K.Slots({
            keys = keys,
            slots = sockets,
            Fly = K.Flyers(page, function(fl)
                local glyph = Art(fl, "glyph1", 24, C.bright, "OVERLAY", true)
                local spin = Anim(fl.ag, "Rotation", 1, K.FLY)
                spin:SetTarget(glyph)
                spin:SetDegrees(-360)
                return glyph
            end, function(glyph, d)
                SetArt(glyph, "glyph" .. d)
            end),
            s1 = 1.6,
            s2 = 1,
            delay = 1.8,
            light = Light,
            empty = Empty,
            reset = Reset,
            open = PlayOpen,
            wrong = PlayWrong,
        })
        MakeStones()
        return {
            Reset = lock.Reset,
            Stop = function()
                ringA.idle:Stop()
                ringB.idle:Stop()
            end,
        }
    end,
})
