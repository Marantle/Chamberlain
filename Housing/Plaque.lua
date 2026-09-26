local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- House plaque  (shown once as you walk into a house)
-- ─────────────────────────────────────────────────────────────────────
-- The house's name, big and glowing, with whose house it is and the owner's
-- motto under it. Any house, held or not, since the name and the owner come
-- from the game on the way in. The owner can give the house a name of their
-- own (h.plaqueName, 3.23.0) that goes over the game's. It and the motto ride
-- the map, and so does the game's name of a house you never visited
-- (h.houseName). It stays up PLAQUE_SECONDS and fades, or goes at once when
-- you leave.

local PLAQUE_SECONDS = 7
local MIN_W, MAX_TEXT = 320, 440
local PAD = 36

-- The owner's two lines of text and how many letters the panel takes for
-- each. The key is the field on the house and the patch kind both.
CH.HOUSE_TEXT = { plaqueName = 40, motto = 80 }
-- A text goes out as a patch only while it fits a message beside the house key.
local PATCH_BYTES = 180

-- One line of the owner's, trimmed, nil for none. The game's | codes
-- (textures, links) go, since a hand-made string could carry them, and so
-- does a pasted line break. letters caps it in bytes, and a letter can be up
-- to four of them, so there is room for that many letters of any kind.
function CH.CleanText(s, letters)
    if type(s) ~= "string" then
        return nil
    end
    s = string.sub(s:gsub("[|\r\n]", ""), 1, letters * 4):match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end

-- The name the game gave the house. Standing in it that one is fresh, where a
-- copy of the map can be behind.
function CH.GameHouseName(guid)
    local h = ChamberlainDB.houses[guid]
    if guid == CH.currentHouseGUID and CH.currentHouseName then
        return CH.currentHouseName
    end
    return h and h.houseName
end

-- The name the house goes by, the owner's own over the game's.
function CH.HouseName(guid)
    local h = ChamberlainDB.houses[guid]
    return h and h.plaqueName or CH.GameHouseName(guid)
end

local MORPHEUS = QuestFont_Huge:GetFont()
local MOTTO_INK = { 0.91, 0.86, 0.69 }

local plaque = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
plaque:SetFrameStrata("HIGH")
-- over the room banner, which shares the strata and can come up under it
plaque:SetFrameLevel(CH.banner:GetFrameLevel() + 20)
plaque:SetBackdrop(CH.BACKDROP_THIN)
plaque:SetBackdropColor(0.03, 0.027, 0.02, 0.86)
plaque:SetBackdropBorderColor(0.35, 0.29, 0.09, 1)
plaque:SetAlpha(0)
plaque:Hide()

-- the inner line of the double frame
local inner = CreateFrame("Frame", nil, plaque, "BackdropTemplate")
inner:SetPoint("TOPLEFT", 4, -4)
inner:SetPoint("BOTTOMRIGHT", -4, 4)
inner:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
inner:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 1))

local entering = plaque:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
entering:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

-- A font string can't glow, so eight dim copies sit a couple of pixels out
-- around the name in its own colour and the name with its shadow goes over
-- them. Close enough to a halo at this size.
local halo = {}
local HALO_R = 2
for i = 1, 8 do
    local fs = plaque:CreateFontString(nil, "ARTWORK")
    fs:SetFont(MORPHEUS, 30, "")
    fs:SetTextColor(CH.RGBA(CH.COLORS.bannerText, 0.18))
    halo[i] = fs
end
local name = plaque:CreateFontString(nil, "OVERLAY")
name:SetFont(MORPHEUS, 30, "")
name:SetShadowOffset(2, -2)
name:SetShadowColor(0, 0, 0, 1)
name:SetTextColor(CH.RGBA(CH.COLORS.bannerText, 1))
name:SetWordWrap(false)
for i, fs in ipairs(halo) do
    local a = (i - 1) * math.pi / 4
    fs:SetPoint("CENTER", name, "CENTER", HALO_R * math.cos(a), HALO_R * math.sin(a))
end

local lineL = plaque:CreateTexture(nil, "ARTWORK")
local lineR = plaque:CreateTexture(nil, "ARTWORK")

local owner = plaque:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
owner:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local motto = plaque:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
motto:SetTextColor(MOTTO_INK[1], MOTTO_INK[2], MOTTO_INK[3], 1)
motto:SetWidth(MAX_TEXT)
motto:SetJustifyH("CENTER")
motto:SetSpacing(2)

local facts = plaque:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
facts:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

-- The lines top down with the gap under each. The line under the name is
-- the entry with no font string.
local ROWS = {
    { fs = entering, gap = 8 },
    { fs = name, gap = 10 },
    { gap = 14 },
    { fs = owner, gap = 8 },
    { fs = motto, gap = 8 },
    { fs = facts, gap = 0 },
}

