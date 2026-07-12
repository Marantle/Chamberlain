"""Reassemble a translated CSV back into a Locale/<code>.lua file.

Usage:
    python reassemble_locale.py [in.csv] [out.lua] [locale_code]

Defaults: chamberlain-fi-clean.csv, Locale/fiFN.lua, fiFN.

Reads the 'key' and 'finnish' columns and writes L["KEY"] = "value" for every row
that carries a real translation. A row is skipped (so it falls back to English at
runtime) when its finnish cell is blank, equals the English, or still holds an
#ERR / #NO_KEY marker. Values keep their Lua escapes (\\n) as-is; only the double
quote is escaped for the "..." literal.
"""

import csv
import sys

inp = sys.argv[1] if len(sys.argv) > 1 else "chamberlain-fi-clean.csv"
out = sys.argv[2] if len(sys.argv) > 2 else "Locale/fiFN.lua"
code = sys.argv[3] if len(sys.argv) > 3 else "fiFN"

rows = list(csv.DictReader(open(inp, encoding="utf-8-sig")))

HEADER = """local _, CH = ...
CH.locales = CH.locales or {}
local L = {}
CH.locales.__CODE__ = L

-- Finnish (Suomi) translations for Chamberlain.
--
-- Finnish is not a language the WoW client ships, so GetLocale() never returns
-- "fiFN". This file is only reached when the player forces it from the Settings
-- tab (Language). Any key left out here falls back to English.
--
-- Generated from a translation CSV by reassemble_locale.py. Keys left
-- untranslated (blank or equal to English) are omitted on purpose so they fall
-- back. Re-run the script to regenerate after the CSV changes.

""".replace("__CODE__", code)


def lua_escape(s):
    # The double quote is the only character that would break a "..."-delimited
    # literal. Backslashes are left alone so an intended \n stays a newline escape.
    return s.replace('"', '\\"')


lines = []
written = blank = same = err = 0
for r in rows:
    key = r["key"]
    en = r.get("english", "")
    fi = r["finnish"]
    if not fi.strip():
        blank += 1
        continue
    if fi.startswith("#ERR") or fi.startswith("#NO_KEY"):
        err += 1
        continue
    if fi == en:
        same += 1
        continue
    lines.append('L["{}"] = "{}"'.format(key, lua_escape(fi)))
    written += 1

with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(HEADER)
    f.write("\n".join(lines))
    f.write("\n")

print("wrote {} to {}".format(written, out))
print("skipped: blank={} same-as-english={} error-marker={}".format(blank, same, err))
