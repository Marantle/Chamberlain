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

-- The most a room's yapper text holds, in the editors and off the wire.
CH.DESC_MAX = 500

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

-- The themed rooms keep the sizes they were walked at, and only the door is
-- sure to land on a grid line. They're artisanal: the game builds each at
-- one size, so it moves and turns but never resizes. The first two were
-- walked, and their cuts and boxes are in yards from the box's low x, low y
-- corner as the room stood when walked.
local function Yards(side)
    return function(x0, y0, x1, y1)
        return { x0 / side, y0 / side, x1 / side, y1 / side }
    end
end
-- The Autumnal Westfall Barn, walked on 2026-10-01, door on the high y side
-- and the raised stall bay along the low x side.
local BARN = 43.2
local Barn = Yards(BARN)
-- The Stormwind Display Room, walked on 2026-10-02. A small room's square on
-- the grid with an alcove across the far wall and the door in the middle of
-- the low y side, opening onto a sunken landing.
local DISPLAY = SPAN
local Display = Yards(DISPLAY)
-- The rest were measured off the game's own room models in October 2026.
-- Each wall's inner face is pushed out half a yard to the line two rooms
-- share, where a square room's wall sits. The door side stays on the door.
-- They're w by h with the door on the low y side door yards along it, and the
-- cuts are in yards from the low x, low y corner. drawn says the floor has
-- steps or a railing to show, drawn into <mask>.png.
local function Artisanal(mask, w, h, door, cuts, drawn)
    local def = {
        w = w,
        h = h,
        rotates = true,
        artisanal = true,
        mask = CH.MEDIA .. "mask-" .. mask,
        deco = drawn and CH.MEDIA .. mask .. ".png" or nil,
        cuts = {},
        doors = { { door / w, 0 } },
    }
    for i, c in ipairs(cuts) do
        def.cuts[i] = { c[1] / w, c[2] / h, c[3] / w, c[4] / h }
    end
    return def
