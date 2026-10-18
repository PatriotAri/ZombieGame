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
## Openings cut into them. Floors above the ground are reached by the flights
## in Stairs (a rectangle with none gets one along a side wall per floor,
## alternating sides going up). Over the top floor sits either a flat roof or,
## with Upper Height, a solid block you can't enter, with painted-on windows.
##
## On uneven ground it stands on a foundation down to the ground all round
## (Foundation: concrete block, stone or wooden posts), made from the terrain
## under it; move it and the foundation follows.
##
## What it makes (walls, floors, glass, doors) isn't saved in the scene: it's
## made fresh from the settings every time. Furniture, containers and markers
## you put under the building are yours and are saved as usual.

const KitMesh := preload("res://world/kit/kit_mesh.gd")

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


## Local z of the middle of the ground-floor front door (0 if there isn't one).
## (A rectangle's; for any shape, outside_front_door().)
func front_door_z() -> float:
	for op in openings:
		if op and op.kind == "door" and edge_of(op) == 0 and op.level == 0:
			return op.offset
	return 0.0


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


## Height of a floor's surface above the node.
func floor_top(level: int) -> float:
	return floor_y if level == 0 else level * STOREY


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


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if footprint.size() > 0 and footprint.size() < 3:
		warnings.append("The drawn outline needs at least 3 corners (it's using the Size rectangle until then).")
	elif footprint.size() >= 3 and not Geometry2D.triangulate_polygon(footprint).size():
		warnings.append("The drawn outline crosses itself: draw it again going round once.")
	for k in floors - 1:
		if not _flights().any(func(f: Dictionary) -> bool: return f["level"] == k):
			warnings.append("Nothing goes up from floor %d to floor %d: place stairs (Map Tools, Buildings)." % [k, k + 1] if footprint.size() >= 3 or not stairs.is_empty()
					else "Too shallow for the staircase to floor %d: it needs %.1f m of depth." % [k + 1, _stairs_needs(k)])
	for flight in _flights():
		if flight["level"] >= floors - 1:
			warnings.append("A staircase starts on floor %d, but the building has %d floor(s)." % [flight["level"], floors])
		elif not _flight_fits(flight):
			warnings.append("A staircase on floor %d doesn't fit inside the building (it needs %.1f m of room ahead of its bottom step)." % [flight["level"], _run(flight["level"]) + LANDING])
	for op in openings:
		if op == null:
			continue
		var n := edge_of(op)
		if n >= edge_count():
			warnings.append("An opening is on wall %d, but the building has %d walls." % [n, edge_count()])
			continue
		var ends := edge_ends(n)
		var length := ends[0].distance_to(ends[1])
		if absf(op.offset) + op.width / 2.0 > length / 2.0 - WALL or op.top > STOREY - 0.25 or op.bottom < 0.0:
			warnings.append("An opening on wall %d (floor %d) doesn't fit in the wall." % [n, op.level])
		if op.level >= floors:
			warnings.append("An opening is on floor %d, but the building has %d floor(s)." % [op.level, floors])
	return warnings


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
	var flights := _flights().filter(func(f: Dictionary) -> bool: return f["level"] < floors - 1 and _flight_fits(f))

	if floor_y > 0.001:
		km.slab(poly, [], floor_y, floor_y, floor_mat, null, null, null)
	for k in floors:
		var y0 := k * STOREY
		var y1 := (k + 1) * STOREY
		var fy := floor_top(k)
		for n in poly.size():
			var ends := edge_ends(n)
			var list := []
			for op in openings:
				if op and edge_of(op) == n and op.level == k:
					list.append({"kind": op.kind, "along": op.offset, "width": op.width, "bottom": fy + op.bottom,
							"top": fy + op.top, "boarded_up": op.boarded_up, "source": op})
			km.wall(_wall_frame(n), ends[0].distance_to(ends[1]), y0, y1, fy, list, ext, inside)
			made.append_array(_opening_nodes(n, k, list, fy))
		# The slab over this floor: its ceiling, and the next floor's floor (with
		# holes where staircases come up).
		var upstairs := k + 1 < floors
		var here := flights.filter(func(f: Dictionary) -> bool: return f["level"] == k)
		var holes := here.map(func(f: Dictionary) -> Dictionary: return _hole(f))
		km.slab(poly, holes, y1, 0.2, floor_mat if upstairs else roof, ceiling, null, inside)
		for flight in here:
			_stairs(km, flight, floor_mat, inside)
	if upper_height > 0.0:
		_upper_block(km, poly, ext, roof)

	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	km.add_to(body)
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


