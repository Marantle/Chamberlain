local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan: live blips (player, corner markers, group members)
-- ─────────────────────────────────────────────────────────────────────

local FP = CH.FP
local canvas = FP.canvas

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

-- Group member dots: class-colored, tooltip with the member's name.
-- UnitPosition only returns coordinates for members in the same instance.
local partyDots = {}

-- Unit tokens built once. The dot loop runs every frame, and rebuilding
-- "raid17" forty times a frame is needless string garbage.
local partyUnits, raidUnits = {}, {}
for i = 1, 4 do
    partyUnits[i] = "party" .. i
end
for i = 1, 40 do
    raidUnits[i] = "raid" .. i
end

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

-- The build pass hides every blip before redrawing and shows the player dot
-- again once the map has tiles.
function FP.HideBlips()
    dotFrame:Hide()
    markerA:Hide()
    markerB:Hide()
end

function FP.ShowPlayerDot()
    dotFrame:Show()
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
    FP.UpdatePanDrag()

    -- The player and party dots live on the active floor. When browsing another
    -- floor, hide every live blip and show a "you're on floor N" reminder instead.
    -- This runs before the scale guard below so the reminder still shows on an
    -- empty floor, which has no scale because there are no rooms to fit.
    if CH.fpViewedFloor ~= (CH.activeFloor or 1) then
        FP.HideBlips()
        for i = 1, #partyDots do
            partyDots[i]:Hide()
        end
        floorHint:SetText(string.format(CH.L["FP_YOURE_ON_FLOOR_X"], CH.activeFloor or 1))
        floorHint:Show()
        return
    end
    floorHint:Hide()

    if not FP.ZoomedScale() then
        return
    end

    local x, y = CH.GetWorldPos()
    if not x then
        dotFrame:Hide()
        return
    end

    if FP.CheckCanvasResize() then
        -- canvas was resized since last build: reframe to the new dimensions
        FP.Build()
        return
    end

    local px, py = FP.WorldToCanvas(x, y)
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
        local ax, ay = FP.WorldToCanvas(CH.pendingA.x, CH.pendingA.y)
        markerA:ClearAllPoints()
        markerA:SetPoint("CENTER", canvas, "TOPLEFT", ax, -ay)
        markerA:Show()
    else
        markerA:Hide()
    end

    if CH.pendingB then
        local bx, by = FP.WorldToCanvas(CH.pendingB.x, CH.pendingB.y)
        markerB:ClearAllPoints()
        markerB:SetPoint("CENTER", canvas, "TOPLEFT", bx, -by)
        markerB:Show()
    else
        markerB:Hide()
    end

    -- party1-4 covers a 5-man, but in a raid those tokens only reach your own
    -- subgroup, so switch to raid units there. raidN includes the player, who
    -- already has the lettered dot above, so their slot is skipped.
    local inRaid = IsInRaid()
    local units = inRaid and raidUnits or partyUnits
    local numUnits = 0
    if ChamberlainDB.settings.showGroupDots then
        numUnits = inRaid and GetNumGroupMembers() or 4
    end
    for i = 1, numUnits do
        local unit = units[i]
        local pd = GetPartyDot(i)
        -- UnitIsVisible is true only when the member is in the same area as us
        -- and in range. A friend in their own (separate) house is not visible,
        -- so this keeps their blip off our floor plan even though all houses
        -- share a map id and reuse similar coordinates.
        local uy, ux = UnitPosition(unit)
        local upx, upy
        if ux and UnitIsVisible(unit) and not UnitIsUnit(unit, "player") then
            upx, upy = FP.WorldToCanvas(ux, uy)
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
    -- Dots past the current roster stay behind after leaving a raid, shrinking
    -- the group, or flipping the setting off. Put them away.
    for i = numUnits + 1, #partyDots do
        partyDots[i]:Hide()
    end
end)
