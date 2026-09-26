local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room banner  (visible while inside a named zone)
-- ─────────────────────────────────────────────────────────────────────
-- The name of the room you walk into, in the room's colour. How it's drawn is
-- your choice in Settings (bannerStyle), unless the house's owner picked a
-- style for it (h.bannerStyle, 3.20.0). Keep my style in other houses turns
-- an owner's pick off, but never your own house's.
-- CH.MakeBanner builds the pieces once and a style shows the ones it needs,
-- so the room editor and Settings draw their previews with the same code as
-- the real banner.

-- The style picker's list, top down. The zone text look comes first. Original
-- is the banner from before 3.18.0, boxed Read button and all. Found art is
-- public domain ornament from OpenClipart, cut up in Media as art-*.tga.
-- Rainbow is four found rainbows cut in two around the name and five flat
-- stripe bands. Scenario, Plates, Ribbons and Lines are the game's own
-- atlases, nothing shipped. A family is one art in several colours, one row in
-- the picker with a chip for each.
CH.BANNER_GROUPS = {
    {
        key = "BP_DRAWN",
        hint = "BP_DRAWN_HINT",
        styles = { "zone", "original", "classic", "plaque", "minimal", "seal", "ribbon", "corners", "glow", "wings" },
    },
    {
        key = "BP_FOUND",
        hint = "BP_FOUND_HINT",
        styles = { "nameplate", "cartouche", "parchment", "scroll", "pennant", "deco", "nouveau", "filigree" },
    },
    {
        key = "BP_RAINBOW",
        hint = "BP_RAINBOW_HINT",
        styles = { "arch", "wave", "swoosh", "chalk", "band", "eight", "pastel", "jewel", "faded" },
    },
    {
        key = "BP_SCENARIO",
        hint = "BP_SCENARIO_HINT",
        styles = {
            "midnight",
            "warwithin",
            "dragonflight",
            "kyrian",
            "embercourt",
            "torghast",
            "nzoth",
            "legion",
            "alliance",
            "horde",
            "gilded",
            "objective",
            "prestige",
        },
    },
    {
        key = "BP_PLATES",
        hint = "BP_PLATES_HINT",
        styles = {
            "midnightplate",
            "midnightgem",
            "midnightframe",
            "warwithinframe",
            "bronzeplate",
            "dragonflightframe",
            "kyrianframe",
            "nightfaeframe",
            "venthyrframe",
            "necrolordframe",
            "oribosframe",
            "mechagonframe",
            "mechagonplate",
            "gildedplate",
            "arena",
            "slate",
            "amber",
            "walnut",
            "questlog",
            "leather",
            {
                family = "BP_FAM_GILT",
                styles = { "giltalliance", "gilthorde", "giltneutral", "giltmarine" },
                chips = { { 0.2, 0.4, 0.85 }, { 0.7, 0.12, 0.1 }, { 0.55, 0.33, 0.15 }, { 0.4, 0.36, 0.18 } },
            },
        },
    },
    {
        key = "BP_RIBBONS",
        hint = "BP_RIBBONS_HINT",
        styles = {
            {
                family = "BP_FAM_TITLE",
                styles = {
                    "titlegold",
                    "titlemarine",
                    "titleventhyr",
                    "titlekyrian",
                    "titlenecrolord",
                    "titlenightfae",
                    "titledragonflight",
                },
                chips = {
                    { 0.85, 0.58, 0.24 },
                    { 0.85, 0.75, 0.44 },
                    { 0.85, 0.59, 0.47 },
                    { 0.85, 0.77, 0.73 },
                    { 0.85, 0.71, 0.45 },
                    { 0.74, 0.78, 0.85 },
                    { 0.85, 0.67, 0.49 },
                },
            },
            "legionfall",
            "garrison",
            "namescroll",
            "pirate",
        },
    },
    {
        key = "BP_LINES",
        hint = "BP_LINES_HINT",
        styles = {
            "roomlabel",
            "maplabel",
            "celebration",
            {
                family = "BP_FAM_GLOW",
                styles = {
                    "glowhorde",
                    "glowalliance",
                    "glowkyrian",
                    "glownecrolord",
                    "glownightfae",
                    "glowmechagon",
                    "glowmidnight",
                    "glowdragonflight",
                },
                chips = {
                    { 0.85, 0.45, 0.33 },
                    { 0.53, 0.85, 0.85 },
                    { 0.42, 0.48, 0.85 },
                    { 0.47, 0.85, 0.73 },
                    { 0.28, 0.58, 0.85 },
                    { 0.85, 0.66, 0.28 },
                    { 0.5, 0.13, 0.85 },
                    { 0.85, 0.71, 0.51 },
                },
            },
            -- chips in the class colours, see CH.BannerChip
            {
                family = "BP_FAM_CLASS",
                styles = {
                    "classdeathknight",
                    "classdemonhunter",
                    "classdruid",
                    "classhunter",
                    "classmage",
                    "classmonk",
                    "classpaladin",
                    "classpriest",
                    "classrogue",
                    "classshaman",
                    "classwarlock",
                    "classwarrior",
                },
            },
        },
    },
}

