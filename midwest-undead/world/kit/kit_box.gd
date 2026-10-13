@tool
class_name KitBox
extends StaticBody3D
## A plain solid box in a material: a fence panel, a counter, a pole, a road.
## Made fresh from its settings (in the editor too). Untick Solid for something
## you can walk through (a decoration).

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const DEFAULT_MATERIAL := preload("res://world/kit/materials/concrete_slab.tres")

## In meters; the box is centered on the node (see Sits On Floor).
@export var size := Vector3(1.0, 1.0, 1.0):
	set(value):
		size = value
		_changed()
@export var material: Material:
	set(value):
		material = value
		_changed()
## The node is at the bottom of the box instead of its middle: put it on a floor
## and the box stands on it. (The kit's furniture scenes have this on.)
@export var sits_on_floor := false:
	set(value):
		sits_on_floor = value
		_changed()
## Blocks movement (and zombie paths). Off: just something to look at.
@export var solid := true:
	set(value):
		solid = value
		_changed()

var _generated: Array[Node] = []
var _dirty := true
var _queued := false


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _dirty:
		_rebuild()


## Darker from now on (a stripped bed: world/salvage.gd).
func darken(amount: float) -> void:
	for node in _generated:
		if node is MeshInstance3D:
			KitMesh.darken(node, amount)


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
			remove_child(node)
			node.queue_free()
	var km := KitMesh.new()
	var at := Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0 if sits_on_floor else 0.0, 0))
	km.box(size, at, KitMesh.all(material if material else DEFAULT_MATERIAL), solid)
	_generated = km.add_to(self)
