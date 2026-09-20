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
    { id = 537422, key = "AMB_TAVERN", cat = "AMB_CAT_CROWDS" }, -- 17
    { id = 537423, key = "AMB_TAVERN_CROWDED", cat = "AMB_CAT_CROWDS" },
    { id = 537374, key = "AMB_DINING_ROOM", cat = "AMB_CAT_ROOMS" },
    { id = 537376, key = "AMB_GREAT_HALL", cat = "AMB_CAT_ROOMS" },
    { id = 537377, key = "AMB_GUEST_CHAMBERS", cat = "AMB_CAT_ROOMS" },
    { id = 537378, key = "AMB_LIBRARY", cat = "AMB_CAT_ROOMS" },
    { id = 537380, key = "AMB_BACKSTAGE", cat = "AMB_CAT_ROOMS" },
    { id = 537381, key = "AMB_OLD_TOWER", cat = "AMB_CAT_ROOMS" },
    { id = 537398, key = "AMB_ARCANE_LIBRARY", cat = "AMB_CAT_ROOMS" },
    { id = 537372, key = "AMB_STABLES", cat = "AMB_CAT_WORK" },
    { id = 537332, key = "AMB_BLACKSMITH", cat = "AMB_CAT_WORK" },
    { id = 537371, key = "AMB_GREAT_FORGE", cat = "AMB_CAT_WORK" },
    { id = 537356, key = "AMB_CRYPT", cat = "AMB_CAT_DUNGEON" },
    { id = 537355, key = "AMB_CATHEDRAL", cat = "AMB_CAT_ROOMS" },
    { id = 537412, key = "AMB_JAIL", cat = "AMB_CAT_DUNGEON" },
    { id = 537349, key = "AMB_PRISON", cat = "AMB_CAT_DUNGEON" },
    { id = 537350, key = "AMB_SEWERS", cat = "AMB_CAT_DUNGEON" },
    { id = 537340, key = "AMB_CAVE_COLD", cat = "AMB_CAT_DUNGEON" },
    { id = 537343, key = "AMB_CAVE_WARM", cat = "AMB_CAT_DUNGEON" },
    { id = 537405, key = "AMB_SHIP", cat = "AMB_CAT_WORK" },
    { id = 537410, key = "AMB_ROOM_SMALL", cat = "AMB_CAT_ROOMS" },
    { id = 537382, key = "AMB_ROOM_LARGE", cat = "AMB_CAT_ROOMS" },
    { id = 537383, key = "AMB_ROOM_LARGE_2", cat = "AMB_CAT_ROOMS" },
    { id = 538994, key = "AMB_FOREST_NIGHT", cat = "AMB_CAT_OUTSIDE" }, -- 40
    { id = 538990, key = "AMB_ENCHANTED_NIGHT", cat = "AMB_CAT_OUTSIDE" },
    { id = 538996, key = "AMB_SCARY_NIGHT", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539046, key = "AMB_CITY_NIGHT_GILNEAS", cat = "AMB_CAT_OUTSIDE" },
    { id = 537413, key = "AMB_CITY_NIGHT", cat = "AMB_CAT_OUTSIDE" },
    { id = 537411, key = "AMB_CITY_DAY", cat = "AMB_CAT_TOWNS" },
    -- 3.11.0, appended
    { id = 537392, key = "AMB_NAXX_ENTRANCE", cat = "AMB_CAT_HAUNTED" }, -- 46
    { id = 537394, key = "AMB_NAXX_PLAGUE", cat = "AMB_CAT_HAUNTED" },
    { id = 537391, key = "AMB_NAXX_KNIGHTS", cat = "AMB_CAT_HAUNTED" },
    { id = 537395, key = "AMB_NAXX_SPIDERS", cat = "AMB_CAT_HAUNTED" },
    { id = 537390, key = "AMB_NAXX_ABOMINATIONS", cat = "AMB_CAT_HAUNTED" },
    { id = 537393, key = "AMB_FROST_WYRM_LAIR", cat = "AMB_CAT_HAUNTED" },
    { id = 537373, key = "AMB_KARA_DEMONS", cat = "AMB_CAT_HAUNTED" },
    { id = 537379, key = "AMB_KARA_NETHERSPITE", cat = "AMB_CAT_HAUNTED" },
    { id = 537375, key = "AMB_KARA_FACADE", cat = "AMB_CAT_HAUNTED" },
    { id = 537326, key = "AMB_AUCH_SHADOW", cat = "AMB_CAT_HAUNTED" },
    { id = 537323, key = "AMB_AUCH_DEMON", cat = "AMB_CAT_HAUNTED" },
    { id = 537329, key = "AMB_BLACKROCK_JAIL", cat = "AMB_CAT_DUNGEON" }, -- 57
    { id = 537365, key = "AMB_ICECROWN", cat = "AMB_CAT_SCOURGE" }, -- 58
    { id = 537366, key = "AMB_PLAGUEWORKS", cat = "AMB_CAT_SCOURGE" },
    { id = 537367, key = "AMB_CRIMSON_HALL", cat = "AMB_CAT_SCOURGE" },
    { id = 537368, key = "AMB_FROSTMOURNE", cat = "AMB_CAT_SCOURGE" },
    { id = 537369, key = "AMB_FORGE_OF_SOULS", cat = "AMB_CAT_SCOURGE" },
    { id = 537431, key = "AMB_ULDUAR_FROZEN", cat = "AMB_CAT_SCOURGE" },
    { id = 537436, key = "AMB_YOGG_BRAIN", cat = "AMB_CAT_SCOURGE" },
    { id = 537414, key = "AMB_STRATHOLME", cat = "AMB_CAT_PLAGUE" },
    { id = 537399, key = "AMB_STRATHOLME_OLD", cat = "AMB_CAT_PLAGUE" },
    { id = 594426, key = "AMB_SCOURGE_LANDS", cat = "AMB_CAT_SCOURGE" },
    { id = 1725215, key = "AMB_NECROPOLIS_OUT", cat = "AMB_CAT_PLAGUE" },
    { id = 1725216, key = "AMB_NECROPOLIS_IN", cat = "AMB_CAT_PLAGUE" },
    { id = 538967, key = "AMB_SPIRIT_WORLD", cat = "AMB_CAT_BEYOND" }, -- 70
    { id = 795737, key = "AMB_GRAVEYARD_CRYPT", cat = "AMB_CAT_PLAGUE" },
    { id = 539115, key = "AMB_PLAGUELANDS_NIGHT", cat = "AMB_CAT_PLAGUE" },
    { id = 539049, key = "AMB_PLAGUED_FOREST", cat = "AMB_CAT_PLAGUE" },
    { id = 1282880, key = "AMB_NIGHTMARE", cat = "AMB_CAT_BEYOND" },
    { id = 594453, key = "AMB_WHISPER_GULCH", cat = "AMB_CAT_BEYOND" },
    { id = 3562886, key = "AMB_REVENDRETH", cat = "AMB_CAT_BEYOND" },
    { id = 3489393, key = "AMB_MALDRAXXUS", cat = "AMB_CAT_BEYOND" },
    { id = 3561137, key = "AMB_MAW", cat = "AMB_CAT_BEYOND" },
    { id = 594483, key = "AMB_GHOSTLANDS_NIGHT", cat = "AMB_CAT_HAUNTED_OUT" }, -- 79
    { id = 539003, key = "AMB_DEADWIND_NIGHT", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539139, key = "AMB_HAUNTED_WASTE", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539051, key = "AMB_EERIE_STORM_FOREST", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539089, key = "AMB_EERIE_WOODS", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539028, key = "AMB_DARK_ENCHANTED", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 1724741, key = "AMB_DRUSTVAR_FOREST", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 1724739, key = "AMB_DRUSTVAR_CLEARING", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539103, key = "AMB_MARSH_NIGHT", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 917985, key = "AMB_SHADOWMOON_SWAMP", cat = "AMB_CAT_HAUNTED_OUT" },
    { id = 539131, key = "AMB_BIRDSONG_FOREST", cat = "AMB_CAT_BRIGHT" }, -- 89
    { id = 539047, key = "AMB_HIGH_FOREST", cat = "AMB_CAT_BRIGHT" },
    { id = 539126, key = "AMB_CLEANSED_FOREST", cat = "AMB_CAT_BRIGHT" },
    { id = 539095, key = "AMB_BREEZY_DAY", cat = "AMB_CAT_BRIGHT" },
    { id = 539056, key = "AMB_GRASSLANDS", cat = "AMB_CAT_BRIGHT" },
    { id = 948412, key = "AMB_NAGRAND", cat = "AMB_CAT_FARLANDS" },
    { id = 594528, key = "AMB_EVERSONG", cat = "AMB_CAT_FARLANDS" },
    { id = 591729, key = "AMB_FOUR_WINDS", cat = "AMB_CAT_FARLANDS" },
    { id = 621873, key = "AMB_SPRING_ROAD", cat = "AMB_CAT_FARLANDS" },
    { id = 591674, key = "AMB_JADE_FOREST", cat = "AMB_CAT_FARLANDS" },
    { id = 1250632, key = "AMB_VALSHARAH", cat = "AMB_CAT_FARLANDS" },
    { id = 1350008, key = "AMB_SURAMAR_FOREST", cat = "AMB_CAT_FARLANDS" },
    { id = 3502681, key = "AMB_ARDENWEALD", cat = "AMB_CAT_FARLANDS" }, -- 101
    { id = 3190869, key = "AMB_BASTION", cat = "AMB_CAT_FARLANDS" },
    { id = 1849036, key = "AMB_STORMSONG", cat = "AMB_CAT_FARLANDS" },
    { id = 1724074, key = "AMB_TIRAGARDE", cat = "AMB_CAT_FARLANDS" },
    { id = 539048, key = "AMB_BEACH", cat = "AMB_CAT_BRIGHT" },
    { id = 539016, key = "AMB_COAST", cat = "AMB_CAT_BRIGHT" },
    { id = 1827835, key = "AMB_JUNGLE_BEACH", cat = "AMB_CAT_BRIGHT" },
    { id = 539097, key = "AMB_JUNGLE", cat = "AMB_CAT_BRIGHT" },
    { id = 1853185, key = "AMB_BORALUS", cat = "AMB_CAT_TOWNS" }, -- 109
    { id = 1838478, key = "AMB_BORALUS_HARBOR", cat = "AMB_CAT_TOWNS" },
    { id = 5633429, key = "AMB_DORNOGAL", cat = "AMB_CAT_TOWNS" },
    { id = 5673242, key = "AMB_SILVERMOON", cat = "AMB_CAT_TOWNS" },
    { id = 537408, key = "AMB_SILVERMOON_OLD", cat = "AMB_CAT_TOWNS" },
    { id = 537351, key = "AMB_DARNASSUS", cat = "AMB_CAT_TOWNS" },
    { id = 537426, key = "AMB_THUNDER_BLUFF", cat = "AMB_CAT_TOWNS" },
    { id = 537401, key = "AMB_ORGRIMMAR", cat = "AMB_CAT_TOWNS" },
    { id = 537357, key = "AMB_DWARVEN_DISTRICT", cat = "AMB_CAT_TOWNS" },
    { id = 537358, key = "AMB_EXODAR", cat = "AMB_CAT_TOWNS" },
    { id = 537370, key = "AMB_IRONFORGE", cat = "AMB_CAT_TOWNS" },
    { id = 539123, key = "AMB_DARKMOON_FAIRE", cat = "AMB_CAT_CROWDS" }, -- 120
    { id = 539055, key = "AMB_DARKMOON_ISLAND", cat = "AMB_CAT_CROWDS" },
    { id = 839843, key = "AMB_ARENA_CROWD", cat = "AMB_CAT_CROWDS" },
    { id = 1010572, key = "AMB_CROWD_CELEBRATING", cat = "AMB_CAT_CROWDS" },
}

