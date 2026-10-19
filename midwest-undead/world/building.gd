@tool
class_name KitBuilding
extends Node3D
## A building you can walk into, made from its settings: change its outline,
## floors, openings, stairs or materials in the Inspector (or draw them with
## the Map Tools panel's Buildings section) and it rebuilds right away, in the
## editor and in the game. See HOW_TO_BUILD.md.
##
## Local axes: x = 0 is the front wall (the street side) and +x goes into the
## building; z runs along the front; y is up from the ground. Its outline is a
## rectangle (Size) or any shape drawn as Footprint corners; every floor has a
## wall along each side of it, numbered from the first corner (a rectangle's
## front is 0, right 1, back 2, left 3), with the doorways and windows in
## Openings cut into them. Inner Walls split floors into rooms (with their own
## doors, doorways and windows), and Rooms give a room its own wall and floor
## materials. Floors above the ground are reached by the flights
## in Stairs (a rectangle with none gets one along a side wall per floor,
## alternating sides going up). Over the top floor: a flat roof, or a pitched
## one (Roof: gable, hip, shed or gambrel, worked out over the outline by
## world/kit/kit_roof.gd, with dormers and chimneys), with an attic under it
## you can climb into or not; and/or, with Upper Height, a solid block you
## can't enter, with painted-on windows.
##
## On uneven ground it stands on a foundation down to the ground all round
## (Foundation: concrete block, stone or wooden posts), made from the terrain
## under it; move it and the foundation follows. It can have a basement under
## the ground floor (level -1), reached by stairs inside or cellar doors
## outside, dark down there; Map Tools' Apply opens the ground for it. Outside
## it can have porches (Porches) and garage doors (an opening kind).
##
## What it makes (walls, floors, glass, doors) isn't saved in the scene: it's
## made fresh from the settings every time. Furniture, containers and markers
## you put under the building are yours and are saved as usual.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const Darkness := preload("res://world/darkness.gd")
const PorchBuilder := preload("res://world/porch_builder.gd")
const BuildingWarnings := preload("res://world/building_warnings.gd")
const Door := preload("res://world/door.gd")

const WALL := KitMesh.WALL
const STOREY := 3.6 # floor to floor: a 3.4 m room under a 0.2 m slab
## The ground floor's height on a sidewalk: you step straight in from it.
## (A building on bare ground uses 0.02: a 10 cm ledge at the door is a wall as
## far as walking is concerned.)
const SIDEWALK_FLOOR_Y := 0.1
const STAIR_WIDTH := 1.6 # wide enough that the navigation mesh fits a zombie up it
const STAIR_START := 1.5 # how far back from the front wall a rectangle's own staircase starts
const STAIR_RUN_PER_RISE := 1.6 # about 32 degrees
const LANDING := 1.0 # floor needed past the top of a staircase
const PAINTED_WINDOW := Vector3(0.04, 1.3, 1.1)
const PAINTED_SPACING := 2.6
## The narrowest door or doorway zombies can path through (the navigation mesh
## keeps 0.5 m from walls each side).
const MIN_PASSAGE := 1.6
## A rectangle's walls by name (KitOpening's Wall): their numbers.
const WALL_NUMBERS := {"front": 0, "right": 1, "back": 2, "left": 3}

const DEFAULT_EXTERIOR := preload("res://world/kit/materials/siding_white.tres")
const DEFAULT_INTERIOR := preload("res://world/kit/materials/plaster.tres")
const DEFAULT_FLOOR := preload("res://world/kit/materials/wood_floor.tres")
const DEFAULT_CEILING := preload("res://world/kit/materials/ceiling_tiles.tres")
const DEFAULT_ROOF := preload("res://world/kit/materials/roof_tar.tres")
const WINDOW_DARK := preload("res://world/kit/materials/window_dark.tres")
const BOARDS := preload("res://world/kit/materials/wood_planks.tres")
const FOUNDATION_MATERIALS := {
	"Concrete block": preload("res://world/kit/materials/concrete_block.tres"),
	"Stone": preload("res://world/kit/materials/stone_gray.tres"),
	"Wooden posts": preload("res://world/kit/materials/timber.tres"),
}
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const POST_SPACING := 2.5 # wooden posts: this far apart along each side
const KitRoof := preload("res://world/kit/kit_roof.gd")
const WindowLook := preload("res://world/props/window.tscn")
const CHIMNEY_MATERIAL := preload("res://world/kit/materials/brick_red.tres")
## The basement: its floor this far below the ground (the building's node), and its walls and floor.
const BASEMENT_DEPTH := 2.8
const BASEMENT_WALL := preload("res://world/kit/materials/concrete_block.tres")
const BASEMENT_FLOOR := preload("res://world/kit/materials/concrete_slab.tres")
## How dark it is down there: the ambient light a basement gets instead of the sky's.
const BASEMENT_DARK := Color(0.012, 0.012, 0.015)
## Cellar doors' steps: steeper than the stairs inside, with a landing at the bottom.
const CELLAR_RUN_PER_RISE := 1.3
const CELLAR_LANDING := 0.8
const CELLAR_WIDE := STAIR_WIDTH + 2.0 * WALL # the stairwell, its walls included
const CELLAR_TOP := 1.0 # its door's top edge, against the wall, above the ground
const CELLAR_DOOR_HEIGHT := 2.1 # the doorway into the basement
const CELLAR_PAD := 2.0 # concrete round it, over where the ground is opened (two terrain cells)
## Porches.
const PORCH_PITCH := 10.0 # degrees: the roof's slope away from the wall
const PORCH_ROOF := 0.12 # the roof's thickness
const PORCH_EAVE := 0.25 # how far the roof sticks out past the deck
const POST := 0.14
const RAIL_HEIGHT := 0.9
const SCREEN_DOOR_WIDTH := 1.6 # (MIN_PASSAGE: zombies have to get through it once it's broken)
const SCREEN_DOOR_HEIGHT := 2.1
const DECK := preload("res://world/kit/materials/wood_planks.tres")
const TIMBER := preload("res://world/kit/materials/timber.tres")
const SCREEN := preload("res://world/kit/materials/screen.tres")
const GarageDoorLook := preload("res://world/props/garage_door.tscn")
const CellarDoorLook := preload("res://world/props/cellar_door.tscn")
const ScreenDoorLook := preload("res://world/props/screen_door.tscn")

@export_group("Template")
## A ready-made building to start from (world/kit/kit_templates.gd): pick one
## and a Variant, then press Apply Template. It replaces all its settings
## (and what's outside it from a template before: a canopy, a sign...), and
## takes out the furniture Furnish Rooms put in. Ctrl+Z undoes it.
@export_enum("Farmhouse", "Ranch house", "Cottage", "Trailer", "Corner store", "Gas station", "Diner", "Church",
		"School", "Police station", "Barn", "Machine shed") var template := "Farmhouse":
	set(value):
		template = value
		template_variant = 0
		notify_property_list_changed()
@export var template_variant := 0
## Apply Template picks the outside's colour at random (from ones that suit it).
@export var random_colours := false
@export_tool_button("Apply Template", "Reload") var template_button := apply_template

@export_group("Size")
## How far back from the front wall it goes (local +x), in meters. (A drawn
## Footprint replaces this and Width.)
@export_range(2.0, 100.0, 0.1, "or_greater") var size_depth := 10.0:
	set(value):
		size_depth = value
		_changed()
## Along the front wall (local z), in meters.
@export_range(2.0, 100.0, 0.1, "or_greater") var size_width := 10.0:
	set(value):
		size_width = value
		_changed()
## Its outline, any shape: corners (x, z) in the building's own meters, in
## order round the outside. Draw it with Map Tools (Buildings > Draw outline).
## Empty: the Size rectangle.
@export var footprint := PackedVector2Array():
	set(value):
		footprint = _ordered(value)
		_changed()
