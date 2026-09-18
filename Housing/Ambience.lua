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

-- House and floor sounds live on the house entry, one table per kind, kind
-- being "ambience" (an index into CH.AMBIENCE) or "music" (a file id):
-- h.ambience = { house = value, floors = { [floor] = value } }, nil while there
-- are none. floor nil means the whole house.
function CH.GetHouseSound(guid, kind, floor)
    local set = ChamberlainDB.houses[guid][kind]
    if floor then
        return set and set.floors and set.floors[floor]
    end
    return set and set.house
end

-- The bare write. Removing a floor and a patch coming in from the owner use
-- this since neither is an edit of ours to stamp and announce.
function CH.StoreHouseSound(h, kind, floor, value)
    local set = h[kind] or {}
    if floor then
        set.floors = set.floors or {}
        set.floors[floor] = value
        if not next(set.floors) then
            set.floors = nil
        end
    else
        set.house = value
    end
    h[kind] = next(set) and set or nil
end

-- The owner picking a sound for the house or a floor. The group gets it as a
-- patch on top of the map they hold. See CH.SendSoundPatch.
function CH.SetHouseSound(guid, kind, floor, value)
    if CH.GetHouseSound(guid, kind, floor) == value then
        return
    end
    local h = ChamberlainDB.houses[guid]
    local baseTs = h.updatedAt
    CH.StoreHouseSound(h, kind, floor, value)
    CH.TouchHouse(guid)
    CH.SendSoundPatch(guid, kind, baseTs, floor and ("F" .. floor) or "H", value)
end

-- The room's own sound wins, then the floor's, then the house's.
function CH.ResolveSound(h, kind, zone)
    local set = h[kind]
    return zone and zone[kind] or set and (set.floors and set.floors[CH.activeFloor] or set.house)
end

-- Game sounds worth having in a room, offered in the music picker next to
-- typing a file number. Only the file id is saved and shared, so unlike
-- CH.AMBIENCE the order here means nothing and entries can go.
CH.SOUNDS = {
    { id = 1044878, key = "SFX_LAUGH_GHOST_WOMAN", cat = "SFX_CAT_LAUGHS" },
    { id = 1044868, key = "SFX_LAUGH_GHOST_MAN", cat = "SFX_CAT_LAUGHS" },
    { id = 552109, key = "SFX_LAUGH_GIRL", cat = "SFX_CAT_LAUGHS" },
    { id = 552170, key = "SFX_LAUGH_BOY", cat = "SFX_CAT_LAUGHS" },
    { id = 554078, key = "SFX_LAUGH_LICH_KING", cat = "SFX_CAT_LAUGHS" },
    { id = 639142, key = "SFX_LAUGH_IMP", cat = "SFX_CAT_LAUGHS" },
    { id = 1124141, key = "SFX_LAUGH_DEMON", cat = "SFX_CAT_LAUGHS" },
    { id = 567392, key = "SFX_SCREAM_WOMAN", cat = "SFX_CAT_SPOOKY" },
    { id = 1056870, key = "SFX_SCREAMS_DISTANT", cat = "SFX_CAT_SPOOKY" },
    { id = 544832, key = "SFX_BANSHEE", cat = "SFX_CAT_SPOOKY" },
    { id = 972586, key = "SFX_SPIRIT_MOANS", cat = "SFX_CAT_SPOOKY" },
    { id = 564856, key = "SFX_OLD_GOD_WHISPER", cat = "SFX_CAT_SPOOKY" },
    { id = 565732, key = "SFX_HEARTBEAT", cat = "SFX_CAT_SPOOKY" },
    { id = 929455, key = "SFX_WOLF_HOWL", cat = "SFX_CAT_SPOOKY" },
    { id = 566564, key = "SFX_BELL", cat = "SFX_CAT_HOUSE" },
    { id = 566254, key = "SFX_BELL_TOWER", cat = "SFX_CAT_HOUSE" },
    { id = 565564, key = "SFX_GONG", cat = "SFX_CAT_HOUSE" },
    { id = 565560, key = "SFX_DOOR", cat = "SFX_CAT_HOUSE" },
    { id = 569086, key = "SFX_GLASS", cat = "SFX_CAT_HOUSE" },
    { id = 569222, key = "SFX_THUNDERCLAP", cat = "SFX_CAT_HOUSE" },
    { id = 656081, key = "SFX_THUNDER_DISTANT", cat = "SFX_CAT_HOUSE" },
    { id = 555997, key = "SFX_MURLOC", cat = "SFX_CAT_FUN" },
    { id = 560229, key = "SFX_SHEEP", cat = "SFX_CAT_FUN" },
    { id = 558137, key = "SFX_PEON", cat = "SFX_CAT_FUN" },
    { id = 539228, key = "SFX_CHEER", cat = "SFX_CAT_FUN" },
    { id = 566373, key = "SFX_FIREWORK", cat = "SFX_CAT_FUN" },
    { id = 567431, key = "SFX_LEVEL_UP", cat = "SFX_CAT_FUN" },
    { id = 567439, key = "SFX_QUEST_COMPLETE", cat = "SFX_CAT_FUN" },
    { id = 567409, key = "SFX_READY_CHECK", cat = "SFX_CAT_FUN" },
    { id = 567397, key = "SFX_RAID_WARNING", cat = "SFX_CAT_FUN" },
}
CH.SOUND_CATS = { "SFX_CAT_LAUGHS", "SFX_CAT_SPOOKY", "SFX_CAT_HOUSE", "SFX_CAT_FUN" }

