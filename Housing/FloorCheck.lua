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
-- The game's room ids are the same on every character and after a relog, and
-- a room keeps its id when it's moved. A stairwell can link too, but the
-- floors between its ends can share one id, so only its ends are any good.

local CHECK_EVERY = 4 -- zone ticks, one second

local ticks = 0
local seenRoom = nil -- the game room the last check saw

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
end

-- Browsing another floor of this house on the map would get thrown back to
-- the floor you stand on. A paused check doesn't look, so the room is still
-- new to it once you come back.
local function Paused()
    local FP = CH.FP
    return CH.editingLayout or (FP.win:IsShown() and not FP.viewGUID and CH.fpViewedFloor ~= CH.activeFloor)
end

function CH.CheckFloorLink(h)
    ticks = ticks + 1
    if ticks < CHECK_EVERY or Paused() then
        return
    end
    ticks = 0
    local room = C_HousingLayout.GetRoomPlayerIsIn()
    if room == seenRoom then
        return
    end
    seenRoom = room
    if not room then
        return
    end
    for _, z in ipairs(h.zones) do
        if z.gameRoom == room then
            local floor = z.floor or 1
            if floor ~= CH.activeFloor then
                CH.SetActiveFloor(floor)
                -- a landing under you on the new floor waits until you step off it
                CH.SyncAnchorLatch()
            end
            return
        end
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