-- A house's style goes over the wire as its number here (bs in the export).
-- Wire identity like CH.HEADS: only append, never reorder or remove, and a
-- style that goes away keeps it slot. The picker's order above is free.
CH.BANNER_IDS = {
    "zone",
    "original",
    "classic",
    "plaque",
    "minimal",
    "seal",
    "ribbon",
    "corners",
    "glow",
    "wings",
    "nameplate",
    "cartouche",
    "parchment",
    "scroll",
    "pennant",
    "deco",
    "nouveau",
    "filigree",
    "arch",
    "wave",
    "swoosh",
    "chalk",
    "band",
    "eight",
    "pastel",
    "jewel",
    "faded",
    "midnight",
    "alliance",
    "horde",
    "nzoth",
    "torghast",
    "embercourt",
    "kyrian",
    "dragonflight",
    "gilded",
    "warwithin",
    "legion",
    "objective",
    "prestige",
    "midnightplate",
    "legionfall",
    "garrison",
    "leather",
    "mechagonplate",
    "bronzeplate",
    "arena",
    "maplabel",
    "pirate",
    "namescroll",
    "roomlabel",
    "slate",
    "questlog",
    "celebration",
    "amber",
    "walnut",
    "kyrianframe",
    "nightfaeframe",
    "venthyrframe",
    "necrolordframe",
    "oribosframe",
    "mechagonframe",
    "dragonflightframe",
    "warwithinframe",
    "midnightframe",
    "midnightgem",
    "gildedplate",
    "giltalliance",
    "gilthorde",
    "giltneutral",
    "giltmarine",
    "titlegold",
    "titlemarine",
    "titleventhyr",
    "titlekyrian",
    "titlenecrolord",
    "titlenightfae",
    "titledragonflight",
    "glowhorde",
    "glowalliance",
    "glowkyrian",
    "glownecrolord",
    "glownightfae",
    "glowmechagon",
    "glowmidnight",
    "glowdragonflight",
    "classdeathknight",
    "classdemonhunter",
    "classdruid",
    "classhunter",
    "classmage",
    "classmonk",
    "classpaladin",
    "classpriest",
    "classrogue",
    "classshaman",
    "classwarlock",
    "classwarrior",
}
CH.BANNER_ID = {}
for id, style in ipairs(CH.BANNER_IDS) do
    CH.BANNER_ID[style] = id
end

local FRIZ, LARGE = GameFontNormalLarge:GetFont()
-- the face of the game's own zone names, with its stand-ins for Asian clients
local MORPHEUS = QuestFont_Huge:GetFont()

-- The colour to tint an svg with so it shows as c scaled by k. An svg's tint
-- goes through the display curve, where a flat texture's doesn't: tinted at
-- 0.2 it came out near 0.45. Only the dark fills need it, since a bright
-- tint barely moves.
local function SvgDark(c, k)
    return { (c[1] * k) ^ 2.2, (c[2] * k) ^ 2.2, (c[3] * k) ^ 2.2 }
end

-- A texture's colour running from alpha a1 on the left to a2 on the right.
local function Fade(tex, c, a1, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
end

-- A line across the middle of b at height y, w wide, out of two halves so it
-- can fade out at both ends. a is its alpha in the middle, edge at the ends.
local function Line(b, l, r, c, w, y, thick, a, edge)
    l:ClearAllPoints()
    r:ClearAllPoints()
    l:SetSize(w * 0.5, thick)
    r:SetSize(w * 0.5, thick)
    l:SetPoint("RIGHT", b, "CENTER", 0, y)
    r:SetPoint("LEFT", b, "CENTER", 0, y)
    Fade(l, c, edge, a)
    Fade(r, c, a, edge)
    l:Show()
    r:Show()
end
CH.BannerLine = Line -- the house plaque rules its name off with it

-- The Read button: a book in a small frame, both in the room's colour. It
-- opens the yapper.
local function MakeReadButton(b, onRead)
    local btn = CreateFrame("Button", nil, b, "BackdropTemplate")
    btn:SetBackdrop(CH.BACKDROP_THIN)
    btn:SetSize(26, 24)
    btn.icon = CH.MakeIcon(btn, "icon-book", 16, "OVERLAY")
    btn.icon:SetPoint("CENTER")
    -- Under the mouse the frame fills with a wash of the room's colour (the
    -- game shows a HIGHLIGHT layer by itself) and the book and edge run most
    -- of the way to white.
    btn.glow = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.glow:SetPoint("TOPLEFT", 1, -1)
    btn.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    function btn:Tint(c, hot)
        local k = hot and 0.6 or 0
        local r, g, bl = c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k
        self.c = c
        self:SetBackdropColor(c[1] * 0.15, c[2] * 0.15, c[3] * 0.15, 0.9)
        self:SetBackdropBorderColor(r, g, bl, 1)
        self.glow:SetColorTexture(c[1], c[2], c[3], 0.3)
        self.icon:SetVertexColor(r, g, bl)
    end
    if onRead then
        btn:SetScript("OnClick", onRead)
        btn:SetScript("OnEnter", function(self)
            self:Tint(self.c, true)
        end)
        btn:SetScript("OnLeave", function(self)
            self:Tint(self.c)
        end)
        CH.Tip(btn, "BANNER_READ")
    else
        btn:EnableMouse(false) -- a preview's button is only a picture
    end
    return btn
end

