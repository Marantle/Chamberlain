local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Consent Dialog
-- ─────────────────────────────────────────────────────────────────────

local consentDialog = CreateFrame("Frame", "ChamberlainConsentDialog", UIParent, "BackdropTemplate")
consentDialog:SetSize(280, 130)
consentDialog:SetFrameStrata("FULLSCREEN_DIALOG")
consentDialog:SetPoint("TOP", UIParent, "TOP", 0, -220)
CH.SkinWindow(consentDialog, "SUI_TITLE_LAYOUT_REQUEST", true)
consentDialog:Hide()
table.insert(UISpecialFrames, "ChamberlainConsentDialog")

local consentText = consentDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
consentText:SetPoint("TOP", 0, -30)
consentText:SetWidth(258)
consentText:SetJustifyH("CENTER")
consentText:SetWordWrap(true)

local btnShare = CH.MakeButton(consentDialog, "SUI_SHARE", 60, 22)
local btnNoShare = CH.MakeButton(consentDialog, "SUI_NO", 48, 22)
local btnBlkHouse = CH.MakeButton(consentDialog, "SUI_BLOCK_HOUSE", 82, 22)
local btnBlkPlyr = CH.MakeButton(consentDialog, "SUI_BLOCK_PLAYER", 82, 22)

btnShare:SetPoint("BOTTOMLEFT", consentDialog, "BOTTOM", -56, 36)
btnNoShare:SetPoint("BOTTOMLEFT", consentDialog, "BOTTOM", 10, 36)
btnBlkHouse:SetPoint("BOTTOMLEFT", consentDialog, "BOTTOM", -84, 8)
btnBlkPlyr:SetPoint("BOTTOMLEFT", consentDialog, "BOTTOM", 4, 8)

local pendingConsentSender, pendingConsentGUID

local function DeclineConsent()
    CH.SendDecline(pendingConsentGUID)
    consentDialog:Hide()
end

function CH.ShowConsentDialog(senderName, houseGUID)
    pendingConsentSender = senderName
    pendingConsentGUID = houseGUID
    local h = ChamberlainDB.houses[houseGUID]
    local houseName = (h and h.owner and string.format(CH.L["SHARE_X_HOUSE"], h.owner)) or CH.L["SHARE_A_HOUSE"]
    consentText:SetText(string.format(CH.L["SUI_CONSENT_X"], senderName, houseName))
    consentDialog:Show()
    consentDialog:Raise()
end

btnShare:SetScript("OnClick", function()
    CH.SendLayout(pendingConsentGUID)
    -- SendLayout goes out on the party/raid channel, so this reaches everyone,
    -- not just whoever asked. Word it that way so it isn't misleading.
    local h = ChamberlainDB.houses[pendingConsentGUID]
    local count = h and h.zones and #h.zones or 0
    local houseName = (h and h.owner) and string.format(CH.L["SHARE_X_HOUSE"], h.owner) or CH.L["SUI_THE_LAYOUT"]
    CH.Print(CH.L["SUI_SHARED_GROUP_X"], houseName, count)
    consentDialog:Hide()
end)

btnNoShare:SetScript("OnClick", DeclineConsent)

btnBlkHouse:SetScript("OnClick", function()
    local h = ChamberlainDB.houses[pendingConsentGUID]
    ChamberlainDB.blocks.houses[pendingConsentGUID] = (h and h.owner) or true
    DeclineConsent()
end)

btnBlkPlyr:SetScript("OnClick", function()
    ChamberlainDB.blocks.players[pendingConsentSender] = true
    DeclineConsent()
end)

-- ─────────────────────────────────────────────────────────────────────
-- Accept Dialog
-- ─────────────────────────────────────────────────────────────────────
-- Consent for every incoming layout you didn't request. You decide per layout
-- (Accept / Decline) and, for a layout shared by a person, may tick "Always
-- accept from <them>" to trust that sender so their future shares apply silently.
-- Trust is stored per character name in ChamberlainDB.trusted.

local acceptDialog = CreateFrame("Frame", "ChamberlainAcceptDialog", UIParent, "BackdropTemplate")
acceptDialog:SetSize(300, 146)
acceptDialog:SetFrameStrata("FULLSCREEN_DIALOG")
acceptDialog:SetPoint("TOP", UIParent, "TOP", 0, -220)
CH.SkinWindow(acceptDialog, "SUI_TITLE_SHARED_LAYOUT", true)
acceptDialog:Hide()
table.insert(UISpecialFrames, "ChamberlainAcceptDialog")

