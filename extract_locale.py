"""Extract enUS locale strings to a translation CSV with per-row context.

Usage:
    python extract_locale.py [--formulas] [enUS.lua] [translation-context.json] [out.csv]

Defaults: Locale/enUS.lua, translation-context.json, chamberlain-<lang>.csv.

Columns: key, english, context, finnish.
The context column is fed to the translator (DeepL 'context' field). It is built
from the context file's prefix map, its word-specific term hints, and automatic
notes about placeholders / color codes / slash commands found in each string.

With --formulas the finnish column is pre-filled so the sheet translates itself
on import: =DEEPL(B<row>, C<row>) for translatable rows, =B<row> for DO NOT
TRANSLATE rows (they mirror the English). Without it, finnish is left blank.
Note: pre-filled DEEPL formulas all evaluate at once on import, which can hit
DeepL's rate limit the same way dragging the formula down does. The DEEPL cell
function retries, so it self-heals, but the Chamberlain menu batch runner in
deepl.gs is the burst-free alternative (leave finnish blank for that path).

Exits non-zero and lists any key whose prefix is not covered by the context file,
so the map stays in step whenever new UI strings are added.
"""

import csv
import json
import re
import sys

argv = [a for a in sys.argv[1:] if a != "--formulas"]
formulas = "--formulas" in sys.argv
src = argv[0] if len(argv) > 0 else "Locale/enUS.lua"
ctx_path = argv[1] if len(argv) > 1 else "translation-context.json"
out = argv[2] if len(argv) > 2 else "chamberlain-fi.csv"

with open(src, encoding="utf-8") as f:
    text = f.read()
with open(ctx_path, encoding="utf-8") as f:
    ctx = json.load(f)

# L["KEY"] = "value"  -- no escaped double quotes appear in this file, and \s*
# spans the newline in the multi-line entries. [^"]* stops at the first closer.
pattern = re.compile(r'L\["([A-Z0-9_]+)"\]\s*=\s*"([^"]*)"')

# Longest prefix first, so CMD_HELP_ wins over CMD_ etc.
prefixes = sorted(ctx["prefixes"], key=lambda p: len(p["match"]), reverse=True)
terms = ctx["terms"]
lead = ctx.get("lead", "")
skip_prefixes = ctx.get("skip_prefixes", [])
skip_keys = set(ctx.get("skip_keys", []))

PLACEHOLDER = re.compile(r"%%|%[-+ 0-9.]*[sdfxX]")

SKIP_CONTEXT = (
    "DO NOT TRANSLATE. Format/label scaffolding only (placeholders, unit letters, "
    "coordinates) that Chamberlain renders identically in every language. Leave the "
    "finnish cell blank so it falls back to English."
)


def is_skip(key):
    return key in skip_keys or any(key.startswith(p) for p in skip_prefixes)


def context_for(key, english):
    parts = [lead]

    surface = next((p["context"] for p in prefixes if key.startswith(p["match"])), None)
    if surface:
        parts.append(surface)

    if "_TT" in key or key.endswith("TT"):
        parts.append("This is one line of a mouseover tooltip.")
    elif "TITLE" in key:
        parts.append("This is a window title.")

    for t in terms:
        if t.get("whole"):
            hit = re.search(r"\b" + re.escape(t["match"]) + r"\b", english, re.I)
        else:
            hit = t["match"].lower() in english.lower()
        if hit:
            parts.append(t["context"])

    if PLACEHOLDER.search(english):
        parts.append("Keep the format placeholders (%s, %d, %.0f, %%) exactly as written and in the same order.")
    if "|cff" in english.lower() or "|r" in english:
        parts.append("Keep the |cff...|r color codes unchanged; translate only the words between them.")
    if "/chamberlain" in english or "/rooms" in english:
        parts.append("Keep slash commands like /chamberlain and /rooms unchanged.")

    return " ".join(parts)


rows, seen, uncovered = [], set(), []
for m in pattern.finditer(text):
    key, english = m.group(1), m.group(2)
    if key in seen:
        raise SystemExit("duplicate key: " + key)
    seen.add(key)
    if is_skip(key):
        rows.append((key, english, SKIP_CONTEXT, True))
        continue
    if not any(key.startswith(p["match"]) for p in prefixes):
        uncovered.append(key)
    rows.append((key, english, context_for(key, english), False))

with open(out, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(["key", "english", "context", "finnish"])
    for i, (key, english, context, skip) in enumerate(rows):
        # Sheet row: header is row 1, so the first data row is row 2.
        row_num = i + 2
        if not formulas:
            finnish = ""
        elif skip:
            finnish = "=B{}".format(row_num)  # format-only, mirror the English
        else:
            finnish = "=DEEPL(B{}, C{})".format(row_num, row_num)
        w.writerow([key, english, context, finnish])

print(f"{len(rows)} strings written to {out}")
if uncovered:
    print("\nWARNING: no context prefix matched these keys, add a prefix to translation-context.json:")
    for k in uncovered:
        print("  " + k)
    sys.exit(1)
