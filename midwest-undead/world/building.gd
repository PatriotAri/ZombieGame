@tool
class_name KitBuilding
extends Node3D
## A building you can walk into, made from its settings: change its size,
## floors, openings or materials in the Inspector and it rebuilds right away,
## in the editor and in the game. See HOW_TO_BUILD.md.
##
## Local axes: x = 0 is the front wall (the street side) and +x goes into the
## building; z runs along the front; y is up from the ground. Every floor has
## walls on all four sides, with the doorways and windows in Openings cut into
## them. Each floor above the ground is reached by a staircase along a side wall
## (alternating sides going up). Over the top floor sits either a flat roof or,
## with Upper Height, a solid block you can't enter, with painted-on windows.
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
const STAIR_START := 1.5 # how far back from the front wall a staircase starts
const STAIR_RUN_PER_RISE := 1.6 # about 32 degrees
const LANDING := 1.0 # floor needed past the top of a staircase
const PAINTED_WINDOW := Vector3(0.04, 1.3, 1.1)
const PAINTED_SPACING := 2.6

const DEFAULT_EXTERIOR := preload("res://world/kit/materials/siding_white.tres")
const DEFAULT_INTERIOR := preload("res://world/kit/materials/plaster.tres")
const DEFAULT_FLOOR := preload("res://world/kit/materials/wood_floor.tres")
const DEFAULT_CEILING := preload("res://world/kit/materials/ceiling_tiles.tres")
const DEFAULT_ROOF := preload("res://world/kit/materials/roof_tar.tres")
const WINDOW_DARK := preload("res://world/kit/materials/window_dark.tres")
const BOARDS := preload("res://world/kit/materials/wood_planks.tres")

@export_group("Size")
## How far back from the front wall it goes (local +x), in meters.
@export_range(2.0, 100.0, 0.1, "or_greater") var size_depth := 10.0:
	set(value):
		size_depth = value
		_changed()
## Along the front wall (local z), in meters.
@export_range(2.0, 100.0, 0.1, "or_greater") var size_width := 10.0:
	set(value):
		size_width = value
		_changed()
## Floors you can walk around on. Each one above the ground gets a staircase.
@export_range(1, 20) var floors := 1:
	set(value):
		floors = maxi(value, 1)
		_changed()
## The ground floor's height above the node: 0.1 on a sidewalk, 0.02 on bare ground.
@export_range(0.0, 1.0, 0.01) var floor_y := SIDEWALK_FLOOR_Y:
	set(value):
		floor_y = value
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
		for op in openings:
			if op and op.changed.is_connected(_changed):
				op.changed.disconnect(_changed)
		openings = value
		for op in openings:
			if op and not op.changed.is_connected(_changed):
				op.changed.connect(_changed)
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
## The side wall the first staircase runs along (seen from outside); the next
## one up runs along the other side, and so on.
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

var _generated: Array[Node] = []
var _dirty := true
var _queued := false


func _ready() -> void:
	ensure_built()


## Builds it now if anything changed (main.gd calls this before the town is in
## the tree, so the doors and windows exist when it looks for them).
func ensure_built() -> void:
	if _dirty:
		_rebuild()


## Its corners on the ground (world x, z), for the map screen.
func ground_corners() -> PackedVector2Array:
	var half := size_width / 2.0
	var corners := PackedVector2Array()
	for corner: Vector3 in [Vector3(0, 0, -half), Vector3(size_depth, 0, -half),
			Vector3(size_depth, 0, half), Vector3(0, 0, half)]:
		var world := global_transform * corner
		corners.append(Vector2(world.x, world.z))
	return corners


## Local z of the middle of the ground-floor front door (0 if there isn't one).
func front_door_z() -> float:
	for op in openings:
		if op and op.kind == "door" and op.wall == "front" and op.level == 0:
			return op.offset
	return 0.0


## Height of a floor's surface above the node.
func floor_top(level: int) -> float:
	return floor_y if level == 0 else level * STOREY


func default_openings() -> void:
	var list: Array[KitOpening] = []
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
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		# Through the editor's undo history, so Ctrl+Z puts the old ones back.
		var undo: Object = Engine.get_singleton("EditorInterface").call("get_editor_undo_redo")
		undo.call("create_action", "Default Openings")
		undo.call("add_do_property", self, "openings", list)
		undo.call("add_undo_property", self, "openings", openings)
		undo.call("commit_action")
	else:
		openings = list