local function Has(fs)
    local t = fs:GetText()
    return t ~= nil and t ~= ""
end

-- Stack the lines from the top, each centred. An empty line takes no room.
local function Layout()
    local w = 0
    for _, row in ipairs(ROWS) do
        if row.fs and Has(row.fs) then
            w = math.max(w, row.fs:GetStringWidth())
        end
    end
    w = math.max(MIN_W, math.min(w, MAX_TEXT) + 2 * PAD)

    local y, lineY = 22, 0
    for _, row in ipairs(ROWS) do
        local fs = row.fs
        if not fs then
            lineY = y
            y = y + row.gap
        elseif Has(fs) then
            fs:Show()
            fs:ClearAllPoints()
            fs:SetPoint("TOP", plaque, "TOP", 0, -y)
            y = y + fs:GetStringHeight() + row.gap
        else
            fs:Hide()
        end
    end
    local h = y + 24
    plaque:SetSize(w, h)
    -- BannerLine hangs off the middle, so its height is from there
    CH.BannerLine(plaque, lineL, lineR, CH.COLORS.line, math.min(w - 2 * PAD, 340), h * 0.5 - lineY, 2, 1, 0)
end

local fadeTimer

local function Fade()
    fadeTimer = nil
    UIFrameFadeOut(plaque, 1, plaque:GetAlpha(), 0)
    C_Timer.After(1, function()
        if plaque:GetAlpha() <= 0.05 then
            plaque:Hide()
        end
    end)
end

-- Bring the plaque up for house guid. preview holds a plaqueName and a motto
-- typed in the House panel, shown in place of the stored ones before they are
-- saved and cleaned the same way Save will.
function CH.ShowPlaque(guid, preview)
    local h = guid and ChamberlainDB.houses[guid]
    local here = guid == CH.currentHouseGUID
    local houseName, text = CH.HouseName(guid), h and h.motto
    if preview then
        houseName = CH.CleanText(preview.plaqueName, CH.HOUSE_TEXT.plaqueName) or CH.GameHouseName(guid)
        text = CH.CleanText(preview.motto, CH.HOUSE_TEXT.motto)
    end
    local who = (here and CH.currentHouseOwner or h and h.owner) or CH.L["HOUSE_HOME_INTERIOR"]
    local whose = string.format(CH.L["RM_X_HOUSE"], who)

    entering:SetText(CH.L["PL_ENTERING"])
    -- a house the game never named is announced by its owner alone
    name:SetText(houseName or whose)
    for _, fs in ipairs(halo) do
        fs:SetText(houseName or whose)
    end
    owner:SetText(houseName and whose or "")
    motto:SetText(text and text ~= "" and string.format(CH.L["PL_MOTTO_X"], text) or "")
    local rooms = h and h.zones and #h.zones or 0
    if rooms == 0 then
        facts:SetText("")
    elseif (h.floorCount or 1) > 1 then
        facts:SetText(string.format(CH.L["PL_FLOORS_ROOMS_X"], h.floorCount, rooms))
    else
        facts:SetText(string.format(CH.L["PL_ROOMS_X"], rooms))
    end
    Layout()

    if fadeTimer then
        fadeTimer:Cancel()
    end
    plaque:Show()
    UIFrameFadeIn(plaque, 0.5, plaque:GetAlpha(), 1)
    fadeTimer = C_Timer.NewTimer(PLAQUE_SECONDS, Fade)
end

function CH.HidePlaque()
    if fadeTimer then
        fadeTimer:Cancel()
        fadeTimer = nil
    end
    -- a fade-in still running would keep raising the alpha of the hidden frame
    UIFrameFadeRemoveFrame(plaque)
    plaque:SetAlpha(0)
    plaque:Hide()
end

CH.ApplyPlaquePos = CH.MakeMovablePersistent(plaque, "plaqueX", "plaqueY")

-- One of the owner's texts, kind a key of CH.HOUSE_TEXT, empty for none. The
-- group gets it as a patch like the banner style, see CH.SetHouseBanner. One
-- too long for a message goes out with the map instead, which the catalog
-- bump makes them pull. None goes out as a single space, which no cleaned
-- text can be.
function CH.SetHouseText(guid, kind, text)
    local h = ChamberlainDB.houses[guid]
    text = CH.CleanText(text, CH.HOUSE_TEXT[kind])
    if h[kind] == text then
        return
    end
    local baseTs = h.updatedAt
    h[kind] = text
    CH.TouchHouse(guid)
    if not text or #text <= PATCH_BYTES then
        CH.SendSoundPatch(guid, kind, baseTs, "H", text or " ", true)
    end
end
