local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Shared utilities
-- ─────────────────────────────────────────────────────────────────────

-- Flat dark button with gold text and a thin bronze border, modeled on the
-- 12.x housing UI. Border and fill brighen on hover, dim when disabled.
local BTN = {
    fill = { 0.11, 0.09, 0.06, 0.92 },
    fillHover = { 0.18, 0.15, 0.09, 0.95 },
    fillDown = { 0.05, 0.04, 0.03, 1.00 },
    fillOn = { 0.36, 0.29, 0.07, 0.95 },
    edge = { 0.55, 0.45, 0.15, 0.80 },
    edgeHover = { 0.95, 0.80, 0.25, 1.00 },
    edgeOff = { 0.30, 0.26, 0.16, 0.50 },
}

function CH.MakeButton(parent, key, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(CH.BACKDROP_THIN)
    b:SetBackdropColor(unpack(BTN.fill))
    b:SetBackdropBorderColor(unpack(BTN.edge))
    b:SetNormalFontObject(GameFontNormalSmall) -- gold
    b:SetHighlightFontObject(GameFontHighlightSmall) -- white on hover
    b:SetDisabledFontObject(GameFontDisableSmall)
    b:SetText(CH.L[key])

    -- Bound the label to the button so a longer translation truncates with an
    -- ellipsis instead of spilling past the edge. The full text shows on hover
    -- (below) when it is actually cut off.
    local fs = b:GetFontString()
    if fs then
        fs:SetWordWrap(false)
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", 4, 0)
        fs:SetPoint("RIGHT", -4, 0)
    end

    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(unpack(BTN.fillHover))
            self:SetBackdropBorderColor(unpack(BTN.edgeHover))
        end
        local f = self:GetFontString()
        if f and f:IsTruncated() then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self:GetText(), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.active and BTN.fillOn or BTN.fill))
        if self:IsEnabled() then
            self:SetBackdropBorderColor(unpack(self.active and BTN.edgeHover or BTN.edge))
        else
            self:SetBackdropBorderColor(unpack(BTN.edgeOff))
        end
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(unpack(BTN.fillDown))
        end
    end)
    b:SetScript("OnMouseUp", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(unpack(BTN.fillHover))
        end
    end)
    b:SetScript("OnDisable", function(self)
        self:SetBackdropBorderColor(unpack(BTN.edgeOff))
    end)
    b:SetScript("OnEnable", function(self)
        self:SetBackdropBorderColor(unpack(self.active and BTN.edgeHover or BTN.edge))
    end)
    return b
end

-- Lit fill and a white label, for the picked button of a row that works like
-- a switch (Move / Grow / Shrink on the build rail).
function CH.SetButtonActive(b, on)
    b.active = on or nil
    b:SetNormalFontObject(on and GameFontHighlightSmall or GameFontNormalSmall)
    -- the colours OnLeave would set, without its GameTooltip:Hide()
    if not b:IsMouseOver() then
        b:SetBackdropColor(unpack(on and BTN.fillOn or BTN.fill))
        if b:IsEnabled() then
            b:SetBackdropBorderColor(unpack(on and BTN.edgeHover or BTN.edge))
        end
    end
    if b.TintIcon then
        b.TintIcon(b:IsMouseOver())
    end
end

-- SVG art from Media. The svgs are drawn white and tinted with SetVertexColor.
local MEDIA = "Interface\\AddOns\\Chamberlain\\Media\\"

function CH.MakeIcon(parent, file, size, layer)
    local v = parent:CreateVectorGraphics()
    CH.SetIconFile(v, file)
    v:SetDrawLayer(layer or "ARTWORK")
    v:SetSize(size, size)
    return v
end

-- Swap the art on an icon from MakeIcon.
function CH.SetIconFile(v, file)
    v:SetSVG(MEDIA .. file .. ".svg")
end

