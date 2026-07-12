local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Locale loader / merge  (must load LAST of the Locale\ files)
-- ─────────────────────────────────────────────────────────────────────
-- Each Locale\<code>.lua file registered its translations into CH.locales.
-- Build the active table from the full English set, then overlay whatever the
-- chosen locale has translated. Any key a locale leaves out keeps its English
-- value, so partial and untranslated languages both fall back to English.
--
-- The chosen locale is CH.FORCE_LANGUAGE (set in Locale\SetLanguage.lua) when the
-- player has picked one, otherwise the WoW client language. Because this runs at
-- file load, before any window is built, CH.L is correct from the first frame and
-- nothing has to be re-stamped later.

local code = CH.FORCE_LANGUAGE or GetLocale()

local L = CopyTable(CH.locales.enUS)

local cur = CH.locales[code]
if cur and cur ~= CH.locales.enUS then
    for k, v in pairs(cur) do
        if v ~= nil and v ~= "" then
            L[k] = v
        end
    end
end

-- Last-resort fallback: a key missing even from enUS returns its own name, which
-- surfaces a typo'd or forgotten key on screen instead of a nil error.
CH.L = setmetatable(L, {
    __index = function(_, k)
        return k
    end,
})

-- Staging table no longer needed.
CH.locales = nil