-- Menu order for the categories. Not wire data, free to change, and so is the
-- cat of an entry. Keep a category to a dozen or so since a longer menu is a
-- chore to read.
CH.AMBIENCE_CATS = {
    "AMB_CAT_ROOMS",
    "AMB_CAT_CROWDS",
    "AMB_CAT_WORK",
    "AMB_CAT_DUNGEON",
    "AMB_CAT_WATER",
    "AMB_CAT_WEATHER",
    "AMB_CAT_BRIGHT",
    "AMB_CAT_FARLANDS",
    "AMB_CAT_OUTSIDE",
    "AMB_CAT_TOWNS",
    "AMB_CAT_HAUNTED",
    "AMB_CAT_SCOURGE",
    "AMB_CAT_PLAGUE",
    "AMB_CAT_BEYOND",
    "AMB_CAT_HAUNTED_OUT",
}

-- House and floor sounds live on the house entry, one table per kind, kind
-- being "ambience" (an index into CH.AMBIENCE), "music" (a file id) or
-- "arrival" (a sound id, played when somebody walks into the house, 3.13.0):
-- h.ambience = { house = value, floors = { [floor] = value } }, nil while there
-- are none. floor nil means the whole house, and arrival has no floors.
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

-- Every pick of one kind the house holds, "music" or "sfx", each once. The
-- house's own comes first, then the floors' and the rooms', though only music
-- has the first two. Silence is left out since the picker always has it on top.
function CH.HousePicks(h, kind)
    local ids, seen = {}, { [CH.SILENCE] = true }
    local function add(id)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    local set = h[kind]
    if set then
        add(set.house)
        for floor = 1, h.floorCount or 1 do
            add(set.floors and set.floors[floor])
        end
    end
    for _, zone in ipairs(h.zones) do
        add(zone[kind])
    end
    return ids
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
    { id = 566564, key = "SFX_BELL", cat = "SFX_CAT_BELLS" },
    { id = 566254, key = "SFX_BELL_TOWER", cat = "SFX_CAT_BELLS" },
    { id = 565564, key = "SFX_GONG", cat = "SFX_CAT_BELLS" },
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
    -- the ones below zero aren't game files, see SHIPPED
    { id = -2, key = "SFX_SHOP_BELL", cat = "SFX_CAT_DOOR" },
    { id = -3, key = "SFX_SHOP_BELL_SQUEAK", cat = "SFX_CAT_DOOR" },
    { id = -4, key = "SFX_DING_DONG", cat = "SFX_CAT_DOOR" },
    { id = 540523, key = "SFX_KNOCK_1", cat = "SFX_CAT_DOOR" },
    { id = 540522, key = "SFX_KNOCK_2", cat = "SFX_CAT_DOOR" },
    { id = 2066499, key = "SFX_DINNER_BELL_1", cat = "SFX_CAT_DOOR" },
    { id = 2066500, key = "SFX_DINNER_BELL_2", cat = "SFX_CAT_DOOR" },
    { id = 2066501, key = "SFX_DINNER_BELL_3", cat = "SFX_CAT_DOOR" },
    { id = 2066502, key = "SFX_DINNER_BELL_4", cat = "SFX_CAT_DOOR" },
    { id = 2066497, key = "SFX_DINNER_BELL_5", cat = "SFX_CAT_DOOR" },
    { id = 2066498, key = "SFX_DINNER_BELL_6", cat = "SFX_CAT_DOOR" },
    { id = 568154, key = "SFX_SHAYS_BELL", cat = "SFX_CAT_DOOR" },
    { id = 1514318, key = "SFX_CHIME_1", cat = "SFX_CAT_CHIMES" },
    { id = 1514321, key = "SFX_CHIME_2", cat = "SFX_CAT_CHIMES" },
    { id = 1514324, key = "SFX_CHIME_3", cat = "SFX_CAT_CHIMES" },
    { id = 1514328, key = "SFX_CHIME_4", cat = "SFX_CAT_CHIMES" },
    { id = 1514311, key = "SFX_CHIMES_1", cat = "SFX_CAT_CHIMES" },
    { id = 1514314, key = "SFX_CHIMES_2", cat = "SFX_CAT_CHIMES" },
    { id = 1514317, key = "SFX_CHIMES_3", cat = "SFX_CAT_CHIMES" },
    { id = 3691975, key = "SFX_CHIME_CELERITY", cat = "SFX_CAT_CHIMES" },
    { id = 6684192, key = "SFX_CHIME_CALENDAR", cat = "SFX_CAT_CHIMES" },
    { id = 3892923, key = "SFX_REPAIR_BELL_1", cat = "SFX_CAT_BELLS" },
    { id = 3892927, key = "SFX_REPAIR_BELL_2", cat = "SFX_CAT_BELLS" },
    { id = 5738550, key = "SFX_BELL_STROKE_1", cat = "SFX_CAT_BELLS" },
    { id = 5738554, key = "SFX_BELL_STROKE_2", cat = "SFX_CAT_BELLS" },
    { id = 5738558, key = "SFX_BELL_STROKE_3", cat = "SFX_CAT_BELLS" },
    { id = 5148442, key = "SFX_BELL_TOLL_2", cat = "SFX_CAT_BELLS" },
    { id = 5148452, key = "SFX_BELL_TOLL_3", cat = "SFX_CAT_BELLS" },
    { id = 1838453, key = "SFX_BELL_RINGING", cat = "SFX_CAT_BELLS" },
    { id = 1129273, key = "SFX_SHIP_BELL_1", cat = "SFX_CAT_BELLS" },
    { id = 1129274, key = "SFX_SHIP_BELL_2", cat = "SFX_CAT_BELLS" },
    { id = 1838477, key = "SFX_SHIP_BELL_PIRATE", cat = "SFX_CAT_BELLS" },
    { id = 1100031, key = "SFX_DARKMOON_BELL", cat = "SFX_CAT_BELLS" },
}
CH.SOUND_CATS = {
    "SFX_CAT_DOOR",
    "SFX_CAT_CHIMES",
    "SFX_CAT_BELLS",
    "SFX_CAT_LAUGHS",
    "SFX_CAT_SPOOKY",
    "SFX_CAT_HOUSE",
    "SFX_CAT_FUN",
}

