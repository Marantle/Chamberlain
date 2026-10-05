local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Tours  (the owner's walk through the house, room by room)
-- ─────────────────────────────────────────────────────────────────────
-- The owner gives rooms a stop number (zone.tourStop, wire field to, 3.41.0)
-- and the house a welcome and a goodbye. A visitor who takes the tour walks
-- the stops in the owner's order. Only the next stop plays its yapper and
-- counts. A later one walked into early is a plain room until its turn comes.
-- A card counts the stops seen and points at the next one. Seen stops go by
-- their number, so a fresh copy of the map coming in halfway keeps the tour
-- wher it was. Nothing of a tour is saved. It lasts the visit.

local tour -- { guid, seen = { [stop] = true }, done }

function CH.IsTourStop(n)
    return type(n) == "number" and n >= 1 and n <= 100 and n % 1 == 0
end

-- A room that can be a stop, the Tour panel's list as well. A sound spot or
-- a stair landing is never walked into as a room. Stairwells are rooms and
-- can be stops. A secret room can be one too since 3.43.0: it stays off the
-- visitor's map, so the card's arrow is how they find it.
function CH.TourRoom(z)
    return CH.IsRoom(z) and not z.part
end

-- A room that counts on the tour.
local function OnTour(z)
    return z.tourStop ~= nil and CH.TourRoom(z)
end

-- The stops of house h in tour order, into out.
function CH.TourStops(h, out)
    wipe(out)
    for _, z in ipairs(h.zones) do
        if OnTour(z) then
            out[#out + 1] = z
        end
    end
    -- ties keep the order the rooms are in
    local at = {}
    for i, z in ipairs(out) do
        at[z] = i
    end
    table.sort(out, function(a, b)
        if a.tourStop ~= b.tourStop then
            return a.tourStop < b.tourStop
        end
        return at[a] < at[b]
    end)
    return out
end

-- Each stop's place in the tour, 1 up with the gaps closed, into out.
local sorted = {}
function CH.TourRanks(h, out)
    wipe(out)
    for i, z in ipairs(CH.TourStops(h, sorted)) do
        out[z] = i
    end
    return out
end

function CH.TouringHere(guid)
    return tour ~= nil and tour.guid == guid
end

function CH.CanStartTour(guid)
    local h = guid and ChamberlainDB.houses[guid]
    if not h or CH.TouringHere(guid) then
        return false
    end
    for _, z in ipairs(h.zones) do
        if OnTour(z) then
            return true
        end
    end
    return false
end

-- Seen on the tour running in the house the map shows.
function CH.TourSeen(guid, zone)
    return CH.TouringHere(guid) and zone.tourStop ~= nil and tour.seen[zone.tourStop] == true
end

-- The unseen stop with the lowest number. A loop rather than a sort, since
-- the ticker asks ten times a second.
local function NextStop(h)
    local best
    for _, z in ipairs(h.zones) do
        if OnTour(z) and not tour.seen[z.tourStop] and (not best or z.tourStop < best.tourStop) then
            best = z
        end
    end
    return best
end

local nextZone -- the stop the card points at, lit on the maps

function CH.IsTourNext(zone)
    return zone == nextZone
end

-- ── The card ────────────────────────────────────────────────────────

local W, PAD = 260, 12

local card = CreateFrame("Frame", "ChamberlainTour", UIParent, "BackdropTemplate")
CH.tourCard = card
card:SetSize(W, 100)
card:SetFrameStrata("MEDIUM")
card:SetBackdrop(CH.BACKDROP_THIN)
card:SetBackdropColor(0.03, 0.027, 0.02, 0.88)
card:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 1))
card:Hide()
CH.ApplyTourPos = CH.MakeMovablePersistent(card, "tourX", "tourY")

local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetWidth(W - PAD - 66)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)
title:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))

local closeBtn = CH.MakeGlyphButton(card, "x")
closeBtn:SetPoint("TOPRIGHT", -6, -6)
CH.Tip(closeBtn, "TOUR_TT_LEAVE")
closeBtn:SetScript("OnClick", function()
    CH.StopTour()
end)

-- Back and forward beside it, see Step for what they do.
local fwdBtn = CH.MakeGlyphButton(card, nil, "arrow-right")
fwdBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
CH.Tip(fwdBtn, "TOUR_TT_FORWARD")
local backBtn = CH.MakeGlyphButton(card, nil, "arrow-left")
backBtn:SetPoint("RIGHT", fwdBtn, "LEFT", -2, 0)
CH.Tip(backBtn, "TOUR_TT_BACK")

local count = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
count:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
count:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

-- One pip per stop, gold for seen. Made as a tour needs them.
local strip = CreateFrame("Frame", nil, card)
strip:SetPoint("TOPLEFT", count, "BOTTOMLEFT", 0, -8)
strip:SetSize(W - 2 * PAD, 6)
local pips = {}