-- Every piece any style uses, made once. onRead is the Read button's click,
-- nil on a preview.
function CH.MakeBanner(parent, onRead)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(340, 54)
    b.flat = b:CreateTexture(nil, "BACKGROUND")
    b.backL = b:CreateTexture(nil, "BACKGROUND")
    b.backR = b:CreateTexture(nil, "BACKGROUND")
    b.lineAL = b:CreateTexture(nil, "BORDER")
    b.lineAR = b:CreateTexture(nil, "BORDER")
    b.lineBL = b:CreateTexture(nil, "BORDER")
    b.lineBR = b:CreateTexture(nil, "BORDER")
    b.stripe = b:CreateTexture(nil, "BORDER")
    b.corners = {}
    for i = 1, 8 do
        b.corners[i] = b:CreateTexture(nil, "BORDER")
    end
    b.diamonds = {}
    for i = 1, 3 do
        b.diamonds[i] = CH.MakeIcon(b, "diamond", 8, "ARTWORK")
    end
    b.seal = CH.MakeIcon(b, "icon-seal", 32, "ARTWORK")
    -- The ribbon is all svg, middle and tails, since a tinted svg comes out
    -- brighter than a flat texture of the same colour and the two never match.
    -- The wedges sit a sublevel under the middle, and the edge lines (BORDER)
    -- over it.
    b.ribL = CH.MakeIcon(b, "ribbon-left", 22, "BACKGROUND")
    b.ribR = CH.MakeIcon(b, "ribbon-right", 22, "BACKGROUND")
    b.ribBody = CH.MakeIcon(b, "rect", 16, "BACKGROUND")
    b.ribL:SetDrawLayer("BACKGROUND", 1)
    b.ribR:SetDrawLayer("BACKGROUND", 1)
    b.ribBody:SetDrawLayer("BACKGROUND", 2)
    -- found art draws a dark backing under two ends and a middle, with the
    -- centre ornament on top
    b.artBack = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.art = {}
    b.artTiles = {} -- made as a long name needs them
    b.gameTex = {} -- the same for game art
    for i, part in ipairs({ "left", "right", "mid", "mid2", "centre" }) do
        b.art[part] = b:CreateTexture(nil, "BACKGROUND", nil, i < 5 and 1 or 2)
    end
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.name:SetWordWrap(false)
    b.book = MakeReadButton(b, onRead)
    -- the Original style's button, the addon's usual one with Read on it
    b.oldRead = CH.MakeButton(b, "BANNER_READ", 44, 18)
    if onRead then
        b.oldRead:HookScript("OnClick", onRead)
    else
        b.oldRead:EnableMouse(false)
    end
    b.read = b.book

    b.parts = { b.flat, b.backL, b.backR, b.lineAL, b.lineAR, b.lineBL, b.lineBR, b.stripe }
    for _, t in ipairs({ b.seal, b.ribL, b.ribR, b.ribBody, b.artBack }) do
        b.parts[#b.parts + 1] = t
    end
    for _, t in pairs(b.art) do
        b.parts[#b.parts + 1] = t
    end
    for _, t in ipairs(b.corners) do
        b.parts[#b.parts + 1] = t
    end
    for _, t in ipairs(b.diamonds) do
        b.parts[#b.parts + 1] = t
    end
    return b
end

-- Name and Read button side by side as one group, its middle dx off b's
-- middle and dy above it. Hands back the group's width.
local function PlaceGroup(b, showRead, dx, dy)
    local tw = b.name:GetStringWidth()
    local w = tw + (showRead and b.read:GetWidth() + 8 or 0)
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b, "CENTER", dx - w * 0.5, dy or 0)
    b.read:ClearAllPoints()
    b.read:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
    return w
end

local function Font(b, face, size, flags, shadow)
    b.name:SetFont(face, size, flags)
    b.name:SetShadowOffset(shadow, -shadow)
    b.name:SetShadowColor(0, 0, 0, 1)
end

-- An svg piece at w by h in colour c.
local function Show(part, c, w, h)
    part:SetSize(w, h)
    part:SetVertexColor(c[1], c[2], c[3])
    part:Show()
end

-- Each style lays b out for a name already set on it, in line colour lc and
-- with or without the Read button. It sizes b itself.
local STYLES = {}

-- The game's own zone name: big, outlined, nothing behind it.
function STYLES.zone(b, _, read)
    Font(b, MORPHEUS, 30, "OUTLINE", 2)
    local w = PlaceGroup(b, read, 0)
    b:SetSize(w + 20, 50)
end

-- The banner as it was up to 3.17, a dark box between two gold lines. Original
-- is the same box, told apart by its old Read button in PaintBanner.
function STYLES.classic(b, lc, read)
    Font(b, FRIZ, LARGE, "", 1)
    local w = math.max(180, PlaceGroup(b, read, 0) + 44)
    b:SetSize(w, 54)
    b.flat:SetAllPoints()
    Fade(b.flat, { 0, 0, 0 }, 0.52, 0.52) -- flat, but it clears seal's gradient
    b.flat:Show()
    Line(b, b.lineAL, b.lineAR, lc, w - 24, 15, 1, 0.9, 0.9)
    Line(b, b.lineBL, b.lineBR, lc, w - 24, -15, 1, 0.9, 0.9)
end
STYLES.original = STYLES.classic

-- A dark glow that fades out sideways, fading lines above and below and a
-- diamond on the top one.
function STYLES.plaque(b, lc, read)
    Font(b, FRIZ, 22, "", 1)
    local w = PlaceGroup(b, read, 0)
    b:SetSize(w + 160, 74)
    Line(b, b.backL, b.backR, { 0, 0, 0 }, w + 160, 0, 60, 0.6, 0)
    Line(b, b.lineAL, b.lineAR, lc, w + 100, 24, 1, 0.9, 0)
    Line(b, b.lineBL, b.lineBR, lc, w + 100, -24, 1, 0.9, 0)
    Show(b.diamonds[1], lc, 8, 8)
    b.diamonds[1]:ClearAllPoints()
    b.diamonds[1]:SetPoint("CENTER", b, "CENTER", 0, 24)
end

-- Nothing behind the name, one fading rule under it.
function STYLES.minimal(b, lc, read)
    Font(b, FRIZ, 24, "", 1)
    local w = PlaceGroup(b, read, 0)
    b:SetSize(w + 80, 50)
    Line(b, b.lineAL, b.lineAR, lc, w + 80, -17, 2, 0.9, 0)
end

-- A card leaning left, a house seal and a stripe in the room's colour.
function STYLES.seal(b, lc, read)
    Font(b, FRIZ, 20, "", 1)
    local tw = b.name:GetStringWidth() + (read and b.read:GetWidth() + 8 or 0)
    local w = 8 + 32 + 12 + tw + 40
    b:SetSize(w, 48)
    b.flat:SetAllPoints()
    Fade(b.flat, { 0, 0, 0 }, 0.7, 0)
    b.flat:Show()
    b.stripe:ClearAllPoints()
    b.stripe:SetPoint("TOPLEFT")
    b.stripe:SetPoint("BOTTOMLEFT")
    b.stripe:SetWidth(3)
    b.stripe:SetColorTexture(lc[1], lc[2], lc[3], 1)
    b.stripe:Show()
    Show(b.seal, lc, 32, 32)
    b.seal:ClearAllPoints()
    b.seal:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b, "LEFT", 52, 0)
    b.read:ClearAllPoints()
    b.read:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
end

-- A dark band edged in the room's colour, with a notched wedge on each end.
-- The edge lines stop where the wedges start.
local RIBBON_H, WEDGE_W = 40, 22

function STYLES.ribbon(b, lc, read)
    Font(b, FRIZ, 20, "", 1)
    local w = PlaceGroup(b, read, 0) + 32
    b:SetSize(w + 2 * WEDGE_W, RIBBON_H)
    local body, dark = b.ribBody, SvgDark(lc, 0.18)
    body:ClearAllPoints()
    body:SetPoint("CENTER")
    Show(body, dark, w, RIBBON_H)
    Line(b, b.lineAL, b.lineAR, lc, w, RIBBON_H * 0.5 - 0.5, 1, 1, 1)
    Line(b, b.lineBL, b.lineBR, lc, w, -RIBBON_H * 0.5 + 0.5, 1, 1, 1)
    Show(b.ribL, dark, WEDGE_W, RIBBON_H)
    Show(b.ribR, dark, WEDGE_W, RIBBON_H)
    -- a pixel into the band so no seam shows
    b.ribL:ClearAllPoints()
    b.ribL:SetPoint("RIGHT", body, "LEFT", 1, 0)
    b.ribR:ClearAllPoints()
    b.ribR:SetPoint("LEFT", body, "RIGHT", -1, 0)
end

-- Four corner brackets on a faint dark backing.
local CORNER_SPOTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

function STYLES.corners(b, lc, read)
    Font(b, FRIZ, 21, "", 1)
    local w = PlaceGroup(b, read, 0) + 56
    b:SetSize(w, 46)
    b.flat:SetAllPoints()
    Fade(b.flat, { 0, 0, 0 }, 0.35, 0.35)
    b.flat:Show()
    for i, spot in ipairs(CORNER_SPOTS) do
        local across, down = b.corners[i * 2 - 1], b.corners[i * 2]
        for _, t in ipairs({ across, down }) do
            t:ClearAllPoints()
            t:SetPoint(spot)
            t:SetColorTexture(lc[1], lc[2], lc[3], 1)
            t:Show()
        end
        across:SetSize(12, 2)
        down:SetSize(2, 12)
    end
end

-- A haze of the room's own colour behind the name and nothing else.
function STYLES.glow(b, lc, read)
    Font(b, FRIZ, 23, "", 1)
    local w = PlaceGroup(b, read, 0)
    b:SetSize(w + 160, 44)
    Line(b, b.backL, b.backR, lc, w + 160, 0, 34, 0.3, 0)
end

-- Fading lines out to both sides of the name, a diamond at their inner ends.
function STYLES.wings(b, lc, read)
    Font(b, FRIZ, 21, "", 1)
    local w = PlaceGroup(b, read, 0)
    local span = w + 2 * (12 + 8 + 6 + 70) + 40
    b:SetSize(span, 44)
    Line(b, b.backL, b.backR, { 0, 0, 0 }, span, 0, 40, 0.5, 0)
    local left, right = b.diamonds[2], b.diamonds[3]
    local edge = w * 0.5 + 12
    for side, d in ipairs({ left, right }) do
        Show(d, lc, 6, 6)
        d:ClearAllPoints()
        d:SetPoint("CENTER", b, "CENTER", side == 1 and -edge or edge, 0)
    end
    edge = edge + 10
    b.lineBL:ClearAllPoints()
    b.lineBR:ClearAllPoints()
    b.lineBL:SetSize(70, 1)
    b.lineBR:SetSize(70, 1)
    b.lineBL:SetPoint("RIGHT", b, "CENTER", -edge, 0)
    b.lineBR:SetPoint("LEFT", b, "CENTER", edge, 0)
    Fade(b.lineBL, lc, 0, 0.9)
    Fade(b.lineBR, lc, 0.9, 0)
    b.lineBL:Show()
    b.lineBR:Show()
end

-- Found art. h is how tall it draws, l the width of an end (r of the right
-- one when they differ) and c of the centre ornament, all in heights
-- measured off the art. A plate puts the name on its middle, which
-- stretches, and back is the dark backing's overhang into the left end, its
-- inset from the top and its overhang into the right end, in pixels. The
-- backing fills the art's own inner frame. A plate with tiles repeats those
-- sections of its middle instead (mid1, mid2 and so on, widths in heights),
-- cut so their torn edges meet in any order. Wings put the name in a gap
-- between the two ends. Art with an ink keeps its own colours and the name
-- takes the ink. The rest is white art tinted to the room.
local INK = { 0.23, 0.16, 0.07 }
local WHITE, BLACK = { 1, 1, 1 }, { 0, 0, 0 }
local ART = {
    nameplate = { h = 64, l = 0.8, c = 0.48, pad = 14, back = { 0, 10, 0 } },
    cartouche = { h = 70, l = 0.51, r = 0.55, c = 0.38, pad = 12, back = { 24, 15, 27 } },
    parchment = {
        h = 72,
        l = 0.37,
        r = 0.44,
        tiles = { 0.148, 0.266, 0.252 },
        pad = 12,
        ink = INK,
        shadow = 0,
    },
    scroll = { h = 60, l = 0.28, pad = 14, ink = INK, shadow = 0 },
    pennant = { h = 48, l = 1.51, pad = 10, dy = -4, ink = { 1, 0.95, 0.86 } },
    deco = { h = 30, l = 3.62, gap = 12 },
    nouveau = { h = 34, l = 2.24, gap = 10 },
    filigree = { h = 34, l = 3.49, gap = 8 },
    -- the rainbow set, l measured off the cut art
    arch = { h = 48, l = 0.95, gap = 8, ink = WHITE },
    wave = { h = 56, l = 1.38, gap = 10, ink = WHITE },
    swoosh = { h = 60, l = 0.76, gap = 8, ink = WHITE },
    chalk = { h = 16, l = 7.15, gap = 12, ink = WHITE },
}
-- the bands are one cut in five palettes
for _, pal in ipairs({ "band", "eight", "pastel", "jewel", "faded" }) do
    ART[pal] = { h = 44, l = 0.6, pad = 10, ink = WHITE }
end
local ART_PATH = "Interface\\AddOns\\Chamberlain\\Media\\art-"

local function Piece(t, file, c, w, h)
    t:SetTexture(ART_PATH .. file .. ".tga")
    t:SetVertexColor(c[1], c[2], c[3])
    t:SetSize(w, h)
    t:ClearAllPoints()
    t:Show()
end

-- Repeats the sections from the left end on, as many as come closest to w,
-- then squeezes or stretches them a little so they fill it exactly. Each runs
-- a pixel under the one before so no seam shows.
local function Tiles(b, name, c, w, h, tiles)
    local n, sum = 0, 0
    local last
    repeat
        n = n + 1
        last = tiles[(n - 1) % #tiles + 1] * h
        sum = sum + last
    until sum >= w
    if n > 1 and w - (sum - last) < sum - w then
        n, sum = n - 1, sum - last
    end
    local k = w / sum
    local prev = b.art.left
    for i = 1, n do
        local t = b.artTiles[i]
        if not t then
            t = b:CreateTexture(nil, "BACKGROUND", nil, 1)
            b.artTiles[i] = t
            b.parts[#b.parts + 1] = t
        end
        local j = (i - 1) % #tiles + 1
        Piece(t, name .. "-mid" .. j, c, tiles[j] * h * k + 1, h)
        t:SetPoint("LEFT", prev, "RIGHT", -1, 0)
        prev = t
    end
end

local function DrawArt(b, lc, read, name, a)
    Font(b, FRIZ, a.gap and 21 or 19, "", a.shadow or 1)
    local gw = PlaceGroup(b, read, 0, a.dy)
    local c = a.ink and WHITE or lc
    local h, ew = a.h, a.l * a.h
    local rw = (a.r or a.l) * h
    local p = b.art
    Piece(p.left, name .. "-left", c, ew, h)
    Piece(p.right, name .. "-right", c, rw, h)
    if a.gap then
        local half = gw * 0.5 + a.gap
        b:SetSize(2 * half + ew + rw, h)
        p.left:SetPoint("RIGHT", b, "CENTER", -half, 0)
        p.right:SetPoint("LEFT", b, "CENTER", half, 0)
        return a.ink
    end
    local cw = (a.c or 0) * h
    local w = math.max(gw + 2 * a.pad, cw + 20)
    b:SetSize(w + ew + rw, h)
    p.left:SetPoint("RIGHT", b, "CENTER", -w * 0.5, 0)
    p.right:SetPoint("LEFT", b, "CENTER", w * 0.5, 0)
    if a.tiles then
        Tiles(b, name, c, w, h, a.tiles)
        return a.ink
    end
    -- the middle runs a pixel under each end so no seam shows
    local mw = (w - cw) * (a.c and 0.5 or 1) + 2
    Piece(p.mid, name .. "-mid", c, mw, h)
    p.mid:SetPoint("LEFT", p.left, "RIGHT", -1, 0)
    if a.c then
        Piece(p.mid2, name .. "-mid", c, mw, h)
        p.mid2:SetPoint("RIGHT", p.right, "LEFT", 1, 0)
        Piece(p.centre, name .. "-centre", c, cw, h)
        p.centre:SetPoint("CENTER")
    end
    if a.back then
        local back, over = b.artBack, a.back
        back:ClearAllPoints()
        back:SetPoint("TOPLEFT", p.left, "TOPRIGHT", -over[1], -over[2])
        back:SetPoint("BOTTOMRIGHT", p.right, "BOTTOMLEFT", over[3], over[2])
        Fade(back, BLACK, 0.45, 0.45)
        back:Show()
    end
    return a.ink
end

for name, a in pairs(ART) do
    STYLES[name] = function(b, lc, read)
        return DrawArt(b, lc, read, name, a)
    end
end

-- Banners out of the game's own art, found by atlas name so nothing ships. A
-- style is one or more layers, each an atlas cut in pieces at cut, shares of
-- its width measured off the textures. Some pieces keep their width and the
-- rest share out whatever a long name needs. A title keeps the ornament
-- between the cuts and stretches both sides. A plate keeps its ends and
-- stretches the middle, stretch stretches all of it. Halves is a left and a
-- right atlas side by side, ends kept up to cut[1] and the inside cut off at
-- cut[2] where a half fades out at its inner edge.
-- h is how tall the style draws, ny how far above the middle the name sits
-- (mid instead gives it as a share of the height, down from the top) and band
-- the share of the width the name may take before the art grows. A plate or
-- halves grows by what the name needs past its middle instead, PLATE_PAD a side. A
-- one layer style names its atlas straight in the style.
-- A layer draws at its own h or scale, else at the first layer's scale, and
-- top places it down from the style's top edge, else it's centred. x and
-- extra are in the atlas's own pixels, its left edge off the style's and how
-- much wider it runs. A wide layer keeps the difference in natural width.
-- The first layer sets the style's width, or the one lead names.
-- A style with an atlas a later patch drops shows Classic.
local GAME = {
    midnight = { atlas = "midnight-scenario-titlebg", cut = { 0.398, 0.602 }, h = 96, mid = 0.484, band = 0.63 },
    alliance = { atlas = "AllianceScenario-TitleBG", cut = { 0.285, 0.707 }, h = 107, mid = 0.511, band = 0.46 },
    horde = { atlas = "HordeScenario-TitleBG", cut = { 0.317, 0.666 }, h = 107, mid = 0.511, band = 0.46 },
    nzoth = { atlas = "nzothscenario-titlebg", cut = { 0.288, 0.7 }, h = 104, mid = 0.574, band = 0.73 },
    torghast = { atlas = "jailerstower-scenario-titlebg", cut = { 0.311, 0.691 }, h = 107, mid = 0.511, band = 0.46 },
    embercourt = { atlas = "embercourtscenario-titlebg", cut = { 0.328, 0.668 }, h = 107, mid = 0.511, band = 0.46 },
    kyrian = { atlas = "kyrian-scenario-TitleBG", cut = { 0.353, 0.645 }, h = 107, mid = 0.511, band = 0.46 },
    dragonflight = {
        atlas = "dragonflight-scenario-titlebg",
        cut = { 0.306, 0.694 },
        h = 107,
        mid = 0.511,
        band = 0.53,
    },
    gilded = { atlas = "evergreen-scenario-titlebg", cut = { 0.389, 0.606 }, h = 126, mid = 0.497, band = 0.69 },
    warwithin = { atlas = "thewarwithin-scenario-titlebg", cut = { 0.363, 0.634 }, h = 126, mid = 0.503, band = 0.53 },
    -- the fel runs along both lines, so all of it stays put and only the
    -- faded ends stretch
    legion = { atlas = "legioninvasion-title-bg", cut = { 0.171, 0.822 }, h = 107, mid = 0.518, band = 0.46 },
    objective = { atlas = "bonusobjectives-title-bg", cut = { 0.428, 0.569 }, h = 58, mid = 0.43, band = 0.62 },
    prestige = { atlas = "titleprestige-title-bg", cut = { 0.428, 0.569 }, h = 58, mid = 0.43, band = 0.62 },
    midnightplate = {
        atlas = "ui-frame-midnight-border-title-bg",
        cut = { 0.142, 0.84 },
        h = 64,
        mid = 0.488,
        kind = "plate",
        size = 22,
    },
    legionfall = {
        atlas = "Legionfall_Banner",
        cut = { 0.119, 0.897 },
        h = 56,
        mid = 0.44,
        kind = "plate",
        size = 20,
        ink = INK,
    },
    garrison = {
        atlas = "GarrMission_RewardsBanner",
        cut = { 0.14, 0.88 },
        h = 80,
        mid = 0.43,
        kind = "plate",
        size = 20,
        ink = INK,
    },
    leather = { atlas = "storyheader-bg", kind = "plate", cut = { 0.01, 0.99 }, h = 60, mid = 0.45 },
    mechagonplate = { atlas = "UI-Frame-Mechagon-Ribbon", kind = "plate", cut = { 0.15, 0.85 }, h = 64, mid = 0.45 },
    bronzeplate = { atlas = "ui-frame-thewarwithin-ribbon", kind = "plate", cut = { 0.25, 0.75 }, h = 64, mid = 0.47 },
    -- the plate fills only the top half of its texture
    arena = {
        atlas = "tournamentarena-titlebackplate",
        kind = "plate",
        cut = { 0.05, 0.95 },
        h = 82,
        mid = 0.28,
        size = 22,
    },
    maplabel = { atlas = "adventuremaplabel-large", kind = "stretch", h = 70, mid = 0.53, band = 0.7, size = 22 },
    -- the ropes and skulls stay at the ends and the cloth between them streches
    pirate = { atlas = "islands-queue-titlesign", kind = "plate", cut = { 0.3, 0.7 }, h = 72, mid = 0.55, size = 20 },
    namescroll = {
        atlas = "islands-queue-card-namescroll",
        kind = "plate",
        cut = { 0.1, 0.9 },
        h = 56,
        mid = 0.52,
        size = 20,
    },
    -- the housing editor's own room label
    roomlabel = {
        atlas = "housing-layout-room-label",
        cut = { 0.36, 0.64 },
        h = 100,
        mid = 0.505,
        band = 0.65,
        size = 22,
    },
    slate = {
        atlas = "craftingorders-header-frame",
        kind = "plate",
        cut = { 0.02, 0.98 },
        h = 48,
        mid = 0.5,
        size = 22,
    },
    -- only the two scrolls and the edges keep their width, the plain leather
    -- around the scrolls stretches
    questlog = {
        atlas = "questlog-reward-header-top",
        kind = "plate",
        cut = { 0.02, 0.12, 0.34, 0.66, 0.88, 0.98 },
        h = 44,
        mid = 0.5,
        size = 20,
    },
    amber = { atlas = "friends-raf-headerbg", kind = "plate", cut = { 0.06, 0.94 }, h = 64, mid = 0.5 },
    walnut = { atlas = "vas-bg-header", kind = "plate", cut = { 0.03, 0.97 }, h = 56, mid = 0.5, size = 22 },
    -- The renown celebration toast, squeezed: its medallion over the top of the
    -- dark band and the gold line along the bottom of it.
    celebration = {
        h = 108,
        ny = -12,
        layers = {
            { atlas = "evergreen-toast-celebration-bg", kind = "plate", cut = { 0.18, 0.82 }, h = 50, top = 40 },
            { atlas = "evergreen-toast-celebration-topfiligree", cut = { 0.15, 0.85 }, h = 56, top = 0, wide = true },
            {
                atlas = "evergreen-toast-celebration-bottomline",
                cut = { 0.24, 0.76 },
                scale = 0.8,
                top = 74,
                wide = true,
            },
        },
    },
    -- The scenario tracker's plate for the last stage. The game hangs the
    -- filigree 10 pixels left of the plate and 3 above it.
    midnightgem = {
        h = 64,
        ny = 0,
        layers = {
            { atlas = "midnight-scenario-trackerheader", kind = "plate", cut = { 0.05, 0.95 } },
            {
                atlas = "midnight-scenario-trackerheader-final-filigree",
                kind = "plate",
                cut = { 0.13, 0.87 },
                x = -10,
                extra = 31,
                top = -2.5,
            },
        },
    },
    gildedplate = {
        h = 64,
        ny = 0,
        layers = {
            { atlas = "evergreen-scenario-trackerheader", kind = "plate", cut = { 0.05, 0.95 } },
            {
                atlas = "evergreen-scenario-trackerheader-final-filigree",
                kind = "plate",
                cut = { 0.19, 0.81 },
                x = -10,
                extra = 11,
                top = -2.4,
            },
        },
    },
}

-- The window title frames, each a left and a right half. The gilt ones fade
-- out at the join, so their fade is cut off and the solid part stretches over
-- it.
local HALVES = {
    kyrianframe = { "UI-Frame-Kyrian", 0.45, 1 },
    nightfaeframe = { "UI-Frame-NightFae", 0.48, 1 },
    venthyrframe = { "UI-Frame-Venthyr", 0.3, 1 },
    necrolordframe = { "ui-frame-necrolord", 0.35, 1 },
    oribosframe = { "UI-Frame-Oribos", 0.45, 1 },
    mechagonframe = { "UI-Frame-Mechagon", 0.2, 0.82 },
    dragonflightframe = { "ui-frame-dragonflight", 0.45, 1 },
    warwithinframe = { "ui-frame-thewarwithin", 0.48, 1 },
    midnightframe = { "ui-frame-midnight", 0.45, 1 },
    giltalliance = { "UI-Frame-Alliance", 0.18, 0.82 },
    gilthorde = { "UI-Frame-Horde", 0.18, 0.82 },
    giltneutral = { "ui-frame-neutral", 0.18, 0.82 },
    giltmarine = { "UI-Frame-Marine", 0.18, 0.82 },
}
for name, f in pairs(HALVES) do
    GAME[name] = {
        atlas = f[1] .. "-TitleLeft",
        right = f[1] .. "-TitleRight",
        kind = "halves",
        cut = { f[2], f[3] },
        h = 64,
        mid = 0.5,
        size = 22,
    }
end

-- The window title ribbons, one parchment in seven dyes.
for _, dye in ipairs({ "Horde", "Marine", "Venthyr", "Kyrian", "necrolord", "NightFae", "dragonflight" }) do
    local name = dye == "Horde" and "titlegold" or "title" .. dye:lower()
    GAME[name] = {
        atlas = "UI-Frame-" .. dye .. "-Ribbon",
        kind = "plate",
        cut = { 0.14, 0.86 },
        h = 64,
        mid = 0.47,
        size = 20,
        ink = INK,
    }
end

-- The glow under a window's subtitle.
for _, glow in ipairs({ "horde", "alliance", "kyrian", "necrolord", "nightfae", "mechagon", "midnight", "dragonflight" }) do
    GAME["glow" .. glow] =
        { atlas = "ui-frame-" .. glow .. "-subtitle", kind = "stretch", h = 36, mid = 0.5, band = 0.7, size = 20 }
end

-- The Legion artifact window's title, the class's line under the name. Every
-- line sits 37 pixels down its own texture, since the game hangs them all from
-- the top, so at LINE_SCALE they all land at 38. The window's own dark header
-- has square ends that only a full window hides, so the celebration toast's
-- band sits behind the name instead.
local LINE_SCALE = 0.6
local CLASS_LINES = {
    deathknight = "DeathKnightFrost",
    demonhunter = "DemonHunter",
    druid = "Druid",
    hunter = "Hunter",
    mage = "MageArcane",
    monk = "Monk",
    paladin = "Paladin",
    priest = "Priest",
    rogue = "Rogue",
    shaman = "Shaman",
    warlock = "Warlock",
    warrior = "Warrior",
}
for class, art in pairs(CLASS_LINES) do
    GAME["class" .. class] = {
        h = 64,
        ny = 12,
        band = 0.7,
        lead = 2, -- the line sets the width and the band stretches along it
        layers = {
            { atlas = "evergreen-toast-celebration-bg", kind = "plate", cut = { 0.18, 0.82 }, h = 44, top = 0 },
            {
                atlas = "Artifacts-" .. art .. "-Header",
                kind = "stretch",
                scale = LINE_SCALE,
                top = 38 - 37 * LINE_SCALE,
            },
        },
    }
end

-- Part of the atlas a, from x1 to x2 across it, drawn w by h.
local function Slice(t, a, x1, x2, w, h)
    local u = a.rightTexCoord - a.leftTexCoord
    t:SetTexture(a.file)
    t:SetTexCoord(a.leftTexCoord + u * x1, a.leftTexCoord + u * x2, a.topTexCoord, a.bottomTexCoord)
    t:SetVertexColor(1, 1, 1)
    t:SetSize(w, h)
    t:ClearAllPoints()
    t:Show()
end

-- A layer's pieces as { atlas, from, to, stretches }. A plate's run kept,
-- stretching, kept and so on for as many cuts as it has, a title's the other
-- way round.
local function Pieces(l)
    local a, r, c = l.info, l.rinfo, l.cut
    if l.kind == "halves" then
        return { { a, 0, c[1] }, { a, c[1], c[2], true }, { r, 1 - c[2], 1 - c[1], true }, { r, 1 - c[1], 1 } }
    elseif l.kind == "stretch" then
        return { { a, 0, 1, true } }
    end
    local pieces, from, grow = {}, 0, l.kind ~= "plate"
    for i = 1, #c + 1 do
        local to = c[i] or 1
        pieces[i] = { a, from, to, grow }
        from, grow = to, not grow
    end
    return pieces
end

-- How wide a layer's pieces draw at scale s, all of them and the stretching
-- ones.
local function Widths(l, s)
    local all, grow = 0, 0
    for _, p in ipairs(l.pieces) do
        local pw = (p[3] - p[2]) * p[1].width * s
        all = all + pw
        grow = p[4] and grow + pw or grow
    end
    return all, grow
end

local PLATE_PAD = 14

-- A layer's scale, s0 being the first layer's.
local function Scale(l, s0)
    return l.h and l.h / l.info.height or l.scale or s0
end

-- The textures game art draws with, made as a style needs them.
local function GameTex(b, n)
    local t = b.gameTex[n]
    if not t then
        t = b:CreateTexture(nil, "BACKGROUND")
        b.gameTex[n] = t
        b.parts[#b.parts + 1] = t
    end
    return t
end

local function DrawGame(b, read, g)
    Font(b, MORPHEUS, g.size or 24, "", g.ink and 0 or 1)
    local gw = PlaceGroup(b, read, 0, g.ny)
    local first = g.layers[1]
    local s0 = (first.h or g.h) / first.info.height
    local lead = g.layers[g.lead or 1]
    local full, middle = Widths(lead, Scale(lead, s0))
    local need
    if lead.kind == "plate" or lead.kind == "halves" then
        -- the name gets only the stretching middle since the ends keep their ornaments
        need = full - middle + gw + 2 * PLATE_PAD
    else
        need = gw / g.band + 40
    end
    local w = math.max(full, need)
    b:SetSize(w, g.h)
    local n = 0
    for i, l in ipairs(g.layers) do
        local s = Scale(l, s0)
        local all, grow = Widths(l, s)
        local lw = w + (l.extra or 0) * s + (l.wide and all - full or 0)
        local k = (lw - all + grow) / grow
        local lh = l.info.height * s
        local x = l.x and l.x * s or (w - lw) * 0.5
        local top = l.top or (g.h - lh) * 0.5
        for _, p in ipairs(l.pieces) do
            local pw = (p[3] - p[2]) * p[1].width * s * (p[4] and k or 1)
            n = n + 1
            local t = GameTex(b, n)
            Slice(t, p[1], p[2], p[3], pw, lh)
            t:SetDrawLayer("BACKGROUND", i)
            t:SetPoint("TOPLEFT", x, -top)
            x = x + pw
        end
    end
    return g.ink
end

for name, g in pairs(GAME) do
    if g.atlas then
        g.layers = { { atlas = g.atlas, right = g.right, kind = g.kind, cut = g.cut } }
        g.ny = (0.5 - g.mid) * g.h
    end
    local found = true
    for _, l in ipairs(g.layers) do
        l.info = C_Texture.GetAtlasInfo(l.atlas)
        l.rinfo = l.right and C_Texture.GetAtlasInfo(l.right)
        found = found and l.info ~= nil and (l.right == nil or l.rinfo ~= nil)
        if found then
            l.pieces = Pieces(l)
        end
    end
    STYLES[name] = found and function(b, _, read)
        return DrawGame(b, read, g)
    end or STYLES.classic
end

function CH.BannerStyleName(style)
    return CH.L["SET_BANNER_" .. style:upper()]
end

-- The colour of a family's ith chip in the picker. The class lines have none
-- listed and take the class's own colour, class plus its token.
function CH.BannerChip(family, i)
    if family.chips then
        return family.chips[i]
    end
    local c = RAID_CLASS_COLORS[family.styles[i]:sub(6):upper()]
    return { c.r, c.g, c.b }
end

-- The line under a style's name in the picker.
function CH.BannerStyleNote(style)
    if style == "zone" or style == "original" or style == "classic" then
        return "BP_NOTE_" .. style:upper()
    end
    local a = ART[style] or GAME[style]
    if a and a.ink then
        return "BP_NOTE_OWN"
    end
    return GAME[style] and "BP_NOTE_GAME" or "BP_NOTE_TINT"
end

-- Draw name in colour c (nil for the default gold) in style, with or without
-- the Read button.
function CH.PaintBanner(b, name, c, read, style)
    for _, part in ipairs(b.parts) do
        part:Hide()
    end
    local tc = c or CH.COLORS.bannerText
    local lc = c or CH.COLORS.line
    b.name:SetText(name)
    -- b.read is whichever button this style uses, and the layouts place it
    local old = style == "original"
    b.read = old and b.oldRead or b.book
    b.book:SetShown(read and not old)
    b.oldRead:SetShown(read and old)
    local draw = STYLES[style] or STYLES.classic
    -- art with its own colours hands back the ink for the name and the book
    local ink = draw(b, lc, read)
    b.book:Tint(ink or lc)
    tc = ink or tc
    b.name:SetTextColor(tc[1], tc[2], tc[3], 1)
end

-- ── The banner itself ────────────────────────────────────────────────

CH.banner = CH.MakeBanner(UIParent, function()
    CH.OpenYapper()
end)
local banner = CH.banner
banner:SetFrameStrata("HIGH")
banner:SetAlpha(0)
banner:Hide() -- hidden until a room is entered; see CH.ShowBanner/CH.HideBanner

-- Track the room the banner is currently annoucing and draw it in the chosen
-- style. The Read button shows when the room has a description.
function CH.SetBannerRoom(zone)
    CH.bannerRoom = zone
    if not zone then
        banner.book:Hide()
        banner.oldRead:Hide()
        return
    end
    local read = zone.rpText ~= nil and zone.rpText ~= "" and ChamberlainDB.settings.showRoomText
    CH.PaintBanner(banner, zone.name, zone.color, read, CH.HouseBannerStyle(CH.currentHouseGUID))
end

-- The owner's pick for the house wins over yours, unless you keep your own in
-- other houses. Your own house's pick always shows, or picking a style there
-- would change nothing you can see.
function CH.HouseBannerStyle(guid)
    local s = ChamberlainDB.settings
    local h = ChamberlainDB.houses[guid]
    if h and h.bannerStyle and (ChamberlainDB.myHouses[guid] or not s.ownBannerStyle) then
        return h.bannerStyle
    end
    return s.bannerStyle
end

-- Settings calls this when the style changes, so a banner that's up redraws.
function CH.RefreshBanner()
    if CH.bannerRoom then
        CH.SetBannerRoom(CH.bannerRoom)
    end
end

-- Every sample from CH.MakeBannerStylePicker, repainted when the style changes.
local samples = {}

local function StyleChanged()
    for _, p in ipairs(samples) do
        p:Refresh()
    end
    CH.RefreshBanner()
end

-- Your own style, from the picker window.
function CH.SetBannerStyle(style)
    ChamberlainDB.settings.bannerStyle = style
    StyleChanged()
end

-- The owner picking the house's style, nil to leave it to each visitor. The
-- group gets it as a patch like the arrival sound, see CH.SendSoundPatch.
function CH.SetHouseBanner(guid, style)
    local h = ChamberlainDB.houses[guid]
    if h.bannerStyle == style then
        return
    end
    local baseTs = h.updatedAt
    h.bannerStyle = style
    CH.TouchHouse(guid)
    StyleChanged()
    CH.SendSoundPatch(guid, "banner", baseTs, "H", CH.BANNER_ID[style], true)
end

-- Standing in a house of yours, Settings and What's New pick that house's
-- style. Anywhere else they pick your own.
local function OwnHouseHere()
    local guid = CH.currentHouseGUID
    return CH.isOwnHouse and ChamberlainDB.houses[guid] and guid or nil
end

-- A sample banner in the chosen style with a button that opens the picker, h
-- tall, the one Settings and What's New both show. p:Refresh() syncs it to
-- the house's style or yours, see OwnHouseHere.
function CH.MakeBannerStylePicker(parent, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(h)
    local sample = CH.MakeBanner(p)
    sample:SetPoint("CENTER", 0, -12)
    sample:SetScale(0.85)

    local choose = CH.MakeButton(p, "SET_BANNER_CHOOSE", 140, 22)
    choose:SetPoint("TOPRIGHT")
    choose:SetScript("OnClick", function()
        CH.OpenBannerPicker(OwnHouseHere())
    end)

    function p.Refresh()
        local guid = OwnHouseHere()
        local style = guid and ChamberlainDB.houses[guid].bannerStyle or ChamberlainDB.settings.bannerStyle
        CH.PaintBanner(sample, CH.L["SET_BANNER_SAMPLE"], nil, true, style)
    end
    samples[#samples + 1] = p
    return p
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
