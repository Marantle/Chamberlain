local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan window  (top-down view of the current house)
-- ─────────────────────────────────────────────────────────────────────

local PADDING = 24

local PALETTE = {
    { 0.40, 0.70, 1.00 },
    { 0.40, 1.00, 0.65 },
    { 1.00, 0.80, 0.25 },
    { 1.00, 0.45, 0.45 },
    { 0.75, 0.45, 1.00 },
    { 0.35, 1.00, 1.00 },
    { 1.00, 0.65, 0.25 },
    { 0.65, 1.00, 0.35 },
}

local fp = CreateFrame("Frame", "ChamberlainFloorPlan", UIParent, "BackdropTemplate")
fp:SetSize(420, 514)
fp:SetFrameStrata("DIALOG")
-- Floor Plan and the Room Manager share the DIALOG strata and overlap. Without
-- this, the other window's child buttons (a higher frame level) bleed through
-- this one's background. SetToplevel makes clicking/showing a window lift its
-- whole subtree above the other.
fp:SetToplevel(true)
fp:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
CH.MakeDraggable(fp)
CH.SkinWindow(fp, "FP_TITLE", true)
fp:Hide()
table.insert(UISpecialFrames, "ChamberlainFloorPlan")

local fpSub = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpSub:SetPoint("TOPLEFT", 10, -27)
fpSub:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

local canvas = CreateFrame("Frame", nil, fp)
canvas:SetPoint("TOPLEFT", fp, "TOPLEFT", 10, -40)
canvas:SetPoint("BOTTOMRIGHT", fp, "BOTTOMRIGHT", -10, 124)

local canvasBg = canvas:CreateTexture(nil, "BACKGROUND")
canvasBg:SetAllPoints()
canvasBg:SetColorTexture(0.025, 0.02, 0.015, 1)

local fpEmpty = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpEmpty:SetPoint("CENTER")
fpEmpty:SetText(CH.L["FP_NO_ROOMS"])
fpEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
fpEmpty:Hide()

local fpClose = CH.MakeButton(fp, "FP_CLOSE", 80, 22)
-- Bottom-right so it never collides with the Add floor / Add stairs buttons that
-- sit at the bottom-left for your own house.
fpClose:SetPoint("BOTTOMRIGHT", fp, "BOTTOMRIGHT", -10, 10)
fpClose:SetScript("OnClick", function()
    fp:Hide()
end)

-- Edit panel: click a room on the canvas to select it, then move or resize
-- it a yard at a time. Own house only.
local selectedIdx = nil
local BuildFloorPlan -- forward declaration; the edit buttons rebuild the map

-- Which floor the map is currently showing. Starts on the player's active floor
-- and follows it up and down the stairs. The +/- arrows browse other floors.
-- Exposed so the create dialog can default a new room to the floor you're viewing.
local viewedFloor = 1
CH.fpViewedFloor = 1

-- An anchor is a stair-link zone, drawn with a distinct border and an arrow glyph.
local function FPIsAnchor(zone)
    return zone.setFloor ~= nil or zone.floorDelta ~= nil
end

local function AnchorGlyph(zone)
    if zone.floorDelta == 1 then
        return "|cff66ddff^|r "
    elseif zone.floorDelta == -1 then
        return "|cff66ddffv|r "
    elseif zone.setFloor then
        return "|cff66ddff#|r "
    end
    return ""
end

-- Floor navigation row, top-right of the window. Hidden on single-floor houses.
local function CurrentHouse()
    return CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
end

local floorHeader = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
floorHeader:SetPoint("TOPRIGHT", fp, "TOPRIGHT", -62, -27)
floorHeader:SetTextColor(0.85, 0.78, 0.55, 1)

local floorUp = CH.MakeButton(fp, "+", 20, 18)
local floorDown = CH.MakeButton(fp, "-", 20, 18)
floorUp:SetPoint("RIGHT", fp, "TOPRIGHT", -10, -36)
floorDown:SetPoint("RIGHT", floorUp, "LEFT", -2, 0)
floorHeader:SetPoint("RIGHT", floorDown, "LEFT", -6, 0)

-- Override: when you're browsing a floor you're not standing on, this tells
-- Chamberlain you've actually moved there. Shown only when the viewed floor and
-- the active floor disagree.
local moveBtn = CH.MakeButton(fp, "FP_MOVE_HERE", 110, 18)
moveBtn:SetPoint("TOPRIGHT", floorUp, "BOTTOMRIGHT", 0, -4)
moveBtn:Hide()
moveBtn:SetScript("OnClick", function()
    CH.SetActiveFloor(viewedFloor)
end)

-- These three sit over the canvas's top-right corner, which is mouse-enabled and
-- clips its children. Without lifting them above the canvas (as resetBtn does),
-- the canvas swallows their clicks even though they draw on top. moveBtn sits
-- fully inside the canvas region. The +/- buttons overlap its top edge.
floorUp:SetFrameLevel(canvas:GetFrameLevel() + 20)
floorDown:SetFrameLevel(canvas:GetFrameLevel() + 20)
moveBtn:SetFrameLevel(canvas:GetFrameLevel() + 20)

-- Floor / stair management lives at the bottom-left, own house only.
local addFloorBtn = CH.MakeButton(fp, "FP_ADD_FLOOR", 76, 22)
addFloorBtn:SetPoint("BOTTOMLEFT", fp, "BOTTOMLEFT", 10, 10)
addFloorBtn:Hide()

local removeFloorBtn = CH.MakeButton(fp, "FP_REMOVE_FLOOR", 86, 22)
removeFloorBtn:SetPoint("LEFT", addFloorBtn, "RIGHT", 4, 0)
removeFloorBtn:Hide()
removeFloorBtn:SetScript("OnClick", function()
    if CH.RemoveTopFloor then
        CH.RemoveTopFloor()
    end
end)

