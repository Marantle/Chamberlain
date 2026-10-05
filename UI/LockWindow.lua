local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- The lock on a locked area: the Arcane Ward
-- ─────────────────────────────────────────────────────────────────────
-- The banner's lock button opens it. Stones put glyphs into the ring, a
-- socket sends its glyph back, and Unlock tries the code (Housing/Lock.lua).
-- Everything moves through AnimationGroups, so nothing runs while it's shut.
--
-- Things learned building it in game:
-- svg (VectorGraphics) has no CreateAnimationGroup, so whatever moves is a
-- png texture and only the still art is svg. Two rotations on one texture
-- fight, so the idle spin pauses while the bite plays. A frame scaling while
-- a texture in it scales too blows the texture up to fill the screen, so
-- those never overlap. An additive glow with a pale tint at full alpha burns
-- out white.

local ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }
local FLY = 0.46

-- The game's own sounds, picked by ear in game. A landing glyph takes one of
-- the two runecarver picks at random so a row of them doesn't drone.
local LAND_SOUNDS = { SOUNDKIT.UI_RUNECARVING_SELECT_UPPER_RUNE, SOUNDKIT.UI_RUNECARVING_SELECT_LOWER_RUNE }
local OPEN_SOUND = SOUNDKIT.UI_72_ARTIFACT_FORGE_FINAL_TRAIT_UNLOCKED
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

-- The ward's own colours, violet and pink. Written as hex like the canvas
-- they came from and turned into r, g, b once.
local C = {
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
}
for name, hex in pairs(C) do
    C[name] =
        { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

local function Tint(r, c)
    r:SetVertexColor(c[1], c[2], c[3])
end

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

local function Anim(ag, kind, order, dur, delay, smooth)
    local a = ag:CreateAnimation(kind)
    a:SetOrder(order)
    a:SetDuration(dur)
    if delay then
        a:SetStartDelay(delay)
    end
    if smooth then
        a:SetSmoothing(smooth)
    end
    return a
end

local function Group(region, onFinished)
    local ag = region:CreateAnimationGroup()
    if onFinished then
        ag:SetScript("OnFinished", onFinished)
    end
    return ag
end

local function Fade(ag, order, dur, from, to, delay)
    local a = Anim(ag, "Alpha", order, dur, delay)
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    return a
end

local function Grow(ag, order, dur, from, to, delay, smooth)
    local a = Anim(ag, "Scale", order, dur, delay, smooth)
    a:SetScaleFrom(from, from)
    a:SetScaleTo(to, to)
    return a
end

local function Spin(ag, order, dur, degrees, delay, smooth)
    Anim(ag, "Rotation", order, dur, delay, smooth):SetDegrees(degrees)
end

-- Keeps a region out of sight for its first dur seconds. Its own alpha stays
-- 1, which works whether the game multiplies an Alpha animation into it or not.
local function Wait(ag, dur)
    return Fade(ag, 1, dur, 0, 0)
end

-- A row of moves one after another, for shakes and bites.
local function Chain(ag, kind, steps, dur)
    for i, v in ipairs(steps) do
        local a = Anim(ag, kind, i, dur)
        if kind == "Rotation" then
            a:SetDegrees(v)
        else
            a:SetOffset(v, 0)
        end
    end
end

local f, stage, tag, title, ringA, ringB, crystal, halo, glow
local sockets, keys, motes = {}, {}, {}
local typed, landed, result = "", 0, "idle"
local target, targetHouse -- the area and the house it's in
local testing -- an owner's Try the lock, see CH.LockTestCopy
local revealing = false -- opened, and the banner hasn't been told yet

-- ── Flying glyphs ────────────────────────────────────────────────────
-- x eases out and y eases in, two translations at once, so the glyph
-- travles on an arc.
local spare = {}

local function NewFlyer()
    local fl = CreateFrame("Frame", nil, f)
    fl:SetSize(40, 40)
    fl:SetFrameLevel(f:GetFrameLevel() + 30)
    fl.glyph = Art(fl, "glyph1", 24, C.bright, "OVERLAY", true)
    fl.ag = fl:CreateAnimationGroup()
    fl.x = Anim(fl.ag, "Translation", 1, FLY, nil, "OUT")
    fl.y = Anim(fl.ag, "Translation", 1, FLY, nil, "IN")
    fl.scale = Grow(fl.ag, 1, FLY, 1, 1, nil, "OUT")
    local spin = Anim(fl.ag, "Rotation", 1, FLY)
    spin:SetTarget(fl.glyph)
    spin:SetDegrees(-360)
    fl.ag:SetScript("OnFinished", function()
        fl:Hide()
        table.insert(spare, fl)
        if fl.done then
            fl.done()
        end
    end)
    return fl
end

local function Fly(from, to, d, s1, s2, done)
    local fl = table.remove(spare) or NewFlyer()
    SetArt(fl.glyph, "glyph" .. d)
    fl:ClearAllPoints()
    fl:SetPoint("CENTER", from)
    local fx, fy = from:GetCenter()
    local tx, ty = to:GetCenter()
    fl.x:SetOffset(tx - fx, 0)
    fl.y:SetOffset(0, ty - fy)
    fl.scale:SetScaleFrom(s1, s1)
    fl.scale:SetScaleTo(s2, s2)
    fl.done = done
    fl:Show()
    fl.ag:Play()
end

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

local TakeFrom

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
    s:SetScript("OnClick", function()
        if i <= landed then
            TakeFrom(i)
        end
    end)
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
    title.reveal:Stop()
    title:SetText(CH.L["LOCK_AREA"])
    for _, s in ipairs(sockets) do
        Empty(s)
    end
    typed, landed, result = "", 0, "idle"
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
    result = "open"
    revealing = true
    PlaySound(OPEN_SOUND, "SFX")
    for i = 1, landed do
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
    title:SetText(target.name)
    title.reveal:Play()
end

local function PlayWrong()
    result = "wrong"
    PlaySound(WRONG_SOUND, "SFX")
    for i = 1, landed do
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

local function Submit()
    if result == "idle" and landed >= CH.LOCK_CODE_MIN and landed == #typed then
        if CH.TryLockCode(target, targetHouse, typed, testing) then
            PlayOpen()
        else
            PlayWrong()
        end
    end
end

-- ── Input ────────────────────────────────────────────────────────────
local function Press(k)
    if result == "open" then
        return
    elseif result == "wrong" then
        Reset()
    end
    if #typed >= CH.LOCK_CODE_MAX then
        return
    end
    local d = ORDER[k]
    local i = #typed + 1
    typed = typed .. d
    Fly(keys[k], sockets[i], d, 1.6, 1, function()
        -- it may have been sent back while flying
        if typed:sub(i, i) == tostring(d) then
            landed = math.max(landed, i)
            Light(sockets[i], d)
        end
    end)
end

function TakeFrom(i)
    if result ~= "idle" then
        return
    end
    for j = i, landed do
        local d = tonumber(typed:sub(j, j))
        Empty(sockets[j])
        Fly(sockets[j], keys[d == 0 and 10 or d], d, 1, 1.6)
    end
    typed = typed:sub(1, i - 1)
    landed = math.min(landed, i - 1)
end

-- ── Window ───────────────────────────────────────────────────────────
local function TextButton(label, w, h, border)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(CH.BACKDROP_THIN)
    b:SetBackdropColor(CH.RGBA(C.stone, 1))
    b:SetBackdropBorderColor(CH.RGBA(border or C.ink, 1))
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    fs:SetTextColor(CH.RGBA(C.text, 1))
    return b
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
            Press(k)
        end)
        keys[k] = b
    end
    local clear = TextButton(CH.L["LOCK_CLEAR"], 196, 40)
    clear:SetPoint("TOPLEFT", 60, -664)
    clear:SetScript("OnClick", function()
        if result == "wrong" then
            Reset()
        elseif result == "idle" and landed > 0 then
            TakeFrom(1)
        end
    end)
    local unlock = TextButton(CH.L["LOCK_UNLOCK"], 196, 40, C.pink)
    unlock:SetPoint("TOPRIGHT", -60, -664)
    unlock:SetScript("OnClick", Submit)
