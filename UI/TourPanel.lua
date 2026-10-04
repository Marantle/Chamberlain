local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Tour panel  (the owner sets the stops of the house tour)
-- ─────────────────────────────────────────────────────────────────────
-- A side panel in the house map, opened from Tour in the House panel. On top
-- the welcome and the goodbye, then the stops in order with the rest of the
-- rooms under them to add, and the picked stop's yapper at the bottom. The
-- yapper is the room's own, the same fields the room editor writes, so a stop
-- has no words of its own on the wire, only its number. Nothing is kept until
-- Save. The map numbers the rooms by the order here while it's open.

local FP = CH.FP
local W = FP.EDIT_W
local PAD = 12
local LABEL_W = 70
local ROW_H = 22
local LIST_TOP, LIST_BOTTOM = -92, -240

local f = FP.MakePanel("TR_TITLE")
local panel = { frame = f }

local guid -- the house the panel works on
local order = {} -- the stops, in tour order
local ranks = {} -- stop -> its place in order, for the map's numbers
local yaps = {} -- room -> its yapper as edited here, made on first pick
local picked -- the stop whose yapper shows

local function House()
    return ChamberlainDB.houses[guid]
end

local Offered = CH.TourRoom

-- ── Welcome and goodbye ──────────────────────────────────────────────

local function TextBox(labelKey, kind, y)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", PAD, y - 4)
    label:SetWidth(LABEL_W - 6)
    label:SetJustifyH("LEFT")
    label:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
    label:SetText(CH.L[labelKey])
    local box = CH.MakeBox(f, W - 2 * PAD - LABEL_W - 4, CH.HOUSE_TEXT[kind])
    box:SetPoint("TOPLEFT", PAD + LABEL_W + 4, y)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local welcomeBox = TextBox("TR_WELCOME", "tourWelcome", -36)
CH.Tip(welcomeBox, "TR_TT_WELCOME")
local byeBox = TextBox("TR_BYE", "tourBye", -62)
CH.Tip(byeBox, "TR_TT_BYE")

-- ── The stops and the rooms to add ───────────────────────────────────

local listRule = CH.MakeRule(f)
listRule:SetPoint("TOPLEFT", PAD, LIST_TOP + 4)
listRule:SetPoint("TOPRIGHT", -PAD, LIST_TOP + 4)

local scroll, list = CH.MakeScrollList(f, "ChamberlainTourList")
scroll:SetPoint("TOPLEFT", PAD, LIST_TOP)
scroll:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -PAD - 18, LIST_BOTTOM)
list:SetWidth(W - 2 * PAD - 18)

local Render -- the list and the map drawn again after any change
local ShowEditor -- the picked stop's yapper into the boxes

local function Pick(z)
    picked = z
    FP.editZone = z
    -- a stop picked in the list may be on another floor
    CH.fpViewedFloor = z.floor or 1
    ShowEditor()
    Render()
end

local function Move(z, by)
    local i = tIndexOf(order, z)
    local j = i + by
    if j < 1 or j > #order then
        return
    end
    order[i], order[j] = order[j], order[i]
    Render()
end

local function Remove(z)
    table.remove(order, tIndexOf(order, z))
    if picked == z then
        picked = nil
        FP.editZone = nil
        ShowEditor()
    end
    Render()
end

