local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: moving and resizing the selected room, and the drag grips
-- ─────────────────────────────────────────────────────────────────────
-- Click a room on the canvas to select it, then move or resize it half a yard
-- at a time from the pad on the build rail, or drag its grips. Own house only.

local FP = CH.FP
local canvas = FP.canvas

local STEP = 0.5 -- yards per button click

-- After an edit lands: stamp the house, redraw and tell the group.
local function Commit(h)
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

-- Resize a room about its centre, refusing a box under a yard.
local function SizeAbout(zone, w, h)
    if w < 1 or h < 1 then
        return false
    end
    local cx, cy = CH.ZoneCentre(zone)
    CH.BoxAbout(zone, cx, cy, w, h)
    return true
end

-- Each delta is how many steps a bound moves. The pad on the build rail
-- (UI/Toolbox.lua) holds the table of them.
function FP.AdjustSelected(dMinX, dMaxX, dMinY, dMaxY)
    local h = FP.CurrentHouse()
    local zone = CH.tbSelZone
    if not h or not zone then
        return
    end
    if zone.shape and not (dMinX == dMaxX and dMinY == dMaxY) then
        -- A shaped room keeps its shape, so any Grow or Shrink button scales it
        -- about the centre by a yard, both axes together.
        local grow = (dMaxX - dMinX) + (dMaxY - dMinY) > 0
        local w = zone.maxX - zone.minX
        local f = (w + (grow and 2 or -2) * STEP) / w
        if not SizeAbout(zone, w * f, (zone.maxY - zone.minY) * f) then
            return
        end
    else
        -- a move, or one wall of a plain room
        local minX, maxX = zone.minX + dMinX * STEP, zone.maxX + dMaxX * STEP
        local minY, maxY = zone.minY + dMinY * STEP, zone.maxY + dMaxY * STEP
        if maxX - minX < 1 or maxY - minY < 1 then
            return
        end -- keep at least 1 yd
        zone.minX, zone.maxX = minX, maxX
        zone.minY, zone.maxY = minY, maxY
    end
    Commit(h)
end

-- The Quick resize chips and the Game size button: a set box about the centre.
function FP.SetSelectedBox(w, h)
    local house, zone = FP.CurrentHouse(), CH.tbSelZone
    if house and zone and SizeAbout(zone, w, h) then
        Commit(house)
    end
end

