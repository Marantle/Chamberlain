local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room manager window  (house list on the left, the picked house on the right)
-- ─────────────────────────────────────────────────────────────────────

local LIST_W = 210 -- left column, its scroll bar included

local roomMgr = CreateFrame("Frame", "ChamberlainRoomManager", UIParent, "BackdropTemplate")
roomMgr:SetSize(600, 520)
roomMgr:SetFrameStrata("DIALOG")
-- See FloorPlan.lua: SetToplevel lets clicking/showing this window pull its
-- whole subtree above the Floor Plan (same strata) instead of bleeding through.
roomMgr:SetToplevel(true)
roomMgr:SetPoint("CENTER")
CH.MakeDraggable(roomMgr)
CH.SkinWindow(roomMgr, "RM_WINDOW_TITLE")
roomMgr:Hide()
table.insert(UISpecialFrames, "ChamberlainRoomManager")

-- Settings have their own window in UI/Settings.lua.

local mgrClose = CH.MakeButton(roomMgr, "RM_CLOSE", 80, 22)
mgrClose:SetPoint("BOTTOMRIGHT", roomMgr, "BOTTOMRIGHT", -10, 10)
mgrClose:SetScript("OnClick", function()
    roomMgr:Hide()
end)

local btnImport = CH.MakeButton(roomMgr, "RM_IMPORT", 80, 22)
btnImport:SetPoint("BOTTOMLEFT", roomMgr, "BOTTOMLEFT", 10, 10)
btnImport:SetScript("OnClick", function()
    CH.OpenExportDialog("import")
end)

local btnArchive = CH.MakeButton(roomMgr, "RM_ARCHIVE", 80, 22)
btnArchive:SetPoint("LEFT", btnImport, "RIGHT", 4, 0)
btnArchive:SetScript("OnClick", function()
    CH.OpenArchive()
end)

local divider = roomMgr:CreateTexture(nil, "ARTWORK")
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", LIST_W + 12, -34)
divider:SetPoint("BOTTOMLEFT", roomMgr, "BOTTOMLEFT", LIST_W + 12, 40)
divider:SetColorTexture(CH.RGBA(CH.COLORS.sep, 0.5))

-- ─────────────────────────────────────────────────────────────────────
-- House data
-- ─────────────────────────────────────────────────────────────────────

