# How to build the town

The town is a set of scenes you edit in the Godot editor. Everything you place
is exactly where the game puts it. Only what's in the containers (on top of
their fixed items), which zombies turn up, and the trader's restocks are random.

- `world/town/town.tscn` is the whole town. It's made of districts.
- `world/town/districts/*.tscn` holds one area each (Main Street, the police
  station, ...). Open a district to work on that area. It's smaller and
  quicker than the whole town.
- `world/kit/` is the building kit: pieces, furniture, materials.

Save with Ctrl+S, then press F5 and start a new game to try it.

## Adding a building

1. Open a district. In the FileSystem dock, drag
   `world/kit/pieces/building.tscn` (a shop) or `two_storey_house.tscn` into
   the 3D view, onto the district's root node.
2. Move it with the move gizmo (W) and turn it with the rotate gizmo (E). The
   **front** is the side with the door: the building's local -X side. Turn it
   so the front faces the street. Turn on snapping (the magnet in the toolbar)
   to rotate in exact 15° steps.
3. Select it and use the Inspector. It rebuilds as you change things.

**Size**
- **Size Depth / Size Width:** how far back from the front it goes, and how
  wide the front is (meters).
- **Floors:** floors you can walk around on. Each floor above the ground gets
  a staircase along a side wall, alternating sides going up.
  A staircase needs about 8.5 m of depth. If it doesn't fit, a warning icon
  shows next to the building in the Scene dock. Hover over it to read why.
- **Floor Y:** use 0.1 when the building stands on a sidewalk, so you step
  straight in. Use 0.02 on bare ground.
- **Upper Height:** a solid block over the top floor that you can't enter,
  with painted-on windows. This is how the Main Street shops look taller than
  they are. Leave it at 0 for a flat roof.

**Openings**

The doors, doorways and windows. Click **Default Openings** to start from a
front door and a few windows on every floor (Ctrl+Z undoes it). Click an
opening in the list to change it:

- **Wall:** front, back, left or right, seen from outside.
- **Kind:** window, door, or doorway (an open gap with no door).
- **Level:** which floor it's on. 0 is the ground floor.
- **Offset:** where its middle is along the wall, from the wall's middle.
  Positive is to the right, seen from outside.
- **Width, Bottom, Top:** its size. Bottom and Top are meters above that
  floor. A door's Bottom is 0.
- **Boarded Up:** nailed shut for good (wood, no glass).
- **Boarded At Start:** planked shut when a new game starts, like the
  survivors' houses. The player can pull the planks off.
- **Door > Start Open, Door Color:** for doors.

Only ground-floor doors and windows can be planked up by the player. Zombies
can smash ground-floor windows and climb in.

**Stairs Side:** which side wall the first staircase runs along.

**Materials:** exterior, interior, floor, ceiling, roof. Drag a material from
`world/kit/materials/` onto a slot (see Materials below). An empty slot uses
the kit's default.

## Furniture and containers

Drag pieces from `world/kit/furniture/` onto the building, so they're its
children and move with it. Furniture pieces stand on the spot you drop them
(their **Sits On Floor** is on).

Containers are the counter, shelf, grocery shelf, kitchen cabinet, dresser,
dumpster, cardboard boxes, supply crate and car. A container has:

- **Label:** what the prompt calls it. Salvaging with the crowbar goes by the
  label: Car, Dresser, Kitchen cabinet, Counter, Shelf and Grocery shelf can
  be stripped.
- **Fixed Items:** always in it. Add an entry; the key is an item id (the
  files in `items/data/`: `canned_food`, `health_pack`, `pistol_ammo`,
  `planks`, `crowbar`, ...), the value is how many.
- **Loot Table:** random extras every new game. `none` means just the fixed
  items. The list shows every table in `items/loot/`; see `HOW_TO_ADD.md` to
  change one or make a new one.
- **Look > Size, Material:** any size, any material.

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
KitZombieSpawn, KitPlace). In the editor each one shows a floating label.

- **SpawnPoint:** where someone starts, facing the marker's forward (-Z).
  **Role** picks who:
  - player, trader, chief, wagon, wagon_trader, woodworker_captive,
    woodworker_home: the game uses the first marker it finds with that role.
  - guard: put it under its guard tower node (the tower's parts don't block
    its aim). Watch From and Watch To are the ends of the stretch of road it
    shoots zombies on.
  - bandit: put it under the camp node. Bandits stay near the camp node's
    position.
  - survivor: put it inside a house (as a child of the Building). Person must
    be a survivor's name (their file in `characters/npcs/survivors/`; see
    `HOW_TO_ADD.md`).
  - survivor_home: their spot in the station yard (same Person).
  - corpse: a body lying there, in Outfit Color.
- **ZombieSpawn:** when a new game starts, each of **Count** zombies turns up
  with **Chance**. **Spread** scatters them in a box around the marker.
- **Place:** a named place on the map. **Kind** is discoverable (found by
  coming within Radius of the marker) or street (a street name, always shown).
  The quest and the wagon trader use the "Safe House" and "Police Station"
  places.

## Things the game relies on

- **Zombies can only walk inside the navigation area:** x from -180 to 125
  and z from -90 to 90. Build outside it and zombies can't reach it. To make
  it bigger, change `filter_baking_aabb` in `world/main.gd`
  (`_setup_navigation`).
- **Groups mark a few special things** (Node dock > Groups):
  - `map_road`: drawn as road on the map screen.
  - `map_fence`: drawn as the compound fence.
  - `base_supply_crate`: the container the base fills each morning.
  - `safe_house_trigger`: walking into it counts as reaching the safe house.
- **Saves find things by their path in the town scene** (district / building
  / name). Renaming or moving something to another parent means an older save
  won't find it.
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