-- A quarter turn for an L or a T. The box swaps its sides about the centre
-- and the mask and the walk-in test read the turn from zone.rot. A room
-- joined to another stays on that door (the southmost, if it meets more),
-- going on to the next turn when this one has no door facing it.
function FP.RotateSelected()
    local house, zone = FP.CurrentHouse(), CH.tbSelZone
    if not house or not zone or not zone.shape then
        return
    end
    local join = CH.JoinedDoor(house, zone)
    for _ = 1, join and 3 or 1 do
        local r = ((zone.rot or 0) + 1) % 4
        zone.rot = r > 0 and r or nil
        SizeAbout(zone, zone.maxY - zone.minY, zone.maxX - zone.minX)
        if not join or CH.PutOnDoor(zone, join) then
            break
        end
    end
    Commit(house)
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
-- An edge grip sits on the door in the middle of its wall, and fx/fy is the
-- way that door faces in the world.
local HANDLE_SIZE = 10
-- stylua: ignore
local HANDLE_SPECS = {
    { px = 0,   py = 0,   mxX = 1, mxY = 1 }, -- top-left corner
    { px = 0.5, py = 0,   mxY = 1, fx = 0, fy = 1 },  -- top edge
    { px = 1,   py = 0,   mnX = 1, mxY = 1 }, -- top-right corner
    { px = 1,   py = 0.5, mnX = 1, fx = -1, fy = 0 }, -- right edge
    { px = 1,   py = 1,   mnX = 1, mnY = 1 }, -- bottom-right corner
    { px = 0.5, py = 1,   mnY = 1, fx = 0, fy = -1 }, -- bottom edge
    { px = 0,   py = 1,   mxX = 1, mnY = 1 }, -- bottom-left corner
    { px = 0,   py = 0.5, mxX = 1, fx = 1, fy = 0 },  -- left edge
    { px = 0.5, py = 0.5, mnX = 1, mxX = 1, mnY = 1, mxY = 1, move = true }, -- centre: move
}
local MOVE_SPEC = HANDLE_SPECS[#HANDLE_SPECS]
local GRIP_GOLD = { 1, 0.82, 0.10, 1 } -- resize, matches the ring
local GRIP_WHITE = { 1, 1, 1, 0.95 } -- move
local GRIP_DOOR = { 0.45, 0.90, 0.55, 1 }
local handles = {}

local handleSpec, handleStart, handleStartCX, handleStartCY

-- Snap: a room on the move, or a square's wall, jumps so one of its doors
-- meets a door that faces it on another room of the same floor. The game's
-- rooms are stored wall to wall and two joined rooms share that wall, so the
-- two doors land on one spot. Nothing snaps until the cursor has moved a
-- few pixels, since a click on a grip is no drag and must never move a room.
-- probe is the box where the drag would put the room before the snap.
local SNAP_PX = 12
local SNAP_AFTER_PX = 3
local snapping, dragMoved
local targets, nTargets = {}, 0 -- flat x, y, nx, ny of the doors it can meet
local lockDoor, lockTarget -- the pair that snapped, held until it's pulled apart
local probe = {}

local function Snaps(zone)
    return ChamberlainDB.settings.snapRooms and CH.IsRoom(zone)
end

-- The other rooms don't move during a drag, so thier doors are read once.
local function CollectTargets(h, zone)
    nTargets = 0
    for _, z in ipairs(CH.OtherRooms(h, zone)) do
        for _, d in ipairs(CH.ZoneDoors(z)) do
            local x, y, nx, ny = CH.DoorAt(z, d)
            targets[nTargets + 1], targets[nTargets + 2] = x, y
            targets[nTargets + 3], targets[nTargets + 4] = nx, ny
            nTargets = nTargets + 4
        end
    end
end

-- Squared distance from a door at (x, y) facing (nx, ny) to target t, plus
-- the step that closes it. Nil when the two don't face each other.
local function Gap(x, y, nx, ny, t)
    if targets[t + 2] ~= -nx or targets[t + 3] ~= -ny then
        return nil
    end
    local dx, dy = targets[t] - x, targets[t + 1] - y
    return dx * dx + dy * dy, dx, dy
end

-- The step that puts the closest door pair of probe together, if one is in
-- reach. Only one pair counts. Once it snaps it holds until that pair is out
-- of reach, so a second door close by can't tug the room back and forth.
-- fx/fy limits it to the door of one wall, for a square's edge grip.
local function SnapStep(reach, fx, fy)
    local doors = CH.ZoneDoors(probe)
    local limit = reach * reach
    if lockDoor then
        local x, y, nx, ny = CH.DoorAt(probe, doors[lockDoor])
        local g, dx, dy = Gap(x, y, nx, ny, lockTarget)
        if g and g <= limit then
            return dx, dy
        end
        lockDoor = nil
    end
    local best, stepX, stepY = limit, 0, 0
    for i, d in ipairs(doors) do
        local x, y, nx, ny = CH.DoorAt(probe, d)
        if not fx or (nx == fx and ny == fy) then
            for t = 1, nTargets, 4 do
                local g, dx, dy = Gap(x, y, nx, ny, t)
                if g and g <= best then
                    best, stepX, stepY = g, dx, dy
                    lockDoor, lockTarget = i, t
                end
            end
        end
    end
    return stepX, stepY
end

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

    -- A shaped room scales about its (fixed) centre: an edge grip sets how far
    -- that edge sits from it, and the other axis follows so the shape keeps.
    -- The centre move grip still falls through to the translation path below.
    if zone.shape and not s.move then
        local ccx, ccy = CH.ZoneCentre(handleStart)
        local w0, h0 = handleStart.maxX - handleStart.minX, handleStart.maxY - handleStart.minY
        local xw, yw = FP.CanvasToWorld(FP.CanvasCursor())
        local f
        if s.mnX or s.mxX then
            f = SnapHalf(math.abs(xw - ccx) * 2) / w0
        else
            f = SnapHalf(math.abs(yw - ccy) * 2) / h0
        end
        f = math.max(f, 1 / math.min(w0, h0)) -- keep at least 1 yd
        -- the grid is half a yard, so most frames change nothing
        if zone.maxX - zone.minX == w0 * f then
            return
        end
        SizeAbout(zone, w0 * f, h0 * f)
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
    if snapping then
        dragMoved = dragMoved or math.abs(cx - handleStartCX) + math.abs(cy - handleStartCY) >= SNAP_AFTER_PX
        if dragMoved then
            probe.minX, probe.maxX, probe.minY, probe.maxY = minX, maxX, minY, maxY
            local sx, sy = SnapStep(SNAP_PX / k, s.fx, s.fy)
            minX, maxX = minX + (s.mnX or 0) * sx, maxX + (s.mxX or 0) * sx
            minY, maxY = minY + (s.mnY or 0) * sy, maxY + (s.mxY or 0) * sy
        end
    end
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
        -- a room dragged past another one stacks by its new size from here, and
        -- the group hears once, on release
        Commit(h)
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
    hb.fill = hb:CreateTexture(nil, "OVERLAY")
    hb.fill:SetAllPoints()
    hb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not FP.CanEdit() then
            return
        end
        local h = FP.CurrentHouse()
        local zone = h and FP.selectedIdx and h.zones[FP.selectedIdx]
        if not zone then
            return
        end
        -- with snap on, a shaped room's edge grips are its doors and they all move it
        local snaps = Snaps(zone)
        handleSpec = snaps and zone.shape and MOVE_SPEC or spec
        snapping = snaps and (handleSpec.move or handleSpec.fx ~= nil)
        if snapping then
            CollectTargets(h, zone)
            lockDoor, dragMoved = nil, false
            probe.shape, probe.rot = zone.shape, zone.rot
        end
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

-- The Snap switch in the map's top left corner, your own house only.
-- Floors.lua shows it with the other tools.
local snapBtn = CH.MakeButton(FP.map, "FP_SNAP", 60, 18)
snapBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 4, -4)
snapBtn:SetFrameLevel(FP.Level("buttons"))
snapBtn:Hide()
CH.Tip(snapBtn, "FP_TT_SNAP")
snapBtn:SetScript("OnClick", function(self)
    local s = ChamberlainDB.settings
    s.snapRooms = not s.snapRooms
    CH.SetButtonActive(self, s.snapRooms)
    FP.PositionHandles()
end)
snapBtn:SetScript("OnShow", function(self)
    CH.SetButtonActive(self, ChamberlainDB.settings.snapRooms)
end)
FP.snapBtn = snapBtn

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
    -- A shaped room keeps the centre move grip and the four edge grips, which
    -- sit on a wall for every shape (the box edge midpoints touch even a disc)
    -- and scale it. The corner grips go: they'd float off a disc or sit in an
    -- L's missing corner, and there is no single wall to pull there anyway.
    -- With snap on the edge grips turn into doors. A square's are on its doors
    -- already. A shaped room's grips move onto its own doors, fewer than four
    -- on an L or a T and off the middle.
    local shaped = zone.shape ~= nil
    local snaps = Snaps(zone)
    local doors = snaps and shaped and CH.ZoneDoors(zone)
    local door = 0
    for i, spec in ipairs(HANDLE_SPECS) do
        local hb = handles[i]
        local color = spec.move and GRIP_WHITE or (snaps and spec.fx) and GRIP_DOOR or GRIP_GOLD
        if hb.color ~= color then
            hb.fill:SetColorTexture(unpack(color))
            hb.color = color
        end
        hb:ClearAllPoints()
        if doors and spec.fx then
            door = door + 1
            local d = doors[door]
            if d then
                local dx, dy = FP.WorldToCanvas(CH.DoorAt(zone, d))
                hb:SetPoint("CENTER", canvas, "TOPLEFT", dx, -dy)
            end
            hb:SetShown(d ~= nil)
        elseif shaped and not spec.move and not spec.fx then
            hb:Hide()
        else
            hb:SetPoint("CENTER", canvas, "TOPLEFT", px + spec.px * zw, -(py + spec.py * zh))
            hb:Show()
        end
    end
end
