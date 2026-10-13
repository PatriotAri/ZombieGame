@tool
class_name KitFloor
extends Node3D
## A flat slab: a floor, a ceiling, a flat roof, a porch. Its top is at the
## node's height, and it reaches `size` along +X and +Z from the node (so the
## node sits on a corner, handy with snapping).

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const DEFAULT_TOP := preload("res://world/kit/materials/wood_floor.tres")
const DEFAULT_BOTTOM := preload("res://world/kit/materials/ceiling_tiles.tres")
const DEFAULT_EDGE := preload("res://world/kit/materials/plaster.tres")

## Along X and Z, in meters.
@export var size := Vector2(4.0, 4.0):
	set(value):
		size = value
		_changed()
@export_range(0.02, 2.0, 0.01) var thickness := 0.2:
	set(value):
		thickness = value
		_changed()
@export var top_material: Material:
	set(value):
		top_material = value
		_changed()
@export var bottom_material: Material:
	set(value):
		bottom_material = value
		_changed()
@export var edge_material: Material:
	set(value):
		edge_material = value
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


func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	var edge: Material = edge_material if edge_material else DEFAULT_EDGE
	var km := KitMesh.new()
	km.box(Vector3(size.x, thickness, size.y), Transform3D(Basis.IDENTITY, Vector3(size.x / 2.0, -thickness / 2.0, size.y / 2.0)),
			[edge, edge, bottom_material if bottom_material else DEFAULT_BOTTOM, top_material if top_material else DEFAULT_TOP, edge, edge])
	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	km.add_to(body)