-- Stairs are placed from the HUD (where you stand); the floor plan only manages
-- structure (floors) and the map view, so the only stair control here is whether
-- they're drawn. Checked by default, and the setting persists.
local stairsCheck = CreateFrame("CheckButton", nil, fp, "UICheckButtonTemplate")
stairsCheck:SetSize(22, 22)
stairsCheck:SetPoint("LEFT", removeFloorBtn, "RIGHT", 16, 0)
local stairsCheckLabel = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stairsCheckLabel:SetPoint("LEFT", stairsCheck, "RIGHT", 2, 0)
stairsCheckLabel:SetText(CH.L["FP_SHOW_STAIRS"])
stairsCheck:Hide()
stairsCheckLabel:Hide()
stairsCheck:SetScript("OnClick", function(self)
    ChamberlainDB.settings.showStairsOnMap = self:GetChecked() and true or false
    BuildFloorPlan()
end)
stairsCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(CH.L["FP_SHOW_STAIRS_TT_TITLE"], unpack(CH.COLORS.tipGold))
    GameTooltip:AddLine(CH.L["FP_SHOW_STAIRS_TT_BODY"], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
stairsCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function SetViewedFloor(n)
    local h = CurrentHouse()
    local count = (h and h.floorCount) or 1
    viewedFloor = math.max(1, math.min(count, n))
    CH.fpViewedFloor = viewedFloor
    selectedIdx = nil -- a selection on the old floor would no longer be visible
    BuildFloorPlan()
end

floorUp:SetScript("OnClick", function()
    SetViewedFloor(viewedFloor + 1)
end)
floorDown:SetScript("OnClick", function()
    SetViewedFloor(viewedFloor - 1)
end)

addFloorBtn:SetScript("OnClick", function()
    local h = CurrentHouse()
    if not h or not CH.isOwnHouse then
        return
    end
    h.floorCount = (h.floorCount or 1) + 1
    h.updatedAt = GetServerTime()
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end -- reveal the HUD's Add stairs button
    if CH.MaybeShowFloorIntro then
        CH.MaybeShowFloorIntro()
    end
    SetViewedFloor(h.floorCount) -- jump to the new top floor
end)

-- Actually delete the top floor: every zone on it, plus any stair anchor that
-- links to it (the anchor's other landing sits a floor below and would otherwise
-- dangle). Floors below keep their numbers, so nothing has to be renumbered.
local DoRemoveTopFloor -- forward declaration; the confirm dialog calls it

-- Confirm dialog for removing a populated top floor. Custom-skinned to match the
-- rest of the addon rather than a Blizzard StaticPopup.
local removeConfirm
local function ShowRemoveConfirm(msg)
    if not removeConfirm then
        removeConfirm = CreateFrame("Frame", "ChamberlainRemoveFloorConfirm", UIParent, "BackdropTemplate")
        removeConfirm:SetSize(380, 200)
        removeConfirm:SetFrameStrata("FULLSCREEN_DIALOG")
        removeConfirm:SetToplevel(true)
        removeConfirm:SetPoint("CENTER")
        CH.MakeDraggable(removeConfirm)
        CH.SkinWindow(removeConfirm, "FP_REMOVE_FLOOR_TITLE", true)
        local body = removeConfirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", 18, -38)
        body:SetPoint("TOPRIGHT", -18, -38)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(3)
        removeConfirm.body = body
        local yes = CH.MakeButton(removeConfirm, "FP_REMOVE_ANYWAY", 130, 24)
        yes:SetPoint("BOTTOMRIGHT", removeConfirm, "BOTTOM", -4, 12)
        yes:SetScript("OnClick", function()
            removeConfirm:Hide()
            DoRemoveTopFloor()
        end)
        local no = CH.MakeButton(removeConfirm, "FP_CANCEL", 90, 24)
        no:SetPoint("BOTTOMLEFT", removeConfirm, "BOTTOM", 4, 12)
        no:SetScript("OnClick", function()
            removeConfirm:Hide()
        end)
    end
    removeConfirm.body:SetText(msg)
    removeConfirm:Show()
end

DoRemoveTopFloor = function()
    local h = CurrentHouse()
    if not h or not CH.isOwnHouse then
        return
    end
    local count = h.floorCount or 1
    if count <= 1 then
        return
    end
    for i = #h.zones, 1, -1 do
        local z = h.zones[i]
        if (z.floor or 1) == count or z.setFloor == count or z.fromFloor == count then
            local removed = table.remove(h.zones, i)
            CH.DropZoneStats(h, removed and removed.name)
        end
    end
    h.floorCount = count - 1
    h.updatedAt = GetServerTime()
    if (CH.activeFloor or 1) > h.floorCount and CH.SetActiveFloor then
        CH.SetActiveFloor(h.floorCount)
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    SetViewedFloor(math.min(viewedFloor, h.floorCount))
    CH.Print(CH.L["FP_REMOVED_FLOOR_X"], count)
end

-- Entry from the Remove floor button. Removes only the top floor. An empty one
-- goes quietly, a populated one asks first.
function CH.RemoveTopFloor()
    local h = CurrentHouse()
    if not h or not CH.isOwnHouse then
        return
    end
    local count = h.floorCount or 1
    if count <= 1 then
        return
    end -- can't remove the only floor

    local onTop = 0
    for _, z in ipairs(h.zones or {}) do
        if (z.floor or 1) == count then
            onTop = onTop + 1
        end
    end

    if onTop > 0 then
        local fmt = onTop == 1 and CH.L["FP_REMOVE_CONFIRM_ONE_X"] or CH.L["FP_REMOVE_CONFIRM_MANY_X"]
        ShowRemoveConfirm(string.format(fmt, count, onTop, count - 1, count))
    else
        DoRemoveTopFloor()
    end
end

local editPanel = CreateFrame("Frame", nil, fp)
editPanel:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -4)
editPanel:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", 0, -4)
editPanel:SetHeight(80)
editPanel:Hide()

local editName = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
editName:SetPoint("TOPLEFT", 4, 0)

local editHint = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
editHint:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 4, -8)
editHint:SetText(CH.L["FP_EDIT_HINT"])
editHint:SetTextColor(0.5, 0.5, 0.5, 1)
editHint:Hide()

local STEP = 0.5 -- yards per button click

local function AdjustSelected(dMinX, dMaxX, dMinY, dMaxY)
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local zone = h and selectedIdx and h.zones[selectedIdx]
    if not zone then
        return
    end
    if zone.shape == "circle" then
        -- Circles ignore direction. A Move button (both bounds of an axis) shifts the
        -- centre. A Grow/Shrink button changes the radius, kept centred and square so
        -- it stays a true circle.
        if dMinX == dMaxX and dMinY == dMaxY then
            zone.minX, zone.maxX = zone.minX + dMinX * STEP, zone.maxX + dMaxX * STEP
            zone.minY, zone.maxY = zone.minY + dMinY * STEP, zone.maxY + dMaxY * STEP
        else
            local cx = (zone.minX + zone.maxX) * 0.5
            local cy = (zone.minY + zone.maxY) * 0.5
            local grow = (dMaxX - dMinX) + (dMaxY - dMinY) > 0
            local r = (zone.maxX - zone.minX) * 0.5 + (grow and STEP or -STEP)
            if r < 0.5 then
                return
            end
            zone.minX, zone.maxX = cx - r, cx + r
            zone.minY, zone.maxY = cy - r, cy + r
        end
    else
        local minX, maxX = zone.minX + dMinX * STEP, zone.maxX + dMaxX * STEP
        local minY, maxY = zone.minY + dMinY * STEP, zone.maxY + dMaxY * STEP
        if maxX - minX < 1 or maxY - minY < 1 then
            return
        end -- keep at least 1 yd
        zone.minX, zone.maxX = minX, maxX
        zone.minY, zone.maxY = minY, maxY
    end
    h.updatedAt = GetServerTime()
    BuildFloorPlan()
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.RefreshToolbox then
        CH.RefreshToolbox() -- keep the toolbox's size readout in step
    end
    if CH.SyncAnchorLatch then
        CH.SyncAnchorLatch() -- nudging a stair box onto us shouldn't fire a transition
    end
end

-- Buttons work in screen space. The map's X axis is mirrored, so screen-left
-- is world +X, screen-up is world +Y. Each entry: label, dMinX, dMaxX, dMinY, dMaxY.
local function MakeAdjustRow(label, yOff, deltas)
    local fsLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fsLabel:SetPoint("TOPLEFT", 4, yOff - 5)
    fsLabel:SetText(label)
    local x = 56
    for _, d in ipairs(deltas) do
        local b = CH.MakeButton(editPanel, d[1], 26, 18)
        b:SetPoint("TOPLEFT", editPanel, "TOPLEFT", x, yOff)
        b:SetScript("OnClick", function()
            AdjustSelected(d[2], d[3], d[4], d[5])
        end)
        x = x + 28
    end
