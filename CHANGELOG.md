# Changelog

## 3.47.0
- Smart drop and Auto map know every themed room the game sells, fifteen more
  from Stormwind, Bel'ameth, Orgrimmar and Silvermoon. Each goes on the map at
  its own shape, with its door where the game puts it.
- Like the barn, they move and turn but don't resize. A shared map keeps
  their turn, since they aren't quite square.
- Eight of them show their steps and railings on the map, the way the barn
  has them. The edge of higher ground is a solid white railing and each step
  a thin line, its tread a little brighter the higher it sits. The other
  seven have flat floors, so they have none.
- Rooms on the house map and the minimap sit a little apart now, each drawn
  half a yard in from its walls. A strip of floor bridges the gap where both
  rooms have a door on the same spot, the way the game's own layout editor
  shows a house. A blank wall, like a stairwell's closed sides, never gets
  one. Doorways between rooms on the Map and bar page of Settings turns it
  off, for rooms that touch wall to wall the old way.
- Fixed Smart drop and Auto map turning down a themed room next to another
  room when only the themed room's empty corners crossed it, like an
  Orgrimmar Theater beside the entrance. They "couldn't find a door near you".
- The Silvermoon Lofty Study has a loft like the barn. Smart drop puts it on
  the floor above, over the study's far half and its spiral stair. A spiral
  goes round on the spot, so the map counts how far you turn on its steps.
  Most of the way up puts you on the loft's floor and most of the way down
  puts you back. Half way up and back again changes nothing.
- Off a loft some other way than its stairs, a jump say, the floor check
  puts you back on the floor below once you stand outside every room up
  there.

## 3.45.0
- The Welcome home window is now a first steps guide for a new house. It lists
  five steps and ticks each one off as you do it. Most steps have a button of
  their own, like Drop this room or Done walking. The guide keeps its place per
  house, so Auto map brings it back where you left off.
- After the last step the window comes back once to say that's the basics and
  points you to the House panel.
- Houses you mapped before this version don't get the guide by themselves.
  To run it in the house you stand in, click Show again under First steps on
  the Map and bar page of Settings, or type /rooms guide. With rooms on the
  map it starts at step 3.
- The first room Smart drop puts on a floor now follows you while you walk in
  it, like rooms that join a door already did. Drop it from a corner, walk to
  the far corners and it moves and turns on the grid to fit the walls. This
  needs Snap on. Round rooms stay where they drop.
- Renaming the room you stand in no longer counts as walking into it for the
  guide.
- The Banner tick in the room editor is now Kind, with three choices. Room is
  what every room was. Nameless room is new. It sits on the map with no name
  on it and shows no banner, so a hall can join your rooms on the map with
  nothing to announce. It can still have its own sounds, but it's never a
  tour stop.
  Sound spot is the old unticked Banner, a sound inside a bigger room, and
  every room you unticked before is one now. Older versions of Chamberlain
  show a nameless room as a normal room.
- Smart drop no longer refuses a room when no open door fits. It puts the
  room down where you stand and says so, and with Snap on the room follows
  you to its corners like a first room. Auto map still waits for a door.
- Match game room, the Smart drop icon next to Edit room, fixes a room that's
  already on your map. Select the room, stand in the real one and click it.
  The room takes the game's shape and size and goes where Smart drop would
  put it, but keeps its name, sounds and story. If another room remembered
  that game room for the floor check, it lets go and chat tells you which.
- Turning on Auto map turns Snap on too when it's off, with a line in chat.
- Slide to me and Stretch to me now put the wall right where you stand, with
  no padding, which makes small spots easier to line up.
- Chinese, Korean and Russian room names no longer show as boxes on the
  banner, the house plaque and the story card when your game runs in another
  language. They use the game's own fonts for those alphabets.

## 3.44.0
- A room with no music of its own now lets the room under it play its music
  where the two overlap. Ambience works the same way. Before, the floor's or
  the house's sound took over, so a little room for a story stopped the track
  and started it again on the way out. Pick Silence for a room that should be
  quiet.
- Walking out of a house in the middle of a tour no longer throws an error.
  The tour card stops pointing while you're outside and picks up again when
  you come back in.
- Add default entrance now shows on every floor of an empty map, not only on
  floor 1. A house with a basement starts higher up, and the entrance goes on
  the floor the map shows.
- In a second house of yours with no rooms yet, the map no longer opens with
  "Did you move this house?" alone. It says how to start a new house first,
  and Fix house comes second for a house you did move.

## 3.43.0
- The room editor has a new Lock tab where you give a room a code of 4 to 8
  digits. Visitors see "Locked by Arcane Ward" on the banner, and
  its button opens the lock instead of the story.
- The Arcane Ward is a ring of magic circles with ten glyph stones under it,
  one glyph per digit. Glyphs fly into the ring as you press them, and a click
  on one sends it back. The right code spins the circles apart and the
  area's real name, banner style and story show. A wrong code makes the ward
  bite back. Each glyph clicks into place with a rune sound, and the open and
  the wrong code have sounds of their own from the game.
- The glyphs are made of straight bars, so the clue can be laid out in the
  house with beams or planks. The Lock tab shows your code as its glyphs while
  you type it.