local function Add(z)
    order[#order + 1] = z
    Pick(z)
end

-- A room clicked on the map picks its stop, or joins the tour as the last
-- one. The floor tabs stay on so every floor's rooms can be reached.
function panel.onTile(z)
    if not Offered(z) then
        return false
    end
    if ranks[z] then
        Pick(z)
    else
        Add(z)
    end
    return true
end
panel.tip = "TR_MAP_TIP"

-- A glyph button on a row, its tip and what it does with the row's room.
local function RowButton(row, icon, tip, onClick)
    local b = CH.MakeGlyphButton(row, nil, icon)
    CH.Tip(b, tip)
    b:SetScript("OnClick", function()
        onClick(row.zone)
    end)
    return b
end

-- One row: a stop with its number, the arrows and the remove, a room off the
-- tour with a plus, or a header line with nothing to click.
local rows = {}
local function GetRow(n)
    local row = rows[n]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(n - 1) * ROW_H)
    row:SetPoint("RIGHT")
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.15))
    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.num:SetPoint("LEFT", 2, 0)
    row.num:SetWidth(20)
    row.num:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 28, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.tag:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    row.remove = RowButton(row, "icon-trash", "TR_TT_REMOVE", Remove)
    row.remove:SetPoint("RIGHT", -2, 0)
    row.down = RowButton(row, "arrow-down", "TR_TT_DOWN", function(z)
        Move(z, 1)
    end)
    row.down:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
    row.up = RowButton(row, "arrow-up", "TR_TT_UP", function(z)
        Move(z, -1)
    end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.add = RowButton(row, "icon-plus", "TR_TT_ADD", Add)
    row.add:SetPoint("RIGHT", -2, 0)
    row:SetScript("OnClick", function(self)
        if self.stop then
            Pick(self.zone)
        end
    end)
    rows[n] = row
    return row
end

-- The words of a stop as they stand here, edited or not.
local function TextOf(z)
    local y = yaps[z]
    if y then
        return y.rpText
    end
    return z.rpText
end

local function ShowRow(n, z, stop, header)
    local row = GetRow(n)
    row.zone, row.stop = z, stop
    row.num:SetText(stop and tostring(n) or "")
    row.name:SetText(header or z.name)
    local ink = header and CH.COLORS.gold or stop and CH.COLORS.bannerText or CH.COLORS.muted
    row.name:SetTextColor(CH.RGBA(ink, 1))
    local tag = ""
    if stop and not TextOf(z) then
        tag = CH.L["TR_NO_TEXT"]
    elseif z and (House().floorCount or 1) > 1 then
        tag = string.format(CH.L["TR_FLOOR_X"], z.floor or 1)
    end
    row.tag:SetText(tag)
    row.tag:ClearAllPoints()
    row.tag:SetPoint("RIGHT", stop and row.up or row.add, "LEFT", -6, 0)
    row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
    row.hl:SetShown(stop and z == picked)
    row.up:SetShown(stop)
    row.down:SetShown(stop)
    row.remove:SetShown(stop)
    row.add:SetShown(not stop and not header)
    row:Show()
end

-- ── The picked stop's yapper ─────────────────────────────────────────

local ED_TOP = LIST_BOTTOM - 8
local edRule = CH.MakeRule(f)
edRule:SetPoint("TOPLEFT", PAD, ED_TOP + 4)
edRule:SetPoint("TOPRIGHT", -PAD, ED_TOP + 4)

local edTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
edTitle:SetPoint("TOPLEFT", PAD, ED_TOP - 2)
edTitle:SetWidth(W - 2 * PAD)
edTitle:SetJustifyH("LEFT")
edTitle:SetWordWrap(false)
edTitle:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))

local editor = CreateFrame("Frame", nil, f)
editor:SetPoint("TOPLEFT", PAD, ED_TOP - 20)
editor:SetPoint("BOTTOMRIGHT", -PAD, 44)

local headPicker, UpdateSpeakerHint, UpdateIdHint, idBox, speakerBox

-- A cast head clears the custom id, a custom head of the house fills it in.
headPicker = CH.MakeHeadPicker(editor, function(i, display)
    local y = yaps[picked]
    if display then
        y.headDisplay = display
        idBox:SetText(tostring(display))
        local name = CH.CustomHeadName(House().zones, display)
        if name then
            y.speaker = name
            speakerBox:SetText(name)
        end
    else
        y.headID, y.headDisplay = i, nil
        idBox:SetText("")
    end
    headPicker:Select(y.headID, y.headDisplay)
    UpdateSpeakerHint()
    UpdateIdHint()
end)

-- The house's custom heads, the ones typed on other stops and not saved yet
-- among them, the picked stop's own first.
local unsaved = {}
local function FillHeads()
    wipe(unsaved)
    for _, y in pairs(yaps) do
        unsaved[#unsaved + 1] = y.headDisplay
    end
    local y = yaps[picked]
    headPicker:Fill(y.headDisplay, House().zones, unsaved)
    headPicker:Select(y.headID, y.headDisplay)
end

-- A label and its box on the row under the heads, at x.
local ROW_Y = -headPicker.height - 2
local function FieldLabel(key, x)
    local label = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, ROW_Y - 4)
    label:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
    label:SetText(CH.L[key])
    return label
end

