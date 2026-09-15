local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Archive window  (stored maps of your houses)
-- ─────────────────────────────────────────────────────────────────────
-- The data and the game hooks live in Housing/Archive.lua. This is the window,
-- a strip about the map in the house right now with the stored maps under it
-- grouped by house. The name dialog every store goes through and the small
-- prompt that follows a house reset live here too. Built on frist open, like
-- the fixer.

local ROW_H = 40
local HEADER_H = 20
local win, scroll, scrollChild, emptyLabel, nowStrip
local headerPool, rowPool = {}, {}

-- The live entry of the house being stood in, if it is yours.
local function OwnHouse()
    local key = CH.isOwnHouse and CH.currentHouseGUID
    return key and ChamberlainDB.houses[key], key
end

-- ─────────────────────────────────────────────────────────────────────
-- Name dialog  (store, put away before a switch, rename)
-- ─────────────────────────────────────────────────────────────────────
-- One dialog. The mode picks the words and the buttons. Store and put-away
-- also carry the blueprint picker, so a map can be named after the blueprint
-- it belongs with.

local MODES = {
    store = {
        title = "AR_TITLE_STORE",
        hint = "AR_HINT_STORE",
        primary = "AR_STORE",
        second = "AR_STORE_CLEAR",
        picker = true,
    },
    putaway = {
        title = "AR_TITLE_PUTAWAY",
        hint = "AR_HINT_PUTAWAY",
        primary = "AR_STORE_SWITCH",
        second = "AR_SWITCH_ANYWAY",
        picker = true,
    },
    rename = { title = "AR_TITLE_RENAME", hint = "AR_HINT_RENAME", primary = "AR_SAVE" },
}

local dlg
local pending -- { mode, house, id, blueprint, go } for the open dialog

local function FillBlueprintMenu(root, btn)
    root:CreateRadio(CH.L["AR_NO_BLUEPRINT"], function()
        return pending.blueprint == nil
    end, function()
        pending.blueprint = nil
        btn:Refresh()
    end)
    local list = CH.HouseBlueprints()
    if #list == 0 then
        root:CreateButton(CH.L["AR_NO_BLUEPRINTS"]):SetEnabled(false)
    end
    for _, bp in ipairs(list) do
        root:CreateRadio(bp.name, function()
            return pending.blueprint ~= nil and pending.blueprint.code == bp.code
        end, function()
            pending.blueprint = { code = bp.code, name = bp.name }
            if dlg.box:GetText() == "" then
                dlg.box:SetText(bp.name)
            end
            btn:Refresh()
        end)
    end
end

-- `second` is the mode's second button: Store and clear, or Switch without
-- storing. Rename has none.
local function Confirm(second)
    local name = dlg.box:GetText()
    local p = pending
    dlg:Hide()
    if p.mode == "rename" then
        CH.ArchiveRename(p.id, name)
    elseif p.mode == "putaway" then
        if not second then
            CH.ArchiveStore(p.house, name, p.blueprint)
        end
        p.go()
    elseif CH.ArchiveStore(p.house, name, p.blueprint) and second then
        CH.ArchiveClear(p.house)
    end
end

local function BuildNameDialog()
    dlg = CreateFrame("Frame", "ChamberlainArchiveName", UIParent, "BackdropTemplate")
    dlg:SetSize(380, 160)
    -- The blueprint menu opens on DIALOG, so on FULLSCREEN_DIALOG this dialog
    -- would cover its own menu. Toplevel lifts it over the archive window instead.
    dlg:SetFrameStrata("DIALOG")
    dlg:SetToplevel(true)
    dlg:SetPoint("CENTER")
    CH.MakeDraggable(dlg)
    CH.SkinWindow(dlg, "AR_TITLE", true)
    dlg:Hide()
    table.insert(UISpecialFrames, "ChamberlainArchiveName")

    dlg.hint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.hint:SetPoint("TOPLEFT", 14, -32)
    dlg.hint:SetPoint("TOPRIGHT", -14, -32)
    dlg.hint:SetJustifyH("LEFT")
    dlg.hint:SetWordWrap(true)
    dlg.hint:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

    dlg.box = CreateFrame("EditBox", "ChamberlainArchiveNameBox", dlg, "InputBoxTemplate")
    dlg.box:SetSize(340, 20)
    dlg.box:SetPoint("TOP", 4, -74)
    dlg.box:SetAutoFocus(false)
    dlg.box:SetMaxLetters(48)
    dlg.box:SetScript("OnEscapePressed", function()
        dlg:Hide()
    end)
    dlg.box:SetScript("OnEnterPressed", function()
        Confirm(false)
    end)

    dlg.bpLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.bpLabel:SetPoint("TOPLEFT", 22, -106)
    dlg.bpLabel:SetText(CH.L["AR_BLUEPRINT"])
    dlg.bpBtn = CH.MakeMenuButton(dlg, 220, "AR_NO_BLUEPRINT", function()
        return pending and pending.blueprint and pending.blueprint.name
    end, FillBlueprintMenu)
    dlg.bpBtn:SetPoint("LEFT", dlg.bpLabel, "RIGHT", 8, 0)

    dlg.cancel = CH.MakeButton(dlg, "AR_CANCEL", 64, 22)
    dlg.cancel:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -10, 10)
    dlg.cancel:SetScript("OnClick", function()
        dlg:Hide()
    end)
    dlg.second = CH.MakeButton(dlg, "AR_STORE_CLEAR", 150, 22)
    dlg.second:SetPoint("RIGHT", dlg.cancel, "LEFT", -4, 0)
    dlg.second:SetScript("OnClick", function()
        Confirm(true)
    end)
    dlg.primary = CH.MakeButton(dlg, "AR_STORE", 120, 22)
    dlg.primary:SetScript("OnClick", function()
        Confirm(false)
    end)
