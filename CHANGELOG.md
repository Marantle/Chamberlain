# Changelog

## 3.16.0
- Either click on the speaker in the Chamberlain bar now opens the list of
  house sounds, with Mute all at the top. The kinds used to hide behind a right
  click that nothing told you about, so most people only ever found the mute.

## 3.15.0
- House and floor sound reaches your group even when their map is older than
  yours. Pick an ambience or a track for the whole house, or for one floor, and
  everyone who has your map hears it. The arrival sound has worked this way
  since 3.14.0 and the other two join it now. A room's own sound still needs
  their map to match yours, because that message names the room by its place in
  your map and the places move when you add or delete a room.
- The Archive no longer throws an error when you open it away from your own
  house. Opening it in a city or in somebody else's house works now.

## 3.14.0
- Echoes. A room's sound on entry can carry through the house, so when a guest
  walks into your entrance hall the bell on the door rings for you down in the
  cellar too. Click Entry sound in the room dialog and drag the Echo slider to
  a number of yards, or all the way right for the whole house.
  Floors don't count, so a room right above the bell is as close as one beside
  it. Everyone in the house with your map hears it, as long as they're in the
  same group or guild as the one who walked in. What plays is the sound and
  the reach in your own copy of the map. The message between players only says
  which room was walked into.
- An arrival sound for the whole house. The Arrival button on the house map,
  next to Ambience and Music, picks the sound of your front door. It plays for
  everyone inside who has your map, whenever somebody running Chamberlain
  walks into the house. The visitor doesn't need the map, so a first-time
  guest rings too, as long as they're in a group or guild with the people
  inside and haven't turned Sharing off. It rings once per visit and a reload
  doesn't set it off. A change of it reaches group members even when their
  copy of your map is behind. With the game's sound or Effects volume off, a
  chat line says who is at the door and which sound would have rung.
- Cooldowns. How often somebody rings for you is yours to set, with two
  sliders in the settings. "Echo wait, same person" starts at 30 seconds and
  goes from 5 seconds up to three minutes. "Echo wait, same room" is off to
  begin with and goes up to a minute. Once a room or the front door has rung,
  it stays quiet for you that long whoever walks in next, for the evening
  when ten guests arrive in a row.
- Mutes by kind. Right click the speaker on the bar, or use the button under
  House sounds in the settings. The ticks are Ambience, Music, Room sounds,
  Echoes, Arrival sound from group members and Arrival sound from guildmates.
  Untick the last one and only people in your group ring your front door. A
  left click on the speaker mutes all of it. The speaker goes grey while some
  kind is off and wears the red mark while everything is.
- An entry sound set to play once or a few times plays to the end, the rest
  of its count included, even when you've already left the room. A thin
  trigger across a doorway rings in full. A looping sound ends as you walk
  out, and muting stops either.
- A shop door bell, the same bell with a squeaky hinge and a ding dong
  doorbell ship with Chamberlain, since the game has none. They're under "At
  the door" in the sound list with knocks and the Waycrest steward's dinner
  bell.
- 51 more game sounds in the list. They sit in five new groups called "At
  the door", Chimes, Bells, Alarms and "Horns and warnings". Alarms has three
  sizes of alarm, a goblin klaxon, Gnomeregan's alarm bot shouting about
  intruders, Undermine car alarms and alarm clocks. Horns and warnings has
  the battleground horns, war horns, a lighthouse foghorn and an alarm drum.
  A vault with a Whole house echo makes a decent burglar alarm.
- A Sharing button on the Chamberlain bar. It opens the Rooms window on its
  Group tab, and a gold dot on it says somebody in your group has a map of the
  house you're standing in, one you don't have yet or a newer one than yours.
  Settings and Sound are a gear and a speaker in the bar's title strip.
- A note icon blinks in the title strip when an update brought notes you
  haven't read, for those who turned the What's New window off. Click it to
  read them and it goes away until the next update.
- Share My Houses and Export ask which house when you have more than one.
  Export works from anywhere and lists your own houses, then the maps you
  hold of other people's.
- Importing shows what the string holds before anything is saved. You see the
  owner named in it, the rooms and floors, when it was last changed and the
  first few room names, plus which kinds of sound it carries. Every import
  asks first. Maps offered by your group show the same summary.