- In a shared map the hidden name, banner style and story are scrambled, so
  searching the shared map won't find them. The code never leaves the owner.
  A visitor who solved an area keeps it open through new maps, unless the
  owner changes the code.
- The Try the lock button on the Lock tab opens the lock as your visitors get it, with
  the code you typed, so you can check it works. Nothing is saved.
- Showcase keeps the lock on screen when you hide the UI, with its own switch
  in Settings. It's on to start with.
- Players on an older Chamberlain see a locked area as a room called Locked.
- The Square room button now drops one grid square right where you stand,
  without snapping. Dragging it snaps as before, and Quick resize still has
  the game's sizes.
- A new Tour guide button at the top of the Tour panel picks who speaks the welcome and
  the goodbye, with the same Head, Decor and Text only switch as a room's
  story. It starts on your own character, as before. Visitors on an older
  Chamberlain keep seeing your character.
- The goodbye now opens under the banner like the welcome, as well as on the
  tour card.
- Secret rooms can be tour stops. They stay off your visitors' map, so the
  card's arrow is how they find them. Visitors on an older Chamberlain skip
  those stops.

## 3.42.0
- The Yapper tab in the room editor is now called Story. A Show switch on top
  picks what the room's card shows beside its words. That's a talking head, a
  piece of decor or the text only.
- Decor shows a piece from the housing catalog, standing still.
  Find decor opens a list over the house map where you can search the catalog
  by name and pick a category. It can also narrow the list to what you've
  collected, what you've placed in your houses or what this house's story
  cards already show (History).
- With Decor picked, the speaker name is the decor's name until you type your
  own. With Text only there's no name unless you type one.
- The card has a new look and opens under the banner as one piece with it.
  Read on the banner drops a dark strip with gold lines down from it, and a
  second click closes it. The banner names the room and the strip names the
  speaker, with the head or the decor on the left. Text only centres the
  words. The banner no longer goes away while you read.
- The lock at the top of the card detaches it from the banner, right where it
  hangs, and then you can drag it anywhere. A second click hangs it under
  the banner again. Only you see where it hangs, and it's kept between sessions.
- The Tour panel has the same switch and Find decor, so a stop can show a
  decor or its words alone too.
- Players on an older Chamberlain still see the room's head with the words.

## 3.41.1
- Rooms on the minimap work with minimap addons that move the minimap and
  draw their own copy of the house picture. Before, that copy stayed over the
  minimap and the rooms didn't show.
- The extra close zoom steps on the minimap work with minimap addons that
  change how the mouse wheel zooms.

## 3.41.0
- Click Tour on the bar or in the House panel to open a Tour panel on the
  house map. The bar's Tour button shows once your map has two rooms. Add
  rooms as stops, put them in order and write a welcome and a goodbye for
  the house.
- With the Tour panel open, click a room on the house map to add it as the
  last stop, or click a stop to pick it. The floor tabs still work, so you can
  add rooms from every floor.
- A click on a stop shows its yapper in the panel, the head, a custom head
  ID, the speaker and the words. An empty speaker shows the head's name in
  grey, the name the yapper uses. These are the room's own, so a change there
  shows in the room editor too.
- Try it saves the tour and starts it for you.
- A visitor with your map gets Take the tour on the plaque, a Tour button on the
  bar and /rooms tour. The welcome plays first. The stops go in your order and
  only the next one plays its yapper. A later stop walked into early shows its
  banner as usual and waits for its turn.
- A card counts the rooms seen and has an arrow that turns with you toward the
  next stop. It says how many yards away it is, and upstairs or downstairs when
  it's on another floor. At the end it shows the goodbye.
- Back and forward arrows on the tour card. Back makes the last stop you saw
  the next one again, so walking in plays it again. Forward skips the next
  stop.
- On the house map the stops have their number before the name, the next one
  turns gold and pulses, and the seen ones fade. The next one pulses gold on
  the minimap too.
- The eye on the bar has a name, Showcase, and a page of its own in Settings.
  The page turns Showcase on and off, and has a switch for each part that
  stays on screen when you hide the UI. The parts it kept before start on, so
  nothing changes for them until you turn one off.
- The tour card stays on screen with the rest.
- Showcase can keep the Chamberlain bar, the house map, the Auto map guide,
  the House panel and the sharing windows up too, so you can map and share
  your house with the UI hidden. The map, the House panel and the Rooms
  window still close with Hide UI like they do with Escape, so open them
  again from the bar. The bar, the House panel and the sharing windows are
  off to start with, the others on. Tooltips, menus and the color picker
  belong to the game's UI and stay hidden with it.
- Showcase keeps the game's own minimap with your rooms on it, its ring, its
  zoom buttons and the mouse wheel zoom included, and Chamberlain's extra
  zoom steps past the closest. It used to keep your rooms alone with
  Chamberlain's own dots. One Minimap switch on the Showcase page covers it.
- Walking into your own house when its map has no rooms brings up a welcome
  from the Lord Chamberlain. Stand in the middle of your entrance and click
  Start auto map there. The window stays up while Auto map runs, with a
  button to stop it. After an L or T room it says to walk around it if it's
  turned wrong, and after a stairwell it says how to carry on mapping on the
  next floor. When a room has no door near it to join, it says a room
  mapped before may be turned wrong and how to rotate it on the map. A room
  whose size Chamberlain doesn't know yet gets named, with a word to place it
  by hand from the build tools. Closing the window stops Auto map too. It
  shows once a visit, and not while the map is locked.