-- file id to name key, the ambience loops along with the sounds
local soundKeys = {}
for _, list in ipairs({ CH.AMBIENCE, CH.SOUNDS }) do
    for _, sound in ipairs(list) do
        soundKeys[sound.id] = sound.key
    end
end

-- Silence is a pick too, for a quiet room in a house with music or a house
-- without the game's music. No game file is silent, so the addon ships one and this
-- number stands for it wherever a music id goes. Real file ids are positive.
CH.SILENCE = -1
local MEDIA = "Interface\\AddOns\\Chamberlain\\Media\\"
local SILENCE_FILE = MEDIA .. "silence.ogg"

-- The game has no shop door bell, so a few sounds ship with the addon and go
-- by a number below zero the same way. The number is what gets saved and
-- shared, so one that has been out is never handed to another file.
local SHIPPED = {
    [-2] = MEDIA .. "shopbell.ogg",
    [-3] = MEDIA .. "shopbell_squeak.ogg",
    [-4] = MEDIA .. "dingdong.ogg",
}

-- A whole positive number that fits the %d of a patch message. tonumber takes
-- "1e20" from the search box just as happily as a wire value can be one.
function CH.IsFileID(n)
    return type(n) == "number" and n >= 1 and n < 2 ^ 31 and n % 1 == 0
