# Chamberlain - Room Names for Housing

Chamberlain lets you name the rooms in your player house. When you walk into a
room, a gold banner shows its name. The banner fades out when you leave. The
addon takes its name from the manor officer who announced guests as they
entered each room.

The banner has ten looks to pick from in Settings, one of them like the
game's own zone names. Only you see the look you pick, so a visitor sees the
room in their own.

To make a room, open the Build toolbox and click Square room or Round room. The
room drops where you stand and the name box opens. To fit the room to the
walls, select it, walk to a wall and click Snap nearest edge to me. The arrows
under it move the room, or push and pull one wall at a time. You can also drag
the corners of the room on the house map.

The Build toolbox and the house map are one window, with the tools down its
left side. Build on the bar opens it folded to just the tools, for walking
around the house. Map opens the whole thing, and the arrow in its corner folds
it or opens it again.

Rooms can overlap. Put a closet inside your bedroom and the smaller room wins
while you stand in it.

The house map draws all your rooms to scale, each in its own color. A dot shows
where you are, and your group members show as dots too. Hover a room to see its
name and size when the label doesn't fit. A small room always sits on top of
the room around it, and stairs and sound spots show as small icons. The mouse
wheel zooms, and a drag on an empty patch moves the view. The labels and your
dot stay the same size.

The rooms also take the place of the minimap picture. Indoors the game shows a
still picture of a house there. In a house you have a map of, the rooms of your
floor show in its place, with you in the middle. The usual minimap buttons zoom
it. Rooms on the minimap in Settings turns it off. If a different addon makes
your minimap square, turn on Square minimap too.

## Floors

A house with more than one floor can have rooms on each floor. A room upstairs
doesn't fire the banner of the room below it. The game doesn't tell addons your
height, so Chamberlain learns your floor from your stairs.

In the Build toolbox click Stairs. Stand on the lowest step and click Mark
bottom. Then go up a little and click Mark top. When you walk onto a mark,
Chamberlain puts you on the floor of that mark.

For a tall shaft, a fall or a balcony, drop a Floor pin. A Floor pin works on
every floor, and you set the floor it sends you to.

The house map has a tab for each floor, and its + button adds one. Its
Move to floor button corrects Chamberlain when it has the wrong floor. If your
stairs spiral, one flight sits above the next. Keep the marks of each flight
off the same spot, or they trigger each other.

## Room name, description and talking head

A room has more than a name. You can set a color for the banner and the map
tile. You can write a description and pick a face that reads it in a talking
head box. Your computer can speak the description in a voice you pick. The
voice stays on your computer and goes to nobody. The room editor keeps these
on three tabs, Room, Yapper and Sound, under a preview of the banner.

A room marked Secret stays off the house maps and room lists of your visitors.
Its banner still fires when they walk in.

## Ambience and music

A room can have a background sound. Edit the room and pick a sound from the
Ambience menu on the Sound tab. The menu has more than 100 loops from the game,
in short categories. A crowded tavern and a slow river are there, and so is
Naxxramas.
The sound fades in when you enter and fades out when you leave.

For a fireplace or a fountain, drop a small room on it, give it the sound and
untick Banner. A room without a banner doesn't count as the room you are in.
The hall around it keeps its banner and its own sound, and the fire plays on
top. Tick Secret too and your visitors don't see it on their map.

The house and each floor can have a sound too, from the Ambience button on the
house map. The sound of a room plays in place of the sound of its floor. The
sound of a floor plays in place of the sound of the house.

Music works the same way. A room, a floor or the house can have a track from
the game's music. You pick it in a search window, where a click plays the track
first. The track takes the place of the game's music while you are there.
Silence is one of the picks, for a room that must have no music. The window
opens on the tracks your house already uses, so one click puts the track of the
hall into the next room.

The title strip of the Chamberlain bar names the track in gold and the ambience
after it. Hover it for the full path of the track. The game has no such
readout, so this is how a guest learns the name of the tune in your hall.

## Entry sounds, echoes and the front door

A room can play a short sound as you walk in. Set it on the Entry sound row of
the room, under Music. The list runs from door bells and chimes to alarms,
horns, laughs and screams. Chamberlain brings 3 of the bells itself, because
the game has no shop door bell. Any other game sound works by its file number.
That number is the FileDataID that sites like wago.tools list for every file in
the game.

Plays sets how often the sound plays, from 1 to 5 times, or Loops. A sound with
a count plays to its end even when you have already left the room. A thin room
across a doorway thus rings in full. A sound that loops stops when you leave.

Echo lets the others in the house hear the sound too. Drag the Echo slider in
the same window to a number of yards, or to Whole house. When somebody walks
into that room, everybody in range hears its sound. Floors don't count for the
range. Put a bell with Whole house on your entrance hall and you hear each
guest arrive, even down in the cellar.

The house can also have an arrival sound, the sound of your front door. Pick it
with the Arrival button on the house map. It plays for everybody inside when
somebody with Chamberlain walks into the house. The visitor doesn't need your
map, so a first visit rings too. It rings once for each visit, and a reload
doesn't ring it.

To hear an echo or an arrival you need the map of the house. An echo needs you
in a group with the person who walked in. An arrival also reaches you through
a guild you share with them. Each person rings a
room for you once in 30 seconds, and a slider in Settings changes that. If the
game's sound is off for you, a chat line tells you who is at the door.