- The same guide comes back whenever you start Auto map on the house map, or
  with /rooms automap. With your entrance on the map already, it says to
  stand in any room instead.
- A moved entrance goes on the map where it is. Smart drop and Auto map used
  to put it where the game first builds it, wherever you'd moved it. Now
  standing anywhere else in it, it goes on the grid where you stand. Standing
  in its middle gets its turn right away, and walking from one door to the
  other fixes a wrong guess. It goes on the floor you're on, so an entrance
  moved upstairs lands upstairs.
- A map with one small room, like the entrance alone, no longer zooms in until
  the room fills the window. The map shows at least 72 yards across.
- A stairwell Smart drop or Auto map puts on an upper floor gets a copy on
  the floor below and on the floor above, since it can't tell which way its
  steps go. Delete the one you don't need. It used to guess one of them,
  mostly up, which was wrong when you mapped your way down. The copy above
  only goes on a floor your map already has, so add the floor with + first
  if it's new. A floor that already has a room in that spot is left alone,
  and on the ground floor only the copy above goes in, as before.
- The empty map's Add the entrance button is called Add default entrance now,
  since it puts the entrance where the game first builds it.
- Build and Map on the bar are one button now, Map. It opens the house map
  with the build tools out. Build in the map's corner still hides them.
- The head grid in the room editor and the Tour panel shows the custom heads
  your house uses before the regular ones, the room's own first. Click one
  to use it, or click a regular head to go back. Two rows show at a time,
  and the mouse wheel scrolls the rest.
- A custom head in the grid is named after the speaker of the first room
  that uses it. Its tooltip shows that name, and picking it fills in the
  Speaker box, which you can change. Each room keeps its own speaker.
- Use default voices in Settings, under Voices, now reads any room with no
  voice of its own, in your own house too. Before, it only read rooms in
  other people's houses. A voice set for a room in the room editor still
  wins. It's off to start with, and your voices never leave your computer.
  The room editor's voice menu calls the no-voice choice Default now, since
  it isn't always silent.
- On a tour, the welcome, the goodbye and every stop are read aloud that
  way. The goodbye plays once the last stop has finished talking.
- Long text in a yapper can be dragged up and down with the mouse. Let go
  and it scrolls on from there. The rest of the box still moves the yapper.
- A duplicated room doesn't copy the original's place on the tour.
- Stored maps in the archive keep the welcome and the goodbye.
- A friend on an older version gets the map without the tour.

## 3.40.0
- A new group at the end of the entry sound list, Tapering echoes. It has 40
  of the game sounds from the list a second time. When one of them is a room's
  echo, it gets quieter the farther away you are. In the room and at its wall
  it plays at full volume, and at a tenth from 100 yards away.
- Each sound is in the list twice, because the game plays the tapering copy
  its own way. A few of them start a moment late or change pitch a little.
- A friend on an older version hears a tapering echo at full volume, the same
  as before.
- Repeating sounds is a new group at the end of the Ambience menu. Each pick is
  a set of game sounds, like ten ghost laughs or a run of chimes. The game
  plays one sound from the set, waits a few seconds and plays another, for as
  long as you are in the room. The menu shows how many sounds each set has.
  These follow your Ambience volume.
- A friend on an older version hears no ambience in a room that has a
  repeating sound.

## 3.39.0
- 42 new banner styles in a Medallions group. They use the ring from the
  toast the game shows when you reach a new renown level, at its full size so
  it stays round. Under the ring is a dark band for the room name.
- The ring can be empty or hold an icon. There are renown faction emblems for
  Dragonflight, The War Within and Midnight, a crest for every class and the
  four covenant sigils. Each set is one row in the picker with a chip for
  every icon.
- The tooltip on a chip names the faction, class or covenant in your game's
  language.
- A friend on an older version sees their own style instead.
- Escape no longer closes the dialog that offers you a shared map. It used
  to throw that map away without a word, and every later offer or import of
  the same house waited behind the closed dialog until a reload. Now only
  Accept and Decline close it. The same goes for the dialog that asks
  whether to share your map, where Escape left the asker without an answer.
- Sharing in a raid is much quieter. Every change to the raid's roster used
  to wipe the list of maps in the group and make every Chamberlain in the
  raid announce all its houses again, so the list kept emptying and refilling
  and the Rooms window kept redrawing. Now Chamberlain waits until the roster
  settles and forgets only the people who left. Only someone who just joined
  announces themselves. A loading screen, like walking through a
  house door, no longer starts a round of announcements either. Only a
  login or a reload does.
- When somebody in your group runs a newer Chamberlain than you, chat says so
  once after you log in or reload, with both versions.
- A request for a map and a no to one go out ahead of everything else. In a
  raid a request could wait a minute or more behind those announcements
  before it even left, which looked like nothing happened.

## 3.38.0
- An eye on the Chamberlain bar keeps the room banner, the house plaque, the
  talking head and the room minimap on screen when you hide the UI in a
  house. Everything else goes, the game's own frames and other addons too.
  Hide the UI with your usual key. The eye's tooltip names it.
