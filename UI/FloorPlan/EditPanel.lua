local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: edit panel and drag grips
-- ─────────────────────────────────────────────────────────────────────
-- Edit panel: click a room on the canvas to select it, then move or resize
-- it a yard at a time. Own house only.

local FP = CH.FP
local fp = FP.win
local canvas = FP.canvas

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
    local h = FP.CurrentHouse()
    local zone = h and FP.selectedIdx and h.zones[FP.selectedIdx]
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
    FP.Build()
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
    local h = FP.CurrentHouse()
    return h and FP.selectedIdx and h.zones[FP.selectedIdx], h
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
    table.remove(h.zones, FP.selectedIdx)
    CH.DropZoneStats(h, zone.name)
    CH.SetSelection(nil, nil) -- clear it on the toolbox too, then rebuild
    CH.TouchHouse(CH.currentHouseGUID)
end)

function FP.RefreshEditPanel()
    local h = FP.CurrentHouse()
    local zone = CH.isOwnHouse and h and FP.selectedIdx and h.zones[FP.selectedIdx]
    if zone then
        editName:SetText(string.format(CH.L["FMT_NAME_DIM_X"], zone.name, CH.ZoneDimText(zone)))
        editPanel:Show()
        editHint:Hide()
    else
        editPanel:Hide()
        editHint:SetShown(CH.isOwnHouse and h ~= nil and h.zones ~= nil and #h.zones > 0)
    end
end

-- ── Drag handles: resize from any edge/corner, move from the centre ──────
-- Eight gold grips around the selected tile (4 corners + 4 edge midpoints) resize
-- the room. A white grip in the centre moves it. They only work because the
-- transform is frozen during a drag (see ComputeFit in Transform.lua): the cursor
-- drives the world bounds directly, so each grip stays pinned under the pointer
-- as the room changes.
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
    local k = FP.ZoomedScale()
    if not handleSpec or not k or k == 0 then
        return
    end
    local h = FP.CurrentHouse()
    local zone = h and FP.selectedIdx and h.zones[FP.selectedIdx]
    if not zone then
        return
    end
    local s = handleSpec

    -- A circle resizes by radius: the rim grips set it to the cursor's distance from
    -- the (fixed) centre, kept square so it stays a true circle. The centre move grip
    -- still falls through to the translation path below.
    if zone.shape == "circle" and not s.move then
        local ccx = (handleStart.minX + handleStart.maxX) * 0.5
        local ccy = (handleStart.minY + handleStart.maxY) * 0.5
        local xw, yw = FP.CanvasToWorld(FP.CanvasCursor())
        local r = SnapHalf(math.sqrt((xw - ccx) * (xw - ccx) + (yw - ccy) * (yw - ccy)))
        if r < 0.5 then
            r = 0.5
        end
        zone.minX, zone.maxX = ccx - r, ccx + r
        zone.minY, zone.maxY = ccy - r, ccy + r
        FP.TileReposition()
        FP.RefreshEditPanel()
        return
    end

    local cx, cy = FP.CanvasCursor()
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
    FP.TileReposition() -- frozen transform: redraw the tile + reposition the grips
    FP.RefreshEditPanel() -- keep the panel's live "name WxH" in step
end

local function EndHandleDrag(self)
    self:SetScript("OnUpdate", nil)
    if not handleSpec then
        return
    end
    handleSpec = nil
    CH.editingLayout = false
    local h = FP.CurrentHouse()
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
        local h = FP.CurrentHouse()
        local zone = h and FP.selectedIdx and h.zones[FP.selectedIdx]
        if not zone then
            return
        end
        handleSpec = spec
        CH.editingLayout = true -- pause stair floor-switching while the box moves under us
        handleStart = { minX = zone.minX, maxX = zone.maxX, minY = zone.minY, maxY = zone.maxY }
        handleStartCX, handleStartCY = FP.CanvasCursor()
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
function FP.PositionHandles()
    local h = FP.CurrentHouse()
    local zone = (h and FP.selectedIdx) and h.zones[FP.selectedIdx] or nil
    local k = FP.ZoomedScale()
    if not zone or not CH.isOwnHouse or not k or not FP.ZoneFrameByIdx(FP.selectedIdx) then
        for _, hb in ipairs(handles) do
            hb:Hide()
        end
        return
    end
    local px, py = FP.WorldToCanvas(zone.maxX, zone.maxY) -- tile top-left (screen)
    local zw = (zone.maxX - zone.minX) * k
    local zh = (zone.maxY - zone.minY) * k
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