local function PaintPips(stops)
    local n = #stops
    local gap = n > 20 and 1 or 3
    local w = (W - 2 * PAD - (n - 1) * gap) / n
    for i, z in ipairs(stops) do
        local p = pips[i]
        if not p then
            p = strip:CreateTexture(nil, "ARTWORK")
            p:SetHeight(6)
            pips[i] = p
        end
        p:ClearAllPoints()
        p:SetPoint("LEFT", (i - 1) * (w + gap), 0)
        p:SetWidth(w)
        if tour.seen[z.tourStop] then
            p:SetColorTexture(CH.RGBA(CH.COLORS.border, 1))
        elseif z == nextZone then
            p:SetColorTexture(CH.RGBA(CH.COLORS.gold, 1))
        else
            p:SetColorTexture(0.17, 0.15, 0.11, 1)
        end
        p:Show()
    end
    for i = n + 1, #pips do
        pips[i]:Hide()
    end
end

-- The next stop: a gold arrow that turns with you inside a dial that stays
-- put, and where the room is beside it. The art comes from
-- _tour-art/compass.py.
local DIAL = 44
local dial = card:CreateTexture(nil, "ARTWORK")
dial:SetTexture(CH.MEDIA .. "tour-dial.tga")
dial:SetSize(DIAL, DIAL)
dial:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", -4, -6)
local arrow = card:CreateTexture(nil, "OVERLAY")
arrow:SetTexture(CH.MEDIA .. "tour-arrow.tga")
arrow:SetSize(DIAL, DIAL)
arrow:SetPoint("CENTER", dial)

local nextName = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
nextName:SetPoint("BOTTOMLEFT", dial, "RIGHT", 8, 1)
nextName:SetWidth(W - 2 * PAD - DIAL - 4)
nextName:SetJustifyH("LEFT")
nextName:SetWordWrap(false)
nextName:SetTextColor(CH.RGBA(CH.COLORS.bannerText, 1))

local nextWhere = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nextWhere:SetPoint("TOPLEFT", nextName, "BOTTOMLEFT", 0, -3)
nextWhere:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

-- The end of the tour: the owner's goodbye and a way to put the card away.
local bye = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bye:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -10)
bye:SetWidth(W - 2 * PAD)
bye:SetJustifyH("LEFT")
bye:SetSpacing(2)
bye:SetTextColor(0.91, 0.86, 0.69, 1)

local doneBtn = CH.MakeButton(card, "TOUR_CLOSE", 90, 22)
doneBtn:SetScript("OnClick", function()
    CH.StopTour()
end)

local function Layout()
    local done = tour.done
    dial:SetShown(not done)
    arrow:SetShown(not done and GetPlayerFacing() ~= nil)
    nextName:SetShown(not done)
    nextWhere:SetShown(not done)
    bye:SetShown(done)
    doneBtn:SetShown(done)
    local h = PAD + title:GetStringHeight() + 4 + count:GetStringHeight() + 8 + 6 + 10
    if done then
        local text = ChamberlainDB.houses[tour.guid].tourBye
        bye:SetText(text and string.format(CH.L["PL_MOTTO_X"], text) or "")
        doneBtn:ClearAllPoints()
        if text then
            doneBtn:SetPoint("TOPLEFT", bye, "BOTTOMLEFT", 0, -10)
            h = h + bye:GetStringHeight() + 10
        else
            doneBtn:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -10)
        end
        h = h + 22
    else
        h = h + DIAL - 4
    end
    card:SetHeight(h + PAD)
end

-- Where the next stop is from you, said only when the words change.
local whereText
local function PointAt(x, y, mapID)
    if not nextZone then
        return
    end
    local facing = GetPlayerFacing()
    arrow:SetShown(facing ~= nil)
    if facing then
        -- our x runs west and y north, and a facing of 0 is north turning left
        local cx = (nextZone.minX + nextZone.maxX) * 0.5
        local cy = (nextZone.minY + nextZone.maxY) * 0.5
        arrow:SetRotation(math.atan2(cx - x, cy - y) - facing)
    end
    local yards = math.floor(CH.DistanceToZone(nextZone, x, y, mapID) + 0.5)
    local floor, here = nextZone.floor or 1, CH.activeFloor or 1
    local text
    if floor > here then
        text = string.format(CH.L["TOUR_UPSTAIRS_X"], yards)
    elseif floor < here then
        text = string.format(CH.L["TOUR_DOWNSTAIRS_X"], yards)
    else
        text = string.format(CH.L["TOUR_YARDS_X"], yards)
    end
    if text ~= whereText then
        whereText = text
        nextWhere:SetText(text)
    end
end

local stops = {}

