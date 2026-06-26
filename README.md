# Chamberlain
World of Warcraft: Midnight player housing addon

https://www.curseforge.com/wow/addons/chamberlain-room-names-for-housing

Room names for player housing (retail, Interface 120007). Mark two corners of a
room, name it, and a gold banner greets you whenever you walk in. Share your
layout with your group, or grab theirs when you visit.

Also additionally can create description that a talking head can read out aloud when you enter a room and click "read".

Named after the manor officer who announced guests to each room.

## Features

- Name rectangular zones inside your house; a banner fades in/out as you cross them
- Floor plan window with a top-down view of your rooms and a live position dot
- Share layouts with your group, party or raid (consent dialog on every request, block list included)
- Per-house data keyed by house GUID, so two houses on one account stay separate
- Descriptions for rooms, that can optionally be read out loud by your favorite NPC talking heads
- Multiple floors via some geofence trickery since WoW does not expose player elevation to addons.

## Slash commands

- `/chamberlain manage` - open the room manager (alias: `/rooms`)
- `/chamberlain floor` - open the floor plan
- `/chamberlain delete <name>` - remove a room
- `/chamberlain reset` - reset frame positions
- `/chamberlain hud` - toggle the position HUD
- `/chamberlain debug` - toggle share debug logging
- `/chamberlain version` - print addon version

## A note on the comment dividers

Oh Yes, the source is full of `── long unicode lines ──` between sections, not because of AI, but because I want them to trip people up.

## Development

Copy `.env.example` to `.env` and fill in your CurseForge token before releasing.

```
make lint          run luacheck
make format        format all Lua files with stylua
make check         format validation without writing (CI)
make package       build Chamberlain-x.y.z.zip
make package-min   build minified zip (comments stripped)
make release       upload to CurseForge (requires CURSEFORGE_TOKEN in .env)
make clean         remove built zips
```

Set `CURSE_PROJECT` in the Makefile to your CurseForge project ID once you have one.