## Turns the Size rectangle into a drawn outline (to drag its corners about).
@export_tool_button("Outline From Size", "Edit") var outline_button := outline_from_size
## Floors you can walk around on.
@export_range(1, 20) var floors := 1:
	set(value):
		floors = maxi(value, 1)
		_changed()
## The ground floor's height above the node: 0.1 on a sidewalk, 0.02 on bare ground.
@export_range(0.0, 1.0, 0.01) var floor_y := SIDEWALK_FLOOR_Y:
	set(value):
		floor_y = value
		_changed()
## What it stands on where the ground under it drops away (a hillside): a
## concrete block or stone base, or wooden posts (cabins, porches, trailers).
## Put the building's node at the height of the highest ground under it.
@export_enum("Concrete block", "Stone", "Wooden posts") var foundation := "Concrete block":
	set(value):
		foundation = value
		_changed()
## A basement under the ground floor: floor -1 (stairs, inner walls and rooms
## can be on it), BASEMENT_DEPTH below the ground, dark inside. Reach it with
## stairs from floor -1 or cellar doors (Outside). Press Apply in Map Tools
## (with the building selected) to open the ground under it.
@export var basement := false:
	set(value):
		basement = value
		_changed()
## A solid block over the top floor (you can't go in), this many meters tall,
## with painted-on windows across the front. 0 = a flat roof.
@export_range(0.0, 30.0, 0.1) var upper_height := 0.0:
	set(value):
		upper_height = value
		_changed()

@export_group("Openings")
## Doorways and windows. Click an entry to set where it is; "Default Openings"
## below fills in a door and windows to start from.
@export var openings: Array[KitOpening] = []:
	set(value):
		_watch(openings, value)
		openings = value
		_changed()
## Replaces the openings with a front door and a few windows on every floor.
@export_tool_button("Default Openings", "Reload") var default_openings_button := default_openings

@export_group("Painted Windows")
## Painted-on windows across the front of the solid upper block.
@export var painted_windows := true:
	set(value):
		painted_windows = value
		_changed()
## Which painted windows are boarded over (0 is the leftmost, seen from outside).
@export var boarded_painted_windows: PackedInt32Array = []:
	set(value):
		boarded_painted_windows = value
		_changed()

@export_group("Stairs")
## The flights between floors: place them with Map Tools (Buildings > Place
## stairs) or add them here. Empty on a rectangle: one per floor along a side
## wall (Stairs Side).
@export var stairs: Array[KitStair] = []:
	set(value):
		_watch(stairs, value)
		stairs = value
		_changed()
## A rectangle with no Stairs: the side wall the first staircase runs along
## (seen from outside); the next one up runs along the other side, and so on.
@export_enum("left", "right") var stairs_side := "left":
	set(value):
		stairs_side = value
		_changed()

@export_group("Roof")
## Flat, or a pitched roof worked out over the outline. Pitched roofs need an
## outline whose walls all run along x or z (right angles); an angled one gets
## a flat roof (a warning says so).
@export_enum("Flat", "Gable", "Hip", "Shed", "Gambrel") var roof_shape := "Flat":
	set(value):
		roof_shape = value
		_changed()
## Degrees from flat (a gambrel's upper slopes are gentler, its lower ones steep).
@export_range(10.0, 60.0, 1.0) var roof_pitch := 35.0:
	set(value):
		roof_pitch = value
		_changed()
## How far the roof sticks out past the walls (meters).
@export_range(0.0, 1.5, 0.05) var roof_overhang := 0.4:
	set(value):
		roof_overhang = value
		_changed()
## A shed roof: the side it slopes down to.
@export_enum("back", "front", "left", "right") var shed_slopes_to := "back":
	set(value):
		shed_slopes_to = value
		_changed()
## The space under a pitched roof: closed off, or an attic floor you can climb
## to (place stairs from the top floor, like any other floor).
@export_enum("Closed", "Walk-in") var attic := "Closed":
	set(value):
		attic = value
		_changed()
## Brick chimneys, from the ground up through the roof (Map Tools: Place chimney).
@export var chimneys: Array[KitChimney] = []:
	set(value):
		_watch(chimneys, value)
		chimneys = value
		_changed()
## Dormers on its sloped roof (Map Tools: Place dormer).
@export var dormers: Array[KitDormer] = []:
	set(value):
		_watch(dormers, value)
		dormers = value
		_changed()

@export_group("Outside")
## Porches along its outside walls (Map Tools: Add porch).
@export var porches: Array[KitPorch] = []:
	set(value):
		_watch(porches, value)
		porches = value
		_changed()
## Storm-cellar doors down into the Basement (Map Tools: Add cellar door).
@export var cellar_doors: Array[KitCellarDoor] = []:
	set(value):
		_watch(cellar_doors, value)
		cellar_doors = value
		_changed()

@export_group("Rooms")
## Walls inside, on one floor each, with their own openings. Draw them with
## Map Tools (Buildings > Draw inner wall).
@export var inner_walls: Array[KitInnerWall] = []:
	set(value):
		_watch(inner_walls, value)
		inner_walls = value
		_changed()
## Rooms with their own wall and floor materials (the space round each one's
## point, closed off by walls), and what they're for (Kind). Map Tools
## (Buildings > Paint room) adds them.
@export var rooms: Array[KitRoom] = []:
	set(value):
		_watch(rooms, value)
		rooms = value
		_changed()
## Puts furniture in every room with a Kind (world/kit/kit_furnish.gd): pieces
## added as ordinary children of the building, yours to move, change or
## delete. Pressing it again takes out what it put in before (only that) and
## furnishes afresh. Ctrl+Z undoes it.
@export_tool_button("Furnish Rooms", "Add") var furnish_button := furnish_rooms

@export_group("Materials")
## Empty = the kit's default. Any material works; the ones in
## world/kit/materials/ tile at any size.
@export var exterior_material: Material:
	set(value):
		exterior_material = value
		_changed()
@export var interior_material: Material:
	set(value):
		interior_material = value
		_changed()
@export var floor_material: Material:
	set(value):
		floor_material = value
		_changed()
@export var ceiling_material: Material:
	set(value):
		ceiling_material = value
		_changed()
@export var roof_material: Material:
	set(value):
		roof_material = value
		_changed()

@export_group("Models")
## Its doors and windows: model scenes (HOW_TO_MODEL.md, "Props"), stretched to
## each opening. With several, each door or window picks one (always the same
## one there). Empty: world/props/door.tscn and window.tscn (set Models there
## to change every building's).
@export var door_models: Array[PackedScene] = []:
	set(value):
		door_models = value
		_changed()
@export var window_models: Array[PackedScene] = []:
	set(value):
		window_models = value
		_changed()

## In the editor: its walls' numbers floating outside them (Map Tools turns
## them on while it's selected). Never in the game.
var show_numbers := false:
	set(value):
		show_numbers = value
		_changed()

var _generated: Array[Node] = []
var _foundation_body: StaticBody3D
var _dirty := true
var _queued := false


func _ready() -> void:
	ensure_built()
	_build_foundation() # now that it's on the map: the terrain is there to measure
	if Engine.is_editor_hint():
		set_notify_transform(true) # moved: the foundation follows the ground


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_changed()


## Builds it now if anything changed (main.gd calls this before the town is in
## the tree, so the doors and windows exist when it looks for them).
func ensure_built() -> void:
	if _dirty:
		_rebuild()


## Template Variant: the chosen template's variants by name.
func _validate_property(property: Dictionary) -> void:
	if property["name"] == "template_variant":
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = ",".join(KitTemplates.VARIANTS.get(template, ["Standard"]))


# --- Its shape ------------------------------------------------------------------

## Its outline: corners (x, z), in the order its walls are numbered.
func outline() -> PackedVector2Array:
	if footprint.size() >= 3:
		return footprint
	var half := size_width / 2.0
	return PackedVector2Array([Vector2(0, -half), Vector2(0, half), Vector2(size_depth, half), Vector2(size_depth, -half)])


