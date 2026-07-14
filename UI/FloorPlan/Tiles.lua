local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: room tiles and the build pass
-- ─────────────────────────────────────────────────────────────────────

local FP = CH.FP
local canvas = FP.canvas

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
function FP.ZoneFrameByIdx(idx)
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
        -- handler: FP.Build re-shows the frames under a stationary cursor,
        -- which fires a fresh OnEnter that would otherwise overwrite the tooltip
        -- with whatever frame sits on top.
        local target = self
        local selectedIdx = FP.selectedIdx
        if selectedIdx and selectedIdx ~= self.zoneIdx then
            for _, idx in ipairs(ZonesAtCursor()) do
                if idx == selectedIdx then
                    target = FP.ZoneFrameByIdx(selectedIdx) or self
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
            if idx == FP.selectedIdx then
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
        -- sets FP.selectedIdx (via CH.FloorPlanSelect) and rebuilds.
        local house = FP.CurrentHouse()
        CH.SetSelection(newIdx and house and house.zones[newIdx] or nil, CH.currentHouseGUID)
        -- Refresh the tooltip to the room we just cycled to (OnEnter only fires on
        -- mouse motion or a frame re-show, so a click alone wouldn't update it).
        local sel = FP.selectedIdx and FP.ZoneFrameByIdx(FP.selectedIdx)
        if sel then
            ShowZoneTooltip(self, sel.zoneName, sel.zoneW, sel.zoneH, sel.zoneTime, sel.cr, sel.cg, sel.cb)
        else
            GameTooltip:Hide() -- nothing selected
        end
    end)

    zonePool[i] = f
    return f
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

local lastBuiltGuid

function FP.Build()
    -- pairs, not ipairs: frames are pooled in draw order, but a rebuild can leave
    -- the pool with holes, and ipairs would stop at the first one, leaving stale
    -- tiles (e.g. a just-deleted floor's rooms) visible. pairs hides every frame.
    for _, f in pairs(zonePool) do
        f:Hide()
    end
    FP.HideBlips()
    FP.empty:Hide()
    FP.fixHint:Hide()
    FP.fixBtn:Hide()
    -- NB: do NOT invalidate the fit here. The transform persists across builds and
    -- is only invalidated by the explicit reframe events (open, house change,
    -- canvas resize, reset, zone changes). Nulling it every build would make the
    -- lazy EnsureFit below refit on every redraw, including each Grow/Move/Shrink
    -- and every drag step, which is exactly the feedback loop this design removes.

    local h = FP.CurrentHouse()

    if h and h.owner then
        FP.sub:SetText(string.format(CH.L["FP_X_HOUSE"], h.owner))
    elseif CH.currentHouseGUID then
        FP.sub:SetText(CH.L["FP_HOME_INTERIOR"])
    else
        FP.sub:SetText(CH.L["FP_NOT_IN_HOUSE"])
    end

    -- A different house reframes to its own bounds and resets the zoom and pan.
    -- Switching floors keeps the shared house-wide frame and your current zoom and
    -- pan, so the view stays put when you take the stairs or page through floors.
    -- A plain rebuild (room edit, dot refresh) leaves everything untouched, which
    -- keeps a dragged handle from chasing a refitting map.
    if CH.currentHouseGUID ~= lastBuiltGuid then
        FP.ResetView()
        FP.InvalidateFit() -- new house: reframe via EnsureFit below
    end
    lastBuiltGuid = CH.currentHouseGUID

    -- Lazily (re)establish the house-wide fit. Only the reframe events invalidate
    -- it (house change above, plus open, reset, canvas resize, and zone changes
    -- elsewhere). A geometry edit never does, so the transform stays frozen while
    -- you drag.
    FP.EnsureFit()

    local floorCount = FP.RefreshFloorControls(h)
    local viewedFloor = CH.fpViewedFloor
    local showStairs = ChamberlainDB.settings.showStairsOnMap

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
        if not FP.ZoneVisible(zone) then
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
        FP.empty:SetText(
            floorCount > 1 and string.format(CH.L["FP_NO_ROOMS_ON_FLOOR_X"], viewedFloor) or CH.L["FP_NO_ROOMS"]
        )
        FP.empty:Show()
        -- Only for a house with nothing saved at all. An empty floor in a house that
        -- does have rooms is just an empty floor, nothing to repair.
        local suggestFix = FP.FixerCandidate()
        FP.fixHint:SetShown(suggestFix)
        FP.fixBtn:SetShown(suggestFix)
        FP.selectedIdx = nil
        FP.RefreshEditPanel()
        FP.PositionHandles()
        return
    end

    -- Selection can go stale when rooms are deleted elsewhere
    if FP.selectedIdx and not h.zones[FP.selectedIdx] then
        FP.selectedIdx = nil
    end

    -- The transform is the shared house-wide fit established by EnsureFit above.
    -- The draw loop maps world to canvas through it. Nothing here recomputes it,
    -- so editing a room never reframes.
    local k = FP.ZoomedScale()
    if not k then
        FP.PositionHandles()
        return -- nothing framed (e.g. all rooms secret to a visitor)
    end

    local selectedIdx = FP.selectedIdx

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
            local px, py = FP.WorldToCanvas(zone.maxX, zone.maxY)
            local zw = (zone.maxX - zone.minX) * k
            local zh = (zone.maxY - zone.minY) * k
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

    FP.ShowPlayerDot()
    FP.UpdateResetButton()
    FP.RefreshEditPanel()
    FP.PositionHandles()
end

-- Reposition the room tiles for the current zoom/pan. The dots, corner markers and
-- player blip follow automatically through the OnUpdate transform, so only the
-- otherwise-static tiles need touching here.
function FP.TileReposition()
    FP.UpdateResetButton()
    local k = FP.ZoomedScale()
    if not k then
        return
    end
    local h = FP.CurrentHouse()
    if not h then
        return
    end
    for _, f in pairs(zonePool) do
        if f:IsShown() and f.zoneIdx then
            local z = h.zones[f.zoneIdx]
            if z then
                local px, py = FP.WorldToCanvas(z.maxX, z.maxY)
                local zw = (z.maxX - z.minX) * k
                local zh = (z.maxY - z.minY) * k
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
    FP.PositionHandles()
end

-- Called from RoomManager when zones change so the floor plan stays in sync
function CH.RebuildFloorPlan()
    if FP.win:IsShown() then
        FP.InvalidateFit() -- zones changed (create/delete/share): reframe to new bounds
        FP.Build()
    end
end

-- Sync the map's selection to a room picked elsewhere (the build toolbox). Pass
-- nil to clear. revealFloor switches the map to the room's floor first, which the
-- toolbox room list wants but a map click does not (you can only click what's
-- shown, and stairs draw on both floors they link). Called through CH.SetSelection,
-- so it never calls back into it.
function CH.FloorPlanSelect(zone, revealFloor)
    local h = FP.CurrentHouse()
    local idx = nil
    if zone and h then
        for i, z in ipairs(h.zones) do
            if z == zone then
                idx = i
                break
            end
        end
    end
    if revealFloor and idx and zone.floor and zone.floor ~= CH.fpViewedFloor then
        CH.fpViewedFloor = zone.floor
    end
    FP.selectedIdx = idx
    if FP.win:IsShown() then
        FP.Build()
    else
        FP.RefreshEditPanel()
    end
end
