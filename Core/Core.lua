local ADDON, CH = ...

CH.VERSION = "3.1.0"

-- How often the zone ticker samples your position, in seconds. Drives stair
-- detection and the per-room time stats both, so they stay in step if it changes.
CH.ZONE_TICK = 0.1

-- ─────────────────────────────────────────────────────────────────────
-- Chat output
-- ─────────────────────────────────────────────────────────────────────
-- One gold-prefixed print helper so localized message values hold only the
-- sentence, not the brand prefix. The format runs through pcall so a bad
-- translation (e.g. a contributor drops a %s) degrades to the raw string
-- instead of throwing a Lua error mid-session. fmt is usually a CH.L value.
function CH.Print(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print("|cffFFD700Chamberlain:|r " .. (ok and s or fmt))
end

-- ─────────────────────────────────────────────────────────────────────
-- Talking-head cast
-- ─────────────────────────────────────────────────────────────────────
-- A curated set of 3D heads for the room "talking head" RP box. Rooms store only
-- the index into this table (headID), so just a small integer crosses the wire.
-- `display` is a creature display ID.
--
-- To add a head: stand near the NPC in-game, target it, and run
--   /run local m=CreateFrame("PlayerModel"); m:SetUnit("target"); C_Timer.After(1,function() print(m:GetDisplayInfo()) end)
-- (or read "Display ID" off the NPC's WoWhead model viewer), then add a line
-- below. Order is the wire identity: only ever append, never reorder or remove,
-- or shared rooms will point at the wrong head.
-- `gender` ("male"/"female") only picks the personal default TTS voice for a room
-- with no per-room voice (see CH.ResolveZoneVoice); it isn't sent over the wire.
CH.HEADS = {
    { name = "Lord Chamberlain", display = 131311, gender = "male" }, -- 1: default (npc 164218)
    { name = "Khadgar", display = 65834, gender = "male" }, -- 2
    { name = "Xal'atath", display = 131474, gender = "female" }, -- 3: The Harbinger
    { name = "Ysera", display = 35253, gender = "female" }, -- 4
    { name = "King Varian Wrynn", display = 28127, gender = "male" }, -- 5
    { name = "Sire Denathrius", display = 92797, gender = "male" }, -- 6
    { name = "Illidan Stormrage", display = 74146, gender = "male" }, -- 7
    { name = "Wrathion <The Black Prince>", display = 93216, gender = "male" }, -- 8
    -- Append new heads at the end, never reorder (order is wire identity):
    -- { name = "Mage",    display = <displayID>, gender = "male" },  -- 9
}

-- ─────────────────────────────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────────────────────────────

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then
            return
        end
        -- A brand-new DB (no SavedVariables file yet) means a first install, not an
        -- upgrade. Used below to decide whether the "What's New" popup fires: fresh
        -- installs start current, upgraders see this release's notes on first entry.
        local freshInstall = (ChamberlainDB == nil)
        ChamberlainDB = ChamberlainDB or {}
        if ChamberlainDB.hudX == nil then
            ChamberlainDB.hudX = -320
        end
        if ChamberlainDB.hudY == nil then
            ChamberlainDB.hudY = 0
        end
        if ChamberlainDB.toolboxX == nil then
            ChamberlainDB.toolboxX = -300
        end
        if ChamberlainDB.toolboxY == nil then
            ChamberlainDB.toolboxY = -40
        end
        if ChamberlainDB.bannerX == nil then
            ChamberlainDB.bannerX = 0
        end
        -- bannerY depends on screen height, resolved in PLAYER_LOGIN
        if ChamberlainDB.thX == nil then
            ChamberlainDB.thX = 0
        end
        -- thY (talking-head Y) depends on screen height, resolved in PLAYER_LOGIN
        if ChamberlainDB.houses == nil then
            ChamberlainDB.houses = {}
        end
        if ChamberlainDB.myHouses == nil then
            ChamberlainDB.myHouses = {}
        end
        if ChamberlainDB.blocks == nil then
            ChamberlainDB.blocks = { houses = {}, players = {} }
        end
        -- Senders you've chosen to auto-accept shared layouts from, by character name.
        if ChamberlainDB.trusted == nil then
            ChamberlainDB.trusted = {}
        end
        if ChamberlainDB.settings == nil then
            ChamberlainDB.settings = { conflictMode = "ask", shareEnabled = true }
        end
        if ChamberlainDB.settings.entrySound == nil then
            ChamberlainDB.settings.entrySound = false
        end
        if ChamberlainDB.settings.hudHidden == nil then
            ChamberlainDB.settings.hudHidden = false
        end
        if ChamberlainDB.settings.showRoomText == nil then
            ChamberlainDB.settings.showRoomText = true
        end
        -- Whether the gold room banner appears on entry. Off is for players who only
        -- want the map. Personal and local, never shared.
        if ChamberlainDB.settings.bannerEnabled == nil then
            ChamberlainDB.settings.bannerEnabled = true
        end
        -- Personal text-to-speech defaults (local only, voiceFemale/voiceMale stay
        -- nil until the player picks them). When enabled, these read rooms shared
        -- to you that have no voice of their own. See CH.ResolveZoneVoice.
        if ChamberlainDB.settings.voiceDefaultsEnabled == nil then
            ChamberlainDB.settings.voiceDefaultsEnabled = false
        end
        -- Seconds before the room banner fades out after it appears. 0 keeps it up
        -- until you leave the room.
        if ChamberlainDB.settings.bannerTimeout == nil then
            ChamberlainDB.settings.bannerTimeout = 0
        end
        -- Shown once, the first time a user adds a second floor: a note that
        -- Chamberlain can't read elevation and to mark their stairs.
        if ChamberlainDB.settings.seenFloorIntro == nil then
            ChamberlainDB.settings.seenFloorIntro = false
        end
        -- Draw stair anchors on the floor plan. On by default. The floor plan has a
        -- "Show stairs" checkbox to hide them for a cleaner map.
        if ChamberlainDB.settings.showStairsOnMap == nil then
            ChamberlainDB.settings.showStairsOnMap = true
        end
        -- Whether the floor plan was open last time. Restored on login only when
        -- standing inside a house (see CH.RestoreFloorPlan); outside a house it
        -- stays closed even if it was open when you left.
        if ChamberlainDB.settings.floorPlanOpen == nil then
            ChamberlainDB.settings.floorPlanOpen = false
        end
        -- Last active floor per house, so a /reload or relog while standing inside
        -- restores the floor you were on. Reset to 1 on a real re-entry (you always
        -- walk into a house on the ground floor).
        if ChamberlainDB.floorMemory == nil then
            ChamberlainDB.floorMemory = {}
        end
        if ChamberlainDB.recentColors == nil then
            ChamberlainDB.recentColors = {}
        end
        -- Whether the "What's New" popup appears after an update. The popup's
        -- "Don't show again" button flips this off.
        if ChamberlainDB.settings.showUpdateNotes == nil then
            ChamberlainDB.settings.showUpdateNotes = true
        end
        -- The version whose notes the player has already seen. A fresh install
        -- starts current (no notes on a first run). An upgrade from before this
        -- field existed leaves it nil, so the popup shows this release's notes on
        -- the next house entry, then stamps CH.VERSION (see CH.MaybeShowWhatsNew).
        if ChamberlainDB.lastSeenVersion == nil and freshInstall then
            ChamberlainDB.lastSeenVersion = CH.VERSION
        end
        if ChamberlainDB.minimapAngle == nil then
            ChamberlainDB.minimapAngle = 220
        end
        if ChamberlainDB.scrollSpeed == nil then
            ChamberlainDB.scrollSpeed = 8
        end -- talking-head text scroll (px/s)
        for _, h in pairs(ChamberlainDB.houses) do
            if h.updatedAt == nil then
                h.updatedAt = 0
            end
            -- Every house has at least one floor, and every zone belongs to floor 1
            -- unless it says otherwise. Backfiled for DBs from before multi-floor.
            if h.floorCount == nil then
                h.floorCount = 1
            end
            if h.zones then
                for _, z in ipairs(h.zones) do
                    if z.floor == nil then
                        z.floor = 1
                    end
                end
            end
        end
        C_ChatInfo.RegisterAddonMessagePrefix("CH")
        CH.ApplyHUDPos()
        if CH.ApplyToolboxPos then
            CH.ApplyToolboxPos()
        end
    elseif event == "PLAYER_LOGIN" then
        if ChamberlainDB.bannerY == nil then
            -- 25% from top = UIParent height * 0.25 above centre
            ChamberlainDB.bannerY = math.floor(UIParent:GetHeight() * 0.25)
        end
        if ChamberlainDB.thY == nil then
            -- Sit the talking head a little below the banner's default spot
            ChamberlainDB.thY = math.floor(UIParent:GetHeight() * 0.12)
        end
        CH.ApplyBannerPos()
        CH.ApplyTalkingHeadPos()
        C_Timer.NewTicker(CH.ZONE_TICK, CH.CheckZones)
        CH.CheckHousingState()
        if CH.RestoreFloorPlan then
            CH.RestoreFloorPlan()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        CH.CheckHousingState()
    end
end)

-- ─────────────────────────────────────────────────────────────────────
-- Slash commands  (/chamberlain  or  /rooms)
-- ─────────────────────────────────────────────────────────────────────

SLASH_CH1 = "/chamberlain"
SLASH_CH2 = "/rooms"
SlashCmdList["CH"] = function(msg)
    local cmd, rest = string.match(msg, "^(%S+)%s*(.*)")
    cmd = string.lower(cmd or "")
    rest = string.match(rest or "", "^%s*(.-)%s*$")

    if cmd == "list" or cmd == "manage" then
        CH.OpenRoomManager()
    elseif cmd == "build" then
        CH.OpenToolbox()
    elseif cmd == "settings" or cmd == "options" then
        CH.OpenSettings()
    elseif cmd == "delete" or cmd == "del" then
        if not CH.isOwnHouse then
            CH.Print(CH.L["CMD_DELETE_OWN_ONLY"])
            return
        end
        if rest == "" then
            CH.Print(CH.L["CMD_DELETE_USAGE"])
            return
        end
        local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
        if not h then
            CH.Print(CH.L["CMD_NOT_IN_HOUSE"])
            return
        end
        for i, z in ipairs(h.zones) do
            if z.name:lower() == rest:lower() then
                table.remove(h.zones, i)
                CH.DropZoneStats(h, z.name)
                h.updatedAt = GetServerTime()
                CH.RebuildFloorPlan()
                CH.QueueBroadcast(CH.currentHouseGUID)
                CH.Print(CH.L["CMD_DELETED_ROOM_X"], z.name)
                return
            end
        end
        CH.Print(CH.L["CMD_ROOM_NOT_FOUND_X"], rest)
    elseif cmd == "reset" then
        ChamberlainDB.hudX = -320
        ChamberlainDB.hudY = 0
        ChamberlainDB.toolboxX = -300
        ChamberlainDB.toolboxY = -40
        ChamberlainDB.bannerX = 0
        ChamberlainDB.bannerY = math.floor(UIParent:GetHeight() * 0.25)
        ChamberlainDB.thX = 0
        ChamberlainDB.thY = math.floor(UIParent:GetHeight() * 0.12)
        CH.ApplyHUDPos()
        if CH.ApplyToolboxPos then
            CH.ApplyToolboxPos()
        end
        CH.ApplyBannerPos()
        CH.ApplyTalkingHeadPos()
        CH.Print(CH.L["CMD_POSITIONS_RESET"])
    elseif cmd == "hud" then
        local hidden = CH.ToggleHud()
        if hidden then
            CH.Print(CH.L["CMD_HUD_HIDDEN"])
        elseif C_Housing.IsInsideHouse() then
            CH.Print(CH.L["CMD_HUD_SHOWN"])
        else
            CH.Print(CH.L["CMD_HUD_WILL_SHOW"])
        end
    elseif cmd == "floor" then
        CH.OpenFloorPlan()
    elseif cmd == "whatsnew" or cmd == "changes" then
        CH.OpenWhatsNew()
    elseif cmd == "fixer" then
        -- Repair tool, deliberately left out of the help list: re-points a saved
        -- house at the one you're standing in, for when a house move changed its
        -- internal id and owner name (see UI/FixHouse.lua).
        CH.OpenFixHouse()
    elseif cmd == "debug" then
        CH.shareDebug = not CH.shareDebug
        CH.Print(CH.shareDebug and CH.L["CMD_DEBUG_ON"] or CH.L["CMD_DEBUG_OFF"])
    elseif cmd == "version" then
        print(ADDON .. " v" .. CH.VERSION)
    else
        -- "help", empty, and anything unrecognized all land here
        print(string.format(CH.L["CMD_HELP_HEADER_X"], CH.VERSION))
        print(CH.L["CMD_HELP_BUILD"])
        print(CH.L["CMD_HELP_MANAGE"])
        print(CH.L["CMD_HELP_FLOOR"])
        print(CH.L["CMD_HELP_SETTINGS"])
        print(CH.L["CMD_HELP_DELETE"])
        print(CH.L["CMD_HELP_RESET"])
        print(CH.L["CMD_HELP_HUD"])
        print(CH.L["CMD_HELP_WHATSNEW"])
        print(CH.L["CMD_HELP_DEBUG"])
        print(CH.L["CMD_HELP_VERSION"])
    end
end
