local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Shared colors and backdrop presets
-- ─────────────────────────────────────────────────────────────────────
-- The same handful of gold/bronze tones were copied as raw numbers all over
-- the UI. They live here now so a palette tweak is one edit. Stored as {r,g,b};
-- pass your own alpha at the call site (SetColorTexture/SetBackdropColor take 4).

CH.COLORS = {
    gold = { 1.00, 0.90, 0.30 }, -- bright gold: section headers
    frame = { 0.85, 0.70, 0.15 }, -- window border and header underline
    border = { 0.55, 0.45, 0.15 }, -- bronze control border: swatches, buttons
    sep = { 0.55, 0.50, 0.10 }, -- faint divider lines
    grey = { 0.25, 0.25, 0.25 }, -- "no color set" placeholder swatch
    muted = { 0.75, 0.75, 0.75 }, -- muted label text
    dim = { 0.60, 0.60, 0.60 }, -- dimmer secondary text
    tipGold = { 1.00, 0.82, 0.00 }, -- tooltip title gold
    line = { 0.85, 0.75, 0.15 }, -- banner and talking-head accent line
    bannerText = { 1.00, 0.92, 0.40 }, -- banner and talking-head name text
}

-- 1px white-fill backdrop used by most of our flat frames. SetBackdrop copies
-- the table, so sharing one instance across frames is safe.
CH.BACKDROP_THIN = {
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
}

-- Spread a {r,g,b} palette entry plus an alpha into the four args the color
-- setters want: CH.RGBA(CH.COLORS.frame, 0.8) -> r, g, b, 0.8
function CH.RGBA(c, a)
    return c[1], c[2], c[3], a
end

CH.MEDIA = "Interface\\AddOns\\Chamberlain\\Media\\"

-- The rooms the game builds, measured in a house in September 2026, wall to
-- wall. Two rooms the game joins share a wall, so at these sizes their boxes
-- touch and the doorway between them is in one room or the other, never in
-- neither. A player can't stand closer than WALL to a wall, so the fit tools
-- put the wall that far past where you stand. Every cross shape is a CORE
-- square with ARM long stubs, and the game's squares and octagons grow by
-- two ARM a step.
CH.WALL = 0.8
local CORE, ARM = 12, 6
local SIDE = CORE + ARM -- an L's side, a T's short side
local SPAN = CORE + 2 * ARM -- a T's long side, a plus's side
local STEPS = { SPAN, SPAN + 2 * ARM, SPAN + 4 * ARM }

-- A room with a shape keeps it: it scales as a whole and an L or a T turns in
-- quarters (zone.rot, 0 to 3). Its box in the saved data is the turned box,
-- so everything that reads minX..maxY still works. cuts are the corners the
-- box lacks at turn 0, as fractions of it {x0, y0, x1, y1}, and diag is an
-- octagon's corner cut along each axis. compact shapes go on the wire as
-- centre, scale and turn instead of a box. mask cuts the map tile, and a
-- shape that turns has a file per turn, mask-l0.tga to mask-l3.tga.
-- doors are where the game puts the doorways, on the box edge at turn 0. An
-- arm is only core wide, so the doors at the end of an L's or a T's side arms
-- sit off the middle, in the middle of the arm. A shape with no doors list
-- gets one in the middle of each side.
local a, b = ARM / SIDE, ARM / SPAN
local armMid = (1 + a) / 2
CH.SHAPES = {
    L = {
        w = SIDE,
        h = SIDE,
        rotates = true,
        compact = true,
        mask = CH.MEDIA .. "mask-l",
        cuts = { { 0, 0, a, a } },
        doors = { { 0, armMid }, { armMid, 0 } },
    },
    T = {
        w = SPAN,
        h = SIDE,
        rotates = true,
        compact = true,
        mask = CH.MEDIA .. "mask-t",
        cuts = { { 0, 0, b, a }, { 1 - b, 0, 1, a } },
        doors = { { 0, armMid }, { 1, armMid }, { 0.5, 0 } },
    },
    plus = {
        w = SPAN,
        h = SPAN,
        compact = true,
        mask = CH.MEDIA .. "mask-plus.tga",
        cuts = { { 0, 0, b, b }, { 1 - b, 0, 1, b }, { 0, 1 - b, b, 1 }, { 1 - b, 1 - b, 1, 1 } },
    },
    oct = {
        w = SPAN,
        h = SPAN,
        diag = 0.3,
        mask = CH.MEDIA .. "mask-oct.tga",
        sizes = { { "TB_SIZE_SMALL", STEPS[1] }, { "TB_SIZE_MEDIUM", STEPS[2] }, { "TB_SIZE_LARGE", STEPS[3] } },
    },
    circle = { w = 46.2, h = 46.2, mask = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask" },
    -- plain boxes with no mask, doors on the ends only. A hall is four closets
    -- back to back
    closet = { w = CORE, h = ARM, rotates = true, doors = { { 0.5, 0 }, { 0.5, 1 } } },
    hall = { w = CORE, h = 2 * CORE, rotates = true, doors = { { 0.5, 0 }, { 0.5, 1 } } },
}

-- The shapes as the build rail and the room dialog offer them, in order, with
-- the icon and the name a fresh room takes. A plain room has no shape.
CH.SHAPE_LIST = {
    { icon = "icon-square", name = "TB_ADD_SQUARE" },
    { shape = "L", icon = "icon-l", name = "TB_ADD_L" },
    { shape = "T", icon = "icon-t", name = "TB_ADD_T" },
    { shape = "plus", icon = "icon-plus", name = "TB_ADD_PLUS" },
    { shape = "oct", icon = "icon-oct", name = "TB_ADD_OCT" },
    { shape = "circle", icon = "icon-circle", name = "TB_ADD_CIRCLE" },
    { shape = "closet", icon = "icon-closet", name = "TB_ADD_CLOSET" },
    { shape = "hall", icon = "icon-hall", name = "TB_ADD_HALL" },
}

function CH.ShapeEntry(shape)
    for _, e in ipairs(CH.SHAPE_LIST) do
        if e.shape == shape then
            return e
        end
    end
end

-- How much of its box a shape fills, for picking the smallest room.
for _, def in pairs(CH.SHAPES) do
    local keep = 1
    for _, c in ipairs(def.cuts or {}) do
        keep = keep - (c[3] - c[1]) * (c[4] - c[2])
    end
    if def.diag then
        keep = 1 - 2 * def.diag * def.diag
    end
    def.keep = keep
end
CH.SHAPES.circle.keep = math.pi / 4

-- A plain room has no shape and its walls move one by one. These are only the
-- sizes it starts at, the game's four squares.
CH.SQUARE_SIZES = {
    { "TB_SIZE_TINY", CORE },
    { "TB_SIZE_SMALL", STEPS[1] },
    { "TB_SIZE_MEDIUM", STEPS[2] },
    { "TB_SIZE_LARGE", STEPS[3] },
}