end

local function OpenNameDialog(mode, houseKey, opts)
    if not dlg then
        BuildNameDialog()
    end
    local m = MODES[mode]
    pending = { mode = mode, house = houseKey, id = opts.id, blueprint = opts.blueprint, go = opts.go }
    CH.SetWindowTitle(dlg, m.title, true)
    dlg.hint:SetText(CH.L[m.hint])
    dlg.box:SetText(opts.name or "")
    dlg.primary:SetText(CH.L[m.primary])
    dlg.second:SetShown(m.second ~= nil)
    if m.second then
        dlg.second:SetText(CH.L[m.second])
    end
    dlg.primary:ClearAllPoints()
    dlg.primary:SetPoint("RIGHT", m.second and dlg.second or dlg.cancel, "LEFT", -4, 0)

    -- The picker needs the 12.1 blueprint API. Without it the row is gone and
    -- the dialog shrinks to just the name.
    local picker = m.picker and C_HousingBlueprint ~= nil
    dlg.bpLabel:SetShown(picker)
    dlg.bpBtn:SetShown(picker)
    dlg:SetHeight(picker and 160 or 130)
    if picker then
        dlg.bpBtn:Refresh()
        CH.RequestBlueprints(function()
            -- A code handed in by the save hook has no name until the collection
            -- says which blueprint it is. Fill the name in once it does.
            local bp = pending and pending.blueprint
            if bp and not bp.name then
                for _, known in ipairs(CH.HouseBlueprints()) do
                    if known.code == bp.code then
                        bp.name = known.name
                    end
                end
                if bp.name and dlg.box:GetText() == "" then
                    dlg.box:SetText(bp.name)
                end
            end
            dlg.bpBtn:Refresh()
        end)
    end
    dlg:Show()
    dlg:Raise()
    dlg.box:SetFocus()
    dlg.box:HighlightText()
end

-- Store the live map of a house. `blueprint` is optional. The save hook passes
-- a bare { code } and the picker fills the rest.
function CH.OpenArchiveStore(houseKey, blueprint)
    OpenNameDialog("store", houseKey, { blueprint = blueprint })
end

-- Restore and clear both go through here. An edited live map gets the put-away
-- question first, while one that is stored as-is (or empty) switches at once.
local function Switch(houseKey, go)
    local h = ChamberlainDB.houses[houseKey]
    if h and h.zones and #h.zones > 0 and not CH.ArchiveInStep(h) then
        OpenNameDialog("putaway", houseKey, { go = go })
    else
        go()
    end
end

