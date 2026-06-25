local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room banner  (visible while inside a named zone)
-- ─────────────────────────────────────────────────────────────────────

CH.banner = CreateFrame("Frame", "ChamberlainBannerFrame", UIParent)
local banner = CH.banner
banner:SetSize(340, 54)
banner:SetFrameStrata("HIGH")
banner:SetAlpha(0)
banner:Hide() -- hidden until a room is entered; see CH.ShowBanner/CH.HideBanner

local bannerBg = banner:CreateTexture(nil, "BACKGROUND")
bannerBg:SetAllPoints()
bannerBg:SetColorTexture(0, 0, 0, 0.52)

CH.bannerLineTop = banner:CreateTexture(nil, "BORDER")
CH.bannerLineTop:SetHeight(1)
CH.bannerLineTop:SetPoint("TOPLEFT", banner, "TOPLEFT", 12, -12)
CH.bannerLineTop:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -12, -12)
CH.bannerLineTop:SetColorTexture(0.85, 0.75, 0.15, 0.90)

CH.bannerLineBot = banner:CreateTexture(nil, "BORDER")
CH.bannerLineBot:SetHeight(1)
CH.bannerLineBot:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 12, 12)
CH.bannerLineBot:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -12, 12)
CH.bannerLineBot:SetColorTexture(0.85, 0.75, 0.15, 0.90)

CH.bannerText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
-- Default centered across the full banner. SetBannerRoom re-anchors to reserve
-- room on the right only when the Read button is shown.
CH.bannerText:SetPoint("LEFT", banner, "LEFT", 16, 0)
CH.bannerText:SetPoint("RIGHT", banner, "RIGHT", -16, 0)
CH.bannerText:SetJustifyH("CENTER")
CH.bannerText:SetWordWrap(false)
CH.bannerText:SetTextColor(1.00, 0.92, 0.40, 1)

-- "Read" button: shown only when the current room has a description, opens the
-- talking-head yapper (which hides this banner while it's up).
CH.bannerYapBtn = CH.MakeButton(banner, CH.L["BANNER_READ"], 44, 18)
CH.bannerYapBtn:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
CH.bannerYapBtn:SetScript("OnClick", function()
    CH.OpenYapper()
end)
CH.bannerYapBtn:Hide()

-- Default banner colors, overridden by per-zone colors on entry
CH.BANNER_TEXT_COLOR = { 1.00, 0.92, 0.40 }
CH.BANNER_LINE_COLOR = { 0.85, 0.75, 0.15 }

-- Track the room the banner is currently annoucing, size the banner to fit the
-- full room name (names are already length-capped, so no ellipsis), and place
-- the Read button after the name when the room has a description.
local BANNER_PAD = 22 -- gap on each side of the content
local BANNER_MIN_W = 180 -- keep short names looking like a banner, not a chip
local YAP_BTN_W = 44 -- must match the Read button's width

function CH.SetBannerRoom(zone)
    CH.bannerRoom = zone
    if not zone then
        CH.bannerYapBtn:Hide()
        return
    end
    local show = zone.rpText and zone.rpText ~= "" and ChamberlainDB.settings.showRoomText

    -- Measure the name unconstrained (single anchor) so we get its natural width.
    CH.bannerText:ClearAllPoints()
    CH.bannerText:SetPoint("LEFT", banner, "LEFT", BANNER_PAD, 0)
    local textW = CH.bannerText:GetStringWidth()

    if show then
        -- name on the left, Read button right after it, both padded symmetrically
        CH.bannerYapBtn:ClearAllPoints()
        CH.bannerYapBtn:SetPoint("LEFT", CH.bannerText, "RIGHT", 8, 0)
        CH.bannerYapBtn:Show()
        banner:SetWidth(math.max(BANNER_MIN_W, BANNER_PAD + textW + 8 + YAP_BTN_W + BANNER_PAD))
    else
        CH.bannerYapBtn:Hide()
        banner:SetWidth(math.max(BANNER_MIN_W, textW + BANNER_PAD * 2))
        CH.bannerText:ClearAllPoints()
        CH.bannerText:SetPoint("CENTER", banner, "CENTER", 0, 0)
    end
end

CH.ApplyBannerPos = CH.MakeMovablePersistent(banner, "bannerX", "bannerY")

-- An alpha-0 frame still captures mouse clicks, which would block clicks anywhere
-- outside a house. So the banner is Shown while announcing a room and Hidden once
-- it finishes fading out, rather than just left sitting at alpha 0.
local bannerTimer -- pending auto fade-out (ChamberlainDB.settings.bannerTimeout)

function CH.ShowBanner(dur)
    if bannerTimer then
        bannerTimer:Cancel()
        bannerTimer = nil
    end
    banner:Show()
    UIFrameFadeIn(banner, dur or 0.5, banner:GetAlpha(), 1)
    -- Optional auto fade-out: hide the banner a set number of seconds after it
    -- appears, even while still in the room. 0 keeps it up until you leave.
    local timeout = ChamberlainDB.settings.bannerTimeout or 0
    if timeout > 0 then
        bannerTimer = C_Timer.NewTimer(timeout, function()
            bannerTimer = nil
            CH.HideBanner(0.8)
        end)
    end
end

function CH.HideBanner(dur)
    if bannerTimer then
        bannerTimer:Cancel()
        bannerTimer = nil
    end
    dur = dur or 0.8
    UIFrameFadeOut(banner, dur, banner:GetAlpha(), 0)
    C_Timer.After(dur, function()
        -- Skip the hide if we faded back in meanwhile (re-entered a room).
        if banner:GetAlpha() <= 0.05 then
            banner:Hide()
        end
    end)
end