## Corners turned to go round the way the walls need (the inside on the left,
## seen from above with +x down the screen); Footprint's setter does this. The
## first wall drawn (first corner to second) stays wall 0, the front.
static func _ordered(corners: PackedVector2Array) -> PackedVector2Array:
	if corners.size() < 3 or KitMesh._area(corners) <= 0.0:
		return corners
	var turned := PackedVector2Array([corners[1], corners[0]])
	for i in range(corners.size() - 1, 1, -1):
		turned.append(corners[i])
	return turned


func outline_from_size() -> void:
	_undoable("Outline From Size", "footprint", outline())


## Wall number n's two ends (x, z).
func edge_ends(n: int) -> Array[Vector2]:
	var poly := outline()
	return [poly[n % poly.size()], poly[(n + 1) % poly.size()]]


func edge_count() -> int:
	return outline().size()


## The wall an opening is in: its Edge, or (on a rectangle, or unset) its Wall's number.
func edge_of(op: KitOpening) -> int:
	if op.edge >= 0:
		return op.edge
	return WALL_NUMBERS.get(op.wall, 0)


## Whether a point (x, z, the building's own space) is inside its outline.
func contains_local(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, outline())


## Its corners on the ground (world x, z), for the map screen.
func ground_corners() -> PackedVector2Array:
	var corners := PackedVector2Array()
	for corner in outline():
		var world := global_transform * Vector3(corner.x, 0, corner.y)
		corners.append(Vector2(world.x, world.z))
	return corners


## A point `distance` meters outside the middle of the ground-floor front door
## (in the world); the front wall's middle if there's no door.
func outside_front_door(distance: float) -> Vector3:
	var along := 0.0
	var n := 0
	for op in openings:
		if op and op.kind == "door" and op.level == 0:
			along = op.offset
			n = edge_of(op)
			break
	var frame := _wall_frame(n)
	return global_transform * (frame * Vector3(-WALL / 2.0 - distance, 0, along))


## Height of a floor's surface above the node (-1: the basement's).
func floor_top(level: int) -> float:
	if level < 0:
		return -BASEMENT_DEPTH
	return floor_y if level == 0 else level * STOREY


## The lowest floor: -1 with a basement, else 0.
func bottom_level() -> int:
	return -1 if basement else 0


## A floor's walls run from the bottom of its floor's slab (the ground for the
## ground floor, or the basement's ceiling) to the bottom of the next one's (y0, y1).
func _wall_span(level: int) -> Vector2:
	var ceiling := floor_y - 0.2 # the basement's
	if level < 0:
		return Vector2(-BASEMENT_DEPTH - 0.2, ceiling)
	return Vector2(ceiling if level == 0 and basement else level * STOREY, (level + 1) * STOREY)


func default_openings() -> void:
	var list: Array[KitOpening] = []
	if footprint.size() < 3:
		_rectangle_openings(list)
	else:
		# A door in the middle of wall 0, and a window in every wall long enough on each floor.
		list.append(KitOpening.make_on_edge(0, "door", 0.0, 1.6, 0.0, 2.4))
		for k in floors:
			for n in edge_count():
				var ends := edge_ends(n)
				var length := ends[0].distance_to(ends[1])
				if length < 3.0:
					continue
				var op := KitOpening.make_on_edge(n, "window", 0.0 if n != 0 or k > 0 else length / 4.0 + 0.6, 1.2, 0.9, 2.3)
				op.level = k
				if not (n == 0 and k == 0 and length < 5.0):
					list.append(op)
	_undoable("Default Openings", "openings", list)


func _rectangle_openings(list: Array[KitOpening]) -> void:
	var half := size_width / 2.0
	list.append(KitOpening.make("front", "door", 0.0, 1.6, 0.0, 2.4))
	for k in floors:
		var on_floor: Array[KitOpening] = []
		if k == 0:
			# A window either side of the door, if there's room.
			var room := half - 0.8 - 0.4 - WALL - 0.4
			if room >= 1.0:
				for s: float in [-1.0, 1.0]:
					on_floor.append(KitOpening.make("front", "window", s * (0.8 + 0.4 + room / 2.0), minf(room, 2.6), 0.9, 2.6))
		else:
			var count := int((size_width - 1.0) / 3.0)
			for i in count:
				var z := -half + 0.5 + 3.0 * (i + 0.5) + ((size_width - 1.0) - 3.0 * count) / 2.0
				on_floor.append(KitOpening.make("front", "window", z, 1.2, 0.9, 2.3))
		for z: float in ([-size_width * 0.3, size_width * 0.3] if size_width > 10.0 else [0.0]):
			on_floor.append(KitOpening.make("back", "window", z, 1.2, 1.1, 2.3))
		for op in on_floor:
			op.level = k
			list.append(op)


## Sets a property through the editor's undo history (Ctrl+Z puts it back);
## outside the editor, just sets it.
func _undoable(action: String, property: String, value: Variant) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var undo: Object = Engine.get_singleton("EditorInterface").call("get_editor_undo_redo")
		undo.call("create_action", action)
		undo.call("add_do_property", self, property, value)
		undo.call("add_undo_property", self, property, get(property))
		undo.call("commit_action")
	else:
		set(property, value)


## Rebuilds when an opening or flight in a list changes.
func _watch(old: Array, new: Array) -> void:
	for item: Resource in old:
		if item and item.changed.is_connected(_changed):
			item.changed.disconnect(_changed)
	for item: Resource in new:
		if item and not item.changed.is_connected(_changed):
			item.changed.connect(_changed)


func _changed() -> void:
	_dirty = true
	# In the game a building is built once (doors move away from it after that);
	# in the editor it follows every change.
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


## What's wrong with it (world/building_warnings.gd).
func _get_configuration_warnings() -> PackedStringArray:
	return BuildingWarnings.of(self)


# --- Building it -------------------------------------------------------------