end

MakeAdjustRow(CH.L["FP_MOVE"], -14, {
    { "<", 1, 1, 0, 0 },
    { "^", 0, 0, 1, 1 },
    { "v", 0, 0, -1, -1 },
    { ">", -1, -1, 0, 0 },
})
MakeAdjustRow(CH.L["FP_GROW"], -36, {
    { "<", 0, 1, 0, 0 },
    { "^", 0, 0, 0, 1 },
    { "v", 0, 0, -1, 0 },
    { ">", -1, 0, 0, 0 },
})
MakeAdjustRow(CH.L["FP_SHRINK"], -58, {
    { "<", 0, -1, 0, 0 },
    { "^", 0, 0, 0, -1 },
    { "v", 0, 0, 1, 0 },
    { ">", 1, 0, 0, 0 },
})

local function SelectedZone()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    return h and selectedIdx and h.zones[selectedIdx], h
end

local btnEdit = CH.MakeButton(editPanel, "FP_EDIT", 62, 18)
btnEdit:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", -2, -14)
btnEdit:SetScript("OnClick", function()
    local zone = SelectedZone()
    if zone then
        CH.OpenRenameDialog(zone, CH.currentHouseGUID)
    end
end)

local btnDelete = CH.MakeButton(editPanel, "FP_DELETE", 62, 18)
btnDelete:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", -2, -36)
btnDelete:SetScript("OnClick", function()
    local zone, h = SelectedZone()
    if not zone or not h then
        return
    end
    table.remove(h.zones, selectedIdx)
    CH.DropZoneStats(h, zone.name)
    CH.SetSelection(nil, nil) -- clear it on the toolbox too, then rebuild
    CH.TouchHouse(CH.currentHouseGUID)
end)