- The game's minimap goes with the rest. Your rooms stay, with you and your
  group drawn on them, as long as Rooms on the minimap is on in Settings.
  The mouse wheel over them zooms through the game's zoom levels and on into
  Chamberlain's closer steps.
- It's off to start with and works only inside a house.

## 3.37.1
- Walking into your own house could leave you with the visitor bar, no Build
  button and a read only map, until a reload. Chamberlain asks the game
  again each time it names the house, and the bar and the map catch up as
  soon as the game knows it's yours.
- A map of your house that you picked in the Rooms window turns into the
  live map when you walk in, with your build tools on it.

## 3.37.0
- Smart drop and Auto map know the Stormwind Display Room. It goes on the
  map at its own shape, a small room's square with the alcove across the far
  wall.
- The map draws the sunken landing inside the door darker than the floor,
  with the one step up out of it and the railed ledges on both sides.
- Like the barn, the Display Room moves and turns but doesn't resize.
- A friend on an older version sees it as a plain square.
- A new Game room names switch on the Rooms page in Settings names new rooms
  the way the game does, in your game's language. A square becomes Square
  Room and a cross becomes Cross-Shaped Room. That covers Smart drop, Auto
  map and the shape buttons. Chamberlain drops the size the game adds to a
  square or an octagon, since you can resize the room. It's off to start
  with, and rooms already on your map keep their names.
- The Plus room is now the Cross room.

## 3.36.0
- Five new banner styles from the game's own art. Victory is the band from
  a boss kill, with a chip for the skull and one for the star the game shows
  when you beat a Mythic+ timer. Housing celebration is the glow with the
  house mark between two vine rails. PvP line is the glow under the PvP
  scoreboard's title, in Alliance blue and Horde red. A friend on an older
  version sees their own style instead.
- /chamberlain delete is gone. It deleted the first room with the name you
  typed, so it could hit the wrong one when two rooms share a name. Delete a
  room on the Build toolbox, in the room editor or in the Rooms window, where
  Undo delete can bring it back.
- A new room gets the next free number when another room of the house
  already has its name, like Stairwell 2. That counts for the barn's loft
  and a stairwell's other end too. Rooms you already have keep their names,
  and you can still rename a room to anything.
- Room counts leave out stairs and sound spots. That covers the Rooms
  window, the plaque, the archive and the lines about a shared map. A house
  with a barn used to count its loft stairs as two more rooms.
- Delete in the Rooms window works like the trash can now, so Undo delete
  can bring the room back. The Rooms window shows the room you deleted last
  over the list of rooms, with its own Undo delete button.
- The floor check line at the foot of the Build toolbox says it's frozen
  while you stand in a smaller room it leaves alone, like the barn's loft.
  Before, it showed the floor of the barn below.
- The house map no longer says Editing a room after the room editor closed
  on its own because the room was gone.

## 3.35.0
- The banner style in Settings is now Personal banner, and it only ever sets
  your own look. Before, it set the house's style when the game said you
  stood in a house of yours and your own anywhere else, so an owner could
  pick for themselves without knowing it. A house's style is picked in the
  House panel.
- A house of yours starts on the Gilded banner instead of Visitor's own.
  Your houses that had no style get Gilded once with this update. Houses
  with a style keep it, and Visitor's own can still be picked.
- The House panel shows a sample of the house's banner style under its
  button.
- Keep my style in other houses is now called Personal banner override.
- When a shared map comes in while you stand in one of its rooms, the
  banner shows that room's new style straight away. Before, it kept the old
  look until you walked into another room.

## 3.34.0
- Smart drop and Auto map know the Autumnal and the Springtime Westfall Barn.
  The barn goes onto the door you came in by at its own shape, which is off
  the usual 6 yard steps. Only its door lines up with the other rooms.
- The barn is the first of the artisanal rooms. The game builds those at one
  size, so on the map they move and turn but don't resize. The size grips
  and the Grow, Shrink and Game size buttons are gone for them.
- The map draws the barn's raised stall bay with a railing along its open
  side and three steps up into it in the middle, and the railed flight up to
  the loft along the wall.
- Smart drop on a barn also puts its loft on the floor above, adding the
  floor if your map doesn't have it. The loft is a plain room of its own,
  with its own name, banner and sounds, and you move or resize it like any
  other.
- A barn has stairs to its loft both ways, so the map follows you up and
  down. They move and turn with the barn and can't be edited on their own.
  They aren't sent when you share, since every Chamberlain adds them to the
  barn itself.
- The floor check leaves you alone while you stand in a smaller room it
  doesn't remember, like the loft over a barn. Step out of it and the room
  you're in puts you back on its floor.
- The room editor has Delete room at the bottom left. It works like the
  trash can on the Build toolbox, so Undo delete brings the room back.
- A friend on an older version sees the barn as a plain square, with no
  stairs.
- What's New shows the barn as the map draws it.

## 3.33.0
- The room editor is part of the house map now. It opens down the left side
  in place of the Build toolbox, and the map holds still while it's open. You
  can still hover the other rooms, but a click doesn't pick them, and the
  grips, the floor buttons, Snap, Auto map and the house sounds wait until
  you save or cancel. The other rooms fade back so the one you edit stands
  out.
