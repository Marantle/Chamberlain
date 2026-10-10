local _, CH = ...
local K = CH.LockKit

-- ─────────────────────────────────────────────────────────────────────
-- Lock style 5: the Pumpkin Patch
-- ─────────────────────────────────────────────────────────────────────
-- The pumpkins a visitor found on the house's hunt sit in a tray where the
-- keys would be. A click sends one into the next hole and a click on one in
-- a hole sends it back. With every hole filled the patch opens, through the
-- code the pumpkins make (Housing/Hunt.lua). Try the lock fills the tray.

local Group, Fade, Grow = K.Group, K.Fade, K.Grow

local LAND_SOUND = SOUNDKIT.PUT_DOWN_GEMS
local OPEN_SOUND = SOUNDKIT.UI_GARRISON_COMMAND_TABLE_CHEST_UNLOCK_GOLD_SUCCESS
local WRONG_SOUND = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER

local C = K.Colors({
    edge = "e3a03a",
    ink = "3b2a1c",
    hint = "6b5539",
    sepia = "8f6b3a",
    spent = "b9a27e",
    rust = "8f3a10",
    key = "fbf6ec",
    lit = "ffd25a",
})

local GOURD_H = CH.GOURD_H
local SEAT_W, TRAY_W = 64, 42
local TRAY_BOX, TRAY_GAP = 52, 8
local MOUND_TOP = -252

local page, sky
local bats, holes, tray = {}, {}, {}
local house, n, have -- whose pumpkins, how many hide, how many the tray holds
local landed, opened = 0, false

local function Gourd(parent, w, layer)
    local t = K.Pic(parent, "gourd", w, w * GOURD_H, layer)
    t:SetPoint("CENTER")
    return t
end

-- The hole middles: one row for four or fewer, else four over the rest,
-- each row centred on the patch.
local function HolePoint(i)
    local rows = n > 4 and 2 or 1
    local row = i > 4 and 2 or 1
    local inRow = row == 1 and math.min(n, 4) or n - 4
    local k = row == 1 and i or i - 4
    local x = 260 + (k - (inRow + 1) / 2) * 100
    local y = rows == 1 and -336 or (row == 1 and -300 or -372)
    return x, y
end

local function TrayPoint(k)
    local w = n * TRAY_BOX + (n - 1) * TRAY_GAP
    return (520 - w) / 2 + (k - 1) * (TRAY_BOX + TRAY_GAP) + TRAY_BOX / 2, -499
end

-- ── Holes and the tray ───────────────────────────────────────────────

local Fly -- K.Flyers, made in Build

local function Paint(k)
    local b = tray[k]
    local inHand = k <= have and not b.out
    b.gourd:SetShown(k <= have)
    b.gourd:SetAlpha(inHand and 1 or 0.25)
    b:SetEnabled(inHand)
end

local Take -- below

local function MakeHole(i)
    local hole = K.Pic(page, "hole", 76, 34, "BORDER")
    -- the seat is the pumpkin sitting in it, its bottom in the hole
    local seat = CreateFrame("Button", nil, page)
    seat:SetSize(SEAT_W, SEAT_W * GOURD_H)
    seat:SetFrameLevel(page:GetFrameLevel() + 10)
    seat.gourd = Gourd(seat, SEAT_W)
    seat.glow = K.Pic(seat, "glow", 96, 96, "BACKGROUND")
    seat.glow:SetPoint("CENTER")
    seat.glow:SetBlendMode("ADD")
    K.Tint(seat.glow, C.lit)
    seat.plop = seat:CreateAnimationGroup()
    Grow(seat.plop, 1, 0.12, 1, 1.15, nil, "OUT")
    Grow(seat.plop, 2, 0.2, 1.15, 1, nil, "IN")
    -- one after another along the patch on open
    seat.flare = seat:CreateAnimationGroup()
    Grow(seat.flare, 1, 0.2, 1, 1.2, (i - 1) * 0.08, "OUT")
    Grow(seat.flare, 2, 0.3, 1.2, 1, nil, "IN")
    seat.lit = Group(seat.glow, function()
        seat.glow:SetAlpha(0.45)
    end)
    Fade(seat.lit, 1, 0.5, 0, 0.45, (i - 1) * 0.08)
    seat:SetScript("OnClick", function()
        Take(i)
    end)
    seat.hole = hole
    return seat
end

local function SitIn(i, k)
    local seat = holes[i]
    seat.k = k
    seat.gourd:Show()
    seat:Show()
end

local function Open()
    opened = true
    for i = 1, n do
        holes[i].glow:SetAlpha(1)
        holes[i].lit:Play()
        holes[i].flare:Play()
    end
    for _, b in ipairs(bats) do
        b.drift:Stop()
        b.flee:Play()
    end
    PlaySound(OPEN_SOUND, "SFX")
end

local function Landed(i, k)
    SitIn(i, k)
    holes[i].plop:Play()
    PlaySound(LAND_SOUND, "SFX")
    landed = landed + 1
    if landed < n then
        return
    end
    if K.Try(CH.PatchCode(ChamberlainDB.houses[house]), 1.4) then
        Open()
    else
        -- a map changed under the lock so the pumpkins no longer fit it
        PlaySound(WRONG_SOUND, "SFX")
    end
end

