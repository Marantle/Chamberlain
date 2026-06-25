local _, CH = ...
CH.locales = CH.locales or {}
local L = {}
CH.locales.ruRU = L

-- Russian (Русский) translations for Chamberlain.
--
-- Copy a line from enUS.lua and translate the text in quotes. Keep the
-- %s/%d placeholders and |cff....|r color codes as they are. Anything you
-- leave out falls back to English. Example:
--   L["CREATE_ROOM"] = "Создать комнату"
