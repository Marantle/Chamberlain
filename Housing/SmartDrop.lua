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
    local first = watch.spots[1]
    if CH.FitToOpenDoor(h, z, first[1], first[2], watch.spots) then
        Mark(z)
        CH.TouchHouse(CH.currentHouseGUID)
    end
end

local function IsStairwell(z)
    local def = z.shape and CH.SHAPES[z.shape]
    return def and def.art ~= nil
end

-- The game's lowest and highest floor in our numbering, where the floor with
-- its base room is 1. Only a house of your own answers.
local function GameFloors()
    local layout = C_HousingLayout
    local lo, hi = layout.GetLowestOccupiedFloorIndex(), layout.GetHighestOccupiedFloorIndex()
    local base = layout.GetBaseRoomFloor()
    if lo and hi and base then
        return lo - base + 1, hi - base + 1
    end
end

-- Whether a stairwell just placed is the top end of its flight, which says
-- where its other end goes. The ground floor is always the foot. A stairwell
-- already mapped under it, or the game's top floor, makes it the top, and
-- anywhere else it's taken for the foot. Its door is the same at both ends,
-- so this can wait until it's on its door.
local function AtTop(h, z)
    local floor = z.floor or 1
    if floor <= 1 then
        return false
    end
    local cx, cy = CH.ZoneCentre(z)
    for _, o in ipairs(h.zones) do
        if (o.floor or 1) == floor - 1 and IsStairwell(o) and CH.ZoneContains(o, cx, cy) then
            return true
        end
    end
    local _, last = GameFloors()
    return last ~= nil and floor >= last
end

-- A copy of stairwell z on floor, the map's floors raised to reach it. False
-- when a room is there already.
local function CopyStairwell(h, z, floor)
    local cx, cy = CH.ZoneCentre(z)
    for _, o in ipairs(h.zones) do
        if CH.IsRoom(o) and (o.floor or 1) == floor and CH.ZoneContains(o, cx, cy) then
            return false
        end
    end
    h.floorCount = math.max(h.floorCount or 1, floor)
    table.insert(h.zones, {
        name = z.name,
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

-- The same stairwell on the floor its steps lead to. On the ground floor that
-- is always the one above, added to the map if need be, since the steps can
-- only go up from there. Higher up it goes where the game has a floor.
local function OtherEnd(h, z)
    if z.floor <= 1 then
        CopyStairwell(h, z, 2)
        return
    end
    local first, last = GameFloors()
    local other = z.floor + (AtTop(h, z) and -1 or 1)
    if first and other >= math.max(first, 1) and other <= last then
        CopyStairwell(h, z, other)
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

-- Drops the room and returns nothing, or returns the chat line that says why
-- not and its argument. auto leaves the first room of a floor alone, since
-- where you happen to step in is no place to put it.
local function Drop(auto)
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

    -- The Entry's spot is known exactly, so it goes on any map, auto or not,
    -- unless a room on the ground floor already covers that spot.
    local record = tonumber(room:match("^Housing%-%d+%-(%d+)%-"))
    if record == CH.ENTRY_ROOM then
        for _, z in ipairs(h.zones) do
            local here = CH.ZoneContains(z, CH.ENTRANCE_X, CH.ENTRANCE_Y)
            if CH.IsRoom(z) and (z.floor or 1) == 1 and z.mapID == mapID and here then
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
    local entry = record and C_HousingCatalog.GetCatalogEntryInfoByRecordID(Enum.HousingCatalogEntryType.Room, record)
    if not kind then
        return "TB_SMART_UNKNOWN_X", entry and entry.name or CH.L["TB_SMART_THIS_ROOM"]
    end

    local name = kind.gameName and entry and entry.name
    local z = CH.NewZone(h, x, y, mapID, kind.shape, name, kind.size)
    local spots = { { x, y } }
    -- the first room of a floor has no door to go on, so it stays at your
    -- feet, on the grid with Snap on
    if any and not CH.FitToOpenDoor(h, z, x, y, spots) then
        return "TB_SMART_NO_FIT_X", name or CH.ShapeName(kind.shape)
    elseif not any and ChamberlainDB.settings.snapRooms then
        CH.SnapToGrid(z)
    end
    -- a stairwell's id can cover more than one floor, and the floor check would
    -- pull you to this floor from the other one, so it goes in unlinked
    z.gameRoom = not stairs and room or nil
    local stairwell = IsStairwell(z)
    if stairwell then
        OtherEnd(h, z)
    end
    table.insert(h.zones, z)
    CH.TouchHouse(CH.currentHouseGUID)
    CH.SetSelection(z, CH.currentHouseGUID)
    -- a stairwell's one door already told its turn
    if any and not stairwell then
        watch = { zone = z, room = room, spots = spots }
        Mark(z)
    end
end

function CH.SmartDrop()
    local key, arg = Drop(false)
    if key then
        CH.Print(CH.L[key], arg)
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
end