- Leaving the editor with changes you haven't saved asks first, from the back
  arrow, the map's close button or Escape in the name box. Save, Keep editing
  or Discard. Escape with the name box not in use closes the map and drops
  the changes.
- Delete is a trash can next to Edit room on the Build toolbox. After a
  delete, Edit room turns into Undo delete until you pick a room. It puts
  the room back with everything it had, picks it and slides the map to it,
  on its own floor. It remembers the last room you deleted until you reload.
- A copy button next to the selected room on the Build toolbox duplicates
  it, half its size right and down on the map, with its look, yapper,
  sounds and banner. The copy is named after it and gets picked so you can
  drag it. It doesn't take over the room the floor check remembers.
- With Snap on, a room dropped from the Build toolbox only goes onto an open
  door within 50 yards of you. With none that close, it lands where you
  stand, on the grid. Either way the map slides over so the new room is in
  the middle.
- Add stairs, Floor pin and the stairs editor open the same way, down the
  map's left side with the map held still, and no longer as windows of their
  own. Only one of them, or the room editor, is open at a time.
- The stairs editor has Make it a room, which turns stairs back into a room
  on the same floor and opens it in the room editor.
- The Banner tab shows the list of banner styles where the map is. Picking
  one sets it for the room, the same as before.
- Edit room on the Build toolbox is bigger and lit, right under the room
  you've selected. A selected room also gets an Edit room button on the map,
  and a double click on a room opens it too.
- The mirror button for stairwells has a new icon, two arrows pointing
  opposite ways.
- Smart drop's name fits on its button.
- A room the floor check remembers says which floor in the room editor,
  Remembered as floor 2, and changes with the Floor button.

## 3.32.0
- Smart drop in the Build toolbox maps the room you stand in. Walk into a
  room from one that's already on your map and click Smart drop. The room
  gets the shape and size the game built it at, goes onto the open door you
  came in by and turns so you're inside it. Keep walking. When you step
  outside it, it turns or moves to another open door so it covers everywhere
  you've been. It's remembered for the floor check too. Every plain shape
  works and the themed rooms don't yet, and Smart drop tells you when you're
  in one. Round rooms and stairwells keep the game's name.
- The left and right stairwells are rooms of their own with their steps
  drawn on the map and the minimap, lighter toward the top, and a railing
  round the well that follows the stairwells above and below it. The bottom
  one of a stack rails round the steps and across the end of the flight. One
  in the middle rails the three sides by the steps and the top one all four,
  with half the first step floor behind it. The up and down arrows next to
  Slide to me on the Build toolbox copy a stairwell onto the next floor, the
  empty stairwell too, and the mirror button beside them turns a left
  stairwell into a right one or back. Smart drop puts one on the floor above
  or below too, and adds that floor when your map doesn't have it yet.
- Auto map, next to Snap on the house map, runs Smart drop on each room you
  walk into, so you can map a house by walking through it. Rooms already on
  the map are left alone. The first room of a floor still needs Smart drop,
  and Auto map turns off when you leave the house.
- A selected L, T, closet, hallway or stairwell on the house map has a small
  turn button next to its middle grip.
- The bar that shows a map going out to your group says the house map when
  you share one, and how many when there are more.
- The bottom of the Build toolbox shows the game's id for the room you stand
  in, under your position and the house, and the floor the floor check puts
  you on there.
- The house map's faint grid now runs every 6 yards along the entrance's
  walls, the lines the game's rooms look to be built on. With Snap on, a room
  you drop or drag with no door near it goes onto those lines.
- Snap on the house map is on for everyone, turned on once with this update.
  The Snap switch in the map's top left corner turns it off again, and your
  choice stays after that.

## 3.31.0
- The rooms on the minimap now sit under the game's own dots. You and your
  group show as the minimap's usual arrow and dots, with their tooltips when
  you hover them, and the rooms keep the same scale as the minimap at every
  zoom.
- The minimap zooms in closer than the game lets it in a house. Turn the
  mouse wheel up at the game's closest zoom and you get three more steps.
  On those the rooms cover the minimap and Chamberlain draws you and your
  group itself, the way it did before. Zoom out goes back a step at a time.
- Inside a house with rooms on the minimap, the minimap stays north up so it
  matches the rooms. It turns again once you leave, if you have Rotate
  Minimap on.

## 3.30.2
- Remember the room I'm in shows in the room dialog in a house of one floor
  too, so your rooms can be remembered before you add a second floor.

## 3.30.1
- A room you drop from the Build toolbox only goes onto the nearest open
  door while Snap is on. With Snap off it lands at your feet like before.

## 3.30.0
- The Build toolbox has a closet and a hallway. A closet is 12 by 6 yards and
  a hallway is 12 by 24, four closets back to back, both measured in a house
  in the game. Their doors are on the short ends only, so Snap joins them the
  way the game does, and Rotate turns them.
- The shape buttons now sit in two rows of four.
- A house map with no rooms has an Add the entrance button. Every house has
  its entrance closet in the same spot, the one the game drops you in when
  you walk in, so the button puts it right there and the rest of the rooms
  can snap on from it.
