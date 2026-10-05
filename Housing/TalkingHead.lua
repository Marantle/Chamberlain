local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room talking-head box  (RP description, opened from the banner's Read button)
-- ─────────────────────────────────────────────────────────────────────
-- Since 3.42.0 the card hangs under the room banner as one piece with it: a
-- dark strip with gold lines, both fading out at the ends like the quest
-- talking head. The banner names the room and the strip the speaker, with
-- the 3D head or a decor floating on the left. Words alone drop the face, and
-- the name too unless a speaker was typed. We render it ourselves rather than
-- driving Blizzard's TalkingHeadFrame (that one is fed from quest data and is
-- fragile to repurose). The head model is chosen by zone.headID, an index
-- into CH.HEADS (defined in Core.lua), the decor by zone.decor, a decor
-- record in the housing catalog. The strip is a fixed, short height. If the
-- text is taller than the viewport it scrolls itself bottom-to-top.

local MODEL_SIZE = 104 -- the head render area; bigger = bigger head
local FRAME_W = 540
local FRAME_H = 132 -- tall enough for the head; text scrolls if it overflows
local FACE_X = 40
local EDGE = 70 -- the text keeps this far from both ends, clear of the fade and the buttons
local TOP, BOTTOM = 16, 14
local NAME_H = 26
local DEFAULT_SPEED = 8 -- px/s; user-adjustable, persisted in ChamberlainDB.scrollSpeed
local MIN_SPEED, MAX_SPEED, SPEED_STEP = 3, 40, 3
-- Head framing. A bigger MODEL_SIZE makes the head large. Pulling the camera back
-- (lower zoom / higher cam distance) gives lean-forward talk poses room so they
-- don't clip the box. Tune the two values live, then bake them in.
local HEAD_ZOOM = 0.90
local HEAD_CAMDIST = 1.30

local MORPHEUS = QuestFont_Huge:GetFont()

-- ── Decor ────────────────────────────────────────────────────────────
-- A decor's catalog entry by its record, nil for a record the catalog
-- doesn't know (a typo on the wire, or not loaded yet).
function CH.DecorInfo(record)
    return record and C_HousingCatalog.GetCatalogEntryInfoByRecordID(Enum.HousingCatalogEntryType.Decor, record)
end

-- What a room's card shows beside its words: "head", "decor" or "text" for
-- the words alone. Only the fields count here. The card itself still falls
-- back to the head for a decor the catalog can't find, see Face.
function CH.StoryMode(zone)
    if zone.noPortrait then
        return "text"
    end
    return zone.decor and "decor" or "head"
end

-- The face a room's card shows: "head", "decor" or nil for words alone.
local function Face(zone)
    local mode = CH.StoryMode(zone)
    if mode == "text" then
        return nil
    end
    return mode == "decor" and CH.DecorInfo(zone.decor) and "decor" or "head"
end

-- The name the card shows when the speaker is left empty, the head's or the
-- decor's. Words alone show none, since the banner over them names the room.
function CH.StoryName(zone)
    local face = Face(zone)
    if face == "decor" then
        return CH.DecorInfo(zone.decor).name
    elseif face == "head" then
        return (CH.HEADS[zone.headID or 1] or CH.HEADS[1]).name
    end
end

-- A decor in a small model scene, the one the catalog's tiles use, which
-- fits big pieces and small to the same square. The model goes first and a
-- decor with none shows its catalog icon (the tiles show the icon first).
-- scene:SetDecor(record) hands back the catalog info.
local DECOR_SCENE = 691 -- the catalog tiles' scene, its actor is tagged "decor"

function CH.MakeDecorModel(parent)
    local scene = CreateFrame("ModelScene", nil, parent, "NonInteractableModelSceneMixinTemplate")
    local icon = scene:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("CENTER")
    icon:Hide()
    -- The scene is set up once like a tile's, and after that only the model
    -- changes. Building it again on every page of Find decor costs.
    local staged = false
    function scene.ClearDecor(_)
        local actor = scene:GetActorByTag("decor")
        if actor then
            actor:ClearModel()
        end
        icon:Hide()
    end
    function scene.SetDecor(_, record)
        local info = CH.DecorInfo(record)
        local actor
        if info and info.asset then
            if not staged then
                scene:TransitionToModelSceneID(
                    DECOR_SCENE,
                    CAMERA_TRANSITION_TYPE_IMMEDIATE,
                    CAMERA_MODIFICATION_TYPE_DISCARD,
                    true
                )
                staged = true
            end
            actor = scene:GetActorByTag("decor")
        end
        if actor then
            actor:SetPreferModelCollisionBounds(true)
            actor:SetModelByFileID(info.asset)
            icon:Hide()
            return info
        end
        scene:ClearDecor()
        if info then
            if info.iconAtlas then
                icon:SetAtlas(info.iconAtlas)
            else
                icon:SetTexture(info.iconTexture)
            end
            icon:Show()
        end
        return info
    end
    return scene