func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()

	var ext := exterior_material if exterior_material else DEFAULT_EXTERIOR
	var inside := interior_material if interior_material else DEFAULT_INTERIOR
	var floor_mat := floor_material if floor_material else DEFAULT_FLOOR
	var ceiling := ceiling_material if ceiling_material else DEFAULT_CEILING
	var roof := roof_material if roof_material else DEFAULT_ROOF
	var poly := outline()
	var km := KitMesh.new()
	var made: Array[Node] = [] # glass and doors, added once the shell is in
	var flights := _flights().filter(func(f: Dictionary) -> bool: return f["level"] < _top_level() and _flight_fits(f))

	var maps := {} # level -> its room map
	for k in range(bottom_level(), floors):
		maps[k] = _room_map(k)
	if basement:
		km.slab(poly, [], -BASEMENT_DEPTH, 0.2, BASEMENT_FLOOR, null, null, null, true, _slits(-1), _floor_pick.bind(maps[-1]))
	elif floor_y > 0.001:
		km.slab(poly, [], floor_y, floor_y, floor_mat, null, null, null, true, _slits(0), _floor_pick.bind(maps[0]))
	for k in range(bottom_level(), floors):
		var fy := floor_top(k)
		# The basement's walls: block inside, the foundation's look outside
		# (where the ground drops away it shows, flush with the foundation).
		var outer_mat := ext if k >= 0 else _foundation_material()
		var inner_mat := inside if k >= 0 else BASEMENT_WALL
		for n in poly.size():
			var ends := edge_ends(n)
			var list := []
			for op in openings:
				if op and edge_of(op) == n and op.level == k:
					list.append(_opening_entry(op, fy))
			if k < 0:
				for cellar in cellar_doors:
					if cellar and cellar.wall == n:
						list.append({"kind": "doorway", "along": cellar.offset, "width": STAIR_WIDTH, "bottom": fy,
								"top": fy + CELLAR_DOOR_HEIGHT, "source": cellar})
			_wall_pieces(km, ends[0], ends[1], WALL / 2.0, k, list, maps[k], outer_mat, inner_mat, true)
			if k >= 0: # (the basement's are the cellar doorways)
				made.append_array(_opening_nodes(_outer_name(n), k, list, fy, true))
		for i in inner_walls.size():
			var inner := inner_walls[i]
			if inner == null or inner.level != k or inner.start.distance_to(inner.end) < 0.3:
				continue
			var list := []
			for op in inner.openings:
				if op:
					list.append(_opening_entry(op, fy))
			_wall_pieces(km, inner.start, inner.end, 0.0, k, list, maps[k], inner_mat, inner_mat, false)
			made.append_array(_opening_nodes("Inner%d" % (i + 1), k, list, fy, false))
		# The slab over this floor: its ceiling, and the next floor's floor (with
		# holes where staircases come up).
		var y1 := (k + 1) * STOREY
		var upstairs := k + 1 < floors or (k + 1 == floors and _walk_in_attic())
		var here := flights.filter(func(f: Dictionary) -> bool: return f["level"] == k)
		var holes := here.map(func(f: Dictionary) -> Dictionary: return _hole(f))
		if k < 0: # the ground floor, over the basement
			km.slab(poly, holes, floor_y, 0.2, floor_mat, ceiling, null, BASEMENT_WALL, true, _slits(0), _floor_pick.bind(maps[0]))
		elif upstairs and k + 1 < floors:
			km.slab(poly, holes, y1, 0.2, floor_mat, ceiling, null, inside, true, _slits(k + 1), _floor_pick.bind(maps[k + 1]))
		elif upstairs: # the attic's floor
			km.slab(poly, holes, y1, 0.2, floor_mat, ceiling, null, inside)
		else:
			km.slab(poly, holes, y1, 0.2, floor_mat if _pitched() else roof, ceiling, null, inside)
		for flight in here:
			_stairs(km, flight, floor_mat, inner_mat)
	if upper_height > 0.0:
		_upper_block(km, poly, ext, roof)
	var peak := floors * STOREY + upper_height
	if _pitched():
		var under := inside if _walk_in_attic() else ceiling
		var built := KitRoof.build(km, poly, floors * STOREY + upper_height, roof_shape.to_lower(), roof_pitch,
				roof_overhang, shed_slopes_to, roof, under, ext, inside)
		peak = built["top"]
		if roof_shape != "Shed":
			for dormer in dormers:
				if dormer == null:
					continue
				var placed := KitRoof.dormer(km, built["parts"], dormer.position, dormer.width, floors * STOREY + upper_height,
						roof_pitch, roof, ext, inside)
				if not placed.is_empty():
					var look := KitProp.make(WindowLook, window_models, Vector3(0.08, 0.9, minf(dormer.width - 0.5, 1.0)))
					look.transform = placed["xform"]
					made.append(look)
	for chimney in chimneys:
		if chimney:
			var height := peak + 0.8
			km.box(Vector3(chimney.size.x, height, chimney.size.y), _at(Vector3(chimney.position.x, height / 2.0, chimney.position.y)),
					KitMesh.all(CHIMNEY_MATERIAL))
	for porch in porches:
		if porch:
			PorchBuilder.build(self, km, porch, roof, made)
	if basement:
		for cellar in cellar_doors:
			if cellar and cellar.wall < poly.size():
				_cellar(km, cellar, made)
		made.append(_darkness())

	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	var shell := km.add_to(body)
	if not Engine.is_editor_hint() and not shell.is_empty() and shell[0] is MeshInstance3D:
		# What it hides from view (occlusion culling): its walls, floors, roof.
		var occluder := KitMesh.occluder_of((shell[0] as MeshInstance3D).mesh)
		if occluder:
			var hides := OccluderInstance3D.new()
			hides.name = "Occluder"
			hides.occluder = occluder
			add_child(hides, false, Node.INTERNAL_MODE_BACK)
			_generated.append(hides)
	for node in made:
		add_child(node, false, Node.INTERNAL_MODE_BACK)
		_generated.append(node)
	if show_numbers and Engine.is_editor_hint():
		_number_walls()
	if is_inside_tree():
		_build_foundation()
	if Engine.is_editor_hint():
		update_configuration_warnings()


## The solid block over the top floor: walls round the outline, a roof on top,
## and painted-on windows along the front (wall 0).
func _upper_block(km: KitMesh, poly: PackedVector2Array, ext: Material, roof: Material) -> void:
	var top := floors * STOREY
	for n in poly.size():
		var ends := edge_ends(n)
		km.wall(_wall_frame(n), ends[0].distance_to(ends[1]), top, top + upper_height, top, [], ext, ext)
	km.slab(poly, [], top + upper_height, 0.2, roof, null, ext, null)
	if not painted_windows or upper_height <= 1.8:
		return
	var ends := edge_ends(0)
	var length := ends[0].distance_to(ends[1])
	var frame := _wall_frame(0)
	var count := int((length - 1.0) / PAINTED_SPACING)
	for i in count:
		var along := -length / 2.0 + 0.5 + PAINTED_SPACING * (i + 0.5) + ((length - 1.0) - PAINTED_SPACING * count) / 2.0
		var mat: Material = BOARDS if i in boarded_painted_windows else WINDOW_DARK
		var at := frame * Transform3D(Basis.IDENTITY, Vector3(-WALL / 2.0 - PAINTED_WINDOW.x / 2.0, top + upper_height / 2.0, along))
		km.box(PAINTED_WINDOW, at, [mat, null, mat, mat, mat, mat], false)


## Each wall's number, floating outside its middle (in the editor, while Map Tools has it selected).
func _number_walls() -> void:
	var height := floors * STOREY + upper_height + 1.0
	for n in edge_count():
		var label := Label3D.new()
		label.text = "Wall %d" % n
		label.font_size = 96
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(1.0, 0.85, 0.3)
		label.position = _wall_frame(n) * Vector3(-1.0, height, 0)
		add_child(label, false, Node.INTERNAL_MODE_BACK)
		_generated.append(label)


## The foundation, on its own (see `foundation`): main.gd builds buildings before
## the map is in the game, so this comes once it is (_ready).
func _build_foundation() -> void:
	if _foundation_body:
		remove_child(_foundation_body)
		_foundation_body.queue_free()
		_foundation_body = null
	var km := KitMesh.new()
	_foundation(km)
	if km.shapes.is_empty() and not km.has_slabs():
		return
	_foundation_body = StaticBody3D.new()
	_foundation_body.name = "Foundation"
	add_child(_foundation_body, false, Node.INTERNAL_MODE_BACK)
	km.add_to(_foundation_body)


## From the building's base (its node's height) down into the ground all
## round, where the ground is lower than the base (see `foundation`).
func _foundation(km: KitMesh) -> void:
	var terrain := TerrainEdit.find_terrain(self) if is_inside_tree() else null
	if terrain == null:
		return
	var poly := outline()
	PorchBuilder.posts(self, km, terrain)
	var lowest := 0.0 # the ground's lowest point under the walls, from the base
	for n in poly.size():
		var ends := edge_ends(n)
		var steps := maxi(2, int(ceil(ends[0].distance_to(ends[1]))))
		for i in steps + 1:
			var p := ends[0].lerp(ends[1], float(i) / steps)
			var world := global_transform * Vector3(p.x, 0, p.y)
			lowest = minf(lowest, TerrainEdit.height_at(terrain, world) - world.y)
	if lowest > -0.05:
		return # level ground: nothing shows
	var depth := -lowest + 0.3 # a little into the ground
	if basement:
		# The basement's walls are the solid part: this is only their outside
		# face, carried on down where the ground's lower than the basement.
		km.slab(poly, [], floor_y - 0.2, depth + floor_y - 0.2, null, null, _foundation_material(), null, false)
		return
	var mat: Material = FOUNDATION_MATERIALS.get(foundation, FOUNDATION_MATERIALS["Concrete block"])
	if foundation != "Wooden posts":
		km.slab(poly, [], 0.0, depth, null, null, mat, null)
		return
	# Posts round the edge: at each corner, and every POST_SPACING or so between.
	for n in poly.size():
		var ends := edge_ends(n)
		var along := (ends[1] - ends[0]).normalized()
		var inward := Vector2(along.y, -along.x) * 0.15
		var count := maxi(1, int(ceil(ends[0].distance_to(ends[1]) / POST_SPACING)))
		for i in count: # (the next wall's first post is this one's last)
			var p := ends[0].lerp(ends[1], float(i) / count) + inward + along * (0.15 if i == 0 else 0.0)
			km.box(Vector3(0.25, depth, 0.25), _at(Vector3(p.x, -depth / 2.0, p.y)), [mat, mat, null, null, mat, mat])


