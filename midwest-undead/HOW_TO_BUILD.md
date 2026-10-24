# How to build buildings and towns

Buildings, furniture, containers and markers go on the map,
`world/map/map.tscn`, which you edit in the Godot editor. Everything you place
is exactly where the game puts it. Only what's in the containers (on top of
their fixed items), which zombies turn up, and the trader's restocks are random.

- `world/map/map.tscn` is the whole world: the terrain and everything on it.
  `HOW_TO_MAP.md` covers the land itself: hills, roads, creeks, forests,
  fields.
- `world/kit/` is the building kit: pieces, furniture, materials.

Save with Ctrl+S, then press F5 and start a new game to try it.

## Adding a building

The quickest way: open the map, then in the **Map Tools** panel (along the
bottom, next to Output) click **Buildings > New building**. It adds a
10 x 10 m building with a door and windows in front of the camera. Or pick a
ready-made one from **New from template** (Template, below). Or:

1. Open the map. In the FileSystem dock, drag
   `world/kit/pieces/building.tscn` (a shop) or `two_storey_house.tscn` into
   the 3D view, onto the map's **Buildings** node.
2. Move it with the move gizmo (W) and turn it with the rotate gizmo (E). The
   **front** is the side with the door: the building's local -X side. Turn it
   so the front faces the street. Turn on snapping (the magnet in the toolbar)
   to rotate in exact 15° steps.
3. Select it and use the Inspector. It rebuilds as you change things.

**Template**

Ready-made buildings to start from, three variants each:
- Homes: **Farmhouse** (two storey with a porch; one storey; two storey with a
  wraparound porch and a cellar), **Ranch house** (with an attached garage,
  without, or with a garage and a basement), **Cottage**, **Trailer**
  (single-wide, double-wide, with an awning).
- Town: **Corner store** (small; large with an office; two storey with an
  apartment upstairs), **Gas station** (with a canopy and pumps out front),
  **Diner**, **Church** (a chapel, or with a steeple), **School** (one room,
  two classrooms, four; a flagpole and a playground outside), **Police
  station** (small, with a cell block, two storey).
- Farm: **Barn** (gambrel with a hayloft, gable with a workshop, a small
  shed), **Machine shed** (open front, garage doors, large).

Pick **Template** and **Variant** and press **Apply Template**: every setting
below is replaced (doors, windows, inner walls, rooms with their Kind,
stairs, porches, roof, materials...), and things outside it from a template
before (a canopy, a sign, a steeple...) and the furniture Furnish Rooms put
in are taken out. Your own children of the building stay. **Random Colours**
picks the outside's material at random from ones that suit it. Ctrl+Z undoes
it. After that it's an ordinary building: change anything. Press **Furnish
Rooms** (Rooms, below) to fill it.

The template's outside things are ordinary children of the building: signs
(**KitSign**: change **Text**), the steeple (**KitSteeple**), the canopy (boxes),
pumps, flagpole and playground (furniture). Move or delete them like anything
else.

A **silo** isn't a Building: Map Tools' New from template adds one
(**KitSilo**: round, a door on its -X side, a ladder up the inside to a hatch
in its dome, which you can stand on). Set its **Radius**, **Height** and
materials in the Inspector.

**Size**
- **Size Depth / Size Width:** how far back from the front it goes, and how
  wide the front is (meters), for a rectangle.
- **Footprint:** any other shape (an L, a T, a U, angled corners): its corners
  in order round the outside. Draw it with Map Tools (below). Empty: the
  rectangle. **Outline From Size** turns the rectangle into a Footprint, to
  move its corners.
- **Floors:** floors you can walk around on. A rectangle with no Stairs gets
  a staircase along a side wall for each floor above the ground, alternating
  sides going up (about 8.5 m of depth needed). A drawn shape needs its stairs
  placed (Stairs, below). If something doesn't fit, a warning icon shows next
  to the building in the Scene dock. Hover over it to read why.
- **Floor Y:** use 0.1 when the building stands on a sidewalk, so you step
  straight in. Use 0.02 on bare ground.
- **Foundation:** on a hillside, put the building's node at the height of the
  highest ground under it; it stands on a foundation down to the ground all
  round: Concrete block, Stone, or Wooden posts (`HOW_TO_MAP.md`, section 10).
