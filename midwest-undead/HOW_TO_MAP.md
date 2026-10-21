# How to make the map

The game's world is one scene: `world/map/map.tscn`. It's a 1 km square of
ground (the **terrain**) that you shape, paint and fill in the Godot editor.
Everything you make there is exactly what the game uses.

This guide goes in the order you'd usually work in. You don't have to finish
one step before starting the next; come back and change anything at any time.

1. [Before you start](#1-before-you-start)
2. [Shaping the land](#2-shaping-the-land)
3. [Painting the ground](#3-painting-the-ground)
4. [Roads](#4-roads)
5. [Creeks, waterfalls and ponds](#5-creeks-waterfalls-and-ponds)
6. [Forests and plants](#6-forests-and-plants)
7. [Crop fields](#7-crop-fields)
8. [Cliffs and rocks](#8-cliffs-and-rocks)
9. [Mines](#9-mines)
10. [Buildings on hills](#10-buildings-on-hills)
11. [The edge of the map](#11-the-edge-of-the-map)
12. [Putting the story back: markers](#12-putting-the-story-back-markers)
13. [How the land plays](#13-how-the-land-plays)
14. [Real textures instead of the placeholders](#14-real-textures-instead-of-the-placeholders)
15. [Keeping it fast](#15-keeping-it-fast)
16. [When something goes wrong](#16-when-something-goes-wrong)

---

## 1. Before you start

**Open the map.** In the FileSystem dock (bottom left), go to `world/map/` and
double-click `map.tscn`. In the Scene dock (top left) you'll see:

- **Terrain**: the ground itself (a Terrain3D node; Terrain3D is the plugin
  that does the ground).
- **Buildings**, **Markers**: folders for things you place. More folders
  (Roads, Water, Plants, Fields, Rocks, Mines) appear by themselves when you
  add those things.

**Moving around the 3D view.** Hold the right mouse button and use W A S D to
fly, Q and E to go down and up, and the mouse to look. The mouse wheel while
holding right-click changes how fast you fly. Select something and press F
to jump to it.

**Two tool sets:**

- The **Terrain3D toolbar** (a column of buttons down the left of the 3D view)
  appears when you select the **Terrain** node. It sculpts and paints the
  ground.
- The **Map Tools** panel is a tab along the bottom of the editor, next to
  Output. It adds roads, creeks, ponds, plants, fields, rocks, mines
  and buildings (drawing their outlines, stairs, doors and windows:
  `HOW_TO_BUILD.md`). If you can't see it, click **Map Tools** in the bottom bar.

**Saving.** Ctrl+S saves the scene *and* the terrain (heights, paint and
plants are kept in `world/map/terrain/`, one file per 256 m tile). Save
often. Saving also gives everything a save game has to find again its save
ID (`HOW_TO_BUILD.md`, "Things the game relies on": rename or move it and
saves still find it).

**Undo.** Ctrl+Z undoes almost anything: sculpting, painting, Apply, a plant
brush stroke. The **History** tab (next to the Inspector tab) lists every
step.

**Trying it out.** Press F5 and start a new game. Old saves from the old
town won't load (the map changed).

**The map is in tiles.** The 1 km is 4 x 4 squares of 256 m (press **1**
with the mouse over the 3D view and the Terrain selected to see their
outlines). This doesn't change anything you do; it's there so the game can
load parts of the map separately later if it ever needs to.

**The map starts flat.** Every hill is yours to make.

---

## 2. Shaping the land

Select the **Terrain** node. The Terrain3D toolbar appears on the left of the
3D view, and its settings (brush size, strength...) along the bottom.

The sculpting tools:

| Tool (key) | What it does |
|---|---|
| **Raise** (R) | Click and drag to push the ground up. Hold **Ctrl** to push it down. Hold **Shift** to smooth instead. |
| **Height** (H) | Sets the ground to an exact height (set in the bottom bar). Good for flat valley floors and building pads. **Ctrl+click** picks up the height under the mouse first. |
| **Slope** (S) | Drag from one point to another to make an even slope between them. Good for road grades and ramps. |
| **Smooth** | Hold **Shift** with any sculpting tool. Softens bumps and sharp edges. |

In the bottom bar: **Size** is the brush's width in meters, **Strength** how
hard it works. Big soft brushes (size 60 to 150 m, low strength) make
natural hills; small strong ones make details.

**Kentucky / Tennessee hill country, step by step** (about 150 m from valley
floor to ridgetop):

1. With **Height**, set a valley floor height of 0 m. Leave the valleys there.
2. With **Raise**, big brush (100 m+), build long **ridges** across the map.
   Ridges in this country are long and wavy, not round mountains.
3. Between ridges, leave narrow **hollows** (hollers): steep-sided valleys
   with a little flat ground at the bottom for a creek, a road and a few
   houses.
4. Shift-drag (smooth) over everything to soften the shapes.
5. Make a few slopes really steep (past 45 degrees). Nobody can climb those,
   so they become the edges of your hollows and the barriers at the map's
   edge (see section 11). Steep ground shows as rock by itself.
6. Keep some wider flat bottomland for the town, the farms and the station.

Tips:
- **Alt + click** with Raise lifts only the low ground (fills valleys without
  touching ridges); **Ctrl + Alt + click** lowers only the high ground.
- Press **3** (mouse over the 3D view) to show contour lines: handy for
  seeing how steep a slope is.
- Zombies and people slow down going uphill, and can't climb past 45
  degrees: a ridge is a real obstacle for a horde (section 13).

---

## 3. Painting the ground

The ground's look comes from a list of ground textures (the **asset dock**,
which appears when the Terrain is selected, usually along the bottom; switch
it to **Textures**):

| # | Texture | Notes |
|---|---|---|
| 0 | Grass | Real texture. Flat ground is grass by itself. |
| 1 | Rock | Real texture. Steep ground is rock by itself. |
| 2 | Forest floor | Leaves: paint it under woods. |
| 3 | Dirt | Creek banks, yards. |
| 4 | Worn path | Footpaths, dirt tracks. |
| 5 | Gravel | Gravel roads, shoulders, driveways. |
| 6 | Mud | Looks only (it doesn't slow you). |
| 7 | Plowed field | Crop fields paint it themselves. |
| 8 | Red clay | Road cuts, bare hillsides. |
| 9 | Creek stones | Creeks paint it themselves. |

2 to 9 are placeholders made for the game: see section 14 to swap in real
ones.

**Grass on the flat, rock on steep slopes happens by itself** (the
*autoshader*). You only paint what's different.

- **Paint** (B): click a texture in the asset dock, then paint. Hard edges.
- **Spray** (V): blends a texture softly over what's there. Good for patches
  of dirt in grass, leaves at a forest's edge.
- **Autoshader** (A): paints the automatic grass/rock back on. **Ctrl+click**
  with it turns it off where you paint.
- **Color** (C) and **Wetness** (W): tint the ground, or make it look wet
  (darker, shinier). Good along creeks.

Roads, creeks and crop fields paint the ground under themselves when you
Apply them, so you don't need to.

---

## 4. Roads

1. In **Map Tools**, under **Roads**, choose a kind of road from the list:
   *Paved two-lane*, *Gravel road* or *Dirt track*.
2. Click **New road**. A short road appears where you're looking.
3. Under **Selected**, turn on **Draw points**. Click on the ground along
   where the road goes: each click adds a point at the end. Right-click
   removes the last point.
4. Drag the points to adjust (the handles on the path). The road's height
   doesn't come from the points: it follows the ground.
5. Press **Apply**. The ground under the road is levelled side to side, cut
   away above it on a hillside (steep cuts turn to rock), built up below it,
   and painted. Paved roads also get their surface, center line and edge
   lines.
6. Change anything and press **Apply** again. Ctrl+Z undoes an Apply.

**Bridges.** Where a road crosses a creek or a hollow:

1. Select the road and click **Add bridge span**.
2. Move the span marker to the crossing, and up or down to the height the
   deck should be (use the move gizmo, W).
3. In the Inspector set **Length** (meters of deck).
4. Press **Apply** on the road. Over the span the road is a flat deck with
   collision, and the ground under it is left alone. The road ramps up to
   the deck on each side.
5. Put your own support models (or kit boxes from `world/kit/pieces/`) under
   the deck.

**Making a new kind of road.** Road kinds are files in `world/map/roads/`.
Right-click one in the FileSystem dock, **Duplicate**, then double-click the
copy and change it in the Inspector:

- **Width:** the driving surface, meters.
- **Surface:** *Paved* (a surface of its own, in Surface Color) or *Painted*
  (the ground painted with Surface Texture).
- **Ruts:** painted roads only: just two wheel tracks with grass between.
- **Shoulder Width / Shoulder Texture:** the strip either side.
- **Markings:** center line (none, dashed, solid, double) and edge lines.
- **Cut Slope / Fill Slope:** how steep the bank above and the fill below
  are (1 = 45 degrees).
- **Smoothing:** how far bumps are smoothed out along the road.

Click **Update plant list** in Map Tools (it refreshes the road kinds too) and
the new kind shows up in the Roads list.

---

## 5. Creeks, waterfalls and ponds

**Creeks**

1. Click **New creek**, turn on **Draw points**, and click along the creek
   **from upstream (where it starts) to downstream (where it ends)**. Follow
   the bottoms of your hollows.
2. In the Inspector: **Width Start / Width End** (it widens downstream),
   **Depth** (water in the middle; deeper than 1.3 m is swimming), **Bank**
   (how far the banks slope back up).
3. Press **Apply**: a channel is carved and lined with stones, and the water
   runs along it, always downhill. Where it drops steeply it turns to white
   rapids by itself.
4. **Waterfalls:** select the creek, click **Add waterfall**, move the marker
   to where the ledge should be, then **Apply** the creek again. Above the
   falls the water runs level for **Pool** meters, then drops all at once.

Applying a creek again doesn't dig it any deeper: it remembers the ground it
started from.

**Ponds and lakes**

1. Dig the basin first with the Terrain3D tools (Raise with Ctrl, or Height).
2. Click **New pond**. Move it over the basin and up or down to the water
   level you want. Set **Size** in the Inspector (big enough to cover the
   basin: water only shows where the ground is lower, so it doesn't have to
   fit the shoreline).

**How water plays:** shallower than 25 cm doesn't slow you. Deeper you wade
(slower; zombies slower still). From 1.3 m you swim: slowly, no guns.
Zombies can't swim: they drown in deep water, and walk around it if they can.

---

## 6. Forests and plants

Plants are painted with brushes. Under **Plants** in Map Tools:

1. Choose a brush from the list. The map's **Plants** node gets selected and
   the 3D view becomes a brush (a yellow circle follows the mouse).
2. Set **Size** (meters across) and **Density**.
3. Click and drag on the ground. Ctrl+Z undoes a whole stroke.
4. Choose **Off** (or select something else) to stop painting.

| Brush | What it does |
|---|---|
| **Forest** | A natural mix: oak, maple, tulip poplar and pine of different sizes, with bushes, ferns and fallen logs between them. Thinner toward the edge of the brush, so woods fade into fields. Density 1 = open woods, 2-3 = forest, 4+ = thick. |
| **Paint plant** | Only the plant chosen in the second list (a pine grove, a hedge of bushes, a patch of corn). |
| **Place one** | One plant exactly where you click. |
| **Erase** | Removes trees and undergrowth (not crops) in the circle. |

No brush puts plants on slopes steeper than each plant allows (most trees: 35
degrees, so cliffs stay bare), under deep water, or closer together than
their spacing.

In the game, **trees have solid trunks** (they stop you, zombies and
bullets, and block sight). **Bushes and crops hide you when you crouch** in
them (zombies can still hear you).

**Adding a plant of your own** (when you have models):

1. Make a scene with your model: a MeshInstance3D at the top (or import a
   .glb and make a scene from it). The bottom of the trunk at the scene's
   origin.
2. In `world/map/plants/`, duplicate a plant file (oak.tres for a tree,
   bush.tres for undergrowth, corn.tres for a crop), and in the Inspector:
   - **Display Name**, **Scene** (your model), **Kind**.
   - **Mesh Id:** set it to **-1** (the copy still has the original's number).
   - **Forest Share:** how often the Forest brush picks it (0: never).
   - **Scale Min/Max, Spacing, Max Slope:** sizes and how it's placed.
   - **Trunk Radius** (trees: solid trunk), **Hides** (cover), **View
     Distance** (not drawn further than this), **Shadows**.
3. In Map Tools click **Update plant list**. It gets its own number and
   appears in the plant list.

Replacing a placeholder with your own model: open its plant file and change
**Scene**, then **Update plant list**. Everything already painted changes
with it.

(Terrain3D has its own plant brush too: select the Terrain, press I, and pick
a plant in the asset dock under **Meshes**. It paints one kind at a time.)

---

## 7. Crop fields

1. Click **New crop field** (under **Fields and features**). A field appears
   where you're looking.
2. Select it, turn on **Draw points** and click its corners in order (it
   closes itself). Or drag the four corners it starts with.
3. In the Inspector: **Crop** (corn.tres or tobacco.tres), **Row Angle**
   (which way the rows run), **Row Spacing**, **Plant Spacing**.
4. Press **Apply** to plow the ground under it.

The crop stands in straight rows following the slope. Crouch in it to hide.
For crops in odd shapes, paint them with the **Paint plant** brush instead.

---

## 8. Cliffs and rocks

**Cliffs** are just very steep ground: sculpt it (Raise with a small strong
brush, or Slope) past about 50 degrees and the rock texture appears by
itself. Nobody can climb it.

**Rocks and outcrops:**

1. Click **New rock**. A boulder appears where you're looking.
2. Move (W), turn (E) and scale (R) it: flat and wide for a ledge, tall for a
   crag, half sunk into a hillside for an outcrop.
3. **Shape** in the Inspector changes its shape (any number); **Roughness**
   how jagged it is.
4. Ctrl+D copies it. A few copies with different shapes make a rock pile.

Rocks are solid, and zombies path around them.

---

## 9. Mines

A mine is one node (a **KitMine**) holding all its tunnels and chambers,
laid out on a grid of 2.5 m squares (**cells**) under the hills. Tunnels are
one cell wide and 3 m high, held up by timber frames; **chambers** are big
rooms, taller than a tunnel. **Levels** are 4 m apart: level 0 is the node's
own height, -1 the one under it, and so on. It's dark inside (no sun or moon
gets in, and the sky's light stops a few meters in from each entrance), so
bring a flashlight, a helmet lamp or a lantern.

1. Make a steep hillside (section 2).
2. In Map Tools' **Mines** section click **New mine**. It appears where
   you're looking: an entrance and a tunnel running away from you.
3. Move the node to the **foot** of the hillside, its floor at the ground,
   and turn it so the tunnel runs into the hill (the green line in its plan
   is the entrance).
4. Pick a tool (the mine must be selected). Its plan shows over everything,
   through the hill: the **Level** you're drawing on in yellow, the other
   levels faint blue, entrances green, shafts a purple X, cave-ins a brown
   box, floods outlined blue, and what a click would add in orange.
   - **Draw tunnel**: click where it starts, then each corner. It runs
     straight from corner to corner along the grid. **Esc** or **Enter**
     ends it; the next click starts another. Start or end on another tunnel
     or a chamber to join them. Right-click takes back the last corner, or
     (when you're not drawing one) removes the tunnel under the mouse.
   - **Draw chamber**: click one corner, then the opposite one. Right-click
     removes the chamber under the mouse. Its **Height** is in the Inspector
     (Chambers); taller than 4 m, a tunnel on the level above that reaches
     its side opens onto a ledge over it.
   - **Mark entrance**: click the end of a tunnel that comes out of the
     hill (again to take it back). A mine can have as many as you like.
5. **Rails** (in the Mines section) gives new tunnels rails; each tunnel's
   **Rails** and **Carts** are in the Inspector (Tunnels). Carts stand at
   the end of the rails where a tunnel stops dead (anywhere else they'd
   block the way). Everything the tools do can also be typed in there.
6. At each entrance the floor runs on 1.5 m past the timber portal. Make the
   ground **level with the floor** where that ends, rising into the hill
   over the portal.
7. Press **Apply**. The hillside is opened where the mine comes through it
   (wherever the ground is inside a tunnel or chamber, or less than a meter
   over its ceiling); under plenty of hill it stays closed. Apply again after
   moving it, drawing more, or re-sculpting the ground over it.

**Between levels:**

- **Ramps.** While drawing a tunnel, change the **Level** before clicking the
  next corner: the stretch between the two corners slopes from one level to
  the other. It needs at least 3 cells for each level it climbs (about 28
  degrees), and Map Tools lengthens it if you click closer; draw it longer
  for a gentler slope. Zombies walk ramps.
- **Shafts** (**Place shaft**): pick the kind (under the Rails box), click
  where it goes on one Level, change the Level and click again. Tunnels on
  the levels it passes that reach its side open into it. Right-click removes
  the shaft under the mouse.
  - **Ladder shaft:** a ladder up one wall (the one no tunnel comes in by),
    and timber landings, half the shaft, on each level a tunnel comes in on.
    You climb up the open half and step off onto a landing.
  - **Open shaft:** just a drop. Falls hurt from 4 m up, and 12 m kills.
  - **Cage shaft:** an elevator. It stops at the bottom and on each level a
    tunnel comes in on. A lever inside sends it to the next stop; a call
    button beside each stop's gate brings it there. The gates stay shut
    unless the cage is at that stop. Zombies that follow you into it ride
    along. It needs power (next).
  - **To Surface** (in the Inspector, Shafts): the shaft comes out on the
    surface, with a stone collar and a timber headframe at **Surface
    Height** (meters over its top level's floor). Set that to where the
    ground is, and press Apply.
- **Generator** (**Place generator**): click where it goes. Every cage in
  the mine works while one of its generators runs. In the game you pour in a
  **gas can** (found in workshops, on farms and in cars) for an hour's
  running, up to three. It's loud: zombies within 35 m hear it.

**Hazards:**

- **Cave-ins** (**Place cave-in**): click a tunnel's cell to fill it with
  rock and broken timber, floor to roof (click again, or right-click, to take
  it away). Zombies can't get past one either. In the game it takes a
  **pickaxe** (found in workshops and on farms): hold interact on it for 12
  seconds, noisily; stop and come back and you carry on where you were.
  Dynamite blows one clear at once. Dug or blown through, it's gone for good
  (the save remembers).
- **Floods** (**Flood**): click one corner of the flooded stretch, then the
  opposite one, on the Level set here; right-click removes the flood under
  the mouse. Its **Depth** is in the Inspector (Floods): from 1.3 m you
  swim, and from 3 m a tunnel's flooded to its roof, so you swim through
  holding your breath (25 seconds; then you drown, losing health). Zombies
  that wade in deep drown. Floods can't be drained.

**Loot:**

- **Place locker** / **Place cache**: click a cell and a **miner's locker**
  (dynamite, batteries, food, ammo, now and then a lantern, a helmet lamp, a
  gas can or a pickaxe: the `miner` loot table) or a **supply cache**
  (dynamite, steel bars, scrap and sheet metal, gas cans, a lantern, shells:
  `mine_cache`) goes against its wall. Right-click removes the one under the
  mouse.
- **Scatter Loot** (the mine, in the Inspector): how many it puts in by
  itself, lockers and caches turn about, in its dead ends first, then round
  its chambers. The same places every time, until you change the layout.

**Zombies:**

- **Place zombies**: click a cell for a **ZombieSpawn** marker (3 zombies;
  its **Count**, **Chance** and **Spread** are in the Inspector). In a new
  game they turn up on the mine's open floor within Spread of it: never in
  rock, in the daylight by an entrance, in a cave-in or under a flood.
  Right-click removes the marker under the mouse.
- **Zombie Density** (the mine, in the Inspector): zombies it fills itself
  with, per 100 m of its tunnels and chambers.
- Down a mine, about 6 in 10 are **miners**: tougher than a walker, with a
  hard hat that the first headshot only knocks off, and a lamp still
  glowing on it, so you see them coming. Miners are only ever in mines.
  The rest are the usual kinds. They're there once each new game: cleared
  stays cleared.

Mines are where to find **dynamite** (light it and throw it, or crouch to
set it down on an 8 second fuse; within 6 m it kills zombies, blows cave-ins
clear, wrecks your own fences and barricades, and hurts you too), the
**helmet lamp** (put it on in your backpack: the flashlight key then switches
it; brighter, and its batteries last twice as long), **lanterns** (hold one
for light all round you, or set it down and pick it up again; it never runs
out) and **steel bars**.

Anything you put under the mine node (crates, lockers, carts of your own) is
drawn in the dark with it, and so are you, zombies and lanterns while they're
down there.

The older **New mine entrance** (Fields and features) is still there: a
single short tunnel that ends in a cave-in.

---

## 10. Buildings on hills

Buildings are made the same way as before (see `HOW_TO_BUILD.md`): Map Tools'
**New building**, or drag one from `world/kit/pieces/` onto the map's
**Buildings** node. Any shape stands on its foundation the same way.

On a slope:

1. Put the building's node at the height of the **highest** ground under it
   (move it up until no part of its floor is underground).
2. Choose its **Foundation** in the Inspector: *Concrete block* (most
   houses), *Stone* (old farmhouses, churches) or *Wooden posts* (cabins,
   porches, trailers).
3. The foundation fills down to the ground all round by itself, and follows
   the building when you move it.

Or flatten a pad first with the **Height** tool and skip the foundation.

---

## 11. The edge of the map

There are no invisible walls. The edge is up to you:

- **Steep ridges** (past 45 degrees) nobody can climb.
- **Thick forest** with fallen logs and rocks.
- **Rivers** (deep creeks) zombies can't cross, and you can only swim.
- **Blocked roads:** wrecked cars, a collapsed bridge (a road span with the
  deck missing...), barricades.

Past the edge, the land carries on as low-detail hills to the horizon (you
can't go there). They're set on the **Terrain** node's material, in the
Inspector under **Material > Shader Parameters**: **World Noise Height** (how
tall: times 10 meters, so 18 is about 180 m) and **World Noise Scale** (how
big the hills are).

If someone does slip past the edge they fall, and are put back on the last
solid ground they stood on. Zombies that fall out just die.

---

## 12. Putting the story back: markers

The old town's story places, people and spawn points went with it. Place
markers on the new map (drag them from `world/markers/` onto the
**Markers** node) and each system starts working again. `HOW_TO_BUILD.md`
(Markers) explains each marker's settings.

| What | Marker or setting | Without it |
|---|---|---|
| Where you start | SpawnPoint, role **player** (there's one at the middle of the map) | you start in the middle |
| The Quartermaster (trader) | SpawnPoint, role **trader** | no shop |
| The Police Chief | SpawnPoint, role **chief** | the story stops at "Talk to the Police Chief" |
| Bandits | SpawnPoint, role **bandit** (under the camp node) | none |
| The woodworker | SpawnPoints **woodworker_captive** and **woodworker_home** | he stands in the middle of the map |
| The wagon trader | SpawnPoints **wagon** and **wagon_trader** | the wagon turns up in the middle |
| Survivors | SpawnPoint **survivor** (in their house), with Person set. Optional: **survivor_home** for their own spot at the police station | they're missing (without a survivor_home they stand round their camp) |
| Bodies at the safe house | SpawnPoint, role **corpse** | none |
| Zombies at the start | ZombieSpawn markers | only the ones scattered around |
| Story places | Place markers named **Safe House**, **Gas Station**, **Grocery Store** | quest steps there can't be reached |
| The police station camp | **Map Tools > Police station camp**: a Base Camp marker in the station, with its **Logbook**, **Board** and **Crate** markers dragged where they go | the camp is wherever you start, with no logbook, board or supply crate |
| Zones (named areas) | **Map Tools > New zone**, then draw its outline (below) | no zone names |
| Reaching the safe house | an Area3D in the group **safe_house_trigger** | that story step never happens |
**Zones** are named areas: a hollow, a town, a farm. Walking into one shows
its name, and the map screen outlines them when you turn that on (interact
while the map is open). They're just names: nothing else depends on them.
To make one:
1. Press **Map Tools > New zone**.
2. In the Inspector, type its **Zone Name**.
3. Turn on **Draw points** and click its corners on the ground, all the way
   round. It closes itself, and right-click removes the last corner.
4. Drag the points to reshape it any time.

**The police station camp** is the base you start with:
- Its logbook saves and loads the game.
- Its bulletin board shows who lives there.
- Its supply crate fills with food and ammo each morning.
- The wagon trader comes once you've killed 75 zombies within 75 m of it.

Put one marker in the station (**Map Tools > Police station camp**), then drag
its three child markers where you want those things. Other camps are built in
the game, from the woodworker's camp kit.

The station's old fixed guards are gone. You post your own survivors on guard
posts you build instead.

---

## 13. How the land plays

| | You | Zombies |
|---|---|---|
| Uphill | slower: half speed on a 45 degree slope | slower still: 30% speed at 45 degrees |
| Steeper than 45 degrees | can't climb (you slide back) | can't climb |
| Shallow water (25 cm to 1.3 m) | wade at 60% speed | 40% speed |
| Deep water (1.3 m or more) | swim slowly, no guns; crouch dives, jump comes up | sink, and drown after 4 seconds |
| Head under water | 25 seconds of breath, then you drown (10 health a second); it comes back three times as fast | (drowned already) |
| Crops and bushes | crouch in them to hide | can't see you unless right next to you |
| Trees | solid trunks block you and bullets, and block sight | the same |
| Hills | block sight | the same |
| Falling | nothing up to 4 m, then it hurts more the further you fall; 12 m kills | the same |

Where to change the numbers:
- You: `characters/player/player.tscn`, root node, Inspector, **Movement**
  (Slope Slowdown, Wade Speed Factor, Swim Speed).
- Zombies: the constants at the top of `characters/zombie/zombie.gd`
  (SLOPE_SLOWDOWN, WADE_FACTOR, DEEP_FACTOR, DROWN_SECONDS).
- Water depths: `world/water.gd` (WADE_DEPTH, SWIM_DEPTH).
- Breath: the constants by `breath` in `characters/player/player.gd`
  (BREATH, DROWN_DAMAGE, BREATH_BACK).
- Falls: `characters/fall.gd` (SAFE, DEADLY). Landing in water, holding on
  to a ladder or riding a mine's cage down never hurts.

Zombies find their way with the **navigation mesh**: a map of where they can
walk, worked out from the ground and everything solid on it. The game works
it out by itself every time it starts (tile by tile, on all the processor's
cores), so you never need to bake it. Deep water and slopes past 45 degrees
are left out of it.

---

## 14. Real textures instead of the placeholders

Free, good textures (the license is CC0: use them for anything):
[ambientCG](https://ambientcg.com) and [Poly Haven](https://polyhaven.com/textures).
Search for "forest floor", "gravel", "mud", "plowed", "dirt", "clay",
"riverbed". Download the **1K** or **2K** PNG version.

Terrain3D wants each texture as **two files**: one with the color and the
height together, one with the normal map and the roughness together. It
packs them for you:

1. Unzip the download somewhere inside the project, e.g. a new folder
   `world/map/textures/downloads/`.
2. Select the **Terrain**. At the top of the 3D view, open the **Terrain3D**
   menu > **Pack Textures**.
3. Pick the **Color** (or Albedo / Diffuse) image and the **Height** (or
   Displacement) image. Then the **Normal** image (choose the *GL* one if
   there are two; or tick *Convert DirectX to OpenGL* for a *DX* one) and
   the **Roughness** image.
4. **Pack Textures As...** and save into `world/map/textures/`, e.g.
   `gravel_real`.
5. In the FileSystem dock, select each new PNG, open the **Import** tab (next
   to Scene, top left) and set: **Mode: VRAM Compressed**, **High Quality:
   On**, **Normal Map: Disabled**, **Mipmaps > Generate: On**. Click
   **Reimport**.
6. Select the Terrain. In the asset dock (**Textures**), right-click the
   placeholder you're replacing (or click its pencil), and in the Inspector
   drag your two files onto **Albedo Texture** and **Normal Texture**.

**All the textures must be the same size** (the ones here are 1024 x 1024)
and the same import settings, or the ground turns white. Resize big
downloads in any image editor, or download the 1K version.

**Mipmaps** are what make textures stay sharp up close but cheap and smooth
far away (the graphics card uses smaller copies at a distance): that's the
"Mipmaps > Generate" setting, and it's why distant ground doesn't shimmer.

**UV Scale** (in each texture's settings) is how big it's drawn: smaller
numbers make it bigger. **Albedo Color** tints it (the grass and rock are
tinted a little greener and greyer than the originals).

---

## 15. Keeping it fast

Your laptop (GTX 1050 Ti) handles this map comfortably as it is: a heavily
forested map (about 65,000 plants) draws about 1 million triangles in about
800 batches from inside the woods. Press **F3** in the game to see the
numbers yourself (frames per second, and which part is slowest).

Towns are kept cheap when a game starts, on their own:
- Buildings, walls and furniture that never change are merged into a few big
  meshes per 48 m patch of map, and a patch isn't drawn at all past about
  700 m (the fog has hidden it by then; View Distance scales that).
- Every piece of furniture, door and window is turned into one mesh (a
  stand-in is dozens of little boxes), and the same ones nearby are drawn
  together (GPU instancing).
- Buildings hide what's behind them (occlusion culling): their walls, floors
  and roofs, not their windows or doorways.

Zombie crowds are kept cheap too (`world/zombies.gd`): far ones think less
often and follow their paths without physics, and past 120 m, out of sight,
they're only data that keeps walking until you come back within 100 m. On
this map, 400 zombies cost about 10 ms of processor time a frame (13 ms with
80 of them on top of you), against 14-15 ms before.

Measured in a test town of 80 furnished buildings: from about 15,500 draw
calls to about 1,300-1,900 from inside it (fewer close to buildings, where
occlusion culling helps most), and about 2.5 ms more processor time per frame
than the empty map (60 fps leaves 16.7 ms). A map can hold several towns that
size without needing to load and unload parts of it.

If it slows down:
- **Plant view distance** (each plant file's View Distance): ferns and bushes
  far away cost a lot and nobody sees them. Lower it first.
- **Forest density:** 2 to 3 looks like forest; 5+ costs much more for
  little difference.
- **Crop fields:** a big field is thousands of plants. Fewer, smaller fields,
  or wider Plant Spacing.
- **Settings > Graphics** in the game: shadows, view distance, resolution,
  and hiding what's behind buildings (occlusion culling).
- Real tree models later need *levels of detail* (simpler versions for far
  away): that comes with the models work.

---

## 16. When something goes wrong

- **The ground is all white:** a texture in the list has a different size or
  import settings than the others (section 14, step 5 and the size rule).
- **A road or creek floats or is buried:** press **Apply** on it again
  (after re-sculpting the ground under it, it needs re-applying).
- **I sculpted over a road:** Apply the road again; it re-cuts the ground.
- **Zombies walk through a wall / can't get somewhere:** walls need collision
  (kit pieces have it). Slopes past 45 degrees and deep water are deliberately
  off-limits.
- **Map Tools doesn't react in the 3D view:** select the road/creek/field you
  want to draw (Draw points), or pick a brush (plants). If the panel is
  missing: Project > Project Settings > Plugins, and make sure **Map Tools**
  and **Terrain3D** are enabled.
- **A mine's tunnel shows through the hill, or there's a hole in the
  ground beside it:** the ground there is within a meter of the tunnel's
  ceiling. Raise the hill over it (or lower the mine a level) and Apply again.
- **I can't get into a mine:** the ground where the floor ends outside an
  entrance must be level with the floor (section 9, step 6). Apply again.
- **The terrain didn't save:** it saves with Ctrl+S on the map scene. Saved
  tiles are listed in the Output panel.
- **"... has no save ID" or "... share the key"** (a test, or a warning when
  the game starts): open the scene it names in the editor and save it; that
  gives out the missing and duplicated IDs.
- **The first time the project opens** Godot sets up the Terrain3D plugin; if
  it asks to restart the editor, let it.
