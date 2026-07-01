local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Housing detection + zone ticker
-- ─────────────────────────────────────────────────────────────────────

CH.currentHouseGUID = nil
CH.currentHouseOwner = nil
CH.isOwnHouse = false

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

local function IsInZone(zone, x, y, mapID)
    if zone.mapID ~= mapID then
        return false
    end
    -- Bounding-box reject first: cheap, and it's the whole test for a rectangle.
    if x < zone.minX or x > zone.maxX or y < zone.minY or y > zone.maxY then
        return false
    end
    if zone.shape == "circle" then
        -- Stored as a square box, so the centre is the box centre and the radius is
        -- half its width. Inside means within that radius of the centre.
        local cx = (zone.minX + zone.maxX) * 0.5
        local cy = (zone.minY + zone.maxY) * 0.5
        local r = (zone.maxX - zone.minX) * 0.5
        if r <= 0 then
            return false
        end
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= r * r
    end
    return true
end

-- An anchor is a zone that changes the active floor when stepped on. Absolute
-- anchors (setFloor) jump to a fixed floor. Relative anchors (floorDelta) move
-- up/down from the current one. A zone with neither is an ordinary room.
local function IsAnchor(zone)
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
        if IsAnchor(zone) and IsInZone(zone, x, y, mapID) then
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
        if CH.toolbox then
            CH.toolbox:Hide()
        end
        CH.HideBanner(0.8)
        CH.HideTalkingHead()
        CH.SetBannerRoom(nil)
        currentZone = nil
        currentAnchor = nil
        CH.activeFloor = 1
        wasInside = false
        promptedGUID = nil
        return
    end

    -- A new visit begins. Mark the floor as not-yet-resolved. The actual choice
    -- (restore the saved floor, or reset to 1) happens once the house id is known
    -- in the callback below. This runs only on the real transition in, not on
    -- every ZONE_CHANGED_NEW_AREA re-check while inside.
    if not wasInside then
        currentAnchor = nil
        wasInside = true
        floorResolved = false
        pendingRestore = isFirst
    end

    CH.hud:Show()
    CH.isOwnHouse = C_Housing.IsInsideOwnHouse()
    CH.RefreshHUDMode()
    if CH.WarmUpHeadModel then
        CH.WarmUpHeadModel()
    end -- one-time, only inside a house
    CH.currentHouseGUID = nil
    CH.currentHouseOwner = nil
    CH.zoneLabel:SetText("...")
    C_Housing.RequestCurrentHouseInfo()
    C_Timer.NewTimer(1.5, function()
        if not C_Housing.IsInsideHouse() then
            return
        end
        local info = C_Housing.GetCurrentHouseInfo()
        if not info then
            CH.zoneLabel:SetText(CH.L["HOUSE_HOME_INTERIOR"])
            return
        end
        -- info.houseGUID is an opaque per-session handle ("Opaque-2") and is NOT
        -- stable across reloads or clients. neighborhoodGUID + plotID is real
        -- server data and identifies the same plot everywhere, so that is the key.
        if info.neighborhoodGUID and info.plotID then
            CH.currentHouseGUID = info.neighborhoodGUID .. ":" .. info.plotID
        else
            CH.currentHouseGUID = info.houseGUID or info.guid or info.houseID
        end
        CH.currentHouseOwner = info.ownerName or info.owner
        CH.zoneLabel:SetText(CH.currentHouseOwner or CH.L["HOUSE_HOME_INTERIOR"])

        -- Resolve the active floor now that we know which house this is. Done once
        -- per visit (floorResolved gate), so re-checks while inside don't disturb a
        -- floor you've since walked to. On a reload/relog in place we restore the
        -- saved floor. On a real walk-in we're on the ground floor, floor 1.
        if not floorResolved and CH.currentHouseGUID then
            floorResolved = true
            if pendingRestore then
                CH.activeFloor = ChamberlainDB.floorMemory[CH.currentHouseGUID] or 1
            else
                CH.activeFloor = 1
                ChamberlainDB.floorMemory[CH.currentHouseGUID] = 1
            end
            if CH.OnActiveFloorChanged then
                CH.OnActiveFloorChanged()
            end
        end

        -- The house is identified now, so re-run the HUD layout: the visitor
        -- Floor Plan button depends on knowing the house and its stored layout.
        CH.RefreshHUDMode()

        if CH.isOwnHouse and CH.currentHouseGUID then
            CH.MigrateLegacyHouse(CH.currentHouseGUID, CH.currentHouseOwner)
            ChamberlainDB.myHouses[CH.currentHouseGUID] = true
            -- Stamp realm and display name on the house entry so the room list can
            -- disambiguate two houses whose owner character names happen to match.
            local h = ChamberlainDB.houses[CH.currentHouseGUID]
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
        local guid = CH.currentHouseGUID
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
    end)
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

    if CH.isOwnHouse then
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
    local found = nil
    local foundArea = math.huge
    for _, zone in ipairs(h.zones) do
        if IsInZone(zone, x, y, mapID) and (zone.floor or 1) == CH.activeFloor and not IsAnchor(zone) then
            local area = CH.ZoneArea(zone)
            if area < foundArea then
                found = zone
                foundArea = area
            end
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
            if ChamberlainDB.settings.entrySound then
                PlaySound(SOUNDKIT.MAP_PING, "SFX")
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
