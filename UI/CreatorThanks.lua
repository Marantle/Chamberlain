local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Creator thanks scene  (opened from the settings window)
-- ─────────────────────────────────────────────────────────────────────
-- A little stage. Lord Chamberlain introduces the creator, turns and walks
-- off through the left edge while the creator walks in from the right to say
-- their thanks. No client can conjure another player's body, so the scene
-- borrows the viewer's own character and dresses it in the creator's clothes.
-- The speech owns up to the trick.

local INTRO_SECS = 8
local WALK_FACING = -math.pi / 2 -- side profile, facing the way they move
local WALK_SPEED = 140 -- px/s, matched to the walk gait by eye
-- The butler model hangs left of his frame facing front and swings right in
-- profile (the rig pivot is not the silhouette center), so the frame counter
-- nudges per pose. Both in px, tuned by eye.
local INTRO_NUDGE = 80
local WALK_NUDGE = -80
local TALK_ANIMS = { 60, 64, 65 } -- talk, exclaim, question, as in the yapper
local SCROLL_SPEED = 12 -- px/s, the speech crawl (the yapper's setting is too personal here)

-- Rothirr's look as worn on the live character, per slot: appearance,
-- secondary appearance, illusion. The shoulder id repeats because the two
-- sides render on their own.
local CREATOR_TRANSMOG = {
    [1] = { 8698, 0, 0 },
    [3] = { 8700, 8700, 0 },
    [5] = { 8701, 0, 0 },
    [6] = { 8696, 0, 0 },
    [7] = { 8703, 0, 0 },
    [8] = { 8702, 0, 0 },
    [9] = { 8697, 0, 0 },
    [10] = { 8699, 0, 0 },
    [15] = { 89419, 0, 0 },
    [16] = { 7416, -1, 0 },
    [19] = { 12730, 0, 0 },
}

local WIN_W, WIN_H = 560, 640

local win = CreateFrame("Frame", "ChamberlainCreatorThanks", UIParent, "BackdropTemplate")
win:SetSize(WIN_W, WIN_H)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:SetPoint("CENTER")
CH.MakeDraggable(win)
CH.SkinWindow(win, "CT_WINDOW_TITLE")
win:Hide()
table.insert(UISpecialFrames, "ChamberlainCreatorThanks")

-- Gold name banner over the stage, same look as the room banner.
local BANNER_PAD = 22
local BANNER_MIN_W = 180

local banner = CreateFrame("Frame", nil, win)
banner:SetSize(BANNER_MIN_W, 40)
banner:SetPoint("TOP", win, "TOP", 0, -30)

local bannerBg = banner:CreateTexture(nil, "BACKGROUND")
bannerBg:SetAllPoints()
bannerBg:SetColorTexture(0, 0, 0, 0.52)

local bannerLineTop = banner:CreateTexture(nil, "BORDER")
bannerLineTop:SetHeight(1)
bannerLineTop:SetPoint("TOPLEFT", banner, "TOPLEFT", 10, -7)
bannerLineTop:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -10, -7)
bannerLineTop:SetColorTexture(CH.RGBA(CH.COLORS.line, 0.90))

local bannerLineBot = banner:CreateTexture(nil, "BORDER")
bannerLineBot:SetHeight(1)
bannerLineBot:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 10, 7)
bannerLineBot:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -10, 7)
bannerLineBot:SetColorTexture(CH.RGBA(CH.COLORS.line, 0.90))

local bannerText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
bannerText:SetPoint("CENTER")
bannerText:SetTextColor(CH.RGBA(CH.COLORS.bannerText, 1))

local function SetBannerName(key)
    bannerText:SetText(CH.L[key])
    banner:SetWidth(math.max(BANNER_MIN_W, bannerText:GetStringWidth() + BANNER_PAD * 2))
end

-- Clipping stage so an actor can slide out through the edge and vanish
-- instead of drawing past the window.
local stage = CreateFrame("Frame", nil, win)
stage:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -78)
stage:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 210)
stage:SetClipsChildren(true)

-- Only ever one speaker at a time. SetAnimation is dropped by a model that is
-- still loading, so the speaker's OnModelLoaded replays the pose (the butler
-- otherwise stood idle until the ticker's first swap).
local talkTicker, speaker

local function TalkPose()
    speaker:SetAnimation(TALK_ANIMS[math.random(#TALK_ANIMS)])
end

local function StartTalk(m)
    if talkTicker then
        talkTicker:Cancel()
    end
    speaker = m
    TalkPose()
    talkTicker = C_Timer.NewTicker(2.5, TalkPose)
end

local function StopTalk()
    speaker = nil
    if talkTicker then
        talkTicker:Cancel()
        talkTicker = nil
    end
end

-- A model re-applies its camera for a few frames after load, else the first
-- animation change pops the framing. Same fix as the yapper's head.
local function MakeActor()
    local m = CreateFrame("DressUpModel", nil, stage)
    m:SetSize(420, 350)
    m:SetPoint("CENTER")
    local function ApplyFraming()
        m:SetPortraitZoom(0)
        m:SetCamDistanceScale(1.05)
    end
    m.Reframe = function()
        ApplyFraming()
        if m.reframeTicker then
            m.reframeTicker:Cancel()
        end
        local n = 0
        m.reframeTicker = C_Timer.NewTicker(0, function(t)
            ApplyFraming()
            n = n + 1
            if n >= 12 then
                t:Cancel()
                m.reframeTicker = nil
            end
        end)
    end
    m:SetScript("OnModelLoaded", function()
        m.Reframe()
        if m == speaker then
            TalkPose()
        end
    end)
    return m
end

local actorA = MakeActor() -- Lord Chamberlain
local actorB = MakeActor() -- the borrowed viewer
local ACTORS = { actorA, actorB }

-- Speech text under the stage. The intro sits still. A speech taller than the
-- viewport rolls in from below like credits, every line passing through view,
-- and parks on its last lines instead of looping.
local viewport = CreateFrame("Frame", nil, win)
viewport:SetClipsChildren(true)
viewport:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -438)
viewport:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 40)

local body = viewport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body:SetWidth(WIN_W - 32)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")
body:SetWordWrap(true)
body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)