-- Bring a stored map back, asking about the current one first if it needs
-- asking. Into its own house unless `houseKey` says otherwise. The rows use
-- it, and so does the blueprint load hook.
function CH.ArchiveSwitchTo(id, houseKey)
    local e = CH.ArchiveFind(id)
    if not e then
        return
    end
    houseKey = houseKey or e.house
    Switch(houseKey, function()
        CH.ArchiveRestore(id, houseKey)
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- Reset prompt
-- ─────────────────────────────────────────────────────────────────────
-- Shown by the reset hook: the house was emptied by the game while the map
-- still has rooms in it.

local resetDlg

local function BuildResetPrompt()
    resetDlg = CreateFrame("Frame", "ChamberlainArchiveReset", UIParent, "BackdropTemplate")
    resetDlg:SetSize(340, 112)
    resetDlg:SetFrameStrata("FULLSCREEN_DIALOG")
    resetDlg:SetToplevel(true)
    resetDlg:SetPoint("TOP", UIParent, "TOP", 0, -220)
    CH.MakeDraggable(resetDlg)
    CH.SkinWindow(resetDlg, "AR_TITLE_RESET", true)
    resetDlg:Hide()
    table.insert(UISpecialFrames, "ChamberlainArchiveReset")

    resetDlg.body = resetDlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetDlg.body:SetPoint("TOP", 0, -32)
    resetDlg.body:SetWidth(310)
    resetDlg.body:SetJustifyH("CENTER")
    resetDlg.body:SetWordWrap(true)

    local store = CH.MakeButton(resetDlg, "AR_STORE", 80, 22)
    local clear = CH.MakeButton(resetDlg, "AR_CLEAR", 100, 22)
    local keep = CH.MakeButton(resetDlg, "AR_KEEP", 64, 22)
    clear:SetPoint("BOTTOM", resetDlg, "BOTTOM", 0, 10)
    store:SetPoint("RIGHT", clear, "LEFT", -4, 0)
    keep:SetPoint("LEFT", clear, "RIGHT", 4, 0)
    store:SetScript("OnClick", function()
        resetDlg:Hide()
        CH.OpenArchiveStore(resetDlg.house) -- Store and clear sits right in that dialog
    end)
    clear:SetScript("OnClick", function()
        resetDlg:Hide()
        CH.ArchiveClear(resetDlg.house)
    end)
    keep:SetScript("OnClick", function()
        resetDlg:Hide()
    end)
end

function CH.OpenArchiveResetPrompt(houseKey, count)
    if not resetDlg then
        BuildResetPrompt()
    end
    resetDlg.house = houseKey
    resetDlg.body:SetText(string.format(CH.L["AR_RESET_BODY_X"], count))
    resetDlg:Show()
    resetDlg:Raise()
end

-- ─────────────────────────────────────────────────────────────────────
-- Window
-- ─────────────────────────────────────────────────────────────────────

-- The strip about the house you're in. It names the house, counts the live
-- map's rooms and floors and says whether that map is stored as it stands.
local function RefreshNow()
    local h, key = OwnHouse()
    local rooms = h and h.zones and #h.zones or 0
    if not h then
        nowStrip.line1:SetText(CH.L["AR_NOW_AWAY"])
        nowStrip.line2:SetText(CH.L["AR_NOW_AWAY_HINT"])
    elseif rooms == 0 then
        nowStrip.line1:SetText(CH.ArchiveHouseLabel(h.owner))
        nowStrip.line2:SetText(CH.L["AR_NOW_EMPTY"])
    else
        local stored = CH.ArchiveInStep(h)
        local was = h.archived and CH.ArchiveFind(h.archived.id) -- the entry it drifted from
        local status
        if stored then
            status = string.format(CH.L["AR_STATUS_STORED_X"], stored.name)
        elseif was then
            status = string.format(CH.L["AR_STATUS_CHANGED_X"], was.name)
        else
            status = CH.L["AR_STATUS_UNSTORED"]
        end
        nowStrip.line1:SetText(CH.ArchiveHouseLabel(h.owner))
        nowStrip.line2:SetText(string.format(CH.L["AR_NOW_X"], rooms, h.floorCount or 1) .. "  " .. status)
    end
    nowStrip.storeBtn:SetEnabled(rooms > 0)
    nowStrip.clearBtn:SetEnabled(rooms > 0)
    nowStrip.key = key
end

local function MakeHeader()
    local hdr = CreateFrame("Frame", nil, scrollChild)
    hdr:SetHeight(HEADER_H)
    hdr.label = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr.label:SetPoint("LEFT", 4, 0)
    hdr.label:SetPoint("RIGHT", -4, 0)
    hdr.label:SetJustifyH("LEFT")
    hdr.label:SetWordWrap(false)
    hdr.label:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    return hdr
end

local function MakeRow()
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 6, -5)
    row.name:SetPoint("RIGHT", row, "RIGHT", -246, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.info:SetPoint("BOTTOMLEFT", 6, 5)
    row.info:SetPoint("RIGHT", row, "RIGHT", -246, 0)
    row.info:SetJustifyH("LEFT")
    row.info:SetWordWrap(false)
    row.info:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

    row.delBtn = CH.MakeButton(row, "AR_DELETE", 52, 20)
    row.delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.renBtn = CH.MakeButton(row, "AR_RENAME", 58, 20)
    row.renBtn:SetPoint("RIGHT", row.delBtn, "LEFT", -4, 0)
    row.resBtn = CH.MakeButton(row, "AR_RESTORE", 70, 20)
    row.resBtn:SetPoint("RIGHT", row.renBtn, "LEFT", -4, 0)
    -- Shown on maps of your other houses while you stand in one of yours. It
    -- puts those rooms into this house instead of the one they came from.
    row.hereBtn = CH.MakeButton(row, "AR_HERE", 48, 20)
    row.hereBtn:SetPoint("RIGHT", row.resBtn, "LEFT", -4, 0)
    CH.Tip(row.hereBtn, "AR_HERE_TT")
    return row
end

-- Delete is a backup going away, so it takes two clicks. The first turns the
-- button into "Sure?" for a few seconds and the second deletes.
local function ArmDelete(row, id)
    row.armedId = id
    row.delBtn:SetText(CH.L["AR_SURE"])
    C_Timer.After(3, function()
        if row.armedId == id then
            row.armedId = nil
            row.delBtn:SetText(CH.L["AR_DELETE"])
        end
    end)
end

-- `hereKey` is the house Here would put this map into, nil hides the button.
local function FillRow(row, e, inUse, striped, hereKey)
    row.armedId = nil
    row.delBtn:SetText(CH.L["AR_DELETE"])
    row.bg:SetColorTexture(0, 0, 0, striped and 0.18 or 0)
    row.name:SetText(e.name)
    local info = string.format(CH.L["AR_ROW_INFO_X"], #e.zones, e.floorCount or 1, date("%Y-%m-%d", e.savedAt or 0))
    if e.blueprint then
        info = info .. string.format(CH.L["AR_ROW_BLUEPRINT_X"], e.blueprint.name or e.blueprint.code)
    end
    row.info:SetText(info)

    row.resBtn:SetText(inUse and CH.L["AR_IN_USE"] or CH.L["AR_RESTORE"])
    row.resBtn:SetEnabled(not inUse)
    row.resBtn:SetScript("OnClick", function()
        CH.ArchiveSwitchTo(e.id)
    end)
    row.hereBtn:SetShown(hereKey ~= nil)
    row.hereBtn:SetScript("OnClick", function()
        CH.ArchiveSwitchTo(e.id, hereKey)
    end)
    row.renBtn:SetScript("OnClick", function()
        OpenNameDialog("rename", e.house, { id = e.id, name = e.name })
    end)
    row.delBtn:SetScript("OnClick", function()
        if row.armedId == e.id then
            CH.ArchiveDelete(e.id)
        else
            ArmDelete(row, e.id)
        end
    end)
end

local function Build()
    win = CreateFrame("Frame", "ChamberlainArchive", UIParent, "BackdropTemplate")
    win:SetSize(440, 470)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "AR_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainArchive")

    local sub = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 12, -30)
    sub:SetPoint("TOPRIGHT", -12, -30)
    sub:SetJustifyH("LEFT")
    sub:SetText(CH.L["AR_SUBTITLE"])
    sub:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))

    nowStrip = CreateFrame("Frame", nil, win, "BackdropTemplate")
    nowStrip:SetPoint("TOPLEFT", 10, -48)
    nowStrip:SetPoint("TOPRIGHT", -10, -48)
    nowStrip:SetHeight(46)
    nowStrip:SetBackdrop(CH.BACKDROP_THIN)
    nowStrip:SetBackdropColor(0, 0, 0, 0.35)
    nowStrip:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.7))

    nowStrip.clearBtn = CH.MakeButton(nowStrip, "AR_CLEAR", 88, 20)
    nowStrip.clearBtn:SetPoint("RIGHT", nowStrip, "RIGHT", -6, 0)
    nowStrip.clearBtn:SetScript("OnClick", function()
        local key = nowStrip.key
        Switch(key, function()
            CH.ArchiveClear(key)
        end)
    end)
    nowStrip.storeBtn = CH.MakeButton(nowStrip, "AR_STORE", 64, 20)
    nowStrip.storeBtn:SetPoint("RIGHT", nowStrip.clearBtn, "LEFT", -4, 0)
    nowStrip.storeBtn:SetScript("OnClick", function()
        CH.OpenArchiveStore(nowStrip.key)
    end)

    nowStrip.line1 = nowStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nowStrip.line1:SetPoint("TOPLEFT", 8, -7)
    nowStrip.line1:SetPoint("RIGHT", nowStrip.storeBtn, "LEFT", -8, 0)
    nowStrip.line1:SetJustifyH("LEFT")
    nowStrip.line1:SetWordWrap(false)
    nowStrip.line1:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    nowStrip.line2 = nowStrip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nowStrip.line2:SetPoint("BOTTOMLEFT", 8, 7)
    nowStrip.line2:SetPoint("RIGHT", nowStrip.storeBtn, "LEFT", -8, 0)
    nowStrip.line2:SetJustifyH("LEFT")
    nowStrip.line2:SetWordWrap(false)
    nowStrip.line2:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))

    scroll, scrollChild = CH.MakeScrollList(win, "ChamberlainArchiveScroll")
    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -104)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 44)

    emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOP", 0, -16)
    emptyLabel:SetWidth(360)
    emptyLabel:SetJustifyH("CENTER")
    emptyLabel:SetWordWrap(true)
    emptyLabel:SetSpacing(2)
    emptyLabel:SetText(CH.L["AR_EMPTY"])
    emptyLabel:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    emptyLabel:Hide()

    local close = CH.MakeButton(win, "AR_CLOSE", 80, 22)
    close:SetPoint("BOTTOM", win, "BOTTOM", 0, 12)
    close:SetScript("OnClick", function()
        win:Hide()
    end)
