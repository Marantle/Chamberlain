local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Pumpkin hunt: the pop-up and the bag
-- ─────────────────────────────────────────────────────────────────────
-- Walking up to a hidden pumpkin brings the pop-up low in the middle of
-- the screen (Housing/Hunt.lua decides when). Pick it up and the pumpkin
-- flies into the bag, which hangs under the room banner like the story
-- card, stays a few seconds and goes. The bar's Pumpkins button brings the
-- bag back.

local GOURD = CH.MEDIA .. "lock-gourd.png"
local GOURD_H = CH.GOURD_H
local FLY = 0.7
local BAG_SECONDS = 4
local SLOT = 26

local PICK_SOUND = SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE
local LAND_SOUND = SOUNDKIT.PUT_DOWN_GEMS
local ASK_SOUND = SOUNDKIT.UI_EVENT_SCHEDULER_CHIME

local function Gourd(parent, w, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(GOURD)
    t:SetSize(w, w * GOURD_H)
    return t
end

-- Where a region's middle sits on UIParent, whatever scale it's drawn at.
-- Its parent says the scale, since it may be a texture. nil while it has no
-- place yet.
local function Middle(r)
    local x, y = r:GetCenter()
    if not x then
        return nil
    end
    local s = r:GetParent():GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * s, y * s
end

-- ── The bag ──────────────────────────────────────────────────────────

local bag = CreateFrame("Frame", "ChamberlainPumpkinBag", UIParent, "BackdropTemplate")
bag:SetFrameStrata("HIGH")
bag:SetHeight(44)
bag:SetBackdrop(CH.BACKDROP_THIN)
bag:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
bag:SetBackdropBorderColor(CH.RGBA(CH.COLORS.frame, 0.9))
bag:Hide()
CH.pumpkinBag = bag -- for Showcase

local bagName = bag:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bagName:SetPoint("TOPLEFT", 10, -8)
bagName:SetText(CH.L["HUNT_BAG"])
bagName:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
local bagCount = bag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bagCount:SetPoint("TOPLEFT", bagName, "BOTTOMLEFT", 0, -2)
bagCount:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local slots = {}
for i = 1, CH.PUMPKIN_MAX do
    local s = CreateFrame("Frame", nil, bag, "BackdropTemplate")
    s:SetSize(SLOT, SLOT)
    s:SetPoint("LEFT", 84 + (i - 1) * (SLOT + 4), 0)
    s:SetBackdrop(CH.BACKDROP_THIN)
    s:SetBackdropColor(0, 0, 0, 0.6)
    s:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.5))
    s.gourd = Gourd(s, 22)
    s.gourd:SetPoint("CENTER")
    s.land = s.gourd:CreateAnimationGroup()
    local grow = s.land:CreateAnimation("Scale")
    grow:SetScaleFrom(1.6, 1.6)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.35)
    grow:SetSmoothing("OUT")
    slots[i] = s
end

local RESTART_W = 74
local restartBtn = CH.MakeButton(bag, "HUNT_RESTART", RESTART_W, 20)
restartBtn:SetPoint("RIGHT", -8, 0)

local hideTimer

local function CancelHide()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

-- Under the story card when it hangs there, else under the banner, or in
-- the banner's place when there's none, as the card does.
local function PlaceBag()
    bag:ClearAllPoints()
    local th = CH.talkingHead
    if th:IsShown() and not ChamberlainDB.settings.yapperLoose then
        bag:SetPoint("TOP", th, "BOTTOM", 0, -4)
    elseif CH.bannerRoom and CH.banner:IsShown() then
        bag:SetPoint("TOP", CH.banner, "BOTTOM", 0, -2)
    else
        bag:SetPoint("TOP", CH.banner, "TOP")
    end
end

