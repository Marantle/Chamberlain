local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Party layout sharing  (catalog broadcast, request/consent, transfer)
-- ─────────────────────────────────────────────────────────────────────
-- The dialogs and progress bars this drives live in ShareUI.lua. This file is
-- the protocol, serialization, send queue and message handler.

CH.partyCatalogs = {} -- { [playerName] = { [houseGUID] = { owner, timestamp, zoneCount } } }
CH.pendingLayouts = {} -- partial incoming transfers keyed by houseGUID

local pendingRequests = {} -- GUIDs we sent LAYOUT_REQ for; consumed on receipt

-- Bump only when an existing message format changes incompatibly.
-- Mismatched protocol = sharing will not work with that client.
-- 2: house keys changed from the client's opaque session handle to the stable
--    neighborhoodGUID:plotID form (0.12.0).
-- 3: layout transfer replaced the per-room LAYOUT_* + ZTEXT stream with a single
--    compressed blob (rooms + heads + descriptions) split into BLOB chunks
--    (2.0.0). Pre-3 clients can't read it, so sharing is gated by version.
local PROTOCOL = 3

-- Senders whose HELLO carried a different protocol. Their sharing traffic is
-- dropped. Rebuilt on every roster change (so it reflects the current group).
local incompatible = {}

-- Senders we've already shown the version-mismatch warning to. Unlike
-- `incompatible`, this is NOT cleared on roster change, so a role check or queue
-- (which fires GROUP_ROSTER_UPDATE repeatedly) doesn't re-spam the warning. The
-- warning shows once per sender per session.
local warnedMismatch = {}

-- Each group member's addon version, from their HELLO. Same protocol can still
-- mean different features: floors (2.4.0) ride along the blob as appended fields,
-- so an older peer shares fine but can't show them. Rebuilt on roster change.
local peerVersions = {}

-- Floors were added in this version. Older peers read the blob but ignore them.
local FLOOR_MIN_VERSION = "2.4.0"