local soundKeys = {}
for _, sound in ipairs(CH.SOUNDS) do
    soundKeys[sound.id] = sound.key
end

-- Silence is a pick too, for a quiet room in a house with music or a house
-- without the game's music. No game file is silent, so the addon ships one and this
-- number stands for it wherever a music id goes. Real file ids are positive.
CH.SILENCE = -1
local SILENCE_FILE = "Interface\\AddOns\\Chamberlain\\Media\\silence.ogg"

-- A whole positive number that fits the %d of a patch message. tonumber takes
-- "1e20" from the search box just as happily as a wire value can be one.
function CH.IsFileID(n)
    return type(n) == "number" and n >= 1 and n < 2 ^ 31 and n % 1 == 0
end

-- The list's path for a music id, nil for an id that isn't in it. Doubles as
-- the check on ids coming in over the wire, so nobody can make a visitor's
-- client play some other sound file.
function CH.MusicPath(id)
    if id == CH.SILENCE then
        return CH.L["MP_SILENCE"]
    end
    if type(id) ~= "number" then
        return
    end
    local _, stop = CH.MUSIC_LIST:find("\n" .. id .. ";", 1, true)
    if stop then
        return CH.MUSIC_LIST:match("[^\n]+", stop + 1)
    end
end

-- A listed sound goes by its name and a track by its path. Any other file shows
-- as its number. "citymusic/stormwind/stormwind01-moment" reads fine in the
-- picker but is too long for a button, which asks for short and gets the last
-- piece.
function CH.SoundName(id, short)
    if soundKeys[id] then
        return CH.L[soundKeys[id]]
    end
    local path = CH.MusicPath(id)
    if path then
        return short and path:match("[^/]+$") or path
    end
    return string.format(CH.L["MP_CUSTOM_X"], id)
end

local FADE_MS = 1500

-- One chat line per session and channel ("Ambience" or "Music") the first time
-- a sound of ours starts while the player has that channel off or at zero, so
-- a silent house doesn't look like a broken addon.
local warned = {}

local function WarnIfMuted(channel)
    if warned[channel] then
        return
    end
    local audible = GetCVarBool("Sound_EnableAllSound")
        and GetCVarBool("Sound_Enable" .. channel)
        and tonumber(GetCVar("Sound_MasterVolume")) > 0
        and tonumber(GetCVar("Sound_" .. channel .. "Volume")) > 0
    if not audible then
        warned[channel] = true
        CH.Print(CH.L["SND_MUTED_" .. channel:upper()])
    end
end