-- The speaker and the custom head id, as in the room editor. An empty
-- speaker shows the picked head's name in grey, the name the yapper uses.
local speakerLabel = FieldLabel("RD_SPEAKER", 0)
speakerBox = CH.MakeBox(editor, 150, 40)
speakerBox:SetPoint("LEFT", speakerLabel, "RIGHT", 6, 0)
speakerBox:SetScript("OnEnterPressed", speakerBox.ClearFocus)
UpdateSpeakerHint = CH.AddPlaceholder(speakerBox, function()
    local y = picked and yaps[picked]
    local head = CH.HEADS[y and y.headID or 1]
    return head and head.name or ""
end)

local idLabel = FieldLabel("RD_CUSTOM_ID", 0)
idLabel:ClearAllPoints()
idLabel:SetPoint("LEFT", speakerBox, "RIGHT", 12, 0)
idBox = CH.MakeBox(editor, 70, 8)
idBox:SetPoint("LEFT", idLabel, "RIGHT", 6, 0)
idBox:SetNumeric(true)
idBox:SetScript("OnEnterPressed", idBox.ClearFocus)
CH.Tip(idBox, "RD_CUSTOM_ID_TT1")
UpdateIdHint = CH.AddPlaceholder(idBox, function()
    return CH.L["RD_CUSTOM_ID_HINT"]
end)
-- a typed id joins the head grid as the stop's own once you're done with it
idBox:HookScript("OnEditFocusLost", function()
    if picked then
        FillHeads()
    end
end)

local textScroll, textBox, UpdateTextHint =
    CH.MakeNoteArea(editor, "ChamberlainTourText", W - 2 * PAD - 22, "RD_DESC_HINT", CH.DESC_MAX)
textScroll:SetPoint("TOPLEFT", 2, ROW_Y - 28)
textScroll:SetPoint("BOTTOMRIGHT", -16, 2)

local Trimmed = CH.BoxText

-- Typing only, a SetText on a pick leaves the edits alone.
speakerBox:HookScript("OnTextChanged", function(self, typed)
    if typed and picked then
        yaps[picked].speaker = Trimmed(self)
    end
end)
idBox:HookScript("OnTextChanged", function(self, typed)
    if typed and picked then
        local y = yaps[picked]
        local n = tonumber(self:GetText())
        y.headDisplay = n and n > 0 and n or nil
        headPicker:Select(y.headID, y.headDisplay)
    end
end)
textBox:HookScript("OnTextChanged", function(self, typed)
    if typed and picked then
        yaps[picked].rpText = Trimmed(self)
    end
end)
-- the no words tag on the row follows what was typed
textBox:HookScript("OnEditFocusLost", function()
    Render()
end)

function ShowEditor()
    editor:SetShown(picked ~= nil)
    if not picked then
        edTitle:SetText(CH.L["TR_PICK_HINT"])
        return
    end
    local y = yaps[picked]
    if not y then
        y = {
            headID = picked.headID or 1,
            headDisplay = picked.headDisplay,
            speaker = picked.speaker,
            rpText = picked.rpText,
        }
        yaps[picked] = y
    end
    edTitle:SetText(string.format(CH.L["TR_YAPPER_X"], picked.name))
    FillHeads()
    speakerBox:SetText(y.speaker or "")
    idBox:SetText(y.headDisplay and tostring(y.headDisplay) or "")
    textBox:SetText(y.rpText or "")
    UpdateSpeakerHint()
    UpdateIdHint()
    UpdateTextHint()
end

-- ── Drawing, saving and leaving ──────────────────────────────────────

local rest = {} -- the rooms off the tour, reused on every draw

local function ByName(a, b)
    return a.name:lower() < b.name:lower()
end

