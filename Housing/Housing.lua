local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Housing detection + zone ticker
-- ─────────────────────────────────────────────────────────────────────

CH.currentHouseGUID = nil
CH.currentHouseOwner = nil
CH.isOwnHouse = false

-- 12.1 renames IsInsideOwnHouse to IsInsideOwnedHouse (the PTR carries both,
-- live only the old one). Take whichever exists, drop the fallback once 12.1
-- is the only client left. The stricter OwnedPlot variants don't matter here,
-- IsInsideHouse is false on the lawn so this never runs out there.
local isInsideOwn = C_Housing.IsInsideOwnedHouse or C_Housing.IsInsideOwnHouse

-- The floor the player is currently on. There is no elevation API, so this is
-- infered: it starts at 1 on entering a house and is changed by walking onto
-- "anchor" zones placed at stair landings (see CheckZones). In-memory only;
-- anchors self-correct it, so it never needs persisting.
CH.activeFloor = 1

-- UnitPosition returns (posY, posX, posZ, mapID). Y is first, X second.
function CH.GetWorldPos()
    local py, px, _, mapID = UnitPosition("player")
    return px, py, mapID
end

-- A circle is stored as a square box, so the centre is the box centre and the
-- radius is half its width.
local function Circle(zone)
    return (zone.minX + zone.maxX) * 0.5, (zone.minY + zone.maxY) * 0.5, (zone.maxX - zone.minX) * 0.5
end

local function IsInZone(zone, x, y, mapID)
    if zone.mapID ~= mapID then
        return false
    end
    -- Bounding-box reject first: cheap, and it's the whole test for a rectangle.
    if x < zone.minX or x > zone.maxX or y < zone.minY or y > zone.maxY then
        return false
    end
    if zone.shape == "circle" then
        local cx, cy, r = Circle(zone)
        if r <= 0 then
            return false
        end
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= r * r
    end
    return true
end

-- Yards from a spot to the nearest edge of a room, 0 inside it. Flat, the
-- floors don't count. A room on another map is out of reach.
function CH.DistanceToZone(zone, x, y, mapID)
    if zone.mapID ~= mapID then
        return math.huge
    end
    if zone.shape == "circle" then
        local cx, cy, r = Circle(zone)
        local dx, dy = x - cx, y - cy
        return math.max(0, math.sqrt(dx * dx + dy * dy) - r)
    end
    local dx = math.max(zone.minX - x, 0, x - zone.maxX)
    local dy = math.max(zone.minY - y, 0, y - zone.maxY)
    return math.sqrt(dx * dx + dy * dy)
end

-- An anchor is a zone that changes the active floor when stepped on. Absolute
-- anchors (setFloor) jump to a fixed floor. Relative anchors (floorDelta) move
-- up/down from the current one. A zone with neither is an ordinary room.
function CH.IsAnchor(zone)
    return zone.setFloor ~= nil or zone.floorDelta ~= nil
end

-- The stair-landing footprint the player is standing on that would fire from the
-- active floor, or nil. An anchor only fires from the floor it connects FROM, so a
-- staircase is inert on floors it doesn't touch. This matters for spiral stairs,
-- where every landing stacks at the same X/Y. First match wins.
--   * relative anchor (floorDelta): fires from the floor it sits on.
--   * absolute anchor with fromFloor: fires only from that linked floor.
--   * absolute anchor without fromFloor: a manual "go to floor N" teleporter that
--     fires from any floor (the power-user dialog option, used rarely).
local function FindActiveAnchor(h, x, y, mapID)
    for _, zone in ipairs(h.zones) do
        if CH.IsAnchor(zone) and IsInZone(zone, x, y, mapID) then
            local fires
            if zone.setFloor ~= nil then
                fires = (zone.fromFloor == nil) or (zone.fromFloor == CH.activeFloor)
            else
                fires = (zone.floor or 1) == CH.activeFloor
            end
            if fires then
                return zone
            end
        end
    end
    return nil
end

