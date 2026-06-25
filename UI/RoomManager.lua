local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Room manager window  (My Rooms / Party / Settings tabs)
-- ─────────────────────────────────────────────────────────────────────

local roomMgr = CreateFrame("Frame", "ChamberlainRoomManager", UIParent, "BackdropTemplate")
roomMgr:SetSize(320, 520)
roomMgr:SetFrameStrata("DIALOG")
-- See FloorPlan.lua: SetToplevel lets clicking/showing this window pull its
-- whole subtree above the Floor Plan (same strata) instead of bleeding through.
roomMgr:SetToplevel(true)
roomMgr:SetPoint("CENTER")
CH.MakeDraggable(roomMgr)
CH.SkinWindow(roomMgr, CH.L["RM_WINDOW_TITLE"])
roomMgr:Hide()
table.insert(UISpecialFrames, "ChamberlainRoomManager")

local tabMyRooms = CH.MakeButton(roomMgr, CH.L["RM_TAB_MY_ROOMS"], 90, 22)
local tabParty = CH.MakeButton(roomMgr, CH.L["RM_TAB_GROUP"], 68, 22)
local tabSettings = CH.MakeButton(roomMgr, CH.L["RM_TAB_SETTINGS"], 86, 22)
tabMyRooms:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", 8, -30)
tabParty:SetPoint("LEFT", tabMyRooms, "RIGHT", 2, 0)
tabSettings:SetPoint("LEFT", tabParty, "RIGHT", 2, 0)

local tabSep = roomMgr:CreateTexture(nil, "ARTWORK")
tabSep:SetHeight(1)
tabSep:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", 8, -54)
tabSep:SetPoint("TOPRIGHT", roomMgr, "TOPRIGHT", -8, -54)
tabSep:SetColorTexture(CH.RGBA(CH.COLORS.sep, 0.8))

local panelMyRooms = CreateFrame("Frame", nil, roomMgr)
local panelParty = CreateFrame("Frame", nil, roomMgr)
local panelSettings = CreateFrame("Frame", nil, roomMgr)
for _, p in ipairs({ panelMyRooms, panelParty, panelSettings }) do
    p:SetPoint("TOPLEFT", roomMgr, "TOPLEFT", 8, -58)
    p:SetPoint("BOTTOMRIGHT", roomMgr, "BOTTOMRIGHT", -8, 40)
    p:Hide()
end

local mgrClose = CH.MakeButton(roomMgr, CH.L["RM_CLOSE"], 80, 22)
mgrClose:SetPoint("BOTTOM", roomMgr, "BOTTOM", 0, 10)
mgrClose:SetScript("OnClick", function()
    roomMgr:Hide()
end)

-- ─────────────────────────────────────────────────────────────────────
-- My Rooms Panel
-- ─────────────────────────────────────────────────────────────────────

local ownerLabel = panelMyRooms:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ownerLabel:SetPoint("TOPLEFT", 2, -4)
ownerLabel:SetTextColor(0.75, 0.75, 0.75, 1)

CH.MakeSep(panelMyRooms, -18, 0.4)

local mgrScroll, mgrScrollChild = CH.MakeScrollList(panelMyRooms, "ChamberlainMgrScroll")
mgrScroll:SetPoint("TOPLEFT", panelMyRooms, "TOPLEFT", 0, -22)
mgrScroll:SetPoint("BOTTOMRIGHT", panelMyRooms, "BOTTOMRIGHT", -20, 26)

local btnExport = CH.MakeButton(panelMyRooms, CH.L["RM_EXPORT"], 80, 20)
btnExport:SetPoint("BOTTOMLEFT", panelMyRooms, "BOTTOM", -84, 2)
btnExport:SetScript("OnClick", function()
    CH.OpenExportDialog("export")
end)

local btnImport = CH.MakeButton(panelMyRooms, CH.L["RM_IMPORT"], 80, 20)
btnImport:SetPoint("BOTTOMLEFT", panelMyRooms, "BOTTOM", 4, 2)
btnImport:SetScript("OnClick", function()
    CH.OpenExportDialog("import")
end)