local function RefreshEditPanel()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local zone = CH.isOwnHouse and h and selectedIdx and h.zones[selectedIdx]
    if zone then
        editName:SetText(string.format(CH.L["FMT_NAME_DIM_X"], zone.name, CH.ZoneDimText(zone)))
        editPanel:Show()
        editHint:Hide()
    else
        editPanel:Hide()
        editHint:SetShown(CH.isOwnHouse and h ~= nil and h.zones ~= nil and #h.zones > 0)
    end
end

-- Zone frame pool: each entry has a fill texture, border texture, and label
local zonePool = {}

-- Zone indices whose rectangle is under the cursor, topmost first (later frames
-- draw on top). Used to cycle selection through overlapping rooms.
local function ZonesAtCursor()
    local cx, cy = GetCursorPosition()
    local s = canvas:GetEffectiveScale()
    if not s or s == 0 then
        return {}
    end
    cx, cy = cx / s, cy / s
    local hits = {}
    for i = #zonePool, 1, -1 do
        local f = zonePool[i]
        if f:IsShown() and f.zoneIdx then
            local l, b, w, ht = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
            if l and b and cx >= l and cx <= l + w and cy >= b and cy <= b + ht then
                hits[#hits + 1] = f.zoneIdx
            end
        end
    end
    return hits
end

-- Fill GameTooltip with a room's name, dimensions, and dwell time. Shared by the
-- hover handler and the click-to-cycle handler so both show the same room.
local function ShowZoneTooltip(owner, name, w, ht, timeSpent, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(name, r, g, b)
    GameTooltip:AddLine(string.format(CH.L["FP_DIM_X"], w, ht), 0.7, 0.7, 0.7)
    if timeSpent and timeSpent >= 1 then
        GameTooltip:AddLine(string.format(CH.L["FP_TIME_HERE_X"], CH.FormatDuration(timeSpent)), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- The visible pooled frame currently drawing a given zone index, or nil.
local function ZoneFrameByIdx(idx)
    for _, fr in pairs(zonePool) do
        if fr:IsShown() and fr.zoneIdx == idx then
            return fr
        end
    end
end

local function GetZoneFrame(i)
    if zonePool[i] then
        zonePool[i]:Show()
        return zonePool[i]
    end
    local f = CreateFrame("Frame", nil, canvas)

    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()

    f.fill = f:CreateTexture(nil, "BORDER")
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    -- A round alpha mask, off by default. Circle rooms switch it on (see
    -- SetZoneRound) so the square tile draws as a disc. The box is square for a
    -- circle, so the inscribed mask matches the room exactly.
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints(f)
    f.mask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    f.masked = false

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.label:SetAllPoints()
    f.label:SetJustifyH("CENTER")
    f.label:SetJustifyV("MIDDLE")
    f.label:SetWordWrap(false)

    -- Tooltip on hover for small rooms where text is clipped
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        -- If the highlighted room is also under the cursor, describe it rather than
        -- this (topmost) frame, so the tooltip tracks the highlight as you click
        -- through a stack. The preference has to live here, not just in the click
        -- handler: BuildFloorPlan re-shows the frames under a stationary cursor,
        -- which fires a fresh OnEnter that would otherwise overwrite the tooltip
        -- with whatever frame sits on top.
        local target = self
        if selectedIdx and selectedIdx ~= self.zoneIdx then
            for _, idx in ipairs(ZonesAtCursor()) do
                if idx == selectedIdx then
                    target = ZoneFrameByIdx(selectedIdx) or self
                    break
                end
            end
        end
        ShowZoneTooltip(
            self,
            target.zoneName,
            target.zoneW,
            target.zoneH,
            target.zoneTime,
            target.cr,
            target.cg,
            target.cb
        )
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click selects for editing. Where rooms overlap, repeated clicks cycle
    -- through every room under the cursor (topmost first), then deselect.
    f:SetScript("OnMouseDown", function(self)
        if not CH.isOwnHouse then
            return
        end
        local hits = ZonesAtCursor()
        if #hits == 0 then
            return
        end
        local pos
        for k, idx in ipairs(hits) do
            if idx == selectedIdx then
                pos = k
                break
            end
        end
        local newIdx
        if not pos then
            newIdx = hits[1]
        elseif pos < #hits then
            newIdx = hits[pos + 1] -- cycle to the next room under the cursor
        else
            newIdx = nil -- cycled past the last room: deselect
        end
        -- Route through the shared setter so the build toolbox follows along. It
        -- sets selectedIdx (via CH.FloorPlanSelect) and rebuilds.
        local house = CurrentHouse()
        CH.SetSelection(newIdx and house and house.zones[newIdx] or nil, CH.currentHouseGUID)
        -- Refresh the tooltip to the room we just cycled to (OnEnter only fires on
        -- mouse motion or a frame re-show, so a click alone wouldn't update it).
        local sel = selectedIdx and ZoneFrameByIdx(selectedIdx)
        if sel then
            ShowZoneTooltip(self, sel.zoneName, sel.zoneW, sel.zoneH, sel.zoneTime, sel.cr, sel.cg, sel.cb)
        else
            GameTooltip:Hide() -- nothing selected
        end
    end)

    zonePool[i] = f
    return f
end

-- Tintable white circle for player blips, falls back to a plain square if
-- the atlas name ever stops resolving
local BLIP_ATLAS = C_Texture.GetAtlasInfo("WhiteCircle-RaidBlips") and "WhiteCircle-RaidBlips" or nil

local function SetBlip(tex, r, g, b)
    if BLIP_ATLAS then
        tex:SetAtlas(BLIP_ATLAS)
        tex:SetVertexColor(r, g, b, 1)
    else
        tex:SetColorTexture(r, g, b, 1)
    end
end

-- Player dot: its own Frame, raised above the zone tiles so it renders on top
-- and receives the mouse for its tooltip.
local dotFrame = CreateFrame("Frame", nil, canvas)
dotFrame:SetSize(14, 14)
dotFrame:SetFrameLevel(canvas:GetFrameLevel() + 10)
dotFrame:Hide()
local dot = dotFrame:CreateTexture(nil, "OVERLAY")
dot:SetAllPoints()
SetBlip(dot, 1, 0.85, 0) -- gold
dotFrame.label = dotFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dotFrame.label:SetPoint("CENTER")
dotFrame.label:SetTextColor(0.05, 0.05, 0.05, 1)
dotFrame:EnableMouse(true)
dotFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(UnitName("player"))
    GameTooltip:Show()
end)
dotFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function MakeCornerMarker(label, r, g, b)
    local mf = CreateFrame("Frame", nil, canvas)
    mf:SetSize(9, 9)
    mf:Hide()
    local tex = mf:CreateTexture(nil, "BORDER")
    tex:SetAllPoints()
    tex:SetColorTexture(r, g, b, 0.80)
    local fs = mf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER") -- centered, not size-bound, so it never clips
    fs:SetText(label)
    fs:SetTextColor(0.05, 0.05, 0.05, 1)
    return mf
end

local markerA = MakeCornerMarker("A", 0.40, 0.90, 1.00)
local markerB = MakeCornerMarker("B", 0.40, 0.90, 1.00)

-- Party member dots: class-colored, tooltip with the member's name.
-- UnitPosition only returns coordinates for members in the same instance.
local partyDots = {}

local function GetPartyDot(i)
    if partyDots[i] then
        return partyDots[i]
    end
    local pd = CreateFrame("Frame", nil, canvas)
    pd:SetSize(14, 14)
    pd:SetFrameLevel(canvas:GetFrameLevel() + 10)
    pd:Hide()
    pd.tex = pd:CreateTexture(nil, "OVERLAY")
    pd.tex:SetAllPoints()
    pd.label = pd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pd.label:SetPoint("CENTER")
    pd.label:SetTextColor(0.05, 0.05, 0.05, 1)
    pd:EnableMouse(true)
    pd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(self.unitName or "?")
        GameTooltip:Show()
    end)
    pd:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    partyDots[i] = pd
    return pd
end

-- Transform state (set by BuildFloorPlan, used by dot update)
local trScale, trMinY, trMaxX, trCanvasH, trCanvasW

-- Forward declaration: BuildFloorPlan and TileReposition both park the resize/move
-- handles onto the selected tile after (re)laying out the map.
local PositionHandles

-- Zoom and pan layered on top of the fit-to-window transform. Only the room tiles
-- scale with zoom. Labels (fixed-size fonts) and the dots (fixed-size frames) just
-- move, so they stay the same size. Reset on house/floor change and on open.
local zoom, panX, panY = 1, 0, 0
local ZOOM_MIN, ZOOM_MAX = 1, 6
local lastBuiltGuid

-- Secret rooms show only on the owner's own floor plan. Visitors holding the
-- shared layout still get the banner on entry (the room is in thier zone list),
-- but it stays off their map.
local function ZoneVisible(zone)
    return CH.isOwnHouse or not zone.secret
end

-- X is mirrored: higher world X is left from entrance (X decreases as you move right).
local function WorldToCanvas(x, y)
    local px = PADDING + (trMaxX - x) * trScale
    local py = trCanvasH - PADDING - (y - trMinY) * trScale
    -- Zoom about the canvas centre, then pan. With zoom 1 / pan 0 this is a no-op.
    local cx, cy = (trCanvasW or 0) * 0.5, (trCanvasH or 0) * 0.5
    px = (px - cx) * zoom + cx + panX
    py = (py - cy) * zoom + cy + panY
    return px, py
end

-- The inverse of WorldToCanvas: canvas-local pixels (as CanvasCursor returns) back
-- to world yards. Used while dragging a circle's rim to read where the cursor sits.
local function CanvasToWorld(px, py)
    if not trScale or trScale == 0 then
        return 0, 0
    end
    local cx, cy = (trCanvasW or 0) * 0.5, (trCanvasH or 0) * 0.5
    local px0 = (px - cx - panX) / zoom + cx
    local py0 = (py - cy - panY) / zoom + cy
    local x = trMaxX - (px0 - PADDING) / trScale
    local y = trMinY + (trCanvasH - PADDING - py0) / trScale
    return x, y
end

-- House-wide fit: the bounding box across EVERY floor's visible zones, mapped onto
-- the canvas. Framing the whole house (not just the viewed floor) means all floors
-- render at one shared scale and origin, so switching to a floor that holds nothing
-- but a stair landing never rescales or jumps the view.
--
-- Recomputed only on explicit reframe events (open, house change, canvas resize,
-- Reset view, zone create/delete), never on a geometry edit. That decoupling is
-- the fix for the drag-resize feedback loop: while you drag a handle the transform
-- is frozen, so a room can grow past the old bounds without the map shrinking out
-- from under the cursor.
local function ComputeFit()
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    if cw <= 0 then
        cw = 400
    end
    if ch <= 0 then
        ch = 350
    end
    trCanvasW, trCanvasH = cw, ch
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h or not h.zones then
        trScale = nil
        return
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, zone in ipairs(h.zones) do
        if ZoneVisible(zone) then
            if zone.minX < minX then
                minX = zone.minX
            end
            if zone.minY < minY then
                minY = zone.minY
            end
            if zone.maxX > maxX then
                maxX = zone.maxX
            end
            if zone.maxY > maxY then
                maxY = zone.maxY
            end
        end
    end
    if minX == math.huge then -- nothing visible to frame
        trScale = nil
        return
    end
    local worldW = math.max(1, maxX - minX)
    local worldH = math.max(1, maxY - minY)
    trScale = math.min((cw - PADDING * 2) / worldW, (ch - PADDING * 2) / worldH)
    trMinY = minY
    trMaxX = maxX -- X is flipped: trMaxX becomes the left edge of the canvas
end

-- Reset-view button, shown over the map's bottom-left only while zoomed or panned.
local TileReposition -- forward declaration; the button and handlers call it

local resetBtn = CH.MakeButton(fp, "FP_RESET_ZOOM", 86, 18)
resetBtn:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 4, 4)
resetBtn:SetFrameLevel(canvas:GetFrameLevel() + 20) -- above the tiles and dots
resetBtn:Hide()
resetBtn:SetScript("OnClick", function()
    zoom, panX, panY = 1, 0, 0
    trScale = nil -- reframe to the full house, recovering any room dragged off-edge
    BuildFloorPlan()
end)

local function UpdateResetButton()
    resetBtn:SetShown(zoom ~= 1 or panX ~= 0 or panY ~= 0)
end

-- Reposition the room tiles for the current zoom/pan. The dots, corner markers and
-- player blip follow automatically through the OnUpdate transform, so only the
-- otherwise-static tiles need touching here.
TileReposition = function()
    UpdateResetButton()
    if not trScale then
        return
    end
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if not h then
        return
    end
    for _, f in pairs(zonePool) do
        if f:IsShown() and f.zoneIdx then
            local z = h.zones[f.zoneIdx]
            if z then
                local px, py = WorldToCanvas(z.maxX, z.maxY)
                local zw = (z.maxX - z.minX) * trScale * zoom
                local zh = (z.maxY - z.minY) * trScale * zoom
                if zw < 4 then
                    zw = 4
                end
                if zh < 4 then
                    zh = 4
                end
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", canvas, "TOPLEFT", px, -py)
                f:SetSize(zw, zh)
            end
        end
    end
    PositionHandles()
end

local function ClampPan()
    local limX = (trCanvasW or 0) * zoom * 0.5
    local limY = (trCanvasH or 0) * zoom * 0.5
    panX = math.max(-limX, math.min(limX, panX))
    panY = math.max(-limY, math.min(limY, panY))
end

-- Cursor in canvas-local pixels: x rightward from the left edge, y downward from
-- the top edge, matching WorldToCanvas's px / py.
local function CanvasCursor()
    local s = canvas:GetEffectiveScale()
    if not s or s == 0 then
        return 0, 0
    end
    local mx, my = GetCursorPosition()
    return mx / s - (canvas:GetLeft() or 0), (canvas:GetTop() or 0) - my / s
end

local dragging, dragSX, dragSY, panStartX, panStartY
local lastCanvasClick = 0

canvas:EnableMouse(true)
canvas:EnableMouseWheel(true)
canvas:SetClipsChildren(true) -- keep zoomed/panned tiles and dots inside the map

canvas:SetScript("OnMouseWheel", function(_, delta)
    if not trScale then
        return
    end
    local z0 = zoom
    zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, zoom * (delta > 0 and 1.2 or 1 / 1.2)))
    if zoom == z0 then
        return
    end
    -- Keep the point under the cursor fixed while zooming.
    local cx, cy = (trCanvasW or 0) * 0.5, (trCanvasH or 0) * 0.5
    local mx, my = CanvasCursor()
    panX = mx - cx - (mx - cx - panX) * (zoom / z0)
    panY = my - cy - (my - cy - panY) * (zoom / z0)
    ClampPan()
    TileReposition()
end)

