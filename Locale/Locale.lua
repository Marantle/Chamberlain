local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Locale loader / merge  (must load LAST of the Locale\ files)
-- ─────────────────────────────────────────────────────────────────────
-- Each Locale\<code>.lua file registered its translations into CH.locales.
-- Build the active table from the full English set, then overlay whatever the
-- player's client locale has translated. Any key a locale leaves out keeps its
-- English value, so partial and untranslated languages both fall back to English.

local L = CopyTable(CH.locales.enUS)

local cur = CH.locales[GetLocale()]
if cur then
    for k, v in pairs(cur) do
        if v ~= nil and v ~= "" then
            L[k] = v
        end
    end
end

-- Last-resort fallback: a key missing even from enUS returns its own name,
-- which surfaces a typo'd/forgotten key on screen instead of a nil error.
CH.L = setmetatable(L, {
    __index = function(_, k)
        return k
    end,
})

-- Staging table no longer needed.
CH.locales = nil