- An import aimed at a house of your own says so in red before it replaces
  your rooms. A string names its house and owner itself, so go by that line
  and decline unless it's your own backup. Group sharing can't touch your own
  houses at all.
- The Entry sound switch in Settings is gone, and the map ping on every room
  with it. It was from before a room could have a sound of its own. Give a
  room an Entry sound in the room dialog if you want to hear when you walk in.
- Rooms, banners and sounds start about a second sooner after the door.
- Fixed: accepting a map from your group out in the world put the Chamberlain
  bar on screen, and the minimap button couldn't hide it.
- Guests on 3.12.0 see and hear everything as before. They don't get echoes,
  the arrival sound or the three shipped door sounds until they update. If a
  friend updates after they already took your map, change anything on it once
  so they pull a fresh copy with the echoes in it.

## 3.12.0
- Now playing. The Chamberlain bar's title strip names the music and ambience
  the house has on, next to three little bars that bounce while something
  plays. The track shows in gold by the last part of its file name, and a name
  too long for the strip slides back and forth. Hover it for the full path.
  Visitors get it as well, so a guest can see what that tune in the hall is
  called. It goes away when nothing of Chamberlain's is playing or the Sound
  button has it muted.
- The sound a room plays as you walk in has a row of its own in the room
  dialog, Entry sound, under Music. The two used to share the Music button, so
  a room had either a track or a sound. Now it can have both, the nursery's
  lullaby and the ghost's laugh. The Fun sound effects tab is gone from the
  music window, which opens for one or the other. Rooms that already had a
  sound keep it, moved over to the new row the first time you log in, and so
  do your stored maps in the archive.
- Group members on an older version still hear a room's sound as long as the
  room has no music of its own. In a room with both they get the music, until
  they update.
- When the owner changes a sound while you're grouped and standing in their
  house, a chat line says who changed it and for which room or floor, then
  names the new track or ambience. An owner clicking through a few sounds to
  compare gets you one line for the pick they end on. A secret room shows up
  as "A room".
- Switching the game's music off and on again with Ctrl+M brought back the
  game's own music in a house that has a track or Silence set. The house's
  pick comes back now, and the same goes for Ctrl+S.
- The Voice row in the room dialog has its help on the label's (?) now, like
  the rows around it, in place of the lone gold question mark at the end.
- The music window lists what the house already uses before you type
  anything, under "Used in this house". The track from the hall is one click
  away when you want it in the next room too. Opened for an entry sound it
  does the same with the sounds your rooms play.

## 3.11.0
- 78 more ambience loops, 123 in all. Most of them are haunted. Naxxramas is in
  wing by wing, so are Icecrown Citadel and Frostmourne, and the spirit world
  you hear when you're dead. The rest is daylight forests and beaches, a dozen
  cities and the Darkmoon Faire.
- The Ambience menu is sorted into fifteen short categories now, none longer
  than twelve. Rooms that already have a sound keep it.
- Clicking a sound in the Ambience menu plays it and the menu stays open, so you
  can click through a few and compare. The room's own ambience goes quiet while
  you listen. Click anywhere else and the menu closes and the sound stops.
- Someone on an older version hears nothing in a room that uses one of the new
  loops, with no error, until they update.

## 3.10.0
- Music. A room, a floor or the whole house can have a track from the game's
  own music, about 6900 of them. It plays in place of the music the game would
  play and the game's comes back when you walk out. The room dialog has a Music
  button and the house map a Music menu beside Ambience. Both open a search
  window. Type a zone or a city, click a track to hear it and press Use this
  track. Click anywhere outside the window to close it. Same order as
  ambience, a room's track over the floor's over the house's, and a bannerless
  room with a track takes the music while you stand in it. Silence is a pick
  too, always on top of the list. It turns the music off wherever you set it,
  the game's own and any the house has set, so the crypt can be quiet while the
  hall above plays on. The Sound button mutes the music as well, and Room
  ambience in Settings is now called House sounds since it covers all of it.
- Room sounds. A room can also play a short game sound as you walk in. The
  room's picker has a Fun sound effects tab with a list of them, from a ghost's
  laugh to a murloc. Any other game sound works too if you type its file number
  into that tab's search box. Plays sets whether the pick loops or runs one to
  five times each time you walk in. A pick with a count and any sound that
  isn't music play over the music that is already on. Only the number of the
  track or sound and how often it plays are saved and shared, so none of this
  adds much to a shared map, and older versions ignore it.
