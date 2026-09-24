local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan window  (top-down view of the current house)
-- ─────────────────────────────────────────────────────────────────────
-- The window is split across UI\FloorPlan\. This file owns the frame, the
-- chrome, and the open/close API. Transform.lua holds the world-to-canvas
-- math and zoom/pan, Floors.lua the floor navigation and add/remove,
-- Tiles.lua the room tiles and the build pass, EditPanel.lua the move and
-- resize logic with the drag grips, Dots.lua the live player and party blips.
-- The rail down the left side is the build toolbox (UI/Toolbox.lua) in your
-- own house and the house card (HouseCard.lua) everywhere else.
--
-- FP (CH.FP) is the table the files talk through. It holds the frames, the
-- shared state and the cross-file functions. Anything not on it is
-- private to its file. Cross-file calls resolve at call time, so the only
-- load-order rule is that this file comes first in the .toc.

local FP = {}
CH.FP = FP

local RAIL_W = 208
local MAP_W = 500
local WIN_H = 520

local fp = CreateFrame("Frame", "ChamberlainFloorPlan", UIParent, "BackdropTemplate")
fp:SetSize(RAIL_W + 1 + MAP_W, WIN_H)
fp:SetFrameStrata("DIALOG")
-- Floor Plan and the Room Manager share the DIALOG strata and overlap. Without
-- this, the other window's child buttons (a higher frame level) bleed through
-- this one's background. SetToplevel makes clicking/showing a window lift its
-- whole subtree above the other.
fp:SetToplevel(true)
CH.MakeDraggable(fp)
CH.SkinWindow(fp, "FP_TITLE", true)
fp:Hide()
table.insert(UISpecialFrames, "ChamberlainFloorPlan")
CH.floorPlan = fp
FP.win = fp

-- Also /rooms reset. The spot isn't saved, so every login starts here.
function CH.ResetMapPos()
    fp:ClearAllPoints()
    fp:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
end
CH.ResetMapPos()

local closeBtn = CH.MakeGlyphButton(fp, "x")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    fp:Hide()
end)

local foldBtn = CH.MakeGlyphButton(fp, "«")
foldBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
foldBtn:SetScript("OnClick", function()
    ChamberlainDB.settings.mapFolded = not ChamberlainDB.settings.mapFolded
    FP.ApplyFold()
end)
CH.Tip(foldBtn, function()
    return ChamberlainDB.settings.mapFolded and "FP_TT_UNFOLD" or "FP_TT_FOLD"
end)

-- Says so in the header when the tools are gone, on a map you can only look at.
local readOnly = CreateFrame("Frame", nil, fp, "BackdropTemplate")
readOnly:SetPoint("LEFT", fp.title, "RIGHT", 8, 0)
readOnly:SetBackdrop(CH.BACKDROP_THIN)
readOnly:SetBackdropColor(0, 0, 0, 0)
readOnly:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.6))
local readOnlyText = readOnly:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
readOnlyText:SetPoint("CENTER")
readOnlyText:SetText(CH.L["FP_READ_ONLY"])
readOnlyText:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
readOnly:SetSize(readOnlyText:GetStringWidth() + 12, 16)
readOnly:Hide()

local rail = CreateFrame("Frame", nil, fp)
rail:SetPoint("TOPLEFT", 0, -26)
rail:SetPoint("BOTTOMLEFT")
rail:SetWidth(RAIL_W)
FP.rail = rail

-- Everything right of the rail. Hidden while folded, and with it the canvas,
-- whose OnUpdate then stops too.
local map = CreateFrame("Frame", nil, fp)
map:SetPoint("TOPLEFT", rail, "TOPRIGHT", 1, 0)
map:SetPoint("BOTTOMRIGHT")
FP.map = map

local divider = map:CreateTexture(nil, "ARTWORK")
divider:SetWidth(1)
divider:SetPoint("TOPRIGHT", map, "TOPLEFT")
divider:SetPoint("BOTTOMRIGHT", map, "BOTTOMLEFT")
divider:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.35))

local fpSub = map:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
fpSub:SetPoint("TOPLEFT", 10, -10)
FP.sub = fpSub

local canvas = CreateFrame("Frame", nil, map)
canvas:SetPoint("TOPLEFT", map, "TOPLEFT", 10, -32)
canvas:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -10, 36)
FP.canvas = canvas