## Glass and doors for one wall of one floor, named for saving ("FrontDoor",
## "BackWindow2", "Floor2FrontWindow", "Wall5Door"...). Only the ground floor's
## can be boarded up.
func _opening_nodes(n: int, level: int, list: Array, fy: float) -> Array[Node]:
	var nodes: Array[Node] = []
	var counts := {"door": 0, "window": 0}
	var wall_name := "Wall%d" % n
	if footprint.size() < 3:
		wall_name = WALL_NUMBERS.find_key(n).capitalize()
	var prefix := ("Floor%d" % (level + 1) if level > 0 else "") + wall_name
	for entry: Dictionary in list: # sorted along the wall by km.wall()
		var op: KitOpening = entry["source"]
		if op.kind == "doorway":
			continue # just a gap
		counts[op.kind] += 1
		var count: int = counts[op.kind]
		var node_name: String = prefix + op.kind.capitalize() + (str(count) if count > 1 else "")
		if op.kind == "door":
			var door := KitMesh.make_door(entry, op.door_color, door_models)
			door.name = node_name
			door.start_open = op.start_open
			door.boardable = level == 0
			door.boarded_at_start = op.boarded_at_start and level == 0
			nodes.append(door)
		elif not op.boarded_up:
			var frame: Transform3D = entry["frame"]
			var pane := KitMesh.make_window(entry, level == 0, op.boarded_at_start and level == 0, frame.origin.y - fy, window_models)
			pane.name = node_name
			nodes.append(pane)
	return nodes


# --- Stairs ------------------------------------------------------------------------
# A flight: {"level", "start" (x, z of its bottom step's middle), "angle"
# (radians it climbs toward, from +x toward +z)}.

## The flights: Stairs, or a rectangle's own (one per floor, along a side wall).
func _flights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not stairs.is_empty() or footprint.size() >= 3:
		for stair in stairs:
			if stair:
				result.append({"level": stair.level, "start": stair.start, "angle": deg_to_rad(stair.direction)})
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
	return (k + 1) * STOREY - floor_top(k)


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
	var ya := floor_top(k)
	var yb := (k + 1) * STOREY
	var rise := yb - ya
	var run := rise * STAIR_RUN_PER_RISE
	var start: Vector2 = flight["start"]
	var frame := Transform3D(Basis(Vector3.UP, -float(flight["angle"])), Vector3(start.x, 0, start.y))
	var angle := atan2(rise, run)
	var ramp_basis := Basis(Vector3(0, 0, 1), angle)
	var center := Vector3(run / 2.0, (ya + yb) / 2.0, 0) - ramp_basis.y * 0.05
	km.box(Vector3(sqrt(run * run + rise * rise), 0.1, STAIR_WIDTH), frame * Transform3D(ramp_basis, center),
			[null, null, null, null, null, null])
	var steps := ceili(rise / 0.2)
	for i in steps:
		var top := ya + rise * (i + 0.5) / steps
		var depth := run / steps
		km.box(Vector3(depth, top - ya, STAIR_WIDTH), frame * _at(Vector3(depth * (i + 0.5), (ya + top) / 2.0, 0)),
				[tread, null, null, tread, tread, tread], false)
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


## Within a wall's thickness (and a little) of the outline.
func _near_wall(p: Vector2) -> bool:
	var poly := outline()
	for n in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(p, poly[n], poly[(n + 1) % poly.size()])
		if closest.distance_to(p) < WALL + 0.1:
			return true
	return false
