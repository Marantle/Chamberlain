local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Share log  (/rooms logs, left out of the help on purpose)
-- ─────────────────────────────────────────────────────────────────────
-- The last 30 things sharing did on this client, so a missing map can be
-- traced back. Kept in the saved data so it outlives a reload, and shown in a
-- box the player can copy from. The lines are English only, since the author
-- reads them.

local KEEP = 30

-- Words joined with spaces, like the debug lines. A | would start an escape
-- in the copy box.
function CH.ShareLog(...)
    local words = {}
    for i = 1, select("#", ...) do
        words[i] = tostring((select(i, ...)))
    end
    local log = ChamberlainDB.shareLog
    log[#log + 1] = date("%m-%d %H:%M:%S ") .. (table.concat(words, " "):gsub("|", "/"))
    while #log > KEEP do
        table.remove(log, 1)
    end
end

local win, box

local function Build()
    win = CreateFrame("Frame", "ChamberlainShareLog", UIParent, "BackdropTemplate")
    win:SetSize(560, 420)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetPoint("CENTER")
    CH.MakeDraggable(win)
    CH.SkinWindow(win, "SHARE_LOG_TITLE", true)
    table.insert(UISpecialFrames, "ChamberlainShareLog")

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -32)
    hint:SetTextColor(CH.RGBA(CH.COLORS.dim, 1))
    hint:SetText(CH.L["SHARE_LOG_HINT"])

    local scroll
    scroll, box = CH.MakeTextArea(win, "ChamberlainShareLogScroll", 520)
    scroll:SetPoint("TOPLEFT", 12, -50)
    scroll:SetPoint("BOTTOMRIGHT", -24, 42)
    box:SetScript("OnEscapePressed", function()
        win:Hide()
    end)
    -- read only: any typing puts the log back
    box:SetScript("OnTextChanged", function(self, user)
        if user then
            self:SetText(win.text)
            self:HighlightText()
        end
    end)

    local close = CH.MakeButton(win, "SUI_CLOSE", 80, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 10)
    close:SetScript("OnClick", function()
        win:Hide()
    end)
end

function CH.OpenShareLog()
    if not win then
        Build()
    end
    local lines = {
        string.format(
            "Chamberlain %s, %s, group of %d, inside a house: %s, house: %s",
            CH.VERSION,
            GetLocale(),
            GetNumGroupMembers(),
            tostring(C_Housing.IsInsideHouse()),
            tostring(CH.currentHouseGUID)
        ),
    }
    -- newest first, so the last thing that happened shows without scrolling
    local log = ChamberlainDB.shareLog
    for i = #log, 1, -1 do
        lines[#lines + 1] = log[i]
    end
    if #lines == 1 then
        lines[2] = CH.L["SHARE_LOG_EMPTY"]
    end
    win.text = table.concat(lines, "\n")
    box:SetText(win.text)
    win:Show()
    box:SetFocus()
    box:HighlightText()
end