-- room is the tone of the room you stand in, spot the bannerless room laid
-- over it (a hearth, a fountain), sting a room's own sound file, preview the
-- dialog's Test buton and a custom sound in the picker. Each holds a file id.
local slots = {
    room = { channel = "Ambience" },
    spot = { channel = "Ambience" },
    sting = { channel = "SFX" },
    preview = { channel = "Ambience" },
}

-- The API has no loop flag and won't say how long a file is. The first time
-- through a sound gets timed, which leaves a short gap before the restart is
-- noticed. After that the next copy starts OVERLAP seconds early and the old
-- tail fades out under it. Per session, so a length that came out wrong
-- because the sound device dropped doesn't stick around.
local OVERLAP = 0.3
local lengths = {}

local function Start(slot)
    local willPlay, handle = PlaySoundFile(slot.file, slot.channel)
    -- nil when the client refuses (sound off), so the ticker won't keep asking
    slot.handle = willPlay and handle or nil
    slot.started = GetTime()
end

local function Loop(slot)
    local played = GetTime() - slot.started
    if slot.left then
        -- a counted sound, no overlap between plays
        if not C_Sound.IsPlaying(slot.handle) then
            slot.left = slot.left - 1
            if slot.left > 0 then
                Start(slot)
            else
                slot.handle = nil
            end
        end
        return
    end
    local len = lengths[slot.file]
    if len then
        if played >= len - OVERLAP then
            StopSound(slot.handle, OVERLAP * 1000)
            Start(slot)
        end
    elseif not C_Sound.IsPlaying(slot.handle) then
        -- the shortest ambience is 3 seconds, anything under 1 got cut off
        if played > 1 then
            lengths[slot.file] = played
        end
        Start(slot)
    end
end

-- plays as in ReadRoomMusic (Sharing/Share.lua). Leaving and coming back starts
-- the count over.
local function SetSlot(slot, file, plays)
    if slot.file == file then
        if slot.handle then
            Loop(slot)
        end
        return
    end
    if slot.handle then
        StopSound(slot.handle, FADE_MS)
        slot.handle = nil
    end
    slot.file = file
    slot.left = plays and plays > 0 and plays or nil
    if file then
        Start(slot)
        WarnIfMuted(slot.channel)
    end
end

local function AmbienceFile(index)
    return index and CH.AMBIENCE[index].id
end

-- Music goes through PlayMusic, which silences the game's own music, loops by
-- itself and hands back on StopMusic. There is one music slot in the client,
-- so one track at a time. wanted is what the ticker resolved, preview what the
-- picker is playing over it.
local music = {}

local function ApplyMusic()
    local id = music.preview or music.wanted
    if id == music.playing then
        return
    end
    if id == CH.SILENCE then
        PlayMusic(SILENCE_FILE)
    elseif id then
        PlayMusic(id)
        WarnIfMuted("Music")
    else
        StopMusic()
    end
    music.playing = id
end

-- Called from the zone ticker with the ambience index of the current room, of
-- the bannerless room on top of it, the music id and a room's own sound file
-- with its play count, nil for none.
function CH.UpdateAmbience(room, spot, musicID, sting, plays)
    if not ChamberlainDB.settings.ambienceEnabled then
        room, spot, musicID, sting = nil, nil, nil, nil
    end
    SetSlot(slots.room, AmbienceFile(room))
    SetSlot(slots.spot, AmbienceFile(spot))
    SetSlot(slots.sting, sting, plays)
    -- keeps a running preview looping as well
    SetSlot(slots.preview, slots.preview.file)
    music.wanted = musicID
    ApplyMusic()
end

-- The music picker playing a track. nil ends it and whatever the house wants
-- comes back. Works outside a house too, where the ticker isn't running.
function CH.PreviewMusic(id)
    music.preview = id
    ApplyMusic()
end

-- A sound file played for the owner to hear it, nil stops. Loops off the zone
-- ticker, so outside a house it plays once through.
function CH.PreviewSound(file, channel)
    SetSlot(slots.preview, nil)
    -- on the channel it will play on in the room, so the volume is the same
    slots.preview.channel = channel or "Ambience"
    SetSlot(slots.preview, file)
end

-- The room dialog's Test button.
function CH.PreviewAmbience(index)
    CH.PreviewSound(AmbienceFile(index))
end