-- Collect all zones from owned houses, grouped by house.
local function GetOwnedHouseList()
    local list = {}
    for guid, _ in pairs(ChamberlainDB.myHouses or {}) do
        local h = ChamberlainDB.houses[guid]
        if h and h.zones and #h.zones > 0 then
            list[#list + 1] = { guid = guid, owner = h.owner, realm = h.realm, zones = h.zones, own = true }
        end
    end

    -- Same character name can exist on different realms on the same account.
    -- Only append realm when two owned houses share an owner name.
    local nameSeen = {}
    for _, entry in ipairs(list) do
        local base = string.format(CH.L["RM_X_HOUSE"], entry.owner or CH.L["RM_HOME_INTERIOR"])
        nameSeen[base] = (nameSeen[base] or 0) + 1
    end
    for _, entry in ipairs(list) do
        local base = string.format(CH.L["RM_X_HOUSE"], entry.owner or CH.L["RM_HOME_INTERIOR"])
        if nameSeen[base] > 1 and entry.realm then
            entry.label = string.format(CH.L["RM_HOUSE_LABEL_REALM_X"], base, entry.realm)
        else
            entry.label = base
        end
    end

    table.sort(list, function(a, b)
        return a.label < b.label
    end)
    return list
end

local function GetSharedHouseList()
    local list = {}
    for guid, h in pairs(ChamberlainDB.houses) do
        if not ChamberlainDB.myHouses[guid] and h.zones and #h.zones > 0 then
            -- These are layouts you received as a visitor, so drop the owner's
            -- secret rooms: they ride the wire for the banner but stay off the
            -- list, matching the floor plan. Owned houses (above) keep theirs.
            local visible = {}
            for _, zone in ipairs(h.zones) do
                if not zone.secret then
                    visible[#visible + 1] = zone
                end
            end
            if #visible > 0 then
                local label = string.format(CH.L["RM_X_HOUSE"], h.owner or CH.L["RM_UNKNOWN"])
                list[#list + 1] = { guid = guid, label = label, zones = visible }
            end
        end
    end
    table.sort(list, function(a, b)
        return a.label < b.label
    end)
    return list
end

local function GetPartyHouseList()
    local byGUID = {}
    for playerName, catalog in pairs(CH.partyCatalogs or {}) do
        for houseGUID, entry in pairs(catalog) do
            local cur = byGUID[houseGUID]
            if not cur or entry.timestamp > cur.bestTimestamp then
                byGUID[houseGUID] = {
                    guid = houseGUID,
                    owner = entry.owner or playerName,
                    bestTimestamp = entry.timestamp,
                    bestHolder = playerName,
                    isTransitive = (entry.owner ~= nil and entry.owner ~= playerName),
                    zoneCount = entry.zoneCount,
                }
            end
        end
    end
    local list = {}
    for _, v in pairs(byGUID) do
        list[#list + 1] = v
    end
    table.sort(list, function(a, b)
        return (a.owner or "") < (b.owner or "")
    end)
    return list
end

local function GetStatus(guid, bestTimestamp)
    if ChamberlainDB.myHouses[guid] then
        return "own"
    end
    local mine = ChamberlainDB.houses[guid]
    if not mine then
        return "not_owned"
    end
    if bestTimestamp > (mine.updatedAt or 0) then
        return "newer"
    end
    return "current"
end

-- ─────────────────────────────────────────────────────────────────────
-- House list (left)
-- ─────────────────────────────────────────────────────────────────────

local selected -- guid of the house shown on the right
local wantGroup = false -- pick the first group map on the next populate
local query = ""
local Populate -- forward declaration; defined below

-- A scroll frame has no width before the window first lays out, so the first
-- popluate goes by the width it's going to have.
local function FitScrollChild(scroll, child, fallback)
    local w = scroll:GetWidth()
    if w <= 10 then
        w = fallback
    end
    child:SetWidth(w)
    return w
end

local searchBox = CreateFrame("EditBox", nil, roomMgr, "InputBoxTemplate")
searchBox:SetSize(LIST_W - 10, 20)
searchBox:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", 16, -34)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(40)

local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 6, 0)
searchHint:SetText(CH.L["RM_SEARCH_HINT"])

local listScroll, listChild = CH.MakeScrollList(roomMgr, "ChamberlainMgrScroll")
listScroll:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", 8, -60)
listScroll:SetPoint("BOTTOMRIGHT", roomMgr, "BOTTOMLEFT", LIST_W - 12, 40)

searchBox:SetScript("OnTextChanged", function(self)
    searchHint:SetShown(self:GetText() == "")
    query = string.lower(string.match(self:GetText(), "^%s*(.-)%s*$"))
    listScroll:SetVerticalScroll(0)
    Populate()
end)
searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)

local listEmpty = listChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
listEmpty:SetPoint("TOPLEFT", 4, -8)
listEmpty:SetPoint("RIGHT", listChild, "RIGHT", -4, 0)
listEmpty:SetJustifyH("LEFT")
listEmpty:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local SECTION_H = 18
local HOUSE_ROW_H = 20

-- Headers and notes are font strings and house rows are buttons, each in its
-- own pool.
local lineLabels = {}
local houseRows = {}

local function LineLabel(i)
    local fs = lineLabels[i]
    if not fs then
        fs = listChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        lineLabels[i] = fs
    end
    return fs
end

local function HouseRow(i)
    local row = houseRows[i]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, listChild)
    row:SetHeight(HOUSE_ROW_H)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.22))

    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.tag:SetPoint("RIGHT", -4, 0)
    row.tag:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        selected = self.guid
        Populate()
    end)
    houseRows[i] = row
    return row
end

local function Matches(item)
    if query == "" or string.find(string.lower(item.label), query, 1, true) then
        return true
    end
    for _, zone in ipairs(item.zones or {}) do
        if string.find(string.lower(zone.name or ""), query, 1, true) then
            return true
        end
    end
    return false
end