-- Count the stops, light the next one and draw the card again. Runs on the
-- start, each stop seen and a map coming in with other stops.
local function Refresh(h)
    CH.TourStops(h, stops)
    local seen = 0
    for _, z in ipairs(stops) do
        if tour.seen[z.tourStop] then
            seen = seen + 1
        end
    end
    local done = #stops > 0 and seen == #stops
    -- the goodbye is read once the last stop's yapper has had its say, and a
    -- step back from the end takes it back
    if done and not tour.done then
        tour.byePending = h.tourBye ~= nil
    elseif not done then
        tour.byePending = nil
    end
    tour.done = done
    -- a glyph button has no greyed look, so one with nothing to do goes
    backBtn:SetShown(seen > 0)
    fwdBtn:SetShown(not done)
    nextZone = not tour.done and NextStop(h) or nil
    title:SetText(string.format(CH.L["TOUR_OF_X"], CH.HouseName(tour.guid) or h.owner or ""))
    if tour.done then
        count:SetText(string.format(CH.L["TOUR_DONE_X"], #stops))
    else
        count:SetText(string.format(CH.L["TOUR_SEEN_X_OF_Y"], seen, #stops))
        nextName:SetText(nextZone and nextZone.name or "")
        whereText = nil
    end
    PaintPips(stops)
    Layout()
    CH.FP.minimapDirty = true
    if CH.floorPlan:IsShown() then
        CH.FP.Build()
    end
end

-- Back makes the stop seen last the next one again, so walking in plays it
-- again. Forward counts the next stop seen without playing it, for a room
-- that's locked or one you know already. Either way the arrow follows.
local function Step(back)
    local h = ChamberlainDB.houses[tour.guid]
    if back then
        CH.TourStops(h, stops)
        for i = #stops, 1, -1 do
            if tour.seen[stops[i].tourStop] then
                tour.seen[stops[i].tourStop] = nil
                break
            end
        end
    else
        local n = NextStop(h)
        if n then
            tour.seen[n.tourStop] = true
        end
    end
    Refresh(h)
end

backBtn:SetScript("OnClick", function()
    Step(true)
end)
fwdBtn:SetScript("OnClick", function()
    Step(false)
end)

-- ── Starting, stopping and the ticker ───────────────────────────────

-- The yapper for zone with text in place of its own words, under the
-- room's banner. It reads them aloud the way it reads any room, see
-- CH.ResolveZoneVoice.
local function Speak(zone, text)
    CH.ShowTalkingHead(setmetatable({ rpText = text }, { __index = zone }))
end

-- Who speaks the welcome and the goodbye, picked in the Tour panel the way a
-- room's story is. Without a pick it's the owner's own character.
local OWNER = { useOwnerHead = true }
function CH.TourGuide(h)
    return h.tourGuide or OWNER
end

-- The welcome plays as you start. Standing in the first stop already counts
-- it, and its own words follow the welcome in the same yapper.
function CH.StartTour(guid)
    local h = ChamberlainDB.houses[guid]
    tour = { guid = guid, seen = {} }
    local room = CH.currentRoom
    local text = h.tourWelcome
    local speaker = CH.TourGuide(h)
    if room and OnTour(room) and room.tourStop == NextStop(h).tourStop then
        tour.seen[room.tourStop] = true
        if room.rpText and room.rpText ~= "" then
            text = text and text .. "\n\n" .. room.rpText or room.rpText
            speaker = room
        end
    end
    if text then
        Speak(speaker, text)
    end
    card:Show()
    Refresh(h)
    CH.RefreshHUDMode()
end

function CH.StopTour()
    if not tour then
        return
    end
    tour, nextZone = nil, nil
    card:Hide()
    CH.FP.minimapDirty = true
    if CH.floorPlan:IsShown() then
        CH.FP.Build()
    end
    CH.RefreshHUDMode()
end

-- The bar's button and /rooms tour.
function CH.ToggleTour()
    if CH.TouringHere(CH.currentHouseGUID) then
        CH.StopTour()
    elseif CH.CanStartTour(CH.currentHouseGUID) then
        CH.StartTour(CH.currentHouseGUID)
    else
        CH.Print(CH.L["TOUR_NONE"])
    end
end

-- The zone ticker's room change. The next stop plays its yapper whether
-- banners are on or not, since the visitor asked for the tour. Any other
-- room, stops still to come included, shows its banner as usual. The next
-- stop is looked up again because the map may have changed since the last
-- tick.
function CH.TourEnter(zone)
    if not tour or tour.done or tour.guid ~= CH.currentHouseGUID or not OnTour(zone) then
        return
    end
    local h = ChamberlainDB.houses[tour.guid]
    local nextStop = NextStop(h)
    if not nextStop or zone.tourStop ~= nextStop.tourStop then
        return
    end
    tour.seen[zone.tourStop] = true
    if zone.rpText and zone.rpText ~= "" then
        Speak(zone, zone.rpText)
    end
    Refresh(h)
end

-- Every zone tick while a tour runs. Leaving the house for another ends it.
-- A new map moves the next stop, and the arrow follows you.
function CH.TourTick(h, x, y, mapID)
    if not tour then
        return
    end
    if tour.guid ~= CH.currentHouseGUID then
        CH.StopTour()
        return
    end
    if not tour.done and NextStop(h) ~= nextZone then
        Refresh(h)
    end
    if not tour.done then
        PointAt(x, y, mapID)
    elseif tour.byePending and not CH.talkingHead:IsShown() then
        tour.byePending = false
        Speak(CH.TourGuide(h), h.tourBye)
    end
end