end

-- ── The strip ────────────────────────────────────────────────────────

CH.talkingHead = CreateFrame("Frame", "ChamberlainTalkingHead", UIParent)
local th = CH.talkingHead
th:SetSize(FRAME_W, FRAME_H)
th:SetFrameStrata("HIGH")
th:SetAlpha(0)
th:Hide()

-- A band of colour c at alpha a in layer, inset px in from the sides, that
-- fades in over fade px at each end. With edge it's a 1 px line y off that
-- edge, else it fills the strip's height. Straight on th so the layers
-- settle which draws over which.
local function FadeBand(layer, c, a, fade, inset, edge, y)
    local left, mid, right = th:CreateTexture(nil, layer), th:CreateTexture(nil, layer), th:CreateTexture(nil, layer)
    for _, t in ipairs({ left, mid, right }) do
        t:SetColorTexture(1, 1, 1, 1)
    end
    local v = edge or "TOP"
    left:SetPoint(v .. "LEFT", inset, y or 0)
    right:SetPoint(v .. "RIGHT", -inset, y or 0)
    if edge then
        left:SetHeight(1)
        right:SetHeight(1)
    else
        left:SetPoint("BOTTOMLEFT", inset, 0)
        right:SetPoint("BOTTOMRIGHT", -inset, 0)
    end
    left:SetWidth(fade)
    right:SetWidth(fade)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local clear, full = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], a)
    left:SetGradient("HORIZONTAL", clear, full)
    right:SetGradient("HORIZONTAL", full, clear)
    mid:SetVertexColor(c[1], c[2], c[3], a)
end

FadeBand("BACKGROUND", { 0, 0, 0 }, 0.68, 70, 0)
FadeBand("BORDER", CH.COLORS.line, 0.9, 90, 24, "TOP", -6)
FadeBand("BORDER", CH.COLORS.line, 0.9, 90, 24, "BOTTOM", 6)

-- The face floats on the strip with no frame, a head or a decor.
local model = CreateFrame("PlayerModel", nil, th)
model:SetSize(MODEL_SIZE, MODEL_SIZE)
model:SetPoint("LEFT", FACE_X, 0)

local decor = CH.MakeDecorModel(th)
decor:SetAllPoints(model)
decor:Hide()

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

-- The speaker's name in the plaque's lettering. The banner above names the
-- room.
th.name = th:CreateFontString(nil, "OVERLAY")
th.name:SetFont(MORPHEUS, 19, "")
th.name:SetShadowOffset(2, -2)
th.name:SetShadowColor(0, 0, 0, 1)
th.name:SetHeight(NAME_H - 4)
th.name:SetWordWrap(false)
th.name:SetTextColor(CH.RGBA(CH.COLORS.bannerText, 1))

-- Clipping viewport for the (possibly scrolling) description
local viewport = CreateFrame("Frame", nil, th)
viewport:SetClipsChildren(true)
th.viewport = viewport
local viewH -- the viewport's height, less while a name takes the top line

th.body = viewport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
th.body:SetJustifyV("TOP")
th.body:SetWordWrap(true)
th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)

-- Close button (returns to the banner), like the X on the quest box
th.close = CreateFrame("Button", nil, th)
th.close:SetSize(18, 18)
th.close:SetPoint("TOPRIGHT", th, "TOPRIGHT", -24, -10)
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
local function MakeMiniButton(glyph, yOff, tipKey, onClick)
    local b = CreateFrame("Button", nil, th)
    b:SetSize(18, 18)
    b:SetPoint("TOPRIGHT", th, "TOPRIGHT", -24, yOff)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetText("|cffFFD700" .. glyph .. "|r")
    b:SetScript("OnEnter", function(self)
        fs:SetText("|cffFFFFFF" .. glyph .. "|r")
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CH.L[tipKey], 1, 0.85, 0.25)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        fs:SetText("|cffFFD700" .. glyph .. "|r")
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    return b
end