## Volume and mutes

Visitors with your map hear all of these sounds. When you change a sound while
you are in a group, your group hears the change at once. A chat line names the
new sound for those who are in the house.

Ambience follows the game's Ambience volume and music follows the Music volume.
Entry sounds, echoes and the arrival sound follow the Effects volume.

The speaker on the Chamberlain bar opens the house sounds, in your house or in
any other. Mute all at the top silences them all at once. Under it you can mute
the ambience, the music and the rest one kind at a time.
There you can mute only the music, or only the arrivals of guildmates.
Settings has 2 sliders that set how soon the same person, or the same room, can
ring for you again.

## Archive

Since patch 12.1 you can save a house to a blueprint, reset it and build it
again from a different blueprint. A room map made for the old house would then
fire in the new one. The Archive keeps a map for that time. Store the map under
a name. If you pick the blueprint it goes with, the map takes the name of the
blueprint. Then clear the rooms or continue to build.

Restore brings a stored map back as the live map. If the live map has edits you
did not store, Chamberlain asks first. You can keep as many maps for a house as
you want and switch between them. You can also put a map from a different house
of yours into the house you stand in.

Chamberlain also watches the blueprint and reset actions. When you save a
blueprint of the full layout or of the interior, it offers to store the map
with it. When you load a blueprint, the map stored with it comes back. When you
reset the house, it asks what to do with the rooms that are still on the map.

The Archive stays on your computer. Your group gets only the live map, and an
export string holds only a live map.

## Sharing

If you are in a party or a raid with other Chamberlain users, you can send them
your map or ask for theirs. A house then needs a map only once. The Rooms
window lists every house you hold a map of, one line each, with a search box
that finds a house by its owner or by a room name. Maps your group offers show
at the top under In your group. The Sharing button on the Chamberlain bar opens
the window, on the first map your group offers if there is one. A gold dot on
the button tells you that somebody has a map of the house you are in. Click one
of your houses and then Share to send its map. Map shows the floor plan of the
house you clicked, even when you are somewhere else.

Every request for your map shows a consent dialog before Chamberlain sends
anything. You can block players or houses that ask too often. A map from your
group never replaces the map of your own house. Maps you received sit in a list
of their own, and you can remove them at any time. You can turn Sharing off in
Settings.

Export makes a text string of the map of the house you clicked. Import reads
such a string. Before Import saves anything, a dialog shows what the string
holds. You see the owner named in it, the number of rooms
and floors, the date of the last change and the first room names. If the string
is for your own house, the dialog says so in red. Decline it unless it is a
backup that you made.

## Good to know

- The build tools show only in your own house. Ownership comes from the server
  and not from your character name, so your alts can edit too.
- If you own a house on both factions, Chamberlain tracks them separately.
- Floors come from the stairs you mark, because the game doesn't tell addons
  your height. With no stairs marked, the house is one floor.
- After an update, a What's New note shows the first time you step indoors. You
  can close it, or turn it off for good. If you turned it off, a note icon
  blinks on the Chamberlain bar when an update has notes you did not read.
- Echoes, the arrival sound and the 3 bells need version 3.14.0 or later on
  both sides. A visitor on an older version sees and hears the rest as before.
- A sound you pick for the whole house or for a floor reaches your group even
  when their map is older than yours, from 3.15.0 on both sides. A room's own
  sound needs their map to match yours, so send it again with Share after you
  add, move or delete a room.

## Features

- Make rooms from the Build toolbox. A square or round room drops where you
  stand.
- A gold banner shows the name of the room when you enter and fades when you
  leave.
- Background sound for a room, a floor or the house, from more than 100 of the
  game's ambience loops. A small room without a banner puts a fire inside the
  great hall.
- Music for a room, a floor or the house, from the game's tracks. Search for a
  track and click it to hear it before you pick.
- An entry sound for each room, from a list of bells, chimes, alarms, horns and
  laughs, or any game sound by its file number.
- Echoes. The others in the house hear a room's entry sound when somebody walks
  in, as far as you set.
- An arrival sound for the house. It rings for everybody inside when a visitor
  walks in.
- A mute for each kind of house sound, and 2 sliders that set how often echoes
  ring for you.
- A house map that draws your rooms to scale and shows where you and your group
  are. Zoom it and move it with the mouse.
- Rooms on the minimap indoors, in place of the game's still house picture.
- Edit rooms on the house map. You can move, resize, rename and recolor them.
- A talking head "Yapper" reads the description of a room like an NPC. Your
  computer can speak it with its TTS (text to speech) voices.
- Secret rooms stay off the maps of your visitors but still announce
  themselves.
- More than one floor, with each room tied to a floor.
- Mark your stairs and the map goes up and down with you. A Floor pin sends you
  to any floor from anywhere.
- Chamberlain tracks the time you spend in each of your rooms and shows it in
  the room tooltip.
- Share maps with your party or raid, or export a map to a text string that
  others can import. Use export for a very large map with a lot of text.
- An import shows what the string holds before you accept it.
- An archive of stored maps for each house, tied to your blueprints if you
  want. The rooms stay safe through a reset or a change of blueprint.
- Block players or houses that ask for your map too often.
- A minimap button and the slash commands /chamberlain and /rooms.

Logo by [Lorc](https://lorcblog.blogspot.com/) from [game-icons.net](https://game-icons.net/1x1/lorc/top-hat.html), licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)
