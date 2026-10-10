local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Pumpkin hunt: pumpkins the owner hides for visitors to find
-- ─────────────────────────────────────────────────────────────────────
-- The owner stands where a pumpkin should hide and the hunt panel keeps the
-- spot. A visitor who walks within reach of one gets the pop-up and picks it
-- up into the bag (UI/Hunt.lua). The spots ride the map as pk, the reach as
-- pr. What a visitor found stays on their side, kept by the spot, so a
-- pumpkin the owner moves is a new one to find.
--
-- Only the owner keeps the spots in the open (h.pumpkins). pk is them
-- scrambled, and a visitor keeps that blob (h.pumpkinBlob) and opens it into
-- a table of this file's, so the spots aren't one /dump of the saved
-- variables away. It's light, like the locks, anybody who reads this file
-- can undo it.
--
-- A Pumpkin Patch lock (UI/Lock/Patch.lua) is sealed with a code made from
-- the spots, so the pumpkins are the key and the lock goes through
-- CH.TryLockCode like any other. Anybody holding the map could work the
-- code out, the same as a code of digits falls to guessing. It's a house
-- puzzle.

CH.PUMPKIN_MAX = 8
-- The pumpkin art (Media/lock-gourd.png) is square, drawn back at its own
-- shape as wide by this much high.
CH.GOURD_H = 0.91
CH.PUMPKIN_REACH, CH.PUMPKIN_REACH_MAX = 2, 8

local NONE = {}

local function Num(v)
    return type(v) == "number" and v == v and math.abs(v) < 100000
end

-- Spots from the flat x, y, floor list, the ones that make sense.
local function Spots(flat)
    if type(flat) ~= "table" then
        return NONE
    end
    local spots = {}
    for i = 1, math.min(#flat, CH.PUMPKIN_MAX * 3) - 2, 3 do
        local x, y, f = flat[i], flat[i + 1], flat[i + 2]
        if Num(x) and Num(y) and type(f) == "number" and f % 1 == 0 and f >= 1 and f <= 99 then
            spots[#spots + 1] = CH.PumpkinSpot(x, y, f)
        end
    end
    return spots
end

-- The blob is base64 of a salt (2 bytes) and the CBOR of the flat list,
-- scrambled with the salt.
local function Seal(spots)
    local flat = {}
    for _, s in ipairs(spots) do
        flat[#flat + 1] = s.x
        flat[#flat + 1] = s.y
        flat[#flat + 1] = s.f
    end
    local salt = math.random(0, 65535)
    local head = string.char(math.floor(salt / 256), salt % 256)
    return C_EncodingUtil.EncodeBase64(head .. CH.Scramble(C_EncodingUtil.SerializeCBOR(flat), "pumpkins|" .. salt))
end

-- It came off the wire, so a broken one can make the decoders throw.
local function Unseal(blob)
    local ok, flat = pcall(function()
        local bytes = C_EncodingUtil.DecodeBase64(blob)
        if not bytes or #bytes < 3 then
            return nil
        end
        local salt = bytes:byte(1) * 256 + bytes:byte(2)
        return C_EncodingUtil.DeserializeCBOR(CH.Scramble(bytes:sub(3), "pumpkins|" .. salt))
    end)
    return Spots(ok and flat)
end

local opened = setmetatable({}, { __mode = "k" }) -- house -> its blob, opened

-- The spots of house h, { x, y, f } each, f the floor.
function CH.HuntSpots(h)
    if not h then
        return NONE
    elseif h.pumpkins then
        return h.pumpkins
    elseif not h.pumpkinBlob then
        return NONE
    end
    local o = opened[h]
    if not o or o.blob ~= h.pumpkinBlob then
        o = { blob = h.pumpkinBlob, spots = Unseal(h.pumpkinBlob) }
        opened[h] = o
    end
    return o.spots
end

function CH.HuntReach(h)
    return h and h.pumpkinReach or CH.PUMPKIN_REACH
end

-- Spots are stored at a tenth of a yard, so both ends write the same key.
function CH.PumpkinSpot(x, y, f)
    return { x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10, f = f }
end

local function SpotKey(s)
    return string.format("%.1f,%.1f,%d", s.x, s.y, s.f)
end

function CH.PatchCode(h)
    local keys = {}
    for i, s in ipairs(CH.HuntSpots(h)) do
        keys[i] = SpotKey(s)
    end
    table.sort(keys)
    return "patch|" .. table.concat(keys, ";")
end

-- ── What a visitor found ─────────────────────────────────────────────

function CH.IsPumpkinFound(house, s)
    local found = ChamberlainDB.pumpkinsFound[house]
    return found ~= nil and found[SpotKey(s)] == true
end

function CH.PumpkinsFound(house)
    local n = 0
    for _, s in ipairs(CH.HuntSpots(ChamberlainDB.houses[house])) do
        if CH.IsPumpkinFound(house, s) then
            n = n + 1
        end
    end
    return n
end

function CH.PickPumpkin(house, s)
    local found = ChamberlainDB.pumpkinsFound[house] or {}
    ChamberlainDB.pumpkinsFound[house] = found
    found[SpotKey(s)] = true
end

-- Every pumpkin back in its place, to play the hunt again.
function CH.ForgetPumpkins(house)
    ChamberlainDB.pumpkinsFound[house] = nil
    CH.RelockPatch(house)
end

-- ── The wire ─────────────────────────────────────────────────────────
-- The owner's spots go out sealed. A copy passes its blob on as it came.

function CH.WritePumpkins(h)
    local spots = h.pumpkins
    if spots and #spots > 0 then
        return Seal(spots), h.pumpkinReach
    end
    return h.pumpkinBlob, h.pumpkinBlob and h.pumpkinReach
end

-- The blob as it came and the reach, for the house entry.
function CH.ReadPumpkins(pk, pr)
    if type(pk) ~= "string" or #pk > 1024 then
        return nil
    end
    local reach = type(pr) == "number" and pr % 1 == 0 and pr >= 1 and pr <= CH.PUMPKIN_REACH_MAX and pr or nil
    return pk, reach
end

-- ── Walking near one ─────────────────────────────────────────────────
-- From the zone ticker. The pop-up asks once per walk up to a pumpkin and
-- again after you've stepped out of its reach. Your own pumpkins never ask.

local asked

function CH.HuntTick(h, x, y)
    if CH.isOwnHouse then
        return
    end
    local spots = CH.HuntSpots(h)
    if #spots == 0 then
        return
    end
    local reach = CH.HuntReach(h) ^ 2
    local near
    for _, s in ipairs(spots) do
        if
            s.f == CH.activeFloor
            and (s.x - x) ^ 2 + (s.y - y) ^ 2 <= reach
            and not CH.IsPumpkinFound(CH.currentHouseGUID, s)
        then
            near = s
            break
        end
    end
    if near ~= asked then
        asked = near
        if near then
            CH.ShowPumpkinPopup(near)
        else
            CH.HidePumpkinPopup()
        end
    end
end

function CH.StopHunt()
    asked = nil
    CH.HidePumpkinPopup()
    CH.HidePumpkinBag()
end
