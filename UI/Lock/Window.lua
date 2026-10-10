local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- The lock window, which every lock style draws into
-- ─────────────────────────────────────────────────────────────────────
-- The banner's lock button opens it. The window owns the close button, the
-- header and the room name fading in once the code is right. Each style
-- (UI/Lock/*.lua) builds its own page on first use and only the page of the
-- open lock shows. Everything moves through AnimationGroups, so nothing runs
-- while it's shut.

local K = {}
CH.LockKit = K

K.FLY = 0.46

-- Hex colours as the canvases wrote them, turned into r, g, b in place.
function K.Colors(t)
    for name, hex in pairs(t) do
        t[name] =
            { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
    end
    return t
end

function K.Tint(r, c)
    r:SetVertexColor(c[1], c[2], c[3])
end

function K.Anim(ag, kind, order, dur, delay, smooth)
    local a = ag:CreateAnimation(kind)
    a:SetOrder(order)
    a:SetDuration(dur)
    if delay then
        a:SetStartDelay(delay)
    end
    if smooth then
        a:SetSmoothing(smooth)
    end
    return a
end

function K.Group(region, onFinished)
    local ag = region:CreateAnimationGroup()
    if onFinished then
        ag:SetScript("OnFinished", onFinished)
    end
    return ag
end

function K.Fade(ag, order, dur, from, to, delay)
    local a = K.Anim(ag, "Alpha", order, dur, delay)
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    return a
end

function K.Grow(ag, order, dur, from, to, delay, smooth)
    local a = K.Anim(ag, "Scale", order, dur, delay, smooth)
    a:SetScaleFrom(from, from)
    a:SetScaleTo(to, to)
    return a
end

function K.Spin(ag, order, dur, degrees, delay, smooth)
    K.Anim(ag, "Rotation", order, dur, delay, smooth):SetDegrees(degrees)
end

function K.Move(ag, order, dur, x, y, delay, smooth)
    local a = K.Anim(ag, "Translation", order, dur, delay, smooth)
    a:SetOffset(x, y)
    return a
end

-- Keeps a region out of sight for its first dur seconds. Its own alpha stays
-- 1, which works whether the game multiplies an Alpha animation into it or not.
function K.Wait(ag, dur)
    return K.Fade(ag, 1, dur, 0, 0)
end

-- A row of moves one after another, for shakes and bites.
function K.Chain(ag, kind, steps, dur)
    for i, v in ipairs(steps) do
        local a = K.Anim(ag, kind, i, dur)
        if kind == "Rotation" then
            a:SetDegrees(v)
        else
            a:SetOffset(v, 0)
        end
    end
end

-- A piece of lock art. The postcard pieces are squashed to power of two
-- sides, so the size given here is what puts them back in shape.
function K.Pic(parent, name, w, h, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(CH.MEDIA .. "lock-" .. name .. ".png")
    t:SetSize(w, h)
    return t
end

-- A postcard bat that drifts while the lock waits, flees when it opens and
-- flaps in a panic on a wrong code. drift is x, y and seconds a swing, flee
-- is x, y and the wait before it goes. Panic is a scale, so the drift can
-- go on under it.
function K.Bat(parent, name, w, h, x, y, drift, flee)
    local b = K.Pic(parent, name, w, h)
    b:SetPoint("TOPLEFT", x, y)
    b.drift = K.Group(b)
    b.drift:SetLooping("BOUNCE")
    K.Move(b.drift, 1, drift[3], drift[1], drift[2], nil, "IN_OUT")
    b.flee = K.Group(b, function()
        b:Hide()
    end)
    K.Move(b.flee, 1, 1.1, flee[1], flee[2], flee[3], "IN")
    K.Fade(b.flee, 1, 1.1, 1, 0, flee[3])
    b.panic = K.Group(b)
    for i = 1, 6 do
        local a = K.Anim(b.panic, "Scale", i, 0.06)
        local squash = i % 2 == 1
        a:SetScaleFrom(1, squash and 1 or 0.7)
        a:SetScaleTo(1, squash and 0.7 or 1)
    end
    return b
end

-- The postcards' paper, tiled over a whole page and tinted to the card.
function K.Paper(page, r, g, b)
    local t = page:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(CH.MEDIA .. "lock-linen.png", "REPEAT", "REPEAT")
    t:SetHorizTile(true)
    t:SetVertTile(true)
    t:SetAllPoints()
    t:SetVertexColor(r, g, b)
    return t
end

-- The orange edge the postcards are printed with.
function K.CardEdge(page, c, w)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, w }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, w } }) do
        local t = page:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        t:SetHeight(side[4])
        t:SetColorTexture(c[1], c[2], c[3])
    end
    for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = page:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        t:SetWidth(w)
        t:SetColorTexture(c[1], c[2], c[3])
    end
end

-- A flat button with a thin edge and a centred label.
function K.Button(parent, label, w, h, fill, edge, text, font)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(CH.BACKDROP_THIN)
    b:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    b:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    local fs = b:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    fs:SetTextColor(text[1], text[2], text[3])
    b.label = fs
    return b
end

-- The Morpheus face of the game's quest titles, at any size. Taken off the
-- font object so each client gets the face its alphabet needs.
function K.Font(fs, size)
    fs:SetFont(QuestFont_30:GetFont(), size, "")
end

-- Things that fly from one button to another, the digits and glyphs on
-- their way to the lock. make(fl) puts what flies on the frame and returns
-- it, set(thing, value) changes it before a flight. x eases out and y eases
-- in, two translations at once, so it travles on an arc.
function K.Flyers(parent, make, set)
    local spare = {}
    local function New()
        local fl = CreateFrame("Frame", nil, parent)
        fl:SetSize(40, 40)
        fl:SetFrameLevel(parent:GetFrameLevel() + 30)
        fl.ag = fl:CreateAnimationGroup()
        fl.x = K.Anim(fl.ag, "Translation", 1, K.FLY, nil, "OUT")
        fl.y = K.Anim(fl.ag, "Translation", 1, K.FLY, nil, "IN")
        fl.scale = K.Grow(fl.ag, 1, K.FLY, 1, 1, nil, "OUT")
        fl.thing = make(fl)
        fl.ag:SetScript("OnFinished", function()
            fl:Hide()
            table.insert(spare, fl)
            if fl.done then
                fl.done()
            end
        end)
        return fl
    end
    return function(from, to, value, s1, s2, done)
        local fl = table.remove(spare) or New()
        set(fl.thing, value)
        fl:ClearAllPoints()
        fl:SetPoint("CENTER", from)
        local fx, fy = from:GetCenter()
        local tx, ty = to:GetCenter()
        fl.x:SetOffset(tx - fx, 0)
        fl.y:SetOffset(0, ty - fy)
        fl.scale:SetScaleFrom(s1, s1)
        fl.scale:SetScaleTo(s2, s2)
        fl.done = done
        fl:Show()
        fl.ag:Play()
    end
end

-- ── A code in slots ──────────────────────────────────────────────────
-- The input of the styles where each number flies from its key into the
-- next slot and a click on a slot sends it and the ones after it back.
-- o carries keys and slots, Fly from K.Flyers, light(slot, d) and
-- empty(slot), reset(), open() and wrong() for the style's own art, delay
-- for the name, the two flight scales s1 and s2, and value(d, i) for what
-- flies when it isn't the digit.
function K.Slots(o)
    local lock = { typed = "", landed = 0, result = "idle" }
    local value = o.value or function(d)
        return d
    end

    function lock.Reset()
        o.reset()
        lock.typed, lock.landed, lock.result = "", 0, "idle"
    end

    function lock.TakeFrom(i)
        if lock.result ~= "idle" then
            return
        end
        for j = i, lock.landed do
            local d = tonumber(lock.typed:sub(j, j))
            o.empty(o.slots[j])
            o.Fly(o.slots[j], o.keys[d == 0 and 10 or d], value(d, j), o.s2, o.s1)
        end
        lock.typed = lock.typed:sub(1, i - 1)
        lock.landed = math.min(lock.landed, i - 1)
    end

    function lock.Press(d)
        if lock.result == "open" then
            return
        elseif lock.result == "wrong" then
            lock.Reset()
        end
        if #lock.typed >= CH.LOCK_CODE_MAX then
            return
        end
        local i = #lock.typed + 1
        lock.typed = lock.typed .. d
        o.Fly(o.keys[d == 0 and 10 or d], o.slots[i], value(d, i), o.s1, o.s2, function()
            -- it may have been sent back while flying
            if lock.typed:sub(i, i) == tostring(d) then
                lock.landed = math.max(lock.landed, i)
                o.light(o.slots[i], d)
            end
        end)
    end

    function lock.Submit()
        if lock.result == "idle" and lock.landed >= CH.LOCK_CODE_MIN and lock.landed == #lock.typed then
            local right = K.Try(lock.typed, o.delay)
            lock.result = right and "open" or "wrong"
            if right then
                o.open()
            else
                o.wrong()
            end
        end
    end

    function lock.Clear()
        if lock.result == "wrong" then
            lock.Reset()
        elseif lock.result == "idle" and lock.landed > 0 then
            lock.TakeFrom(1)
        end
    end

    -- each slot gives its number back when clicked
    for i, s in ipairs(o.slots) do
        s:SetScript("OnClick", function()
            if i <= lock.landed then
                lock.TakeFrom(i)
            end
        end)
    end
    return lock
end

-- The keys of the postcard locks, 1 to 0 in two rows, with Clear and the
-- style's own go button under them. c holds the style's key, sepia, ink,
-- spent, hint, orange, rust and cream colours.
function K.PostcardKeys(page, c, goKey, lock)
    local keys = {}
    for k = 1, 10 do
        local d = k % 10
        local b = K.Button(page, d, 73.6, 60, { c.key[1], c.key[2], c.key[3], 0.6 }, c.sepia, c.ink)
        K.Font(b.label, 30)
        b:SetPoint("TOPLEFT", 60 + ((k - 1) % 5) * 81.6, -518 - math.floor((k - 1) / 5) * 68)
        b:SetScript("OnClick", function()
            lock.Press(d)
        end)
        keys[k] = b
    end
    local clear = K.Button(page, CH.L["LOCK_CLEAR"], 196, 40, { 0, 0, 0, 0 }, c.spent, c.hint)
    K.Font(clear.label, 17)
    clear:SetPoint("TOPLEFT", 60, -664)
    clear:SetScript("OnClick", function()
        lock.Clear()
    end)
    local go = K.Button(page, CH.L[goKey], 196, 40, c.orange, c.rust, c.cream)
    K.Font(go.label, 17)
    go:SetPoint("TOPRIGHT", -60, -664)
    go:SetScript("OnClick", function()
        lock.Submit()
    end)
    return keys
end

-- ── Styles ───────────────────────────────────────────────────────────
-- K.Register(id, def) from each style file, id as in CH.LOCK_STYLES. def
-- holds w and h, back (the window's colour, r g b a), edge, title and hint
-- colours, hintKey, and Build(page), which draws the style on its page and
-- returns the look: Reset(house, test) to start over, Stop() when the
-- window hides.
local styles = {}

function K.Register(id, def)
    styles[id] = def
end

local f, head, tag, title, hint
local look, shown -- the open style's look and its def
local target, targetHouse -- the area and the house it's in
local testing -- an owner's Try the lock, see CH.LockTestCopy
local revealing = false -- opened, and the banner hasn't been told yet

-- A code typed at the lock. When it's right the room's name fades in after
-- delay seconds, holds a moment, then the lock closes and the banner takes
-- over.
function K.Try(code, delay)
    if not CH.TryLockCode(target, targetHouse, code, testing) then
        return false
    end
    revealing = true
    title:SetText(target.name)
    -- the face for the name's own alphabet, as on the banner
    CH.SetNameFont(title, QuestFont_30, 30, "")
    title.wait:SetDuration(delay)
    title.reveal:Play()
    return true
end

local function Build()
    f = CreateFrame("Frame", "ChamberlainLock", UIParent, "BackdropTemplate")
    f:SetPoint("CENTER")
    -- over the house map, which is DIALOG, since Try the lock opens from it
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop(CH.BACKDROP_THIN)
    -- what flies off on open (the witch, the balloon, bats) goes out of sight
    -- at the card's edge instead of crossing the screen
    f:SetClipsChildren(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- Kept off UISpecialFrames so Showcase can carry it through Hide UI,
    -- which closes everything on that list. The x is the way out.
    CH.lockWindow = f

    -- the header rides over the pages, whose paper would cover it
    head = CreateFrame("Frame", nil, f)
    head:SetAllPoints()
    head:SetFrameLevel(f:GetFrameLevel() + 40)
    -- the template's own click goes through HideUIPanel, which refuses in combat
    local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    tag = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tag:SetPoint("TOP", 0, -22)
    -- Blizzard's Morpheus family, which has a font for every alphabet a room
    -- name can be typed in
    title = head:CreateFontString(nil, "OVERLAY", "QuestFont_30")
    title:SetPoint("TOP", 0, -40)
    title.reveal = K.Group(title, function()
        f:Hide()
    end)
    title.wait = K.Wait(title.reveal, 1.8)
    K.Fade(title.reveal, 2, 0.6, 0, 1)
    K.Fade(title.reveal, 3, 0.9, 1, 1)
    hint = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", 0, -74)

    f:SetScript("OnHide", function(self)
        -- the UI hiding with the lock still up, glyphs and all
        if CH.OnlyParentHid(self) then
            return
        end
        if look then
            look.Stop()
        end
        -- however it closes after the right code, Escape in the middle of
        -- the fade included, the banner hears it once
        title.reveal:Stop()
        if revealing then
            revealing = false
            if testing then
                CH.PreviewReveal(target)
            else
                CH.RoomRevealed(target)
            end
        end
    end)
end

-- The style's page, built the first time it opens.
local function Page(id)
    local def = styles[id]
    if not def.look then
        def.page = CreateFrame("Frame", nil, f)
        def.page:SetAllPoints()
        def.look = def.Build(def.page)
    end
    return def
end

function CH.OpenLock(zone, house, test)
    if not f then
        Build()
        -- opened from a banner Showcase holds up, it goes along
        CH.RefreshKeepOnScreen()
    end
    f:Hide()
    target, targetHouse, testing = zone, house, test
    local def = Page(CH.LockStyle(zone).id)
    if shown and shown ~= def then
        shown.page:Hide()
    end
    shown, look = def, def.look
    def.page:Show()
    f:SetSize(def.w, def.h)
    f:SetBackdropColor(unpack(def.back))
    f:SetBackdropBorderColor(CH.RGBA(def.edge, 1))
    tag:SetText(CH.LockStyleName(zone):upper())
    title:SetTextColor(CH.RGBA(def.title, 1))
    hint:SetText(CH.L[def.hintKey])
    hint:SetTextColor(CH.RGBA(def.hint, 1))
    f:Show()
    title.reveal:Stop()
    title:SetText(CH.L["LOCK_AREA"])
    CH.SetNameFont(title, QuestFont_30, 30, "")
    -- the patch needs to know whose pumpkins it takes
    look.Reset(house, test)
end

function CH.CloseLock()
    if f and not revealing then
        f:Hide()
    end
end
