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

local function CanSend()
    if not GroupChannel() then
        Debug("send skipped: not in group")
        return false
    end
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
local sendTicker
local tokens = TOKENS_MAX
local lastTick

-- Send-side progress, counted in BLOB chunks being sent out.
local sendRoomsTotal, sendRoomsDone = 0, 0

local function FlushQueue()
    local now = GetTime()
    tokens = math.min(TOKENS_MAX, tokens + (now - (lastTick or now)) * TOKEN_RATE)
    lastTick = now

    -- Pick the channel at flush time so it reflects the current group category
    -- (home party/raid vs. instance group). If the group is gone, drop the
    -- queued traffic rather than firing PARTY/RAID into the void.
    local channel = GroupChannel()
    if not channel then
        sendQueue, sendQueueHi = {}, {}
        if sendTicker then
            sendTicker:Cancel()
            sendTicker = nil
        end
        if sendRoomsTotal > 0 then
            CH.HideSendProgress()
            sendRoomsTotal, sendRoomsDone = 0, 0
        end
        return
    end
    -- Drain the layout transfer first so a user-initiated share isn't stuck
    -- behind routine catalog/HELLO chatter (which would freeze its progress bar).
    while tokens >= 1 and (#sendQueueHi > 0 or #sendQueue > 0) do
        tokens = tokens - 1
        local payload = (#sendQueueHi > 0) and table.remove(sendQueueHi, 1) or table.remove(sendQueue, 1)
        local ok, err = pcall(C_ChatInfo.SendAddonMessage, "CH", payload, channel)
        Debug(
            "send:",
            string.sub(payload, 1, 50),
            "queue=" .. (#sendQueueHi + #sendQueue),
            ok and "ok" or ("FAILED: " .. tostring(err))
        )
        if payload:find("^BLOB|") and sendRoomsTotal > 0 then
            sendRoomsDone = sendRoomsDone + 1
            CH.UpdateSendProgress(sendRoomsDone, sendRoomsTotal)
        end
    end

    if #sendQueueHi == 0 and #sendQueue == 0 and sendTicker then
        sendTicker:Cancel()
        sendTicker = nil
        if sendRoomsTotal > 0 then
            CH.HideSendProgress()
            sendRoomsTotal, sendRoomsDone = 0, 0
        end
    end
end

local function Send(payload)
    if not CanSend() then
        return
    end
    -- Layout transfer (BLOBSTART/BLOB) goes in the priority lane. Everything
    -- else (HELLO, CATALOG, requests) in the normal lane.
    if payload:find("^BLOB") then
        sendQueueHi[#sendQueueHi + 1] = payload
    else
        sendQueue[#sendQueue + 1] = payload
    end
    if not sendTicker then
        lastTick = GetTime()
        FlushQueue() -- fire what the bucket allows immediately
        sendTicker = C_Timer.NewTicker(SEND_INTERVAL, FlushQueue)
    end
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

-- Push your own houses to the whole party. Layouts you received from others
-- are not re-broadcast here (though they can still be served on request, which
-- is how transitive sharing works).
function CH.ShareAll()
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
        if h and h.zones and #h.zones > 0 then
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
        existing.owner = data.owner or existing.owner
        existing.ownerGUID = data.ownerGUID or existing.ownerGUID
        existing.floorCount = data.floorCount or existing.floorCount or 1
    else
        ChamberlainDB.houses[houseGUID] = {
            owner = data.owner,
            ownerGUID = data.ownerGUID,
            updatedAt = data.timestamp,
            floorCount = data.floorCount or 1,
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
    else
        CH.ShowAcceptDialog(houseGUID, data, senderName)
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
        timestamp = type(payload.ts) == "number" and payload.ts or GetServerTime(),
        floorCount = type(payload.fc) == "number" and payload.fc or 1,
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
    for _, z in ipairs(h.zones) do
        payload.zones[#payload.zones + 1] = {
            n = z.name,
            m = z.mapID,
            x1 = z.minX,
            x2 = z.maxX,
            y1 = z.minY,
            y2 = z.maxY,
            c = z.color,
            t = z.rpText, -- room description
            hi = z.headID, -- talking-head index
            hd = z.headDisplay, -- custom head display ID (overrides hi)
            sp = z.speaker, -- custom speaker name (overrides head name)
            oh = z.useOwnerHead, -- show the house owner's character when present
            se = z.secret, -- hidden from visitors' floor plan and room list, banner still fires
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
    local existing = ChamberlainDB.houses[guid]
    if existing and existing.zones and #existing.zones > 0 then
        CH.ShowAcceptDialog(guid, data, CH.L["SHARE_IMPORTED_STRING"], true)
    else
        CH.ApplyLayout(guid, data, CH.L["SHARE_SENDER_IMPORT"])
    end
end

function CH.HandleMessage(prefix, payload, _, fullSender)
    if prefix ~= "CH" then
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
        CH.ShowConsentDialog(sender, guid)
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
