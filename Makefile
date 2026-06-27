-include .env
export

ADDON          := Chamberlain
VERSION        := $(shell grep "^\#\# Version:" $(ADDON).toc | awk '{print $$3}')
TOC_VERSION    := $(shell grep "^\#\# Interface:" $(ADDON).toc | awk '{print $$3}')
TOC_DISPLAY    := $(shell echo $(TOC_VERSION) | awk '{printf "%d.%d.%d", substr($$0,1,2), substr($$0,3,2), substr($$0,5,2)}')
CODE_VERSION   := $(shell grep "^CH.VERSION" Core/Core.lua | awk -F'"' '{print $$2}')
CURSE_PROJECT  := 1573197
WAGO_PROJECT   := $(shell grep "^\#\# X-Wago-ID:" $(ADDON).toc | awk '{print $$3}')
WOWI_PROJECT   := $(shell grep "^\#\# X-WoWI-ID:" $(ADDON).toc | awk '{print $$3}')
# Packaged files are derived from the .toc, never hand-listed, so the zip can
# never drift from what the game actually loads. (2.4.0 and 2.4.1 alphas shipped
# without Voice.lua and Stairs.lua because a hardcoded list here was never updated
# when those files were added to the .toc, leaving the .toc referencing files the
# zip didn't contain.) Pull every .lua line the .toc references, drop CRLF, and
# convert the backslash paths to forward slashes (\134 is octal for backslash).
SRC_LUA        := $(shell grep -vE '^[[:space:]]*\#' $(ADDON).toc | grep -iE '\.lua[[:space:]]*$$' | tr -d '\r' | tr '\134' '/')
SRC_FILES      := $(SRC_LUA) $(ADDON).toc
DIST_FILES     := $(SRC_FILES)
SRC_DIRS       := Core Housing UI Sharing Locale
RELEASE_TYPE   ?= alpha
CHANGELOG      ?= See project page for changes.

.PHONY: help lint format check package package-min notes release-check release release-wago release-wowi release-github release-all clean

help:
	@echo "make lint          run luacheck"
	@echo "make format        format all Lua files with stylua"
	@echo "make check         check formatting without writing (for CI)"
	@echo "make package       build $(ADDON)-$(VERSION).zip"
	@echo "make package-min   build $(ADDON)-$(VERSION)-min.zip (comments stripped)"
	@echo "make release       upload to CurseForge (requires CURSEFORGE_TOKEN)"
	@echo "make release-wago  upload to Wago (requires WAGO_API_TOKEN)"
	@echo "make release-wowi  upload to WoWInterface (requires WOWI_API_TOKEN and X-WoWI-ID)"
	@echo "make release-github  create a GitHub release (uses gh)"
	@echo "make release-all   upload to every configured platform"
	@echo "make clean         remove built zips"

# stylua and luacheck are 64-bit exes in System32. GnuWin32 make is 32-bit, so
# WOW64 redirection hides them from its direct process spawn and a bare command
# fails with "file not found". Running them through $(SHELL), which is 64-bit Git
# sh, resolves them. On Linux/CI $(SHELL) is /bin/sh, so this changes nothing.
lint:
	@"$(SHELL)" -c "luacheck $(SRC_DIRS)"

format:
	@"$(SHELL)" -c "stylua $(SRC_DIRS)"

check:
	@"$(SHELL)" -c "stylua --check $(SRC_DIRS)"

# zip on Linux (CI), Compress-Archive on Windows. Both leave a Chamberlain/ folder
# at the zip root, which is the layout every platform expects.
package: clean
	@echo "Packaging $(ADDON) v$(VERSION)..."
	@mkdir -p dist/$(ADDON)
	@cp --parents $(SRC_FILES) dist/$(ADDON)/
	@if command -v zip >/dev/null 2>&1; then \
	  (cd dist && zip -qr "../$(ADDON)-$(VERSION).zip" "$(ADDON)"); \
	else \
	  pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION).zip'"; \
	fi
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION).zip"

package-min: clean
	@echo "Packaging $(ADDON) v$(VERSION) (minified)..."
	@mkdir -p dist/$(ADDON)
	@python minify.py dist/$(ADDON) $(DIST_FILES)
	@if command -v zip >/dev/null 2>&1; then \
	  (cd dist && zip -qr "../$(ADDON)-$(VERSION)-min.zip" "$(ADDON)"); \
	else \
	  pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION)-min.zip'"; \
	fi
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION)-min.zip"

# Write this release's notes (the top CHANGELOG entry's body) to .notes.md, which
# every upload target sends as its changelog.
notes:
	@python changelog.py notes

# Block a release unless the .toc, the Lua code, and the changelog all name the
# same valid version, and that version is higher than the previous changelog entry.
# The clean-tree check is skipped under CI, where the checkout is already clean.
release-check:
	@test -n "$$CI" || [ -z "$$(git status --porcelain --untracked-files=no)" ] || { echo "Error: uncommitted changes; commit before releasing"; exit 1; }
	@python changelog.py check "$(VERSION)" "$(CODE_VERSION)"