- **Basement:** a floor under the ground floor (floor -1), 2.8 m down, with
  block walls and a concrete floor. It's dark down there (bring a
  flashlight): only what comes down the stairs or in at a cellar door lights
  it. Reach it with stairs placed on floor -1 (they climb to the ground
  floor) and/or cellar doors (Outside, below). Inner walls and rooms can go
  on floor -1 too. The ground has to be opened for it: select the building
  and press **Apply** in Map Tools (Selected). Press it again after moving
  the building or changing its outline or cellar doors (Ctrl+Z undoes it).
  Put basements on fairly level ground.
- **Upper Height:** a solid block over the top floor that you can't enter,
  with painted-on windows. This is how the Main Street shops look taller than
  they are. Leave it at 0 for a roof straight over the top floor (a pitched
  Roof sits on top of the block when there is one).

**Openings**

The doors, doorways and windows. Click **Default Openings** to start from a
front door and a few windows on every floor (Ctrl+Z undoes it). Click an
opening in the list to change it:

- **Wall:** front, back, left or right, seen from outside (a rectangle).
- **Edge:** a drawn shape's wall, by its number (shown over the walls while
  the building is selected; the first wall you drew is 0, the front). -1: use
  Wall.
- **Kind:** window, door, doorway (an open gap with no door), or garage
  door: a door that tips up into the ceiling, on the ground floor of an
  outside wall (2.8 m wide is one car, 5 m two). You open and shut it;
  zombies can't break it and only get past it while it's open; it can't be
  boarded up. A detached garage is a small building of its own with one
  (and a concrete floor: Floor Material, or Paint room).
- **Level:** which floor it's on. 0 is the ground floor.
- **Offset:** where its middle is along the wall, from the wall's middle.
  Positive is to the right, seen from outside.
- **Width, Bottom, Top:** its size. Bottom and Top are meters above that
  floor. A door's Bottom is 0. Doors and doorways need to be at least 1.6 m
  wide or zombies can't find their way through them (a warning says so).
- **Boarded Up:** nailed shut for good (wood, no glass).
- **Boarded At Start:** planked shut when a new game starts, like the
  survivors' houses. The player can pull the planks off.
- **Door > Start Open, Door Color:** for doors.

**Models > Door Models, Window Models:** what its doors and windows look like
(stretched to each opening); empty uses `world/props/door.tscn` and
`window.tscn`. See `HOW_TO_MODEL.md`, "Props".

Only ground-floor doors and windows can be planked up by the player. Zombies
can smash ground-floor windows and climb in.

**Stairs:** the flights between floors. Each has a **Level** (the floor it
starts on; it climbs to the next), a **Start** (where its bottom step's middle
is: x back from the front, y along the front) and a **Direction** (0 climbs
straight back, 90 toward the building's +z side). It needs its length (5.8 m
for one storey) plus 1 m of floor past the top inside the building. The floor
above gets a hole and a railing round it. **Stairs Side:** for a rectangle
with no Stairs, which side wall the first staircase runs along.