local acceptText = acceptDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
acceptText:SetPoint("TOP", 0, -30)
acceptText:SetWidth(278)
acceptText:SetJustifyH("CENTER")
acceptText:SetWordWrap(true)

local trustCB = CreateFrame("CheckButton", "ChamberlainTrustCB", acceptDialog, "UICheckButtonTemplate")
trustCB:SetSize(20, 20)
trustCB:SetPoint("BOTTOMLEFT", acceptDialog, "BOTTOM", -110, 38)

local trustLabel = acceptDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
trustLabel:SetPoint("LEFT", trustCB, "RIGHT", 4, 0)
trustLabel:SetTextColor(0.8, 0.8, 0.8, 1)

local btnAccept = CH.MakeButton(acceptDialog, "SUI_ACCEPT", 80, 22)
local btnDecline = CH.MakeButton(acceptDialog, "SUI_DECLINE", 80, 22)
btnAccept:SetPoint("BOTTOMLEFT", acceptDialog, "BOTTOM", -84, 8)
btnDecline:SetPoint("BOTTOMLEFT", acceptDialog, "BOTTOM", 4, 8)

-- The dialog is a singleton, but "Share My Houses" pushes every house at once,
-- so sevral offers can land before the player answers the first. Queue them
-- (FIFO) and show one at a time instead of letting each overwrite the last.
local acceptQueue = {}
local pendingGUID, pendingData, pendingSender, pendingImport

-- Text out of a map somebody else made goes on screen as written. A name
-- with || codes in it could otherwise draw a texture or fake a line of ours.
local function Plain(text)
    return (text:gsub("|", "||"))
end

local PREVIEW_NAMES = 5

