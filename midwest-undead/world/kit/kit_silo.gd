@tool
class_name KitSilo
extends StaticBody3D
## A round silo you can go into: a door at the bottom (on its -X side), an
## empty concrete floor inside, and a ladder up the wall to a hatch in the
## domed roof, which you can stand on (a lookout). Put its node on the ground
## (at the highest ground under it). Map Tools adds one (Buildings > New from
## template > Silo).

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const Door := preload("res://world/door.gd")
const GameData := preload("res://core/game_data.gd")
const LADDER := preload("res://world/props/ladder.tscn")
const FLOOR := preload("res://world/kit/materials/concrete_slab.tres")
const DEFAULT_WALL := preload("res://world/kit/materials/concrete_block.tres")
const DEFAULT_ROOF := preload("res://world/kit/materials/metal_gray.tres")
const SEGMENTS := 20
const WALL := 0.25
const DOOR_HEIGHT := 2.3
const CLIMB_REACH := 1.0 # how far out from the ladder you can be and still climb

@export_range(2.0, 8.0, 0.1) var radius := 3.0:
	set(value):
		radius = value
		_changed()
@export_range(4.0, 30.0, 0.5) var height := 12.0:
	set(value):
		height = value
		_changed()
## How high the dome rises over the top of the wall.
@export_range(0.5, 4.0, 0.1) var dome := 1.8:
	set(value):
		dome = value
		_changed()
@export var wall_material: Material:
	set(value):
		wall_material = value
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


## Builds it now if anything changed (main.gd calls this before the map's doors
## are looked for; in the game it's built once: its door moves away after).
func ensure_built() -> void:
	if _dirty:
		_rebuild()


func _changed() -> void:
	_dirty = true
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


## Segment i's middle angle; the door is in segments 0 and SEGMENTS - 1 (round -X).
func _angle(i: float) -> float:
	return PI + (i + 0.5) * TAU / SEGMENTS


func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	var wall := wall_material if wall_material else DEFAULT_WALL
	var roof := roof_material if roof_material else DEFAULT_ROOF
	var km := KitMesh.new()
	var chord := 2.0 * (radius + WALL / 2.0) * sin(PI / SEGMENTS) + 0.02
	var mid_r := radius + WALL / 2.0
	for i in SEGMENTS:
		var a := _angle(i)
		var basis := Basis(Vector3.UP, -a) # its X out from the middle
		var at := Vector3(cos(a), 0, sin(a)) * mid_r
		var door := i == 0 or i == SEGMENTS - 1
		var bottom := DOOR_HEIGHT if door else 0.0
		km.box(Vector3(WALL, height - bottom, chord), Transform3D(basis, at + Vector3(0, (height + bottom) / 2.0, 0)), KitMesh.all(wall))
	# The floor.
	var rim := PackedVector2Array()
	for i in SEGMENTS:
		var a := _angle(i) - PI / SEGMENTS
		rim.append(Vector2(cos(a), sin(a)) * (radius + WALL))
	if KitMesh._area(rim) > 0.0:
		rim.reverse()
	km.slab(rim, [], 0.1, 0.3, FLOOR, null, wall, null)
	# The dome: a shallow cone, each segment's slice, but the ladder's: an
	# opening (the hatch) from the rim partway up.
	var top := Vector3(0, height + dome, 0)
	var ladder_i := SEGMENTS / 2 # straight across from the door
	for i in SEGMENTS:
		var a0 := _angle(i) - PI / SEGMENTS
		var a1 := _angle(i) + PI / SEGMENTS
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (radius + WALL + 0.2) + Vector3(0, height - 0.12, 0)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (radius + WALL + 0.2) + Vector3(0, height - 0.12, 0)
		var face: PackedVector3Array
		if i == ladder_i:
			face = PackedVector3Array([p0.lerp(top, 0.45), p1.lerp(top, 0.45), top])
		else:
			face = PackedVector3Array([p0, p1, top])
		if (face[1] - face[0]).cross(face[2] - face[0]).y < 0.0:
			face = PackedVector3Array([face[1], face[0], face[2]])
		km.plate(face, 0.1, roof, roof, roof)
	_generated = km.add_to(self)
	# The ladder up the inside of the wall under the hatch, and its climbing area.
	var la := _angle(ladder_i)
	var inward := -Vector3(cos(la), 0, sin(la))
	var foot := -inward * (radius - 0.15)
	var ladder_basis := Basis(Vector3.UP, atan2(inward.x, inward.z)) # its +Z inward
	var look := KitProp.make(LADDER, [], Vector3(0.56, height + 0.6, 0.06), Vector3(0, (height + 0.6) / 2.0, 0))
	look.transform = Transform3D(ladder_basis, foot)
	add_child(look, false, Node.INTERNAL_MODE_BACK)
	_generated.append(look)
	if not Engine.is_editor_hint():
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = GameData.LAYER_PLAYER
		area.set_meta("top_y", height + 0.3) # (in the area's space: set below once it's placed)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, height + 1.0, CLIMB_REACH)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0, (height + 1.0) / 2.0, CLIMB_REACH / 2.0)
		area.add_child(col)
		area.transform = Transform3D(ladder_basis, foot)
		area.body_entered.connect(func(body: Node3D) -> void:
			if body.has_method("enter_ladder"):
				body.call("enter_ladder", area))
		area.body_exited.connect(func(body: Node3D) -> void:
			if body.has_method("exit_ladder"):
				body.call("exit_ladder", area))
		add_child(area, false, Node.INTERNAL_MODE_BACK)
		_generated.append(area)
		area.ready.connect(func() -> void: area.set_meta("top_y", global_position.y + height + 0.3), CONNECT_ONE_SHOT)
	# The door, across the gap.
	var door := Door.new()
	var width := chord * 2.0 - 0.1
	var hinge := Vector3(-mid_r * cos(PI / SEGMENTS), 0.1, -width / 2.0)
	door.setup(Vector3(0.08, DOOR_HEIGHT - 0.12, width - 0.05), Vector3(0, (DOOR_HEIGHT - 0.12) / 2.0, (width - 0.05) / 2.0),
			Color(0.4, 0.42, 0.42), Transform3D(Basis.IDENTITY, hinge), PI / 2.0)
	door.name = "Door"
	add_child(door, false, Node.INTERNAL_MODE_BACK)
	_generated.append(door)
