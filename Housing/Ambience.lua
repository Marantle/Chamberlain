local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room ambience
-- ─────────────────────────────────────────────────────────────────────
-- A room can carry one of the game's own ambience files. Only the index into
-- CH.AMBIENCE is stored and shared since the file itself is already on every
-- client. Order is wire identity like CH.HEADS: append at the end, never
-- reorder or remove.
CH.AMBIENCE = {
    { id = 538974, key = "AMB_RIVER_SLOW", cat = "AMB_CAT_WATER" }, -- 1
    { id = 538980, key = "AMB_RIVER_FAST", cat = "AMB_CAT_WATER" },
    { id = 538973, key = "AMB_LAKE", cat = "AMB_CAT_WATER" },
    { id = 565772, key = "AMB_WATERFALL", cat = "AMB_CAT_WATER" },
    { id = 565790, key = "AMB_FOUNTAIN", cat = "AMB_CAT_WATER" },
    { id = 565707, key = "AMB_FOUNTAIN_ELVEN", cat = "AMB_CAT_WATER" },
    { id = 538977, key = "AMB_OCEAN", cat = "AMB_CAT_WATER" },
    { id = 565519, key = "AMB_CAMPFIRE", cat = "AMB_CAT_WEATHER" }, -- 8
    { id = 565408, key = "AMB_CAMPFIRE_LARGE", cat = "AMB_CAT_WEATHER" },
    { id = 538983, key = "AMB_RAIN_LIGHT", cat = "AMB_CAT_WEATHER" },
    { id = 538981, key = "AMB_RAIN_MEDIUM", cat = "AMB_CAT_WEATHER" },
    { id = 538982, key = "AMB_RAIN_HEAVY", cat = "AMB_CAT_WEATHER" },
    { id = 2057629, key = "AMB_RAIN_LIGHT_WIDE", cat = "AMB_CAT_WEATHER" },
    { id = 2057626, key = "AMB_RAIN_HEAVY_WIDE", cat = "AMB_CAT_WEATHER" },
    { id = 2182419, key = "AMB_THUNDERSTORM", cat = "AMB_CAT_WEATHER" },
    { id = 538985, key = "AMB_SNOW", cat = "AMB_CAT_WEATHER" },
    { id = 537422, key = "AMB_TAVERN", cat = "AMB_CAT_ROOMS" }, -- 17
    { id = 537423, key = "AMB_TAVERN_CROWDED", cat = "AMB_CAT_ROOMS" },
    { id = 537374, key = "AMB_DINING_ROOM", cat = "AMB_CAT_ROOMS" },
    { id = 537376, key = "AMB_GREAT_HALL", cat = "AMB_CAT_ROOMS" },
    { id = 537377, key = "AMB_GUEST_CHAMBERS", cat = "AMB_CAT_ROOMS" },
    { id = 537378, key = "AMB_LIBRARY", cat = "AMB_CAT_ROOMS" },
    { id = 537380, key = "AMB_BACKSTAGE", cat = "AMB_CAT_ROOMS" },
    { id = 537381, key = "AMB_OLD_TOWER", cat = "AMB_CAT_ROOMS" },
    { id = 537398, key = "AMB_ARCANE_LIBRARY", cat = "AMB_CAT_ROOMS" },
    { id = 537372, key = "AMB_STABLES", cat = "AMB_CAT_ROOMS" },
    { id = 537332, key = "AMB_BLACKSMITH", cat = "AMB_CAT_ROOMS" },
    { id = 537371, key = "AMB_GREAT_FORGE", cat = "AMB_CAT_ROOMS" },
    { id = 537356, key = "AMB_CRYPT", cat = "AMB_CAT_ROOMS" },
    { id = 537355, key = "AMB_CATHEDRAL", cat = "AMB_CAT_ROOMS" },
    { id = 537412, key = "AMB_JAIL", cat = "AMB_CAT_ROOMS" },
    { id = 537349, key = "AMB_PRISON", cat = "AMB_CAT_ROOMS" },
    { id = 537350, key = "AMB_SEWERS", cat = "AMB_CAT_ROOMS" },
    { id = 537340, key = "AMB_CAVE_COLD", cat = "AMB_CAT_ROOMS" },
    { id = 537343, key = "AMB_CAVE_WARM", cat = "AMB_CAT_ROOMS" },
    { id = 537405, key = "AMB_SHIP", cat = "AMB_CAT_ROOMS" },
    { id = 537410, key = "AMB_ROOM_SMALL", cat = "AMB_CAT_ROOMS" },
    { id = 537382, key = "AMB_ROOM_LARGE", cat = "AMB_CAT_ROOMS" },
    { id = 537383, key = "AMB_ROOM_LARGE_2", cat = "AMB_CAT_ROOMS" },
    { id = 538994, key = "AMB_FOREST_NIGHT", cat = "AMB_CAT_OUTSIDE" }, -- 40
    { id = 538990, key = "AMB_ENCHANTED_NIGHT", cat = "AMB_CAT_OUTSIDE" },
    { id = 538996, key = "AMB_SCARY_NIGHT", cat = "AMB_CAT_OUTSIDE" },
    { id = 539046, key = "AMB_CITY_NIGHT_GILNEAS", cat = "AMB_CAT_OUTSIDE" },
    { id = 537413, key = "AMB_CITY_NIGHT", cat = "AMB_CAT_OUTSIDE" },
    { id = 537411, key = "AMB_CITY_DAY", cat = "AMB_CAT_OUTSIDE" },
}