- A closet or a hallway shows up as a plain room of the same size for
  anyone on an older Chamberlain.
- A room you drop from the Build toolbox goes straight onto the nearest open
  door of the rooms you have, one of its own doors on it, with Snap on or
  off. An L, a T, a closet or a hallway turns whichever way puts it nearest
  to you, and a door with another room past it is skipped.
- Rotate keeps a room on the door it's joined at and turns it around that
  door. Joined at more than one, it turns around the southmost. A turn with
  no door facing that way is skipped.
- The room banner is now the Gilded one, the scenario banner, instead of the
  plaque. If you still had the plaque it moves over once. Pick the plaque in
  Settings and it stays. Any other banner you picked stays as it is.
- The cornerstone in front of a house shows the name its owner gave the
  house in the House panel, over the game's name. You see it on houses you
  have a map of, and on your own. A house without a name of its own keeps
  the game's name.
- View Houses, the list of someone's houses you open from their name, shows
  the same names.

## 3.28.0
- Floor check puts you back on the right floor. Edit a room in a house with
  more than one floor, stand in the game room it sits in and click Remember
  the room I'm in. When you walk into
  that game room, Chamberlain puts you on the room's floor, so a missed
  stair or a jump off a balcony fixes itself.
- Chamberlain only keeps a note of the game room on its own map. Your house
  in the game stays as it is.
- It only acts as you walk in. Stairs inside the room and Move to floor still
  work as before, and it waits while the house map shows another floor.
- A stairwell can be remembered on its bottom or top floor. The floors
  between can share one game room, so chat warns you in a stairwell.
- Move a remembered game room to another floor or remove it in the editor
  and Chamberlain forgets it. A line in chat names the room.
- The notes go to your group with the map. Your group needs 3.28.0 to use
  them.
- In a group, the minimap works in a house you have no map of too. It has no
  rooms on it, but you see where your group is around you. Alone in such a
  house the game's picture stays.
- Maps and strings now carry the Chamberlain version that made them. If one
  comes from a newer version than yours, chat tells you after you take it,
  since some of it may not show until you update. The map still comes in as
  before.
- The sharing bars have a Cancel button. Cancel a share you send and your
  group's bars close too, on 3.28.0 or newer. Cancel one coming in and it
  stops, with your copy left as it was.
- The sharing bars now say Chamberlain in their title, so a bar that pops up
  when someone shares a house map with you shows where it comes from.
- Share in the Rooms window asks first. The dialog tells you what your group
  sees when the map comes in, since in a raid that is a lot of people.

## 3.27.0
- A lock on the house map, next to its close button. Click it and your map
  locks. The build tools go away and rooms can't be dragged, resized or
  deleted. Floors and stairs stay as they are too. Click it again to unlock.
- The lock is for all your houses and only on your own client. Your group
  sees nothing of it.
- While the map is locked, a click on a room opens only its Sound tab, so you
  can still change its ambience, music and entry sound. Edit in the Rooms
  window does the same. The House panel works as before.

## 3.26.0
- Snap on the house map. Turn it on in the map's top left corner, and a room
  you drag snaps door to door with the rooms next to it on the same floor.
  Rooms the game joins share a wall, so snapped rooms sit where the game puts
  them.
- With Snap on, the grips on the sides of a room are its doors and they turn
  green. An L has two doors and a T has three, at the ends of its arms. The
  side arm doors sit off the middle of the side. Drag any of them, or the
  white grip in the middle, to move the room. Grow and Shrink on the build
  tools still resize it.
- A square keeps its resize grips. Drag one of its sides near a door on
  another room and the wall snaps flush to it.
- Only one pair of doors snaps at a time. Pull the room more than a short
  distance away and it lets go.

## 3.25.0
- A room can have its own banner style. Edit the room and open the new Banner
  tab. It shows the room's banner big, with Choose style under it.
- A room with no style of its own uses the house's style, the one you set in
  the House panel. House style at the top of the picker puts a room back on
  it.
- The small banner at the top of the room editor now shows the style the room
  uses. Before, it always showed your own.
- The room's style goes to your group with the map when you save. Sound
  changes still reach them right away, but a new style comes with the map.
- Keep my style in other houses skips room styles too.
- Your group needs 3.25.0 to see a room's style. An older client shows the
  house's style there.
- Walking from one room into the next, the banner fades the old name out and
  the new one in. Fade between rooms on the Rooms page of Settings sets how
  long, half a second to start with. Off swaps the name at once, like before.
- The banner style picker has a Close button at the bottom.
- The small house icon in the bar's header is now a House button next to
  Build and Map. It shows in every house of yours, even one with no rooms
  yet, so a new house can get its name, banner and sounds first.
- Map on the bar opens the house map without the build tools, and Build opens
  it with them. The Build button in the map's corner shows or hides the tools
  and replaces the small arrow that folded the map away. The window with only
  the build tools is gone.
- The room name in the bar's header has more space. Hover it to see the full
  name, the house and which floor you are on.
- Your own dot on the house map and on the minimap has a small arrow on its
  edge that shows which way you face.

## 3.24.0
- 71 new banner styles the addon draws from the game's own files, so they
  look the way they do in the game. Nothing new ships with the addon for
  them.
