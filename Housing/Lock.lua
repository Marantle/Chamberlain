local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Locked areas: a code hides an area's name, banner style and story
-- ─────────────────────────────────────────────────────────────────────
-- The owner keeps the code and the plain fields. On the wire the hidden
-- fields ride in one scrambled blob, lk, so nobody finds the answer by
-- searching a shared string. It's light on purpose. A code of digits falls to
-- anyone who sets out to guess it, and that's fine for a house puzzle. The
-- code itself never leaves the owner.
--
-- lk is base64 of the salt (2 bytes), a check (2 bytes) and the CBOR of the
-- hidden fields, xored with a stream seeded from the code, the house and the
-- salt. The salt is picked once per area, so two areas on one code diffre.

-- The wire keys a lock hides. CH.SealEntry below leaves them out of a locked
-- zone.
CH.LOCK_HIDDEN = { "n", "bs", "t", "hi", "hd", "sp", "oh", "dr", "np" }
-- what a locked zone sends as its name, for clients before 3.43.0
CH.LOCK_WIRE_NAME = "Locked"
-- Lock styles by wire id, append only like the heads.
CH.LOCK_STYLES = { "LOCK_STYLE_ARCANE" }
CH.LOCK_CODE_MIN, CH.LOCK_CODE_MAX = 4, 8

local TWO32 = 2 ^ 32

-- Only good for seeding the stream.
local function Hash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % TWO32
    end
    return h
end

-- xor with an LCG stream. Running it again undoes it.
local function Stream(data, seed)
    local x = seed
    local out = {}
    for i = 1, #data do
        x = (x * 69069 + 1) % TWO32
        out[i] = string.char(bit.bxor(data:byte(i), math.floor(x / 2 ^ 24)))
    end
    return table.concat(out)
end

local function Seed(code, house, salt)
    return Hash(code .. "|" .. house .. "|" .. salt)
end

local function Check(code, salt)
    return Hash("check|" .. code .. "|" .. salt) % 65536
end

local function Seal(fields, code, salt, house)
    local check = Check(code, salt)
    local head = string.char(math.floor(salt / 256), salt % 256, math.floor(check / 256), check % 256)
    local raw = C_EncodingUtil.SerializeCBOR(fields)
    return C_EncodingUtil.EncodeBase64(head .. Stream(raw, Seed(code, house, salt)))
end

-- The hidden fields in their wire keys, or nil for a wrong code. The blob
-- came off the wire, so a broken one can make the decoders throw.
local function Open(blob, code, house)
    local ok, fields = pcall(function()
        local bytes = C_EncodingUtil.DecodeBase64(blob)
        if not bytes or #bytes < 5 then
            return nil
        end
        local salt = bytes:byte(1) * 256 + bytes:byte(2)
        if bytes:byte(3) * 256 + bytes:byte(4) ~= Check(code, salt) then
            return nil
        end
        return C_EncodingUtil.DeserializeCBOR(Stream(bytes:sub(5), Seed(code, house, salt)))
    end)
    return ok and type(fields) == "table" and type(fields.n) == "string" and fields or nil
end

function CH.ValidLockCode(code)
    return #code >= CH.LOCK_CODE_MIN and #code <= CH.LOCK_CODE_MAX and code:find("^%d+$") ~= nil
end

function CH.IsLocked(zone)
    return zone ~= nil and zone.lockBlob ~= nil and not zone.lockOpen
end

function CH.LockStyleName(zone)
    return CH.L[CH.LOCK_STYLES[zone.lockStyle] or CH.LOCK_STYLES[1]]
end

-- An owner's area gets its salt the first time it's locked.
function CH.NewLockSalt()
    return math.random(0, 65535)
end

-- Export side: seal wire entry e of zone z. An owner's area is sealed from
-- its code. A copy someone else made passes its blob on as it came, and the
-- fields it opened stay with whoever opened them.
function CH.SealEntry(e, z, house)
    local blob = z.lockBlob
    if z.lockCode then
        local hidden = {}
        for _, k in ipairs(CH.LOCK_HIDDEN) do
            hidden[k] = e[k]
        end
        blob = Seal(hidden, z.lockCode, z.lockSalt, house)
    end
    if not blob then
        return
    end
    for _, k in ipairs(CH.LOCK_HIDDEN) do
        e[k] = nil
    end
    e.n = CH.LOCK_WIRE_NAME
    e.lk = blob
    e.ls = z.lockStyle
end

-- Codes that opened something, by house and the blob's salt and check. A
-- new map of the house opens again by itself, unless the owner changed the
-- code, which changes the check.
local function CodeKey(house, blob)
    return house .. ":" .. blob:sub(1, 6)
end

local function Reveal(zone, fields)
    for k, v in pairs(CH.ReadHiddenFields(fields)) do
        zone[k] = v
    end
    zone.lockOpen = true
end

-- A code typed at the lock. True when it opened the area. A test run
-- doesn't remember the code.
function CH.TryLockCode(zone, house, code, test)
    local fields = Open(zone.lockBlob, code, house)
    if not fields then
        return false
    end
    Reveal(zone, fields)
    if not test then
        ChamberlainDB.lockCodes[CodeKey(house, zone.lockBlob)] = code
    end
    return true
end

-- Try the lock on the Lock tab: room z sealed with code the way a shared
-- map seals it, as a throwaway area a visitor would get. Opening it runs the
-- whole round trip and the real room never changes.
function CH.LockTestCopy(z, house, code)
    local e = CH.ZoneEntry(z)
    CH.SealEntry(e, { lockCode = code, lockSalt = z.lockSalt or CH.NewLockSalt(), lockStyle = 1 }, house)
    return { lockBlob = e.lk, lockStyle = e.ls, name = CH.L["LOCK_AREA"], color = z.color }
end

-- The zone fields an open lock filled in, which locking again takes back.
local REVEALED =
    { "name", "headID", "headDisplay", "speaker", "useOwnerHead", "decor", "noPortrait", "rpText", "bannerStyle" }

-- /rooms relock: shut every area this player opened in the house and forget
-- the codes, so the locks can be tried again. Your own areas have no blob
-- and stay as they are.
function CH.Relock(house)
    local h = house and ChamberlainDB.houses[house]
    if not h then
        CH.Print(CH.L["LOCK_RELOCK_NONE"])
        return
    end
    for key in pairs(ChamberlainDB.lockCodes) do
        if key:sub(1, #house + 1) == house .. ":" then
            ChamberlainDB.lockCodes[key] = nil
        end
    end
    local n = 0
    for _, zone in ipairs(h.zones) do
        if zone.lockOpen then
            for _, k in ipairs(REVEALED) do
                zone[k] = nil
            end
            zone.name = CH.L["LOCK_AREA"]
            zone.lockOpen = nil
            n = n + 1
        end
    end
    CH.Print(CH.L["LOCK_RELOCKED_X"], n)
    CH.OnBannerSettingChanged()
end

-- After a new map lands, open whatever this player opened before.
function CH.ReopenLocks(h, house)
    for _, zone in ipairs(h.zones) do
        local code = zone.lockBlob and ChamberlainDB.lockCodes[CodeKey(house, zone.lockBlob)]
        local fields = code and Open(zone.lockBlob, code, house)
        if fields then
            Reveal(zone, fields)
        end
    end
end