func _changed() -> void:
	_dirty = true
	# In the game a building is built once (doors move away from it after that);
	# in the editor it follows every change.
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for k in floors - 1:
		if not _stairs_fit(k):
			warnings.append("Too shallow for the staircase to floor %d: it needs %.1f m of depth." % [k + 1, _stairs_needs(k)])
	for op in openings:
		if op == null:
			continue
		var length := size_width if op.wall in ["front", "back"] else size_depth
		if absf(op.offset) + op.width / 2.0 > length / 2.0 - WALL or op.top > STOREY - 0.25 or op.bottom < 0.0:
			warnings.append("An opening on the %s wall (floor %d) doesn't fit in the wall." % [op.wall, op.level])
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
	var d := size_depth
	var w := size_width
	var half := w / 2.0
	var km := KitMesh.new()
	var made: Array[Node] = [] # glass and doors, added once the shell is in

	if floor_y > 0.001:
		km.box(Vector3(d, floor_y, w), _at(Vector3(d / 2.0, floor_y / 2.0, 0)), [null, null, null, floor_mat, null, null])
	for k in floors:
		var y0 := k * STOREY
		var y1 := (k + 1) * STOREY
		var fy := floor_top(k)
		for wall_name: String in ["front", "back", "left", "right"]:
			var list := []
			for op in openings:
				if op and op.wall == wall_name and op.level == k:
					list.append({"kind": op.kind, "along": op.offset, "width": op.width, "bottom": fy + op.bottom,
							"top": fy + op.top, "boarded_up": op.boarded_up, "source": op})
			var frame := _wall_frame(wall_name)
			km.wall(frame, w if wall_name in ["front", "back"] else d, y0, y1, fy, list, ext, inside)
			made.append_array(_opening_nodes(wall_name, k, list, fy))
		# The slab over this floor: its ceiling, and the next floor's floor (with
		# a hole where the staircase comes up).
		var upstairs := k + 1 < floors
		var hole := _stairs_hole(k) if upstairs and _stairs_fit(k) else Rect2()
		_slab(km, y1, hole, floor_mat if upstairs else roof, ceiling, inside)
		if hole.has_area():
			_stairs(km, k, floor_mat, inside)
	if upper_height > 0.0:
		var top := floors * STOREY
		km.box(Vector3(d, upper_height, w), _at(Vector3(d / 2.0, top + upper_height / 2.0, 0)), [ext, ext, null, roof, ext, ext])
		if painted_windows and upper_height > 1.8:
			var count := int((w - 1.0) / PAINTED_SPACING)
			for i in count:
				var z := -half + 0.5 + PAINTED_SPACING * (i + 0.5) + ((w - 1.0) - PAINTED_SPACING * count) / 2.0
				var mat: Material = BOARDS if i in boarded_painted_windows else WINDOW_DARK
				km.box(PAINTED_WINDOW, _at(Vector3(-PAINTED_WINDOW.x / 2.0, top + upper_height / 2.0, z)),
						[mat, null, mat, mat, mat, mat], false)

	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	km.add_to(body)
	for node in made:
		add_child(node, false, Node.INTERNAL_MODE_BACK)
		_generated.append(node)
	if Engine.is_editor_hint():
		update_configuration_warnings()


static func _at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)


## A wall's frame (see kit_mesh.gd): its middle at the foot, outside toward -X,
## running along +Z (to the right, seen from outside).
func _wall_frame(wall_name: String) -> Transform3D:
	var half := size_width / 2.0
	match wall_name:
		"back":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(size_depth - WALL / 2.0, 0, 0))
		"left":
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(size_depth / 2.0, 0, -(half - WALL / 2.0)))
		"right":
			return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(size_depth / 2.0, 0, half - WALL / 2.0))
	return Transform3D(Basis.IDENTITY, Vector3(WALL / 2.0, 0, 0))


## Glass and doors for one wall of one floor, named for saving ("FrontDoor",
## "BackWindow2", "Floor2FrontWindow"...). Only the ground floor's can be boarded up.
func _opening_nodes(wall_name: String, level: int, list: Array, fy: float) -> Array[Node]:
	var nodes: Array[Node] = []
	var counts := {"door": 0, "window": 0}
	var prefix := ("Floor%d" % (level + 1) if level > 0 else "") + wall_name.capitalize()
	for entry: Dictionary in list: # sorted along the wall by km.wall()
		var op: KitOpening = entry["source"]
		if op.kind == "doorway":
			continue # just a gap
		counts[op.kind] += 1
		var n: int = counts[op.kind]
		var node_name: String = prefix + op.kind.capitalize() + (str(n) if n > 1 else "")
		if op.kind == "door":
			var door := KitMesh.make_door(entry, op.door_color)
			door.name = node_name
			door.start_open = op.start_open
			door.boardable = level == 0
			door.boarded_at_start = op.boarded_at_start and level == 0
			nodes.append(door)
		elif not op.boarded_up:
			var frame: Transform3D = entry["frame"]
			var pane := KitMesh.make_window(entry, level == 0, op.boarded_at_start and level == 0, frame.origin.y - fy)
			pane.name = node_name
			nodes.append(pane)
	return nodes