static func _at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)


## Wall n's frame (see kit_mesh.gd): its middle at the foot, outside toward -X,
## running along +Z from its first corner toward the next.
func _wall_frame(n: int) -> Transform3D:
	var ends := edge_ends(n)
	var along := (ends[1] - ends[0]).normalized()
	var z := Vector3(along.x, 0, along.y)
	var x := Vector3(along.y, 0, -along.x) # into the building
	var middle := (ends[0] + ends[1]) / 2.0
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(middle.x, 0, middle.y) + x * (WALL / 2.0))


## An opening as km.wall() takes it (heights from the floor's top).
static func _opening_entry(op: KitOpening, fy: float) -> Dictionary:
	return {"kind": op.kind, "along": op.offset, "width": op.width, "bottom": fy + op.bottom,
			"top": fy + op.top, "boarded_up": op.boarded_up, "source": op}


## Wall n's name for its doors and windows: a rectangle's Front, Right, Back,
## Left; a drawn outline's Wall0, Wall1...
func _outer_name(n: int) -> String:
	return WALL_NUMBERS.find_key(n).capitalize() if footprint.size() < 3 else "Wall%d" % n


## Glass and doors for one wall of one floor, named for saving ("FrontDoor",
## "BackWindow2", "Floor2FrontWindow", "Wall5Door", "Inner2Door",
## "LeftGarageDoor"...). Only the ground floor's outside ones can be boarded up.
func _opening_nodes(wall_name: String, level: int, list: Array, fy: float, outside: bool) -> Array[Node]:
	var nodes: Array[Node] = []
	var counts := {"door": 0, "window": 0, "garage door": 0}
	var boardable := outside and level == 0
	var prefix := ("Floor%d" % (level + 1) if level > 0 else "") + wall_name
	for entry: Dictionary in list: # sorted along the wall by km.wall()
		if not entry.has("frame"):
			continue # off the end of the wall (a warning says so)
		var op: KitOpening = entry["source"]
		if op.kind == "doorway" or (op.kind == "garage door" and not outside):
			continue # just a gap
		counts[op.kind] += 1
		var count: int = counts[op.kind]
		var node_name: String = prefix + op.kind.capitalize().replace(" ", "") + (str(count) if count > 1 else "")
		if op.kind == "garage door":
			var garage := _garage_door(entry, op.door_color)
			garage.name = node_name
			garage.start_open = op.start_open
			nodes.append(garage)
		elif op.kind == "door":
			var door := KitMesh.make_door(entry, op.door_color, door_models)
			door.name = node_name
			door.start_open = op.start_open
			door.boardable = boardable
			door.boarded_at_start = op.boarded_at_start and boardable
			nodes.append(door)
		elif not op.boarded_up:
			var frame: Transform3D = entry["frame"]
			var pane := KitMesh.make_window(entry, boardable, op.boarded_at_start and boardable, frame.origin.y - fy, window_models)
			pane.name = node_name
			nodes.append(pane)
	return nodes


## A garage door for an opening made by km.wall(): it tips up into the
## ceiling, hinged along its top edge; zombies can't break it, and it stays in
## the navigation bake (door.gd).
func _garage_door(entry: Dictionary, color: Color) -> Door:
	var height: float = entry["top"] - entry["bottom"] - 0.02
	var width: float = entry["width"] - 0.06
	var frame: Transform3D = entry["frame"]
	var door := Door.new()
	door.setup(Vector3(0.06, height, width), Vector3(0.0, -height / 2.0, 0.0), color,
			frame * _at(Vector3(0, (entry["top"] - entry["bottom"]) / 2.0, 0)), PI / 2.0)
	door.open_axis = Vector3.BACK # along the top edge: the bottom swings in (+X) and up
	door.look_scene = GarageDoorLook
	door.label = "garage door"
	door.breakable = false
	door.boardable = false
	door.in_navigation = true
	return door


# --- Templates ----------------------------------------------------------------------

## What a template sets (and puts back to the default when it doesn't say).
const TEMPLATE_PROPERTIES := ["size_depth", "size_width", "footprint", "floors", "floor_y", "foundation", "basement",
		"upper_height", "openings", "painted_windows", "boarded_painted_windows", "stairs", "stairs_side", "roof_shape",
		"roof_pitch", "roof_overhang", "shed_slopes_to", "attic", "chimneys", "dormers", "porches", "cellar_doors",
		"inner_walls", "rooms", "exterior_material", "interior_material", "floor_material", "ceiling_material",
		"roof_material"]


## See template_button. Returns the extras it put outside.
func apply_template() -> Array[Node]:
	var values := _template_values()
	if values.is_empty():
		return []
	var fresh: Node = (get_script() as Script).new()
	var old: Array[Node] = get_children().filter(func(n: Node) -> bool: return n.has_meta("template_extra") or n.has_meta("furnished"))
	var added: Array[Node] = values["extras"]
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface") and is_inside_tree():
		var editor: Object = Engine.get_singleton("EditorInterface")
		var scene_root: Node = editor.call("get_edited_scene_root")
		var undo: Object = editor.call("get_editor_undo_redo")
		undo.call("create_action", "Apply Template: " + template)
		for property: String in TEMPLATE_PROPERTIES:
			undo.call("add_do_property", self, property, values.get(property, fresh.get(property)))
			undo.call("add_undo_property", self, property, get(property))
		for node in old:
			undo.call("add_do_method", self, "remove_child", node)
			undo.call("add_undo_method", self, "add_child", node, true)
			undo.call("add_undo_method", node, "set_owner", scene_root)
			undo.call("add_undo_reference", node)
		for node in added:
			undo.call("add_do_method", self, "add_child", node, true)
			undo.call("add_do_method", node, "set_owner", scene_root)
			undo.call("add_do_reference", node)
			undo.call("add_undo_method", self, "remove_child", node)
		undo.call("commit_action")
	else:
		for property: String in TEMPLATE_PROPERTIES:
			set(property, values.get(property, fresh.get(property)))
		for node in old:
			remove_child(node)
			node.queue_free()
		for node in added:
			add_child(node, true)
	fresh.free()
	return added


## The chosen template's settings, and its extras ready to add (named, marked).
func _template_values() -> Dictionary:
	var rng: RandomNumberGenerator = null
	if random_colours:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var values := KitTemplates.settings(template, template_variant, rng)
	if values.is_empty():
		return {}
	var extras: Array[Node] = []
	for node: Node3D in values.get("extras", []):
		node.set_meta("template_extra", true)
		if node is KitSign:
			node.name = (node.get("text") as String).capitalize() + "Sign"
		elif str(node.name).is_empty(): # (made in code)
			node.name = (node.get_script() as Script).get_global_name() if node.get_script() else node.get_class()
		extras.append(node)
	values["extras"] = extras
	return values


