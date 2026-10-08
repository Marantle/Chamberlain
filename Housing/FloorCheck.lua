local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor check: rooms linked to the game's own rooms
-- ─────────────────────────────────────────────────────────────────────
-- The stairs guess the floor from where you step, and a missed landing leaves
-- the guess wrong until the next one. The game knows which of its rooms you
-- stand in, so a room linked to one of them puts you back on its floor when
-- you walk in. Only on the way in, so stairs and "Move to floor" still get the
-- last word inside the room.
--
-- A smaller room no game room remembers holds the floor you're on while you
-- stand in it, a barn's loft say, which is in the barn's game room one floor
-- up. Stepping out of it counts as walking into the game room again.
--
-- The game's room ids are the same on every character and after a relog, and
-- a room keeps its id when it's moved. A stairwell can link too, but one id
-- reaches over more than one floor (three floors of stairwells showed two
-- ids), so a linked one can put you on the wrong floor.

local CHECK_EVERY = 4 -- zone ticks, under half a second

local ticks = 0
local seenRoom = nil -- the game room the last check saw
local held = false -- standing in a smaller room the check leaves alone

-- The game room you stand in and whether it's a stairwell, or nil outside one.
function CH.GameRoomHere()
    local room = C_HousingLayout.GetRoomPlayerIsIn()
    if room then
        return room, C_HousingLayout.RoomHasStairs(room)
    end
end

-- Leaving the house, so the first room of the next visit counts as walked into.
function CH.ForgetGameRoom()
    seenRoom = nil
    held = false
end

function CH.FloorCheckHeld()
    return held
end

-- Browsing another floor of this house on the map would get thrown back to
-- the floor you stand on. A paused check doesn't look, so the room is still
-- new to it once you come back.
local function Paused()
    local FP = CH.FP
    return CH.editingLayout or (FP.win:IsShown() and not FP.viewGUID and CH.fpViewedFloor ~= CH.activeFloor)
end

-- The room of house h that remembers game room room, or nil.
function CH.LinkedZone(h, room)
    for _, z in ipairs(h.zones) do
        if z.gameRoom == room then
            return z
        end
    end
end

-- Whether you stand in a room on this floor that no game room remembers and
-- that is smaller than linked. A big hand drawn room over a whole floor
-- doesn't count, or it would keep a wrong floor for good.
local function Held(h, linked, x, y, mapID)
    local area = CH.ZoneArea(linked)
    for _, z in ipairs(h.zones) do
        if
            not z.gameRoom
            and CH.IsRoom(z)
            and (z.floor or 1) == CH.activeFloor
            and z.mapID == mapID
            and CH.ZoneContains(z, x, y)
            and CH.ZoneArea(z) < area
        then
            return true
        end
    end
end

-- Up on a loft's floor in its room's game room but in nothing mapped there,
-- so you came down some other way than the stairs, a jump say.
local function OffLoft(h, linked, x, y, mapID)
    local def = linked.shape and CH.SHAPES[linked.shape]
    if not (def and def.loft) or CH.activeFloor ~= (linked.floor or 1) + 1 or CH.OnSpiralStairs() then
        return false
    end
    for _, z in ipairs(h.zones) do
        if (z.floor or 1) == CH.activeFloor and z.mapID == mapID and CH.ZoneContains(z, x, y) then
            return false
        end
    end
    return true
end

function CH.CheckFloorLink(h, x, y, mapID)
    ticks = ticks + 1
    if ticks < CHECK_EVERY or Paused() then
        return
    end
    ticks = 0
    local room = C_HousingLayout.GetRoomPlayerIsIn()
    CH.SmartDropCheck(room)
    local linked = room and CH.LinkedZone(h, room)
    held = linked and Held(h, linked, x, y, mapID) or false
    if held then
        -- so stepping out of it is walking in
        seenRoom = nil
        return
    end
    if linked and OffLoft(h, linked, x, y, mapID) then
        CH.SetActiveFloor(linked.floor or 1)
        CH.SyncAnchorLatch()
        return
    end
    if room == seenRoom then
        return
    end
    seenRoom = room
    local floor = linked and (linked.floor or 1)
    if floor and floor ~= CH.activeFloor then
        CH.SetActiveFloor(floor)
        -- a landing under you on the new floor waits until you step off it
        CH.SyncAnchorLatch()
    end
end

-- ── Rooms moved or removed in the editor ─────────────────────────────
-- The move and remove events don't say which room. The game makes you select
-- a room first and the selection clears just before either one fires, so the
-- last room selected is the one. It's used once and forgoten.

local picked, pickedFloor = nil, nil

local function Unlink(room, key)
    local guid = CH.currentHouseGUID
    local h = guid and ChamberlainDB.houses[guid]
    if not h then
        return
    end
    local any = false
    for _, z in ipairs(h.zones) do
        if z.gameRoom == room then
            z.gameRoom = nil
            any = true
            CH.Print(CH.L[key], room, z.name)
        end
    end
    if any then
        CH.TouchHouse(guid)
    end
end

local editor = CreateFrame("Frame")
editor:RegisterEvent("HOUSING_LAYOUT_ROOM_SELECTION_CHANGED")
editor:RegisterEvent("HOUSING_LAYOUT_ROOM_MOVED")
editor:RegisterEvent("HOUSING_LAYOUT_ROOM_REMOVED")
editor:SetScript("OnEvent", function(_, event, hasSelection)
    if event == "HOUSING_LAYOUT_ROOM_SELECTION_CHANGED" then
        if hasSelection then
            picked = C_HousingLayout.GetSelectedRoom()
            pickedFloor = C_HousingLayout.GetViewedFloor()
        end
        return
    end
    if picked then
        if event == "HOUSING_LAYOUT_ROOM_REMOVED" then
            Unlink(picked, "HOUSE_UNLINKED_REMOVED_X")
        elseif C_HousingLayout.GetViewedFloor() ~= pickedFloor then
            Unlink(picked, "HOUSE_UNLINKED_MOVED_X")
        end
    end
    picked = nil
end)