## A 0.2 m slab with its top at `top` over the whole footprint, minus `hole`
## (x, z). Edges show only around the hole (the walls cover the rest).
func _slab(km: KitMesh, top: float, hole: Rect2, top_mat: Material, bottom_mat: Material, edge_mat: Material) -> void:
	var d := size_depth
	var half := size_width / 2.0
	var pieces: Array[Rect2] = []
	if not hole.has_area():
		pieces.append(Rect2(0, -half, d, size_width))
	else:
		pieces.append(Rect2(0, -half, hole.position.x, size_width))
		pieces.append(Rect2(hole.end.x, -half, d - hole.end.x, size_width))
		pieces.append(Rect2(hole.position.x, -half, hole.size.x, hole.position.y + half))
		pieces.append(Rect2(hole.position.x, hole.end.y, hole.size.x, half - hole.end.y))
	for r in pieces:
		if r.size.x <= 0.001 or r.size.y <= 0.001:
			continue
		var faces := [
			edge_mat if r.position.x > 0.001 else null, edge_mat if r.end.x < d - 0.001 else null,
			bottom_mat, top_mat,
			edge_mat if r.position.y > -half + 0.001 else null, edge_mat if r.end.y < half - 0.001 else null,
		]
		km.box(Vector3(r.size.x, 0.2, r.size.y), _at(Vector3(r.get_center().x, top - 0.1, r.get_center().y)), faces)


## Which side wall flight k (floor k to k+1) runs along: -1 left (-z), +1 right.
func _stairs_sign(k: int) -> float:
	var first := -1.0 if stairs_side == "left" else 1.0
	return first if k % 2 == 0 else -first


func _stairs_rise(k: int) -> float:
	return (k + 1) * STOREY - floor_top(k)


func _stairs_needs(k: int) -> float:
	return STAIR_START + _stairs_rise(k) * STAIR_RUN_PER_RISE + LANDING + WALL


func _stairs_fit(k: int) -> bool:
	return size_depth >= _stairs_needs(k) and size_width >= STAIR_WIDTH + 2.0 * WALL + 1.0


## The hole flight k comes up through, in the slab over floor k: (x, z), out to the side wall.
func _stairs_hole(k: int) -> Rect2:
	var s := _stairs_sign(k)
	var half := size_width / 2.0
	var x0 := STAIR_START
	var run := _stairs_rise(k) * STAIR_RUN_PER_RISE
	var inner := s * (half - WALL - STAIR_WIDTH) # the room-side edge
	var z0 := minf(inner, s * half)
	var z1 := maxf(inner, s * half)
	return Rect2(x0, z0, run, z1 - z0)


## Flight k: a ramp to walk on (and for the navigation mesh), steps to look at,
## and a railing round the hole upstairs.
func _stairs(km: KitMesh, k: int, tread: Material, side: Material) -> void:
	var s := _stairs_sign(k)
	var half := size_width / 2.0
	var ya := floor_top(k)
	var yb := (k + 1) * STOREY
	var rise := yb - ya
	var run := rise * STAIR_RUN_PER_RISE
	var x0 := STAIR_START
	var zc := s * (half - WALL - STAIR_WIDTH / 2.0)
	var angle := atan2(rise, run)
	var ramp_basis := Basis(Vector3(0, 0, 1), angle)
	var center := Vector3(x0 + run / 2.0, (ya + yb) / 2.0, zc) - ramp_basis.y * 0.05
	km.box(Vector3(sqrt(run * run + rise * rise), 0.1, STAIR_WIDTH), Transform3D(ramp_basis, center),
			[null, null, null, null, null, null])
	var steps := ceili(rise / 0.2)
	for i in steps:
		var top := ya + rise * (i + 0.5) / steps
		var depth := run / steps
		km.box(Vector3(depth, top - ya, STAIR_WIDTH), _at(Vector3(x0 + depth * (i + 0.5), (ya + top) / 2.0, zc)),
				[tread, null, null, tread, tread, tread], false)
	# Railing upstairs: along the room side of the hole, and across its low end.
	var inner := s * (half - WALL - STAIR_WIDTH)
	km.box(Vector3(run, 1.0, 0.06), _at(Vector3(x0 + run / 2.0, yb + 0.5, inner - s * 0.03)), KitMesh.all(side))
	var hole_len := half - absf(inner)
	km.box(Vector3(0.06, 1.0, hole_len), _at(Vector3(x0 - 0.03, yb + 0.5, s * (absf(inner) + hole_len / 2.0))), KitMesh.all(side))