-- The three sections of the list, each item with what the right side needs.
-- Group maps only show while there is something to fetch, a map you lack or a
-- newer one than yours. Maps already current sit in their own section anyway.
local function BuildSections()
    local shared = GetSharedHouseList()
    local sharedByGUID = {}
    for _, item in ipairs(shared) do
        sharedByGUID[item.guid] = item
    end

    local party = {}
    local groupItems = {}
    local partyList = GetPartyHouseList()
    for _, p in ipairs(partyList) do
        local status = GetStatus(p.guid, p.bestTimestamp)
        if status == "not_owned" or status == "newer" then
            p.status = status
            party[p.guid] = p
            -- A newer map than yours shows the rooms of the copy you hold, with
            -- the owner's secret rooms already left out.
            local copy = sharedByGUID[p.guid]
            local item = {
                guid = p.guid,
                label = string.format(CH.L["RM_X_HOUSE"], p.owner),
                tag = CH.L[status == "newer" and "RM_TAG_NEWER" or "RM_TAG_NEW"],
                zones = copy and copy.zones or {},
            }
            if Matches(item) then
                groupItems[#groupItems + 1] = item
            end
        end
    end

    local function withMatches(list)
        local out = {}
        for _, item in ipairs(list) do
            if Matches(item) then
                item.tag = tostring(#item.zones)
                out[#out + 1] = item
            end
        end
        return out
    end

    local sections = {}
    if IsInGroup() then
        local note
        if query == "" and #groupItems == 0 then
            note = #partyList == 0 and "RM_NO_MEMBERS_HAVE_ADDON" or "RM_GROUP_NOTHING_NEW"
        end
        sections[1] = { key = "RM_IN_GROUP", items = groupItems, note = note }
    end
    sections[#sections + 1] = { key = "RM_YOUR_HOUSES", items = withMatches(GetOwnedHouseList()) }
    sections[#sections + 1] = { key = "RM_SHARED_LAYOUTS", items = withMatches(shared) }
    return sections, party
end

-- Lays out the list and returns the item for the selected house.
local function PopulateList(sections)
    for _, fs in ipairs(lineLabels) do
        fs:Hide()
    end
    for _, row in ipairs(houseRows) do
        row:Hide()
    end

    local byGUID, firstGUID = {}, nil
    for _, sec in ipairs(sections) do
        for _, item in ipairs(sec.items) do
            byGUID[item.guid] = byGUID[item.guid] or item
            firstGUID = firstGUID or item.guid
        end
    end
    if wantGroup then
        wantGroup = false
        local first = sections[1].key == "RM_IN_GROUP" and sections[1].items[1]
        if first then
            selected = first.guid
        end
    end
    if not byGUID[selected] then
        selected = byGUID[CH.currentHouseGUID] and CH.currentHouseGUID or firstGUID
    end

    local w = FitScrollChild(listScroll, listChild, LIST_W - 20)
    local y, lineIdx, rowIdx = 0, 0, 0
    local function addLine(key, r, g, b)
        lineIdx = lineIdx + 1
        local fs = LineLabel(lineIdx)
        fs:SetText(CH.L[key])
        fs:SetTextColor(r, g, b)
        fs:SetPoint("TOPLEFT", listChild, "TOPLEFT", 4, -(y + 5))
        fs:SetPoint("RIGHT", listChild, "RIGHT", -4, 0)
        fs:Show()
        y = y + SECTION_H
    end

    for _, sec in ipairs(sections) do
        if #sec.items > 0 or sec.note then
            addLine(sec.key, CH.RGBA(CH.COLORS.muted, 1))
            if sec.note then
                addLine(sec.note, CH.RGBA(CH.COLORS.dim, 1))
            end
            for _, item in ipairs(sec.items) do
                rowIdx = rowIdx + 1
                local row = HouseRow(rowIdx)
                row.guid = item.guid
                row:SetWidth(w)
                row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
                row.label:SetText(item.label)
                row.tag:SetText(item.tag)
                row.sel:SetShown(item.guid == selected)
                row:Show()
                y = y + HOUSE_ROW_H
            end
            y = y + 4
        end
    end

    local empty = not firstGUID and lineIdx == 0
    if empty then
        listEmpty:SetText(CH.L[query == "" and "RM_NO_ROOMS_YET" or "RM_NO_MATCHES"])
    end
    listEmpty:SetShown(empty)
    listChild:SetHeight(math.max(y, 1))
    return byGUID[selected]
end

-- ─────────────────────────────────────────────────────────────────────
-- The picked house (right)
-- ─────────────────────────────────────────────────────────────────────

local detail = CreateFrame("Frame", nil, roomMgr)
detail:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", LIST_W + 22, -34)
detail:SetPoint("BOTTOMRIGHT", roomMgr, "BOTTOMRIGHT", -8, 40)

local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detailTitle:SetPoint("TOPLEFT", 0, 0)
detailTitle:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
detailTitle:SetJustifyH("LEFT")
detailTitle:SetWordWrap(false)

local detailMeta = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailMeta:SetPoint("TOPLEFT", 0, -22)
detailMeta:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local detailNote = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailNote:SetPoint("TOPLEFT", 0, -36)
detailNote:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
detailNote:SetJustifyH("LEFT")
detailNote:SetWordWrap(false)

local btnMap = CH.MakeButton(detail, "RM_MAP", 72, 22)
local btnExport = CH.MakeButton(detail, "RM_EXPORT", 72, 22)
local btnShare = CH.MakeButton(detail, "RM_SHARE", 72, 22)
local btnRequest = CH.MakeButton(detail, "RM_REQUEST", 72, 22)
local btnRemove = CH.MakeButton(detail, "RM_REMOVE", 72, 22)
local actionButtons = { btnMap, btnExport, btnShare, btnRequest, btnRemove }

local function LayoutActions()
    local prev
    for _, b in ipairs(actionButtons) do
        if b:IsShown() then
            b:ClearAllPoints()
            if prev then
                b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            else
                b:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -54)
            end
            prev = b
        end
    end
end

CH.MakeSep(detail, -82, 0.4)

local roomScroll, roomChild = CH.MakeScrollList(detail, "ChamberlainRoomScroll")
roomScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -86)
roomScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -20, 0)

local roomEmpty = roomChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
roomEmpty:SetPoint("TOPLEFT", 4, -12)
roomEmpty:SetPoint("RIGHT", roomChild, "RIGHT", -4, 0)
roomEmpty:SetJustifyH("LEFT")
roomEmpty:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

local ROW_H = 26
local rowPool = {}

local function AddZoneRow(zoneIdx, w, y, zone, houseGUID, canDelete)
    local row = rowPool[zoneIdx]
    if not row then
        row = CreateFrame("Frame", nil, roomChild)
        row:SetHeight(ROW_H)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameLabel:SetPoint("LEFT", 4, 0)
        row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.nameLabel:SetJustifyH("LEFT")
        row.nameLabel:SetWordWrap(false)

        row.delBtn = CH.MakeButton(row, "RM_DELETE", 52, 20)
        row.delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        row.editBtn = CH.MakeButton(row, "RM_EDIT", 38, 20)
        row.editBtn:SetPoint("RIGHT", row.delBtn, "LEFT", -2, 0)

        rowPool[zoneIdx] = row
    end

    row:SetWidth(w)
    row:SetPoint("TOPLEFT", roomChild, "TOPLEFT", 0, -y)
    row:Show()
    row.bg:SetColorTexture(0, 0, 0, zoneIdx % 2 == 0 and 0.18 or 0)
    row.nameLabel:SetText(string.format(CH.L["FMT_NAME_DIM_X"], zone.name, CH.ZoneDimText(zone)))

    if canDelete then
        row.delBtn:Show()
        row.delBtn:SetScript("OnClick", function()
            local house = ChamberlainDB.houses[houseGUID]
            if house then
                local removed = table.remove(house.zones, zoneIdx)
                CH.DropZoneStats(house, removed and removed.name)
                CH.TouchHouse(houseGUID)
            end
        end)
        row.editBtn:Show()
        row.editBtn:SetScript("OnClick", function()
            CH.OpenRenameDialog(zone, houseGUID)
        end)
    else
        row.delBtn:Hide()
        row.editBtn:Hide()
    end

    return y + ROW_H
end

-- Per-house Request debounce: after a click the button stays disabled this many
-- seconds, kept across list repopulates so it can't be spammed.
local REQUEST_COOLDOWN = 5
local requestCooldowns = {}
local shareBusy = false

function CH.RequestCooling(guid)
    return requestCooldowns[guid] ~= nil and GetTime() - requestCooldowns[guid] < REQUEST_COOLDOWN
end

-- Also the Request on the map's house card.
function CH.RequestGroupMap(guid)
    requestCooldowns[guid] = GetTime()
    C_Timer.After(REQUEST_COOLDOWN, CH.RefreshGroupMaps)
    CH.RequestLayout(guid)
end

-- The group's best map of one house when it's one you don't have or newer than
-- yours, with status "not_owned" or "newer". nil otherwise.
function CH.GroupOffer(guid)
    for _, p in ipairs(GetPartyHouseList()) do
        if p.guid == guid then
            local status = GetStatus(guid, p.bestTimestamp)
            if status == "not_owned" or status == "newer" then
                p.status = status
                return p
            end
        end
    end
end

local function PopulateDetail(item, p)
    for _, row in ipairs(rowPool) do
        row:Hide()
    end
    local h = item and ChamberlainDB.houses[item.guid]

    detailTitle:SetText(item and item.label or "")
    detailMeta:SetText(h and string.format(CH.L["RM_ROOMS_FLOORS_X"], #item.zones, h.floorCount or 1) or "")
    local note = ""
    if p then
        note = CH.L[p.status == "newer" and "RM_GROUP_HAS_NEWER" or "RM_GROUP_HAS_MAP"]
        if p.isTransitive then
            note = note .. string.format(CH.L["RM_VIA_X"], p.bestHolder)
        end
    end
    detailNote:SetText(note)

    btnMap:SetShown(h ~= nil)
    btnExport:SetShown(h ~= nil)
    btnShare:SetShown(item and item.own or false)
    btnShare:SetEnabled(not shareBusy)
    btnRequest:SetShown(p ~= nil)
    btnRequest:SetEnabled(not (item and CH.RequestCooling(item.guid)))
    btnRemove:SetShown(h ~= nil and not item.own)
    LayoutActions()

    local w = FitScrollChild(roomScroll, roomChild, 340)
    local y = 0
    for zoneIdx, zone in ipairs(h and item.zones or {}) do
        y = AddZoneRow(zoneIdx, w, y, zone, item.guid, item.own)
    end
    roomChild:SetHeight(math.max(y, 1))

    if item and not h then
        roomEmpty:SetText(CH.L["RM_NO_MAP_YET"])
    end
    roomEmpty:SetShown(item ~= nil and not h)
end

Populate = function()
    local sections, party = BuildSections()
    local item = PopulateList(sections)
    PopulateDetail(item, item and party[item.guid])
end

btnMap:SetScript("OnClick", function()
    CH.OpenFloorPlan(selected)
end)

btnExport:SetScript("OnClick", function()
    CH.OpenExportDialog("export", selected)
end)

btnShare:SetScript("OnClick", function()
    CH.ShareAll(selected)
end)

btnRequest:SetScript("OnClick", function()
    btnRequest:Disable()
    CH.RequestGroupMap(selected)
end)

btnRemove:SetScript("OnClick", function()
    ChamberlainDB.houses[selected] = nil
    CH.RefreshGroupMaps()
end)

-- Disable the share button while a transfer is in flight so it can't be spammed
-- mid-share. Driven by the send-progress lifecycle in ShareUI (ShowSendProgress
-- on start, HideSendProgress when the queue drains or the send is aborted).
function CH.SetShareBusy(busy)
    shareBusy = busy
    btnShare:SetEnabled(not busy)
end

-- ─────────────────────────────────────────────────────────────────────
-- Public Api
-- ─────────────────────────────────────────────────────────────────────

function CH.RefreshRoomList()
    if roomMgr:IsShown() then
        Populate()
    end
end

-- The bar's Sharing button wears a dot while somebody in the group has a map
-- of the house you're standing in, one you don't have or a newer one than yours.
-- Maps of other houses can wait in the list. Also called from
-- CH.RefreshHUDMode, which runs when the house changes.
function CH.RefreshSharingDot()
    local guid = CH.currentHouseGUID
    CH.SetSharingDot(guid ~= nil and CH.GroupOffer(guid) ~= nil)
end

-- Call after a group catalog or a received map changes.
function CH.RefreshGroupMaps()
    CH.RefreshRoomList()
    CH.RefreshSharingDot()
    CH.RefreshHouseCard()
end

-- Opens on the first map your group offers, the one the Sharing dot is about.
-- With nothing on offer the pick stays where it was.
function CH.OpenRoomManager()
    wantGroup = true
    roomMgr:Show()
    roomMgr:Raise()
    Populate()
end

-- Launcher/minimap toggle: open if closed, close if already open.
function CH.ToggleRoomManager()
    if roomMgr:IsShown() then
        roomMgr:Hide()
    else
        CH.OpenRoomManager()
    end
end