end
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
    -- A stairwell is a small square with its steps drawn on it (art) and one
    -- door, in the middle of the open side between the foot of the steps and
    -- the landing, the same on both floors. The left one is the right one
    -- mirrored.
    stairR = { w = STEPS[1], h = STEPS[1], rotates = true, art = "right", stack = true, doors = { { 0.5, 0 } } },
    stairL = { w = STEPS[1], h = STEPS[1], rotates = true, art = "left", stack = true, doors = { { 0.5, 0 } } },
    -- the empty stairwell, a plain small square that copies onto the next
    -- floor like the others and nothing more
    stairE = { w = STEPS[1], h = STEPS[1], stack = true },
    -- deco is drawn over the fill like a stairwell's steps, but it's no
    -- stairwell, so nothing stacks it. loft is the plain room Smart drop puts
    -- on the floor above, a room of its own from then on. parts are the
    -- stairs CH.BuildParts makes of it, up floors above the barn's own and
    -- going to the barn's floor plus to.
    barn = {
        w = BARN,
        h = BARN,
        rotates = true,
        artisanal = true,
        loft = Barn(30.7, 0, BARN, 39.3),
        parts = {
            { box = Barn(36.6, 27.6, 43.1, 29.6), up = 0, to = 1 },
            { box = Barn(36.6, 29.5, 43.1, 39.5), up = 1, to = 0 },
        },
        mask = CH.MEDIA .. "mask-barn",
        deco = CH.MEDIA .. "barn.png",
        cuts = {
            Barn(0, 0, 11.1, 7.9),
            Barn(0, 31.7, 11.1, 39.2),
            Barn(0, 39.2, 16.8, BARN),
            Barn(31.2, 39.2, BARN, BARN),
        },
        doors = { { 24 / BARN, 1 } },
    },
    display = {
        w = DISPLAY,
        h = DISPLAY,
        rotates = true,
        artisanal = true,
        mask = CH.MEDIA .. "mask-display",
        deco = CH.MEDIA .. "display.png",
        cuts = { Display(0, 21.5, 3, DISPLAY), Display(21, 21.5, DISPLAY, DISPLAY) },
        doors = { { 0.5, 0 } },
    },
    -- the Kitchen's two side bays are in the cuts' gaps
    swKitchen = Artisanal("swkitchen", 24, 22.87, 12, {
        { 0, 12.75, 2, 22.75 },
        { 22, 12.75, 24, 22.75 },
        { 0, 0, 2, 3 },
        { 22, 0, 24, 3 },
    }, true),
    -- the Stormwind Armory's walls were walked in game, they sit wider than the
    -- model said and its door ends up near the middle
    swArmory = Artisanal("swarmory", 36.2, 35.54, 17.9, {
        { 32, 24.5, 36.25, 35.5 },
        { 0, 32, 12, 35.5 },
        { 24, 32, 32, 35.5 },
        { 0, 23.75, 3.25, 32 },
        { 0, 0, 4, 6.25 },
        { 32, 0, 36.25, 5.5 },
    }, true),
    swGrandHall = Artisanal("swgrandhall", 45.5, 46.6, 22.75, {
        { 0, 38.5, 14, 46.5 },
        { 31.5, 38.5, 45.5, 46.5 },
        { 0, 0, 5, 8 },
        { 40.5, 0, 45.5, 8 },
        { 0, 31.75, 5, 38.5 },
        { 40.5, 31.75, 45.5, 38.5 },
    }, true),
    -- the Bel'ameth rooms round their corners off, too little for a cut
    beBedroom = Artisanal("bebedroom", 23, 22.7, 11.5, {}),
    beTheater = Artisanal("betheater", 23, 22.76, 11.5, {}, true),
    beMeeting = Artisanal("bemeeting", 33.5, 35.01, 16.75, {
        { 0, 0, 4.25, 25 },
        { 29.25, 0, 33.5, 25 },
    }),
    -- most of the Temple Room's floor is a terrace three yards up
    beTemple = Artisanal("betemple", 48, 48.76, 24, {
        { 0, 14, 3.25, 19.5 },
        { 44.75, 14, 48, 19.5 },
        { 0, 29.25, 3, 35 },
        { 45, 29.25, 48, 35 },
        { 0, 0, 4, 4.25 },
        { 44, 0, 48, 4.25 },
    }, true),
    ogCouncil = Artisanal("ogcouncil", 45, 45.71, 22.5, {
        { 0, 0, 7.75, 7 },
        { 37.25, 0, 45, 7 },
        { 0, 39, 7.25, 45.75 },
        { 37.75, 39, 45, 45.75 },
        { 0, 7, 4.5, 10 },
        { 40.5, 7, 45, 10 },
        { 0, 35.5, 3.75, 39 },
        { 41.25, 35.5, 45, 39 },
        { 7.75, 0, 11, 3.75 },
        { 34, 0, 37.25, 3.75 },
    }, true),
    ogStonePit = Artisanal("ogstonepit", 23.5, 21.25, 11.75, {}),
    ogTheater = Artisanal("ogtheater", 36.5, 35.18, 18.25, {
        { 0, 0, 5, 14.5 },
        { 31.5, 0, 36.5, 14.5 },
        { 0, 30.5, 14.25, 35.25 },
        { 22.25, 30.5, 36.5, 35.25 },
        { 5, 0, 13, 5.5 },
        { 23.5, 0, 31.5, 5.5 },
        { 0, 22, 5, 30.5 },
        { 31.5, 22, 36.5, 30.5 },
        { 5, 5.5, 8, 7.5 },
        { 28.5, 5.5, 31.5, 7.5 },
    }, true),
    ogDisplay = Artisanal("ogdisplay", 23, 21.48, 11.5, {}),
    smArmory = Artisanal("smarmory", 31.5, 33.28, 15.75, {
        { 0, 0, 10.5, 2.5 },
        { 21, 0, 31.5, 2.5 },
    }),
    smLoftyStudy = Artisanal("smloftystudy", 46.5, 47.25, 23.25, {
        { 0, 0, 8, 8.5 },
        { 38.5, 0, 46.5, 8.5 },
        { 0, 39.25, 7.75, 47.25 },
        { 38.75, 39.25, 46.5, 47.25 },
        { 8, 0, 18.25, 2.25 },
        { 28.25, 0, 38.5, 2.25 },
        { 0, 29, 2, 39.25 },
        { 44.5, 29, 46.5, 39.25 },
    }, true),
    -- the Lofty Study's loft over its far half and the spiral up to it
    smLoftyLoft = Artisanal("smloftyloft", 46.5, 31.04, 0, {
        { 0, 22.75, 7.5, 31 },
        { 39, 22.75, 46.5, 31 },
        { 4.75, 0, 16.5, 4.5 },
        { 30.25, 0, 41.25, 4.75 },
        { 0, 12.75, 2, 22.75 },
        { 44.5, 12.75, 46.5, 22.75 },
    }),
    smDisplay = Artisanal("smdisplay", 21.5, 22.39, 10.75, {
        { 0, 0, 6, 3 },
        { 15.5, 0, 21.5, 3 },
    }),
    smSmallStudy = Artisanal("smsmallstudy", 23.51, 22.8, 11.75, {
        { 0, 0, 2, 6 },
        { 21.5, 0, 23.5, 6 },
        { 0, 17, 2, 22.75 },
        { 21.5, 17, 23.5, 22.75 },
    }),
}

