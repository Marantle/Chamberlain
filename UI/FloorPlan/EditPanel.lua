local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: moving and resizing the selected room, and the drag grips
-- ─────────────────────────────────────────────────────────────────────
-- Click a room on the canvas to select it, then move or resize it half a yard
-- at a time from the pad on the build rail, or drag its grips. Own house only.

local FP = CH.FP
local canvas = FP.canvas

local STEP = 0.5 -- yards per button click

-- Each delta is how many steps a bound moves. The pad on the build rail
-- (UI/Toolbox.lua) holds the table of them.
function FP.AdjustSelected(dMinX, dMaxX, dMinY, dMaxY)
    local h = FP.CurrentHouse()
    local zone = CH.tbSelZone
    if not h or not zone then
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
    if CH.RefreshRoomList then
        CH.RefreshRoomList()
    end
    CH.QueueBroadcast(CH.currentHouseGUID)
    if CH.SyncAnchorLatch then
        CH.SyncAnchorLatch() -- nudging a stair box onto us shouldn't fire a transition
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
        -- the grid is half a yard, so most frames change nothing
        if zone.minX == ccx - r then
            return
        end
        zone.minX, zone.maxX = ccx - r, ccx + r
        zone.minY, zone.maxY = ccy - r, ccy + r
        FP.TileReposition()
        CH.RefreshToolbox()
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
    if zone.minX == minX and zone.maxX == maxX and zone.minY == minY and zone.maxY == maxY then
        return
    end
    zone.minX, zone.maxX, zone.minY, zone.maxY = minX, maxX, minY, maxY
    FP.TileReposition() -- frozen transform: redraw the tile + reposition the grips
    CH.RefreshToolbox() -- keep the rail's live "name WxH" in step
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
    -- a room dragged past another one stacks by its new size from here
    FP.Build()
    if CH.RefreshRoomList then
        CH.RefreshRoomList()
    end
    CH.QueueBroadcast(CH.currentHouseGUID) -- broadcast once on release, not per frame
    if CH.SyncAnchorLatch then
        CH.SyncAnchorLatch() -- re-latch so a box dropped on us doesn't fire next tick
    end
end

for i, spec in ipairs(HANDLE_SPECS) do
    local hb = CreateFrame("Frame", nil, canvas)
    hb:SetSize(spec.move and HANDLE_SIZE + 4 or HANDLE_SIZE, spec.move and HANDLE_SIZE + 4 or HANDLE_SIZE)
    hb:SetFrameLevel(FP.Level("grips"))
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
        if button ~= "LeftButton" or not FP.CanEdit() then
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
    if not zone or not FP.CanEdit() or not k or not FP.ZoneFrameByIdx(FP.selectedIdx) then
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