end

-- What a room's sound on entry or the house's arrival sound may be, a game
-- file or one of ours.
function CH.IsSoundID(n)
    return CH.IsFileID(n) or SHIPPED[n] ~= nil
end

-- A room's echo is how many yards its sound on entry carries to the others in
-- the house when somebody walks in. This number stands for all of it.
CH.WHOLE_HOUSE = -1
CH.ECHO_MAX = 100

function CH.IsEcho(n)
    return n == CH.WHOLE_HOUSE or (type(n) == "number" and n >= 1 and n <= CH.ECHO_MAX and n % 1 == 0)
end

function CH.EchoText(echo)
    if echo == CH.WHOLE_HOUSE then
        return CH.L["MP_ECHO_HOUSE"]
    end
    return echo and string.format(CH.L["MP_ECHO_YARDS_X"], echo) or CH.L["MP_ECHO_NONE"]
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
-- dialog's Test buton and a custom sound in the picker, echo a sting somebody
-- else set off elsewhere in the house. Each holds a file id.
local slots = {
    room = { channel = "Ambience" },
    spot = { channel = "Ambience" },
    sting = { channel = "SFX" },
    preview = { channel = "Ambience" },
    echo = { channel = "SFX" },
}

-- The API has no loop flag and won't say how long a file is. The first time
-- through a sound gets timed, which leaves a short gap before the restart is
-- noticed. After that the next copy starts OVERLAP seconds early and the old
-- tail fades out under it. Per session, so a length that came out wrong
-- because the sound device dropped doesn't stick around.
local OVERLAP = 0.3
local lengths = {}