-- on the map, since the canvas clips anything drawn past its edges
local canvasEdge = map:CreateTexture(nil, "BACKGROUND")
canvasEdge:SetPoint("TOPLEFT", canvas, -1, 1)
canvasEdge:SetPoint("BOTTOMRIGHT", canvas, 1, -1)
canvasEdge:SetColorTexture(CH.RGBA(CH.COLORS.border, 0.5))

local canvasBg = canvas:CreateTexture(nil, "BACKGROUND")
canvasBg:SetAllPoints()
canvasBg:SetColorTexture(0.025, 0.02, 0.015, 1)

local fpEmpty = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpEmpty:SetPoint("CENTER")
fpEmpty:SetText(CH.L["FP_NO_ROOMS"])
fpEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
fpEmpty:Hide()
FP.empty = fpEmpty

-- Nudge toward the fixer, shown under the empty state only when this house looks
-- like one that moved (see FixerCandidate). /rooms fixer opens the same window.
local fpFixHint = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpFixHint:SetPoint("TOP", fpEmpty, "BOTTOM", 0, -16)
fpFixHint:SetWidth(280)
fpFixHint:SetJustifyH("CENTER")
fpFixHint:SetWordWrap(true)
fpFixHint:SetSpacing(2)
fpFixHint:SetText(CH.L["FP_FIX_HINT"])
fpFixHint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
fpFixHint:Hide()
FP.fixHint = fpFixHint

local fpFixBtn = CH.MakeButton(canvas, "FIX_TITLE", 110, 22)
fpFixBtn:SetPoint("TOP", fpFixHint, "BOTTOM", 0, -8)
fpFixBtn:SetScript("OnClick", function()
    CH.OpenFixHouse()
end)
fpFixBtn:Hide()
FP.fixBtn = fpFixBtn

-- The other way an owned house comes up empty: its map was put away in the
-- archive (before a reset or a blueprint swap). Points at the archive so the
-- map can be brought back from here. Anchored in FP.Build, since it sits under
-- the fixer nudge when that shows too.
local fpArchiveHint = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpArchiveHint:SetWidth(280)
fpArchiveHint:SetJustifyH("CENTER")
fpArchiveHint:SetWordWrap(true)
fpArchiveHint:SetText(CH.L["FP_ARCHIVE_HINT"])
fpArchiveHint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
fpArchiveHint:Hide()
FP.archiveHint = fpArchiveHint

local fpArchiveBtn = CH.MakeButton(canvas, "FP_OPEN_ARCHIVE", 110, 22)
fpArchiveBtn:SetPoint("TOP", fpArchiveHint, "BOTTOM", 0, -8)
fpArchiveBtn:SetScript("OnClick", function()
    CH.OpenArchive()
end)
fpArchiveBtn:Hide()
FP.archiveBtn = fpArchiveBtn

-- A house of yours that comes up with no rooms while other houses you own do have
-- some is what a moved house looks like: the new neighborhood minted a new id, so
-- every room is still parked under the old one. Suggest the repair instead of
-- leaving a blank map with no explanation.
function FP.FixerCandidate()
    if not FP.CanEdit() or not CH.currentHouseGUID then
        return false
    end
    local cur = ChamberlainDB.houses[CH.currentHouseGUID]
    if cur and cur.zones and #cur.zones > 0 then
        return false
    end
    for guid in pairs(ChamberlainDB.myHouses or {}) do
        if guid ~= CH.currentHouseGUID then
            local other = ChamberlainDB.houses[guid]
            if other and other.zones and #other.zones > 0 then
                return true
            end
        end
    end
    return false
end

-- Shared state and helpers ------------------------------------------------

-- FP.selectedIdx: index into the house's zones of the room picked on the rail
-- (CH.tbSelZone), or nil. Worked out again on every build, read everywhere.

-- Which floor the map is currently showing. Starts on the player's active floor
-- and follows it up and down the stairs. The floor tabs browse the others.
-- Public (not on FP) so the create dialog can default a new room to the floor
-- you're viewing, and Stairs can seed its pickers from it.
CH.fpViewedFloor = 1

-- Set while the map shows a house picked in the Rooms window instead of the one
-- you stand in. That map is read only. It hides the dots and the tools and keeps
-- the floor you picked. Closing the map clears it.
FP.viewGUID = nil

function FP.HouseGUID()
    return FP.viewGUID or CH.currentHouseGUID
end

function FP.CurrentHouse()
    local guid = FP.HouseGUID()
    return guid and ChamberlainDB.houses[guid]
end

-- The edit tools only work on the house you stand in, and only if it's yours.
function FP.CanEdit()
    return CH.isOwnHouse and not FP.viewGUID