th.faster = MakeMiniButton("+", -32, "TH_SCROLL_FASTER", function()
    ChamberlainDB.scrollSpeed = math.min(MAX_SPEED, (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) + SPEED_STEP)
end)
th.slower = MakeMiniButton("-", -52, "TH_SCROLL_SLOWER", function()
    ChamberlainDB.scrollSpeed = math.max(MIN_SPEED, (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) - SPEED_STEP)
end)

-- The strip hangs under the banner and moves with it, or comes loose with
-- the lock and goes where it's dragged (settings.yapperLoose, each player's
-- own choice, thX and thY its spot). Hanging with no banner up, a tour's
-- welcome or banners turned off, it takes the banner's place.
local PutLoose = CH.MakeMovablePersistent(th, "thX", "thY")

local function Loose()
    return ChamberlainDB.settings.yapperLoose == true
end

function CH.ApplyTalkingHeadPos()
    th:EnableMouse(Loose())
    if Loose() then
        PutLoose()
        return
    end
    th:ClearAllPoints()
    if CH.bannerRoom and CH.banner:IsShown() then
        th:SetPoint("TOP", CH.banner, "BOTTOM", 0, -2)
    else
        th:SetPoint("TOP", CH.banner, "TOP")
    end
end

-- The lock beside the close X, shut while the strip hangs under the banner
-- and open once it's loose. It comes loose right where it hangs, so nothing
-- jumps.
local latch = CH.MakeGlyphButton(th, nil, "icon-lock")
latch:SetPoint("RIGHT", th.close, "LEFT", -4, 0)
CH.TipText(latch, function()
    return CH.L[Loose() and "TH_ATTACH" or "TH_DETACH"]
end)
local function ShowLatch()
    CH.SetIconFile(latch.glyph, Loose() and "icon-unlock" or "icon-lock")
end
latch:SetScript("OnClick", function()
    if not Loose() then
        local cx, cy = UIParent:GetCenter()
        local fx, fy = th:GetCenter()
        ChamberlainDB.thX, ChamberlainDB.thY = fx - cx, fy - cy
    end
    ChamberlainDB.settings.yapperLoose = not Loose() or nil
    CH.ApplyTalkingHeadPos()
    ShowLatch()
end)
latch:SetScript("OnShow", ShowLatch)

-- ── Auto-scroll ──────────────────────────────────────────────────────
-- The body translates upward inside the clipping viewport: it starts just below
-- the bottom edge and rises until fully above the top, then loops. Only runs
-- when the text is taller than the viewport. Short text sits static at the top.
local scrollDY, scrollBH

-- The text can be held with the mouse and dragged up or down. Let go and it
-- scrolls on from there. While held it follows the cursor instead of the
-- clock, in the same OnUpdate. grabY and grabDY are where the drag began.
local grabY, grabDY

local function CursorY()
    local _, y = GetCursorPosition()
    return y / viewport:GetEffectiveScale()
end

local function ScrollUpdate(_, elapsed)
    if grabY then
        -- up to just short of the end, a drag never closes the yapper
        scrollDY = math.max(-viewH, math.min(scrollBH - 1, grabDY + CursorY() - grabY))
    else
        scrollDY = scrollDY + (ChamberlainDB.scrollSpeed or DEFAULT_SPEED) * elapsed
    end
    if scrollDY > scrollBH then
        -- The last line has scrolled off the top, so close the yapper
        -- and bring the banner back instead of looping.
        CH.CloseYapper()
        return
    end
    th.body:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, scrollDY)
end

-- The text takes the mouse only while it scrolls.
viewport:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
        grabY, grabDY = CursorY(), scrollDY
    end
end)
viewport:SetScript("OnMouseUp", function()
    grabY = nil
end)
viewport:SetScript("OnHide", function()
    grabY = nil
end)

local function SetupScroll()
    scrollBH = th.body:GetStringHeight()
    th.body:ClearAllPoints()
    grabY = nil
    viewport:EnableMouse(scrollBH > viewH)
    if scrollBH > viewH then
        scrollDY = -viewH -- start just below the viewport, scroll up
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