local function Start(slot)
    local willPlay, handle = PlaySoundFile(SHIPPED[slot.file] or slot.file, slot.channel)
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

-- plays as in ReadRoomSounds (Sharing/Share.lua). Leaving and coming back starts
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
    CH.RefreshNowPlaying()
end

local function AmbienceFile(index)
    return index and CH.AMBIENCE[index].id
end

-- Music goes through PlayMusic, which silences the game's own music, loops by
-- itself and hands back on StopMusic. There is one music slot in the client,
-- so one track at a time. wanted is what the ticker resolved, preview what the
-- picker is playing over it.
local music = {}
local musicWatch = CreateFrame("Frame")

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
    -- only listening while a track of ours is on
    if id then
        musicWatch:RegisterEvent("CVAR_UPDATE")
    else
        musicWatch:UnregisterEvent("CVAR_UPDATE")
    end
    CH.RefreshNowPlaying()
end

-- Music switched off and on again (Ctrl+M, or all sound with Ctrl+S) comes
-- back as the zone's own. The client has dropped our track by then, Silence
-- too, so it goes on again.
musicWatch:SetScript("OnEvent", function(_, _, cvar)
    if (cvar == "Sound_EnableMusic" or cvar == "Sound_EnableAllSound") and GetCVarBool(cvar) then
        music.playing = nil
        ApplyMusic()
    end
end)

