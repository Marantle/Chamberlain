local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- House fixer  (/rooms fixer)
-- ─────────────────────────────────────────────────────────────────────
-- Moving a house to another neighborhood mints a new stable key
-- (neighborhoodGUID:plotID) and the owner name on the saved entry can go stale
-- with it, so every room stays parked under the old key and the map comes up
-- blank. This lists the houses you own and lets you point one at the house you
-- are standing in now, which adopts that house's id and its owner name from the
-- housing API. Deliberately on no button anywhere: it is a repair tool, reached
-- only by the slash command.

local ROW_H = 30
local win, scroll, scrollChild, emptyLabel
local rowPool = {}

local function OwnHouses()
    local list = {}
    for guid in pairs(ChamberlainDB.myHouses or {}) do
        local h = ChamberlainDB.houses[guid]
        if h then
            list[#list + 1] = {
                guid = guid,
                owner = h.owner,
                rooms = h.zones and #h.zones or 0,
            }
        end
    end
    table.sort(list, function(a, b)
        return (a.owner or "") < (b.owner or "")
    end)
    return list
end

local Populate -- forward declaration; the row buttons call it after a repair

local function Build()
    win = CreateFrame("Frame", "ChamberlainFixHouse", UIParent, "BackdropTemplate")
    win:SetSize(400, 320)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "FIX_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainFixHouse")

    local body = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 14, -34)
    body:SetPoint("TOPRIGHT", -14, -34)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetSpacing(2)
    body:SetText(CH.L["FIX_BODY"])
    body:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

    scroll, scrollChild = CH.MakeScrollList(win, "ChamberlainFixHouseScroll")
    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -96)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 44)

    emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOP", 0, -10)
    emptyLabel:SetText(CH.L["FIX_NO_HOUSES"])
    emptyLabel:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    emptyLabel:Hide()

    local close = CH.MakeButton(win, "FIX_CLOSE", 80, 22)
    close:SetPoint("BOTTOM", win, "BOTTOM", 0, 12)
    close:SetScript("OnClick", function()
        win:Hide()
    end)
end

Populate = function()
    local list = OwnHouses()
    for _, row in ipairs(rowPool) do
        row:Hide()
    end

    local w = scroll:GetWidth() - 20
    if w <= 10 then
        w = 340
    end
    scrollChild:SetWidth(w)

    for i, data in ipairs(list) do
        local row = rowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(ROW_H)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -76, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)

            row.fixBtn = CH.MakeButton(row, "FIX_BUTTON", 68, 20)
            row.fixBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

            rowPool[i] = row
        end

        row:SetWidth(w)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Show()
        row.bg:SetColorTexture(0, 0, 0, i % 2 == 0 and 0.18 or 0)

        local name = string.format(CH.L["RM_X_HOUSE"], data.owner or CH.L["RM_HOME_INTERIOR"])
        row.label:SetText(string.format(CH.L["FIX_ROW_X"], name, data.rooms))

        -- The house you're already standing in needs no fixing.
        local guid = data.guid
        row.fixBtn:SetEnabled(guid ~= CH.currentHouseGUID)
        row.fixBtn:SetScript("OnClick", function()
            if not CH.RepairHouseKey(guid) then
                return
            end
            CH.Print(CH.L["FIX_FIXED_X"], name)
            if CH.RebuildFloorPlan then
                CH.RebuildFloorPlan()
            end
            if CH.RefreshHUDMode then
                CH.RefreshHUDMode()
            end
            if CH.RefreshMyRoomsTab then
                CH.RefreshMyRoomsTab()
            end
            if CH.RefreshToolbox then
                CH.RefreshToolbox()
            end
            if CH.QueueBroadcast then
                CH.QueueBroadcast(CH.currentHouseGUID)
            end
            Populate()
        end)
    end

    scrollChild:SetHeight(math.max(#list * ROW_H, 1))
    emptyLabel:SetShown(#list == 0)
end

-- Entry point for /rooms fixer. Requires standing in a recognized house, since the
-- whole job is adopting that house's id and owner.
function CH.OpenFixHouse()
    if not CH.currentHouseGUID then
        CH.Print(CH.L["FIX_NOT_IN_HOUSE"])
        return
    end
    -- Claiming a house you don't own would be a data mess (and a lie), so the
    -- housing API has to agree this one is yours. CH.RepairHouseKey re-checks.
    if not CH.isOwnHouse then
        CH.Print(CH.L["FIX_ONLY_OWN_HOUSE"])
        return
    end
    if not win then
        Build()
    end
    Populate()
    win:Show()
end