local currentZone = nil
local echoZone = nil -- the room whose sound on entry we last walked into, so an echo goes out once per entry
local currentAnchor = nil -- the anchor footprint we're standing on; latched until we leave all anchors
local wasInside = false -- were we inside a house on the previous state check (for entry detection)
local firstCheck = true -- has CH.CheckHousingState run yet this session
local floorResolved = false -- have we set the active floor for the current visit yet
local pendingRestore = false -- this visit began as a reload/relog in place, so restore the saved floor
local promptedGUID = nil -- tracks which house we already printed the party-has-layout prompt for

-- Versions before 0.12.0 keyed houses by the client's opaque session handle
-- ("Opaque-2"), which changes between sessions and clients. When standing in
-- our own house, fold legacy entries with this house's owner into the stable
-- key. Legacy keys never contain ":"; stable keys always do.
function CH.MigrateLegacyHouse(stableKey, owner)
    if not owner then
        return
    end
    local legacy = {}
    for key, old in pairs(ChamberlainDB.houses) do
        if key ~= stableKey and not string.find(key, ":", 1, true) and old.owner == owner then
            legacy[#legacy + 1] = key
        end
    end
    for _, key in ipairs(legacy) do
        local old = ChamberlainDB.houses[key]
        local h = ChamberlainDB.houses[stableKey]
        if not h then
            ChamberlainDB.houses[stableKey] = old
        else
            for _, z in ipairs(old.zones or {}) do
                table.insert(h.zones, z)
            end
            if old.stats then
                h.stats = h.stats or {}
                for name, secs in pairs(old.stats) do
                    h.stats[name] = (h.stats[name] or 0) + secs
                end
            end
            if (old.updatedAt or 0) > (h.updatedAt or 0) then
                h.updatedAt = old.updatedAt
            end
        end
        ChamberlainDB.houses[key] = nil
        ChamberlainDB.myHouses[key] = nil
        CH.Print(CH.L["HOUSE_MIGRATED"])
    end
end

-- Rooms are map-bound: IsInZone rejects any zone whose stored mapID isn't the
-- map you're standing on. A moved house can come back on a new interior map id,
-- and so can one rebuilt from a blueprint, and then the rooms would draw on the
-- plan but never fire a banner, which looks like the repair half-worked. Re-stamp
-- them onto the map we're on now. A no-op when the id didn't change. Every zone
-- in a house shares one map by design (the room dialog refuses corners on
-- different maps), so stamping them all is safe. Only call this standing in the
-- house the entry belongs to.
function CH.StampHouseMap(h)
    local _, _, mapID = CH.GetWorldPos()
    if mapID then
        for _, z in ipairs(h.zones or {}) do
            z.mapID = mapID
        end
    end
end

-- Moving a house to another neighborhood mints a new stable key
-- (neighborhoodGUID:plotID), and the owner name on the entry can go stale too, so
-- the rooms saved under the old key are orphaned and the map comes up empty.
-- Re-point a saved house at the house you are standing in now, adopting its key,
-- owner and realm. Driven by the fixer dialog (UI/FixHouse.lua). Merge rules match
-- MigrateLegacyHouse for the case where the new key already holds an entry.
function CH.RepairHouseKey(oldKey)
    local newKey = CH.currentHouseGUID
    -- Hard gate: this marks the current house as yours (myHouses) and stamps its
    -- owner onto your rooms, so it must never run in someone else's house. The
    -- housing API is the authority, not the saved entry.
    if not CH.isOwnHouse then
        return false
    end
    if not newKey or not oldKey or oldKey == newKey then
        return false
    end
    local old = ChamberlainDB.houses[oldKey]
    if not old then
        return false
    end

    local h = ChamberlainDB.houses[newKey]
    if not h then
        ChamberlainDB.houses[newKey] = old
        h = old
    else
        -- An entry can exist without a zones table (a house you'd entered but never
        -- put a room in), so don't assume one is there to insert into.
        h.zones = h.zones or {}
        for _, z in ipairs(old.zones or {}) do
            table.insert(h.zones, z)
        end
        if old.stats then
            h.stats = h.stats or {}
            for name, secs in pairs(old.stats) do
                h.stats[name] = (h.stats[name] or 0) + secs
            end
        end
        if (old.floorCount or 1) > (h.floorCount or 1) then
            h.floorCount = old.floorCount
        end
        h.ambience = h.ambience or old.ambience
        h.music = h.music or old.music
        h.arrival = h.arrival or old.arrival
    end

    CH.StampHouseMap(h)

    -- Adopt the house actually being stood in. A move can change the owner name and
    -- the house name, so take both from the housing API rather than from the stale
    -- saved entry (and never from the player's own character).
    local info = C_Housing.GetCurrentHouseInfo()
    h.owner = (info and (info.ownerName or info.owner)) or CH.currentHouseOwner or h.owner
    h.houseName = (info and info.houseName) or h.houseName
    h.realm = GetRealmName()
    h.updatedAt = GetServerTime()

    ChamberlainDB.myHouses[newKey] = true
    ChamberlainDB.myHouses[oldKey] = nil
    -- Stored maps follow the house since they are of the same rooms.
    for _, e in ipairs(ChamberlainDB.archive) do
        if e.house == oldKey then
            e.house = newKey
            e.owner = h.owner
        end
    end
    -- Drop the old floor memory instead of carrying it over. You are standing in
    -- this house right now, so the floor you walked in on (already recorded against
    -- the new key on entry) is the truth. Copying the old house's last floor would
    -- make a later reload restore a floor you are not standing on.
    if ChamberlainDB.floorMemory then
        ChamberlainDB.floorMemory[oldKey] = nil
    end
    ChamberlainDB.houses[oldKey] = nil

    return true
end

-- Called on ZONE_CHANGED_NEW_AREA and PLAYER_LOGIN.
-- Re-requests house info every time so house transitions are caught.
function CH.CheckHousingState()
    -- "First check of the session" is how we tell a reload/relog in place from a
    -- normal walk-in: only a reload can land the very first check already inside a
    -- house. That case restores the saved floor. Every later entry resets to 1.
    local isFirst = firstCheck
    firstCheck = false

    if not C_Housing.IsInsideHouse() then
        CH.currentHouseGUID = nil
        CH.currentHouseOwner = nil
        CH.isOwnHouse = false
        CH.zoneLabel:SetText("-")
        CH.hud:Hide()
        -- the build tools and the map of the house you left go with it, but a
        -- map picked in the Rooms window stays
        if not CH.FP.viewGUID then
            CH.floorPlan:Hide()
        end
        CH.HideBanner(0.8)
        CH.HideTalkingHead()
        CH.SetBannerRoom(nil)
        CH.UpdateAmbience()
        CH.StopRoomSounds()
        CH.ForgetEchoes()
        CH.SetHudRoom(nil)
        currentZone = nil
        echoZone = nil
        currentAnchor = nil
        CH.activeFloor = 1
        wasInside = false
        promptedGUID = nil
        return
    end

    -- A new visit begins. Mark the floor as not-yet-resolved. The actual choice
    -- (restore the saved floor, or reset to 1) happens once the house id is known
    -- in CH.OnHouseInfo. This runs only on the real transition in, not on
    -- every ZONE_CHANGED_NEW_AREA re-check while inside.
    if not wasInside then
        currentAnchor = nil
        wasInside = true
        floorResolved = false
        pendingRestore = isFirst
        -- Unknown until the game says which house. Only on the way in: a
        -- re-check in the middle of a visit keeps the house it has, or the rooms
        -- would hang on a second answer that may never come. CH.OnHouseInfo
        -- swaps it if the answer names another house.
        CH.currentHouseGUID = nil
        CH.currentHouseOwner = nil
        CH.zoneLabel:SetText("...")
        -- First step indoors this visit: surface any post-update release notes.
        if CH.MaybeShowWhatsNew then
            CH.MaybeShowWhatsNew()
        end
    end

    CH.hud:Show()
    CH.isOwnHouse = isInsideOwn()
    CH.RefreshHUDMode()
    if CH.WarmUpHeadModel then
        CH.WarmUpHeadModel()
    end -- one-time, only inside a house
    -- The answer comes back as CURRENT_HOUSE_INFO_RECIEVED, see CH.OnHouseInfo.
    C_Housing.RequestCurrentHouseInfo()
end

-- A real walk-in rings the front door. We hear the house's arrival sound and
-- the others inside get a word so they hear theirs (room 0 of CH.SendEcho).
-- Without the map there's no telling whether the house has one, so that case
-- speaks up too. A map that has none stays quiet.
local function Arrive(guid)
    local h = ChamberlainDB.houses[guid]
    local sound = h and CH.GetHouseSound(guid, "arrival")
    -- our own way in is neither a groupmate's nor a guildmate's, so it takes
    -- both arrival mutes off to silence it
    local s = ChamberlainDB.settings
    if sound and s.ambienceEnabled and (s.arrivalGroup or s.arrivalGuild) then
        CH.PlayEcho(sound, 1)
    end
    if sound or not h then
        CH.SendEcho(guid)
    end
end

-- CURRENT_HOUSE_INFO_RECIEVED (Blizzard's spelling). A fixed wait before
-- reading GetCurrentHouseInfo is a guess. The info is nil from the door until
-- this event and a relaod had it three seconds out. Once you've left it still
-- names the house you were in.
--
-- It fires two or three times a visit and out on the plot as well, so it only
-- counts inside and once per house. On a walk-in the game sends one unasked
-- that beats ZONE_CHANGED_NEW_AREA by a few hundredths, before the entry above
-- has run. The entry runs from here then, so it doesn't matter which firing
-- shows up or whether our own request gets a reply of its own.
function CH.OnHouseInfo(info)
    if not C_Housing.IsInsideHouse() then
        return
    end
    if not wasInside then
        CH.CheckHousingState()
    end
    -- info.houseGUID is an opaque per-session handle ("Opaque-2") and is NOT
    -- stable across reloads or clients. neighborhoodGUID + plotID is real
    -- server data and identifies the same plot everywhere, so that is the key.
    local guid
    if info.neighborhoodGUID and info.plotID then
        guid = info.neighborhoodGUID .. ":" .. info.plotID
    else
        guid = info.houseGUID or info.guid or info.houseID
    end
    if guid == CH.currentHouseGUID then
        return
    end
    CH.currentHouseGUID = guid
    CH.currentHouseOwner = info.ownerName or info.owner
    CH.zoneLabel:SetText(CH.currentHouseOwner or CH.L["HOUSE_HOME_INTERIOR"])

    -- Resolve the active floor now that we know which house this is. Done once
    -- per visit (floorResolved gate), so re-checks while inside don't disturb a
    -- floor you've since walked to. On a reload/relog in place we restore the
    -- saved floor. On a real walk-in we're on the ground floor, floor 1, and the
    -- front door rings.
    if not floorResolved and guid then
        floorResolved = true
        if pendingRestore then
            CH.activeFloor = ChamberlainDB.floorMemory[guid] or 1
        else
            CH.activeFloor = 1
            ChamberlainDB.floorMemory[guid] = 1
            Arrive(guid)
        end
        if CH.OnActiveFloorChanged then
            CH.OnActiveFloorChanged()
        end
    end

    -- The house is identified now, so re-run the HUD layout: the visitor
    -- Floor Plan button depends on knowing the house and its stored layout.
    -- The minimap only swaps its picture for a house we hold rooms for.
    CH.RefreshHUDMode()
    CH.RefreshMinimapRooms()

    if CH.isOwnHouse and guid then
        CH.MigrateLegacyHouse(guid, CH.currentHouseOwner)
        ChamberlainDB.myHouses[guid] = true
        -- Stamp realm and display name on the house entry so the room list can
        -- disambiguate two houses whose owner character names happen to match.
        local h = ChamberlainDB.houses[guid]
        if h then
            h.realm = GetRealmName()
            h.houseName = info.houseName
        end
    end

    -- Let the party know what we have, and check if a party member has a
    -- layout for this house that we don't.
    CH.BroadcastCatalog()
    if CH.AnnounceOwnerPresence then
        CH.AnnounceOwnerPresence() -- in our own house, let visitors aim owner-head rooms at us
    end
    if guid and not ChamberlainDB.houses[guid] and guid ~= promptedGUID then
        if CH.partyCatalogs then
            for pName, catalog in pairs(CH.partyCatalogs) do
                if catalog[guid] then
                    promptedGUID = guid
                    CH.Print(CH.L["HOUSE_PARTY_HAS_LAYOUT_X"], pName)
                    break
                end
            end
        end
    end
end

-- Manual override: tell Chamberlain which floor you're actually on, for when the
-- guess is wrong (it never saw you take the stairs, or you jumped a balcony). The
-- floor plan's "Move to floor" button calls this. Persisted like any other change,
-- and self-correcting: the next anchor you cross still updates it.
function CH.SetActiveFloor(n)
    if not CH.currentHouseGUID then
        return
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    local count = (h and h.floorCount) or 1
    CH.activeFloor = math.max(1, math.min(count, n))
    ChamberlainDB.floorMemory[CH.currentHouseGUID] = CH.activeFloor
    if CH.OnActiveFloorChanged then
        CH.OnActiveFloorChanged()
    end
end

-- Re-latch the anchor under the player without applying any floor change. The floor
-- plan calls this after editing a stair box so a landing dragged or resized onto the
-- player reads as already-occupied, not as the player walking in, and so won't fire
-- a transition on the next tick (it must be left and re-entered to fire again).
function CH.SyncAnchorLatch()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local x, y, mapID
    if h then
        x, y, mapID = CH.GetWorldPos()
    end
    currentAnchor = (h and x) and FindActiveAnchor(h, x, y, mapID) or nil
end

function CH.CheckZones()
    -- Run for any house we have a layout for, not just our own. This lets a
    -- visitor who has the owner's shared layout see the room banners too.
    if not CH.currentHouseGUID then
        return
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    if not h then
        return
    end

    local x, y, mapID = CH.GetWorldPos()
    if not x then
        return
    end

    if CH.coordLabel:IsVisible() then
        CH.coordLabel:SetText(string.format(CH.L["HOUSE_COORD_X"], x, y))
    end

    -- 1. Anchor pass: the stair-landing footprint we're standing on that fires from
    -- the active floor (see FindActiveAnchor for the rules).
    --
    -- Edge-trigger latch keyed to the box we last fired on, not "any anchor". Release
    -- it the moment we step off that box, even straight onto another landing, so a
    -- normal up/down pair fires as you walk between them (step on "To F2", then back
    -- onto "To F1", and it drops you again). A spiral's two landings share one
    -- footprint, so stepping onto the other does not leave the fired box, and they
    -- still can't ping-pong the floor while you stand there.
    --
    -- Skip the effect while editing the layout (dragging or resizing a stair box):
    -- that slides the zone under a stationary player, which isn't walking onto it.
    -- CH.SyncAnchorLatch re-latches after an edit so it won't fire until you step off.
    if currentAnchor and not IsInZone(currentAnchor, x, y, mapID) then
        currentAnchor = nil
    end

    local anchor = FindActiveAnchor(h, x, y, mapID)
    if anchor and not currentAnchor and not CH.editingLayout then
        if anchor.setFloor ~= nil then
            CH.activeFloor = anchor.setFloor
        elseif anchor.floorDelta ~= nil then
            local floorCount = h.floorCount or 1
            CH.activeFloor = math.max(1, math.min(floorCount, CH.activeFloor + anchor.floorDelta))
        end
        ChamberlainDB.floorMemory[CH.currentHouseGUID] = CH.activeFloor
        currentAnchor = anchor
        if CH.OnActiveFloorChanged then
            CH.OnActiveFloorChanged()
        end
    end

    -- 2. Room pass: smallest matching room wins, scoped to the active floor.
    -- Standing on a named anchor, the anchor itself provides the banner.
    -- Bannerless rooms run their own smallest-wins beside it. They only bring
    -- a sound, so a hearth inside the great hall must not take the hall's place
    -- as the room you're in.
    local found, spot = nil, nil
    local foundArea, spotArea = math.huge, math.huge
    for _, zone in ipairs(h.zones) do
        if IsInZone(zone, x, y, mapID) and (zone.floor or 1) == CH.activeFloor and not CH.IsAnchor(zone) then
            local area = CH.ZoneArea(zone)
            if zone.noBanner then
                if area < spotArea then
                    spot = zone
                    spotArea = area
                end
            elseif area < foundArea then
                found = zone
                foundArea = area
            end
        end
    end
    -- There is one music slot, so a bannerless room with a track (a stage, a
    -- music box) takes it from the room around it. The sound on entry has one
    -- slot as well and goes the same way.
    local musicZone = spot and spot.music and spot or found
    local sfxZone = spot and spot.sfx and spot or found
    CH.UpdateAmbience(
        CH.ResolveSound(h, "ambience", found),
        spot and spot.ambience,
        CH.ResolveSound(h, "music", musicZone),
        sfxZone and sfxZone.sfx,
        sfxZone and sfxZone.sfxPlays
    )
    -- The others in the house hear it too when the room has an echo. Dragging
    -- a room over yourself in the floor plan isn't walking in.
    if sfxZone ~= echoZone then
        echoZone = sfxZone
        -- sfx is asked too: clearing the sound on 3.12.0 leaves the echo behind
        if sfxZone and sfxZone.sfx and sfxZone.echo and not CH.editingLayout then
            CH.SendEcho(CH.currentHouseGUID, h, sfxZone)
        end
    end
    -- A named anchor (one with a real name, not a bare floor switch) shows its
    -- own banner, the "Stairs Up" live confirmation, but only if no smaller room
    -- on this floor overlaps it.
    if anchor and not found then
        found = anchor
    end

    -- Time spent per room, accumulated at the ticker rate (own house only)
    if found and CH.isOwnHouse then
        h.stats = h.stats or {}
        h.stats[found.name] = (h.stats[found.name] or 0) + CH.ZONE_TICK
    end

    local foundName = found and found.name or nil
    if foundName ~= currentZone then
        currentZone = foundName
        CH.SetHudRoom(found)
        if found then
            -- Entering a room shows the gold banner with its name. If the room
            -- has a description, the banner's Read button opens the talking-head
            -- yapper on demand, we never pop it automatically. Close any yapper
            -- left over from the previous room.
            CH.HideTalkingHead()
            if ChamberlainDB.settings.bannerEnabled then
                local tc = found.color or CH.BANNER_TEXT_COLOR
                local lc = found.color or CH.BANNER_LINE_COLOR
                CH.bannerText:SetText(found.name)
                CH.bannerText:SetTextColor(tc[1], tc[2], tc[3], 1)
                CH.bannerLineTop:SetColorTexture(lc[1], lc[2], lc[3], 0.90)
                CH.bannerLineBot:SetColorTexture(lc[1], lc[2], lc[3], 0.90)
                CH.SetBannerRoom(found)
                CH.ShowBanner(0.5)
            else
                -- Banners off: keep it hidden even as rooms change.
                CH.SetBannerRoom(nil)
                CH.HideBanner(0)
            end
        else
            CH.HideTalkingHead()
            CH.SetBannerRoom(nil)
            CH.HideBanner(0.8)
        end
    end
end

-- Called when the "Show room banners" setting is flipped. Drop any banner that's
-- up right now if it was turned off, and clear the room latch so the next tick
-- re-decides (re-showing it if you're standing in a room and it was turned on).
function CH.OnBannerSettingChanged()
    currentZone = nil
    if not ChamberlainDB.settings.bannerEnabled then
        CH.HideBanner(0)
        CH.HideTalkingHead()
    end
end