-- An icon on a MakeButton that follows its label: gold, white on hover or while
-- active, grey when disabled. An svg can't be a button texture, so it rides on
-- top and the button's scripts recolor it. The caller anchors it.
function CH.AddButtonIcon(btn, file, size)
    local icon = CH.MakeIcon(btn, file, size, "OVERLAY")
    local function tint(hot)
        if not btn:IsEnabled() then
            icon:SetVertexColor(0.5, 0.5, 0.5)
        elseif hot or btn.active then
            icon:SetVertexColor(1, 1, 1)
        else
            icon:SetVertexColor(CH.RGBA(CH.COLORS.tipGold, 1))
        end
    end
    btn:HookScript("OnEnter", function()
        tint(true)
    end)
    -- a script passes the button first, which tint would read as hot
    local function settle()
        tint(false)
    end
    btn:HookScript("OnLeave", settle)
    btn:HookScript("OnEnable", settle)
    btn:HookScript("OnDisable", settle)
    btn.TintIcon = tint
    tint(false)
    return icon
end

-- The small gold letter buttons that sit in a window's header, x to close and
-- the fold arrows. White under the mouse.
function CH.MakeGlyphButton(parent, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.glyph:SetAllPoints()
    b.glyph:SetText(glyph)
    b.glyph:SetTextColor(1, 0.84, 0, 1)
    b:SetScript("OnEnter", function(self)
        self.glyph:SetTextColor(1, 1, 1, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self.glyph:SetTextColor(1, 0.84, 0, 1)
    end)
    return b
end

-- Text tabs over a faint line, the picked one gold with a bar under it.
-- onPick(i) runs when a tab is clicked. row:Select(i) only marks one.
function CH.MakeTabs(parent, keys, onPick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    local base = CH.MakeRule(row, 0.35)
    base:SetPoint("BOTTOMLEFT")
    base:SetPoint("BOTTOMRIGHT")

    local tabs = {}
    function row:Select(i)
        self.current = i
        for n, t in ipairs(tabs) do
            if n == i then
                t.label:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
            else
                t.label:SetTextColor(CH.RGBA(CH.COLORS.muted, 1))
            end
            t.bar:SetShown(n == i)
        end
    end

    local prev
    for i, key in ipairs(keys) do
        local t = CreateFrame("Button", nil, row)
        t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t.label:SetPoint("BOTTOM", 0, 7)
        t.label:SetText(CH.L[key])
        t:SetSize(t.label:GetStringWidth() + 8, 24)
        if prev then
            t:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 12, 0)
        else
            t:SetPoint("BOTTOMLEFT")
        end
        t.bar = t:CreateTexture(nil, "OVERLAY")
        t.bar:SetHeight(2)
        t.bar:SetPoint("BOTTOMLEFT")
        t.bar:SetPoint("BOTTOMRIGHT")
        t.bar:SetColorTexture(CH.RGBA(CH.COLORS.frame, 1))
        t:SetScript("OnClick", function()
            row:Select(i)
            onPick(i)
        end)
        t:SetScript("OnEnter", function()
            if row.current ~= i then
                t.label:SetTextColor(1, 1, 1, 1)
            end
        end)
        t:SetScript("OnLeave", function()
            row:Select(row.current)
        end)
        tabs[i] = t
        prev = t
    end
    row:Select(1)
    return row
end

-- Shared window skin: dark navy gradient, 1px gold frame, gold-tinted header
-- strip with the title in it. Frame must be created with BackdropTemplate.
function CH.SkinWindow(f, titleKey, branded)
    f:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
    f:SetBackdropBorderColor(CH.RGBA(CH.COLORS.frame, 0.9))

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    f.bg:SetColorTexture(1, 1, 1, 1)
    f.bg:SetGradient(
        "VERTICAL",
        CreateColor(0.03, 0.025, 0.02, 0.97), -- bottom
        CreateColor(0.10, 0.08, 0.05, 0.97)
    ) -- top

    f.header = f:CreateTexture(nil, "BORDER")
    f.header:SetPoint("TOPLEFT", 1, -1)
    f.header:SetPoint("TOPRIGHT", -1, -1)
    f.header:SetHeight(24)
    f.header:SetColorTexture(1, 1, 1, 1)
    f.header:SetGradient(
        "HORIZONTAL",
        CreateColor(0.45, 0.36, 0.08, 0.50), -- left
        CreateColor(0.10, 0.09, 0.05, 0.05)
    ) -- right

    f.headerLine = f:CreateTexture(nil, "ARTWORK")
    f.headerLine:SetHeight(1)
    f.headerLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -25)
    f.headerLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -25)
    f.headerLine:SetColorTexture(CH.RGBA(CH.COLORS.frame, 0.8))

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f, "TOPLEFT", 10, -13)
    CH.SetWindowTitle(f, titleKey, branded)

    return f