local mgrEmpty = mgrScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
mgrEmpty:SetPoint("TOP", 0, -20)
mgrEmpty:SetText(CH.L["RM_NO_ROOMS_SAVED"])
mgrEmpty:SetTextColor(0.6, 0.6, 0.6, 1)
mgrEmpty:Hide()

local ROW_H = 26
local rowPool = {}

-- Collect all zones from owned houses, grouped by house.
local function GetOwnedHouseList()
    local list = {}
    for guid, _ in pairs(ChamberlainDB.myHouses or {}) do
        local h = ChamberlainDB.houses[guid]
        if h and h.zones and #h.zones > 0 then
            list[#list + 1] = { guid = guid, owner = h.owner, realm = h.realm, zones = h.zones }
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
                local label = string.format(CH.L["RM_X_HOUSE_SHARED_X"], h.owner or CH.L["RM_UNKNOWN"])
                list[#list + 1] = { guid = guid, label = label, zones = visible }
            end
        end
    end
    table.sort(list, function(a, b)
        return a.label < b.label
    end)
    return list
end

local HEADER_H = 20
local PopulateRoomList -- forward declaration; defined below

local sharedDivider = CreateFrame("Frame", nil, mgrScrollChild)
sharedDivider:SetHeight(HEADER_H)
sharedDivider:Hide()
local sharedDividerLabel = sharedDivider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sharedDividerLabel:SetPoint("LEFT", 4, 0)
sharedDividerLabel:SetText(CH.L["RM_SHARED_LAYOUTS"])
sharedDividerLabel:SetTextColor(0.60, 0.60, 0.60, 1)

-- Headers and zone rows live in separate pools. Mixing them would hand a
-- header slot to a zone row (or vice versa) when the list composition changes.
local headerPool = {}

-- Session-only: which houses are expanded in the My Rooms list. Deliberately
-- not persisted to ChamberlainDB. Owned houses defualt open, shared houses
-- default closed, and the user's expand/collapse choices last only until the
-- next reload.
local expandedHouses = {}

local function IsHouseExpanded(guid, defaultExpanded)
    local e = expandedHouses[guid]
    if e == nil then
        return defaultExpanded
    end
    return e
end

local ICON_EXPANDED = "|TInterface\\Buttons\\UI-MinusButton-Up:14:14:0:0|t "
local ICON_COLLAPSED = "|TInterface\\Buttons\\UI-PlusButton-Up:14:14:0:0|t "

local function AddSectionHeader(hdrIdx, w, y, text, removeGUID, toggleGUID, isExpanded)
    local hdr = headerPool[hdrIdx]
    if not hdr then
        hdr = CreateFrame("Frame", nil, mgrScrollChild)
        hdr:SetHeight(HEADER_H)
        hdr:EnableMouse(true)
        hdr.hl = hdr:CreateTexture(nil, "HIGHLIGHT")
        hdr.hl:SetAllPoints()
        hdr.hl:SetColorTexture(1, 1, 1, 0.06)
        hdr.label = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr.label:SetPoint("LEFT", 4, 0)
        hdr.label:SetJustifyH("LEFT")
        hdr.label:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
        hdr.label:SetWordWrap(false)
        hdr.removeBtn = CH.MakeButton(hdr, CH.L["RM_REMOVE"], 56, 16)
        hdr.removeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
        headerPool[hdrIdx] = hdr
    end
    local prefix = ""
    if toggleGUID then
        prefix = isExpanded and ICON_EXPANDED or ICON_COLLAPSED
    end
    hdr.label:SetText(prefix .. text)
    hdr.label:SetPoint("RIGHT", hdr, "RIGHT", removeGUID and -62 or -4, 0)
    hdr:SetWidth(w)
    hdr:SetPoint("TOPLEFT", mgrScrollChild, "TOPLEFT", 0, -y)
    hdr:Show()
    if toggleGUID then
        hdr.hl:Show()
        hdr:SetScript("OnMouseUp", function()
            expandedHouses[toggleGUID] = not isExpanded
            PopulateRoomList()
        end)
    else
        hdr.hl:Hide()
        hdr:SetScript("OnMouseUp", nil)
    end
    if removeGUID then
        hdr.removeBtn:Show()
        hdr.removeBtn:SetScript("OnClick", function()
            ChamberlainDB.houses[removeGUID] = nil
            PopulateRoomList()
        end)
    else
        hdr.removeBtn:Hide()
    end
    return y + HEADER_H
end

local function AddZoneRow(rowIdx, w, y, zone, zoneIdx, houseGUID, canDelete)
    local row = rowPool[rowIdx]
    if not row then
        row = CreateFrame("Frame", nil, mgrScrollChild)
        row:SetHeight(ROW_H)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameLabel:SetPoint("LEFT", 4, 0)
        row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.nameLabel:SetJustifyH("LEFT")
        row.nameLabel:SetWordWrap(false)

        row.delBtn = CH.MakeButton(row, CH.L["RM_DELETE"], 52, 20)
        row.delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        row.editBtn = CH.MakeButton(row, CH.L["RM_EDIT"], 38, 20)
        row.editBtn:SetPoint("RIGHT", row.delBtn, "LEFT", -2, 0)

        rowPool[rowIdx] = row
    end

    row:SetWidth(w)
    row:SetPoint("TOPLEFT", mgrScrollChild, "TOPLEFT", 0, -y)
    row:Show()
    row.bg:SetColorTexture(0, 0, 0, zoneIdx % 2 == 0 and 0.18 or 0)
    row.nameLabel:SetText(string.format(CH.L["RM_ZONE_DIM_X"], zone.name, zone.maxX - zone.minX, zone.maxY - zone.minY))

    if canDelete then
        row.delBtn:Show()
        row.delBtn:SetScript("OnClick", function()
            local house = ChamberlainDB.houses[houseGUID]
            if house then
                local removed = table.remove(house.zones, zoneIdx)
                CH.DropZoneStats(house, removed and removed.name)
                house.updatedAt = GetServerTime()
                PopulateRoomList()
                if CH.RebuildFloorPlan then
                    CH.RebuildFloorPlan()
                end
                CH.QueueBroadcast(houseGUID)
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

PopulateRoomList = function()
    local owned = GetOwnedHouseList()
    local shared = GetSharedHouseList()

    local totalZones = 0
    for _, h in ipairs(owned) do
        totalZones = totalZones + #h.zones
    end
    for _, h in ipairs(shared) do
        totalZones = totalZones + #h.zones
    end

    if #owned > 0 then
        ownerLabel:SetText(CH.L["RM_YOUR_HOUSES"])
    elseif #shared > 0 then
        ownerLabel:SetText(CH.L["RM_SHARED_LAYOUTS"])
    else
        ownerLabel:SetText(CH.L["RM_NO_ROOMS_YET"])
    end

    for _, row in ipairs(rowPool) do
        row:Hide()
    end
    for _, hdr in ipairs(headerPool) do
        hdr:Hide()
    end
    sharedDivider:Hide()

    local w = mgrScroll:GetWidth() - 20
    if w <= 10 then
        w = 260
    end
    mgrScrollChild:SetWidth(w)

    local rowIdx = 0
    local hdrIdx = 0
    local y = 0

    for _, houseData in ipairs(owned) do
        -- Every owned house gets a collapsible header, open by default.
        local expanded = IsHouseExpanded(houseData.guid, true)
        hdrIdx = hdrIdx + 1
        y = AddSectionHeader(hdrIdx, w, y, houseData.label, nil, houseData.guid, expanded)
        if expanded then
            for zoneIdx, zone in ipairs(houseData.zones) do
                rowIdx = rowIdx + 1
                y = AddZoneRow(rowIdx, w, y, zone, zoneIdx, houseData.guid, true)
            end
        end
    end

    if #shared > 0 then
        -- The divider is a separator beneath your own houses. With no owned
        -- houses above it the panel's top label already reads "Shared layouts",
        -- so showing it here would just duplicate that.
        if #owned > 0 then
            sharedDivider:SetWidth(w)
            sharedDivider:SetPoint("TOPLEFT", mgrScrollChild, "TOPLEFT", 0, -y)
            sharedDivider:Show()
            y = y + HEADER_H
        end

        for _, houseData in ipairs(shared) do
            -- Shared (not-owned) houses default to collapsed on each reload.
            local expanded = IsHouseExpanded(houseData.guid, false)
            hdrIdx = hdrIdx + 1
            y = AddSectionHeader(hdrIdx, w, y, houseData.label, houseData.guid, houseData.guid, expanded)
            if expanded then
                for zoneIdx, zone in ipairs(houseData.zones) do
                    rowIdx = rowIdx + 1
                    y = AddZoneRow(rowIdx, w, y, zone, zoneIdx, houseData.guid, false)
                end
            end
        end
    end

    mgrScrollChild:SetHeight(math.max(y, 1))
    mgrEmpty:SetShown(totalZones == 0)
end

-- ─────────────────────────────────────────────────────────────────────
-- Party Panel
-- ─────────────────────────────────────────────────────────────────────

local partySubtitle = panelParty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
partySubtitle:SetPoint("TOPLEFT", 2, -4)
partySubtitle:SetTextColor(0.75, 0.75, 0.75, 1)

CH.MakeSep(panelParty, -18, 0.4)

local partyScroll, partyScrollChild = CH.MakeScrollList(panelParty, "ChamberlainPartyScroll")
partyScroll:SetPoint("TOPLEFT", panelParty, "TOPLEFT", 0, -22)
partyScroll:SetPoint("BOTTOMRIGHT", panelParty, "BOTTOMRIGHT", -20, 30)

local partyEmpty = partyScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
partyEmpty:SetPoint("TOP", 0, -20)
partyEmpty:SetText(CH.L["RM_NO_LAYOUTS_FROM_GROUP"])
partyEmpty:SetTextColor(0.6, 0.6, 0.6, 1)
partyEmpty:Hide()

local shareAllBtn = CH.MakeButton(panelParty, CH.L["RM_SHARE_MY_HOUSES"], 120, 22)
shareAllBtn:SetPoint("BOTTOM", panelParty, "BOTTOM", 0, 4)
shareAllBtn:SetScript("OnClick", function()
    CH.ShareAll()
end)

local PARTY_ROW_H = 34
local partyRowPool = {}

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

local function PopulatePartyList()
    local list = GetPartyHouseList()
    local count = #list

    if not IsInGroup() then
        partySubtitle:SetText(CH.L["RM_NOT_IN_GROUP"])
    elseif count == 0 then
        partySubtitle:SetText(CH.L["RM_NO_MEMBERS_HAVE_ADDON"])
    else
        partySubtitle:SetText(
            string.format(count == 1 and CH.L["RM_N_HOUSE_AVAILABLE_X"] or CH.L["RM_N_HOUSES_AVAILABLE_X"], count)
        )
    end

    for _, row in ipairs(partyRowPool) do
        row:Hide()
    end

    local w = partyScroll:GetWidth() - 20
    if w <= 10 then
        w = 260
    end
    partyScrollChild:SetWidth(w)

    for i, data in ipairs(list) do
        local row = partyRowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, partyScrollChild)
            row:SetHeight(PARTY_ROW_H)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameLabel:SetPoint("TOPLEFT", 4, -4)
            row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -68, 0)
            row.nameLabel:SetJustifyH("LEFT")
            row.nameLabel:SetWordWrap(false)

            row.statusLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.statusLabel:SetPoint("BOTTOMLEFT", 4, 4)

            row.reqBtn = CH.MakeButton(row, CH.L["RM_REQUEST"], 62, 20)
            row.reqBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

            partyRowPool[i] = row
        end

        row:SetWidth(w)
        row:SetPoint("TOPLEFT", partyScrollChild, "TOPLEFT", 0, -(i - 1) * PARTY_ROW_H)
        row:Show()
        row.bg:SetColorTexture(0, 0, 0, i % 2 == 0 and 0.18 or 0)

        local displayName = string.format(CH.L["RM_X_HOUSE"], data.owner)
        if data.isTransitive then
            displayName = displayName .. string.format(CH.L["RM_VIA_X"], data.bestHolder)
        end
        row.nameLabel:SetText(displayName)

        local status = GetStatus(data.guid, data.bestTimestamp)
        if status == "own" then
            row.statusLabel:SetText(CH.L["RM_STATUS_YOUR_HOUSE"])
            row.reqBtn:Disable()
        elseif status == "not_owned" then
            row.statusLabel:SetText(CH.L["RM_STATUS_NOT_OWNED"])
            row.reqBtn:Enable()
        elseif status == "newer" then
            row.statusLabel:SetText(CH.L["RM_STATUS_NEWER_AVAILABLE"])
            row.reqBtn:Enable()
        else
            row.statusLabel:SetText(CH.L["RM_STATUS_UP_TO_DATE"])
            row.reqBtn:Disable()
        end

        local guid = data.guid
        row.reqBtn:SetScript("OnClick", function()
            CH.RequestLayout(guid)
        end)
    end

    partyScrollChild:SetHeight(math.max(count * PARTY_ROW_H, 1))
    partyEmpty:SetShown(count == 0)
end

-- ─────────────────────────────────────────────────────────────────────
-- Settings Panel
-- ─────────────────────────────────────────────────────────────────────

CH.MakeSectionHeader(panelSettings, CH.L["RM_SECTION_SHARING"], -6)

local shareToggle = CH.MakeToggleButton(panelSettings, CH.L["RM_TOGGLE_SHARING"], "shareEnabled")
shareToggle:SetPoint("TOPLEFT", 4, -22)

local soundToggle = CH.MakeToggleButton(panelSettings, CH.L["RM_TOGGLE_ENTRY_SOUND"], "entrySound")
soundToggle:SetPoint("TOPLEFT", 4, -46)

local roomTextToggle = CH.MakeToggleButton(panelSettings, CH.L["RM_TOGGLE_ROOM_DESCRIPTIONS"], "showRoomText")
roomTextToggle:SetPoint("TOPLEFT", 4, -70)

-- Banner fade-out: seconds before the room banner fades after it appears. 0 keeps
-- it up until you leave the room.
local bannerTimeoutLabel = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bannerTimeoutLabel:SetPoint("TOPLEFT", 8, -98)
bannerTimeoutLabel:SetText(CH.L["RM_BANNER_FADE_OUT"])

local bannerSlider = CH.MakeSlider(panelSettings, 120, 0, 20, 1)
bannerSlider:SetPoint("LEFT", bannerTimeoutLabel, "RIGHT", 12, 0)

local bannerTimeoutVal = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bannerTimeoutVal:SetPoint("LEFT", bannerSlider, "RIGHT", 10, 0)
bannerTimeoutVal:SetTextColor(0.75, 0.75, 0.75, 1)

local function UpdateBannerTimeoutLabel(v)
    bannerTimeoutVal:SetText(v <= 0 and CH.L["RM_BANNER_OFF_STAYS"] or string.format(CH.L["RM_SECONDS_X"], v))
end

bannerSlider:SetScript("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ChamberlainDB.settings.bannerTimeout = value
    UpdateBannerTimeoutLabel(value)
end)

CH.MakeSep(panelSettings, -120)
CH.MakeSectionHeader(panelSettings, CH.L["RM_SECTION_ROOM_NARRATION"], -126)

-- When on, your personal voices read rooms shared to you that carry no voice
-- (your own rooms always use the per-room voice you set in the room dialog).
local voiceToggle = CH.MakeToggleButton(panelSettings, CH.L["RM_TOGGLE_USE_DEFAULT_VOICES"], "voiceDefaultsEnabled")
voiceToggle:SetPoint("TOPLEFT", 4, -142)

local femLabel = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
femLabel:SetPoint("TOPLEFT", 8, -172)
femLabel:SetText(CH.L["RM_FEMININE"])

local femVoice = CH.MakeVoiceDropdown(panelSettings, 150, CH.L["RM_VOICE_NONE"], function()
    return ChamberlainDB.settings.voiceFemale
end, function(n)
    ChamberlainDB.settings.voiceFemale = n
end)
femVoice:SetPoint("TOPLEFT", 84, -168)

local femTest = CH.MakeButton(panelSettings, CH.L["RM_TEST"], 44, 20)
femTest:SetPoint("LEFT", femVoice, "RIGHT", 6, 0)
femTest:SetScript("OnClick", function()
    local v = ChamberlainDB.settings.voiceFemale
    if v then
        CH.Speak(CH.L["RM_VOICE_TEST_FEMININE"], v)
    else
        CH.Print(CH.L["RM_PICK_FEMININE_FIRST"])
    end
end)

local malLabel = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
malLabel:SetPoint("TOPLEFT", 8, -198)
malLabel:SetText(CH.L["RM_MASCULINE"])

local malVoice = CH.MakeVoiceDropdown(panelSettings, 150, CH.L["RM_VOICE_NONE"], function()
    return ChamberlainDB.settings.voiceMale
end, function(n)
    ChamberlainDB.settings.voiceMale = n
end)
malVoice:SetPoint("TOPLEFT", 84, -194)

local malTest = CH.MakeButton(panelSettings, CH.L["RM_TEST"], 44, 20)
malTest:SetPoint("LEFT", malVoice, "RIGHT", 6, 0)
malTest:SetScript("OnClick", function()
    local v = ChamberlainDB.settings.voiceMale
    if v then
        CH.Speak(CH.L["RM_VOICE_TEST_MASCULINE"], v)
    else
        CH.Print(CH.L["RM_PICK_MASCULINE_FIRST"])
    end
end)

local voiceNote = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
voiceNote:SetPoint("TOPLEFT", 8, -222)
voiceNote:SetPoint("RIGHT", panelSettings, "RIGHT", -8, 0)
voiceNote:SetJustifyH("LEFT")
voiceNote:SetWordWrap(true)
voiceNote:SetText(CH.L["RM_VOICE_NOTE"])
voiceNote:SetTextColor(0.6, 0.6, 0.6, 1)

CH.MakeSep(panelSettings, -278)
CH.MakeSectionHeader(panelSettings, CH.L["RM_SECTION_TRUSTED_BLOCKED"], -284)

local blockDesc = panelSettings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
blockDesc:SetPoint("TOPLEFT", 4, -300)
blockDesc:SetText(CH.L["RM_TRUST_BLOCK_DESC"])
blockDesc:SetTextColor(0.75, 0.75, 0.75, 1)

local blockScroll, blockScrollChild = CH.MakeScrollList(panelSettings, "ChamberlainBlockScroll")
blockScroll:SetPoint("TOPLEFT", panelSettings, "TOPLEFT", 0, -316)
blockScroll:SetPoint("BOTTOMRIGHT", panelSettings, "BOTTOMRIGHT", -20, 0)

local blockEmpty = blockScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
blockEmpty:SetPoint("TOP", 0, -12)
blockEmpty:SetText(CH.L["RM_NO_TRUST_OR_BLOCKS"])
blockEmpty:SetTextColor(0.6, 0.6, 0.6, 1)
blockEmpty:Hide()

local BLOCK_ROW_H = 22
local blockRowPool = {}

local function PopulateBlockList()
    for _, row in ipairs(blockRowPool) do
        row:Hide()
    end

    local entries = {}
    local blocks = ChamberlainDB.blocks
    for playerName, _ in pairs(ChamberlainDB.trusted or {}) do
        entries[#entries + 1] = { kind = "trusted", key = playerName, label = playerName }
    end
    for guid, ownerOrBool in pairs(blocks.houses) do
        local label = type(ownerOrBool) == "string" and string.format(CH.L["RM_X_HOUSE"], ownerOrBool)
            or CH.L["RM_UNKNOWN_HOUSE"]
        entries[#entries + 1] = { kind = "house", key = guid, label = label }
    end
    for playerName, _ in pairs(blocks.players) do
        entries[#entries + 1] = { kind = "player", key = playerName, label = playerName }
    end
    table.sort(entries, function(a, b)
        return a.label < b.label
    end)

    local w = blockScroll:GetWidth() - 20
    if w <= 10 then
        w = 260
    end
    blockScrollChild:SetWidth(w)

    for i, entry in ipairs(entries) do
        local row = blockRowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, blockScrollChild)
            row:SetHeight(BLOCK_ROW_H)

            row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameLabel:SetPoint("LEFT", 4, 0)
            row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -72, 0)
            row.nameLabel:SetJustifyH("LEFT")
            row.nameLabel:SetWordWrap(false)

            row.kindLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.kindLabel:SetPoint("RIGHT", row, "RIGHT", -62, 0)

            row.unblockBtn = CH.MakeButton(row, CH.L["RM_UNBLOCK"], 58, 18)
            row.unblockBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

            blockRowPool[i] = row
        end

        row:SetWidth(w)
        row:SetPoint("TOPLEFT", blockScrollChild, "TOPLEFT", 0, -(i - 1) * BLOCK_ROW_H)
        row:Show()
        row.nameLabel:SetText(entry.label)
        local kindText = entry.kind == "house" and CH.L["RM_KIND_HOUSE"]
            or entry.kind == "trusted" and CH.L["RM_KIND_TRUSTED"]
            or CH.L["RM_KIND_PLAYER"]
        row.kindLabel:SetText(kindText)
        row.unblockBtn:SetText(entry.kind == "trusted" and CH.L["RM_UNTRUST"] or CH.L["RM_UNBLOCK"])

        local kind, key = entry.kind, entry.key
        row.unblockBtn:SetScript("OnClick", function()
            if kind == "house" then
                ChamberlainDB.blocks.houses[key] = nil
            elseif kind == "trusted" then
                ChamberlainDB.trusted[key] = nil
            else
                ChamberlainDB.blocks.players[key] = nil
            end
            PopulateBlockList()
        end)
    end

    blockScrollChild:SetHeight(math.max(#entries * BLOCK_ROW_H, 1))
    blockEmpty:SetShown(#entries == 0)
end

local function RefreshSettingsTab()
    shareToggle:Refresh()
    soundToggle:Refresh()
    roomTextToggle:Refresh()
    voiceToggle:Refresh()
    femVoice:Refresh()
    malVoice:Refresh()
    local timeout = ChamberlainDB.settings.bannerTimeout or 0
    bannerSlider:SetValue(timeout)
    UpdateBannerTimeoutLabel(timeout)
    PopulateBlockList()
end

-- ─────────────────────────────────────────────────────────────────────
-- Tab Switching
-- ─────────────────────────────────────────────────────────────────────

local activeTab = nil

local function ShowTab(tab)
    if activeTab == tab then
        return
    end
    activeTab = tab
    panelMyRooms:SetShown(tab == "myrooms")
    panelParty:SetShown(tab == "party")
    panelSettings:SetShown(tab == "settings")
    tabMyRooms:SetEnabled(tab ~= "myrooms")
    tabParty:SetEnabled(tab ~= "party")
    tabSettings:SetEnabled(tab ~= "settings")
    if tab == "myrooms" then
        PopulateRoomList()
    end
    if tab == "party" then
        PopulatePartyList()
    end
    if tab == "settings" then
        RefreshSettingsTab()
    end
end

tabMyRooms:SetScript("OnClick", function()
    ShowTab("myrooms")
end)
tabParty:SetScript("OnClick", function()
    ShowTab("party")
end)
tabSettings:SetScript("OnClick", function()
    ShowTab("settings")
end)

-- ─────────────────────────────────────────────────────────────────────
-- Public Api
-- ─────────────────────────────────────────────────────────────────────

CH.RefreshMyRoomsTab = function()
    if activeTab == "myrooms" then
        PopulateRoomList()
    end
end

CH.RefreshPartyTab = function()
    if activeTab == "party" then
        PopulatePartyList()
    end
end

-- Exposed so the trust list refreshes when "Always accept from X" is ticked.
CH.RefreshSettingsTab = function()
    if activeTab == "settings" then
        RefreshSettingsTab()
    end
end

function CH.OpenRoomManager()
    roomMgr:Show()
    roomMgr:Raise()
    ShowTab(activeTab or "myrooms")
end
