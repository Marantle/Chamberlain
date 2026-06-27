local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room talking-head box  (RP description, opened from the banner's Read button)
-- ─────────────────────────────────────────────────────────────────────
-- A look-alike of the quest "talking head" frame: a 3D head on the left, the
-- head's name in gold (like the NPC name on Blizzard's box), and the room
-- description below. We render it ourselves with a PlayerModel rather than
-- driving Blizzard's TalkingHeadFrame (that one is fed from quest data and is
-- fragile to repurose). The head model is chosen by zone.headID, an index into
-- CH.HEADS (defined in Core.lua). The box is a fixed, short height. If the text
-- is taller than the viewport it scrolls itself bottom-to-top.

local MODEL_SIZE = 112 -- the head render area; bigger = bigger head
local FRAME_W = 470
local FRAME_H = 144 -- tall enough for the larger head; text scrolls if it overflows
local VIEWPORT_H = 88
local BODY_W = 300
local TEXT_X = 12 + MODEL_SIZE + 12 -- model inset + model + gap
local DEFAULT_SPEED = 8 -- px/s; user-adjustable, persisted in ChamberlainDB.scrollSpeed
local MIN_SPEED, MAX_SPEED, SPEED_STEP = 3, 40, 3
-- Head framing. A bigger MODEL_SIZE makes the head large. Pulling the camera back
-- (lower zoom / higher cam distance) gives lean-forward talk poses room so they
-- don't clip the box. Tune the two values live, then bake them in.
local HEAD_ZOOM = 0.90
local HEAD_CAMDIST = 1.30

CH.talkingHead = CreateFrame("Frame", "ChamberlainTalkingHead", UIParent, "BackdropTemplate")
local th = CH.talkingHead
th:SetSize(FRAME_W, FRAME_H)
th:SetFrameStrata("HIGH")
th:SetAlpha(0)
th:Hide()

local bg = th:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.62)

local lineTop = th:CreateTexture(nil, "BORDER")
lineTop:SetHeight(1)
lineTop:SetPoint("TOPLEFT", th, "TOPLEFT", 10, -8)
lineTop:SetPoint("TOPRIGHT", th, "TOPRIGHT", -10, -8)
lineTop:SetColorTexture(0.85, 0.75, 0.15, 0.90)

local lineBot = th:CreateTexture(nil, "BORDER")
lineBot:SetHeight(1)
lineBot:SetPoint("BOTTOMLEFT", th, "BOTTOMLEFT", 10, 8)
lineBot:SetPoint("BOTTOMRIGHT", th, "BOTTOMRIGHT", -10, 8)
lineBot:SetColorTexture(0.85, 0.75, 0.15, 0.90)

-- 3D head portrait on the left
local model = CreateFrame("PlayerModel", nil, th)
model:SetSize(MODEL_SIZE, MODEL_SIZE)
model:SetPoint("LEFT", th, "LEFT", 12, 0)

-- Camera framing for the head.
local function ApplyHeadFraming()
    model:SetPortraitZoom(HEAD_ZOOM)
    model:SetCamDistanceScale(HEAD_CAMDIST)
end

-- A freshly loaded model reports "loaded" before its camera is ready, so framing
-- it once sits the head too low. Re-apply for a few frames until it catches, then
-- stop.
local function ReframeHead()
    ApplyHeadFraming()
    local n = 0
    if model.reframeTicker then
        model.reframeTicker:Cancel()
    end
    model.reframeTicker = C_Timer.NewTicker(0, function(self)
        ApplyHeadFraming()
        n = n + 1
        if n >= 12 then
            self:Cancel()
            model.reframeTicker = nil
        end
    end)
end

model:SetScript("OnModelLoaded", ReframeHead)
th.model = model

-- True only during the invisible warmup (CH.WarmUpHeadModel). It lets a real
-- yapper opening mid-warmup cancel the warmup teardown instead of being clobbered.
local warming = false

