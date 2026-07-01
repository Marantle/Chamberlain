# Changelog

## 2.9.0
- The position HUD is now a small launcher. Instead of a tall stack of buttons it
  carries a few: Build, Map, Rooms, and Settings. The House Map is one click away
  again. It still shows in your own house and can be moved or hidden the same way.
- New build toolbox. Click Build to open it. It
  shows your live coordinates and holds the tools for making and fitting rooms.
- Making a room no longer needs Mark A, Mark B and Create. Stand where you want the
  room and click Add room here. A small room drops at your feet and the name box
  opens right away.
- Fit a room while you stand in it: pick the room in the toolbox, walk to a wall and
  click Snap nearest edge to me, or use Grow and Shrink. The house map keeps its
  drag handles for fitting from above.
- Add stairs and Floor marker moved off the HUD and into the toolbox.
- Settings moved out of the room manager into their own window, opened by the
  Settings button or /chamberlain settings. The room manager is now only My Rooms
  and Party.
- The minimap button: left-click shows or hides the launcher as before, middle-click
  opens the house map, right-click opens the room manager.
- Rooms can be round. In the toolbox, Add a Circle instead of a Square and it drops
  where you stand like any room. A circle's banner fires inside the actual circle,
  not the corners of its box. Size it with Grow and Shrink, or stand at the rim and
  click Set radius to me. Round rooms draw as a disc on the house map, and they
  share and export like any other room. Older clients see them as a square.
- A "Room banners" switch in Settings turns the gold name banner off entirely, for
  players who only want the map. It's personal and stays on your computer, and
  flipping it off clears any banner already showing.

## 2.8.0
- A room set to use the owner's own head now shows that person to visitors as long
  as you are in a party with them, even when they are on a different character than
  the one that owns the house. Their addon announces who they are while they are
  home, and yours points the talking head at them. They leave the group and it
  falls back to the room's curated head.

## 2.7.0
- The Floor Plan is now called the House Map.
- Rooms can be resized and moved by dragging handles on the map: grab a corner or
  edge to resize, the centre grip to move. 
  The Move/Grow/Shrink buttons still work for tiny nudges.
- A selected room is now clearly highlighted, and the hover tooltip follows your
  selection as you click through overlapping rooms.
- All floors share one scale, so switching floors no longer jumps or rescales the
  view, and editing a room no longer makes the map twitch. Reset view or a
  double-click reframes to the whole house.
- Stair landings are named for where they take you, "To F2" and "To F1", instead
  of "Stairs Up" and "Stairs Down".
- The stair editor shows which floors a landing connects, keeps its floor fixed
  while it is a staircase, and can switch a landing to a one-way teleporter and back.
- Fixed the stair editor's behaviour menu opening behind the window.
- Fixed dragging a stair box over your character switching your floor mid-edit.
- Fixed the map sometimes sticking to the cursor after a pan.

## 2.6.0
- The Floor Plan now remembers being open across a /reload or relog, but only when
  you're inside a house. Reload outside a house and it stays closed, so it never
  reopens to an empty map.

## 2.5.0
- Localization support. Every visible string now goes through a locale table, so
  Chamberlain can be translated. English ships complete. German, French, Spanish
  (EU and LatAm), Italian, Korean, Brazilian Portuguese, Russian, and both Chinese
  variants ship as empty stubs in Locale\ ready for translators to fill in. Any
  untranslated line falls back to English, so a partly-translated language is fine.
- The "Create Zone" button on the position HUD is now labelled "Create Room".
 
## 2.4.1
- Fixed the 2.4.0 release shipping without UI/Stairs.lua and Core/Voice.lua, which
  meant the Add stairs and Floor marker buttons did nothing and per-room voice
  never played.
- Fixed the Floor Plan's "Move to floor" button being unclickable, and the +/-
  floor arrows being partly unclickable, where the map canvas overlapped them and
  swallowed the clicks.
- Fixed the "You're on floor N" reminder not showing while viewing an empty floor,
  so browsing a floor with no rooms yet no longer hides where you actually are.

## 2.4.0
- Multiple floors. A house can now have more than one floor and rooms are scoped
  to the floor they sit on, so a room upstairs and a room directly below it no
  longer fight over the same banner. Open the Floor Plan and use Add floor, then
  use the up/down arrows to browse each floor.
