local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Archive  (stored house maps, blueprint and reset hooks)
-- ─────────────────────────────────────────────────────────────────────
-- A house has one live map, ChamberlainDB.houses[key], and that is all the
-- banner, the floor plan and sharing ever read. The archive is a separate list
-- of stored copies of it, so a map can be put away before a blueprint swap or a
-- house reset and brought back later, or several layouts of the same house can
-- be kept and switched between. Nothing in this list goes over the wire and the
-- share code never looks at it.
--
-- The live map remembers which entry it was stored as or restored from
-- (h.archived = { id, at }). While h.updatedAt still equals `at` the map is in
-- step with that entry, so switching away needs no question. Every edit path
-- bumps updatedAt, which is what breaks the tie.

local NAME_MAX = 48

function CH.ArchiveFind(id)
    for i, e in ipairs(ChamberlainDB.archive) do
        if e.id == id then
            return e, i
        end
    end
    return nil
end

-- Entries for one house (or all of them with nil), newset first.
function CH.ArchiveEntries(houseKey)
    local list = {}
    for _, e in ipairs(ChamberlainDB.archive) do
        if not houseKey or e.house == houseKey then
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b)
        return (a.savedAt or 0) > (b.savedAt or 0)
    end)
    return list
end

-- Cheap yes/no, no list built, for callers that redraw often.
function CH.ArchiveHas(houseKey)
    for _, e in ipairs(ChamberlainDB.archive) do
        if e.house == houseKey then
            return true
        end
    end
    return false
end

-- A stored map is waiting for the house you're in: it is yours, it has no rooms
-- and the archive holds a map for it. The launcher and the empty floor plan
-- both point at the archive then.
function CH.ArchiveWaiting(houseKey)
    if not CH.isOwnHouse or not houseKey then
        return false
    end
    local h = ChamberlainDB.houses[houseKey]
    if h and h.zones and #h.zones > 0 then
        return false
    end
    return CH.ArchiveHas(houseKey)
end

-- The entry the live map still matches, or nil once it has been edited (or the
-- entry was deleted from under it).
function CH.ArchiveInStep(h)
    local mark = h and h.archived
    if not mark or mark.at ~= h.updatedAt then
        return nil
    end
    return CH.ArchiveFind(mark.id)
end

local function Mark(h, id)
    h.archived = id and { id = id, at = h.updatedAt } or nil
end

-- Same label the room list and the fixer use for a house.
function CH.ArchiveHouseLabel(owner)
    return string.format(CH.L["RM_X_HOUSE"], owner or CH.L["RM_HOME_INTERIOR"])
end

local function TrimName(name)
    name = string.match(name or "", "^%s*(.-)%s*$")
    return string.sub(name, 1, NAME_MAX)
end

-- The window lives in UI/Archive.lua and refreshes itself only while open.
local function Refresh()
    if CH.RefreshArchive then
        CH.RefreshArchive()
    end
end

-- The live map of the house you're standing in, when it is yours and has rooms
-- (the only case the game hooks care about). Returns the key and the entry.
local function OwnMapWithRooms()
    local key = CH.currentHouseGUID
    if not CH.isOwnHouse or not key then
        return nil
    end
    local h = ChamberlainDB.houses[key]
    if not h or not h.zones or #h.zones == 0 then
        return nil
    end
    return key, h
end

-- Refresh fan-out after the live map changed wholesale. TouchHouse bumps
-- updatedAt, redraws the map, room list and launcher and queues the catalog
-- broadcast (the live map is what peers see, and it did change). The mark goes
-- on after that bump so it carries the new updatedAt.
local function AfterSwap(houseKey, id)
    local h = ChamberlainDB.houses[houseKey]
    if CH.SetSelection then
        CH.SetSelection(nil, nil) -- the toolbox and map held a room from the old map
    end
    CH.TouchHouse(houseKey)
    Mark(h, id)
    if houseKey == CH.currentHouseGUID then
        CH.SetActiveFloor(CH.activeFloor) -- clamps to the new floor count
        CH.SyncAnchorLatch()
    end
    Refresh()
end