end

-- `branded` titles get the gold "Chamberlain" prefix and the key supplies the
-- localized tail. RM_WINDOW_TITLE bakes the brand into its own value, so it is
-- passed without branded. Also used by dialogs whose title changes with the job.
function CH.SetWindowTitle(f, titleKey, branded)
    local t = CH.L[titleKey]
    f.title:SetText(branded and ("|cffFFD700Chamberlain|r  " .. t) or t)
end

-- Slim scrollbar: hides the arrow buttons, stretches the bar over their
-- space, and swaps the ornate thumb for a thin gold strip on a dark track.
function CH.SkinScrollBar(scroll)
    local name = scroll:GetName()
    local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
    if not bar then
        return
    end

    local up = bar.ScrollUpButton or (name and _G[name .. "ScrollBarScrollUpButton"])
    local down = bar.ScrollDownButton or (name and _G[name .. "ScrollBarScrollDownButton"])
    if up then
        up:SetAlpha(0)
        up:EnableMouse(false)
    end
    if down then
        down:SetAlpha(0)
        down:EnableMouse(false)
    end

    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, -1)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 1)
    bar:SetWidth(6)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.45)

    local thumb = bar:GetThumbTexture()
    thumb:SetTexture("Interface/Buttons/WHITE8X8")
    thumb:SetVertexColor(CH.RGBA(CH.COLORS.frame, 0.7))
    thumb:SetSize(6, 36)
end

-- One-line hover tooltip on a button, looked up by locale key. key can be a
-- function handing back the key, for a button whose job changes.
function CH.Tip(btn, key)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(CH.L[type(key) == "function" and key() or key], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Small square color button with a bronze border (the picker swatches in the
-- room dialog). Caller positions it and wires OnClick.
function CH.MakeSwatch(parent, size)
    local s = CreateFrame("Button", nil, parent, "BackdropTemplate")
    s:SetSize(size, size)
    s:SetBackdrop(CH.BACKDROP_THIN)
    s:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.8))
    return s
end

-- Gold section title, top-left of its parent at the given y offset.
function CH.MakeSectionHeader(parent, key, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 4, yOff)
    fs:SetText(CH.L[key])
    fs:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    return fs
end

-- Thin full-width divider line. alpha defaults to the faint 0.25 used between
-- settings sections. Pass a higher value for a more visible rule.
function CH.MakeSep(parent, yOff, alpha)
    local t = CH.MakeRule(parent, alpha)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    return t
end