local function Put(k)
    if opened then
        return
    end
    for i = 1, n do
        if not holes[i].k then
            local b = tray[k]
            b.out = true
            holes[i].k = k -- taken now, so a second click aims at the next
            Paint(k)
            Fly(b, holes[i], nil, 1, SEAT_W / TRAY_W, function()
                Landed(i, k)
            end)
            return
        end
    end
end

-- Only a pumpkin that has landed goes back.
Take = function(i)
    local seat = holes[i]
    if opened or not seat.k or not seat.gourd:IsShown() then
        return
    end
    local k = seat.k
    seat.k = nil
    seat.gourd:Hide()
    landed = landed - 1
    Fly(seat, tray[k], nil, SEAT_W / TRAY_W, 1, function()
        tray[k].out = nil
        Paint(k)
    end)
end

-- ── The card ─────────────────────────────────────────────────────────

local yours, short

local function Reset(h, test)
    house = h
    local spots = CH.HuntSpots(ChamberlainDB.houses[h])
    n = #spots
    have = test and n or CH.PumpkinsFound(h)
    landed, opened = 0, false
    for i, seat in ipairs(holes) do
        local on = i <= n
        seat.k = nil
        seat.plop:Stop()
        seat.flare:Stop()
        seat.lit:Stop()
        seat.glow:SetAlpha(0)
        seat.gourd:Hide()
        seat:SetShown(on)
        seat.hole:SetShown(on)
        if on then
            local x, y = HolePoint(i)
            seat.hole:ClearAllPoints()
            seat.hole:SetPoint("CENTER", page, "TOPLEFT", x, y)
            seat:ClearAllPoints()
            seat:SetPoint("CENTER", page, "TOPLEFT", x, y + 14)
        end
    end
    for k, b in ipairs(tray) do
        b.out = nil
        b:SetShown(k <= n)
        if k <= n then
            b:ClearAllPoints()
            b:SetPoint("CENTER", page, "TOPLEFT", TrayPoint(k))
            Paint(k)
        end
    end
    for _, b in ipairs(bats) do
        b.flee:Stop()
        b:SetAlpha(1)
        b:Show()
        b.drift:Play()
    end
    yours:SetText(string.format(CH.L["LOCK_PATCH_YOURS_X"], have, n))
    local left = n - have
    if n == 0 then
        short:SetText(CH.L["LOCK_PATCH_NONE"])
    elseif left == 1 then
        short:SetText(CH.L["LOCK_PATCH_ONE_MORE"])
    elseif left > 1 then
        short:SetText(string.format(CH.L["LOCK_PATCH_MORE_X"], left))
    else
        short:SetText("")
    end
end

K.Register("patch", {
    w = 520,
    h = 724,
    back = { 0.94, 0.9, 0.83, 1 },
    edge = C.edge,
    title = C.ink,
    hint = C.hint,
    hintKey = "LOCK_PATCH_HINT",
    Build = function(p)
        page = p
        K.Paper(page, 1, 1, 1)
        K.CardEdge(page, C.edge, 10)
        local moon = K.Pic(page, "moon", 150, 88, "BORDER")
        moon:SetPoint("TOPLEFT", 24, -104)
        local town = K.Pic(page, "town", 348, 100, "BORDER")
        town:SetPoint("TOPLEFT", 86, -168)
        local mound = K.Pic(page, "mound", 452, 178, "BORDER")
        mound:SetPoint("TOPLEFT", 34, MOUND_TOP)
        -- the mound and the town sit on BORDER under the holes
        mound:SetDrawLayer("BORDER", -1)
        town:SetDrawLayer("BORDER", -2)

        sky = CreateFrame("Frame", nil, page)
        sky:SetAllPoints()
        sky:SetFrameLevel(page:GetFrameLevel() + 5)
        bats[1] = K.Bat(sky, "pbat1", 92, 54, 380, -112, { 6, -8, 1.6 }, { 160, 140, 0.6 })
        bats[2] = K.Bat(sky, "pbat2", 70, 46, 200, -120, { -5, 6, 1.9 }, { -170, 150, 0.6 })

        for i = 1, CH.PUMPKIN_MAX do
            holes[i] = MakeHole(i)
        end
        for k = 1, CH.PUMPKIN_MAX do
            local b = K.Button(page, "", TRAY_BOX, 46, { C.key[1], C.key[2], C.key[3], 0.6 }, C.sepia, C.ink)
            b.gourd = Gourd(b, TRAY_W)
            b:SetScript("OnClick", function()
                Put(k)
            end)
            tray[k] = b
        end
        Fly = K.Flyers(page, function(fl)
            return Gourd(fl, TRAY_W, "OVERLAY")
        end, function() end)

        yours = page:CreateFontString(nil, "OVERLAY")
        K.Font(yours, 17)
        yours:SetPoint("TOP", 0, -452)
        yours:SetTextColor(CH.RGBA(C.hint, 1))
        short = page:CreateFontString(nil, "OVERLAY")
        K.Font(short, 15)
        short:SetPoint("TOP", 0, -536)
        short:SetTextColor(CH.RGBA(C.rust, 1))

        local back = K.Button(page, CH.L["LOCK_PATCH_BACK"], 196, 40, { 0, 0, 0, 0 }, C.spent, C.hint)
        K.Font(back.label, 17)
        back:SetPoint("TOP", 0, -616)
        back:SetScript("OnClick", function()
            for i = 1, n do
                Take(i)
            end
        end)
        return {
            Reset = Reset,
            Stop = function()
                for _, b in ipairs(bats) do
                    b.drift:Stop()
                end
            end,
        }
    end,
})
