@tool
class_name KitSteeple
extends StaticBody3D
## A church steeple: a square tower with an open belfry and a pointed spire on
## top. Stand its node on the roof (or the ground) where the tower starts; it
## can't be climbed into. Templates put one over a church's front.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const DEFAULT_WALL := preload("res://world/kit/materials/siding_white.tres")
const DEFAULT_ROOF := preload("res://world/kit/materials/roof_tar.tres")

## Across the tower (meters).
@export_range(1.0, 8.0, 0.1) var width := 3.0:
	set(value):
		width = value
		_changed()
## The tower, from the node up to the spire.
@export_range(1.0, 30.0, 0.1) var tower := 5.0:
	set(value):
		tower = value
		_changed()
@export_range(1.0, 30.0, 0.1) var spire := 5.0:
	set(value):
		spire = value
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
			remove_child(node)
			node.queue_free()
	var wall := wall_material if wall_material else DEFAULT_WALL
	var roof := roof_material if roof_material else DEFAULT_ROOF
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	var km := KitMesh.new()
	var h := width / 2.0
	var belfry := minf(1.6, tower * 0.35) # the open part at the top of the tower
	km.box(Vector3(width, tower - belfry, width), Transform3D(Basis.IDENTITY, Vector3(0, (tower - belfry) / 2.0, 0)), KitMesh.all(wall))
	# The belfry: posts at the corners, dark louvres between, a cap.
	for x: float in [-h + 0.15, h - 0.15]:
		for z: float in [-h + 0.15, h - 0.15]:
			km.box(Vector3(0.3, belfry, 0.3), Transform3D(Basis.IDENTITY, Vector3(x, tower - belfry / 2.0, z)), KitMesh.all(wall))
	km.box(Vector3(width - 0.4, belfry - 0.2, width - 0.4), Transform3D(Basis.IDENTITY, Vector3(0, tower - belfry / 2.0, 0)), KitMesh.all(dark))
	km.box(Vector3(width + 0.3, 0.2, width + 0.3), Transform3D(Basis.IDENTITY, Vector3(0, tower + 0.1, 0)), KitMesh.all(wall))
	# The spire: four sloping faces to a point.
	var top := Vector3(0, tower + 0.2 + spire, 0)
	var y := tower + 0.2
	var corners := [Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h), Vector3(-h, y, h)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var face := PackedVector3Array([a, b, top])
		if (b - a).cross(top - a).dot((a + b) / 2.0 - Vector3(0, y, 0)) < 0.0:
			face = PackedVector3Array([b, a, top])
		km.plate(face, 0.08, roof, roof, null)
	_generated = km.add_to(self)
	var cross := MeshInstance3D.new() # a small cross on the point
	var bar := BoxMesh.new()
	bar.size = Vector3(0.08, 0.9, 0.08)
	cross.mesh = bar
	cross.position = top + Vector3(0, 0.45, 0)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.5, 0.08, 0.08)
	arm.mesh = arm_mesh
	arm.position = Vector3(0, 0.15, 0)
	cross.add_child(arm)
	add_child(cross, false, Node.INTERNAL_MODE_BACK)
	_generated.append(cross)