-- The same faint 1px line with no anchors, for the caller to lay across a row.
function CH.MakeRule(parent, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(CH.RGBA(CH.COLORS.sep, alpha or 0.25))
    return t
end

-- ON/OFF toggle button bound to a boolean in ChamberlainDB.settings[key].
-- Clicking flips the setting and relabels. Call b:Refresh() to sync the label
-- to the stored value (e.g. when the panel opens).
function CH.MakeToggleButton(parent, labelKey, key)
    local b = CH.MakeButton(parent, "", 230, 22)
    function b:Refresh()
        local on = ChamberlainDB.settings[key]
        self:SetText(CH.L[labelKey] .. (on and CH.L["SKIN_TOGGLE_ON"] or CH.L["SKIN_TOGGLE_OFF"]))
    end
    b:SetScript("OnClick", function(self)
        ChamberlainDB.settings[key] = not ChamberlainDB.settings[key]
        self:Refresh()
    end)
    return b
end

-- Dropdown button over a MenuUtil context menu. getLabel() returns the text for
-- the current pick, or nil to show noneKey. fill(root, btn) adds the menu's
-- entries and calls btn:Refresh() after a pick. Returns the button. Call
-- :Refresh() to resync its label, for example when a panel opens. onClose, if
-- given, runs once when the whole menu goes away, not when a submenu folds.
function CH.MakeMenuButton(parent, w, noneKey, getLabel, fill, onClose)
    local btn = CH.MakeButton(parent, noneKey, w, 22)
    local fs = btn:GetFontString()
    if fs then
        fs:SetWidth(w - 14)
        fs:SetWordWrap(false)
    end
    function btn:Refresh()
        self:SetText(getLabel() or CH.L[noneKey])
    end
    btn:SetScript("OnClick", function(self)
        if not MenuUtil then
            return
        end
        local menu = MenuUtil.CreateContextMenu(self, function(_, root)
            fill(root, self)
        end)
        if menu and onClose then
            menu:SetClosedCallback(onClose)
        end
    end)
    -- No Refresh() here: this runs in the main chunk before ADDON_LOADED sets up
    -- ChamberlainDB. The button shows noneLabel until the caller refreshes it (the
    -- settings tab does on open), matching how MakeToggleButton defers.
    return btn
end

-- Voice picker by NAME. getName() returns the stored name or nil. setName(name)
-- stores the choice. The button shows a compacted name from CH.ShortVoiceName
-- while the menu lists the full OS names.
function CH.MakeVoiceDropdown(parent, w, noneKey, getName, setName)
    return CH.MakeMenuButton(parent, w, noneKey, function()
        return CH.ShortVoiceName(getName())
    end, function(root, btn)
        root:CreateRadio(CH.L[noneKey], function()
            return getName() == nil
        end, function()
            setName(nil)
            btn:Refresh()
        end)
        local voices = CH.GetVoices()
        if #voices == 0 then
            root:CreateButton(CH.L["SKIN_NO_VOICES"]):SetEnabled(false)
        end
        for _, v in ipairs(voices) do
            local n = v.name
            root:CreateRadio(n, function()
                return getName() == n
            end, function()
                setName(n)
                btn:Refresh()
            end)
        end
    end)
end

-- A radio closes the menu unless its handler answers Refresh, which also moves
-- the dot. That keeps the ambience menu open while you click through sounds.
local function PickAndPlay(set, index)
    set(index)
    CH.PreviewAmbience(index)
    return MenuResponse.Refresh
end

-- MakeMenuButton's onClose for a menu filled by CH.FillAmbienceMenu. The closed
-- callback hands over the menu frame, which must not reach PreviewAmbience as
-- an index.
function CH.StopAmbiencePreview()
    CH.PreviewAmbience(nil)
end

-- The ambience list as radios under a menu or a submenu. None sits on top with
-- a submenu per category under it. get() returns the picked CH.AMBIENCE index
-- or nil. set(index) stores it.
function CH.FillAmbienceMenu(desc, get, set)
    desc:CreateRadio(CH.L["RD_AMBIENCE_NONE"], function()
        return get() == nil
    end, function()
        return PickAndPlay(set, nil)
    end)
    -- the category holding the current pick goes gold so it can be found again
    local picked = CH.AMBIENCE[get()]
    for _, cat in ipairs(CH.AMBIENCE_CATS) do
        local label = CH.L[cat]
        if picked and picked.cat == cat then
            label = "|cffFFD700" .. label .. "|r"
        end
        local sub = desc:CreateButton(label)
        for i, sound in ipairs(CH.AMBIENCE) do
            if sound.cat == cat then
                sub:CreateRadio(CH.L[sound.key], function()
                    return get() == i
                end, function()
                    return PickAndPlay(set, i)
                end)
            end
        end
    end
end

-- Horizontal slider over [minV, maxV] in whole steps of `step`, skinned to match
-- the addon: a dark track with a thin gold thumb. The caller sets the value with
-- :SetValue and reads changes with an OnValueChanged handler. `w` is the bar width.
function CH.MakeSlider(parent, w, minV, maxV, step)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(w, 12)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)
    s:SetBackdrop(CH.BACKDROP_THIN)
    s:SetBackdropColor(0, 0, 0, 0.45)
    s:SetBackdropBorderColor(CH.RGBA(CH.COLORS.border, 0.8))
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface/Buttons/WHITE8X8")
    thumb:SetVertexColor(CH.RGBA(CH.COLORS.gold, 1))
    thumb:SetSize(8, 16)
    s:SetThumbTexture(thumb)
    return s