# --- Furnishing ----------------------------------------------------------------------

## See furnish_button. Returns the pieces it added.
func furnish_rooms() -> Array[Node]:
	var old: Array[Node] = get_children().filter(func(n: Node) -> bool: return n.has_meta("furnished"))
	var added: Array[Node] = []
	for room in rooms:
		if room == null or room.kind == "None":
			continue
		for item in KitFurnish.plan(self, room):
			var node: Node3D = KitFurnish.scene_of(item["piece"]).instantiate()
			node.transform = item["xform"]
			node.name = room.kind.to_pascal_case() + node.name
			node.set_meta("furnished", true)
			if node.get("loot_table") == "standard" and KitFurnish.ROOM_LOOT.has(room.kind):
				node.set("loot_table", KitFurnish.ROOM_LOOT[room.kind])
			added.append(node)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor: Object = Engine.get_singleton("EditorInterface")
		var scene_root: Node = editor.call("get_edited_scene_root")
		var undo: Object = editor.call("get_editor_undo_redo")
		undo.call("create_action", "Furnish Rooms")
		for node in old:
			undo.call("add_do_method", self, "remove_child", node)
			undo.call("add_undo_method", self, "add_child", node, true)
			undo.call("add_undo_method", node, "set_owner", scene_root)
			undo.call("add_undo_reference", node)
		for node in added:
			undo.call("add_do_method", self, "add_child", node, true)
			undo.call("add_do_method", node, "set_owner", scene_root)
			undo.call("add_do_reference", node)
			undo.call("add_undo_method", self, "remove_child", node)
		undo.call("commit_action")
	else:
		for node in old:
			remove_child(node)
			node.queue_free()
		for node in added:
			add_child(node, true)
	return added


# --- The basement ----------------------------------------------------------------------

## What the basement's walls look like outside: the foundation's (block, if that's posts).
func _foundation_material() -> Material:
	var name := "Concrete block" if foundation == "Wooden posts" else foundation
	return FOUNDATION_MATERIALS.get(name, FOUNDATION_MATERIALS["Concrete block"])


## A cellar door's frame: on the ground at the outline, in the middle of the
## stairwell; X out from the wall, Z along it (back toward the wall's first corner).
func _cellar_frame(cellar: KitCellarDoor) -> Transform3D:
	var ends := edge_ends(cellar.wall)
	var along := (ends[1] - ends[0]).normalized()
	var out := Vector2(-along.y, along.x)
	var at := (ends[0] + ends[1]) / 2.0 + along * cellar.offset
	return Transform3D(Basis(Vector3(out.x, 0, out.y), Vector3.UP, Vector3(-along.x, 0, -along.y)), Vector3(at.x, 0, at.y))


## How far out from the wall a cellar door's stairwell reaches.
static func _cellar_length() -> float:
	return BASEMENT_DEPTH * CELLAR_RUN_PER_RISE + CELLAR_LANDING


## One cellar door: a stairwell down beside the wall to the basement doorway,
## concrete walls round it rising to a slanted door over it, and a concrete
## pad round it all (over the ground Apply opens).
func _cellar(km: KitMesh, cellar: KitCellarDoor, made: Array[Node]) -> void:
	var f := _cellar_frame(cellar)
	var length := _cellar_length()
	var bottom := -BASEMENT_DEPTH
	var half := STAIR_WIDTH / 2.0
	# The landing, and the steps up to the ground away from the wall.
	km.box(Vector3(CELLAR_LANDING, 0.2, STAIR_WIDTH), f * _at(Vector3(CELLAR_LANDING / 2.0, bottom - 0.1, 0)), KitMesh.all(BASEMENT_FLOOR))
	var foot := f * Vector3(CELLAR_LANDING, 0, 0)
	_ramp(km, {"level": -1, "start": Vector2(foot.x, foot.z), "angle": atan2(f.basis.x.z, f.basis.x.x)}, bottom, 0.0, STAIR_WIDTH,
			BASEMENT_FLOOR, BASEMENT_WALL, CELLAR_RUN_PER_RISE)
	# Its two walls: down in the ground, and their slanted tops above it.
	var top_at := func(u: float) -> float: return lerpf(CELLAR_TOP, 0.05, u / length) - 0.04
	for s: float in [-1.0, 1.0]:
		var z := s * (half + WALL / 2.0)
		km.box(Vector3(length, -bottom + 0.2, WALL), f * _at(Vector3(length / 2.0, (bottom - 0.2) / 2.0, z)),
				[BASEMENT_WALL, BASEMENT_WALL, null, null, BASEMENT_WALL, BASEMENT_WALL])
		var face := s * (half + WALL) # its outer face
		var cheek := PackedVector3Array([f * Vector3(0, 0, face), f * Vector3(length, 0, face),
				f * Vector3(length, top_at.call(length), face), f * Vector3(0, top_at.call(0.0), face)])
		var n := (cheek[1] - cheek[0]).cross(cheek[2] - cheek[0])
		if n.dot(f.basis.z * s) < 0.0:
			cheek.reverse()
		km.plate(cheek, WALL, BASEMENT_WALL, BASEMENT_WALL, BASEMENT_WALL) # (its back is the stairwell's side)
	# The pad round it, with the stairwell cut out of it.
	var pad := CELLAR_PAD + WALL
	var outline := PackedVector2Array()
	for c: Vector3 in [Vector3(0, 0, -half - pad), Vector3(length + CELLAR_PAD, 0, -half - pad),
			Vector3(length + CELLAR_PAD, 0, half + pad), Vector3(0, 0, half + pad)]:
		var w := f * c
		outline.append(Vector2(w.x, w.z))
	if KitMesh._area(outline) > 0.0:
		outline.reverse()
	var well_middle := f * Vector3(length / 2.0, 0, 0)
	var well := {"xform": Transform2D(atan2(f.basis.x.z, f.basis.x.x), Vector2(well_middle.x, well_middle.z)),
			"size": Vector2(length, STAIR_WIDTH + 2.0 * WALL)}
	km.slab(outline, [well], 0.05, 0.4, BASEMENT_FLOOR, null, BASEMENT_FLOOR, null)
	# The door: one slanted leaf over the stairwell, hinged along its +Z side,
	# swinging up and over. Its frame: Y up the slope to the wall, X down into
	# the stairwell (its outside, -X, faces up), Z across (the frame's -Z).
	var rise := CELLAR_TOP - 0.05
	var up_slope := (f.basis.x * -length + Vector3.UP * rise).normalized()
	var down := (f.basis.x * -rise - Vector3.UP * length).normalized()
	var hinge := f * Vector3(length, 0.05, half + WALL)
	var leaf_length := sqrt(length * length + rise * rise)
	var door := Door.new()
	door.setup(Vector3(0.05, leaf_length, STAIR_WIDTH + 2.0 * WALL), Vector3(-0.03, leaf_length / 2.0, half + WALL),
			Color(0.3, 0.33, 0.3), Transform3D(Basis(down, up_slope, down.cross(up_slope)), hinge), -PI * 0.6)
	door.look_scene = CellarDoorLook
	door.label = "cellar door"
	door.name = "CellarDoor%d" % (cellar_doors.find(cellar) + 1)
	made.append(door)


## Darkness: the basement gets almost no light but what comes down the stairs
## or in through a cellar door (a reflection probe that stands in for the sky's light).
func _darkness() -> ReflectionProbe:
	var poly := outline()
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	# Up to just under the floor above: its ceiling well inside (past the
	# blend), the ground floor's floor outside.
	var top := floor_y - 0.05
	var bottom := -BASEMENT_DEPTH - 0.5
	# Its sides in the middle of the walls: their inside faces dark, their outsides not.
	var probe := Darkness.probe(Vector3(box.size.x - WALL, top - bottom, box.size.y - WALL),
			Vector3(box.get_center().x, (top + bottom) / 2.0, box.get_center().y), BASEMENT_DARK, 0.1)
	probe.name = "BasementDark"
	probe.max_distance = 20.0
	return probe