-- The head's name, gold, like the NPC name on Blizzard's talking head. Anchored
-- to the frame (not the floating model) so the text layout is deterministic.
th.name = th:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
th.name:SetPoint("TOPLEFT", th, "TOPLEFT", TEXT_X, -14)
th.name:SetWidth(BODY_W)
th.name:SetJustifyH("LEFT")
th.name:SetWordWrap(false)
th.name:SetTextColor(1.00, 0.92, 0.40, 1)

-- Clipping viewport for the (possibly scrolling) description
local viewport = CreateFrame("Frame", nil, th)
viewport:SetClipsChildren(true)
viewport:SetPoint("TOPLEFT", th.name, "BOTTOMLEFT", 0, -4)
viewport:SetSize(BODY_W, VIEWPORT_H)
th.viewport = viewport

th.body = viewport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
th.body:SetWidth(BODY_W)
th.body:SetJustifyH("LEFT")
th.body:SetJustifyV("TOP")
th.body:SetWordWrap(true)
th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)

-- Close button (returns to the banner), like the X on the quest box
th.close = CreateFrame("Button", nil, th)
th.close:SetSize(18, 18)
th.close:SetPoint("TOPRIGHT", th, "TOPRIGHT", -4, -4)
local closeX = th.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeX:SetAllPoints()
closeX:SetText("|cffFFD700x|r")
th.close:SetScript("OnEnter", function()
    closeX:SetText("|cffFFFFFFx|r")
end)
th.close:SetScript("OnLeave", function()
    closeX:SetText("|cffFFD700x|r")
end)

-- Small gold glyph buttons stacked under the close X: live scroll-speed control.
local function MakeMiniButton(glyph, yOff, tip, onClick)
    local b = CreateFrame("Button", nil, th)
    b:SetSize(18, 18)
    b:SetPoint("TOPRIGHT", th, "TOPRIGHT", -4, yOff)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetText("|cffFFD700" .. glyph .. "|r")
    b:SetScript("OnEnter", function(self)
        fs:SetText("|cffFFFFFF" .. glyph .. "|r")
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 0.85, 0.25)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        fs:SetText("|cffFFD700" .. glyph .. "|r")
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    return b
end

th.faster = MakeMiniButton("+", -26, CH.L["TH_SCROLL_FASTER"], function()
    ChamberlainDB.scrollSpeed = math.min(MAX_SPEED, (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) + SPEED_STEP)
end)
th.slower = MakeMiniButton("-", -46, CH.L["TH_SCROLL_SLOWER"], function()
    ChamberlainDB.scrollSpeed = math.max(MIN_SPEED, (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) - SPEED_STEP)
end)

CH.ApplyTalkingHeadPos = CH.MakeMovablePersistent(th, "thX", "thY")

-- ── Auto-scroll ──────────────────────────────────────────────────────
-- The body translates upward inside the clipping viewport: it starts just below
-- the bottom edge and rises until fully above the top, then loops. Only runs
-- when the text is taller than the viewport. Short text sits static at the top.
local scrollDY, scrollBH

local function ScrollUpdate(_, elapsed)
    scrollDY = scrollDY + (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) * elapsed
    if scrollDY > scrollBH then
        -- The last line has scrolled off the top, so close the yapper
        -- and bring the banner back instead of looping.
        CH.CloseYapper()
        return
    end
    th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, scrollDY)
end

local function SetupScroll()
    scrollBH = th.body:GetStringHeight()
    th.body:ClearAllPoints()
    if scrollBH > VIEWPORT_H then
        scrollDY = -VIEWPORT_H -- start just below the viewport, scroll up
        th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, scrollDY)
        th:SetScript("OnUpdate", ScrollUpdate)
        th.faster:Show()
        th.slower:Show() -- speed controls only matter while scrolling
    else
        th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
        th:SetScript("OnUpdate", nil)
        th.faster:Hide()
        th.slower:Hide()
    end
