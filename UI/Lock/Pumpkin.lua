local _, CH = ...
local K = CH.LockKit

-- ─────────────────────────────────────────────────────────────────────
-- Lock style 2: the Pumpkin Balloon
-- ─────────────────────────────────────────────────────────────────────
-- A Hallowe'en postcard. The numbers fly into a row of slots under a
-- jack-o'-lantern balloon, and on the right code its eyes light up and it
-- sails off the card, hauling the witch's basket up from under the card's
-- edge on its way. The art is cut from an old postcard, see
-- _lock-art/postcards.py.

local Group, Fade, Grow, Move, Tint = K.Group, K.Fade, K.Grow, K.Move, K.Tint

local LAND_SOUND = SOUNDKIT.PUT_DOWN_GEMS
local OPEN_SOUND = SOUNDKIT.UI_GARRISON_COMMAND_TABLE_CHEST_UNLOCK_GOLD_SUCCESS
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

local C = K.Colors({
    edge = "e3a03a", -- the card's orange border
    ink = "3b2a1c",
    hint = "6b5539",
    sepia = "8f6b3a",
    faint = "a88c62", -- an empty slot
    spent = "b9a27e",
    orange = "c4561c",
    rust = "8f3a10",
    cream = "fbf3e4",
    key = "fbf6ec",
    lit = "ffd25a",
    dead = "3a2414",
})

-- far enough to put the basket's top below the window's bottom edge
local BASKET_DROP = 400
-- The sail the balloon and the basket fly together, x and y. y takes the
-- basket's bottom past the card's top edge too, not just the balloon.
local SAIL_X, SAIL_Y = 50, 560

local page, stage, sky, balloon, basket, lock
local eyes, bats, slots = {}, {}, {}

-- ── Slots ────────────────────────────────────────────────────────────
local function Empty(s)
    s.land:Stop()
    s.flare:Stop()
    s.digit:SetText("")
    s.digit:SetTextColor(CH.RGBA(C.orange, 1))
    Tint(s.ring, C.faint)
end

local function Light(s, d)
    s.digit:SetText(d)
    Tint(s.ring, C.orange)
    s.land:Play()
    PlaySound(LAND_SOUND, "SFX")
end

local function MakeSlot(i)
    local s = CreateFrame("Button", nil, stage)
    s:SetSize(40, 40)
    s:SetPoint("TOPLEFT", 12 + (i - 1) * 48, -256)
    s:SetFrameLevel(stage:GetFrameLevel() + 10)
    -- png, an svg would stand still while the slot pops
    s.ring = K.Pic(s, "ring", 40, 40, "BORDER")
    s.ring:SetAllPoints()
    s.digit = s:CreateFontString(nil, "OVERLAY")
    K.Font(s.digit, 22)
    s.digit:SetPoint("CENTER", 0, 1)
    s.land = s:CreateAnimationGroup()
    Grow(s.land, 1, 0.35, 1.3, 1, nil, "OUT")
    -- one after another along the row on open
    s.flare = s:CreateAnimationGroup()
    Grow(s.flare, 1, 0.2, 1, 1.3, (i - 1) * 0.07, "OUT")
    Grow(s.flare, 2, 0.3, 1.3, 1, nil, "IN")
    return s
end

-- ── The card ─────────────────────────────────────────────────────────
-- An eye of the lantern, a glow over the card's painted eye. Lit is added
-- light, dead is a dark smudge laid over it.
local function MakeEye(x, lit)
    local e = K.Pic(balloon, "glow", 44, 44, "OVERLAY")
    e:SetPoint("TOPLEFT", x, -117)
    e:SetAlpha(0)
    if lit then
        e:SetBlendMode("ADD")
        Tint(e, C.lit)
        -- catches, gutters, then burns. Added light past half burns out
        -- white, so it stays under.
        e.on = Group(e, function()
            e:SetAlpha(0.5)
        end)
        K.Wait(e.on, 0.4)
        Fade(e.on, 2, 0.42, 0, 0.5)
        Fade(e.on, 3, 0.35, 0.5, 0.3)
        Fade(e.on, 4, 0.63, 0.3, 0.5)
    else
        Tint(e, C.dead)
        e.on = Group(e, function()
            e:SetAlpha(0.9)
        end)
        Fade(e.on, 1, 0.4, 0, 1)
        Fade(e.on, 2, 1.2, 1, 0.9)
    end
    return e
end

