local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: the house card
-- ─────────────────────────────────────────────────────────────────────
-- The rail on a map you can't edit: someone else's house, or any house picked
-- in the Rooms window. It shows whose house it is and how old the map is, a
-- newer map when the group has one and the room under the mouse. The yapper's
-- words stay out of it on purpose, since those are for reading in the house.

local FP = CH.FP
local PAD = 10
local WIDTH = 188

local card = CreateFrame("Frame", nil, FP.rail)
card:SetAllPoints()
card:Hide()
FP.card = card

local function Text(font, color)
    local fs = card:CreateFontString(nil, "OVERLAY", font)
    fs:SetWidth(WIDTH)
    fs:SetJustifyH("LEFT")
    if color then
        fs:SetTextColor(CH.RGBA(color, 1))
    end
    return fs
end

local title = Text("GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD, -12)
title:SetTextColor(1, 1, 1, 1)
title:SetWordWrap(false)

local meta = Text("GameFontHighlightSmall", CH.COLORS.dim)
meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

local age = Text("GameFontHighlightSmall", CH.COLORS.dim)
age:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -4)

-- The group's offer, same words as in the Rooms window.
local offer = CreateFrame("Frame", nil, card, "BackdropTemplate")
offer:SetPoint("TOPLEFT", age, "BOTTOMLEFT", 0, -10)
offer:SetWidth(WIDTH)
offer:SetBackdrop(CH.BACKDROP_THIN)
offer:SetBackdropColor(1, 0.6, 0, 0.08)
offer:SetBackdropBorderColor(1, 0.6, 0, 0.35)
local offerText = offer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
offerText:SetPoint("TOPLEFT", 7, -6)
offerText:SetWidth(WIDTH - 14)
offerText:SetJustifyH("LEFT")
offerText:SetSpacing(2)

local request = CH.MakeButton(card, "RM_REQUEST", WIDTH, 22)
request:SetPoint("TOPLEFT", offer, "BOTTOMLEFT", 0, -6)

local sep = CH.MakeRule(card)
sep:SetWidth(WIDTH)

-- The room under the mouse.
local roomName = Text("GameFontNormal", CH.COLORS.gold)
roomName:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -10)
roomName:SetWordWrap(false)

local roomSize = Text("GameFontHighlightSmall", CH.COLORS.dim)
roomSize:SetPoint("TOPLEFT", roomName, "BOTTOMLEFT", 0, -4)

local roomSounds = Text("GameFontHighlightSmall", CH.COLORS.dim)
roomSounds:SetPoint("TOPLEFT", roomSize, "BOTTOMLEFT", 0, -8)
roomSounds:SetSpacing(3)

local back = CH.MakeButton(card, "FP_BACK_HERE", WIDTH, 22)
back:SetPoint("BOTTOMLEFT", PAD, 10)
back:SetScript("OnClick", function()
    CH.OpenFloorPlan()
end)

local shownGuid -- the house the room lines were filled for

local function ClearRoom()
    roomName:SetText(CH.L["FP_POINT_AT_ROOM"])
    roomName:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
    roomSize:SetText("")
    roomSounds:SetText("")
end

local function SoundLine(key, value)
    return CH.L[key] .. "  |cffffffff" .. value .. "|r"
end

function FP.ShowCardRoom(idx)
    if not card:IsShown() then
        return
    end
    local h = FP.CurrentHouse()
    local z = h and h.zones[idx]
    if not z then
        return
    end
    roomName:SetText(z.name)
    roomName:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    roomSize:SetText(CH.ZoneDimText(z))
    local lines = {}
    if z.ambience and CH.AMBIENCE[z.ambience] then
        lines[#lines + 1] = SoundLine("RD_AMBIENCE", CH.L[CH.AMBIENCE[z.ambience].key])
    end
    if z.music then
        lines[#lines + 1] = SoundLine("RD_MUSIC", CH.SoundName(z.music, true))
    end
    if z.sfx then
        lines[#lines + 1] = SoundLine("RD_SFX", CH.SoundName(z.sfx, true))
    end
    roomSounds:SetText(table.concat(lines, "\n"))
end

-- h is the house on the map, nil when there's no map of it yet.
function FP.RefreshCard(h)
    local guid = FP.HouseGUID()
    title:SetText(FP.sub:GetText())

    local rooms = 0
    for _, z in ipairs(h and h.zones or {}) do
        if FP.ZoneVisible(z) then
            rooms = rooms + 1
        end
    end
    meta:SetText(h and string.format(CH.L["RM_ROOMS_FLOORS_X"], rooms, h.floorCount or 1) or "")
    local stamp = h and h.updatedAt or 0
    age:SetText(stamp > 0 and string.format(CH.L["FP_MAP_FROM_X"], date("%Y-%m-%d", stamp)) or "")

    local p = guid and CH.GroupOffer(guid)
    if p then
        offerText:SetText(CH.L[p.status == "newer" and "RM_GROUP_HAS_NEWER" or "RM_GROUP_HAS_MAP"])
        offer:SetHeight(offerText:GetStringHeight() + 12)
        request:SetEnabled(not CH.RequestCooling(guid))
    end
    offer:SetShown(p ~= nil)
    request:SetShown(p ~= nil)
    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", p and request or age, "BOTTOMLEFT", 0, -12)

    -- A house picked in the Rooms window while you stand in another.
    back:SetShown(FP.viewGUID ~= nil and CH.currentHouseGUID ~= nil)

    if guid ~= shownGuid then
        shownGuid = guid
        ClearRoom()
    end
end

request:SetScript("OnClick", function()
    request:Disable()
    CH.RequestGroupMap(FP.HouseGUID())
end)

-- For when the group's maps chnage under an open card.
function CH.RefreshHouseCard()
    if card:IsShown() then
        FP.RefreshCard(FP.CurrentHouse())
    end
end