end

local function Populate()
    RefreshNow()
    for _, hdr in ipairs(headerPool) do
        hdr:Hide()
    end
    for _, row in ipairs(rowPool) do
        row:Hide()
    end

    local w = scroll:GetWidth() - 20
    if w <= 10 then
        w = 380
    end
    scrollChild:SetWidth(w)

    -- Group by house, the house you're standing in first, the rest by name. The
    -- label follows the live entry where there is one, so a house another of
    -- your characters took over reads by its owner now, not at store time.
    local groups, order = {}, {}
    for _, e in ipairs(CH.ArchiveEntries(nil)) do
        local g = groups[e.house]
        if not g then
            local live = ChamberlainDB.houses[e.house]
            g = { house = e.house, label = CH.ArchiveHouseLabel((live or e).owner), entries = {} }
            groups[e.house] = g
            order[#order + 1] = g
        end
        g.entries[#g.entries + 1] = e
    end
    table.sort(order, function(a, b)
        if a.house == CH.currentHouseGUID then
            return true
        end
        if b.house == CH.currentHouseGUID then
            return false
        end
        return a.label < b.label
    end)

    -- A map restored into the house you're in is in use there, whichever house
    -- it came from.
    local here, hereKey = OwnHouse()
    local hereStep = here and CH.ArchiveInStep(here)

    local y, hdrIdx, rowIdx, total = 0, 0, 0, 0
    for _, g in ipairs(order) do
        hdrIdx = hdrIdx + 1
        local hdr = headerPool[hdrIdx]
        if not hdr then
            hdr = MakeHeader()
            headerPool[hdrIdx] = hdr
        end
        hdr.label:SetText(g.label)
        hdr:SetWidth(w)
        hdr:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        hdr:Show()
        y = y + HEADER_H

        local inStep = CH.ArchiveInStep(ChamberlainDB.houses[g.house])
        local hereFor = g.house ~= hereKey and hereKey or nil
        for i, e in ipairs(g.entries) do
            rowIdx = rowIdx + 1
            local row = rowPool[rowIdx]
            if not row then
                row = MakeRow()
                rowPool[rowIdx] = row
            end
            row:SetWidth(w)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            row:Show()
            local inUse = (inStep ~= nil and inStep.id == e.id) or (hereStep ~= nil and hereStep.id == e.id)
            FillRow(row, e, inUse, i % 2 == 0, hereFor)
            y = y + ROW_H
            total = total + 1
        end
        y = y + 6
    end

    scrollChild:SetHeight(math.max(y, 1))
    emptyLabel:SetShown(total == 0)
end

function CH.OpenArchive()
    if not win then
        Build()
    end
    Populate()
    win:Show()
    win:Raise()
end

function CH.ToggleArchive()
    if win and win:IsShown() then
        win:Hide()
    else
        CH.OpenArchive()
    end
end

-- Called from the data side after anything in the archive or the live map
-- moved, so an open window never shows a stale list.
function CH.RefreshArchive()
    if win and win:IsShown() then
        Populate()
    end
end