-- Copy the live map into a new entry. A blank name gets the house and the date,
-- or the blueprint's name when one is attached.
function CH.ArchiveStore(houseKey, name, blueprint)
    local h = ChamberlainDB.houses[houseKey]
    if not h or not h.zones or #h.zones == 0 then
        return nil
    end
    local savedAt = GetServerTime()
    name = TrimName(name)
    if name == "" then
        name = blueprint and blueprint.name
            or string.format(CH.L["AR_DEFAULT_NAME_X"], CH.ArchiveHouseLabel(h.owner), date("%Y-%m-%d", savedAt))
    end
    local id = ChamberlainDB.archiveNextId
    ChamberlainDB.archiveNextId = id + 1
    local e = {
        id = id,
        house = houseKey,
        owner = h.owner,
        houseName = h.houseName,
        realm = h.realm,
        name = name,
        savedAt = savedAt,
        floorCount = h.floorCount or 1,
        ambience = h.ambience and CopyTable(h.ambience) or nil,
        music = h.music and CopyTable(h.music) or nil,
        zones = CopyTable(h.zones),
        stats = h.stats and CopyTable(h.stats) or nil,
        blueprint = blueprint and { code = blueprint.code, name = blueprint.name } or nil,
    }
    table.insert(ChamberlainDB.archive, e)
    Mark(h, id)
    CH.Print(CH.L["AR_STORED_X"], name)
    Refresh()
    return e
end

-- Empty the live map. The house entry stays (ownership, name, realm) and only
-- the rooms go, so nothing fires in a house that was reset or rebuilt from a
-- different blueprint.
function CH.ArchiveClear(houseKey)
    local h = ChamberlainDB.houses[houseKey]
    if not h then
        return
    end
    h.zones = {}
    h.floorCount = 1
    h.ambience = nil
    h.music = nil
    h.stats = nil
    AfterSwap(houseKey, nil)
    CH.Print(CH.L["AR_CLEARED"])
end

