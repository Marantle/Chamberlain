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
    edge = { 0.55, 0.45, 0.15, 0.80 },
    edgeHover = { 0.95, 0.80, 0.25, 1.00 },
    edgeOff = { 0.30, 0.26, 0.16, 0.50 },
}

function CH.MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(CH.BACKDROP_THIN)
    b:SetBackdropColor(unpack(BTN.fill))
    b:SetBackdropBorderColor(unpack(BTN.edge))
    b:SetNormalFontObject(GameFontNormalSmall) -- gold
    b:SetHighlightFontObject(GameFontHighlightSmall) -- white on hover
    b:SetDisabledFontObject(GameFontDisableSmall)
    b:SetText(text)

    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(unpack(BTN.fillHover))
            self:SetBackdropBorderColor(unpack(BTN.edgeHover))
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(BTN.fill))
        if self:IsEnabled() then
            self:SetBackdropBorderColor(unpack(BTN.edge))
        else
            self:SetBackdropBorderColor(unpack(BTN.edgeOff))
        end
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
        self:SetBackdropBorderColor(unpack(BTN.edge))
    end)
    return b
end

-- Shared window skin: dark navy gradient, 1px gold frame, gold-tinted header
-- strip with the title in it. Frame must be created with BackdropTemplate.
function CH.SkinWindow(f, titleText)
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
    f.title:SetText(titleText)

    return f
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
function CH.MakeSectionHeader(parent, text, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 4, yOff)
    fs:SetText(text)
    fs:SetTextColor(CH.RGBA(CH.COLORS.gold, 1))
    return fs
end

-- Thin full-width divider line. alpha defaults to the faint 0.25 used between
-- settings sections. Pass a higher value for a more visible rule.
function CH.MakeSep(parent, yOff, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    t:SetColorTexture(CH.RGBA(CH.COLORS.sep, alpha or 0.25))
    return t
end

-- ON/OFF toggle button bound to a boolean in ChamberlainDB.settings[key].
-- Clicking flips the setting and relabels. Call b:Refresh() to sync the label
-- to the stored value (e.g. when the panel opens).
function CH.MakeToggleButton(parent, label, key)
    local b = CH.MakeButton(parent, "", 230, 22)
    function b:Refresh()
        local on = ChamberlainDB.settings[key]
        self:SetText(label .. (on and CH.L["SKIN_TOGGLE_ON"] or CH.L["SKIN_TOGGLE_OFF"]))
    end
    b:SetScript("OnClick", function(self)
        ChamberlainDB.settings[key] = not ChamberlainDB.settings[key]
        self:Refresh()
    end)
    return b
end

-- Dropdown button for picking a TTS voice by NAME, built on a MenuUtil context
-- menu. noneLabel shows when nothing is picked. getName() returns the stored name
-- or nil. setName(name) stores the choice. Returns the button. Call :Refresh() to
-- resync its label, for example when a panel opens. The button shows a compacted
-- name from CH.ShortVoiceName while the menu lists the full OS names.
function CH.MakeVoiceDropdown(parent, w, noneLabel, getName, setName)
    local btn = CH.MakeButton(parent, noneLabel, w, 22)
    local fs = btn:GetFontString()
    if fs then
        fs:SetWidth(w - 14)
        fs:SetWordWrap(false)
    end
    function btn:Refresh()
        self:SetText(CH.ShortVoiceName(getName()) or noneLabel)
    end
    btn:SetScript("OnClick", function(self)
        if not MenuUtil then
            return
        end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateRadio(noneLabel, function()
                return getName() == nil
            end, function()
                setName(nil)
                self:Refresh()
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
                    self:Refresh()
                end)
            end
        end)
    end)
    -- No Refresh() here: this runs in the main chunk before ADDON_LOADED sets up
    -- ChamberlainDB. The button shows noneLabel until the caller refreshes it (the
    -- settings tab does on open), matching how MakeToggleButton defers.
    return btn
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

-- Stamp a house as changed and push that change everywhere it shows: the floor
-- plan, the room list, and the party broadcast. Saves repeating the same lines
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
    if CH.RefreshMyRoomsTab then
        CH.RefreshMyRoomsTab()
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