**Rooms**
- **Inner Walls:** walls inside, each on one floor (**Level**), from
  **Start** to **End** (the building's own meters), floor to ceiling. Each
  has its own **Openings**: doorways, doors and windows like the outside
  walls' (**Offset** from the wall's middle, + toward End; Wall and Edge
  don't matter). Inner doors and windows can't be boarded up. The spaces the
  walls close off are rooms; start and end each wall on an outside wall or
  another inner wall to close one off.
- **Rooms:** give a room its own **Wall Material** (its walls' inside faces)
  and **Floor Material**, and its **Kind**. A room is the space round its
  **Point** on its floor, as far as the walls (a doorway doesn't join two
  rooms). Empty materials use the building's.
- **Kind:** what the room is for: home rooms (bedroom, kitchen, living room,
  dining room, bathroom, laundry, garage, basement storage), town rooms
  (store floor, stockroom, office, diner seating, diner kitchen, sanctuary,
  classroom, police office, cells, restroom) and farm rooms (barn stalls,
  hayloft, workshop, machine bay).
- **Furnish Rooms:** puts furniture in every room with a Kind: a bed,
  nightstand and dresser in a bedroom, a fridge, stove, sink, cabinets and a
  table with chairs in a kitchen, pews in rows facing an altar, booths along
  a diner's walls... Pieces go against walls with their backs to them, keep
  out of doorways and off the stairs, and aren't taller than a window's sill
  in front of a window. Rows face the room's front: the wall furthest from its
  doors to outside. The pieces are ordinary children of the building: move,
  change or delete any of them. Press it again and it takes out what it put
  in (only that) and furnishes afresh; Ctrl+Z undoes it. The same room comes
  out the same every time; move its Point for another arrangement.
  Containers it puts in hold what suits the room (below).

**Outside**
- **Porches:** a porch along one or more outside walls, at the ground
  floor's height (so with Floor Y 0.4 or so it's a raised porch with steps).
  - **Walls:** the walls it runs along, by number. Two or more, one after
    another round the building (`[0, 1]`), and it wraps round the corner.
  - **Length / Offset:** on one wall, how long it is (0 = the whole wall)
    and where its middle is from the wall's middle (like an opening).
  - **Depth:** how far out it comes.
  - **Kind:** **Roofed** (a roof on posts, a railing), **Open** (a deck or
    a stoop: no roof) or **Screened** (roofed, with screens all round and a
    screen door at the steps; zombies can't get through the screens, but
    can bash in the screen door, which can be boarded up).
  - **Railing:** round the edge, except at the steps.
  - **Steps Wall / Steps Offset:** which of its walls the steps come off,
    and where along it (from the wall's middle); -1 for none.
  A porch roof sits under the house's eaves; a warning says if it's too
  low over the deck (a deep porch on a high floor), or if a door or window
  behind it is taller than the roof.
- **Cellar Doors:** storm-cellar doors outside, for a building with a
  Basement: a slanted door over steps down beside a wall (**Wall**, by
  number, and **Offset** along it), into a doorway in the basement wall,
  with a concrete pad round it. It opens and shuts like a door; zombies can
  bash it in, and it can be boarded up. Press Apply after adding one.

**Roof**
- **Roof Shape:** Flat, or a pitched roof worked out over the whole outline:
  **Gable** (two slopes, a triangle of wall at each end), **Hip** (sloped on
  every side), **Shed** (one slope) or **Gambrel** (a barn roof: steep lower
  slopes, gentler upper ones). An L, T or U gets a roof per wing, meeting in
  valleys. Pitched roofs need every wall of the outline to run straight back
  or straight across (right angles, as Draw outline makes them without
  Shift); an outline with an angled wall gets a flat roof and a warning.
- **Roof Pitch:** how steep, in degrees from flat (35 is a typical house; a
  gambrel's upper slopes are gentler than this, its lower ones steeper).
- **Roof Overhang:** how far the eaves stick out past the walls (meters).
- **Shed Slopes To:** for a Shed roof, the side it slopes down to. Steep shed
  roofs over a wide building get very tall on the high side: use a low pitch
  (10 to 20).
- **Attic:** **Closed** (no way in), or **Walk-in**: the ceiling of the top
  floor becomes an attic floor. Place a flight on the top floor (Level =
  Floors - 1) to reach it. Put it under the ridge, the middle of the roof,
  where there's headroom: near the eaves the roof comes down to the floor,
  and a warning says when the top of the stairs is too low to stand. A
  walk-in attic needs Upper Height 0.
- **Chimneys:** brick chimneys from the ground up through the roof, to 0.8 m
  above its peak. Each has a **Position** (x back from the front, y along the
  front) and a **Size**.
- **Dormers:** little gabled bumps with a window, each on the slope nearest
  its **Position**, set near the eave; **Width** sets its size. The window is
  to look at, there's no way in. Not on Shed roofs.

You can stand and walk on a pitched roof; past 45° it's too steep to stand
on and you slide off.

**Drawing it: Map Tools > Buildings**

Select the building, then pick a tool. Clicks land on the building's floor
(the Floor box picks which: -1 is the basement), so a view from above works
best.
- **Draw outline:** click its corners, going round (it closes itself). The
  first click starts a new outline. Corners snap to a 0.5 m grid and each wall
  turns at a right angle to the last; hold Shift for any angle. Right-click
  takes back the last corner. Then use **Default Openings** for a door in
  wall 0 and windows, or add your own.
- **Draw inner wall:** click one end, then the other (right angles; Shift
  for any; ends on the 0.5 m grid). Right-click on one removes it.
- **Paint room:** click inside a room: it's marked and opens in the
  Inspector to set its materials (click a marked room to open it again).
  Right-click removes the mark.
- **Place stairs:** click where the bottom step goes, then click the way it
  climbs (right angles; Shift for any). It climbs from the Floor set in the
  panel. Right-click on a flight removes it.
- **Add door / window / doorway:** click on a wall, outside or inner, where
  it goes, on the Floor set in the panel. Right-click on one removes it. Change its size in
  the Inspector (Openings).
- **Add garage door:** click on an outside wall where it goes (ground
  floor).
- **New from template** (not a tool: a list): adds a ready-made building, or
  a silo, in front of the camera.
- **Furnish rooms** (a button): the selected building's Furnish Rooms.
- **Place chimney / Place dormer:** click where it goes; clicks land at the
  top of the walls. A dormer needs a pitched Roof Shape; click near the edge
  of the roof, and it sits on the nearest slope. Right-click on one removes
  it.
- **Add porch:** click on a wall: a roofed porch along it, opened in the
  Inspector to set its kind, depth and steps. Click the next wall round from
  a porch to wrap the porch round the corner onto it. Right-click on a
  porch's wall takes that wall off it (from either end), or removes it.
- **Add cellar door:** click on a wall where it goes (turn on Basement
  first), then press Apply. Right-click on one removes it.
- **Apply** (Selected): opens the ground under its basement and cellar
  doors (or closes it again, with no basement).
Everything can be undone (Ctrl+Z).

**Materials:** exterior, interior, floor, ceiling, roof. Drag a material from
`world/kit/materials/` onto a slot (see Materials below). An empty slot uses
the kit's default.

## Furniture and containers

Drag pieces from `world/kit/furniture/` onto the building, so they're its
children and move with it. Furniture pieces stand on the spot you drop them
(their **Sits On Floor** is on).

The pieces: bed, nightstand, dresser, couch, armchair, chair, coffee table,
table, TV, bookcase, desk, fridge, stove, sink cabinet, kitchen cabinet,
counter, toilet, bathtub, bathroom sink, washer, workbench, filing cabinet,
gun locker, shelf, grocery shelf, school desk, chalkboard, pew, altar, booth,
stool, cell bars, hay bale, feed trough, tractor, gas pump, flagpole, swing
set, slide, cardboard boxes, supply crate, dumpster, car. Chairs, stools,
school desks, the flagpole and the playground pieces aren't solid (you walk
through them), so rooms full of them don't block anyone's way.

Containers are the counter, shelf, grocery shelf, kitchen cabinet, dresser,
nightstand, fridge, sink cabinet, bathroom sink (its medicine cabinet),
workbench, filing cabinet, gun locker, feed trough, dumpster, cardboard boxes,
supply crate and car. A container has:

- **Label:** what the prompt calls it. Salvaging with the crowbar goes by the
  label (the list is in `world/salvage.gd`): wooden furniture gives plywood or
  planks, a car, fridge, stove, washer, filing cabinet, gas pump or tractor
  scrap metal.
- **Fixed Items:** always in it. Add an entry; the key is an item id (the
  files in `items/data/`: `canned_food`, `health_pack`, `pistol_ammo`,
  `planks`, `crowbar`, ...), the value is how many.
- **Loot Table:** random extras every new game. `none` means just the fixed
  items. The list shows every table in `items/loot/`; see `HOW_TO_ADD.md` to
  change one or make a new one. Furnish Rooms gives a container whose table
  is `standard` its room's instead: `kitchen` (food), `bathroom` (first aid),
  `bedroom`, `office`, `workshop` (materials), `police` (ammunition and guns),
  `farm`, `grocery` or `snack`. A fridge, medicine cabinet, gun locker,
  workbench and the like have their own table already.
- **Look > Size, Material:** any size, any material.
- **Model > Models:** what it looks like (a shaped stand-in to start with),
  stretched to its Size; see `HOW_TO_MODEL.md`, "Props". Empty: a plain box in
  its Material.

A **bed** can be stripped for plywood because of its metadata `salvage_label`
(Inspector, bottom). Give any box that metadata (value "Bed", or another label
from the list in `world/salvage.gd`) to make it strippable.

## Odd shapes: the modular pieces

For what a Building can't do (an L-shaped store, a back room, a garage), build
from pieces in `world/kit/pieces/`. Turn on snapping, and set the snap step in
the toolbar's Transform menu > Configure Snap (0.1 or 0.2 works well).

- **wall.tscn (KitWall):** one straight wall of any length and height, with
  doors, doorways and windows like a building's. It starts at the node and runs
  along +Z. It's 0.2 m thick, and its outside faces -X.
- **floor.tscn (KitFloor):** a slab for a floor, ceiling or flat roof. Its top
  is at the node, and it reaches along +X and +Z from that corner.
- **stairs.tscn (KitStairs):** climbs `Rise` meters along +X. Keep it 1.6 m
  wide, or zombies can't path up it. Leave a hole in the floor above it, and
  put a railing round the hole.
- **box.tscn, fence.tscn (KitBox):** a plain solid box: fences, counters,
  poles, roads. Untick **Solid** for decoration you can walk through.

## Materials

`world/kit/materials/` holds the starter looks: bricks, siding, stone,
concrete, plaster, floorboards, ceiling tiles, asphalt, sidewalk, grass,
plywood, metal, car paint and more. They're drawn from numbers, not images,
and laid out in world space, so they tile evenly on a piece of any size.

**One material is shared by everything that uses it.** Changing
`brick_red.tres` changes every red-brick building. For a one-off change,
right-click the material in a slot and choose **Make Unique**. Or duplicate the
file in the FileSystem dock and change the copy.

To make a new pattern, duplicate one of the `.tres` files and change its
settings in the Inspector:

- **Pattern:** 0 plain, 1 bricks, 2 siding, 3 tiles, 4 floorboards,
  5 stone blocks, 6 shingles.
- **Color, Joint Color:** the main color and the mortar/groove color.
- **Cell:** one brick or board, in meters (across, up).
- **Joint:** the joint width, in meters.
- **Variation:** how much each brick or board differs from the next.
- **Grime:** dirt and weathering.

To use a real texture:

1. Duplicate `your_texture_template.tres`.
2. Set **Albedo > Texture** to your image.
3. Set **UV1 > Scale** to 1 divided by the size the image covers in meters.
   For example, a 2 m by 2 m brick photo gets 0.5, 0.5, 0.5.
4. Optionally add a normal map under **Normal Map**.

The template uses world triplanar mapping, so like the starter materials it
tiles at any size. Custom 3D models come later.

## Markers

Drag these from `world/markers/` (or add them as nodes: KitSpawnPoint,
KitZombieSpawn, KitPlace; zones and the police station camp come from the Map
Tools panel) onto the map's **Markers** node (or under the building or camp
they belong to). In the editor each one shows a floating
label. `HOW_TO_MAP.md` (section 12) lists which ones the story needs.

- **SpawnPoint:** where someone starts, facing the marker's forward (-Z).
  **Role** picks who:
  - player: where you start (the first one).
  - guard: an old-style fixed guard (the old police station had them). Put it
    under its guard tower node. Watch From and Watch To are the ends of the
    stretch of road it shoots zombies on. The new map doesn't use any: you post
    your own survivors on guard posts you build instead.
  - bandit: put it under the camp node. Bandits stay near the camp node's
    position.
  - survivor: put it inside a house (as a child of the Building). Person must
    be a survivor's name (their file in `characters/npcs/survivors/`; see
    `HOW_TO_ADD.md`).
  - survivor_home: optional. Their own spot at the police station camp (same
    Person). Without one they stand round their camp.
  - corpse: a body lying there, in Outfit Color.
