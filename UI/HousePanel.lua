local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- House panel  (everything set for a whole house of yours, in one place)
-- ─────────────────────────────────────────────────────────────────────
-- The house icon on the bar opens it for the house you stand in, House in the
-- Rooms window for the one picked there. Each row is a setting with its help
-- under the name and its control on the right. The house map keeps the floor
-- sounds, since those hang on a floor.

local W = 460
local PAD = 14
local CONTROL_W = 150

local win = CreateFrame("Frame", "ChamberlainHouse", UIParent, "BackdropTemplate")
win:SetWidth(W)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:SetPoint("CENTER")
CH.MakeDraggable(win)
CH.SkinWindow(win, "HP_TITLE", true)
win:Hide()
table.insert(UISpecialFrames, "ChamberlainHouse")

local closeBtn = CH.MakeGlyphButton(win, "x")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    win:Hide()
end)
-- a preview left playing would folow you out of the panel
win:SetScript("OnHide", CH.StopAmbiencePreview)

local guid -- the house the panel shows
local refreshers = {}

local body = CreateFrame("Frame", nil, win)
body:SetPoint("TOPLEFT", PAD, -34)
body:SetPoint("TOPRIGHT", -PAD, -34)
local y = 0

-- A row of CH.MakeSettingRow. extraH is room kept at the bottom for controls
-- that don't fit on the right.
local function Row(labelKey, hintKey, extraH)
    local row, h = CH.MakeSettingRow(body, y, 0, W - 2 * PAD, labelKey, hintKey, CONTROL_W)
    h = math.max(h, 38) + (extraH or 0)
    row:SetHeight(h)
    y = y + h
    return row
end

-- The control on the right of a row, a button whose label is the current pick.
local function Control(row)
    local btn = CH.MakeButton(row, "HP_NONE", CONTROL_W, 22)
    btn:SetPoint("TOPRIGHT", 0, -8)
    local fs = btn:GetFontString()
    fs:SetWidth(CONTROL_W - 14)
    fs:SetWordWrap(false)
    return btn
end

local function House()
    return ChamberlainDB.houses[guid]
end

-- The owner's two texts, the name and the motto, each a box with Preview and
-- Save under its row. A box gets its text when the panel opens, never on a
-- refresh, or a change coming in would wipe what you are typing. Preview
-- shows both boxes as they stand.
local boxes = {}

local function Preview()
    CH.ShowPlaque(guid, { plaqueName = boxes.plaqueName:GetText(), motto = boxes.motto:GetText() })
end

local function TextRow(labelKey, hintKey, kind)
    local row = Row(labelKey, hintKey, 30)
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetPoint("BOTTOMLEFT", 6, 10)
    box:SetSize(W - 2 * PAD - 6 - 2 * 68, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(CH.HOUSE_TEXT[kind])
    local function save()
        CH.SetHouseText(guid, kind, box:GetText())
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", save)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    local saveBtn = CH.MakeButton(row, "HP_SAVE", 64, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", 0, 9)
    saveBtn:SetScript("OnClick", save)
    local previewBtn = CH.MakeButton(row, "HP_PREVIEW", 64, 22)
    previewBtn:SetPoint("RIGHT", saveBtn, "LEFT", -4, 0)
    previewBtn:SetScript("OnClick", Preview)
    boxes[kind] = box
    return box
end

-- An empty name box shows the game's name in grey, which is what the plaque
-- falls back to.
local nameBox = TextRow("HP_NAME", "HP_HINT_NAME", "plaqueName")
local gameName = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
gameName:SetPoint("LEFT", 2, 0)
nameBox:HookScript("OnTextChanged", function(self)
    gameName:SetShown(self:GetText() == "")
end)
refreshers[#refreshers + 1] = function()
    gameName:SetText(CH.GameHouseName(guid) or CH.L["HP_NO_NAME"])
end

-- Banner style, picked in the same list Settings opens.
local bannerBtn = Control(Row("HP_BANNER", "HP_HINT_BANNER"))
bannerBtn:SetScript("OnClick", function()
    CH.OpenBannerPicker(guid)
end)
refreshers[#refreshers + 1] = function()
    bannerBtn:SetText((CH.BannerPickText(House().bannerStyle)))
end

TextRow("HP_MOTTO", "HP_HINT_MOTTO", "motto")

-- A row whose button opens the music picker, for the arrival sound and the
-- music. forSounds as in CH.OpenMusicPicker.
local function PickerRow(labelKey, hintKey, kind, forSounds, extraH)
    local row = Row(labelKey, hintKey, extraH)
    local btn = Control(row)
    btn:SetScript("OnClick", function()
        CH.OpenMusicPicker(CH.GetHouseSound(guid, kind), function(picked)
            CH.SetHouseSound(guid, kind, nil, picked)
        end, House(), forSounds)
    end)
    refreshers[#refreshers + 1] = function()
        local id = CH.GetHouseSound(guid, kind)
        btn:SetText(id and CH.SoundName(id, true) or CH.L["HP_NONE"])
    end
    return row, btn
end

PickerRow("HP_ARRIVAL", "HP_HINT_ARRIVAL", "arrival", "arrival")

local ambienceRow = Row("HP_AMBIENCE", "HP_HINT_AMBIENCE")
local ambienceBtn = CH.MakeMenuButton(ambienceRow, CONTROL_W, "HP_NONE", function()
    local picked = CH.AMBIENCE[CH.GetHouseSound(guid, "ambience")]
    return picked and CH.L[picked.key]
end, function(root)
    CH.FillAmbienceMenu(root, function()
        return CH.GetHouseSound(guid, "ambience")
    end, function(index)
        CH.SetHouseSound(guid, "ambience", nil, index)
    end)
end, CH.StopAmbiencePreview)
ambienceBtn:SetPoint("TOPRIGHT", 0, -8)
refreshers[#refreshers + 1] = function()
    ambienceBtn:Refresh()
end

-- Silence for the whole house is the way to get the game's music out of the
-- way, so it gets a button of its own while the house has no music at all.
local musicRow, musicBtn = PickerRow("HP_MUSIC", "HP_HINT_MUSIC", "music", nil, 22)
local silenceBtn = CH.MakeButton(musicRow, "HP_USE_SILENCE", CONTROL_W, 22)
silenceBtn:SetPoint("TOP", musicBtn, "BOTTOM", 0, -4)
silenceBtn:SetScript("OnClick", function()
    CH.SetHouseSound(guid, "music", nil, CH.SILENCE)
end)
refreshers[#refreshers + 1] = function()
    silenceBtn:SetShown(CH.GetHouseSound(guid, "music") == nil)
end

-- without a height the body has no rect and nothing hung off it gets drawn
body:SetHeight(y)
win:SetHeight(34 + y + 12)

function CH.RefreshHousePanel()
    if win:IsShown() and House() then
        for _, fn in ipairs(refreshers) do
            fn()
        end
    end
end

function CH.OpenHousePanel(g)
    guid = g
    for kind, box in pairs(boxes) do
        box:SetText(House()[kind] or "")
    end
    win:Show()
    win:Raise()
    CH.RefreshHousePanel()
end

-- The bar's icon: open on the house you stand in, or close it again.
function CH.ToggleHousePanel()
    if win:IsShown() and guid == CH.currentHouseGUID then
        win:Hide()
    else
        CH.CurrentHouse()
        CH.OpenHousePanel(CH.currentHouseGUID)
    end
end