- Sound changes reach your group right away. Pick another ambience or track
  while grouped and everyone who has your latest map hears it change, so you
  can turn the great hall to a thunderstorm mid scene. A chat line tells you it
  went out. That only happens from the owner of the house, and only when sound
  is all that changed. Rename the room in the same save and the group gets the
  usual newer map to pull. A friend whose copy of the map is older, or who runs
  an older version, is left alone and sees a newer map on offer like before. If
  a house has sounds and your game sound or the Ambience, Music or Effects
  volume is off or at zero, Chamberlain says so once per session in chat so a
  quiet house doesn't look like a bug.

## 3.9.0
- Ambience for the whole house and per floor. In your own house the house map
  has an Ambience button in its top left corner. Whole house sets a sound that
  plays everywhere indoors, and on a house with several floors the menu lists
  each floor so it can have its own. A room's own ambience wins over the
  floor's and the floor's wins over the house's. Sound spots still play on top
  of whichever it is.
- Both are shared and exported with the map and stored with it in the Archive.
  Older versions ignore them.
- The short pause when a looping ambience started over is covered up. The first
  time through the sound gets timed, and from then on the next round starts a
  moment early under the fading end of the last one.

## 3.8.0
- Room ambience. The room dialog has an Ambience menu with 45 of the game's own
  background loops, from a crowded tavern to a slow river. It fades in when you
  walk into the room and out again when you leave. Test plays the pick while
  you choose. Its volume follows the Ambience slider in the game's sound
  options, and Room ambience in Settings turns it off for you alone. In a house
  whose map has sounds the launcher bar gets a Sound button that mutes and
  unmutes with one click.
- Banner checkbox in the room dialog. Untick it and the room shows no banner
  and stops counting as the room you're in. That makes a sound spot. Put a small
  room over the fireplace with the fire ambience and tick Secret so visitors
  don't see it on the map. The great hall around it keeps its banner and its
  time count while the fire crackles on top. Once a house has any, the house
  map gets a Sound spots checkbox in its corner that takes them off the map and
  the minimap.
- Both travel with sharing and export strings. Someone on an older version gets
  the map as before but hears nothing, and the bannerless rooms show a banner
  for them, so give those a name that reads fine.

## 3.7.0
- The Archive. Patch 12.1 lets you save your house to a blueprint, reset it and
  load another, and the room map used to just sit there firing in a house it no
  longer matched. Now you can store the map under a name (Archive in the Rooms
  window or /rooms archive), and the archive keeps as many as you like per
  house. The launcher bar grows an Archive button only while the house has no
  rooms and a stored map is waiting for it. Restore brings one back as the live
  map, and if the map in the house has edits that aren't stored yet it asks
  whether to store them first. Store and clear empties the house's rooms after
  storing, for the reset flow, and Clear rooms does it on its own. A map from
  one of your other houses has a Here button that puts it into the house you're
  standing in. The archive is local. Sharing and export read the live map and
  nothing else, same as before.
- Blueprints. When storing you can pick one of your house blueprints and the map
  takes its name. Chamberlain also follows what the game does with blueprints.
  Saving a full layout or interior blueprint offers to store the map with it.
  Loading one brings that map back, asking about the current map first if it
  has unstored edits. Resetting the house asks whether the map still in there
  should be stored or cleared. On a client without blueprints the archive works
  the same, just without the picker.
- The house map points at the archive when the house is empty and a stored map
  exists for it.

## 3.6.0
- Rooms on the minimap. Indoors the game swaps the minimap for a still picture of
  a house. Turn on Rooms on the minimap in Settings and that picture makes way for
  the rooms of the floor you are on, you in the middle and the rooms sliding past
  as you walk, group members as dots. Same orientation as the house map. The
  minimap zoom buttons and the mouse wheel set how much of the house fits in the
  ring. If an addon squares your minimap, flip Square minimap too so the rooms
  fill the corners. It does not turn with you when rotate minimap is on.

## 3.5.1
- Ready for patch 12.1. Blizzard renames the check for standing in your own
  house there, and the addon now works with both the old and the new name, so
  nothing breaks on patch day. Flagged for the 12.1 client as well.

