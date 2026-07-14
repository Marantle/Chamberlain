local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: world-to-canvas transform, zoom and pan
-- ─────────────────────────────────────────────────────────────────────
-- Owns the fit (trScale and friends) and the zoom/pan layered on top. The
-- raw scale never leaves this file: other files map coordinates through
-- FP.WorldToCanvas / FP.CanvasToWorld and size tiles with FP.ZoomedScale().

local FP = CH.FP
local fp = FP.win
local canvas = FP.canvas

local PADDING = 24

-- Transform state (set by ComputeFit, used by every draw pass)
local trScale, trMinY, trMaxX, trCanvasH, trCanvasW

-- Zoom and pan layered on top of the fit-to-window transform. Only the room tiles
-- scale with zoom. Labels (fixed-size fonts) and the dots (fixed-size frames) just
-- move, so they stay the same size. Reset on house/floor change and on open.
local zoom, panX, panY = 1, 0, 0
local ZOOM_MIN, ZOOM_MAX = 1, 6

-- X is mirrored: higher world X is left from entrance (X decreases as you move right).
function FP.WorldToCanvas(x, y)
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
function FP.CanvasToWorld(px, py)
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
    local h = FP.CurrentHouse()
    if not h or not h.zones then
        trScale = nil
        return
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, zone in ipairs(h.zones) do
        if FP.ZoneVisible(zone) then
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

-- Lazily (re)establish the fit: only the explicit reframe events null trScale,
-- so a geometry edit between them keeps the frozen transform.
function FP.EnsureFit()
    if not trScale then
        ComputeFit()
    end
end

function FP.InvalidateFit()
    trScale = nil
end

-- The scale tiles draw at (fit times zoom), or nil while nothing is framed.
function FP.ZoomedScale()
    if trScale then
        return trScale * zoom
    end
end

function FP.ResetView()
    zoom, panX, panY = 1, 0, 0
end

-- The dot loop calls this each frame: a canvas resized since the last fit
-- invalidates it and reports true so the caller can rebuild.
function FP.CheckCanvasResize()
    local ch = canvas:GetHeight()
    if ch ~= trCanvasH and ch > 0 then
        trScale = nil
        return true
    end
    return false
end

-- Reset-view button, shown over the map's bottom-left only while zoomed or panned.
local resetBtn = CH.MakeButton(fp, "FP_RESET_ZOOM", 86, 18)
resetBtn:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 4, 4)
resetBtn:SetFrameLevel(canvas:GetFrameLevel() + 20) -- above the tiles and dots
resetBtn:Hide()
resetBtn:SetScript("OnClick", function()
    FP.ResetView()
    FP.InvalidateFit() -- reframe to the full house, recovering any room dragged off-edge
    FP.Build()
end)

function FP.UpdateResetButton()
    resetBtn:SetShown(zoom ~= 1 or panX ~= 0 or panY ~= 0)
end

local function ClampPan()
    local limX = (trCanvasW or 0) * zoom * 0.5
    local limY = (trCanvasH or 0) * zoom * 0.5
    panX = math.max(-limX, math.min(limX, panX))
    panY = math.max(-limY, math.min(limY, panY))
end

-- Cursor in canvas-local pixels: x rightward from the left edge, y downward from
-- the top edge, matching WorldToCanvas's px / py.
function FP.CanvasCursor()
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
    local mx, my = FP.CanvasCursor()
    panX = mx - cx - (mx - cx - panX) * (zoom / z0)
    panY = my - cy - (my - cy - panY) * (zoom / z0)
    ClampPan()
    FP.TileReposition()
end)

canvas:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then
        return
    end
    local now = GetTime()
    if now - lastCanvasClick < 0.3 then -- double-click empty space resets the view
        FP.ResetView()
        dragging = false
        lastCanvasClick = 0
        FP.InvalidateFit() -- reframe to the full house
        FP.Build()
        return
    end
    lastCanvasClick = now
    dragging = true
    dragSX, dragSY = FP.CanvasCursor()
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
        local mx, my = FP.CanvasCursor()
        if math.abs(mx - dragSX) < 4 and math.abs(my - dragSY) < 4 then
            CH.SetSelection(nil, nil)
        end
    end
end)

-- Advance an in-flight pan. Called every frame from the dot loop (Dots.lua owns
-- the canvas OnUpdate). OnMouseUp only fires if the button is released over the
-- canvas: let go while the cursor sits on a tile or handle and that child eats
-- the event, leaving the pan stuck to the mouse, so this also bails the moment
-- the button is no longer held.
function FP.UpdatePanDrag()
    if not dragging then
        return
    end
    if not IsMouseButtonDown("LeftButton") then
        dragging = false
        return
    end
    local mx, my = FP.CanvasCursor()
    panX = panStartX + (mx - dragSX)
    panY = panStartY + (my - dragSY)
    ClampPan()
    FP.TileReposition()
end
