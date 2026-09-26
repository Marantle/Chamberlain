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
-- shaped room fills only part of its box (CH.SHAPES).
function CH.ZoneArea(z)
    local def = z.shape and CH.SHAPES[z.shape]
    return (z.maxX - z.minX) * (z.maxY - z.minY) * (def and def.keep or 1)
end

-- Short size readout for a zone: "8 x 6" for a rectangle, "8 wide" for a
-- shaped room, which only ever scales as a whole.
function CH.ZoneDimText(z)
    if z.shape then
        return string.format(CH.L["FMT_DIAMETER_X"], z.maxX - z.minX)
    end
    return string.format(CH.L["FMT_DIM_X"], z.maxX - z.minX, z.maxY - z.minY)
end

-- The game's box for a shaped room at a quarter turn (an L stays square, a
-- T lies on its side).
function CH.ShapeSize(shape, rot)
    local def = CH.SHAPES[shape]
    if (rot or 0) % 2 == 1 then
        return def.h, def.w
    end
    return def.w, def.h
end

-- Set a zone's box to w by h about (cx, cy), which is how every shaped room
-- is placed and resized.
function CH.BoxAbout(z, cx, cy, w, h)
    z.minX, z.maxX = cx - w * 0.5, cx + w * 0.5
    z.minY, z.maxY = cy - h * 0.5, cy + h * 0.5
end

function CH.ZoneCentre(z)
    return (z.minX + z.maxX) * 0.5, (z.minY + z.maxY) * 0.5
end

-- A point in a turned box, as fractions of it, back to where it sits in the
-- shape's own orientation. The mask files are drawn turned the same way.
local function Unturn(u, v, rot)
    if rot == 1 then
        return v, 1 - u
    elseif rot == 2 then
        return 1 - u, 1 - v
    elseif rot == 3 then
        return 1 - v, u
    end
    return u, v
end

-- Is (x, y) inside the room: its box for a rectangle, the disc for a circle,
-- the box less its missing corners for the rest. The box test alone anwsers
-- for most spots, so the rest only runs once you are close.
function CH.ZoneContains(z, x, y)
    if x < z.minX or x > z.maxX or y < z.minY or y > z.maxY then
        return false
    end
    local def = z.shape and CH.SHAPES[z.shape]
    if not def then
        return true
    end
    local u, v = (x - z.minX) / (z.maxX - z.minX), (y - z.minY) / (z.maxY - z.minY)
    if z.shape == "circle" then
        local dx, dy = u - 0.5, v - 0.5
        return dx * dx + dy * dy <= 0.25
    end
    u, v = Unturn(u, v, z.rot)
    if def.diag then
        local d = def.diag
        return u + v >= d and 1 - u + v >= d and u + 1 - v >= d and 2 - u - v >= d
    end
    for _, c in ipairs(def.cuts) do
        if u >= c[1] and u <= c[3] and v >= c[2] and v <= c[4] then
            return false
        end
    end
    return true
end