local function MakeCard()
    local town = K.Pic(stage, "town", 348, 100, "BORDER")
    town:SetPoint("TOPLEFT", 26, -300)
    -- The balloon and the bats move on their own, so they hang over the
    -- stage instead of in it. Inside the stage the shake on a wrong code
    -- knocked them off the card for good.
    sky = CreateFrame("Frame", nil, page)
    sky:SetAllPoints(stage)
    sky:SetFrameLevel(stage:GetFrameLevel() + 5)
    bats[1] = K.Bat(sky, "pbat1", 92, 54, 8, -40, { 6, 8, 1.6 }, { -160, 140, 1 })
    bats[2] = K.Bat(sky, "pbat2", 84, 55, 304, -110, { -5, 6, 1.9 }, { 170, 160, 1.1 })

    balloon = CreateFrame("Frame", nil, sky)
    balloon:SetSize(190, 235)
    balloon:SetPoint("TOPLEFT", 105, -6)
    local pumpkin = K.Pic(balloon, "pumpkin", 190, 235)
    pumpkin:SetAllPoints()
    balloon.bob = Group(balloon)
    balloon.bob:SetLooping("BOUNCE")
    Move(balloon.bob, 1, 2.25, 0, 6, nil, "IN_OUT")
    -- slips its moorings and sails off the top of the card
    balloon.sail = Group(balloon, function()
        balloon:Hide()
    end)
    Move(balloon.sail, 1, 1.8, SAIL_X, SAIL_Y, 1, "IN")

    -- The witch's basket waits under the card's bottom edge, out of sight
    -- in the clipped window, and on open it's hauled up to hang from the
    -- ropes just before the balloon goes. As a child of the balloon it was
    -- left behind by the sail, so it flies the same sail on its own.
    basket = CreateFrame("Frame", nil, sky)
    basket:SetSize(190, 179)
    basket:SetPoint("TOPLEFT", 105, -241 - BASKET_DROP)
    K.Pic(basket, "basket", 190, 179):SetAllPoints()
    basket.rise = Group(basket, function()
        basket:Hide()
    end)
    Move(basket.rise, 1, 0.9, 0, BASKET_DROP, nil, "OUT")
    Move(basket.rise, 2, 1.8, SAIL_X, SAIL_Y, 0.1, "IN")
    eyes.lit = { MakeEye(42, true), MakeEye(100, true) }
    eyes.dead = { MakeEye(42), MakeEye(100) }
end

-- ── Open and wrong ───────────────────────────────────────────────────
local function Reset()
    balloon.sail:Stop()
    basket.rise:Stop()
    basket:Show()
    balloon:Show()
    balloon.bob:Play()
    for _, b in ipairs(bats) do
        b.flee:Stop()
        b.panic:Stop()
        b:SetAlpha(1)
        b:Show()
        b.drift:Play()
    end
    for _, e in ipairs({ eyes.lit[1], eyes.lit[2], eyes.dead[1], eyes.dead[2] }) do
        e.on:Stop()
        e:SetAlpha(0)
    end
    stage.jolt:Stop()
    for _, s in ipairs(slots) do
        Empty(s)
    end
end

-- An Alpha animation may be multiplied into the eye's own alpha, so that
-- goes to 1 before each one plays.
local function PlayOpen()
    PlaySound(OPEN_SOUND, "SFX")
    for i = 1, lock.landed do
        slots[i].land:Stop()
        slots[i].flare:Play()
    end
    for _, e in ipairs(eyes.lit) do
        e:SetAlpha(1)
        e.on:Play()
    end
    balloon.bob:Stop()
    basket.rise:Play()
    balloon.sail:Play()
    for _, b in ipairs(bats) do
        b.drift:Stop()
        b.flee:Play()
    end
end

local function PlayWrong()
    PlaySound(WRONG_SOUND, "SFX")
    for i = 1, lock.landed do
        slots[i].digit:SetTextColor(CH.RGBA(C.spent, 1))
        Tint(slots[i].ring, C.spent)
    end
    stage.jolt:Play()
    for _, e in ipairs(eyes.dead) do
        e:SetAlpha(1)
        e.on:Play()
    end
    for _, b in ipairs(bats) do
        b.panic:Play()
    end
end

K.Register("pumpkin", {
    w = 520,
    h = 724,
    back = { 0.94, 0.9, 0.83, 1 },
    edge = C.edge,
    title = C.ink,
    hint = C.hint,
    hintKey = "LOCK_PUMPKIN_HINT",
    Build = function(p)
        page = p
        K.Paper(page, 1, 1, 1)
        K.CardEdge(page, C.edge, 10)
        stage = CreateFrame("Frame", nil, page)
        stage:SetSize(400, 400)
        stage:SetPoint("TOP", 0, -100)
        stage.jolt = stage:CreateAnimationGroup()
        K.Chain(stage.jolt, "Translation", { -9, 16, -11, 6, -2 }, 0.08)

        MakeCard()
        for i = 1, CH.LOCK_CODE_MAX do
            slots[i] = MakeSlot(i)
        end
        local o = {
            slots = slots,
            Fly = K.Flyers(page, function(fl)
                local fs = fl:CreateFontString(nil, "OVERLAY")
                K.Font(fs, 24)
                fs:SetPoint("CENTER")
                fs:SetTextColor(CH.RGBA(C.orange, 1))
                return fs
            end, function(fs, d)
                fs:SetText(d)
            end),
            s1 = 1.3,
            s2 = 1,
            delay = 2.1,
            light = Light,
            empty = Empty,
            reset = Reset,
            open = PlayOpen,
            wrong = PlayWrong,
        }
        lock = K.Slots(o)
        o.keys = K.PostcardKeys(page, C, "LOCK_PUMPKIN_GO", lock)
        return {
            Reset = lock.Reset,
            Stop = function()
                balloon.bob:Stop()
                for _, b in ipairs(bats) do
                    b.drift:Stop()
                end
            end,
        }
    end,
})