## Opens the ground (the terrain) for the basement and its cellar doors (Map
## Tools' Apply): everywhere a terrain cell lies wholly inside the outline, and
## over each cellar door's stairwell (its pad covers the rest). Returns the
## (x, z) area changed, in the world. Without a basement, closes it again
## (under the building and its cellar doors' pads: nowhere else).
func apply(terrain: Node) -> Rect2:
	var spacing: float = terrain.vertex_spacing
	var corners: Array[Vector3] = []
	for c in outline():
		corners.append(global_transform * Vector3(c.x, 0, c.y))
	var wells: Array[Transform3D] = []
	for cellar in cellar_doors:
		if cellar and cellar.wall < edge_count():
			var f := global_transform * _cellar_frame(cellar)
			wells.append(f)
			for u: float in [0.0, _cellar_length() + CELLAR_PAD]:
				for z: float in [-CELLAR_WIDE / 2.0 - CELLAR_PAD, CELLAR_WIDE / 2.0 + CELLAR_PAD]:
					corners.append(f * Vector3(u, 0, z))
	var rect := Rect2(corners[0].x, corners[0].z, 0, 0)
	for c in corners:
		rect = rect.expand(Vector2(c.x, c.z))
	rect = rect.grow(spacing * 2.0)
	var poly := outline()
	for x in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing) + 1):
		for z in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing) + 1):
			var v := Vector3(x * spacing, 0.0, z * spacing)
			var local := to_local(Vector3(v.x, global_position.y, v.z))
			var p := Vector2(local.x, local.z)
			var inside := Geometry2D.is_point_in_polygon(p, poly)
			var ours := inside # (only the ground under it and its cellar doors' pads is touched)
			# Every cell round this corner is inside: it can go.
			var hole := basement and inside and _distance_to_outline(p) >= spacing * 1.42
			for f in wells:
				var w := f.affine_inverse() * Vector3(v.x, global_position.y, v.z)
				ours = ours or (w.x > -spacing and w.x < _cellar_length() + CELLAR_PAD and absf(w.z) < CELLAR_WIDE / 2.0 + CELLAR_PAD)
				# Any cell round it over the stairwell: it goes (the pad hides the rest).
				if basement and w.x > -spacing and w.x < _cellar_length() + spacing and absf(w.z) < STAIR_WIDTH / 2.0 + spacing:
					hole = true
			if ours:
				terrain.data.set_control_hole(v, hole)
	TerrainEdit.finish(terrain, rect)
	return rect


func _distance_to_outline(p: Vector2) -> float:
	var poly := outline()
	var least := INF
	for n in poly.size():
		least = minf(least, Geometry2D.get_closest_point_to_segment(p, poly[n], poly[(n + 1) % poly.size()]).distance_to(p))
	return least


# --- The roof ---------------------------------------------------------------------

## A pitched roof (not flat, and the outline allows it).
func _pitched() -> bool:
	return roof_shape != "Flat" and KitRoof.fits(outline())


## An attic you can climb into: a pitched roof, set Walk-in, straight on the top floor.
func _walk_in_attic() -> bool:
	return _pitched() and attic == "Walk-in" and upper_height <= 0.0


## Room to stand under the roof (above the attic floor) at the top of a flight
## to the attic, and past it: the least of the two. (Worked out as if every
## part of the roof were a gable: a hip's ends are lower.)
func _headroom(flight: Dictionary) -> float:
	var frame := _flight_frame(flight)
	var run := _run(flight["level"])
	var least := INF
	var tan_p := tan(deg_to_rad(roof_pitch))
	for at: Vector2 in [frame * Vector2(run, 0), frame * Vector2(run + LANDING, 0)]:
		var best := 0.0
		for part: Dictionary in KitRoof._split(outline()):
			var r: Rect2 = part["rect"]
			if not r.grow(0.01).has_point(at):
				continue
			var v := at.y if part["along_x"] else at.x
			var v0 := r.position.y if part["along_x"] else r.position.x
			var v1 := r.end.y if part["along_x"] else r.end.x
			var height := (minf(v - v0, v1 - v) * tan_p) if roof_shape != "Shed" else (v1 - v0) * tan_p / 2.0
			best = maxf(best, height - KitRoof.THICK)
		least = minf(least, best)
	return least


## The highest floor stairs can reach: the top floor, or the attic.
func _top_level() -> int:
	return floors if _walk_in_attic() else floors - 1


# --- Walls and rooms ------------------------------------------------------------------

## A wall from a to b on floor `level`, its middle line `shift` in from the
## line (a wall of the outline: WALL / 2, so its outside is flush with the
## outline; an inner wall: 0, centered). It's made in pieces, split where inner
## walls meet it, so each side of each piece can take the material of the room
## it faces (see _room_map). outside_mat: its -X face's when that's not in a
## room (outer: the outside of the building, never a room). list: its
## openings (km.wall()'s), which come back with their frames.
func _wall_pieces(km: KitMesh, a: Vector2, b: Vector2, shift: float, level: int, list: Array,
		map: Dictionary, outside_mat: Material, inside_mat: Material, outer: bool) -> void:
	var length := a.distance_to(b)
	var along := (b - a).normalized()
	var into := Vector2(along.y, -along.x) # +X: into the building, or an inner wall's +X side
	var cuts: Array[float] = [0.0, length]
	for inner in inner_walls:
		if inner == null or inner.level != level:
			continue
		for end: Vector2 in [inner.start, inner.end]:
			var t := (end - a).dot(along)
			var off := (end - a).dot(into) - shift
			if absf(off) < WALL and t > 0.05 and t < length - 0.05:
				cuts.append(t)
	cuts.sort()
	var span := _wall_span(level)
	var fy := floor_top(level)
	for i in cuts.size() - 1:
		var t0 := cuts[i]
		var t1 := cuts[i + 1]
		if t1 - t0 < 0.01:
			continue
		var mid := (t0 + t1) / 2.0
		var middle := a + along * mid + into * shift
		var frame := Transform3D(Basis(Vector3(into.x, 0, into.y), Vector3.UP, Vector3(along.x, 0, along.y)), Vector3(middle.x, 0, middle.y))
		var here := []
		for op: Dictionary in list:
			var at: float = op["along"] + length / 2.0 # from a
			if at >= t0 and at < t1:
				var piece_op := op.duplicate()
				piece_op["along"] = at - mid
				here.append(piece_op)
		var in_room := _room_at(map, middle + into * (WALL / 2.0 + 0.3))
		var out_room := null if outer else _room_at(map, middle - into * (WALL / 2.0 + 0.3))
		km.wall(frame, t1 - t0, span.x, span.y, fy, here, _wall_mat(out_room, outside_mat), _wall_mat(in_room, inside_mat))
		# Back to the caller's list, with their frames (for the doors and glass).
		for piece_op: Dictionary in here:
			for op: Dictionary in list:
				if op["source"] == piece_op["source"]:
					op["frame"] = piece_op["frame"]


static func _wall_mat(room: KitRoom, otherwise: Material) -> Material:
	return room.wall_material if room and room.wall_material else otherwise


## Thin cuts along each inner wall on a floor, so its floor splits into rooms.
func _slits(level: int) -> Array:
	var result := []
	for inner in inner_walls:
		if inner and inner.level == level and inner.start.distance_to(inner.end) >= 0.3:
			var middle := (inner.start + inner.end) / 2.0
			var angle := (inner.end - inner.start).angle()
			result.append({"xform": Transform2D(angle, middle), "size": Vector2(inner.start.distance_to(inner.end), 0.004)})
	return result