canvas:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then
        return
    end
    local now = GetTime()
    if now - lastCanvasClick < 0.3 then -- double-click empty space resets the view
        zoom, panX, panY, dragging = 1, 0, 0, false
        lastCanvasClick = 0
        trScale = nil -- reframe to the full house
        BuildFloorPlan()
        return
    end
    lastCanvasClick = now
    dragging = true
    dragSX, dragSY = CanvasCursor()
    panStartX, panStartY = panX, panY
end)

-- Releasing over the canvas means the click landed on empty map: the room tiles and
-- handles are child frames that eat their own clicks. A near-stationary release is a
-- click (not the end of a pan), so clear the selection on both the map and toolbox.
canvas:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then
        return
    end
    dragging = false
    if CH.isOwnHouse and dragSX then
        local mx, my = CanvasCursor()
        if math.abs(mx - dragSX) < 4 and math.abs(my - dragSY) < 4 then
            CH.SetSelection(nil, nil)
        end
    end
end)
-- ── Drag handles: resize from any edge/corner, move from the centre ──────
-- Eight gold grips around the selected tile (4 corners + 4 edge midpoints) resize
-- the room. A white grip in the centre moves it. They only work because the
-- transform is frozen during a drag (see ComputeFit): the cursor drives the world
-- bounds directly, so each grip stays pinned under the pointer as the room changes.
--
-- Screen/world mapping (X is mirrored, Y grows upward): screen-left = world maxX,
-- screen-right = minX, screen-top = maxY, screen-bottom = minY. Each spec lists
-- which world bounds its drag delta moves. The centre grip moves all four (a
-- translation). px/py are the grip's fractional position along the tile (0..1).
local HANDLE_SIZE = 10
-- stylua: ignore
local HANDLE_SPECS = {
    { px = 0,   py = 0,   mxX = 1, mxY = 1 }, -- top-left corner
    { px = 0.5, py = 0,   mxY = 1 },          -- top edge
    { px = 1,   py = 0,   mnX = 1, mxY = 1 }, -- top-right corner
    { px = 1,   py = 0.5, mnX = 1 },          -- right edge
    { px = 1,   py = 1,   mnX = 1, mnY = 1 }, -- bottom-right corner
    { px = 0.5, py = 1,   mnY = 1 },          -- bottom edge
    { px = 0,   py = 1,   mxX = 1, mnY = 1 }, -- bottom-left corner
    { px = 0,   py = 0.5, mxX = 1 },          -- left edge
    { px = 0.5, py = 0.5, mnX = 1, mxX = 1, mnY = 1, mxY = 1, move = true }, -- centre: move
}
local handles = {}

local handleSpec, handleStart, handleStartCX, handleStartCY

-- Round a yard delta to the 0.5 grid the buttons use, so dragged coords stay tidy.
local function SnapHalf(v)
    return math.floor(v / 0.5 + 0.5) * 0.5
end

local function UpdateHandleDrag()
    if not handleSpec or not trScale then
        return
    end
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local zone = h and selectedIdx and h.zones[selectedIdx]
    if not zone then
        return
    end
    local k = trScale * zoom
    if k == 0 then
        return
    end
    local s = handleSpec

    -- A circle resizes by radius: the rim grips set it to the cursor's distance from
    -- the (fixed) centre, kept square so it stays a true circle. The centre move grip
    -- still falls through to the translation path below.
    if zone.shape == "circle" and not s.move then
        local ccx = (handleStart.minX + handleStart.maxX) * 0.5
        local ccy = (handleStart.minY + handleStart.maxY) * 0.5
        local xw, yw = CanvasToWorld(CanvasCursor())
        local r = SnapHalf(math.sqrt((xw - ccx) * (xw - ccx) + (yw - ccy) * (yw - ccy)))
        if r < 0.5 then
            r = 0.5
        end
        zone.minX, zone.maxX = ccx - r, ccx + r
        zone.minY, zone.maxY = ccy - r, ccy + r
        TileReposition()
        if RefreshEditPanel then
            RefreshEditPanel()
        end
        return
    end

    local cx, cy = CanvasCursor()
    -- Screen +x is world -x (mirrored); screen +y is downward, i.e. world -y.
    local dx = SnapHalf(-(cx - handleStartCX) / k)
    local dy = SnapHalf(-(cy - handleStartCY) / k)
    local minX = handleStart.minX + (s.mnX or 0) * dx
    local maxX = handleStart.maxX + (s.mxX or 0) * dx
    local minY = handleStart.minY + (s.mnY or 0) * dy
    local maxY = handleStart.maxY + (s.mxY or 0) * dy
    -- Resize grips move a single bound per axis, so a big drag can cross the
    -- opposite wall, so clamp the moving bound to keep at least 1 yd. (The move grip
    -- shifts both bounds together, so its size never changes and this is a no-op.)
    if not s.move then
        if maxX - minX < 1 then
            if (s.mnX or 0) > 0 then
                minX = maxX - 1
            else
                maxX = minX + 1
            end
        end
        if maxY - minY < 1 then
            if (s.mnY or 0) > 0 then
                minY = maxY - 1
            else
                maxY = minY + 1
            end
        end
    end
    zone.minX, zone.maxX, zone.minY, zone.maxY = minX, maxX, minY, maxY
    TileReposition() -- frozen transform: redraw the tile + reposition the grips
    if RefreshEditPanel then
        RefreshEditPanel() -- keep the panel's live "name WxH" in step
    end