-- The Lofty Study puts its loft on the floor above like the barn, in the
-- loft's own shape, which comes with the room and has no door to snap to.
-- spiral is where its stair goes round, in yards at turn 0: the centre, the
-- steps between r0 and r1 out, starting at angle from and climbing sweep
-- degrees round with the angle falling. The centre is off points walked round
-- the post, and r0 is the post's edge as the map draws it.
CH.SHAPES.smLoftyLoft.doors = {}
CH.SHAPES.smLoftyStudy.loft = { 0, 16.21 / 47.25, 1, 1 }
CH.SHAPES.smLoftyStudy.loftShape = "smLoftyLoft"
CH.SHAPES.smLoftyStudy.spiral = { s = 23.3, t = 23.81, r0 = 3, r1 = 7.6, from = 35, sweep = 235 }

-- The shapes as the build rail and the room dialog offer them, in order, with
-- the icon and the name a fresh room takes. A plain room has no shape. record
-- is the game room whose name a new room takes when Game room names is on,
-- the smallest one where the game sells sizes.
CH.SHAPE_LIST = {
    { icon = "icon-square", name = "TB_ADD_SQUARE", record = 7 },
    { shape = "L", icon = "icon-l", name = "TB_ADD_L", record = 8 },
    { shape = "T", icon = "icon-t", name = "TB_ADD_T", record = 6 },
    { shape = "plus", icon = "icon-plus", name = "TB_ADD_PLUS", record = 13 },
    { shape = "oct", icon = "icon-oct", name = "TB_ADD_OCT", record = 14 },
    { shape = "circle", icon = "icon-circle", name = "TB_ADD_CIRCLE", record = 223 },
    { shape = "closet", icon = "icon-closet", name = "TB_ADD_CLOSET", record = 3 },
    { shape = "hall", icon = "icon-hall", name = "TB_ADD_HALL", record = 2 },
}