- Scenario has the title banners the game shows over its scenarios, from
  Midnight's purple gem to the Horde sigil.
- Plates has the game's window titles, the covenant frames among them.
- Ribbons has the parchment title ribbon and the Legionfall and Garrison
  scrolls.
- Lines has the housing editor's own room label and a line for every class
  from the Legion artifact window.
- A style that comes in several colors is one row in the picker, with a
  color chip for each. Hover a chip to see it and click it to pick it.
- The banner picker is wider and lists its groups down the left, with a
  search box over them. It opens on the group of the style you use.
- A banner grows with a long name. On the scenario banners the ornament keeps
  its size and the sides stretch, and on the plates and ribbons the middle
  stretches. The name takes the room's color, except on the parchment
  ribbons and scrolls, where it's dark ink.
- Your group needs 3.24.0 to see one of them on your house. An older
  client shows its own style instead.

## 3.23.0
- When you walk into a house, a plaque comes up with its name big and
  glowing, whose house it is under that and the owner's motto under both. It
  fades after a few seconds and sits over the room banner. Every house has a
  name in the game, so it works in any house, map or no map. Drag it where you
  want it. House plaque on the Rooms page of Settings turns it off.
- You can give your house a name of your own in the House panel. It goes on
  the plaque and in the Rooms list over the name the game gave it. Leave it
  empty and the game's name is back.
- A House panel sets the name, the banner style, the motto and the sounds for
  a whole house, arrival sound included. The house icon on the bar opens it in
  a house of yours, and House in the Rooms window opens it for the house you
  picked there. It takes the place of the Banner button.
- The music row has a Use silence button. Silence for the whole house stops
  the game's own music, so the music on your floors and rooms is all you hear.
- Your group gets a new name or motto right away, and both go out with the
  map and the export string too. Group members need 3.23.0 to see them.
- The Rooms window lists a house by its name, with whose house it is under
  that. A map you got from somebody carries the name from
  3.23.0 on, so older maps keep the old label until they are shared again.
- The web site shows the house name and the motto.

## 3.22.0
- A Rainbow group in the banner picker, nine styles. Arch, Wave, Swoosh
  and Chalk are public domain rainbows cut in two, so the name sits
  between the halves. Band, Eight stripe, Pastel, Jewel and Faded are a
  flat band with a swallowtail at each end, one cut in five palettes. They
  all keep their own colors whatever the room is set to, and the name is
  white on them. Your group needs 3.22.0 to see one on your house. An
  older client shows its own style instead.
- The banner sample on the Rooms page of Settings sits under its help text
  again. The longer help from 3.21.0 had run into it.

## 3.21.0
- Every room shape the game builds is in the Add row now, one icon each,
  the L, the T, the plus and the octagon beside the square and the round
  room. A room lands at the size the game builds it, so a square starts Tiny
  and an octagon Small, and Quick resize under the room list switches a
  square or an octagon between the game's sizes. An L or a T turns a quarter with Rotate, and Game size
  takes a room you resized by hand back to the size the game builds it at.
  A new room is named after its shape, so the second round room you drop
  starts as Round room 2.
- Edit room has a Copy from button that takes another room's color, yapper,
  sounds and ticks, and a Shape row that gives the room another shape at the
  game's size around its middle. Both keep the name and everything you
  don't change, for a room whose real one you swapped.
- A shaped room keeps its shape. Grow, Shrink and the grips on the map scale
  it as a whole about its middle. A square still moves one wall at a time
  like before.
- Slide to me moves the picked room so its nearest wall is where you stand,
  for every shape. Stretch to me is the old Snap nearest edge to me, for
  squares.
- On the map an L, T, plus or octagon is cut to its shape, on the minimap
  too, and its missing corner clicks through to the room under it. Walking
  into that corner does not count as being in the room either.
- Always use my style in Settings is now called Keep my style in other
  houses, and its hint and the Banner style hint say plainly what each does.
  It no longer hides the style you picked for your own house, which made a
  new pick there look like it did nothing.
- Stairs on both floors in Settings, on as before, draws a staircase on both
  floors it joins. Turn it off and each end shows only on its own floor.
- Sharing sends an L, T or plus as its centre, size and turn, which is
  smaller than a box. A group member on an older version sees the rest of
  your rooms and a note tells you who that is, as with floors.

## 3.20.1
- The Sharing to group bar closes when the last part of your house is sent.
  Before, it stayed open until the addon had also told the group about every
  map you hold, which took a long time with many maps, and the Share button
  stayed off for all of it.

## 3.20.0
- You can pick a banner style for each of your houses. Choose style in
  Settings sets it for the house you stand in when it's yours, and the Banner
  button in the Rooms window sets it for the house you have selected. Your
  group sees a new pick right away, even on an older copy of your map, and an
  exported string carries it too.
  Visitor's own at the top of the list leaves it to each visitor, like before.
  Outside your houses, Choose style still sets your own style.
- A house's style wins over the one you picked in Settings. Always use my
  style under Banner style keeps yours in every house.
- A style from a newer version of Chamberlain shows as your own style.