local scrollDY, scrollMax
local scrollToken = 0 -- invalidates pending crawl timers when the text changes

local function ScrollUpdate(_, elapsed)
    scrollDY = scrollDY + SCROLL_SPEED * elapsed
    if scrollDY >= scrollMax then
        scrollDY = scrollMax
        win:SetScript("OnUpdate", nil)
    end
    body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, scrollDY)
end

local function ShowText(key, scrolled)
    win:SetScript("OnUpdate", nil)
    scrollToken = scrollToken + 1
    local token = scrollToken
    body:SetText(CH.L[key])
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    if not scrolled then
        return
    end
    C_Timer.After(0, function() -- measure once the text has wrapped
        local overflow = body:GetStringHeight() - viewport:GetHeight()
        if overflow <= 0 or token ~= scrollToken or not win:IsShown() then
            return
        end
        -- start with the first line at the bottom edge, hidden, and rise
        scrollDY, scrollMax = -viewport:GetHeight(), overflow
        body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, scrollDY)
        win:SetScript("OnUpdate", ScrollUpdate)
    end)
end

-- The handoff: both actors walk left one stage width, the butler out through
-- the edge, the creator in from beyond the right edge onto center.
local slideX

local function SlideUpdate(_, elapsed)
    local width = stage:GetWidth()
    slideX = slideX - WALK_SPEED * elapsed
    actorA:SetPoint("CENTER", stage, "CENTER", slideX + WALK_NUDGE, 0)
    actorB:SetPoint("CENTER", stage, "CENTER", slideX + width, 0)
    if slideX <= -width then
        stage:SetScript("OnUpdate", nil)
        actorA:ClearModel()
        actorA:Hide()
        actorB:SetPoint("CENTER", stage, "CENTER", 0, 0)
        actorB:SetFacing(0)
        SetBannerName("CT_CREATOR_NAME")
        StartTalk(actorB)
        ShowText("CT_SPEECH", true)
        -- read aloud with the viewer's masculine voice pick (the speaker is
        -- Rothirr), falling back like a shared room does
        local s = ChamberlainDB.settings
        local voice = s.voiceDefaultsEnabled and (s.voiceMale or s.voiceFemale)
        if voice then
            CH.Speak(CH.L["CT_SPEECH"], voice)
        end
    end
end

local handoffTimer

local function Handoff()
    handoffTimer = nil
    StopTalk()
    -- pin the camera through the animation swap, else the model refits
    -- itself larger the moment the walk starts
    for _, m in ipairs(ACTORS) do
        m:SetFacing(WALK_FACING)
        m:SetAnimation(4)
        m.Reframe()
    end
    slideX = 0
    stage:SetScript("OnUpdate", SlideUpdate)
end

function CH.CloseCreatorThanks()
    if handoffTimer then
        handoffTimer:Cancel()
        handoffTimer = nil
    end
    StopTalk()
    CH.StopSpeaking()
    stage:SetScript("OnUpdate", nil)
    win:SetScript("OnUpdate", nil)
    for _, m in ipairs(ACTORS) do
        if m.reframeTicker then
            m.reframeTicker:Cancel()
            m.reframeTicker = nil
        end
        m:ClearModel()
        m:Hide()
    end
    win:Hide()
end

function CH.OpenCreatorThanks()
    CH.CloseCreatorThanks() -- reset any half-played scene
    win:Show()
    actorA:Show()
    actorA:SetPoint("CENTER", stage, "CENTER", INTRO_NUDGE, 0)
    actorA:SetDisplayInfo(CH.HEADS[1].display)
    -- Facing sticks to the frame across model loads, so without this a replay
    -- starts both actors in last time's walk profile.
    actorA:SetFacing(0)
    actorA.Reframe()
    -- The stand-in loads and dresses beyond the right edge while the buttler
    -- has the floor.
    actorB:Show()
    actorB:SetPoint("CENTER", stage, "CENTER", stage:GetWidth(), 0)
    actorB:SetUnit("player")
    actorB:SetFacing(0)
    C_Timer.After(0.4, function()
        if not win:IsShown() then
            return
        end
        actorB:Undress()
        for slot, t in pairs(CREATOR_TRANSMOG) do
            actorB:SetItemTransmogInfo(ItemUtil.CreateItemTransmogInfo(t[1], t[2], t[3]), slot)
        end
        -- weapon on the back, a speech is no place to brandish it
        actorB:SetSheathed(true)
    end)
    SetBannerName("CT_INTRO_NAME")
    ShowText("CT_INTRO_TEXT", false)
    StartTalk(actorA)
    handoffTimer = C_Timer.NewTimer(INTRO_SECS, Handoff)
    UIFrameFadeIn(win, 0.4, 0, 1)
end

-- ESC closes via UISpecialFrames, route it through the full cleanup
win:SetScript("OnHide", CH.CloseCreatorThanks)

local closeBtn = CH.MakeButton(win, "RM_CLOSE", 80, 22)
closeBtn:SetPoint("BOTTOM", win, "BOTTOM", 0, 10)
closeBtn:SetScript("OnClick", CH.CloseCreatorThanks)