release: release-check package notes
	@test -n "$(CURSEFORGE_TOKEN)" || { echo "Error: CURSEFORGE_TOKEN not set"; exit 1; }
	@test "$(CURSE_PROJECT)" != "0" || { echo "Error: set CURSE_PROJECT in Makefile first"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip (WoW $(TOC_DISPLAY)) to CurseForge..."
	@GAME_VER_ID=$$(curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  "https://wow.curseforge.com/api/game/versions" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x['name']==v),''))"); \
	test -n "$$GAME_VER_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found in CurseForge API"; exit 1; }; \
	python -c "import json; open('.release_meta.json','w').write(json.dumps({'gameVersions':[int('$$GAME_VER_ID')],'releaseType':'$(RELEASE_TYPE)','changelog':open('.notes.md',encoding='utf-8').read(),'changelogType':'markdown'}))" && \
	curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  -F "metadata=<.release_meta.json;type=application/json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://wow.curseforge.com/api/projects/$(CURSE_PROJECT)/upload-file" && \
	rm -f .release_meta.json && \
	echo "Released $(ADDON)-$(VERSION).zip as '$(RELEASE_TYPE)'."

# Wago calls a stable build "stable" where CurseForge calls it "release".
release-wago: release-check package notes
	@test -n "$(WAGO_API_TOKEN)" || { echo "Error: WAGO_API_TOKEN not set"; exit 1; }
	@test -n "$(WAGO_PROJECT)" || { echo "Error: X-Wago-ID not set in $(ADDON).toc"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip to Wago..."
	@STAB=$$(test "$(RELEASE_TYPE)" = "release" && echo stable || echo "$(RELEASE_TYPE)"); \
	python -c "import json; open('.wago_meta.json','w').write(json.dumps({'label':'$(VERSION)','stability':'$$STAB','changelog':open('.notes.md',encoding='utf-8').read(),'supported_retail_patch':'$(TOC_DISPLAY)'}))" && \
	curl -sf \
	  -H "Authorization: Bearer $(WAGO_API_TOKEN)" \
	  -H "Accept: application/json" \
	  -F "metadata=<.wago_meta.json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://addons.wago.io/api/projects/$(WAGO_PROJECT)/version" && \
	rm -f .wago_meta.json && \
	echo "Released to Wago as '$$STAB'."

# WoWInterface field names follow its addons/update API. Confirm them against the
# live docs before the first real upload. Inert until X-WoWI-ID and the token are set.
release-wowi: release-check package notes
	@test -n "$(WOWI_API_TOKEN)" || { echo "Error: WOWI_API_TOKEN not set"; exit 1; }
	@test -n "$(WOWI_PROJECT)" || { echo "Error: X-WoWI-ID not set in $(ADDON).toc"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip to WoWInterface..."
	@COMPAT_ID=$$(curl -sf "https://api.wowinterface.com/addons/compatible.json" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x.get('name')==v),''))"); \
	test -n "$$COMPAT_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found in WoWInterface API"; exit 1; }; \
	curl -sf \
	  -H "x-api-token: $(WOWI_API_TOKEN)" \
	  -F "id=$(WOWI_PROJECT)" \
	  -F "version=$(VERSION)" \
	  -F "compatible=$$COMPAT_ID" \
	  -F "changelog=<.notes.md" \
	  -F "archive=@$(ADDON)-$(VERSION).zip" \
	  "https://api.wowinterface.com/addons/update" && \
	echo "Released to WoWInterface."

release-github: release-check package notes
	@echo "Creating GitHub release $(VERSION)..."
	@PRE=$$(test "$(RELEASE_TYPE)" = "release" || echo --prerelease); \
	gh release create "$(VERSION)" "$(ADDON)-$(VERSION).zip" --title "$(VERSION)" --notes-file .notes.md $$PRE && \
	echo "Released $(VERSION) on GitHub."

# Push to every platform that's configured. A site with no token (or no ID) is
# skipped with a notice instead of failing. WoWInterface has no alpha/beta channel,
# so non-release types skip it rather than push a prerelease as the live download.
release-all: release-check
	@if [ -n "$(CURSEFORGE_TOKEN)" ]; then $(MAKE) release; else echo "Skipping CurseForge (CURSEFORGE_TOKEN not set)"; fi
	@if [ -n "$(WAGO_API_TOKEN)" ]; then $(MAKE) release-wago; else echo "Skipping Wago (WAGO_API_TOKEN not set)"; fi
	@if [ "$(RELEASE_TYPE)" != "release" ]; then echo "Skipping WoWInterface (no alpha/beta channel; RELEASE_TYPE=$(RELEASE_TYPE))"; \
	  elif [ -n "$(WOWI_API_TOKEN)" ] && [ -n "$(WOWI_PROJECT)" ]; then $(MAKE) release-wowi; \
	  else echo "Skipping WoWInterface (WOWI_API_TOKEN or X-WoWI-ID not set)"; fi
	@$(MAKE) release-github

debug-release: package
	@test -n "$(CURSEFORGE_TOKEN)" || { echo "Error: CURSEFORGE_TOKEN not set"; exit 1; }
	@echo "Fetching game version ID for WoW $(TOC_DISPLAY)..."
	@GAME_VER_ID=$$(curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  "https://wow.curseforge.com/api/game/versions" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x['name']==v),''))"); \
	test -n "$$GAME_VER_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found"; exit 1; }; \
	echo "Game version ID: $$GAME_VER_ID"; \
	python -c "import json; open('.release_meta.json','w').write(json.dumps({'gameVersions':[int('$$GAME_VER_ID')],'releaseType':'$(RELEASE_TYPE)','changelog':open('CHANGELOG.md').read(),'changelogType':'markdown'}))" && \
	echo "Metadata:" && cat .release_meta.json && echo "" && \
	curl -v \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  -F "metadata=<.release_meta.json;type=application/json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://wow.curseforge.com/api/projects/$(CURSE_PROJECT)/upload-file"; \
	rm -f .release_meta.json

clean:
	@rm -f $(ADDON)-*.zip .notes.md .wago_meta.json
	@rm -rf dist