end

-- ── Yapping animation ────────────────────────────────────────────────
-- Cycle through talk animations while shown, idle on hide. The exact IDs vary
-- per model rig: 60 EmoteTalk, 64 EmoteTalkExclamation, 65 EmoteTalkQuestion.
local TALK_ANIMS = { 60, 64, 65 }
local yapTicker

local function StartYap()
    if yapTicker then
        yapTicker:Cancel()
    end
    model:SetAnimation(TALK_ANIMS[math.random(#TALK_ANIMS)])
    yapTicker = C_Timer.NewTicker(2.5, function()
        model:SetAnimation(TALK_ANIMS[math.random(#TALK_ANIMS)])
    end)
end

local function StopYap()
    if yapTicker then
        yapTicker:Cancel()
        yapTicker = nil
    end
    model:SetAnimation(0)
end

-- True if the party/raid unit is the named owner. UnitName gives (name, realm).
-- h.owner comes from C_Housing's ownerName and can be a bare name or "Name-Realm",
-- so check both forms. Comparing UnitName("player") to owner directly is unreliable
-- becuase ownerName can carry a realm suffix that the player name never has.
local function UnitMatchesOwner(unit, owner)
    local name, realm = UnitName(unit)
    if not name then
        return false
    end -- nil for a non-existent unit
    if name == owner then
        return true
    end
    return realm and realm ~= "" and (name .. "-" .. realm) == owner
end

-- Resolve the current house's owner to a renderable unit, or nil. Their own
-- character only shows if it's you, or a group member in range/visible (so the
-- client has their model loaded). Returns unit, displayName.
local function ResolveOwnerUnit()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local owner = h and h.owner
    -- Your own house: server-checked, account-aware, cross-realm safe. This is the
    -- real ownership answer, so don't gate "is this me" on a name match.
    if CH.isOwnHouse then
        return "player", owner or UnitName("player")
    end
    -- Saved name/GUID only match the character that made the room. CH.liveOwners
    -- tracks the owner across alts, so prefer it, then fall back to the saved ones.
    if not IsInGroup() then
        return nil
    end
    local guid = h and h.ownerGUID
    local live = CH.liveOwners and CH.currentHouseGUID and CH.liveOwners[CH.currentHouseGUID]
    local liveGUID = live and live.guid
    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and 40 or 4
    for i = 1, count do
        local u = prefix .. i
        if UnitIsVisible(u) then
            local ug = UnitGUID(u)
            if liveGUID and ug == liveGUID then
                return u, UnitName(u)
            elseif guid and ug == guid then
                return u, UnitName(u)
            elseif not guid and not liveGUID and owner and UnitMatchesOwner(u, owner) then
                return u, owner
            end
        end
    end
    return nil
end

-- Room open in the yapper, so a late owner ping can swap in the live model.
local shownZone

function CH.ShowTalkingHead(zone)
    warming = false -- a real open takes over from any warmup
    shownZone = zone
    model:SetSize(MODEL_SIZE, MODEL_SIZE) -- restore size if the warmup shrank it
    local head = CH.HEADS[zone.headID or 1] or CH.HEADS[1]
    th:Show() -- the model needs the frame shown to load

    -- Optionally show the house owner's own character instead of a curated head,
    -- when the room is flagged (zone.useOwnerHead) and the owner is reachable
    -- (you, or a visible group member). Otherwise fall back to curated / custom ID.
    local ownerName, ownerGender
    if zone.useOwnerHead then
        local unit, name = ResolveOwnerUnit()
        if unit then
            model:SetUnit(unit)
            ownerName = name
            local sex = UnitSex(unit) -- 2 = male, 3 = female, 1 = unknown
            ownerGender = (sex == 3 and "female") or (sex == 2 and "male") or nil
        elseif not CH.isOwnHouse and CH.RequestOwnerPresence then
            CH.RequestOwnerPresence(CH.currentHouseGUID) -- ask the owner to announce
        end
    end
    if not ownerName then
        local display = zone.headDisplay or (head and head.display) -- custom ID overrides
        if display then
            model:SetDisplayInfo(display)
        end
    end
    ReframeHead() -- frame now and re-apply across the next frames (cold-load fix)
    StartYap()

    th.name:SetText(zone.speaker or ownerName or (head and head.name) or "")
    th.body:SetText(zone.rpText or "")
    SetupScroll() -- best-effort now...
    C_Timer.After(0, SetupScroll) -- ...and again once the text has wrapped

    -- Read the description aloud. In your own house this uses the room's own voice
    -- pick, or nothing if none. In a house you're visiting the room carries no
    -- voice, so it falls back to your personal default for the head's gender when
    -- enabled. See CH.ResolveZoneVoice.
    CH.Speak(zone.rpText, CH.ResolveZoneVoice(zone, CH.isOwnHouse, ownerGender))

    UIFrameFadeIn(th, 0.5, th:GetAlpha(), 1)
end

-- Owner just announced. Swap their live model into the open yapper.
function CH.OnLiveOwnerUpdate(houseGUID)
    if not th:IsShown() or not shownZone or not shownZone.useOwnerHead then
        return
    end
    if houseGUID ~= CH.currentHouseGUID then
        return
    end
    local unit, name = ResolveOwnerUnit()
    if unit then
        model:SetUnit(unit)
        ReframeHead()
        th.name:SetText(shownZone.speaker or name or "")
    end
end

function CH.HideTalkingHead()
    if not th:IsShown() then
        return
    end
    shownZone = nil
    CH.StopSpeaking() -- cut narration when the yapper closes
    StopYap()
    if model.reframeTicker then
        model.reframeTicker:Cancel()
        model.reframeTicker = nil
    end
    th:SetScript("OnUpdate", nil)
    -- 3D models ignore frame alpha, so a fade-out would leave the head floating
    -- until the frame hides. Clear the model and hide outright. Reset alpha so the
    -- next ShowTalkingHead still fades in cleanly.
    model:ClearModel()
    th:Hide()
    th:SetAlpha(0)
end

-- Open the yapper for the room the banner is currently showing.
function CH.OpenYapper()
    local zone = CH.bannerRoom
    if not zone or not zone.rpText or zone.rpText == "" then
        return
    end
    CH.HideBanner(0.3)
    CH.ShowTalkingHead(zone)
end

-- Close the yapper and bring the room banner back (if still in a room).
function CH.CloseYapper()
    CH.HideTalkingHead()
    if CH.bannerRoom then
        CH.ShowBanner(0.3)
    end
end

-- One-time warmup. The first paint of this model frame always frames low, so
-- render it once shrunk to a single pixel (invisible) to pay that cost up front;
-- the first real yapper is then past it. It must be this exact frame, a throwaway
-- model wouldn't help. Called from CH.CheckHousingState the first time you're
-- inside a house.
local warmedUp = false
function CH.WarmUpHeadModel()
    if warmedUp or th:IsShown() then
        return
    end
    warmedUp = true
    warming = true
    model:SetSize(1, 1) -- one pixel: the frame still does its first-paint setup, unseen
    th:SetAlpha(0)
    th:Show()
    model:SetDisplayInfo(CH.HEADS[1].display)
    ReframeHead()
    C_Timer.After(1.5, function()
        if not warming then
            return
        end -- a real yapper took over; leave it alone
        warming = false
        if model.reframeTicker then
            model.reframeTicker:Cancel()
            model.reframeTicker = nil
        end
        model:ClearModel()
        model:SetSize(MODEL_SIZE, MODEL_SIZE)
        th:Hide()
        th:SetAlpha(0)
    end)
end

th.close:SetScript("OnClick", CH.CloseYapper)