-- The game's name for one of its rooms in the client's language, nil if the
-- catalog doesn't have it. A square or an octagon carries its size in
-- brackets at the end, like Square Room (Small), and a Chinese client uses
-- full width brackets. Rooms resize so the size goes. Russian puts the size
-- in front as a word and keeps it. Other names stay whole since the two
-- round rooms might be told apart by a bracket.
function CH.GameRoomName(record)
    local entry = C_HousingCatalog.GetCatalogEntryInfoByRecordID(Enum.HousingCatalogEntryType.Room, record)
    if not entry then
        return nil
    end
    if not CH.GAME_ROOMS[record].size then
        return entry.name
    end
    return (entry.name:gsub("%s*%b()$", ""):gsub("%s*（.-）$", ""))
end

function CH.ShapeEntry(shape)
    for _, e in ipairs(CH.SHAPE_LIST) do
        if e.shape == shape then
            return e
        end
    end
end

-- What a room of this shape is called, a square room for one not on the
-- build rail.
function CH.ShapeName(shape)
    local e = CH.ShapeEntry(shape) or CH.SHAPE_LIST[1]
    return ChamberlainDB.settings.gameRoomNames and CH.GameRoomName(e.record) or CH.L[e.name]
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

-- The game's rooms smart drop knows, by the room's catalog record, which is
-- also the middle number of its room id (Housing-2-<record>-<slot>). A size
-- is the side of a plain room or an octagon. The Entry (46) isn't sold and
-- has no catalog record. Of the themed rooms only the two Riverside rooms
-- are missing, because the game has no room data for them yet.
CH.GAME_ROOMS = {
    [7] = { size = CORE },
    [1] = { size = STEPS[1] },
    [11] = { size = STEPS[2] },
    [12] = { size = STEPS[3] },
    -- the stairwells keep the game's name so they don't pass for plain rooms
    [10] = { shape = "stairL", gameName = true },
    [50] = { shape = "stairR", gameName = true },
    [48] = { shape = "stairE", gameName = true },
    [3] = { shape = "closet" },
    [2] = { shape = "hall" },
    [8] = { shape = "L" },
    [6] = { shape = "T" },
    [13] = { shape = "plus" },
    [14] = { shape = "oct", size = STEPS[1] },
    [9] = { shape = "oct", size = STEPS[2] },
    [15] = { shape = "oct", size = STEPS[3] },
    -- two round rooms the same shape, told apart by the game's name
    [223] = { shape = "circle", gameName = true },
    [233] = { shape = "circle", gameName = true },
    -- the Autumnal and the Springtime barn, the same room
    [400] = { shape = "barn", gameName = true },
    [401] = { shape = "barn", gameName = true },
    [281] = { shape = "display", gameName = true },
    [277] = { shape = "swKitchen", gameName = true },
    [273] = { shape = "swArmory", gameName = true },
    [282] = { shape = "swGrandHall", gameName = true },
    [290] = { shape = "beBedroom", gameName = true },
    [289] = { shape = "beTheater", gameName = true },
    [288] = { shape = "beMeeting", gameName = true },
    [287] = { shape = "beTemple", gameName = true },
    [132] = { shape = "ogCouncil", gameName = true },
    [151] = { shape = "ogStonePit", gameName = true },
    [292] = { shape = "ogTheater", gameName = true },
    [294] = { shape = "ogDisplay", gameName = true },
    [283] = { shape = "smArmory", gameName = true },
    [285] = { shape = "smLoftyStudy", gameName = true },
    [286] = { shape = "smDisplay", gameName = true },
    [307] = { shape = "smSmallStudy", gameName = true },
}
CH.ENTRY_ROOM = 46
-- where the Entry sits in every house, and the map's entrance closet with it
CH.ENTRANCE_X, CH.ENTRANCE_Y = -1000, -1000
-- Every game room is a multiple of six yards and joins door to door, so a
-- house's walls look to fall on lines every GRID yards along the entrance
-- closet's walls, 12 by 6 about its middle. Not proven past a couple of rooms
-- measued. The map draws the lines and Snap puts rooms on them.
CH.GRID = 6
CH.GRID_X, CH.GRID_Y = CH.ENTRANCE_X, CH.ENTRANCE_Y + 3