-- The slots for the house you stand in, all found ones lit. With flying the
-- last of them is still in the air and lights when it lands.
local function FillBag(flying)
    local house = CH.currentHouseGUID
    local spots = CH.HuntSpots(ChamberlainDB.houses[house])
    local n = 0
    for i, s in ipairs(slots) do
        local spot = spots[i]
        s:SetShown(spot ~= nil)
        if spot and CH.IsPumpkinFound(house, spot) then
            n = n + 1
        end
    end
    for i = 1, #spots do
        slots[i].gourd:SetShown(i <= n and not (flying and i == n))
    end
    bagCount:SetText(string.format(CH.L["HUNT_X_OF_Y"], n, #spots))
    restartBtn:SetShown(n > 0)
    bag:SetWidth(84 + #spots * (SLOT + 4) + 6 + (n > 0 and RESTART_W + 8 or 0))
    return n
end

-- the bag stays up while the confirm asks
restartBtn:SetScript("OnClick", function()
    CancelHide()
    local house = CH.currentHouseGUID
    CH.ShowConfirm("HUNT_TITLE", CH.L["HUNT_RESTART_ASK"], "HUNT_RESTART", function()
        CH.ForgetPumpkins(house)
        FillBag()
        CH.RefreshHUDMode()
    end)
end)

-- seconds nil keeps it up until the bar's button puts it away
local function ShowBag(seconds, flying)
    CancelHide()
    local n = FillBag(flying)
    PlaceBag()
    if not bag:IsShown() then
        bag:SetAlpha(0)
        bag:Show()
        UIFrameFadeIn(bag, 0.25, 0, 1)
    end
    if seconds then
        hideTimer = C_Timer.NewTimer(seconds, function()
            hideTimer = nil
            CH.HidePumpkinBag()
        end)
    end
    return n
end

function CH.HidePumpkinBag()
    CancelHide()
    UIFrameFadeRemoveFrame(bag)
    bag:Hide()
end

-- The bar's Pumpkins button.
function CH.TogglePumpkinBag()
    if bag:IsShown() and not hideTimer then
        CH.HidePumpkinBag()
    else
        ShowBag()
    end
end

-- ── The pumpkin in the air ───────────────────────────────────────────
-- x eases out and y eases in, two translations at once, so it flies on an
-- arc and shrinks to the slot on the way.

local flyer = CreateFrame("Frame", nil, UIParent)
flyer:SetFrameStrata("TOOLTIP")
flyer:SetSize(100, 100 * GOURD_H)
flyer:Hide()
local flyerArt = Gourd(flyer, 100)
flyerArt:SetAllPoints()
local flight = flyer:CreateAnimationGroup()
local function Leg(kind, smooth)
    local a = flight:CreateAnimation(kind)
    a:SetDuration(FLY)
    a:SetSmoothing(smooth)
    return a
end
local legX, legY = Leg("Translation", "OUT"), Leg("Translation", "IN")
local shrink = Leg("Scale", "IN")
shrink:SetScaleFrom(1, 1)
local spin = Leg("Rotation", "IN")
spin:SetDegrees(-340)
local landing
local function Land()
    flyer:Hide()
    local s = slots[landing]
    s.gourd:Show()
    s.land:Play()
    PlaySound(LAND_SOUND, "SFX")
end
flight:SetScript("OnFinished", Land)

-- A bag laid out on this very frame may not have its place yet, and then
-- the pumpkin just lands.
local function Fly(from, slot)
    landing = slot
    local fx, fy = Middle(from)
    local tx, ty = Middle(slots[slot])
    if not (fx and tx) then
        Land()
        return
    end
    flyer:ClearAllPoints()
    flyer:SetPoint("CENTER", UIParent, "BOTTOMLEFT", fx, fy)
    legX:SetOffset(tx - fx, 0)
    legY:SetOffset(0, ty - fy)
    shrink:SetScaleTo(22 / 100, 22 / 100)
    flight:Stop()
    flyer:Show()
    flight:Play()
end

-- ── The pop-up ───────────────────────────────────────────────────────

local POP_W = 300

local pop = CreateFrame("Frame", "ChamberlainPumpkinPopup", UIParent, "BackdropTemplate")
pop:SetSize(POP_W, 214)
pop:SetPoint("BOTTOM", 0, 200)
pop:SetFrameStrata("HIGH")
CH.SkinWindow(pop, "HUNT_TITLE", true)
pop:Hide()
-- Escape is Leave it
table.insert(UISpecialFrames, "ChamberlainPumpkinPopup")
CH.pumpkinPopup = pop -- for Showcase

local popArt = Gourd(pop, 100)
popArt:SetPoint("TOP", 0, -36)
local bob = popArt:CreateAnimationGroup()
bob:SetLooping("BOUNCE")
local rise = bob:CreateAnimation("Translation")
rise:SetOffset(0, 5)
rise:SetDuration(1.2)
rise:SetSmoothing("IN_OUT")

local popTitle = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popTitle:SetPoint("TOP", popArt, "BOTTOM", 0, -10)
popTitle:SetText(CH.L["HUNT_FOUND"])
popTitle:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
local popWhere = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
popWhere:SetPoint("TOP", popTitle, "BOTTOM", 0, -4)
popWhere:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local pickBtn = CH.MakeButton(pop, "HUNT_PICK", 110, 22)
pickBtn:SetPoint("BOTTOMLEFT", pop, "BOTTOM", 4, 12)
CH.SetButtonActive(pickBtn, true)
local leaveBtn = CH.MakeButton(pop, "HUNT_LEAVE", 110, 22)
leaveBtn:SetPoint("BOTTOMRIGHT", pop, "BOTTOM", -4, 12)
leaveBtn:SetScript("OnClick", function()
    pop:Hide()
end)

local offered -- the spot the pop-up shows

pop:SetScript("OnShow", function()
    bob:Play()
end)
pop:SetScript("OnHide", function()
    bob:Stop()
end)

pickBtn:SetScript("OnClick", function()
    if not offered then
        return
    end
    CH.PickPumpkin(CH.currentHouseGUID, offered)
    offered = nil
    PlaySound(PICK_SOUND, "SFX")
    local n = ShowBag(BAG_SECONDS + FLY, true)
    -- the bag must be laid out before the flight can aim at a slot
    Fly(popArt, n)
    pop:Hide()
    CH.RefreshHUDMode()
end)

function CH.ShowPumpkinPopup(spot)
    offered = spot
    local room = CH.currentRoom
    popWhere:SetText(room and not room.nameless and string.format(CH.L["HUNT_IN_X"], room.name) or "")
    if not pop:IsShown() then
        PlaySound(ASK_SOUND, "SFX")
    end
    pop:Show()
end

function CH.HidePumpkinPopup()
    offered = nil
    pop:Hide()
end