## 3.5.0
- The Floor pin now asks which floor it works from. It starts on the floor you are
  standing on, so the pin fires only from that floor and the map shows it only
  there. Step the selector down past floor 1 to get the old kind that works from
  every floor. Saving is blocked while the pin would send you to the floor it
  already works from, since that would never do anything. This also makes pins a
  way to hand-build custom stairs: two pointing at each other work exactly like a
  stair pair, and a single one covers a one-way trip, like a ladder up or a
  balcony jump down.
- The house map draws floor markers where they actually live. A lone pin or a
  one-floor hop shows only on its own floor now, while a stair pair still shows on
  both floors it connects, so the two ends can be lined up from either side.
- Editing stairs got simpler. The edit window now shows the same two rows as the
  pin: which floor the anchor works from and which floor it sends you to, instead
  of the old behaviour menu. Any combination can be set directly, so turning a
  landing between floors 1 and 2 into one between 2 and 3 no longer means deleting
  it and starting over. The old "up one floor" and "down one floor" anchors still
  work and read as from/to in the editor.

## 3.4.0
- Added a credits button to Settings. Worth a minute when you have one.
- Sharing now has a sibling switch, Receiving. Sharing is your houses going out,
  Receiving is other people's houses coming in. Turn Receiving off and their
  catalogs and layouts are dropped before any popup can fire, and whatever the
  Party tab had already collected is cleared out. With Sharing off, requests for
  your houses are now ignored outright instead of popping a consent dialog at you.

## 3.3.0
- The build toolbox now docks to the right edge of the house map, so Build opens the
  pair and they move as one window. Drag the toolbox away to set it floating on its
  own for walking the house with just the small palette up, and the « button in its
  header glues it back. Opening the map alone never brings the toolbox along, and
  closing the toolbox leaves the map open.
- The house map now points at the repair itself. If you own the house you are standing
  in, its map is empty, and another house of yours does have rooms, the map offers a
  Fix house button under the empty message. It opens the same window as /rooms fixer.
  A house you have simply not made rooms in yet still shows the plain empty map.

## 3.2.0
- /rooms fixer now also re-stamps your rooms onto the house's current map. A moved
  house can come back on a new internal map, and without this the rooms showed on the
  house map but never announced themselves when you walked into one.
- /rooms fixer no longer leaves you on the wrong floor after a reload, and it now
  picks up the house's current name as well as its owner.

## 3.1.0
- Fixed: moving your house to another neighborhood gives it a new internal id and
  owner name, so the rooms stayed saved under the old one and the house came up
  empty. Stand in your house and run /rooms fixer, then pick the saved house that is
  really this one. It only works in a house you own.
- Share My Houses button stays disabled while a share is still sending, and a Request
  button in the group tab waits a few seconds after you click it, so neither can be
  spammed.
- Finnish translation added. WoW does not offer Finnish, so to switch the addon to
  it, open Locale\SetLanguage.lua in the Chamberlain folder, set the language on the
  marked line, and reload. Leaving it alone keeps your client's language. This was added
  just for my friend who is better at Finnish than English so pay no mind to this.


## 3.0.0
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
- Add stairs and Floor pin moved off the HUD and into the toolbox.
- Settings moved out of the room manager into their own window, opened by the
  Settings button or /chamberlain settings. The room manager is now only My Rooms
  and Party.
- The minimap button: left-click shows or hides the launcher as before, middle-click
  opens the house map, right-click opens the room manager.
- Rooms can be round. In the toolbox, click Round room instead of Square room and it
  drops where you stand like any room. A circle's banner fires inside the actual circle,
  not the corners of its box. Size it with Grow and Shrink, or stand at the rim and
  click Set radius to me. Round rooms draw as a disc on the house map, and they
  share and export like any other room. Older clients see them as a square.
- A "Room banners" switch in Settings turns the gold name banner off entirely, for
  players who only want the map. It's personal and stays on your computer, and
  flipping it off clears any banner already showing.
- A What's New notice pops the first time you step indoors after updating, listing
  the changes since the version you last ran. Close it, or click Never show update
  notes to silence them for good. You can reopen the latest notes anytime with
  /chamberlain whatsnew. New installs don't see it.

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