-- What a map holds, in grey lines under the question. Secret rooms count but
-- stay unnamed here as everywhere.
local function DescribeLayout(data)
    local lines = {}
    if data.owner then
        lines[#lines + 1] = string.format(CH.L["SUI_PREVIEW_OWNER_X"], Plain(data.owner))
    end
    local floors = data.floorCount or 1
    lines[#lines + 1] =
        string.format(CH.L[floors > 1 and "SUI_PREVIEW_SIZE_FLOORS_X" or "SUI_PREVIEW_SIZE_X"], #data.zones, floors)
    lines[#lines + 1] = string.format(CH.L["SUI_PREVIEW_CHANGED_X"], date("%Y-%m-%d", data.timestamp))

    local has = { AMBIENCE = data.ambience, MUSIC = data.music, ARRIVAL = data.arrival }
    local names, hidden = {}, 0
    for _, zone in ipairs(data.zones) do
        has.AMBIENCE = has.AMBIENCE or zone.ambience
        has.MUSIC = has.MUSIC or zone.music
        has.SFX = has.SFX or zone.sfx
        has.ECHO = has.ECHO or zone.echo
        if zone.secret or #names == PREVIEW_NAMES then
            hidden = hidden + 1
        else
            names[#names + 1] = Plain(zone.name)
        end
    end
    local kinds = {}
    for _, kind in ipairs({ "AMBIENCE", "MUSIC", "SFX", "ECHO", "ARRIVAL" }) do
        if has[kind] then
            kinds[#kinds + 1] = CH.L["SUI_PREVIEW_KIND_" .. kind]
        end
    end
    if #kinds > 0 then
        lines[#lines + 1] = string.format(CH.L["SUI_PREVIEW_SOUNDS_X"], table.concat(kinds, ", "))
    end
    if #names > 0 then
        local list = table.concat(names, ", ")
        if hidden > 0 then
            list = list .. string.format(CH.L["SUI_PREVIEW_MORE_X"], hidden)
        end
        lines[#lines + 1] = string.format(CH.L["SUI_PREVIEW_ROOMS_X"], list)
    end
    return "|cffb0b0b0" .. table.concat(lines, "\n") .. "|r"
end

-- The question with the map's details under it, and the dialog sized to fit.
local function SetAcceptText(question, data)
    acceptText:SetText(question .. "\n\n" .. DescribeLayout(data))
    acceptDialog:SetHeight(acceptText:GetStringHeight() + 106)
end

local function ShowNextAccept()
    local item = table.remove(acceptQueue, 1)
    if not item then
        pendingGUID, pendingData, pendingSender, pendingImport = nil, nil, nil, nil
        acceptDialog:Hide()
        return
    end
    pendingGUID, pendingData, pendingSender, pendingImport = item.guid, item.data, item.sender, item.isImport
    local existing = ChamberlainDB.houses[item.guid]
    local myCount = existing and existing.zones and #existing.zones or 0
    local newCount = #item.data.zones
    local houseName = (item.data.owner and string.format(CH.L["SHARE_X_HOUSE"], Plain(item.data.owner)))
        or CH.L["SHARE_A_HOUSE"]

    if item.isImport then
        -- Pasted strings aren't tied to a person, so no trust offer here.
        trustCB:Hide()
        trustLabel:Hide()
        -- A string names its own house and owner, and whoever made it chose
        -- both. One keyed to a house of yours can call itself anything, so for
        -- those the name is left out of the question and the dialog says whose
        -- rooms go. Sharing never gets here since CH.ReceiveLayout drops maps of
        -- your houses.
        local question
        if ChamberlainDB.myHouses[item.guid] and myCount > 0 then
            question = string.format(CH.L["SUI_OVERWRITE_OWN_X"], myCount, newCount)
        elseif ChamberlainDB.myHouses[item.guid] then
            question = string.format(CH.L["SUI_IMPORT_OWN_X"], newCount)
        elseif myCount > 0 then
            question = string.format(CH.L["SUI_OVERWRITE_X"], houseName, myCount, newCount)
        else
            question = string.format(CH.L["SUI_IMPORT_X"], houseName, newCount)
        end
        SetAcceptText(question, item.data)
    else
        local verb = myCount > 0 and CH.L["SUI_VERB_UPDATE"] or CH.L["SUI_VERB_SHARE"]
        local more = #acceptQueue > 0 and string.format(CH.L["SUI_MORE_X"], #acceptQueue) or ""
        SetAcceptText(
            string.format(CH.L["SUI_ACCEPT_PROMPT_X"], item.sender, verb, houseName, newCount, more),
            item.data
        )
        trustLabel:SetText(string.format(CH.L["SUI_ALWAYS_ACCEPT_X"], item.sender))
        trustCB:SetChecked(false)
        trustCB:Show()
        trustLabel:Show()
    end
    acceptDialog:Show()
    acceptDialog:Raise()
end

-- senderName is a character name for a shared push, or a label like "the
-- imported string" when isImport is true.
function CH.ShowAcceptDialog(houseGUID, incomingData, senderName, isImport)
    -- A re-send of a house already waiting (or on screen) just refreshes its
    -- data so we decide against the newest copy, rather than queueing a dupe.
    -- The one on screen goes back through ShowNextAccept so the dialog says
    -- what Accept will do. A pasted string could otherwise ride in under a
    -- groupmate's "wants to share" that was still up.
    local offer = { guid = houseGUID, data = incomingData, sender = senderName, isImport = isImport }
    if pendingGUID == houseGUID and acceptDialog:IsShown() then
        table.insert(acceptQueue, 1, offer)
        ShowNextAccept()
        return
    end
    for i, item in ipairs(acceptQueue) do
        if item.guid == houseGUID then
            acceptQueue[i] = offer
            return
        end
    end
    acceptQueue[#acceptQueue + 1] = offer
    if not acceptDialog:IsShown() then
        ShowNextAccept()
    end
end

btnAccept:SetScript("OnClick", function()
    local trust = (not pendingImport) and trustCB:GetChecked() and pendingSender
    if trust then
        ChamberlainDB.trusted[pendingSender] = true
    end
    CH.ApplyLayout(pendingGUID, pendingData, pendingSender)
    if trust then
        -- Trusting this sender means auto-accepting the rest of their queued
        -- offers without further prompts. Walk backwards while removing.
        for i = #acceptQueue, 1, -1 do
            local item = acceptQueue[i]
            if not item.isImport and item.sender == pendingSender then
                CH.ApplyLayout(item.guid, item.data, item.sender)
                table.remove(acceptQueue, i)
            end
        end
        if CH.RefreshSettingsTab then
            CH.RefreshSettingsTab()
        end
    end
    ShowNextAccept()
end)

btnDecline:SetScript("OnClick", function()
    -- One-time decline, nothing is remembered. Permanent muting is the block
    -- list (Settings), reachable via the consent dialog when someone requests.
    ShowNextAccept()
end)

-- Share.lua fires these instead of calling the dialogs directly, so the wire
-- layer stays free of UI knowledge. Wired here once both dialogs exist.
CH.onLayoutReceived = function(houseGUID, data, senderName)
    CH.ShowAcceptDialog(houseGUID, data, senderName)
end
CH.onConsentRequired = function(sender, guid)
    CH.ShowConsentDialog(sender, guid)
end

-- ─────────────────────────────────────────────────────────────────────
-- Transfer Progress Bars
-- ─────────────────────────────────────────────────────────────────────

local function MakeProgressBar(yOff)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(260, 48)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetPoint("TOP", UIParent, "TOP", 0, yOff)
    CH.SkinWindow(f, "")
    f.title:SetFontObject("GameFontNormalSmall") -- smaller than the default header font
    f:Hide()

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -26)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -26)
    bar:SetHeight(16)
    bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
    bar:SetStatusBarColor(CH.RGBA(CH.COLORS.frame, 1))

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)

    f.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")
    f.bar = bar
    return f
end

local recvBar = MakeProgressBar(-160)
local sendBar = MakeProgressBar(-214)

function CH.ShowReceiveProgress(owner, expected)
    local what = (owner and owner ~= "?") and string.format(CH.L["SUI_OWNERS_LAYOUT_X"], owner) or CH.L["SUI_A_LAYOUT"]
    recvBar.title:SetText(string.format(CH.L["SUI_RECEIVING_X"], what))
    recvBar.bar:SetMinMaxValues(0, math.max(expected, 1))
    recvBar.bar:SetValue(0)
    recvBar.text:SetText(string.format(CH.L["SUI_PROGRESS_X"], 0, expected))
    recvBar:Show()
end

function CH.UpdateReceiveProgress(current, expected)
    recvBar.bar:SetValue(current)
    recvBar.text:SetText(string.format(CH.L["SUI_PROGRESS_X"], current, expected))
end

function CH.HideReceiveProgress()
    recvBar:Hide()
end

function CH.ShowSendProgress(total)
    sendBar.title:SetText(CH.L["SUI_SHARING_TO_GROUP"])
    sendBar.bar:SetMinMaxValues(0, math.max(total, 1))
    sendBar.bar:SetValue(0)
    sendBar.text:SetText(string.format(CH.L["SUI_PROGRESS_X"], 0, total))
    sendBar:Show()
    if CH.SetShareBusy then
        CH.SetShareBusy(true)
    end
end

function CH.UpdateSendProgress(current, total)
    sendBar.bar:SetValue(current)
    sendBar.text:SetText(string.format(CH.L["SUI_PROGRESS_X"], current, total))
end

function CH.HideSendProgress()
    sendBar:Hide()
    if CH.SetShareBusy then
        CH.SetShareBusy(false)
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Export / Import Dialog
-- ─────────────────────────────────────────────────────────────────────

local exportDialog = CreateFrame("Frame", "ChamberlainExportDialog", UIParent, "BackdropTemplate")
exportDialog:SetSize(360, 110)
exportDialog:SetFrameStrata("FULLSCREEN_DIALOG")
exportDialog:SetPoint("CENTER")
CH.SkinWindow(exportDialog, "SUI_TITLE_LAYOUT_STRING", true)
exportDialog:Hide()
table.insert(UISpecialFrames, "ChamberlainExportDialog")

local exportHint = exportDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportHint:SetPoint("TOP", 0, -30)
exportHint:SetTextColor(0.7, 0.7, 0.7, 1)

local exportBox = CreateFrame("EditBox", "ChamberlainExportBox", exportDialog, "InputBoxTemplate")
exportBox:SetSize(330, 20)
exportBox:SetPoint("TOP", 0, -46)
exportBox:SetAutoFocus(false)
exportBox:SetScript("OnEscapePressed", function()
    exportDialog:Hide()
end)

local btnDoImport = CH.MakeButton(exportDialog, "SUI_IMPORT_BTN", 80, 22)
btnDoImport:SetPoint("BOTTOMLEFT", exportDialog, "BOTTOM", 2, 8)
btnDoImport:SetScript("OnClick", function()
    CH.ImportLayout(exportBox:GetText())
    exportDialog:Hide()
end)

local btnExportClose = CH.MakeButton(exportDialog, "SUI_CLOSE", 80, 22)
btnExportClose:SetPoint("BOTTOMRIGHT", exportDialog, "BOTTOM", -2, 8)
btnExportClose:SetScript("OnClick", function()
    exportDialog:Hide()
end)

-- mode "export": prefills the string of house guid, ready to copy.
-- mode "import": empty box, paste and click Import.
function CH.OpenExportDialog(mode, guid)
    if mode == "export" then
        local s = guid and CH.ExportLayout(guid)
        if not s then
            CH.Print(CH.L["SUI_NO_EXPORT"])
            return
        end
        exportHint:SetText(CH.L["SUI_COPY_HINT"])
        exportBox:SetText(s)
        btnDoImport:Hide()
        exportDialog:Show()
        exportBox:SetFocus()
        exportBox:HighlightText()
    else
        exportHint:SetText(CH.L["SUI_PASTE_HINT"])
        exportBox:SetText("")
        btnDoImport:Show()
        exportDialog:Show()
        exportBox:SetFocus()
    end
end
