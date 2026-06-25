-include .env
export

ADDON          := Chamberlain
VERSION        := $(shell grep "^\#\# Version:" $(ADDON).toc | awk '{print $$3}')
TOC_VERSION    := $(shell grep "^\#\# Interface:" $(ADDON).toc | awk '{print $$3}')
TOC_DISPLAY    := $(shell echo $(TOC_VERSION) | awk '{printf "%d.%d.%d", substr($$0,1,2), substr($$0,3,2), substr($$0,5,2)}')
CURSE_PROJECT  := 1573197
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

.PHONY: help lint format check package package-min release clean

help:
	@echo "make lint          run luacheck"
	@echo "make format        format all Lua files with stylua"
	@echo "make check         check formatting without writing (for CI)"
	@echo "make package       build $(ADDON)-$(VERSION).zip"
	@echo "make package-min   build $(ADDON)-$(VERSION)-min.zip (comments stripped)"
	@echo "make release       upload to CurseForge (requires CURSEFORGE_TOKEN env var)"
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

package: clean
	@echo "Packaging $(ADDON) v$(VERSION)..."
	@mkdir -p dist/$(ADDON)
	@cp --parents $(SRC_FILES) dist/$(ADDON)/
	@pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION).zip'"
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION).zip"

package-min: clean
	@echo "Packaging $(ADDON) v$(VERSION) (minified)..."
	@mkdir -p dist/$(ADDON)
	@python minify.py dist/$(ADDON) $(DIST_FILES)
	@pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION)-min.zip'"
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION)-min.zip"

release: package
	@test -n "$(CURSEFORGE_TOKEN)" || { echo "Error: CURSEFORGE_TOKEN not set"; exit 1; }
	@test "$(CURSE_PROJECT)" != "0" || { echo "Error: set CURSE_PROJECT in Makefile first"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip (WoW $(TOC_DISPLAY)) to CurseForge..."
	@GAME_VER_ID=$$(curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  "https://wow.curseforge.com/api/game/versions" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x['name']==v),''))"); \
	test -n "$$GAME_VER_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found in CurseForge API"; exit 1; }; \
	python -c "import json; open('.release_meta.json','w').write(json.dumps({'gameVersions':[int('$$GAME_VER_ID')],'releaseType':'$(RELEASE_TYPE)','changelog':open('CHANGELOG.md').read(),'changelogType':'markdown'}))" && \
	curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  -F "metadata=<.release_meta.json;type=application/json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://wow.curseforge.com/api/projects/$(CURSE_PROJECT)/upload-file" && \
	rm -f .release_meta.json && \
	echo "Released $(ADDON)-$(VERSION).zip as '$(RELEASE_TYPE)'."

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
	@rm -f $(ADDON)-*.zip
	@rm -rf dist
