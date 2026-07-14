local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Floor plan window  (top-down view of the current house)
-- ─────────────────────────────────────────────────────────────────────
-- The window is split across UI\FloorPlan\. This file owns the frame, the
-- chrome, and the open/close API. Transform.lua holds the world-to-canvas
-- math and zoom/pan, Floors.lua the floor navigation and add/remove,
-- Tiles.lua the room tiles and the build pass, EditPanel.lua the nudge
-- buttons and drag grips, Dots.lua the live player and party blips.
--
-- FP (CH.FP) is the table the files talk through: the two frames, the
-- selection and viewed-floor state, and the cross-file functions. Anything
-- not on it is private to its file. Cross-file calls resolve at call time,
-- so the only load-order rule is that this file comes first in the .toc.

local FP = {}
CH.FP = FP

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
-- The build toolbox docks onto this frame's right edge (UI/Toolbox.lua).
CH.floorPlan = fp
FP.win = fp

local fpSub = fp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpSub:SetPoint("TOPLEFT", 10, -27)
fpSub:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
FP.sub = fpSub

local canvas = CreateFrame("Frame", nil, fp)
canvas:SetPoint("TOPLEFT", fp, "TOPLEFT", 10, -40)
canvas:SetPoint("BOTTOMRIGHT", fp, "BOTTOMRIGHT", -10, 124)
FP.canvas = canvas

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

-- A house of yours that comes up with no rooms while other houses you own do have
-- some is what a moved house looks like: the new neighborhood minted a new id, so
-- every room is still parked under the old one. Suggest the repair instead of
-- leaving a blank map with no explanation.
function FP.FixerCandidate()
    if not CH.isOwnHouse or not CH.currentHouseGUID then
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

local fpClose = CH.MakeButton(fp, "FP_CLOSE", 80, 22)
-- Bottom-right so it never collides with the Add floor / Add stairs buttons that
-- sit at the bottom-left for your own house.
fpClose:SetPoint("BOTTOMRIGHT", fp, "BOTTOMRIGHT", -10, 10)
fpClose:SetScript("OnClick", function()
    fp:Hide()
end)

-- Shared state and helpers ------------------------------------------------

-- FP.selectedIdx: index into the house's zones of the room selected for editing,
-- or nil. Set by tile clicks and CH.FloorPlanSelect, read everywhere.

-- Which floor the map is currently showing. Starts on the player's active floor
-- and follows it up and down the stairs. The +/- arrows browse other floors.
-- Public (not on FP) so the create dialog can default a new room to the floor
-- you're viewing, and Stairs can seed its pickers from it.
CH.fpViewedFloor = 1

function FP.CurrentHouse()
    return CH.currentHouseGUID and ChamberlainDB.houses[CH.currentHouseGUID]
end

-- Secret rooms show only on the owner's own floor plan. Visitors holding the
-- shared layout still get the banner on entry (the room is in thier zone list),
-- but it stays off their map.
function FP.ZoneVisible(zone)
    return CH.isOwnHouse or not zone.secret
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
    -- A docked toolbox is part of this window, so closing the map puts it away
    -- too. Without the explicit Hide it would pop back the next time the map
    -- alone is opened, and the Map button is supposed to open just the map.
    if CH.toolbox and CH.toolbox:GetParent() == fp and CH.toolbox:IsShown() then
        CH.toolbox:Hide()
    end
end)

function CH.OpenFloorPlan()
    FP.ResetView() -- open at the fitted view
    FP.InvalidateFit() -- reframe on open
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