-- Bring a stored map back as the live map of the house it came from, or of
-- `houseKey` when given (the house you're standing in, for a map made for a
-- blueprint you've now loaded there).
function CH.ArchiveRestore(id, houseKey)
    local e = CH.ArchiveFind(id)
    if not e then
        return false
    end
    houseKey = houseKey or e.house
    local h = ChamberlainDB.houses[houseKey]
    if not h then
        -- Entries only ever come from your own houses, so the live entry is
        -- missing because it was cleaned up at some point, or because the house
        -- you're standing in never had a room yet. Rebuild it as yours.
        h = { updatedAt = 0 }
        if houseKey == CH.currentHouseGUID then
            h.owner = CH.currentHouseOwner
            h.realm = GetRealmName()
        else
            h.owner, h.houseName, h.realm = e.owner, e.houseName, e.realm
        end
        ChamberlainDB.houses[houseKey] = h
        ChamberlainDB.myHouses[houseKey] = true
    end
    h.zones = CopyTable(e.zones)
    h.floorCount = e.floorCount or 1
    h.ambience = e.ambience and CopyTable(e.ambience) or nil
    h.music = e.music and CopyTable(e.music) or nil
    h.stats = e.stats and CopyTable(e.stats) or nil
    -- Standing in the house, re-stamp the rooms onto the map we're on. A house
    -- rebuilt from a blueprint may come back on a new interior map id, another
    -- house of yours has its own, and a stored map from elsewhere would draw
    -- fine but never fire a banner.
    if houseKey == CH.currentHouseGUID then
        CH.StampHouseMap(h)
    end
    AfterSwap(houseKey, id)
    CH.Print(CH.L["AR_RESTORED_X"], e.name)
    return true
end

function CH.ArchiveRename(id, name)
    local e = CH.ArchiveFind(id)
    name = TrimName(name)
    if not e or name == "" then
        return
    end
    e.name = name
    Refresh()
end

function CH.ArchiveDelete(id)
    local e, i = CH.ArchiveFind(id)
    if not e then
        return
    end
    table.remove(ChamberlainDB.archive, i)
    CH.Print(CH.L["AR_DELETED_X"], e.name)
    Refresh()
end

-- ─────────────────────────────────────────────────────────────────────
-- Blueprints
-- ─────────────────────────────────────────────────────────────────────
-- Blueprints from the player's collection that hold the inside of the house,
-- whole-house and interior-only, as { code, name }, for the picker in the store
-- dialog. The rooms are all indoors, so those two are the ones a map belongs
-- with. Room and exterior blueprints don't describe it, and the autosaves the
-- game makes on every import would only bury the real ones, so they are left
-- out. The collection is async and Blizzard's own blueprint window asks for it
-- too (after every save, load, rename and delete), so the answer we consume may
-- well be theirs. Same data either way. We only ask when the player opens the
-- store dialog or has just saved a blueprint.

local blueprints = {}
local waiting = {} -- callbacks for the collection currently requested

local events = CreateFrame("Frame")

local function HoldsInterior(blueprintType)
    return blueprintType == Enum.HousingBlueprintType.House or blueprintType == Enum.HousingBlueprintType.Interior
end

function CH.HouseBlueprints()
    return blueprints
end

function CH.RequestBlueprints(callback)
    if not C_HousingBlueprint then
        return
    end
    waiting[#waiting + 1] = callback
    events:RegisterEvent("HOUSING_BLUEPRINT_COLLECTION_RECEIVED")
    events:RegisterEvent("HOUSING_BLUEPRINT_COLLECTION_FAILURE")
    C_HousingBlueprint.RequestBlueprintCollection()
end

local function CollectionDone(collection)
    events:UnregisterEvent("HOUSING_BLUEPRINT_COLLECTION_RECEIVED")
    events:UnregisterEvent("HOUSING_BLUEPRINT_COLLECTION_FAILURE")
    if collection then
        wipe(blueprints)
        for _, group in ipairs(collection.groups) do
            for _, bp in ipairs(group.entries) do
                if HoldsInterior(bp.blueprintType) and not bp.isAutoSave then
                    blueprints[#blueprints + 1] = { code = bp.shareCode, name = bp.name }
                end
            end
        end
    end
    local list = waiting
    waiting = {}
    for _, cb in ipairs(list) do
        cb()
    end
end

-- The player just saved a blueprint. If it holds the interior and the live map
-- isn't already stored against that code, offer to store the map with it.
local function OnBlueprintSaved(code)
    local key, h = OwnMapWithRooms()
    if not key or not HoldsInterior(C_HousingBlueprint.GetBlueprintTypeForCode(code)) then
        return
    end
    local stored = CH.ArchiveInStep(h)
    if stored and stored.blueprint and stored.blueprint.code == code then
        return
    end
    CH.OpenArchiveStore(key, { code = code })
end

-- The newest stored map tagged with a blueprint code, this house's own first,
-- then any house (the same blueprint lays the rooms out the same way wherever
-- it is loaded).
local function EntryForBlueprint(code, houseKey)
    local other
    for _, e in ipairs(CH.ArchiveEntries(nil)) do
        if e.blueprint and e.blueprint.code == code then
            if e.house == houseKey then
                return e
            end
            other = other or e
        end
    end
    return other
end

-- The player just loaded a blueprint. The success event has no payload, so the
-- import call is hooked for its code, and the map stored with that blueprint
-- comes back into the house you're in. Room blueprints load through a
-- different call and never match. A house already in step with it is left
-- alone.
local importCode

local function OnBlueprintLoaded()
    local code = importCode
    importCode = nil
    local key = CH.currentHouseGUID
    if not code or not CH.isOwnHouse or not key then
        return
    end
    local e = EntryForBlueprint(code, key)
    if not e then
        return
    end
    local stored = CH.ArchiveInStep(ChamberlainDB.houses[key])
    if not stored or stored.id ~= e.id then
        CH.ArchiveSwitchTo(e.id, key)
    end
end

-- HOUSE_RESET_COMPLETED says nothing about what was reset, so remember the scope
-- the player asked for. It is a bitmask, Blizzard's reset menu passes Interior,
-- Exterior or both together for "everything". An exterior-only reset leaves the
-- rooms alone. No scope on record (a reset we didn't see asked for) counts as
-- touching the interior.
local resetScope

local function OnHouseReset()
    local scope = resetScope
    resetScope = nil
    if scope and bit.band(scope, Enum.HousingHouseScope.Interior) == 0 then
        return
    end
    local key, h = OwnMapWithRooms()
    if key then
        CH.OpenArchiveResetPrompt(key, #h.zones)
    end
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "HOUSING_BLUEPRINT_COLLECTION_RECEIVED" then
        CollectionDone(arg1)
    elseif event == "HOUSING_BLUEPRINT_COLLECTION_FAILURE" then
        CollectionDone(nil)
    elseif event == "HOUSING_BLUEPRINT_EXPORT_SUCCESS" then
        OnBlueprintSaved(arg1)
    elseif event == "HOUSING_BLUEPRINT_IMPORT_SUCCESS" then
        OnBlueprintLoaded()
    elseif event == "HOUSE_RESET_COMPLETED" then
        OnHouseReset()
    end
end)

-- Blueprints and the house reset arrived with 12.1. On an older client the
-- namespace is nil and the events don't exist (registering an unknown event
-- throws), so the archive is names-only there.
if C_HousingBlueprint then
    events:RegisterEvent("HOUSING_BLUEPRINT_EXPORT_SUCCESS")
    events:RegisterEvent("HOUSING_BLUEPRINT_IMPORT_SUCCESS")
    -- Blizzard's import window calls this after its own confirm popup, so the
    -- hook sees the code the player picked or typed.
    hooksecurefunc(C_HousingBlueprint, "ImportBlueprint", function(code)
        importCode = code
    end)
end
-- ResetHouse is restricted (the player has to confirm it in Blizzard's own
-- popup), so this only ever listens and never calls it.
if C_Housing.ResetHouse then
    hooksecurefunc(C_Housing, "ResetHouse", function(scope)
        resetScope = scope
    end)
    events:RegisterEvent("HOUSE_RESET_COMPLETED")
end
