local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Small pure helpers
-- ─────────────────────────────────────────────────────────────────────

-- Seconds to a short "5h 2m" / "2m" / "30s" string.
function CH.FormatDuration(seconds)
    if seconds >= 3600 then
        return string.format(CH.L["UTIL_DURATION_HM"], seconds / 3600, (seconds % 3600) / 60)
    elseif seconds >= 60 then
        return string.format(CH.L["UTIL_DURATION_M"], seconds / 60)
    end
    return string.format(CH.L["UTIL_DURATION_S"], seconds)
end

-- First character of a name, UTF-8 aware (accented letters are multi-byte).
function CH.FirstChar(name)
    return name and string.match(name, "^[%z\1-\127\194-\244][\128-\191]*") or "?"
end