end

-- Standard scrolling list: a skinned UIPanelScrollFrame with a content child
-- already attached. Returns the scroll frame and its child. The caller anchors
-- the scroll frame and fills the child. Used by every list panel in the addon.
function CH.MakeScrollList(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    CH.SkinScrollBar(scroll)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    return scroll, child
end

-- Make a frame block clicks (so they don't fall through to the world) and be
-- draggable by its body. Position is not saved.
function CH.MakeDraggable(f)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

-- Like MakeDraggable, but the frame's centre offset from UIParent is saved to
-- ChamberlainDB[xKey]/[yKey] on drop. Returns an Apply function that re-anchors
-- the frame from the saved offset (e.g. CH.ApplyHUDPos = CH.MakeMovablePersistent(...)).
function CH.MakeMovablePersistent(f, xKey, yKey)
    CH.MakeDraggable(f)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local cx, cy = UIParent:GetCenter()
        local fx, fy = f:GetCenter()
        ChamberlainDB[xKey] = fx - cx
        ChamberlainDB[yKey] = fy - cy
    end)
    return function()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", ChamberlainDB[xKey], ChamberlainDB[yKey])
    end
end

-- Remember the last 5 room colors used, newest first, deduplicated.
function CH.PushRecentColor(c)
    if not c then
        return
    end
    local list = ChamberlainDB.recentColors
    for i = #list, 1, -1 do
        local e = list[i]
        if math.abs(e[1] - c[1]) + math.abs(e[2] - c[2]) + math.abs(e[3] - c[3]) < 0.01 then
            table.remove(list, i)
        end
    end
    table.insert(list, 1, { c[1], c[2], c[3] })
    while #list > 5 do
        table.remove(list)
    end
end

-- Stamp a house as changed and push that change to the floor plan, the room
-- list, the launcher and the party broadcast. Saves repeating the same lines
-- after every edit (create, resize, rename, delete). guid may be nil, in which
-- case only the open windows refresh.
function CH.TouchHouse(guid)
    local h = guid and ChamberlainDB.houses[guid]
    if h then
        h.updatedAt = GetServerTime()
    end
    if CH.RebuildFloorPlan then
        CH.RebuildFloorPlan()
    end
    if CH.RefreshRoomList then
        CH.RefreshRoomList()
    end
    -- The launcher's Archive button depends on whether this house has rooms.
    if guid and guid == CH.currentHouseGUID and CH.RefreshHUDMode then
        CH.RefreshHUDMode()
    end
    if guid and CH.QueueBroadcast then
        CH.QueueBroadcast(guid)
    end
end

-- Drop a deleted room's time stats, unless another room still uses the name
-- (stats are keyed by room name and duplicates are allowed).
function CH.DropZoneStats(house, name)
    if not house or not house.stats or not name then
        return
    end
    for _, z in ipairs(house.zones) do
        if z.name == name then
            return
        end
    end
    house.stats[name] = nil
end