- Stairs. Since the game gives addons no height information, Chamberlain follows
  you between floors by watching your staircases. Use Add stairs on the position
  HUD (or from the one-time intro), stand at the bottom and mark it, walk to the
  top and mark it, and from then on walking up or down switches the active floor.
  A stair banner ("Stairs Up" / "Stairs Down") confirms it as you cross. For odd
  spots a staircase can't cover there's also a Floor marker that sets a chosen
  floor from anywhere.
- Spiral staircases work: a staircase only switches floors between the two floors
  it connects, so walking on floor 4 above a floor-1 landing no longer drops you.
- Chamberlain remembers your floor across a /reload or relog while you're inside.
  Walking back in starts you on the ground floor as usual.
- A "Move to floor" button on the Floor Plan corrects the floor by hand if it ever
  guesses wrong (a balcony jump, a stair it didn't see).
- Add floor has a matching Remove floor (top floor only). If the top floor still
  has rooms, it asks first and suggests moving them down a floor to keep them.
- A "Stairs" checkbox on the Floor Plan hides the stair markers for a cleaner map.
- The Floor Plan zooms (mouse wheel, toward the cursor) and pans (drag an empty
  part of the map). Room labels and player dots stay their normal size. A Reset
  zoom button appears while zoomed, and double-clicking the map resets it too.
- On the Floor Plan, a staircase shows on both floors it links, and a Floor marker
  shows on every floor.
- Floors and stairs are shared and exported with the rest of your layout. Older
  clients see every room on a single floor, so no version match is needed. Sharing
  a multi-floor house tells you which group members are too old to see the floors.
- Fixed shared houses vanishing from the sharing list after a /reload. The group
  now re-announces, so the list fills back in.
- Houses you already have are untouched: every existing room stays on floor 1 and
  behaves exactly as before until you add a floor.

## 2.3.0
- Secret rooms. The room editor has a new "Secret" checkbox. A secret room is
  hidden from visitors' floor plans and room lists, so they cannot see it laid
  out ahead of time, but its banner still announces it when they walk in. You
  still see it on your own floor plan. Secret rooms are shared like any other, so
  no version match is needed with your group.
- Fixed the Floor Plan button not appearing on a visitor's HUD right after they
  received a shared layout. It used to need a reload.

## 2.2.1
- Moved the addon to housing category in Addon listing in game

## 2.2.0

- Rooms can read their description out loud. In the room editor you can pick a
  text-to-speech voice for a room, and it speaks the description when the
  talking-head box opens. A Test button plays a sample and turns into Stop while
  it is talking, so you can cut it off.
- Personal default voices. In Settings you can choose a feminine and a masculine
  voice and switch them on. They read rooms shared to you that have no voice of
  their own, picking the feminine or masculine one from the room's head. Your own
  rooms always use the voice you set on them, and stay silent if you set none.
- Voices stay on your own computer. The voice you pick is never sent to other
  players, since there is no way to know which voices their PC has. When you share
  a room, the people who receive it read it with their own default voices. A note
  in Settings and a "?" in the room editor explain this.
- Three more talking heads to choose from: Sire Denathrius, Illidan Stormrage,
  and Wrathion.
- A "Banner fade-out" slider in Settings, 0 to 20 seconds. The room banner fades
  out that many seconds after it appears. Left at 0 it stays up until you leave the
  room, the same as before.
- Fixed the talking head not being positioned correctly when the Yapper dialog opened 
  for first time per login/reload
- Fixed an invisible room banner that still caught mouse clicks when you were not
  in a house, for example in a raid. It now hides fully once it fades out.
- Fixed the talking head sitting a little low the first time it opened after a
  reload. It now frames the same every time.
- The room editor window now comes to the front when you click it, like the other
  windows do.
- Sharing now works in instance groups such as delves and looking-for-raid, where
  it used to silently fail.

Voices are personal and never shared, and the sharing format did not change, so
you do not need to be on the same version as your group.

## 2.1.0

- Fixed "Use my head when I'm home" not working in your own house for some
  players. It used to work out who owned the house from a name, which did not
  always match, so you got a fixed head instead of your character. It now asks
  the game whether the house is yours, so it recognizes you on any character.
- Visitors can now see your own character on a room's talking head even when you
  are playing an alt. Before, a visitor only saw you if the name on the house
  matched the character you were on. Your character is now identified properly,
  so it works across your alts. The visitor still needs to be grouped with you,
  in the house with you, and using your shared layout.
- The "Use my head when I'm home" checkbox now explains itself when you hover it,
  and the Custom ID and Speaker fields have a "(?)" you can hover for a short note
  on what they do and when to leave them blank.
- Fixed the share message saying to join a party when sharing was actually just
  turned off in settings. It now tells you sharing is off.

This update tucks a little extra into shared and exported layouts so your
character can show for visitors. Older versions ignore it, and sharing and
importing still work both ways, so your group does not have to update all at once.

## 2.0.2

- Update to support WoW 12.0.7

## 2.0.1

- Under the hood optimizations to addon structure, no changes to users needs.

## 2.0.0: Role Playing Talking head feature in each room

- Rooms can now have a description. Pick a 3D head and write the text, up to
  500 characters. When you enter a room that has one, the gold banner shows a
  "Read" button. Click it and a quest-style talking-head box appears with the
  head's name, the head talking, and the description scrolling by. Close it with
  the x to return to the banner.
- Edit a room from the My Rooms list or the floor plan with the Edit button. You
  can rename it, recolor it, change its head, or write its description.
- Descriptions and head choices travel with shared and exported layouts.
- Sharing now sends a house as a single compressed bundle split into a few
  messages, instead of one message per room plus separate text. Sharing a few
  rooms takes a fraction of the time it used to, and many rooms will share quite 
  a bit faster than previously
- The sharing had a 30second timeout before on recipient end, this was not logged
  well before so it is now 180 seconds, if it takes more than that it stop, this
  a safety measure in case there is too much data to share and to load into your
  addons memory before its transferred completely
- Settings has a "Room descriptions" toggle that turns the talking-head box off
  and falls back to the plain banner.
- The description talking head can also be set to be YOU yourself by checking 
  a checkmark in edit dialog, but only works if you are in a visitors party whom
  you shared your layout to

The new sharing format is not understood by older versions, so everyone in your
group has to update to 2.0 to share with each other. Anyone on an older version
is told to update and won't try to share. Your saved rooms and exported layout
strings still work as before.

## 1.2.0

- The My Rooms list now groups rooms under a collapsible header for each house.
  Click a house to fold its rooms away or open them back up. Your own houses
  start open. Shared layouts start closed, so a long list of other people's
  houses no longer fills the panel. What you fold and unfold is remembered only
  until your next reload or relog.
- Fixed the house names in the list being centred instead of lined up on the
  left.
- Removed the duplicate "Shared layouts" heading that showed when you had no
  houses of your own.
- Fixed the minimap button icon sitting up and to the left, where it poked
  through the border ring. It now sits centred.

## 1.1.0

- When someone shares a layout you did not request, Chamberlain now asks before
  applying it instead of overwriting your copy. The prompt names the player and
  the house and offers Accept or Decline. This replaces the old replace/keep
  conflict prompt and its setting.
- The accept prompt has an "Always accept from this player" option. Tick it to
  trust that player, and their later shares apply without asking. Trust is saved
  per character and can be removed under Settings, in Trusted and blocked.
- The Settings tab lists the players you trust next to the houses and players
  you have blocked, each with a button to remove it.
- A house owner re-sharing their houses updates your copy without a prompt once
  you have accepted or trusted them.
- Receiving skips houses that have not changed. If Share My Houses includes a
  house you already hold at the same version, it is dropped on arrival with no
  progress bar.
- A declined or unavailable layout request is now reported to the requester
  instead of failing silently.
- Fixed shared layouts not updating when several arrived at once. The prompts
  could overwrite each other, so the wrong house was applied.
- Fixed the floor plan and room manager windows showing through each other when
  open together. Clicking either now brings it fully to the front.

## 1.0.1

- Sharing now works in a raid group, not just a 5-person party. Messages go out
  on the raid channel when you are in a raid, so everyone receives them.
- Fixed the minimap left-click: it now always toggles the position HUD, instead
  of opening the room manager when you were not in your own house.
- Fixed the position HUD not coming back after you hid it.
- On the floor plan, clicking where rooms overlap cycles through each room under
  the cursor, so a room covered by another can still be selected.

## 1.0.0

First stable release. Everything below landed since the 0.12.0 beta, most of it
around making party sharing reliable.

- The position HUD can be hidden. The choice sticks across houses and sessions.
  Toggle it with the minimap button's left-click or `/chamberlain hud`.
- Minimap button now has three controls: left-click shows/hides the position
  HUD, right-click opens the room manager, middle-click opens the floor plan.
- Fixed the minimap button sitting inside the ring on larger minimaps. It now
  positions from the minimap's actual size, so it rides the edge at any size.
- Fixed: layout transfers could arrive dropped or corrupted, so requested rooms
  never showed up. Outgoing messages now go through a paced queue instead of
  firing a whole layout in one burst, which the addon channel could not take.
- Fixed: your houses were not announced to party members if you were already
  grouped before logging in, so they could not request your layouts even though
  you could request theirs. Your catalog now goes out on login as well.
- Catalog broadcasts are debounced. A burst of edits (for example nudging a
  room repeatedly on the floor plan) now sends one update instead of one per
  change. The version handshake no longer rides along with every catalog. It
  is sent only on join and login.
- Requesting a layout you already have now updates it directly instead of
  asking you to resolve a conflict. The conflict prompt is only for layouts
  pushed to you that you did not ask for.
- Both ends show a progress bar with a room count during a layout transfer. The
  sender sees it whether responding to a request or using Share My Houses.
- The Party tab now updates its status as soon as a layout finishes arriving,
  instead of only after switching tabs.
- Fixed: party members in their own house showed as blips on your floor plan.
  Only members in the same house as you are shown now.
- The "Share All" button is now "Share My Houses" and pushes only houses you
  own, instead of also re-broadcasting layouts you received from other people.
- The floor plan can be opened anywhere, not only in your own house. When you
  visit a house you hold a layout for, a Floor Plan button appears on the HUD.
- Room banners now fire in any house you have a layout for, not just your own.
  A friend's shared layout labels their rooms when you visit.
- Export/import strings are now a compact compressed blob instead of plain
  text. They carry the house identifier so an import lands under the right house
  and its banners fire when you visit, they handle any characters in room names
  (commas, Cyrillic, and so on), and they are shorter for large layouts. Import
  no longer requires standing in your own house. Strings from earlier versions
  no longer import.

## 0.12.0

- Fixed: rooms could vanish between sessions. The game's house GUID turned out
  to be a per-session handle, so the same house got a fresh identity on every
  login. Houses are now keyed by neighborhood and plot, which is stable, and
  existing data migrates automatically the next time you stand in your house.
  This also fixes sharing between two accounts. Sharing protocol bumped:
  0.12.0 clients will not exchange layouts with older versions.
- Rooms can be renamed from the floor plan edit panel. Time stats follow the
  new name.
- Per-room colors. Pick one while naming the room (with your five most recent
  colors as one-click swatches) or later via the floor plan's Color button.
  The room tile and the entry banner both use it. Colors travel with shared
  layouts.
- Optional sound when entering a room. On by default, toggle in Settings.
- Minimap button. Left-click opens the room manager, right-click the floor
  plan, drag to reposition.
- Party members inside your house show as class-colored dots on the floor plan.
- Layouts can be exported to a text string and imported from one, for sharing
  outside the party. Buttons are at the bottom of the My Rooms tab.
- Hovering a room on the floor plan now also shows how long you have spent in it.

## 0.11.0

- New look modeled on the 12.x housing UI: dark gradient panels with a gold
  header bar, flat dark buttons with gold text, and slim scrollbars. Replaces
  the default tooltip-style backdrop and red buttons everywhere.
- Rooms can be edited on the floor plan. Click a room to select it, then move,
  grow or shrink it half a yard at a time with the direction buttons below the
  map. Own house only.
- A "?" in the HUD corner shows the room creation workflow and other usage tips.
- Addon list icon (a top hat, naturally).

## 0.10.0

- Party members now check each other's addon version. If the sharing protocol
  doesn't match, you get one warning and sharing with that player is disabled.
- Incoming layouts for a house you own are ignored. Your own copy is always
  the right one. This came up with two WoW accounts on one battlenet account,
  which own the same houses.
- The Party tab marks houses you own as "Your house" instead of offering a
  Request button for them.
- The catalog also broadcasts when you enter a house or create/delete a room,
  not just on roster changes, so the party's view of your layouts stays current.
- `/chamberlain` is now the primary command. `/rooms` still works as an alias.
- New `/chamberlain debug` command logs share traffic for troubleshooting.
- Sharing a layout through the consent dialog now prints a confirmation.

## 0.9.0

First beta.

- Name a room by marking its two corners. A banner shows the room name when
  you walk in and fades when you leave.
- Overlapping rooms work. The smallest one you stand in wins.
- Floor plan window with a live player dot, markers for pending corners, and
  hover tooltips
- Party layout sharing with consent dialog, conflict resolution and block lists
- Room manager with My Rooms / Party / Settings tabs
- Shared layouts can be browsed and removed separately from your own rooms
- Editing tools only appear in your own house (ownership comes from the
  server, not the character name)

## 0.1.0

- Initial scaffold