-- Menu order for the categories. Not wire data, free to change.
CH.AMBIENCE_CATS = { "AMB_CAT_ROOMS", "AMB_CAT_WATER", "AMB_CAT_WEATHER", "AMB_CAT_OUTSIDE" }

-- House and floor sounds live on the house entry as
-- h.ambience = { house = index, floors = { [floor] = index } }, nil while
-- there are none. floor nil sets the whole house.
function CH.SetHouseAmbience(guid, floor, index)
    local h = ChamberlainDB.houses[guid]
    local amb = h.ambience or {}
    if floor then
        amb.floors = amb.floors or {}
        amb.floors[floor] = index
        if not next(amb.floors) then
            amb.floors = nil
        end
    else
        amb.house = index
    end
    h.ambience = next(amb) and amb or nil
    CH.TouchHouse(guid)
end

local FADE_MS = 1500

-- room is the tone of the room you stand in, spot the bannerless room laid
-- over it (a hearth, a fountain), preview the dialog's Test buton.
local slots = { room = {}, spot = {}, preview = {} }

-- The API has no loop flag and won't say how long a file is. The first time
-- through a sound gets timed, which leaves a short gap before the restart is
-- noticed. After that the next copy starts OVERLAP seconds early and the old
-- tail fades out under it. Per session, so a length that came out wrong
-- because the sound device dropped doesn't stick around.
local OVERLAP = 0.3
local lengths = {}

local function Start(slot)
    local willPlay, handle = PlaySoundFile(CH.AMBIENCE[slot.index].id, "Ambience")
    -- nil when the client refuses (sound off), so the ticker won't keep asking
    slot.handle = willPlay and handle or nil
    slot.started = GetTime()
end

local function Loop(slot)
    local played = GetTime() - slot.started
    local len = lengths[slot.index]
    if len then
        if played >= len - OVERLAP then
            StopSound(slot.handle, OVERLAP * 1000)
            Start(slot)
        end
    elseif not C_Sound.IsPlaying(slot.handle) then
        -- the shortest file is 3 seconds, anything under 1 got cut off
        if played > 1 then
            lengths[slot.index] = played
        end
        Start(slot)
    end
end

local function SetSlot(slot, index)
    if slot.index == index then
        if slot.handle then
            Loop(slot)
        end
        return
    end
    if slot.handle then
        StopSound(slot.handle, FADE_MS)
        slot.handle = nil
    end
    slot.index = index
    if index then
        Start(slot)
    end
end

-- Called from the zone ticker with the ambience index of the current room and
-- of the bannerless room on top of it, nil for none.
function CH.UpdateAmbience(room, spot)
    if not ChamberlainDB.settings.ambienceEnabled then
        room, spot = nil, nil
    end
    SetSlot(slots.room, room)
    SetSlot(slots.spot, spot)
    -- keeps a running preview looping as well
    SetSlot(slots.preview, slots.preview.index)
end

-- The room dialog's Test button, nil stops. Loops off the zone ticker, so
-- outside a house it plays once through.
function CH.PreviewAmbience(index)
    SetSlot(slots.preview, nil)
    SetSlot(slots.preview, index)
end
