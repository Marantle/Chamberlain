"""CHANGELOG helpers for the release targets.

  python changelog.py check <toc_version> <code_version>
      Exit non-zero unless the .toc, the Lua code, and the top CHANGELOG entry name
      the same valid X.Y.Z version, and that version is higher than the previous
      entry.

  python changelog.py notes
      Write this release's notes (the top entry's body) to .notes.md.
"""

import re
import sys


def entries(text):
    # (version, body) for each "## x.y.z" section, in file order. A leading
    # "# Changelog" H1 has one hash and is ignored.
    heads = list(re.finditer(r"(?m)^## (.+?)\s*$", text))
    out = []
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        out.append((h.group(1), text[h.end():end].strip()))
    return out


def version_parts(v):
    return tuple(int(n) for n in v.split("."))


def main():
    items = entries(open("CHANGELOG.md", encoding="utf-8").read())
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""

    if cmd == "notes":
        open(".notes.md", "w", encoding="utf-8").write(items[0][1] if items else "")
        return

    if cmd == "check":
        version, code_version = sys.argv[2], sys.argv[3]
        top = items[0][0] if items else "(none)"

        def fail(msg):
            sys.exit("Release check: " + msg)

        if not re.match(r"^\d+\.\d+\.\d+$", version):
            fail("version %r is not X.Y.Z" % version)
        if version != code_version:
            fail(".toc Version %s does not match CH.VERSION %s" % (version, code_version))
        if top != version:
            fail("CHANGELOG top is %s, expected %s" % (top, version))
        if len(items) > 1 and version_parts(version) <= version_parts(items[1][0]):
            fail("version %s is not higher than previous %s" % (version, items[1][0]))
        print("Release check OK: " + version)
        return

    sys.exit("changelog.py: unknown command %r" % cmd)


main()