-- True if version string a is numerically older than b (compares X.Y.Z parts).
local function VersionOlder(a, b)
    local pa, pb = {}, {}
    for n in tostring(a):gmatch("%d+") do
        pa[#pa + 1] = tonumber(n)
    end
    for n in tostring(b):gmatch("%d+") do
        pb[#pb + 1] = tonumber(n)
    end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return x < y
        end
    end
    return false
end

CH.shareDebug = false -- /chamberlain debug

local function Debug(...)
    if CH.shareDebug then
        print("|cff888888[CH debug]|r", ...)
    end
end

-- Pick the addon-message channel from the *actual* group category. In a solo
-- delve or LFR you are in an INSTANCE group, not a home party/raid: IsInGroup()
-- is true but the PARTY/RAID channels don't exist there, so the server rejects
-- every send with "You aren't in a party/raid." Instance groups must use
-- INSTANCE_CHAT. Returns nil when there is no group to send to.
local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    return nil
end

-- What holds for the guild channel as much as for the group.
local function SendingAllowed()
    if C_ChatInfo.InChatMessagingLockdown() then
        Debug("send skipped: messaging lockdown")
        return false
    end
    if not ChamberlainDB.settings.shareEnabled then
        Debug("send skipped: sharing disabled")
        return false
    end
    return true
end

local function CanSend()
    if not GroupChannel() then
        Debug("send skipped: not in group")
        return false
    end
    return SendingAllowed()
end

-- Outgoing messages go through a token-bucket queue. WoW gives each addon prefix
-- an allowance of ~10 messages that refills at 1/second. Firing a layout's chunks
-- all at once overruns it and the tail is dropped. Mirror that bucket: burst up to
-- TOKENS_MAX, then 1/second.
local SEND_INTERVAL = 0.1
local TOKENS_MAX = 8 -- leave headroom below the ~10 server allowance
local TOKEN_RATE = 1 -- 1/sec sustained, matching the server's delivery. Higher
-- overruns it: past ~16-20 messages every other one drops.
local sendQueue = {} -- background traffic: HELLO, CATALOG, LAYOUT_REQ/DECLINE
local sendQueueHi = {} -- user-initiated layout transfer (BLOBSTART/BLOB); jumps ahead
local sendQueueGuild = {} -- echoes for guildmates outside the group, the one thing sent on GUILD
local sendTicker
local tokens = TOKENS_MAX
local lastTick

-- Send-side progress, counted in BLOB chunks being sent out.
local sendRoomsTotal, sendRoomsDone = 0, 0

-- The next message out and the channel it goes on. A guild echo is one short
-- message and goes ahead of the rest. After it the layout transfer drains
-- first so a user-initiated share isn't stuck behind routine catalog/HELLO
-- chatter (which would freeze its progress bar). FlushQueue empties the group
-- lanes whenever there is no group channel.
local function NextOut(channel)
    if #sendQueueGuild > 0 then
        return table.remove(sendQueueGuild, 1), "GUILD"
    elseif #sendQueueHi > 0 then
        return table.remove(sendQueueHi, 1), channel
    elseif #sendQueue > 0 then
        return table.remove(sendQueue, 1), channel
    end
end

local function FlushQueue()
    local now = GetTime()
    tokens = math.min(TOKENS_MAX, tokens + (now - (lastTick or now)) * TOKEN_RATE)
    lastTick = now

    -- Pick the channel at flush time so it reflects the current group category
    -- (home party/raid vs. instance group). If the group is gone, drop the
    -- queued traffic rather than firing PARTY/RAID into the void. The guild
    -- lane doesn't care about the group and stays.
    local channel = GroupChannel()
    if not channel then
        sendQueue, sendQueueHi = {}, {}
    end
    while tokens >= 1 do
        local payload, to = NextOut(channel)
        if not payload then
            break
        end
        tokens = tokens - 1
        local prefix = payload:find("^ECHO") and CH.ECHO_PREFIX or "CH"
        -- result is the client's own verdict, 0 for sent. A refused guild send
        -- comes back as a number here and throws nothing.
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, payload, to)
        Debug(
            "send:",
            to,
            string.sub(payload, 1, 50),
            "queue=" .. (#sendQueueHi + #sendQueue + #sendQueueGuild),
            ok and ("result " .. tostring(result)) or ("FAILED: " .. tostring(result))
        )
        if payload:find("^BLOB|") and sendRoomsTotal > 0 then
            sendRoomsDone = sendRoomsDone + 1
            CH.UpdateSendProgress(sendRoomsDone, sendRoomsTotal)
        end
    end

    if #sendQueueHi == 0 and #sendQueue == 0 and #sendQueueGuild == 0 and sendTicker then
        sendTicker:Cancel()
        sendTicker = nil
        if sendRoomsTotal > 0 then
            CH.HideSendProgress()
            sendRoomsTotal, sendRoomsDone = 0, 0
        end
    end
end

local function StartSending()
    if not sendTicker then
        lastTick = GetTime()
        FlushQueue() -- fire what the bucket allows immediately
        sendTicker = C_Timer.NewTicker(SEND_INTERVAL, FlushQueue)
    end
end

local function Send(payload)
    if not CanSend() then
        return
    end
    -- Layout transfer (BLOBSTART/BLOB) goes in the priority lane, and an echo
    -- with it since it has to ring while the guest is still in the doorway.
    -- Everything else (HELLO, CATALOG, requests) in the normal lane.
    if payload:find("^BLOB") or payload:find("^ECHO") then
        sendQueueHi[#sendQueueHi + 1] = payload
    else
        sendQueue[#sendQueue + 1] = payload
    end
    StartSending()
end

local function StripRealm(fullName)
    return fullName:match("([^%-]+)") or fullName
end

-- ─────────────────────────────────────────────────────────────────────
-- Outgoing
-- ─────────────────────────────────────────────────────────────────────

-- Version handshake. The version never changes mid-session, so this only goes
-- out on join/login, not with every catalog (which fires on every room edit).
-- `isReply` tags a HELLO sent in answer to someone else's, so the receiver knows
-- not to answer it again (otherwise two clients would HELLO back and forth).
function CH.SendHello(isReply)
    Send("HELLO|" .. CH.VERSION .. "|" .. PROTOCOL .. (isReply and "|R" or ""))
end

-- Tell the requester (and the rest of the group) that we won't serve a layout.
-- The consent dialog calls this so the wire format stays here in the core.
function CH.SendDecline(houseGUID)
    Send("LAYOUT_DECLINE|" .. (houseGUID or ""))
end

-- A sound change from the owner as a patch on the map the group already holds,
-- so they hear it right away without pulling the whole layout again (3.10.0).
-- target is "H" for the house, "F<n>" a floor or "R<n>" the nth room. Rooms
-- have no id of their own and n only means the same room while both sides hold
-- the same version, which is what baseTs is for. A client applies the patch
-- only to a copy stamped baseTs and then stamps it with the new time. Anyone
-- else sees a newer catalog two seconds later and pulls the map as before.
-- kind is "ambience" (the value an index into CH.AMBIENCE), "music", "sfx" or
-- "arrival" (a file id each, sfx for rooms only and new in 3.12.0, arrival for
-- the house only and new in 3.13.0), 0 on the wire for none. A client that
-- doesn't know a type skips it and pulls the map.
local PATCH_TYPE = { ambience = "AMB", music = "MUS", sfx = "SFX", arrival = "ARR" }
local PATCH_KIND = { AMB = "ambience", MUS = "music", SFX = "sfx", ARR = "arrival" }
-- where each kind may land: a Room, a Floor, the House
local PATCH_TARGETS = { ambience = "RFH", music = "RFH", sfx = "R", arrival = "H" }
local lastSentNotice = 0

-- quiet skips the chat line, for the later patches of a save that sends a few.
-- plays rides behind a room's sound and its echo behind that (3.13.0). See
-- ReadRoomSounds. The reader splits on runs of |, so an empty field in the
-- middle would pull the echo into the plays seat. A sound always has a count,
-- and without a sound both are left off.
function CH.SendSoundPatch(houseGUID, kind, baseTs, target, value, quiet, plays, echo)
    if not ChamberlainDB.myHouses[houseGUID] or not CanSend() then
        return
    end
    local h = ChamberlainDB.houses[houseGUID]
    Send(
        string.format(
            "%s|%s|%d|%d|%s|%d|%s|%s",
            PATCH_TYPE[kind],
            houseGUID,
            baseTs or 0,
            h.updatedAt,
            target,
            value or 0,
            plays or "",
            plays and echo or ""
        )
    )
    -- The map's ambience menu stays open for comparing and every click in it is
    -- a change that goes out, so the line would stack up in chat.
    local now = GetTime()
    if not quiet and now - lastSentNotice > 10 then
        lastSentNotice = now
        CH.Print(CH.L["SHARE_SOUND_SENT"])
    end
end

-- An echo (3.13.0): somebody walked into a room whose sound on entry carries,
-- and the others in the house hear it as far as the room's echo reaches. The
-- message names the house, the map version and the nth room. Room 0 with no
-- version is the front door. Whoever walks into a house says so once per
-- visit, if their map has an arrival sound or they hold no map of it at all,
-- and those inside play the house's arrival sound.
-- Which sound and how far both come out of the receiver's own copy, so nobody
-- can send a sound or a reach of their choosing. Anyone with the map sends
-- one, the owner walking in too. It goes to the group and to the guild, for
-- the guildmate who dropped by without an invite. Once per person and room in
-- ECHO_COOLDOWN seconds. The sender holds back that long, which only saves
-- messages. The receiver's own count is the one that can't be got round, and
-- it runs a little short. The first copy may have sat in the send queue, and
-- an honest re-entry at 31 seconds would otherwise land at 29 and be lost.
--
-- Echoes travel under a prefix of their own. The game only delivers a prefix
-- to clients that registered it, and everything up to 3.12.0 knows "CH"
-- alone, so a guild full of older versions never sees an echo at all. Those
-- clients have no guard against a message that comes in as secret values
-- (see CH.HandleMessage) and this way they don't need one.
CH.ECHO_PREFIX = "ChamberlainEcho"

-- The receiver's wait is theirs to set (3.14.0). echoPersonWait goes from
-- ECHO_COOLDOWN up. echoRoomWait is a second one per room that counts whoever
-- walks in, for a busy house. Both start when an echo was heard, so one that
-- was out of earshot uses up neither.
local ECHO_COOLDOWN = 30
local ECHO_SLACK = 5
local echoSent = {}
local echoHeard = {} -- by sender and room
local roomHeard = {} -- by room, whoever it was

-- true while key is still inside wait seconds
local function Cooling(times, key, wait)
    return times[key] ~= nil and GetTime() - times[key] < wait
end

function CH.SendEcho(houseGUID, h, zone)
    local group, guild = GroupChannel(), IsInGuild()
    if not (group or guild) or not SendingAllowed() then
        return
    end
    -- no zone is an arrival, room 0 on the wire, see the ECHO handler
    local n = zone and tIndexOf(h.zones, zone) or 0
    local key = houseGUID .. "#" .. n
    if Cooling(echoSent, key, ECHO_COOLDOWN) then
        return
    end
    echoSent[key] = GetTime()
    local payload = string.format("ECHO|%s|%d|%d", houseGUID, zone and h.updatedAt or 0, n)
    if group then
        Send(payload)
    end
    if guild then
        sendQueueGuild[#sendQueueGuild + 1] = payload
        StartSending()
    end
end

-- On the way out of a house, to keep the table small. What we sent stays, or
-- stepping out and back in would get round the wait on the front door.
function CH.ForgetEchoes()
    wipe(echoHeard)
    wipe(roomHeard)
end

-- Live owner presence: house key -> GUID of whoever announced they own it now.
-- Saved name/GUID can't track the owner onto an alt. Runtime only, wiped on roster.
CH.liveOwners = CH.liveOwners or {}

function CH.AnnounceOwnerPresence()
    if not IsInGroup() or not CH.isOwnHouse or not CH.currentHouseGUID then
        return
    end
    local h = ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or not h.zones then
        return
    end
    local usesOwnerHead = false
    for _, z in ipairs(h.zones) do
        if z.useOwnerHead then
            usesOwnerHead = true
            break
        end
    end
    if usesOwnerHead then
        Send("OWNERHEAD|" .. CH.currentHouseGUID .. "|" .. (UnitGUID("player") or ""))
    end
end

-- Ask the owner to re-announce, for when we missed it.
function CH.RequestOwnerPresence(houseGUID)
    if IsInGroup() and houseGUID then
        Send("OWNERHEAD_REQ|" .. houseGUID)
    end
end

-- Advertise the houses you hold. With `only` (a set of guids) just those go out;
-- with nil, the whole catalog does (used on login / roster change).
function CH.BroadcastCatalog(only)
    if not CanSend() then
        return
    end
    for guid, h in pairs(ChamberlainDB.houses) do
        if not only or only[guid] then
            local owner = string.gsub(h.owner or "?", "|", "")
            local ts = h.updatedAt or 0
            local count = h.zones and #h.zones or 0
            Send("CATALOG|" .. guid .. "|" .. owner .. "|" .. ts .. "|" .. count)
        end
    end
end

-- Coalesce rapid changes (a burst of floor-plan nudges, several rooms in a row)
-- into one broadcast ~2s after the last change. Pass the edited houseGUID so only
-- that house is re-advertised. Editing your own rooms shouldn't re-announce every
-- layout you hold (that floods the send queue). With no guid, the whole catalog
-- goes out (login / roster).
local broadcastTimer
local pendingGuids -- set of guids to advertise next
local pendingAll = false -- a caller asked for a full re-advertise
function CH.QueueBroadcast(guid)
    if not IsInGroup() then
        return
    end
    if guid then
        pendingGuids = pendingGuids or {}
        pendingGuids[guid] = true
    else
        pendingAll = true
    end
    if broadcastTimer then
        broadcastTimer:Cancel()
    end
    broadcastTimer = C_Timer.NewTimer(2, function()
        broadcastTimer = nil
        local only = (not pendingAll) and pendingGuids or nil
        pendingGuids, pendingAll = nil, false
        CH.BroadcastCatalog(only)
    end)
end

function CH.RequestLayout(houseGUID)
    -- Called from a Party tab button, so refusals say why instead of doing
    -- nothing. Requesting needs both levers: receiving to take the answer,
    -- sharing because it goes out over the same muted wire.
    if not ChamberlainDB.settings.receiveEnabled then
        CH.Print(CH.L["SHARE_RECV_OFF"])
        return
    end
    if not ChamberlainDB.settings.shareEnabled then
        CH.Print(CH.L["SHARE_OFF"])
        return
    end
    if not CanSend() then
        return
    end
    local bestHolder, bestTs = nil, 0
    for playerName, catalog in pairs(CH.partyCatalogs) do
        local entry = catalog[houseGUID]
        if entry and entry.timestamp > bestTs then
            bestTs = entry.timestamp
            bestHolder = playerName
        end
    end
    if not bestHolder then
        return
    end
    pendingRequests[houseGUID] = true
    Send("LAYOUT_REQ|" .. houseGUID .. "|" .. bestHolder)
end

-- The whole layout (rooms, coords, colors, heads, descriptions) is sent as one
-- compressed blob (the exact bytes CH.ExportLayout produces) split into BLOB
-- chunks. One deflate over everything keeps a house to a handful of messages.
-- Opaque to pre-3 clients, so sharing is gated by protocol version (see
-- CH.ShareAll / the HELLO handshake).
function CH.SendLayout(houseGUID)
    local h = ChamberlainDB.houses[houseGUID]
    if not h or not h.zones or #h.zones == 0 then
        Debug("SendLayout: no data for", houseGUID)
        return
    end
    local serialized = CH.ExportLayout(houseGUID) -- "CHB1:"<base64 blob>
    if not serialized then
        Debug("SendLayout: serialize failed for", houseGUID)
        return
    end
    local blob = string.sub(serialized, 6) -- strip the "CHB1:" tag
    local owner = string.gsub(h.owner or "?", "|", "")
    local ts = h.updatedAt or 0

    -- Keep every message under 250 chars: cap the chunk at 250 minus the
    -- "BLOB|<guid>|<seq>|" header, with slack for the seq digits.
    local maxChunk = 250 - #houseGUID - 14
    if maxChunk < 16 then
        maxChunk = 16
    end
    local total = math.ceil(#blob / maxChunk)

    Debug("SendLayout:", houseGUID, "(" .. #h.zones .. " zones, " .. total .. " chunks) to PARTY")
    sendRoomsTotal = sendRoomsTotal + total -- accumulates across Share My Houses
    CH.ShowSendProgress(sendRoomsTotal)
    Send(string.format("BLOBSTART|%s|%s|%d|%d", houseGUID, owner, ts, total))
    for seq = 1, total do
        local chunk = string.sub(blob, (seq - 1) * maxChunk + 1, seq * maxChunk)
        Send(string.format("BLOB|%s|%d|%s", houseGUID, seq, chunk))
    end
end

-- Push your own houses to the whole party, or the one house `only` names.
-- Layouts you received from others are not re-broadcast here (though they can
-- still be served on request, which is how transitive sharing works).
function CH.ShareAll(only)
    -- Check each blocker separately so the message names the real reason. CanSend
    -- folds them into one boolean, fine for silent auto-broadcasts but not here.
    if not ChamberlainDB.settings.shareEnabled then
        CH.Print(CH.L["SHARE_OFF"])
        return
    end
    if not IsInGroup() then
        CH.Print(CH.L["SHARE_JOIN_GROUP"])
        return
    end
    if C_ChatInfo.InChatMessagingLockdown() then
        CH.Print(CH.L["SHARE_CANT_NOW"])
        return
    end
    -- The blob transfer (protocol 3) is unreadable to older clients, so refuse
    -- the whole share if any group member is on a mismatched version. Sharing
    -- is a broadcast, so it's all-or-nothing. They're already warned by HELLO.
    local outdated = {}
    for name in pairs(incompatible) do
        outdated[#outdated + 1] = name
    end
    if #outdated > 0 then
        table.sort(outdated)
        CH.Print(CH.L["SHARE_CANT_OUTDATED_X"], table.concat(outdated, ", "))
        return
    end
    local names = {}
    local sharingFloors = false
    for guid, _ in pairs(ChamberlainDB.myHouses) do
        local h = ChamberlainDB.houses[guid]
        if (not only or guid == only) and h and h.zones and #h.zones > 0 then
            CH.SendLayout(guid)
            names[#names + 1] = string.format(CH.L["SHARE_X_HOUSE"], h.owner or CH.L["SHARE_HOME"])
            if (h.floorCount or 1) > 1 then
                sharingFloors = true
            end
        end
    end
    if #names == 0 then
        CH.Print(CH.L["SHARE_NO_ROOMS"])
        return
    end
    CH.Print(CH.L["SHARE_SHARED_X"], table.concat(names, CH.L["SHARE_AND"]))

    -- Floors share fine across versions (appended blob fields), but a pre-2.4.0
    -- peer can't display them, so quietly let you know who'll see a flat layout.
    if sharingFloors then
        local flat = {}
        for name, ver in pairs(peerVersions) do
            if VersionOlder(ver, FLOOR_MIN_VERSION) then
                flat[#flat + 1] = name
            end
        end
        if #flat > 0 then
            table.sort(flat)
            CH.Print(
                CH.L["SHARE_FLOOR_NOTE_X"],
                table.concat(flat, ", "),
                #flat == 1 and CH.L["SHARE_IS"] or CH.L["SHARE_ARE"],
                FLOOR_MIN_VERSION
            )
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Incoming
-- ─────────────────────────────────────────────────────────────────────

function CH.ApplyLayout(houseGUID, data, senderName)
    local existing = ChamberlainDB.houses[houseGUID]
    if existing then
        existing.zones = data.zones
        existing.updatedAt = data.timestamp
        -- only an import reaches a house of your own, and the name in a string
        -- is whatever its maker typed
        if not ChamberlainDB.myHouses[houseGUID] then
            existing.owner = data.owner or existing.owner
        end
        existing.ownerGUID = data.ownerGUID or existing.ownerGUID
        existing.floorCount = data.floorCount or existing.floorCount or 1
        existing.ambience = data.ambience
        existing.music = data.music
        existing.arrival = data.arrival
    else
        ChamberlainDB.houses[houseGUID] = {
            owner = data.owner,
            ownerGUID = data.ownerGUID,
            updatedAt = data.timestamp,
            floorCount = data.floorCount or 1,
            ambience = data.ambience,
            music = data.music,
            arrival = data.arrival,
            zones = data.zones,
        }
    end
    Debug("ApplyLayout: saved", houseGUID, "(" .. #data.zones .. " zones) from", senderName)
    local houseName = (data.owner and string.format(CH.L["SHARE_X_HOUSE"], data.owner)) or CH.L["SHARE_A_HOUSE"]
    CH.Print(CH.L["SHARE_RECEIVED_X"], #data.zones, houseName, senderName)
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    if CH.RefreshPartyTab then
        CH.RefreshPartyTab()
    end
    if CH.RebuildFloorPlan then
        CH.RebuildFloorPlan()
    end
    -- Standing in the sharer's house, the HUD's Floor Plan button only shows once
    -- we hold zones for it. Re-evaluate now so it appears without a /reload.
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end
end

function CH.ReceiveLayout(houseGUID, data, senderName)
    -- Two accounts on one battlenet own the same houses, so an alt can end up
    -- requesing a house it owns. The owner's local copy stays authoritative.
    if ChamberlainDB.myHouses[houseGUID] then
        pendingRequests[houseGUID] = nil
        CH.Print(CH.L["SHARE_IGNORED_OWN_X"], senderName)
        return
    end
    local existing = ChamberlainDB.houses[houseGUID]
    local solicited = pendingRequests[houseGUID]
    pendingRequests[houseGUID] = nil
    Debug(
        "ReceiveLayout:",
        houseGUID,
        "from",
        senderName,
        "solicited=" .. tostring(solicited or false),
        "existing=" .. tostring(existing ~= nil)
    )

    -- You explicitly asked for this layout, so apply it without prompting.
    if solicited then
        CH.ApplyLayout(houseGUID, data, senderName)
        return
    end

    -- Unsolicited push (someone's Share My Houses, or the group-wide copy sent
    -- when a request is served). A blocked sender is dropped without a peep.
    if ChamberlainDB.blocks.players[senderName] then
        Debug("ReceiveLayout: dropped, sender blocked:", senderName)
        return
    end

    -- Don't nag about a copy that isn't newer than what we already hold (the
    -- BLOBSTART guard usually catches this earlier, this is the backstop).
    if existing and (data.timestamp or 0) <= (existing.updatedAt or 0) then
        Debug("ReceiveLayout: kept local copy (incoming is not newer)")
        return
    end

    -- Consent is required for everything else. If you've trusted this sender,
    -- take it silently, otherwise ask whether to accept it.
    if ChamberlainDB.trusted[senderName] then
        CH.ApplyLayout(houseGUID, data, senderName)
    elseif CH.onLayoutReceived then
        CH.onLayoutReceived(houseGUID, data, senderName)
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Export / Import Strings
-- ─────────────────────────────────────────────────────────────────────

-- The string is the zone table serialized (CBOR), compressed (deflate) and
-- base64 encoded, behind a "CHB1:" tag. C_EncodingUtil is built into the 12.x
-- client, so no library is needed, and the blob handles any charaters in room
-- names. The house GUID travels inside it, so an import lands under the right
-- house and its banners fire when you visit.

local IMPORT_MAX_BYTES = 200000 -- reject absurdly large blobs before deserializing

-- True when a sound value off the wire is one we can play, an ambience index
-- we have or a music id in the list. A newer version may know more than we do
-- and those stay quiet here.
local KNOWN = {
    ambience = function(v)
        return CH.AMBIENCE[v] ~= nil
    end,
    music = function(v)
        return CH.MusicPath(v) ~= nil
    end,
    -- any game file or one of ours, the same as a room's sound on entry
    arrival = CH.IsSoundID,
}

-- The sound on entry came in this version. Before it a room's sound sat in the
-- music field, mu, with its play count in mn behind it.
local SFX_MIN_VERSION = "3.12.0"

-- A map's timestamp off the wire: whole seconds that date() and a %d both
-- take. date() hands back nil for a year it can't place, a negative or a 1e20
-- for instance, and the import summary would throw on it. A fraction would be
-- cut by %d in an echo and never match the receiver's copy again.
local function IsTimestamp(n)
    return type(n) == "number" and n >= 0 and n < 2 ^ 31 and n % 1 == 0
end

local function ReadPlays(n)
    return type(n) == "number" and n >= 0 and n <= 5 and n % 1 == 0 and n or nil
end

-- A room's picks off the wire as music, sfx, sfxPlays. Music is a listed track
-- or Silence, so a file that isn't in the list never gets the music slot. The
-- sound may be any game file by id and there is no list to check it against,
-- only that it is a whole positive number, or one of the few the addon ships.
-- Its plays is 1 to 5 or 0 for a loop.
-- A music pick that has a count or isn't listed is a sound the old way, from
-- an older client or from the copy a newer one sends for them (see
-- CH.ExportLayout), and sx wins over it.
local function ReadRoomSounds(mu, mn, sx, sn)
    local music, sfx, sfxPlays
    if CH.IsSoundID(sx) then
        sfx, sfxPlays = sx, ReadPlays(sn) or 0
    end
    if mu == CH.SILENCE or (KNOWN.music(mu) and not ReadPlays(mn)) then
        music = mu
    elseif not sfx and CH.IsFileID(mu) then
        sfx, sfxPlays = mu, ReadPlays(mn) or 0
    end
    return music, sfx, sfxPlays
end

-- The chat line a visitor gets when the owner's sound patch lands, naming the
-- track since the game won't say what is playing. An owner comparing sounds
-- sends a patch per click, so the line waits for two quiet seconds and only
-- the last pick for each place gets said.
local soundNotes = {}
local noteTimer

local function FlushSoundNotes()
    for _, note in pairs(soundNotes) do
        CH.Print("%s", note)
    end
    wipe(soundNotes)
end

local function NoteSoundChange(kind, target, sender, place, value)
    local name = CH.L["RD_AMBIENCE_NONE"]
    if value then
        name = kind == "ambience" and CH.L[CH.AMBIENCE[value].key] or CH.SoundName(value)
    end
    soundNotes[kind .. target] = string.format(CH.L["SHARE_SOUND_GOT_" .. kind:upper()], sender, place, name)
    if noteTimer then
        noteTimer:Cancel()
    end
    noteTimer = C_Timer.NewTimer(2, FlushSoundNotes)
end

-- The house and floor sounds of one kind off a decoded payload, in the
-- h.ambience shape, or nil when it carries none.
local function ReadHouseSound(kind, house, floors)
    local known = KNOWN[kind]
    local set = { house = known(house) and house or nil }
    if type(floors) == "table" then
        for n, v in ipairs(floors) do
            if known(v) then
                set.floors = set.floors or {}
                set.floors[n] = v
            end
        end
    end
    return next(set) and set or nil
end

-- Decode a base64 blob (the bytes inside a "CHB1:" string, or a reassembled BLOB
-- transfer) into a validated { guid, owner, timestamp, zones } table, or nil.
-- Shared by string import and the over-the-wire blob receive.
local function DeserializeLayout(b64)
    local ok, payload = pcall(function()
        local raw = C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(b64))
        if not raw or #raw > IMPORT_MAX_BYTES then
            return nil
        end
        return C_EncodingUtil.DeserializeCBOR(raw)
    end)
    if not ok or type(payload) ~= "table" or type(payload.zones) ~= "table" then
        return nil
    end

    local zones = {}
    for _, z in ipairs(payload.zones) do
        if
            type(z) == "table"
            and type(z.n) == "string"
            and type(z.m) == "number"
            and type(z.x1) == "number"
            and type(z.x2) == "number"
            and type(z.y1) == "number"
            and type(z.y2) == "number"
            and #zones < 100
        then
            local color
            if type(z.c) == "table" and type(z.c[1]) == "number" then
                color = { z.c[1], z.c[2], z.c[3] }
            end
            local music, sfx, sfxPlays = ReadRoomSounds(z.mu, z.mn, z.sx, z.sn)
            zones[#zones + 1] = {
                name = string.sub(z.n, 1, 48),
                mapID = z.m,
                minX = z.x1,
                maxX = z.x2,
                minY = z.y1,
                maxY = z.y2,
                color = color,
                headID = type(z.hi) == "number" and z.hi or nil,
                headDisplay = type(z.hd) == "number" and z.hd or nil,
                speaker = type(z.sp) == "string" and string.sub(z.sp, 1, 40) or nil,
                useOwnerHead = z.oh == true or nil,
                rpText = type(z.t) == "string" and string.sub(z.t, 1, 500) or nil,
                secret = z.se == true or nil,
                noBanner = z.nb == true or nil,
                ambience = KNOWN.ambience(z.am) and z.am or nil,
                music = music,
                sfx = sfx,
                sfxPlays = sfxPlays,
                echo = sfx and CH.IsEcho(z.ec) and z.ec or nil,
                -- Room shape (3.0.0): only "circle" so far. Anything else, or absent
                -- from older blobs, is a rectangle. Geometry still rides in x1..y2.
                shape = z.sh == "circle" and "circle" or nil,
                -- Multi-floor (2.4.0): defaults to floor 1 so pre-floors blobs
                -- (which omit these) land every room on the ground floor.
                floor = type(z.fl) == "number" and z.fl or 1,
                setFloor = type(z.sf) == "number" and z.sf or nil,
                floorDelta = type(z.fd) == "number" and z.fd or nil,
                fromFloor = type(z.ff) == "number" and z.ff or nil,
            }
        end
    end
    if #zones == 0 then
        return nil
    end

    return {
        guid = type(payload.guid) == "string" and payload.guid or nil,
        owner = type(payload.owner) == "string" and payload.owner or nil,
        ownerGUID = type(payload.oguid) == "string" and payload.oguid or nil,
        timestamp = IsTimestamp(payload.ts) and payload.ts or GetServerTime(),
        floorCount = type(payload.fc) == "number" and payload.fc or 1,
        ambience = ReadHouseSound("ambience", payload.ha, payload.fa),
        music = ReadHouseSound("music", payload.hm, payload.fm),
        arrival = ReadHouseSound("arrival", payload.ar),
        zones = zones,
    }
end

function CH.ExportLayout(houseGUID)
    local h = ChamberlainDB.houses[houseGUID]
    if not h or not h.zones or #h.zones == 0 then
        return nil
    end
    local payload = {
        v = 1,
        guid = houseGUID,
        owner = h.owner,
        oguid = h.ownerGUID,
        ts = h.updatedAt or 0,
        fc = h.floorCount or 1,
        zones = {},
    }
    -- House and floor sounds: ha/fa ambience (3.9.0), hm/fm music (3.10.0), ar
    -- the arrival sound (3.13.0), which has no floors.
    -- The floor one is a value per floor with 0 for none, a plain array so
    -- nothing rides on how CBOR treats sparse keys.
    for kind, keys in pairs({ ambience = { "ha", "fa" }, music = { "hm", "fm" }, arrival = { "ar" } }) do
        local set = h[kind]
        if set then
            payload[keys[1]] = set.house
            if set.floors then
                local floors = {}
                for n = 1, payload.fc do
                    floors[n] = set.floors[n] or 0
                end
                payload[keys[2]] = floors
            end
        end
    end
    for _, z in ipairs(h.zones) do
        payload.zones[#payload.zones + 1] = {
            n = z.name,
            m = z.mapID,
            x1 = z.minX,
            x2 = z.maxX,
            y1 = z.minY,
            y2 = z.maxY,
            c = z.color,
            sh = z.shape, -- room shape "circle", or nil for a rectangle (3.0.0)
            t = z.rpText, -- room description
            hi = z.headID, -- talking-head index
            hd = z.headDisplay, -- custom head display ID (overrides hi)
            sp = z.speaker, -- custom speaker name (overrides head name)
            oh = z.useOwnerHead, -- show the house owner's character when present
            se = z.secret, -- hidden from visitors' floor plan and room list, banner still fires
            nb = z.noBanner, -- no banner on entry (3.8.0, older clients still show one)
            am = z.ambience, -- index into CH.AMBIENCE (3.8.0)
            -- music file id (3.10.0). Clients before 3.12.0 read a sound from here
            -- with its count in mn, so a room without music sends its sound this
            -- way too and they keep hearing it.
            mu = z.music or z.sfx,
            mn = not z.music and z.sfxPlays or nil,
            sx = z.sfx, -- sound on entry, any game file id (3.12.0)
            sn = z.sfxPlays, -- times it plays on walking in, 0 loops
            ec = z.echo, -- yards the others hear it from, CH.WHOLE_HOUSE for all (3.13.0)
            fl = z.floor, -- which floor the room is on (2.4.0; appended, old clients ignore)
            sf = z.setFloor, -- absolute stair anchor: stepping on sets this floor
            fd = z.floorDelta, -- relative stair anchor: +1/-1 from current floor
            ff = z.fromFloor, -- stair anchor only fires from this floor (the linked floor)
        }
    end
    local ok, blob = pcall(function()
        return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(payload)))
    end)
    if not ok or not blob then
        return nil
    end
    return "CHB1:" .. blob
end

function CH.ImportLayout(text)
    text = string.match(text or "", "^%s*(.-)%s*$")
    local b64 = string.match(text or "", "^CHB1:(.+)$")
    if not b64 then
        CH.Print(CH.L["SHARE_BAD_STRING"])
        return
    end

    local data = DeserializeLayout(b64)
    if not data then
        CH.Print(CH.L["SHARE_CANT_READ_STRING"])
        return
    end

    local guid = data.guid or CH.currentHouseGUID
    if not guid then
        CH.Print(CH.L["SHARE_IMPORT_NO_HOUSE"])
        return
    end
    -- Always through the dialog, which shows what the string holds before
    -- anything is saved.
    CH.ShowAcceptDialog(guid, data, CH.L["SHARE_IMPORTED_STRING"], true)
end

local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

function CH.HandleMessage(prefix, payload, channel, fullSender)
    -- On a boss, in a key or in a PvP match the game may hand these over as
    -- secret values, and comparing or splitting one is a Lua error. Echoes go
    -- to the whole guild, so they reach people there. Nothing of a house
    -- matters to them in a fight and the message is let go. Blizzard's event
    -- docs mark the chat events that turn secret in a lockdown and
    -- CHAT_MSG_ADDON isn't one of them, so this may never fire. Nobody has
    -- watched it in a real fight yet.
    if issecretvalue(prefix) or issecretvalue(payload) or issecretvalue(channel) or issecretvalue(fullSender) then
        return
    end
    if prefix ~= "CH" and prefix ~= CH.ECHO_PREFIX then
        return
    end
    -- Chamberlain only sends to the group, and echoes to the guild as well.
    -- Whatever comes another way was made by hand: a whispered
    -- ECHO|<house>|0|0 would ring the door of anybody whose house key you know.
    if not GROUP_CHANNELS[channel] and not (channel == "GUILD" and prefix == CH.ECHO_PREFIX) then
        return
    end
    local sender = StripRealm(fullSender)
    local myName = UnitName("player")
    if sender == myName then
        return
    end -- party messages echo back to us; ignore
    Debug("recv from", sender, ":", string.sub(payload, 1, 60))

    local parts = {}
    for part in payload:gmatch("[^|]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return
    end
    local msgType = parts[1]
    -- the echo prefix carries echoes and "CH" everything else, so nothing but
    -- an echo gets in by way of the guild
    if (prefix == CH.ECHO_PREFIX) ~= (msgType == "ECHO") then
        return
    end

    if msgType == "HELLO" then
        local version = string.sub(parts[2] or "?", 1, 16)
        local protocol = tonumber(parts[3]) or 0
        local isReply = parts[4] == "R" -- a HELLO answering one of ours
        peerVersions[sender] = version
        if protocol == PROTOCOL then
            incompatible[sender] = nil
            warnedMismatch[sender] = nil -- they updated; allow a fresh warning if it ever changes again
        else
            incompatible[sender] = true
            if not warnedMismatch[sender] then
                warnedMismatch[sender] = true
                local who = protocol < PROTOCOL and string.format(CH.L["SHARE_THEY_ARE_X"], sender)
                    or CH.L["SHARE_YOU_ARE"]
                CH.Print(CH.L["SHARE_MISMATCH_X"], sender, version, CH.VERSION, who)
            end
        end
        -- The sender just (re)started, so it lost any catalog and version info we
        -- sent before. Re-advertise our houses either way. If this was its own
        -- announcement (not a reply to ours), greet it back once so it learns our
        -- version too. A reply never gets answered, so two clients can't volley.
        if not isReply then
            CH.SendHello(true)
        end
        CH.QueueBroadcast()
        return
    end

    -- Everything past this point is sharing traffic. Refuse it from clients
    -- whose protocol does not match ours.
    if incompatible[sender] then
        Debug("recv dropped (incompatible protocol):", sender)
        return
    end

    -- The two sharing levers. Sharing off ignores requests for our houses
    -- outright, so nobody can spam the consent popup. Receiving off drops other
    -- people's catalogs and layout pushes before any UI fires.
    if msgType == "LAYOUT_REQ" and not ChamberlainDB.settings.shareEnabled then
        Debug("recv dropped (sharing off): LAYOUT_REQ from", sender)
        return
    end
    if
        not ChamberlainDB.settings.receiveEnabled
        and (msgType == "CATALOG" or msgType == "BLOBSTART" or msgType == "BLOB" or PATCH_KIND[msgType])
    then
        Debug("recv dropped (receiving off):", msgType, "from", sender)
        return
    end

    if msgType == "CATALOG" then
        local guid = parts[2]
        local owner = parts[3]
        local ts = tonumber(parts[4]) or 0
        local count = tonumber(parts[5]) or 0
        if not guid then
            return
        end
        CH.partyCatalogs[sender] = CH.partyCatalogs[sender] or {}
        CH.partyCatalogs[sender][guid] = { owner = owner, timestamp = ts, zoneCount = count }
        if CH.RefreshPartyTab then
            CH.RefreshPartyTab()
        end
    elseif msgType == "LAYOUT_REQ" then
        local guid = parts[2]
        local target = parts[3]
        if not guid then
            return
        end
        if target and target ~= myName then
            return
        end
        local blocks = ChamberlainDB.blocks
        if blocks.players[sender] then
            return
        end
        if blocks.houses[guid] then
            return
        end
        local h = ChamberlainDB.houses[guid]
        if not h then
            Send("LAYOUT_DECLINE|" .. guid)
            return
        end
        if CH.onConsentRequired then
            CH.onConsentRequired(sender, guid)
        end
    elseif msgType == "BLOBSTART" then
        local guid = parts[2]
        local owner = parts[3]
        local ts = tonumber(parts[4]) or 0
        local total = tonumber(parts[5]) or 0
        if not guid or #guid > 64 then
            Debug("BLOBSTART dropped: bad guid")
            return
        end
        if total < 1 or total > 400 then
            Debug("BLOBSTART dropped: bad chunk count", total)
            return
        end
        -- Share My Houses re-sends every house, including ones that haven't
        -- changed. If we didn't ask for this and already hold a copy at this
        -- timestamp or newer, skip the whole transfer here. Owner edits bump the
        -- timestamp, so genuine updates still come through. (A solicited request
        -- is always accepted.)
        if not pendingRequests[guid] then
            local have = ChamberlainDB.houses[guid]
            if have and (have.updatedAt or 0) >= ts then
                Debug("BLOBSTART skipped: already hold", guid, "at ts >=", ts)
                return
            end
        end
        local ownerSafe = string.sub(owner or "?", 1, 64)
        local transfer = {
            sender = sender,
            owner = ownerSafe,
            ts = ts,
            total = total,
            chunks = {},
            have = 0,
        }
        CH.pendingLayouts[guid] = transfer
        Debug("BLOBSTART from", sender, "expecting", total, "chunks")
        CH.ShowReceiveProgress(ownerSafe, total)
        -- If the transfer hasn't finished after 3 minutes, give up and report what
        -- was missing, so a dead transfer (sender left, real drop) can't hang in
        -- memory. The identity check skips this if it finished or was superseded.
        C_Timer.NewTimer(180, function()
            if CH.pendingLayouts[guid] ~= transfer then
                return
            end
            CH.pendingLayouts[guid] = nil
            CH.HideReceiveProgress()
            local missing = {}
            for s = 1, transfer.total do
                if not transfer.chunks[s] then
                    missing[#missing + 1] = s
                    if #missing >= 12 then
                        break
                    end
                end
            end
            CH.Print(
                CH.L["SHARE_TRANSFER_INCOMPLETE_X"],
                sender,
                transfer.have,
                transfer.total,
                table.concat(missing, ","),
                #missing >= 12 and "..." or ""
            )
        end)
    elseif msgType == "BLOB" then
        -- One chunk of the layout blob. Collect until all arrive, then decode
        -- the whole thing and hand it to the consent/accept flow.
        local guid = parts[2]
        local seq = tonumber(parts[3])
        local chunk = parts[4]
        if not guid or not seq or not chunk then
            return
        end
        local pending = CH.pendingLayouts[guid]
        if not pending or pending.sender ~= sender then
            Debug("BLOB dropped: no pending transfer (BLOBSTART was missed?)")
            return
        end
        if seq < 1 or seq > pending.total or pending.chunks[seq] then
            return
        end
        pending.chunks[seq] = chunk
        pending.have = pending.have + 1
        CH.UpdateReceiveProgress(pending.have, pending.total)
        if pending.have < pending.total then
            return
        end

        local blob = table.concat(pending.chunks, "", 1, pending.total)
        CH.pendingLayouts[guid] = nil
        CH.HideReceiveProgress()
        local data = DeserializeLayout(blob)
        if data then
            Debug("BLOB complete:", guid, "(" .. #data.zones .. " zones) from", sender)
            CH.ReceiveLayout(guid, data, sender)
        else
            CH.Print(CH.L["SHARE_DECODE_FAILED_X"], sender)
        end
    elseif PATCH_KIND[msgType] then
        -- See CH.SendSoundPatch. Dropped unless we hold this exact version of
        -- the map, and never applied to a house of our own.
        local kind = PATCH_KIND[msgType]
        local guid = parts[2]
        local baseTs, newTs = tonumber(parts[3]), tonumber(parts[4])
        local where, n = (parts[5] or ""):match("^(%a)(%d*)$")
        local value = tonumber(parts[6])
        local h = guid and ChamberlainDB.houses[guid]
        if not h or not IsTimestamp(newTs) or not value or ChamberlainDB.myHouses[guid] then
            return
        end
        -- The arrival sound is the one exception to the exact version. It hangs
        -- on the house and not on the nth room, so a copy that is behind takes
        -- it as well, as long as the patch is newer than the copy. Such a copy
        -- keeps its old stamp and still pulls the map for the rest.
        local current = h.updatedAt == baseTs
        if not current and not (kind == "arrival" and newTs > (h.updatedAt or 0)) then
            return
        end
        if ChamberlainDB.blocks.players[sender] then
            return
        end
        if not where or not PATCH_TARGETS[kind]:find(where, 1, true) then
            return
        end
        n = where ~= "H" and tonumber(n) or nil
        local stored, place
        if where == "R" then
            local zone = h.zones[n]
            if not zone then
                return
            end
            local plays = tonumber(parts[7])
            if kind == "ambience" then
                zone.ambience = KNOWN.ambience(value) and value or nil
            elseif kind == "sfx" then
                local echo = tonumber(parts[8])
                zone.sfx = CH.IsSoundID(value) and value or nil
                zone.sfxPlays = zone.sfx and (ReadPlays(plays) or 0)
                zone.echo = CH.IsEcho(echo) and echo or nil
            else
                local music, sfx, sfxPlays = ReadRoomSounds(value, plays)
                zone.music = music
                -- An owner from before the split has one field for both, so
                -- their pick takes the place of the room's sound as well.
                if sfx or VersionOlder(peerVersions[sender], SFX_MIN_VERSION) then
                    zone.sfx, zone.sfxPlays = sfx, sfxPlays
                end
                kind = sfx and "sfx" or kind
            end
            if not zone.sfx then
                zone.echo = nil
            end
            stored = zone[kind]
            -- a secret room's name is not for the visitor's chat either
            place = zone.secret and CH.L["SHARE_SOUND_A_ROOM"] or zone.name
        elseif where == "H" or n then
            stored = KNOWN[kind](value) and value or nil
            CH.StoreHouseSound(h, kind, n, stored)
            place = n and string.format(CH.L["FP_AMBIENCE_FLOOR_X"], n) or CH.L["FP_AMBIENCE_HOUSE"]
        else
            return
        end
        if current then
            h.updatedAt = newTs
        end
        Debug(msgType, "applied:", guid, parts[5], value, "from", sender)
        if guid == CH.currentHouseGUID then
            -- the mute button shows only in a house that has a sound somewhere
            CH.RefreshHUDMode()
            NoteSoundChange(kind, parts[5], sender, place, stored)
        end
    elseif msgType == "ECHO" then
        -- The whole guild gets these, so the ones for another house go first.
        local guid, n = parts[2], tonumber(parts[4])
        if guid ~= CH.currentHouseGUID or not n or not ChamberlainDB.settings.ambienceEnabled then
            return
        end
        local h = ChamberlainDB.houses[guid]
        if not h or ChamberlainDB.blocks.players[sender] then
            return
        end
        -- Room 0 is the front door, sent when somebody arrives. That one takes
        -- no map version since the visitor may not hold the map at all.
        local zone = n > 0 and h.updatedAt == tonumber(parts[3]) and h.zones[n]
        local file = n == 0 and h.arrival and h.arrival.house or zone and zone.echo and zone.sfx
        if not file then
            return
        end
        -- Room echoes go by one mute. The front door has two, by whether a
        -- group member walked in or a guildmate outside the group. A groupmate
        -- in the guild sends on both channels, and peerVersions knows every
        -- group member who runs the addon, so their guild copy counts as the
        -- group's and not as a way round that mute. This sits ahead of the
        -- cooldown so a copy that is muted doesn't use it up.
        local fromGuild = channel == "GUILD" and not peerVersions[sender]
        local mute = n > 0 and "echoes" or fromGuild and "arrivalGuild" or "arrivalGroup"
        if not ChamberlainDB.settings[mute] then
            return
        end
        -- A groupmate in the guild sends it twice and the second copy stops at
        -- the first of these. The slack comes off the player's own number too,
        -- since it is there for a copy that sat in the sender's queue.
        local s = ChamberlainDB.settings
        if Cooling(echoHeard, sender .. n, s.echoPersonWait - ECHO_SLACK) or Cooling(roomHeard, n, s.echoRoomWait) then
            return
        end
        local x, y, mapID = CH.GetWorldPos()
        if not zone or zone.echo == CH.WHOLE_HOUSE or (x and CH.DistanceToZone(zone, x, y, mapID) <= zone.echo) then
            echoHeard[sender .. n], roomHeard[n] = GetTime(), GetTime()
            Debug("ECHO heard:", zone and zone.name or "arrival", "from", sender)
            if zone then
                CH.PlayEcho(file, zone.sfxPlays)
            else
                CH.PlayArrival(file, sender)
            end
        end
    elseif msgType == "LAYOUT_DECLINE" then
        -- The holder said no (or no longer has it). Declines are broadcast, so
        -- only the person who actually asked has a matching pending request;
        -- everyone else quietly ignores it. Clearing the flag also stops a
        -- later unsolicited copy from being mistaken for the one we asked for.
        local guid = parts[2]
        if not guid or not pendingRequests[guid] then
            return
        end
        pendingRequests[guid] = nil
        local h = ChamberlainDB.houses[guid]
        local houseName = (h and h.owner) and string.format(CH.L["SHARE_X_HOUSE"], h.owner) or CH.L["SHARE_THAT_LAYOUT"]
        CH.Print(CH.L["SHARE_DIDNT_SHARE_X"], sender, houseName)
    elseif msgType == "OWNERHEAD" then
        local guid = parts[2]
        local ownerGUID = parts[3]
        if guid and ownerGUID and ownerGUID ~= "" then
            CH.liveOwners[guid] = { guid = ownerGUID, name = sender }
            if CH.OnLiveOwnerUpdate then
                CH.OnLiveOwnerUpdate(guid)
            end
        end
    elseif msgType == "OWNERHEAD_REQ" then
        local guid = parts[2]
        if guid and CH.isOwnHouse and CH.currentHouseGUID == guid then
            CH.AnnounceOwnerPresence() -- answer if this is our house
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────────────────────────────

local shareFrame = CreateFrame("Frame")
shareFrame:RegisterEvent("CHAT_MSG_ADDON")
shareFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
shareFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
shareFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_ADDON" then
        CH.HandleMessage(arg1, arg2, arg3, arg4)
    elseif event == "GROUP_ROSTER_UPDATE" then
        wipe(CH.partyCatalogs)
        if CH.RefreshPartyTab then
            CH.RefreshPartyTab()
        end
        wipe(incompatible)
        wipe(peerVersions)
        wipe(CH.liveOwners) -- cleared here, present owners re-announce below
        C_Timer.NewTimer(1, function()
            CH.SendHello()
            CH.BroadcastCatalog()
            CH.AnnounceOwnerPresence()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Announce our version and catalog on login / after each loading screen,
        -- so party members already grouped before we arrived learn our houses.
        CH.SendHello()
        CH.QueueBroadcast()
    end
end)