end

local function EndHandleDrag(self)
    self:SetScript("OnUpdate", nil)
    if not handleSpec then
        return
    end
    handleSpec = nil
    CH.editingLayout = false
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    if h then
        h.updatedAt = GetServerTime()
    end
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
    end
    CH.QueueBroadcast(CH.currentHouseGUID) -- broadcast once on release, not per frame
    if CH.SyncAnchorLatch then
        CH.SyncAnchorLatch() -- re-latch so a box dropped on us doesn't fire next tick
    end
end

for i, spec in ipairs(HANDLE_SPECS) do
    local hb = CreateFrame("Frame", nil, canvas)
    hb:SetSize(spec.move and HANDLE_SIZE + 4 or HANDLE_SIZE, spec.move and HANDLE_SIZE + 4 or HANDLE_SIZE)
    hb:SetFrameLevel(canvas:GetFrameLevel() + 15) -- above tiles and dots
    hb:EnableMouse(true)
    hb:Hide()
    local outline = hb:CreateTexture(nil, "ARTWORK")
    outline:SetPoint("TOPLEFT", -1, 1)
    outline:SetPoint("BOTTOMRIGHT", 1, -1)
    outline:SetColorTexture(0, 0, 0, 1)
    local fill = hb:CreateTexture(nil, "OVERLAY")
    fill:SetAllPoints()
    if spec.move then
        fill:SetColorTexture(1, 1, 1, 0.95) -- white centre grip = move
    else
        fill:SetColorTexture(1, 0.82, 0.10, 1) -- gold grips = resize, matches the ring
    end
    hb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not CH.isOwnHouse then
            return
        end
        local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
        local zone = h and selectedIdx and h.zones[selectedIdx]
        if not zone then
            return
        end
        handleSpec = spec
        CH.editingLayout = true -- pause stair floor-switching while the box moves under us
        handleStart = { minX = zone.minX, maxX = zone.maxX, minY = zone.minY, maxY = zone.maxY }
        handleStartCX, handleStartCY = CanvasCursor()
        -- A lost mouse-up off-frame would otherwise strand the drag, so the OnUpdate
        -- also bails the moment the button is no longer held.
        self:SetScript("OnUpdate", function(s)
            if not IsMouseButtonDown("LeftButton") then
                EndHandleDrag(s)
                return
            end
            UpdateHandleDrag()
        end)
    end)
    hb:SetScript("OnMouseUp", EndHandleDrag)
    handles[i] = hb
end

-- Park the grips on the selected tile's edges/centre, or hide them when there's
-- nothing editable selected on the viewed floor.
PositionHandles = function()
    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
    local zone = (h and selectedIdx) and h.zones[selectedIdx] or nil
    if not zone or not CH.isOwnHouse or not trScale or not ZoneFrameByIdx(selectedIdx) then
        for _, hb in ipairs(handles) do
            hb:Hide()
        end
        return
    end
    local px, py = WorldToCanvas(zone.maxX, zone.maxY) -- tile top-left (screen)
    local zw = (zone.maxX - zone.minX) * trScale * zoom
    local zh = (zone.maxY - zone.minY) * trScale * zoom
    if zw < 4 then
        zw = 4
    end
    if zh < 4 then
        zh = 4
    end
    -- For a circle, keep the centre move grip and the four edge grips, which sit on
    -- the rim (the box edge midpoints touch the inscribed circle) and drag the radius.
    -- Hide the corner grips: they'd float off the disc, and a circle has no corners.
    local round = zone.shape == "circle"
    for i, spec in ipairs(HANDLE_SPECS) do
        local hb = handles[i]
        local isEdge = (spec.px == 0.5) ~= (spec.py == 0.5) -- exactly one centred axis
        if round and not spec.move and not isEdge then
            hb:Hide()
        else
            hb:ClearAllPoints()
            hb:SetPoint("CENTER", canvas, "TOPLEFT", px + spec.px * zw, -(py + spec.py * zh))
            hb:Show()
        end
    end
end

-- Toggle a pooled tile between a square room and a round one by masking its fill
-- and border. Tracked on the frame so a rebuild doesn't stack masks, and so a
-- pooled frame reused for a rectangle drops the mask again.
local function SetZoneRound(f, round)
    if round == f.masked then
        return
    end
    f.masked = round
    if round then
        f.border:AddMaskTexture(f.mask)
        f.fill:AddMaskTexture(f.mask)
    else
        f.border:RemoveMaskTexture(f.mask)
        f.fill:RemoveMaskTexture(f.mask)
    end
end