-- A custom head has no name of its own, so the head grid calls it by the
-- speaker of the first room in zones that wears it with one (3.41.0). Each
-- room keeps its own speaker and nothing is renamed. nil for none.
function CH.CustomHeadName(zones, display)
    for _, z in ipairs(zones or {}) do
        if z.headDisplay == display and z.speaker then
            return z.speaker
        end
    end
end

-- Room open in the yapper, so a late owner ping can swap in the live model.
local shownZone

-- The head or the decor on the left with the text beside it, or words alone
-- centred across the strip.
local textX
local function Arrange(face)
    model:SetShown(face == "head")
    decor:SetShown(face == "decor")
    textX = face and FACE_X + MODEL_SIZE + 16 or EDGE
    local w = FRAME_W - textX - EDGE
    local justify = face and "LEFT" or "CENTER"
    th.name:SetWidth(w)
    th.name:SetJustifyH(justify)
    viewport:SetWidth(w)
    th.body:SetWidth(w)
    th.body:SetJustifyH(justify)
end

-- The name takes the top line when there is one, and the words start
-- under it or at the top.
local function SetName(text)
    th.name:SetText(text or "")
    th.name:SetShown(text ~= nil)
    th.name:ClearAllPoints()
    th.name:SetPoint("TOPLEFT", textX, -TOP)
    local nameH = text and NAME_H or 0
    viewH = FRAME_H - TOP - BOTTOM - nameH
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", textX, -TOP - nameH)
    viewport:SetHeight(viewH)
end

-- Put zone's face on the strip, a head starting to talk. Hands back the
-- owner's name and gender when it's the owner's own character. quiet skips
-- asking the owner to announce, for a face that's only put back.
local function PutHead(zone, quiet)
    local face = Face(zone)
    if face ~= "head" then
        StopYap()
        if face == "decor" then
            decor:SetDecor(zone.decor)
        end
        return
    end
    local head = CH.HEADS[zone.headID or 1] or CH.HEADS[1]
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
        elseif not quiet and not CH.isOwnHouse and CH.RequestOwnerPresence then
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
    return ownerName, ownerGender
end

-- Hide UI hides the models for a moment before Showcase carries the box on,
-- and a model hidden comes back blank, so the open room's face goes back on.
-- A real open sets shownZone only after its Show, so this skips it.
local function PutBack()
    if shownZone and not warming then
        PutHead(shownZone, true)
    end
end
model:SetScript("OnShow", PutBack)
decor:HookScript("OnShow", PutBack)

function CH.ShowTalkingHead(zone)
    warming = false -- a real open takes over from any warmup
    shownZone = nil -- the last room's face isn't put back while this one arranges
    model:SetSize(MODEL_SIZE, MODEL_SIZE) -- restore size if the warmup shrank it
    Arrange(Face(zone))
    CH.ApplyTalkingHeadPos()
    th:Show() -- the model needs the frame shown to load
    shownZone = zone
    local ownerName, ownerGender = PutHead(zone)

    SetName(zone.speaker or ownerName or CH.StoryName(zone))
    th.body:SetText(zone.rpText or "")
    SetupScroll() -- best-effort now...
    C_Timer.After(0, SetupScroll) -- ...and again once the text has wrapped

    -- Read the description aloud, in the room's own voice pick or else your
    -- personal default for the head's gender when enabled. See
    -- CH.ResolveZoneVoice.
    CH.Speak(zone.rpText, CH.ResolveZoneVoice(zone, ownerGender))

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
    if unit and Face(shownZone) == "head" then
        model:SetUnit(unit)
        ReframeHead()
        SetName(shownZone.speaker or name)
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
    -- until the frame hides. Clear the models and hide outright. Reset alpha so the
    -- next ShowTalkingHead still fades in cleanly.
    model:ClearModel()
    decor:ClearDecor()
    th:Hide()
    th:SetAlpha(0)
end

-- The banner's book opens the yapper under it for the room it shows, and
-- closes it again.
function CH.OpenYapper()
    if th:IsShown() then
        CH.CloseYapper()
        return
    end
    local zone = CH.bannerRoom
    if not zone or not zone.rpText or zone.rpText == "" then
        return
    end
    -- a banner already fading out on its timer comes back to hold the strip
    CH.ShowBanner(0.2)
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