-- What the bar's ticker shows. Hands back the track on the music slot and a
-- list of the other files heard. The list holds the room's ambience, the
-- spot's over it and a room sound that loops. A sound being tried out stands
-- in for the room's, which is quiet meanwhile. A sound on a count is over
-- before anyone could read its name.
function CH.NowPlaying()
    local sting = slots.sting
    local files = {}
    files[#files + 1] = slots.preview.file or slots.room.file
    files[#files + 1] = slots.spot.file
    files[#files + 1] = not sting.left and sting.file or nil
    return music.playing, files
end

-- Called from the zone ticker with the ambience index of the current room, of
-- the bannerless room on top of it, the music id and a room's own sound file
-- with its play count, nil for none.
function CH.UpdateAmbience(room, spot, musicID, sting, plays)
    -- ambienceEnabled is the master mute, the three under it a kind each. The
    -- fourth kind, what other players set off, goes by CH.EchoesOn.
    local s = ChamberlainDB.settings
    if not (s.ambienceEnabled and s.soundAmbience) then
        room, spot = nil, nil
    end
    if not (s.ambienceEnabled and s.soundMusic) then
        musicID = nil
    end
    if not (s.ambienceEnabled and s.soundRooms) then
        sting = nil
    end
    -- a sound being tried out is heard alone and the room's own come back after
    if slots.preview.file then
        room, spot = nil, nil
    end
    SetSlot(slots.room, AmbienceFile(room))
    SetSlot(slots.spot, AmbienceFile(spot))
    SetSlot(slots.sting, sting, plays)
    -- keeps a running preview looping as well
    SetSlot(slots.preview, slots.preview.file)
    -- same for an echo still playing out, and this is where muting cuts it short
    SetSlot(slots.echo, CH.EchoesOn() and slots.echo.file or nil)
    music.wanted = musicID
    ApplyMusic()
end

function CH.EchoesOn()
    return ChamberlainDB.settings.ambienceEnabled and ChamberlainDB.settings.echoes
end

-- A room's sound set off by somebody else walking in, from the ECHO message
-- (Sharing/Share.lua). Cleared first since the same bell rings again for the
-- next visitor. A sound that loops for the one standing in it plays once here.
function CH.PlayEcho(file, plays)
    CH.StopEcho()
    SetSlot(slots.echo, file, math.max(plays, 1))
end

-- Also on the way out of a house. The ticker stops there, and a bell left
-- halfway trough its count would ring the rest in the next house.
function CH.StopEcho()
    SetSlot(slots.echo, nil)
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
