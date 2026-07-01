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

-- Floor area of a zone, used to pick the smallest room when several overlap. A
-- circle is stored as a square bounding box, so its radius is half the width.
function CH.ZoneArea(z)
    local w, h = z.maxX - z.minX, z.maxY - z.minY
    if z.shape == "circle" then
        local r = w * 0.5
        return math.pi * r * r
    end
    return w * h
end

-- Short size readout for a zone: "8 x 6" for a rectangle, "8 wide" for a circle.
function CH.ZoneDimText(z)
    if z.shape == "circle" then
        return string.format(CH.L["FMT_DIAMETER_X"], z.maxX - z.minX)
    end
    return string.format(CH.L["FMT_DIM_X"], z.maxX - z.minX, z.maxY - z.minY)
end
