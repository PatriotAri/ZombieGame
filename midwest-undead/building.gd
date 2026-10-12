extends Node3D
## One storefront you can walk into: a hollow shell with a doorway and big windows
## on the street side, windows at the back, a ceiling, a solid upper floor with
## decorative windows on taller buildings, and some searchable furniture inside.
##
## Local axes: x = 0 is the street face and +x goes into the building;
## z runs along the street; y is up. main.gd rotates the node so +x points away
## from Main Street on either side.

const GameData := preload("res://game_data.gd")
const LootSpot := preload("res://loot_spot.gd")
const Door := preload("res://door.gd")

const WALL := 0.2
## Default floor height: matches the sidewalk, so you step straight in from it.
## Buildings standing on bare ground pass floor_y = 0.02 to build() instead;
## a 10 cm ledge at the door is a wall as far as character physics is concerned.
const SIDEWALK_FLOOR_Y := 0.1
const CEILING_Y := 3.4
const WALL_TOP := CEILING_Y + 0.2 # walls stop at the top of the ceiling slab
const DOOR_WIDTH := 1.6 # wide enough that the navmesh still fits a zombie through
const DOOR_TOP := 2.5
const BOARDED_CHANCE := 0.3

const FLOOR_COLOR := Color(0.33, 0.27, 0.2)
const CEILING_COLOR := Color(0.32, 0.32, 0.3)
const WOOD := Color(0.42, 0.3, 0.18)
const GLASS := Color(0.55, 0.65, 0.7, 0.22)
const DARK_WINDOW := Color(0.05, 0.06, 0.08)
const DOOR_COLOR := Color(0.36, 0.24, 0.14)

var loot_spots: Array = [] # containers inside, for main.gd to fill
var interior_points: Array[Vector3] = [] # global spots inside where a zombie could stand
var door_z := 0.0 # local z of the doorway's center
var _rng: RandomNumberGenerator
var _boarded_chance := BOARDED_CHANCE
var FLOOR_Y := SIDEWALK_FLOOR_Y # top of the floor slab for this building (set in build())


func build(depth: float, width: float, height: float, color: Color, rng: RandomNumberGenerator,
		furnish := true, boarded_chance := BOARDED_CHANCE, floor_y := SIDEWALK_FLOOR_Y) -> void:
	_rng = rng
	FLOOR_Y = floor_y
	_boarded_chance = boarded_chance
	var half := width / 2.0

	# Floor and ceiling cover the whole footprint.
	_solid(Vector3(depth, FLOOR_Y, width), Vector3(depth / 2.0, FLOOR_Y / 2.0, 0), FLOOR_COLOR)
	_solid(Vector3(depth, 0.2, width), Vector3(depth / 2.0, CEILING_Y + 0.1, 0), CEILING_COLOR)

	# Side walls: neighbouring buildings are right next door, so no openings.
	for s: int in [-1, 1]:
		_solid(Vector3(depth, WALL_TOP, WALL), Vector3(depth / 2.0, WALL_TOP / 2.0, s * (half - WALL / 2.0)), color)

	# Street side: doorway near the middle, a big shop window on each side of it.
	door_z = _rng.randf_range(-width * 0.15, width * 0.15)
	var door_start := door_z - DOOR_WIDTH / 2.0
	var door_end := door_z + DOOR_WIDTH / 2.0
	var front: Array[Dictionary] = []
	_maybe_window(front, -half + WALL + 0.4, door_start - 0.4, 1.0, 2.7)
	front.append({"start": door_start, "end": door_end, "bottom": FLOOR_Y, "top": DOOR_TOP, "kind": "door"})
	_maybe_window(front, door_end + 0.4, half - WALL - 0.4, 1.0, 2.7)
	_wall(0.0, width, front, color)

	# Back side: one or two smaller windows looking out over the field.
	var back: Array[Dictionary] = []
	if width > 10.0:
		_maybe_window(back, -width * 0.3 - 0.6, -width * 0.3 + 0.6, 1.2, 2.4)
		_maybe_window(back, width * 0.3 - 0.6, width * 0.3 + 0.6, 1.2, 2.4)
	else:
		_maybe_window(back, -0.7, 0.7, 1.2, 2.4)
	_wall(depth - WALL, width, back, color)

	# Upper floors: a solid block (not enterable) with dark windows painted on the front.
	var upper := height - WALL_TOP
	if upper > 0.5:
		_solid(Vector3(depth, upper, width), Vector3(depth / 2.0, WALL_TOP + upper / 2.0, 0), color)
		if upper > 1.8:
			var count := int((width - 1.0) / 2.6)
			for i in count:
				var z := -half + 0.5 + 2.6 * (i + 0.5) + ((width - 1.0) - 2.6 * count) / 2.0
				var boarded := _rng.randf() < _boarded_chance
				_decor(Vector3(0.04, 1.3, 1.1), Vector3(-0.02, WALL_TOP + upper / 2.0, z),
						WOOD if boarded else DARK_WINDOW)

	if furnish:
		_furnish(depth, width)


