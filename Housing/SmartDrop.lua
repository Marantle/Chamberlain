local _, CH = ...

-- Smart drop maps the game room you stand in with one click. The room's id
-- names its type and CH.GAME_ROOMS turns that into our shape and size. The
-- room then goes onto an open door of a room already on the map, at the turn
-- that has you inside it. The game won't tell an addon where its rooms are or wich
-- way they face, so the doors and your spot are all there is to go on.

-- The room smart drop placed last, followed while you're still in its game
-- room. The turn it picked is a guess from where you stood, so every spot you
-- walk to after goes on its list, and a spot outside the room makes it look
-- again for a turn and a door that hold them all.
local watch

-- Where watch last put the room, so a move, a resize or a turn of your own
-- ends it.
local function Mark(z)
    watch.box = { z.minX, z.maxX, z.minY, z.maxY, z.rot or 0 }
end

local function Watch(z, room, spots, grid)
    watch = { zone = z, room = room, spots = spots, grid = grid }
    Mark(z)
end

local function Touched(z)
    local b = watch.box
    return z.minX ~= b[1] or z.maxX ~= b[2] or z.minY ~= b[3] or z.maxY ~= b[4] or (z.rot or 0) ~= b[5]
end

local function Follow(room)
    local z = watch.zone
    local h = CH.CurrentHouse()
    local kept = tIndexOf(h.zones, z)
    -- the map lock stops it too, nothing moves on a locked map
    if room ~= watch.room or not kept or Touched(z) or not CH.FP.CanEdit() then
        watch = nil
        return
    end
    local x, y = CH.GetWorldPos()
    local last = watch.spots[#watch.spots]
    if not x or (x - last[1]) ^ 2 + (y - last[2]) ^ 2 < 1 then
        return
    end
    table.insert(watch.spots, { x, y })
    -- a long stay has settled the turn long ago
    if #watch.spots > 60 then
        watch = nil
        return
    end
    if CH.ZoneContains(z, x, y) then
        return
    end
    -- a moved entrance or the first room of a floor has no door to go on,
    -- only the grid
    local first = watch.spots[1]
    local moved
    if watch.grid then
        moved = CH.FitOnGrid(z, watch.spots)
    else
        moved = CH.FitToOpenDoor(h, z, first[1], first[2], watch.spots)
    end
    if moved then
        Mark(z)
        CH.TouchHouse(CH.currentHouseGUID)
    end
end

local function IsStairwell(z)
    local def = z.shape and CH.SHAPES[z.shape]
    return def and def.art ~= nil
end

local function RoomAt(h, floor, x, y)
    for _, o in ipairs(h.zones) do
        if CH.IsRoom(o) and (o.floor or 1) == floor and CH.ZoneContains(o, x, y) then
            return true
        end
    end
end

-- A copy of stairwell z on floor, the map's floors raised to reach it. False
-- when a room is there already.
local function CopyStairwell(h, z, floor)
    if RoomAt(h, floor, CH.ZoneCentre(z)) then
        return false
    end
    h.floorCount = math.max(h.floorCount or 1, floor)
    table.insert(h.zones, {
        name = CH.FreeName(h, z.name),
        mapID = z.mapID,
        shape = z.shape,
        rot = z.rot,
        floor = floor,
        minX = z.minX,
        maxX = z.maxX,
        minY = z.minY,
        maxY = z.maxY,
    })
    return true
end

-- A barn's loft, a plain room of its own on the floor above, unless a room is
-- there already.
local function AddLoft(h, z, box)
    local loft = { name = CH.FreeName(h, z.name), mapID = z.mapID, floor = z.floor + 1 }
    loft.minX, loft.maxX, loft.minY, loft.maxY = CH.ShapeBox(z, box)
    if RoomAt(h, loft.floor, CH.ZoneCentre(loft)) then
        return
    end
    h.floorCount = math.max(h.floorCount or 1, loft.floor)
    table.insert(h.zones, loft)
end

-- The same stairwell on the floors its steps may lead to. On the ground floor
-- that is the one above, added to the map if need be, since the steps can
-- only go up from there. Higher up a stairwell can be either end of its
-- flight and nothing tells which, so it goes on the floor below and the one
-- above both, and the wrong one is deleted by hand. Before 3.41.0 a guess
-- picked one end. The one above only goes on a floor the map
-- already has, so the top floor adds no new one. The game's own floor count
-- was asked before that, and out of the layout editor it answers 99, 0, 0.
-- A floor that has a room there is left alone, so a stairwell already mapped
-- there stays one.
local function OtherEnd(h, z)
    if z.floor > 1 then
        CopyStairwell(h, z, z.floor - 1)
    end
    if z.floor <= 1 or z.floor < (h.floorCount or 1) then
        CopyStairwell(h, z, z.floor + 1)
    end
end

-- The toolbox's up and down arrows: stairwell z again one floor up or down,
-- no matter what the game says, since only the owner knows where they built.
-- step is 1 or -1.
function CH.AddStairwellNextTo(z, step)
    local floor = (z.floor or 1) + step
    if floor < 1 then
        CH.Print(CH.L["TB_STAIRS_NO_BELOW"])
    elseif not CopyStairwell(CH.CurrentHouse(), z, floor) then
        CH.Print(CH.L["TB_STAIRS_TAKEN_X"], floor)
    else
        CH.TouchHouse(CH.currentHouseGUID)
    end
end

local home = {} -- the entrance where the game first builds it

-- Whether you stand in the entrance where the game first builds it, which
-- leaves that box in home.
local function AtHome(x, y)
    local w, hh = CH.ShapeSize("closet", 0)
    CH.BoxAbout(home, CH.ENTRANCE_X, CH.ENTRANCE_Y, w, hh)
    return CH.ZoneContains(home, x, y)
end

-- The catalog record in a game room's id, Housing-2-<record>-<slot>, or nil.
function CH.RoomRecord(room)
    return room and tonumber(room:match("^Housing%-%d+%-(%d+)%-"))
end

-- The game room you stand in, whether it's a stairwell, and your spot and
-- map. Or the chat line that says why not, which comes first.
local function Here()
    local room, stairs = CH.GameRoomHere()
    if not room then
        return "TB_SMART_NOT_IN_ROOM"
    end
    local x, y, mapID = CH.GetWorldPos()
    if not x then
        return "TB_NO_POSITION"
    end
    if not CH.currentHouseGUID then
        return "RD_HOUSE_NOT_IDENTIFIED"
    end
    return nil, room, stairs, x, y, mapID
end

-- The catalog's name for a room we don't know the size of.
local function UnknownName(record)
    local entry = record and C_HousingCatalog.GetCatalogEntryInfoByRecordID(Enum.HousingCatalogEntryType.Room, record)
    return entry and entry.name or CH.L["TB_SMART_THIS_ROOM"]
end

-- Room z, at the game's shape and size about your spot, goes onto an open
-- door or stays at your feet. It takes the game room and what comes with its
-- shape and is followed as you walk. any says the floor has other rooms.
-- False when auto finds no door, else true and whether it stayed at your
-- feet with other rooms about. Smart drop and Match game room both end here.
local function Place(h, z, room, stairs, x, y, any, auto)
    local spots = { { x, y } }
    -- The first room of a floor has no door to go on, so it stays at your
    -- feet, on the grid with Snap on. So does a room with no open door that
    -- fits when you clicked for it (3.45.0). Auto map waits for a door
    -- instead, since a room it drops in a doorway is most often wrong.
    local fitted = any and CH.FitToOpenDoor(h, z, x, y, spots)
    if any and not fitted and auto then
        return false
    elseif not fitted and ChamberlainDB.settings.snapRooms then
        CH.SnapToGrid(z)
    end
    -- a stairwell's id can cover more than one floor, and the floor check would
    -- pull you to this floor from the other one, so it goes in unlinked
    z.gameRoom = not stairs and room or nil
    -- in before its other end or loft, so they don't get its name
    if not tIndexOf(h.zones, z) then
        table.insert(h.zones, z)
    end
    if IsStairwell(z) then
        OtherEnd(h, z)
    end
    local def = z.shape and CH.SHAPES[z.shape]
    if def and def.loft then
        AddLoft(h, z, def.loft)
    end
    CH.TouchHouse(CH.currentHouseGUID)
    CH.SetSelection(z, CH.currentHouseGUID)
    -- A room with one door, like a stairwell or a barn, already told its turn.
    --
    -- A room at your feet follows you on the grid with Snap on, like a moved
    -- entrance. A round room's disc doesn't fill its grid box, so it stays
    -- where it dropped.
    local follow = fitted or ChamberlainDB.settings.snapRooms and z.shape ~= "circle"
    if follow and #CH.ZoneDoors(z) > 1 then
        Watch(z, room, spots, not fitted)
    end
    CH.AutoMapPlaced(z)
    return true, any and not fitted
end

-- Drops the room and returns nothing, or returns the chat line that says why
-- not, or where it went, and its argument. auto leaves the first room of a
-- floor alone, since where you happen to step in is no place to put it.
local function Drop(auto)
    local why, room, stairs, x, y, mapID = Here()
    if why then
        return why
    end
    local h = CH.CurrentHouse()
    local floor = CH.MapFloor()
    local any = false
    for _, z in ipairs(h.zones) do
        if z.gameRoom == room then
            return "TB_SMART_LINKED_X", z.name
        end
        if CH.IsRoom(z) and (z.floor or 1) == floor then
            if z.mapID == mapID and CH.ZoneContains(z, x, y) then
                return "TB_SMART_TAKEN_X", z.name
            end
            any = true
        end
    end

    -- The Entry's own spot is known exactly, so standing in it the entrance
    -- goes there on any map, auto or not, unless a room on this floor already
    -- covers it. Standing anywhere else the owner moved it, and it goes on the
    -- grid where you stand, followed like any other drop. Either way on the
    -- floor you're on, since it can be moved to another.
    local record = CH.RoomRecord(room)
    if record == CH.ENTRY_ROOM then
        if not AtHome(x, y) then
            Watch(CH.AddEntrance(room, x, y), room, { { x, y } }, true)
            return "TB_ENTRANCE_MOVED"
        end
        for _, z in ipairs(h.zones) do
            local here = CH.ZoneContains(z, CH.ENTRANCE_X, CH.ENTRANCE_Y)
            if CH.IsRoom(z) and (z.floor or 1) == floor and z.mapID == mapID and here then
                return "TB_SMART_TAKEN_X", z.name
            end
        end
        CH.AddEntrance(room)
        return
    end
    if auto and not any then
        return "TB_AUTO_FIRST"
    end
    local kind = record and CH.GAME_ROOMS[record]
    if not kind then
        return "TB_SMART_UNKNOWN_X", UnknownName(record)
    end

    local name = (kind.gameName or ChamberlainDB.settings.gameRoomNames) and CH.GameRoomName(record) or nil
    local z = CH.NewZone(h, x, y, mapID, kind.shape, name, kind.size)
    local placed, atFeet = Place(h, z, room, stairs, x, y, any, auto)
    if not placed then
        return "TB_SMART_NO_FIT_X", name or CH.ShapeName(kind.shape)
    elseif atFeet then
        return "TB_SMART_AT_FEET"
    end
end

function CH.SmartDrop()
    local key, arg = Drop(false)
    if key then
        CH.Print(CH.L[key], arg)
    end
end

-- Match game room on the build rail. Picked room z takes the shape and size
-- of the game room you stand in and goes where smart drop would put it, on
-- the floor you're on. It keeps its name and the rest the owner gave it.
-- Another room linked to that game room lets go of it, since only one room
-- can hold it.
function CH.MatchGameRoom(z)
    local why, room, stairs, x, y, mapID = Here()
    if why then
        CH.Print(CH.L[why])
        return
    end
    local record = CH.RoomRecord(room)
    local entrance = record == CH.ENTRY_ROOM
    local kind = entrance and { shape = "closet" } or record and CH.GAME_ROOMS[record]
    if not kind then
        CH.Print(CH.L["TB_SMART_UNKNOWN_X"], UnknownName(record))
        return
    end
    local h = CH.CurrentHouse()
    local other = CH.LinkedZone(h, room)
    if other and other ~= z then
        other.gameRoom = nil
        CH.Print(CH.L["TB_MATCH_LINK_MOVED_X"], other.name)
    end
    local w, hh = kind.size, kind.size
    if not w then
        w, hh = CH.ShapeSize(kind.shape)
    end
    z.shape, z.rot, z.floor, z.mapID = kind.shape, nil, CH.MapFloor(), mapID
    CH.BoxAbout(z, x, y, w, hh)
    -- the entrance goes where smart drop puts it, never on a door
    if entrance then
        if AtHome(x, y) then
            z.minX, z.maxX, z.minY, z.maxY = home.minX, home.maxX, home.minY, home.maxY
        else
            CH.FitOnGrid(z, { { x, y } })
            Watch(z, room, { { x, y } }, true)
        end
        z.gameRoom = room
        CH.TouchHouse(CH.currentHouseGUID)
        return
    end
    local _, atFeet = Place(h, z, room, stairs, x, y, #CH.OtherRooms(h, z) > 0)
    if atFeet then
        CH.Print(CH.L["TB_SMART_AT_FEET"])
    end
end

-- Auto map runs smart drop on every room you walk into, from the floor check.
-- Off by default and off again when you leave the house, never saved.
CH.autoMap = false

local doneRoom, tryRoom, tryX, tryY = nil, nil, 0, 0
local told = {} -- rooms that already had their one chat line this session

-- A game room already linked on the map is passed over quietly. The rest can
-- come right once you've walked on: the game can call it your room while
-- you still stand in the room you came from (a round room's reaches past its
-- drawn wall), a fit can fail in the doorway, and the house can take a moment
-- to be known. Those try again each time you've moved a yard, for as long as
-- you're in that game room.
local QUIET = { TB_SMART_LINKED_X = true }
local RETRY = {
    TB_SMART_TAKEN_X = true,
    TB_SMART_NO_FIT_X = true,
    TB_NO_POSITION = true,
    RD_HOUSE_NOT_IDENTIFIED = true,
}

-- The floor check calls this with the game room you stand in.
function CH.SmartDropCheck(room)
    if watch then
        Follow(room)
    end
    if not CH.autoMap or not room or room == doneRoom or not CH.FP.CanEdit() then
        return
    end
    local x, y = CH.GetWorldPos()
    if x then
        if room == tryRoom and (x - tryX) ^ 2 + (y - tryY) ^ 2 < 1 then
            return
        end
        tryRoom, tryX, tryY = room, x, y
    end
    local key, arg = Drop(true)
    -- no open door in reach most often means a room before this one went
    -- down turned the wrong way, so the guide says how to put it right
    if key == "TB_SMART_NO_FIT_X" then
        CH.AutoMapStuck()
    elseif key == "TB_SMART_UNKNOWN_X" then
        CH.AutoMapStuck("AM_HINT_UNKNOWN_X", arg)
    end
    if RETRY[key] then
        return
    elseif key and not QUIET[key] then
        -- an unknown room says so once, the first room hint once in all
        local mark = key == "TB_AUTO_FIRST" and key or room
        if not told[mark] then
            told[mark] = true
            CH.Print(CH.L[key], arg)
        end
    end
    doneRoom = room
end

-- Turns Auto map off and forgets the walked spots, the retries and which
-- rooms were already told.
function CH.StopAutoMap()
    CH.autoMap = false
    doneRoom, tryRoom, watch = nil, nil, nil
    wipe(told)
    CH.RefreshAutoMapWelcome()
end

-- The map's button and the welcome window both turn it on and off here, so
-- each shows what the other did.
-- Auto map fits rooms to the game's walls, and so does Snap, so turning it on
-- turns Snap on too and says so. Snap stays on after.
function CH.SetAutoMap(on)
    if on then
        CH.autoMap = true
        if not ChamberlainDB.settings.snapRooms then
            CH.FP.SetSnap(true)
            CH.Print(CH.L["AM_SNAP_ON"])
        end
        CH.RefreshAutoMapWelcome()
    else
        CH.StopAutoMap()
    end
    if CH.FP.autoBtn:IsShown() then
        CH.SetButtonActive(CH.FP.autoBtn, CH.autoMap)
    end
end