- **ZombieSpawn:** when a new game starts, each of **Count** zombies turns up
  with **Chance**. **Spread** scatters them in a box around the marker.
- **Place:** a named place on the map. **Kind** is discoverable (found by
  coming within Radius of the marker) or street (a street name, always shown).
  (Quests use quest markers instead: below.)
- **Zone:** a named area, drawn as an outline (Map Tools > New zone, then Draw
  points). Walking in shows its name.
- **Base Camp:** the police station's camp (Map Tools > Police station camp).
  Drag its Logbook, Board and Crate child markers to where those go.
- **Person:** someone from a person file (Map Tools > Quests > New person):
  the Chief, the Quartermaster... **Captive** ties them to a post until you
  untie them.
- **Quest marker:** a spot, area or usable thing quests point at by its
  Marker Id (Map Tools > Quests > New quest marker).

## Things the game relies on

- **Zombies can walk anywhere on the map** that's not too steep (past 45
  degrees), not under deep water, and not blocked by something solid. Where
  they can walk (the navigation mesh) is worked out when the game starts
  (`world/nav_tiles.gd`), so there's nothing to bake by hand.
- **Groups mark a few special things** (Node dock > Groups):
  - `map_road`: drawn as road on the map screen.
  - `map_fence`: drawn as the compound fence.
- **Saves find things by their save id** (given out when you save the map in
  the editor: `HOW_TO_MAP.md`, section 12), so renaming or moving something
  keeps older saves working.
- **Buildings and modular pieces are merged when a game starts.** To keep the
  game fast, every Building and modular piece (wall, floor, stairs, box) is
  combined into a few big meshes by material (`world/static_merge.gd`). This
  doesn't change anything in the editor, and their collision stays as it was.
  Anything that has to change or move during play can't be one of these
  pieces: containers, doors, windows and items stay separate, and so does
  anything with a `salvage_label`.
- **Small things stop being drawn far away**: containers, items on the
  ground, windows, doors and the boards over them. The bigger a container,
  the further it shows (`core/view_distance.gd`). The View Distance setting
  scales them all.
