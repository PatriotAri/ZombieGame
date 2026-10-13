@tool
class_name KitStairs
extends Node3D
## A straight staircase. It starts at the node (the middle of its bottom step)
## and climbs along +X, `rise` meters up. You walk up a hidden ramp (so do
## zombies, and the navigation mesh); the steps are what you see.
## Leave a hole in the floor above it (KitFloor pieces around it) and put a
## railing round the hole (KitBox).

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const DEFAULT_TREAD := preload("res://world/kit/materials/wood_floor.tres")
const DEFAULT_SIDE := preload("res://world/kit/materials/plaster.tres")

## How high it climbs (one floor of a Building is 3.6 m).
@export_range(0.2, 20.0, 0.05, "or_greater") var rise := 3.6:
	set(value):
		rise = value
		_changed()
## How far it runs along X. 0 = 1.6 times the rise (about 32 degrees); steeper
## than 45 degrees (run under the rise) can't be walked up.
@export_range(0.0, 40.0, 0.05, "or_greater") var run := 0.0:
	set(value):
		run = value
		_changed()
## 1.6 m or more, or zombies can't find their way up it.
@export_range(0.5, 10.0, 0.05, "or_greater") var width := 1.6:
	set(value):
		width = value
		_changed()
@export var tread_material: Material:
	set(value):
		tread_material = value
		_changed()
@export var side_material: Material:
	set(value):
		side_material = value
		_changed()

var _generated: Array[Node] = []
var _dirty := true
var _queued := false


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _dirty:
		_rebuild()


func _changed() -> void:
	_dirty = true
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	var length := run if run > 0.0 else rise * 1.6
	if length < rise:
		return PackedStringArray(["Steeper than 45 degrees: nobody can walk up it. Make Run longer than Rise."])
	return PackedStringArray()


func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	var length := run if run > 0.0 else rise * 1.6
	var tread: Material = tread_material if tread_material else DEFAULT_TREAD
	var side: Material = side_material if side_material else DEFAULT_SIDE
	var km := KitMesh.new()
	var ramp := Basis(Vector3(0, 0, 1), atan2(rise, length))
	km.box(Vector3(sqrt(length * length + rise * rise), 0.1, width),
			Transform3D(ramp, Vector3(length / 2.0, rise / 2.0, 0) - ramp.y * 0.05), [null, null, null, null, null, null])
	var steps := maxi(ceili(rise / 0.2), 1)
	for i in steps:
		var top := rise * (i + 0.5) / steps
		var depth := length / steps
		km.box(Vector3(depth, top, width), Transform3D(Basis.IDENTITY, Vector3(depth * (i + 0.5), top / 2.0, 0)),
				[tread, tread if i == steps - 1 else null, null, tread, side, side], false)
	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	km.add_to(body)
	if Engine.is_editor_hint():
		update_configuration_warnings()