BuildFloorPlan = function()
    -- pairs, not ipairs: frames are pooled in draw order, but a rebuild can leave
    -- the pool with holes, and ipairs would stop at the first one, leaving stale
    -- tiles (e.g. a just-deleted floor's rooms) visible. pairs hides every frame.
    for _, f in pairs(zonePool) do
        f:Hide()
    end
    dotFrame:Hide()
    markerA:Hide()
    markerB:Hide()
    fpEmpty:Hide()
    -- NB: do NOT clear trScale here. The transform persists across builds and is
    -- only invalidated by the explicit reframe events (open, house change, canvas
    -- resize, reset, zone changes). Nulling it every build would make the lazy
    -- ComputeFit below refit on every redraw, including each Grow/Move/Shrink and
    -- every drag step, which is exactly the feedback loop this design removes.

    local h = CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]

    if h and h.owner then
        fpSub:SetText(string.format(CH.L["FP_X_HOUSE"], h.owner))
    elseif CH.currentHouseGUID then
        fpSub:SetText(CH.L["FP_HOME_INTERIOR"])
    else
        fpSub:SetText(CH.L["FP_NOT_IN_HOUSE"])
    end

    -- Drive the floor navigation row. Multi-floor houses only, clamp the viewed
    -- floor to the current count and show the +/- arrows and "Floor N / M" label.
    local floorCount = (h and h.floorCount) or 1
    if viewedFloor > floorCount then
        viewedFloor = floorCount
    end
    if viewedFloor < 1 then
        viewedFloor = 1
    end
    CH.fpViewedFloor = viewedFloor

    -- A different house reframes to its own bounds and resets the zoom and pan.
    -- Switching floors keeps the shared house-wide frame and your current zoom and
    -- pan, so the view stays put when you take the stairs or page through floors.
    -- A plain rebuild (room edit, dot refresh) leaves everything untouched, which
    -- keeps a dragged handle from chasing a refitting map.
    if CH.currentHouseGUID ~= lastBuiltGuid then
        zoom, panX, panY = 1, 0, 0
        trScale = nil -- new house: reframe via ComputeFit below
    end
    lastBuiltGuid = CH.currentHouseGUID

    -- Lazily (re)establish the house-wide fit. Only the reframe events null trScale
    -- (house change above, plus open, reset, canvas resize, and zone changes
    -- elsewhere). A geometry edit never does, so the transform stays frozen while
    -- you drag.
    if not trScale then
        ComputeFit()
    end
    if floorCount > 1 then
        floorHeader:SetText(string.format(CH.L["FP_FLOOR_COUNT_X"], viewedFloor, floorCount))
        floorHeader:Show()
        floorUp:Show()
        floorDown:Show()
        floorUp:SetEnabled(viewedFloor < floorCount)
        floorDown:SetEnabled(viewedFloor > 1)
        -- Offer the override only while browsing a floor you're not standing on.
        if viewedFloor ~= (CH.activeFloor or 1) then
            moveBtn:SetText(string.format(CH.L["FP_MOVE_TO_FLOOR_X"], viewedFloor))
            moveBtn:Show()
        else
            moveBtn:Hide()
        end
    else
        floorHeader:Hide()
        floorUp:Hide()
        floorDown:Hide()
        moveBtn:Hide()
    end
    addFloorBtn:SetShown(CH.isOwnHouse and h ~= nil)
    -- Removing the top floor only makes sense once there are 2+ floors.
    removeFloorBtn:SetShown(CH.isOwnHouse and h ~= nil and floorCount > 1)
    -- The Show stairs toggle appears whenever the house has stairs to show/hide.
    local showStairs = ChamberlainDB.settings.showStairsOnMap
    stairsCheck:SetShown(floorCount > 1)
    stairsCheckLabel:SetShown(floorCount > 1)
    stairsCheck:SetChecked(showStairs)

    -- Anchors show on every floor they actually reach, not just the one they sit on,
    -- so the map matches how they fire: a floor marker (no fromFloor) triggers from
    -- anywhere, and a staircase connects two floors.
    local function AnchorOnViewedFloor(zone)
        local f = zone.floor or 1
        if zone.setFloor and zone.fromFloor then
            -- A staircase links fromFloor and setFloor. Show it on both so the pair
            -- can be aligned from either floor. (Keyed off the linked floors, not
            -- `floor`, since a landing now sits on the floor it fires from.)
            return viewedFloor == zone.fromFloor or viewedFloor == zone.setFloor
        elseif zone.setFloor then
            return true -- floor marker: fires from any floor
        elseif zone.floorDelta then
            return viewedFloor == f or viewedFloor == f + zone.floorDelta
        end
        return viewedFloor == f
    end

    -- A zone is drawn when it's visible to us (secret rooms hide from visitors),
    -- belongs on the floor we're viewing, and isn't a stair anchor we've hidden.
    local function DrawZone(zone)
        if not ZoneVisible(zone) then
            return false
        end
        if FPIsAnchor(zone) then
            if not showStairs then
                return false
            end
            return AnchorOnViewedFloor(zone)
        end
        return (zone.floor or 1) == viewedFloor
    end

    -- Count rooms we'll actually draw on this floor. A floor with no visible rooms
    -- shows the empty state, same as a house with none.
    local visibleCount = 0
    if h and h.zones then
        for _, zone in ipairs(h.zones) do
            if DrawZone(zone) then
                visibleCount = visibleCount + 1
            end
        end
    end

    if not h or not h.zones or visibleCount == 0 then
        fpEmpty:SetText(
            floorCount > 1 and string.format(CH.L["FP_NO_ROOMS_ON_FLOOR_X"], viewedFloor) or CH.L["FP_NO_ROOMS"]
        )
        fpEmpty:Show()
        selectedIdx = nil
        RefreshEditPanel()
        PositionHandles()
        return
    end

    -- Selection can go stale when rooms are deleted elsewhere
    if selectedIdx and not h.zones[selectedIdx] then
        selectedIdx = nil
    end

    -- Transform (trScale / trMinY / trMaxX / canvas dims) is the shared house-wide
    -- fit established by ComputeFit above. The draw loop maps world to canvas
    -- through it. Nothing here recomputes it, so editing a room never reframes.
    if not trScale then
        PositionHandles()
        return -- nothing framed (e.g. all rooms secret to a visitor)
    end

    -- Draw order, not zone index, keys the frame pool: only on-floor zones get a
    -- frame, so keying by zone index would leave holes. A running counter keeps the
    -- pool dense (so #zonePool and the top-of-build hide stay correct); the real
    -- zone index rides on f.zoneIdx for selection and editing.
    local drawn = 0
    for i, zone in ipairs(h.zones) do
        if DrawZone(zone) then
            local c = zone.color or PALETTE[((i - 1) % #PALETTE) + 1]
            local r, g, b = c[1], c[2], c[3]

            -- With X flipped, zone.maxX maps to the left canvas edge, zone.maxY to the top.
            local px, py = WorldToCanvas(zone.maxX, zone.maxY)
            local zw = (zone.maxX - zone.minX) * trScale * zoom
            local zh = (zone.maxY - zone.minY) * trScale * zoom
            if zw < 4 then
                zw = 4
            end
            if zh < 4 then
                zh = 4
            end

            drawn = drawn + 1
            local f = GetZoneFrame(drawn)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", canvas, "TOPLEFT", px, -py)
            f:SetSize(zw, zh)
            SetZoneRound(f, zone.shape == "circle")
            local anchor = FPIsAnchor(zone)
            -- Selected tiles get a fat ring: inset the fill by 3px (vs 1px normally)
            -- so the border texture shows through as a thick band. The pool reuses
            -- frames, so the unselected branch has to put the inset back to 1px.
            f.fill:ClearAllPoints()
            if i == selectedIdx then
                f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
                f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
                -- Bright gold ring + brightened (not darkened) fill so the room lights up.
                f.border:SetColorTexture(1, 0.82, 0.10, 1)
                f.fill:SetColorTexture(r, g, b, 0.85)
            else
                f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
                f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
                if anchor then
                    -- Stair anchors get a cyan border so they read as connectors, not rooms.
                    f.border:SetColorTexture(0.40, 0.85, 1.00, 0.95)
                    f.fill:SetColorTexture(0.20, 0.45, 0.60, 0.45)
                else
                    f.border:SetColorTexture(r, g, b, 0.85)
                    f.fill:SetColorTexture(r * 0.55, g * 0.55, b * 0.55, 0.50)
                end
            end
            f.label:SetText(AnchorGlyph(zone) .. zone.name)
            -- White label over the bright selected fill stays legible, otherwise the
            -- room colour as before.
            if i == selectedIdx then
                f.label:SetTextColor(1, 1, 1, 1)
            else
                f.label:SetTextColor(r, g, b, 1)
            end
            -- Store for tooltip and click selection
            f.zoneIdx = i
            f.zoneName = zone.name
            f.zoneW = zone.maxX - zone.minX
            f.zoneH = zone.maxY - zone.minY
            f.zoneTime = h.stats and h.stats[zone.name] or 0
            f.cr, f.cg, f.cb = r, g, b
        end
    end

    dotFrame:Show()
    UpdateResetButton()
    RefreshEditPanel()
    PositionHandles()
end

-- Shown when the player is browsing a floor other than the one they're standing
-- on: their dot (and party dots) belong to the active floor, so they're hidden
-- here and this reminds the viewer where they actually are.
local floorHint = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
floorHint:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 6)
floorHint:Hide()

-- Dot update via OnUpdate (only fires while fp is visible). Runs every frame:
-- the transform math is trivail and a throttled dot moves in visible steps.
canvas:SetScript("OnUpdate", function()
    if dragging then
        -- OnMouseUp only fires if the button is released over the canvas. Let go
        -- while the cursor sits on a tile or handle and that child eats the event,
        -- leaving the pan stuck to the mouse. Bail here the moment it's no longer held.
        if not IsMouseButtonDown("LeftButton") then
            dragging = false
        else
            local mx, my = CanvasCursor()
            panX = panStartX + (mx - dragSX)
            panY = panStartY + (my - dragSY)
            ClampPan()
            TileReposition()
        end
    end

    -- The player and party dots live on the active floor. When browsing another
    -- floor, hide every live blip and show a "you're on floor N" reminder instead.
    -- This runs before the trScale guard below so the reminder still shows on an
    -- empty floor, which has no scale because there are no rooms to fit.
    if viewedFloor ~= (CH.activeFloor or 1) then
        dotFrame:Hide()
        markerA:Hide()
        markerB:Hide()
        for i = 1, 4 do
            if partyDots[i] then
                partyDots[i]:Hide()
            end
        end
        floorHint:SetText(string.format(CH.L["FP_YOURE_ON_FLOOR_X"], CH.activeFloor or 1))
        floorHint:Show()
        return
    end
    floorHint:Hide()

    if not trScale then
        return
    end

    local x, y = CH.GetWorldPos()
    if not x then
        dotFrame:Hide()
        return
    end

    local ch = canvas:GetHeight()
    if ch ~= trCanvasH and ch > 0 then
        -- canvas was resized since last build: reframe to the new dimensions
        trScale = nil
        BuildFloorPlan()
        return
    end

    local px, py = WorldToCanvas(x, y)
    dotFrame:ClearAllPoints()
    dotFrame:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
    if not dotFrame.lettered then
        dotFrame.label:SetText(CH.FirstChar(UnitName("player")))
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS[class]
        if cc then
            SetBlip(dot, cc.r, cc.g, cc.b)
        end
        dotFrame.lettered = true
    end
    dotFrame:Show()

    if CH.pendingA then
        local ax, ay = WorldToCanvas(CH.pendingA.x, CH.pendingA.y)
        markerA:ClearAllPoints()
        markerA:SetPoint("CENTER", canvas, "TOPLEFT", ax, -ay)
        markerA:Show()
    else
        markerA:Hide()
    end

    if CH.pendingB then
        local bx, by = WorldToCanvas(CH.pendingB.x, CH.pendingB.y)
        markerB:ClearAllPoints()
        markerB:SetPoint("CENTER", canvas, "TOPLEFT", bx, -by)
        markerB:Show()
    else
        markerB:Hide()
    end

    for i = 1, 4 do
        local unit = "party" .. i
        local pd = GetPartyDot(i)
        -- UnitIsVisible is true only when the member is in the same area as us
        -- and in range. A friend in their own (separate) house is not visible,
        -- so this keeps their blip off our floor plan even though all houses
        -- share a map id and reuse similar coordinates.
        local uy, ux = UnitPosition(unit)
        local upx, upy
        if ux and UnitIsVisible(unit) then
            upx, upy = WorldToCanvas(ux, uy)
            -- Drop dots that would land outside the canvas
            if upx < 0 or upy < 0 or upx > canvas:GetWidth() or upy > canvas:GetHeight() then
                upx = nil
            end
        end
        if upx then
            local _, class = UnitClass(unit)
            local cc = class and RAID_CLASS_COLORS[class]
            SetBlip(pd.tex, cc and cc.r or 0.8, cc and cc.g or 0.8, cc and cc.b or 0.8)
            pd.unitName = UnitName(unit)
            pd.label:SetText(CH.FirstChar(pd.unitName))
            pd:ClearAllPoints()
            pd:SetPoint("CENTER", canvas, "TOPLEFT", upx, -upy)
            pd:Show()
        else
            pd:Hide()
        end
    end
end)

-- OnShow/OnHide also track the open flag, so every close path (the Close button,
-- Escape via UISpecialFrames, /reload tear-down doesn't fire OnHide) keeps the
-- saved state honest without each one having to set it.
fp:SetScript("OnShow", function()
    if ChamberlainDB and ChamberlainDB.settings then
        ChamberlainDB.settings.floorPlanOpen = true
    end
    BuildFloorPlan()
end)
fp:SetScript("OnHide", function()
    if ChamberlainDB and ChamberlainDB.settings then
        ChamberlainDB.settings.floorPlanOpen = false
    end
end)

function CH.OpenFloorPlan()
    zoom, panX, panY = 1, 0, 0 -- open at the fitted view
    trScale = nil -- reframe on open
    fp:Show()
    fp:Raise()
end

-- Launcher/minimap toggle: open if closed, close if already open.
function CH.ToggleFloorPlan()
    if fp:IsShown() then
        fp:Hide()
    else
        CH.OpenFloorPlan()
    end
end

-- Reopen the floor plan on login if it was open when we last left, but only while
-- standing inside a house. Outside a house it stays closed, so a /reload in the
-- open world doesn't pop an empty map. The window populates itself once the async
-- house lookup resolves (CH.OnActiveFloorChanged rebuilds it).
function CH.RestoreFloorPlan()
    if ChamberlainDB.settings.floorPlanOpen and C_Housing.IsInsideHouse() then
        CH.OpenFloorPlan()
    end
end

-- Called from RoomManager when zones change so the floor plan stays in sync
function CH.RebuildFloorPlan()
    if fp:IsShown() then
        trScale = nil -- zones changed (create/delete/share): reframe to new bounds
        BuildFloorPlan()
    end
end

-- Called from Housing when the player's active floor changes (took the stairs):
-- snap the viewed floor to follow them, so the map shows where they now are.
function CH.OnActiveFloorChanged()
    viewedFloor = CH.activeFloor or 1
    CH.fpViewedFloor = viewedFloor
    if fp:IsShown() then
        BuildFloorPlan()
    end
end

-- Sync the map's selection to a room picked elsewhere (the build toolbox). Pass
-- nil to clear. revealFloor switches the map to the room's floor first, which the
-- toolbox room list wants but a map click does not (you can only click what's
-- shown, and stairs draw on both floors they link). Called through CH.SetSelection,
-- so it never calls back into it.
function CH.FloorPlanSelect(zone, revealFloor)
    local h = CurrentHouse()
    local idx = nil
    if zone and h then
        for i, z in ipairs(h.zones) do
            if z == zone then
                idx = i
                break
            end
        end
    end
    if revealFloor and idx and zone.floor and zone.floor ~= viewedFloor then
        viewedFloor = zone.floor
        CH.fpViewedFloor = viewedFloor
    end
    selectedIdx = idx
    if fp:IsShown() then
        BuildFloorPlan()
    else
        RefreshEditPanel()
    end
end