## Searchable furniture, plus a couple of spots where a zombie might be waiting.
func _furnish(depth: float, width: float) -> void:
	var half := width / 2.0
	var counter_len := minf(3.0, width * 0.3)
	# Keep the counter out of line with the door so the entrance isn't blocked.
	var counter_z := -door_z * 0.8
	_add_loot(Vector3(0.8, 1.0, counter_len), Vector3(depth * 0.4, FLOOR_Y + 0.5, counter_z), WOOD, "Counter")

	var shelf_len := minf(4.0, depth * 0.35)
	for s: int in [-1, 1]:
		if s == -1 or _rng.randf() < 0.6:
			_add_loot(Vector3(shelf_len, 1.8, 0.5),
					Vector3(depth * 0.68, FLOOR_Y + 0.9, s * (half - WALL - 0.35)),
					Color(0.5, 0.5, 0.48), "Shelf")

	for p: Vector3 in [Vector3(depth * 0.25, FLOOR_Y, half * 0.4), Vector3(depth * 0.8, FLOOR_Y, -half * 0.3)]:
		interior_points.append(transform * p)


## A door for the doorway, hinged on its left edge (seen from the street) and
## swinging inward. Not added to the tree: main.gd puts it outside the
## navigation region so zombie paths still run through the doorway.
func make_door() -> Door:
	var thickness := 0.08
	var height := DOOR_TOP - FLOOR_Y - 0.02
	var leaf := Vector3(thickness, height, DOOR_WIDTH - 0.1)
	# The hinge sits in the middle of the wall at the doorway's edge; the panel
	# runs along +z from it, so turning +90 degrees swings it into the room (+x).
	var hinge := Vector3(WALL / 2.0, FLOOR_Y, door_z - DOOR_WIDTH / 2.0)
	var door := Door.new()
	door.setup(leaf, Vector3(0.0, height / 2.0, DOOR_WIDTH / 2.0), DOOR_COLOR,
			transform * Transform3D(Basis.IDENTITY, hinge), PI / 2.0)
	return door


## Adds a window opening covering [z_from, z_to] if there's room for one.
func _maybe_window(list: Array[Dictionary], z_from: float, z_to: float, bottom: float, top: float) -> void:
	var length := z_to - z_from
	if length < 1.0:
		return
	var w := minf(length, 2.6)
	var center := (z_from + z_to) / 2.0
	list.append({"start": center - w / 2.0, "end": center + w / 2.0, "bottom": bottom, "top": top, "kind": "window"})


## A wall in the plane x..x+WALL spanning the full width, with holes cut for each
## opening. Built from boxes: solid columns between openings, plus a piece below and
## above each opening. Windows get glass (or boards); doorways stay open.
func _wall(x: float, width: float, openings: Array[Dictionary], color: Color) -> void:
	var cx := x + WALL / 2.0
	var cursor := -width / 2.0
	for op in openings:
		var start: float = op["start"]
		var end: float = op["end"]
		var bottom: float = op["bottom"]
		var top: float = op["top"]
		var length := end - start
		var mid := (start + end) / 2.0
		if start > cursor:
			_solid(Vector3(WALL, WALL_TOP, start - cursor), Vector3(cx, WALL_TOP / 2.0, (cursor + start) / 2.0), color)
		if bottom > FLOOR_Y + 0.01:
			_solid(Vector3(WALL, bottom, length), Vector3(cx, bottom / 2.0, mid), color)
		_solid(Vector3(WALL, WALL_TOP - top, length), Vector3(cx, (top + WALL_TOP) / 2.0, mid), color)
		if op["kind"] == "window":
			var size := Vector3(0.06, top - bottom, length)
			var pos := Vector3(cx, (bottom + top) / 2.0, mid)
			if _rng.randf() < _boarded_chance:
				_solid(Vector3(0.1, size.y, size.z), pos, WOOD)
			else:
				_glass(size, pos)
		cursor = end
	if cursor < width / 2.0:
		_solid(Vector3(WALL, WALL_TOP, width / 2.0 - cursor), Vector3(cx, WALL_TOP / 2.0, (cursor + width / 2.0) / 2.0), color)


## Glass blocks movement but not sight or bullets: it lives on its own collision
## layer, which bodies collide with but the sight and shooting rays ignore.
func _glass(size: Vector3, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GLASS
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	var body := _body(size, pos, mat)
	body.collision_layer = GameData.LAYER_GLASS
	(body.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # let sunlight in


func _solid(size: Vector3, pos: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_body(size, pos, mat)


func _body(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = box
	body.add_child(inst)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


## Visual only, no collision.
func _decor(size: Vector3, pos: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = pos
	add_child(inst)


func _add_loot(size: Vector3, pos: Vector3, color: Color, label: String) -> void:
	var spot := LootSpot.new()
	spot.position = pos
	spot.setup(size, color, label)
	add_child(spot)
	loot_spots.append(spot)