function Render()
    wipe(ranks)
    local n = 0
    for i, z in ipairs(order) do
        ranks[z] = i
        n = n + 1
        ShowRow(n, z, true)
    end
    n = n + 1
    ShowRow(n, nil, false, CH.L[#order == 0 and "TR_NONE_YET" or "TR_OFF_TOUR"])
    -- the rest by name, so a room is found without reading the whole list
    wipe(rest)
    for _, z in ipairs(House().zones) do
        if Offered(z) and not ranks[z] then
            rest[#rest + 1] = z
        end
    end
    table.sort(rest, ByName)
    for _, z in ipairs(rest) do
        n = n + 1
        ShowRow(n, z, false)
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
    end
    list:SetHeight(math.max(1, n * ROW_H))
    FP.Build()
end

-- The numbers the map writes before room names: this panel's order while it
-- is open, the running tour's otherwise, nil for none.
local touring = {}
function FP.TourRanks(h)
    if FP.panel == panel then
        return ranks
    end
    if h and CH.TouringHere(FP.HouseGUID()) then
        return CH.TourRanks(h, touring)
    end
end

-- The yapper fields the panel edits, the room editor's own names.
local YAP = { "headDisplay", "speaker", "rpText" }

-- Whether the yapper y edited here differs from room z.
local function YapDiffers(z, y)
    if y.headID ~= (z.headID or 1) then
        return true
    end
    for _, k in ipairs(YAP) do
        if y[k] ~= z[k] then
            return true
        end
    end
    return false
end

local function Changed()
    local h = House()
    if Trimmed(welcomeBox) ~= h.tourWelcome or Trimmed(byeBox) ~= h.tourBye then
        return true
    end
    for _, z in ipairs(h.zones) do
        if Offered(z) and ranks[z] ~= z.tourStop then
            return true
        end
    end
    for z, y in pairs(yaps) do
        if YapDiffers(z, y) then
            return true
        end
    end
    return false
end

local function Save()
    local h = House()
    -- a stop's number is its place, so the tour on the wire has no gaps
    local touched = false
    for _, z in ipairs(h.zones) do
        if Offered(z) and ranks[z] ~= z.tourStop then
            z.tourStop = ranks[z]
            touched = true
        end
    end
    for z, y in pairs(yaps) do
        if YapDiffers(z, y) then
            z.headID = y.headID
            for _, k in ipairs(YAP) do
                z[k] = y[k]
            end
            touched = true
        end
    end
    if touched then
        CH.TouchHouse(guid)
    end
    CH.SetHouseText(guid, "tourWelcome", welcomeBox:GetText())
    CH.SetHouseText(guid, "tourBye", byeBox:GetText())
    FP.ClosePanel()
end

local foot = FP.PanelFooter(f, "TR_SAVE", Save)

-- Starts the tour as the house has it now, so Save comes first.
local tryBtn = CH.MakeButton(foot, "TR_TRY", 90, 22)
tryBtn:SetPoint("LEFT")
CH.Tip(tryBtn, "TR_TT_TRY")
tryBtn:SetScript("OnClick", function()
    Save()
    CH.StopTour()
    CH.ToggleTour()
end)

-- Hide UI with the map kept on screen keeps the edits.
f:SetScript("OnHide", function(self)
    if CH.OnlyParentHid(self) then
        return
    end
    welcomeBox:ClearFocus()
    byeBox:ClearFocus()
    speakerBox:ClearFocus()
    idBox:ClearFocus()
    textBox:ClearFocus()
    wipe(order)
    wipe(ranks)
    wipe(yaps)
    picked = nil
end)

-- The map left this house of yours, or rooms went away under the panel.
function panel.check()
    local h = House()
    if FP.HouseGUID() ~= guid or not FP.OwnMap() or not h then
        FP.ClosePanel(true)
        return
    end
    for i = #order, 1, -1 do
        if not tIndexOf(h.zones, order[i]) then
            table.remove(order, i)
        end
    end
    if picked and not tIndexOf(h.zones, picked) then
        picked = nil
        FP.editZone = nil
    end
end

function panel.leave(after)
    local function go()
        FP.ClosePanel()
        if after then
            after()
        end
    end
    if Changed() then
        CH.ShowConfirm("TR_TITLE", CH.L["TR_DISCARD_ASK"], "TR_DISCARD", go)
    else
        go()
    end
end

local stops = {}
local function Open()
    guid = CH.currentHouseGUID
    local h = CH.CurrentHouse()
    for i, z in ipairs(CH.TourStops(h, stops)) do
        order[i] = z
    end
    welcomeBox:SetText(h.tourWelcome or "")
    byeBox:SetText(h.tourBye or "")
    FP.OpenPanel(panel, nil)
    ShowEditor()
    Render()
end

-- House panel's Tour button, in your own house only, since the map can only
-- edit the house you stand in.
function CH.OpenTourPanel()
    if not CH.isOwnHouse or not CH.currentHouseGUID or FP.panel == panel then
        return
    end
    if not FP.win:IsShown() or FP.HouseGUID() ~= CH.currentHouseGUID then
        CH.OpenFloorPlan()
    end
    if FP.panel then
        FP.LeavePanel(Open)
    else
        Open()
    end
end