## 3.19.0
- Eight new banner styles made from old public domain ornaments, named
  Nameplate, Cartouche, Parchment, Scroll, Pennant, Deco, Nouveau and Filigree
  in the style list. Each one is cut into two ends and a middle that grows
  with the name, and on Parchment the torn middle repeats instead of
  stretching. Nameplate, Cartouche and the three wing styles take the room's
  color like the others. Parchment, Scroll and Pennant keep their own colors
  and write the name in a color that reads on them.
- The style menu is now a Choose style button that opens a list of every
  style, each drawn as a small banner. The one you have picked shows big at
  the top. Short name and Long name show how a style stretches. A click on
  a row takes it right away. The same button sits in this release's What's New
  note, and the 3.18.0 note lost its old style menu.

## 3.18.0
- The house map draws its rooms more clearly. A small room now always sits on
  top of the big room around it, whichever was made first, so a closet no
  longer hides under its bedroom.
- Room names are pale with a shadow, so they read on any room color. The
  fills are a dark wash of the room's color with a crisp edge.
- A name sits in the middle of its room, and moves to the top left corner only
  when a smaller room covers the middle. Names never overlap each other, and
  where two would, the bigger room keeps its name. A room too small for even a
  few letters leaves its name to the hover.
- Stairs and sound spots show as a small icon instead of a named box, on the
  map and on the minimap. Show stairs on the map used to hide them. Now it
  draws each stair's box under its icon, for lining them up.
- The minimap draws the rooms without their names, which crowded it at that
  size. The house map still has them.
- A faint grid every 8 yards sits behind the rooms, with a scale bar in the
  corner that follows the zoom.
- The room banner comes in ten styles and starts on the new Plaque. Pick
  another under Banner style on the Rooms page of Settings, or in the What's
  New note, each with a sample. Zone text looks like the game's own zone names
  and Original is the banner as it was. Seven more sit in the menu to try, and
  all but Original have a Read button that's a book in a small frame in the
  room's color. The choice stays on your computer, so everyone sees their own.
- The web site draws shared houses the same way.

## 3.17.0
- The Rooms window got a new layout, for players in housing guilds who hold
  maps from dozens of people. The houses are now a short list on the left, one
  line each with its number of rooms. Click a house to see its rooms on the
  right. A search box above the list finds a house by its owner or by the name
  of one of its rooms.
- The Group tab is gone. When somebody in your group has a map you don't, or a
  newer one than yours, it shows at the top of the list under In your group,
  with a Request button on the right.
- The Rooms and Sharing buttons on the bar opened the same window, so Rooms is
  gone and Sharing opens it. It starts on the first map your group offers, the
  one the gold dot is about. With one or two buttons the bar no longer shrinks,
  and the buttons grow to fill it, so the now playing names keep their room
  when you visit a house.
- A Map button in the Rooms window opens the house map of the house you clicked,
  from anywhere. You can only look at it. It shows no dots or build tools, and
  the floor stays where you put it. Secret rooms stay hidden unless the house is
  yours. The Map button on the bar, or the Build toolbox, brings back the map of
  the house you stand in.
- Share My Houses is now a Share button on each of your houses, so you pick
  the house by clicking it. Export works on the house you clicked too, and the
  menu that asked which house is gone.
- The Build toolbox and the house map are one window now. The tools run down
  its left side and the map fills the rest. Build on the bar opens it folded
  to just the tools and Map opens all of it. The arrow in the corner switches
  between the two. The toolbox no longer docks, floats or tears off.
- The map's own rows of Move, Grow and Shrink arrows are gone. The tools have
  one arrow pad with a Move, Grow and Shrink switch, and the middle of the pad
  grows or shrinks every wall at once, like the old Grow and Shrink buttons.
- Floors are tabs along the top of the map, with + and - next to them in your
  own house. The sound buttons and the Sound spots and Stairs ticks moved to
  one row under the map.
- A map you can only look at gets a house card where the tools would be. It
  shows whose house it is, how many rooms it has and how old the map is. A
  Request button turns up when your group has a newer one. Point at a room and
  the card shows its name, size and sounds. The descriptions stay out of it,
  since they're for reading in the house.
- The room editor has three tabs, Room, Yapper and Sound, under a preview of
  the banner in the room's color. It no longer grows taller on a house with
  floors. The map's colors are quick picks next to your recent ones.
- The bar names the room you stand in, and the floor when the house has more
  than one. Its buttons have icons, and what's playing got its own line under
  them. Slim bar in Settings shrinks it to a single row of icons.
- Settings has pages down its left side and a switch with a line of help for
  each setting. The six kinds of house sound are switches on the Sound page,
  so the menu that held them is gone from there. The bar's speaker still
  opens it.
- Room echoes only go to your group now. Echoes from older versions that still
  come in through the guild are ignored, and the front door still reaches
  guildmates.
- Two new switches on the Sound page decide who hears the door when you walk
  into a house, one for your group and one for your guild. Turn one off and
  those players don't hear it.
- Rooms on the minimap is on for everyone now, visitors included, and this
  update switches it on once for those who had it off. It only takes over
  the minimap in a house you have a map of, so a house without one keeps the
  game's picture. Settings turns it off again.
- The icons need 12.1. On 12.0 the buttons keep their plain labels and the
  switches are square.

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