end

local function Build()
    f = CreateFrame("Frame", "ChamberlainLock", UIParent, "BackdropTemplate")
    f:SetSize(520, 724)
    f:SetPoint("CENTER")
    -- over the house map, which is DIALOG, since Try the lock opens from it
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop(CH.BACKDROP_THIN)
    f:SetBackdropColor(0.06, 0.04, 0.1, 0.96)
    f:SetBackdropBorderColor(CH.RGBA(C.frame, 1))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- Kept off UISpecialFrames so Showcase can carry it through Hide UI,
    -- which closes everything on that list. The x is the way out.
    CH.lockWindow = f
    -- the template's own click goes through HideUIPanel, which refuses in combat
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    tag = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tag:SetPoint("TOP", 0, -22)
    -- Blizzard's Morpheus family, which has a font for every alphabet a room
    -- name can be typed in
    title = f:CreateFontString(nil, "OVERLAY", "QuestFont_30")
    title:SetPoint("TOP", 0, -40)
    title:SetTextColor(CH.RGBA(C.title, 1))
    -- the real name fades in late, holds a moment, then the lock closes and
    -- the banner takes over
    title.reveal = Group(title, function()
        f:Hide()
    end)
    Wait(title.reveal, 1.8)
    Fade(title.reveal, 2, 0.6, 0, 1)
    Fade(title.reveal, 3, 0.9, 1, 1)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", 0, -74)
    hint:SetText(CH.L["LOCK_ENTER_CODE"])
    hint:SetTextColor(CH.RGBA(C.hint, 1))

    stage = CreateFrame("Frame", nil, f)
    stage:SetSize(400, 400)
    stage:SetPoint("TOP", 0, -100)
    stage.jolt = stage:CreateAnimationGroup()
    Chain(stage.jolt, "Translation", { -9, 16, -11, 6, -2 }, 0.08)

    MakeRings()
    MakeCore()
    for i = 1, 8 do
        sockets[i] = MakeSocket(i)
    end
    MakeStones()

    f:SetScript("OnHide", function(self)
        -- the UI hiding with the lock still up, glyphs and all
        if CH.OnlyParentHid(self) then
            return
        end
        ringA.idle:Stop()
        ringB.idle:Stop()
        -- however it closes after the right code, Escape in the middle of
        -- the fade included, the banner hears it once
        title.reveal:Stop()
        if revealing then
            revealing = false
            if testing then
                CH.PreviewReveal(target)
            else
                CH.RoomRevealed(target)
            end
        end
    end)
end

function CH.OpenLock(zone, house, test)
    if not f then
        Build()
        -- opened from a banner Showcase holds up, it goes along
        CH.RefreshKeepOnScreen()
    end
    f:Hide()
    target, targetHouse, testing = zone, house, test
    tag:SetText(CH.LockStyleName(zone):upper())
    f:Show()
    Reset()
end

function CH.CloseLock()
    if f and result ~= "open" then
        f:Hide()
    end
end
