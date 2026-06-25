local _, CH = ...

-- ─────────────────────────────────────────────────────────────────────
-- Shared colors and backdrop presets
-- ─────────────────────────────────────────────────────────────────────
-- The same handful of gold/bronze tones were copied as raw numbers all over
-- the UI. They live here now so a palette tweak is one edit. Stored as {r,g,b};
-- pass your own alpha at the call site (SetColorTexture/SetBackdropColor take 4).

CH.COLORS = {
    gold = { 1.00, 0.90, 0.30 }, -- bright gold: section headers, banner text
    frame = { 0.85, 0.70, 0.15 }, -- window border and header underline
    border = { 0.55, 0.45, 0.15 }, -- bronze control border: swatches, buttons
    sep = { 0.55, 0.50, 0.10 }, -- faint divider lines
    grey = { 0.25, 0.25, 0.25 }, -- "no color set" placeholder swatch
}

-- 1px white-fill backdrop used by most of our flat frames. SetBackdrop copies
-- the table, so sharing one instance across frames is safe.
CH.BACKDROP_THIN = {
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
}

-- Spread a {r,g,b} palette entry plus an alpha into the four args the color
-- setters want: CH.RGBA(CH.COLORS.frame, 0.8) -> r, g, b, 0.8
function CH.RGBA(c, a)
    return c[1], c[2], c[3], a
end
