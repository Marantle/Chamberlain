local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Text-to-speech  (local only, never shared)
-- ─────────────────────────────────────────────────────────────────────
-- Reads a room's description aloud with the OS SAPI voice picked for it. Stored
-- per zone as a NAME string (zone.voice), not the voiceID, since voiceIDs are list
-- positions that shift when voices are added or removed. Kept out of the export
-- and share path, so it never leaves this client.

-- C_VoiceChat.SpeakText changed signature in the 12.0 client. Older clients took a
-- destination arg before rate/volume. Detect the build once and pick the call. The
-- wrong order puts the volume in the wrong slot and plays silently.
local rawSpeak
do
    local iface = select(4, GetBuildInfo())
    if iface and iface >= 120000 then
        rawSpeak = function(id, text, rate, vol, overlap)
            C_VoiceChat.SpeakText(id, text, rate or 0, vol or 100, overlap or false)
        end
    else
        local DEST = (Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback) or 1
        rawSpeak = function(id, text, rate, vol, overlap)
            C_VoiceChat.SpeakText(id, text, DEST, rate or 0, vol or 100, overlap or false)
        end
    end
end

-- Every TTS voice the client exposes (the OS SAPI 5 list), or an empty table.
function CH.GetVoices()
    return (C_VoiceChat and C_VoiceChat.GetTtsVoices()) or {}
end

-- Resolve a stored voice name to a live voiceID, or nil if it's unset or the
-- voice is no longer instaled.
function CH.FindVoiceID(name)
    if not name then
        return nil
    end
    for _, v in ipairs(CH.GetVoices()) do
        if v.name == name then
            return v.voiceID
        end
    end
    return nil
end

-- Speak text with the named voice. No-op when text or voice is missing, so a room
-- with no chosen voice stays silent. overlap=false cuts off any current speech.
-- Wrapped in pcall: SpeakText is protected during boss encounters.
function CH.Speak(text, voiceName)
    if not text or text == "" then
        return
    end
    local id = CH.FindVoiceID(voiceName)
    if not id then
        return
    end
    text = text:gsub("[<>]", ""):gsub("%-%-", ". ") -- TTS chokes on these
    pcall(rawSpeak, id, text, 0, 100, false)
end

function CH.StopSpeaking()
    if C_VoiceChat then
        pcall(C_VoiceChat.StopSpeakingText)
    end
end

-- Compact display label for a voice name. OS names like "Microsoft Noora Online
-- (Natural) - Finnish (Finland)" are too long for a button, so strip the vendor
-- prefix and the locale and qualifier text. Returns nil for nil. Callers supply
-- their own "none" label. Menus still show the full names.
function CH.ShortVoiceName(name)
    if not name then
        return nil
    end
    local s = name:gsub("^Microsoft%s+", "")
    s = s:gsub("%s*%-%s*.*$", "") -- drop " - Finnish (Finland)"
    s = s:gsub("%s*%(.-%)", "") -- drop "(Natural)" etc.
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s ~= "" and s or name
end

-- Decide which voice reads a zone's description.
--  * Own house: the per-room pick wins (zone.voice, or nil for silent).
--  * Visiting or a shared layout: the room carries no local voice, so fall back to
--    your personal default for the head's gender when defaults are on.
-- genderOverride lets the caller pass a gender (e.g. the owner's UnitSex when the
-- room shows their own character); otherwise the head's gender is used.
function CH.ResolveZoneVoice(zone, isOwnHouse, genderOverride)
    if isOwnHouse then
        return zone.voice
    end
    if zone.voice then
        return zone.voice
    end
    local s = ChamberlainDB.settings
    if not s.voiceDefaultsEnabled then
        return nil
    end
    local gender = genderOverride
    if not gender then
        local head = CH.HEADS[zone.headID or 1]
        gender = head and head.gender
    end
    local pick = (gender == "female") and s.voiceFemale or s.voiceMale
    return pick or s.voiceMale or s.voiceFemale -- whichever default is set
end