end

-- The floor a new room or stair defaults to: the one on the map, unless the map
-- shows another house while a stairs wizard is still open for this one.
function CH.MapFloor()
    if FP.viewGUID then
        return CH.activeFloor or 1
    end
    return CH.fpViewedFloor or CH.activeFloor or 1
end

-- Whether the map shows the owner's view with the secret rooms. Another house
-- of yours gets it too, since its secrets are your own.
function FP.OwnerView()
    if FP.viewGUID then
        return ChamberlainDB.myHouses[FP.viewGUID] ~= nil
    end
    return CH.isOwnHouse
end

-- Secret rooms show only on the owner's own floor plan. Visitors holding the
-- shared layout still get the banner on entry (the room is in thier zone list),
-- but it stays off their map.
function FP.ZoneVisible(zone)
    return FP.OwnerView() or not zone.secret
end

-- OnShow/OnHide also track the open flag, so every close path (the Close button,
-- Escape via UISpecialFrames, /reload tear-down doesn't fire OnHide) keeps the
-- saved state honest without each one having to set it.
fp:SetScript("OnShow", function()
    if ChamberlainDB and ChamberlainDB.settings then
        ChamberlainDB.settings.floorPlanOpen = true
    end
    FP.Build()
end)
fp:SetScript("OnHide", function()
    if ChamberlainDB and ChamberlainDB.settings then
        ChamberlainDB.settings.floorPlanOpen = false
    end
    FP.viewGUID = nil
end)

-- Folded, the window is only the rail: the build tools to carry around the
-- house with the map out of the way. Only your own house folds. The top left
-- corner stays put, so the rail doesn't jump when the map comes and goes.
function FP.ApplyFold()
    local edit = FP.CanEdit()
    local folded = edit and ChamberlainDB.settings.mapFolded
    local w = folded and RAIL_W or RAIL_W + 1 + MAP_W
    local h = folded and FP.foldedHeight or WIN_H
    if fp:GetWidth() ~= w or fp:GetHeight() ~= h then
        local left, top = fp:GetLeft(), fp:GetTop()
        if left then
            fp:ClearAllPoints()
            fp:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        fp:SetSize(w, h)
    end
    map:SetShown(not folded)
    foldBtn:SetShown(edit)
    foldBtn.glyph:SetText(folded and "»" or "«")
    CH.SetWindowTitle(fp, folded and "TB_TITLE" or "FP_TITLE", true)
    readOnly:SetShown(not edit)
end

-- The rail holds the build tools on a map you can edit and the house card on
-- any other. Called from every build pass.
function FP.RefreshRail(h)
    local edit = FP.CanEdit()
    CH.toolbox:SetShown(edit)
    FP.card:SetShown(not edit)
    if edit then
        CH.RefreshToolbox()
    else
        FP.RefreshCard(h)
    end
    FP.ApplyFold()
end

-- guid is a house picked in the Rooms window, nil the one you stand in. Moving
-- between the two starts on floor 1 of the other house, or back on the floor
-- you stand on.
function CH.OpenFloorPlan(guid)
    if guid == CH.currentHouseGUID then
        guid = nil
    end
    if guid ~= FP.viewGUID then
        FP.viewGUID = guid
        CH.fpViewedFloor = guid and 1 or (CH.activeFloor or 1)
    end
    FP.ResetView() -- open at the fitted view
    FP.InvalidateFit() -- reframe on open
    if fp:IsShown() then
        FP.Build()
    else
        fp:Show()
    end
    fp:Raise()
end

-- The bar's Map button opens the whole window or unfolds a folded one, and
-- closes it when your map already shows. A map of another house counts as
-- closed, so the button brings back yours.
function CH.ToggleFloorPlan()
    local s = ChamberlainDB.settings
    if fp:IsShown() and not FP.viewGUID and not (s.mapFolded and FP.CanEdit()) then
        fp:Hide()
    else
        s.mapFolded = false
        CH.OpenFloorPlan()
    end
end

-- The bar's Build button, the other way round: it folds an open map down to
-- the rail and closes the rail when that's all there is.
function CH.OpenToolbox()
    ChamberlainDB.settings.mapFolded = true
    CH.OpenFloorPlan()
end

function CH.ToggleToolbox()
    if fp:IsShown() and not FP.viewGUID and (ChamberlainDB.settings.mapFolded or not FP.CanEdit()) then
        fp:Hide()
    else
        CH.OpenToolbox()
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