## A floor piece's material: its room's floor, or null (the building's).
func _floor_pick(piece: PackedVector2Array, map: Dictionary) -> Variant:
	var middle := Vector2.ZERO
	for p in piece:
		middle += p
	middle /= piece.size()
	var room := _room_at(map, middle)
	if room == null:
		# A long thin piece's middle can land on a wall: try near a corner.
		for p in piece:
			room = _room_at(map, p.lerp(middle, 0.2))
			if room:
				break
	return room.floor_material if room and room.floor_material else null


const ROOM_CELL := 0.25 # meters: the grid rooms are found on


## Which floor cells belong to which room on floor `level`: from each room's
## point, every cell reachable without crossing a wall (doorways don't join
## rooms). {"origin": Vector2, "cells": {Vector2i: KitRoom}}; empty if the
## floor has no rooms.
func _room_map(level: int) -> Dictionary:
	var here := rooms.filter(func(r: KitRoom) -> bool: return r != null and r.level == level)
	if here.is_empty():
		return {}
	var poly := outline()
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var walls := inner_walls.filter(func(w: KitInnerWall) -> bool: return w != null and w.level == level)
	var cells := {}
	for room: KitRoom in here:
		var queue: Array[Vector2i] = [Vector2i(((room.point - box.position) / ROOM_CELL).floor())]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			if cells.has(cell):
				continue
			var at := box.position + (Vector2(cell) + Vector2(0.5, 0.5)) * ROOM_CELL
			if not Geometry2D.is_point_in_polygon(at, poly) or _on_inner_wall(at, walls):
				continue
			cells[cell] = room
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not cells.has(cell + step):
					queue.append(cell + step)
	return {"origin": box.position, "cells": cells}


func _on_inner_wall(p: Vector2, walls: Array) -> bool:
	for wall: KitInnerWall in walls:
		var closest := Geometry2D.get_closest_point_to_segment(p, wall.start, wall.end)
		if closest.distance_to(p) < WALL / 2.0 + ROOM_CELL * 0.5:
			return true
	return false


static func _room_at(map: Dictionary, p: Vector2) -> KitRoom:
	if map.is_empty():
		return null
	var cell := Vector2i(((p - (map["origin"] as Vector2)) / ROOM_CELL).floor())
	return (map["cells"] as Dictionary).get(cell)


## The room marked round a point on a floor (its Rooms entry), or null.
func room_at(level: int, p: Vector2) -> KitRoom:
	return _room_at(_room_map(level), p)


# --- Stairs ------------------------------------------------------------------------
# A flight: {"level", "start" (x, z of its bottom step's middle), "angle"
# (radians it climbs toward, from +x toward +z)}.

## The flights: Stairs, or a rectangle's own (one per floor, along a side wall;
## unless Stairs has some going up from the ground floor or higher: a flight
## down to the basement alone doesn't count).
func _flights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stair in stairs:
		if stair:
			result.append({"level": stair.level, "start": stair.start, "angle": deg_to_rad(stair.direction)})
	if footprint.size() >= 3 or stairs.any(func(st: KitStair) -> bool: return st != null and st.level >= 0):
		return result
	var half := size_width / 2.0
	for k in floors - 1:
		if not _stairs_fit(k):
			continue
		var s := _stairs_sign(k)
		result.append({"level": k, "start": Vector2(STAIR_START, s * (half - WALL - STAIR_WIDTH / 2.0)), "angle": 0.0})
	return result


## Which side wall a rectangle's own flight k runs along: -1 left (-z), +1 right.
func _stairs_sign(k: int) -> float:
	var first := -1.0 if stairs_side == "left" else 1.0
	return first if k % 2 == 0 else -first


func _stairs_rise(k: int) -> float:
	return floor_top(k + 1) - floor_top(k)


func _run(k: int) -> float:
	return _stairs_rise(k) * STAIR_RUN_PER_RISE


func _stairs_needs(k: int) -> float:
	return STAIR_START + _run(k) + LANDING + WALL


func _stairs_fit(k: int) -> bool:
	return size_depth >= _stairs_needs(k) and size_width >= STAIR_WIDTH + 2.0 * WALL + 1.0


## The flight's own frame on the floor (x, z): its bottom step's middle, x the way it climbs.
func _flight_frame(flight: Dictionary) -> Transform2D:
	return Transform2D(float(flight["angle"]), flight["start"])


## The hole it comes up through, in the slab over its floor.
func _hole(flight: Dictionary) -> Dictionary:
	var run := _run(flight["level"])
	return {"xform": _flight_frame(flight) * Transform2D(0.0, Vector2(run / 2.0, 0)), "size": Vector2(run, STAIR_WIDTH)}


## Whether the flight, and the landing past its top, are inside the outline.
func _flight_fits(flight: Dictionary) -> bool:
	var frame := _flight_frame(flight)
	var run := _run(flight["level"])
	var w := STAIR_WIDTH / 2.0 - 0.01
	for corner: Vector2 in [Vector2(0.01, -w), Vector2(0.01, w), Vector2(run + LANDING, -w), Vector2(run + LANDING, w)]:
		if not contains_local(frame * corner):
			return false
	return true


## One flight: a ramp to walk on (and for the navigation mesh), steps to look
## at, and a railing round the hole upstairs (not where a wall already is).
func _stairs(km: KitMesh, flight: Dictionary, tread: Material, side: Material) -> void:
	var k: int = flight["level"]
	var yb := floor_top(k + 1)
	var run := _run(k)
	var frame := _ramp(km, flight, floor_top(k), yb, STAIR_WIDTH, tread, tread)
	# Railing upstairs: along each long side of the hole and across its low end,
	# where there isn't a wall right there.
	var h := STAIR_WIDTH / 2.0
	var rails := [[Vector3(run, 1.0, 0.06), Vector3(run / 2.0, yb + 0.5, -h - 0.03)],
			[Vector3(run, 1.0, 0.06), Vector3(run / 2.0, yb + 0.5, h + 0.03)],
			[Vector3(0.06, 1.0, STAIR_WIDTH), Vector3(-0.03, yb + 0.5, 0)]]
	for rail: Array in rails:
		var at: Vector3 = frame * rail[1]
		if _near_wall(Vector2(at.x, at.z)):
			continue
		km.box(rail[0], frame * _at(rail[1]), KitMesh.all(side))


## A flight's ramp (to walk on, and for the navigation mesh) and the steps to
## look at, from ya at its start up to yb, `width` wide, climbing the way it
## points; side: the steps' ends (null: not drawn). Returns its frame.
func _ramp(km: KitMesh, flight: Dictionary, ya: float, yb: float, width: float, tread: Material, side: Material,
		run_per_rise := STAIR_RUN_PER_RISE) -> Transform3D:
	var rise := yb - ya
	var run := rise * run_per_rise
	var start: Vector2 = flight["start"]
	var frame := Transform3D(Basis(Vector3.UP, -float(flight["angle"])), Vector3(start.x, 0, start.y))
	var ramp_basis := Basis(Vector3(0, 0, 1), atan2(rise, run))
	var center := Vector3(run / 2.0, (ya + yb) / 2.0, 0) - ramp_basis.y * 0.05
	km.box(Vector3(sqrt(run * run + rise * rise), 0.1, width), frame * Transform3D(ramp_basis, center),
			[null, null, null, null, null, null])
	var steps := ceili(rise / 0.2)
	for i in steps:
		var top := ya + rise * (i + 0.5) / steps
		var depth := run / steps
		km.box(Vector3(depth, top - ya, width), frame * _at(Vector3(depth * (i + 0.5), (ya + top) / 2.0, 0)),
				[tread, null, null, tread, side, side], false)
	return frame


## Within a wall's thickness (and a little) of the outline.
func _near_wall(p: Vector2) -> bool:
	var poly := outline()
	for n in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(p, poly[n], poly[(n + 1) % poly.size()])
		if closest.distance_to(p) < WALL + 0.1:
			return true
	return false
