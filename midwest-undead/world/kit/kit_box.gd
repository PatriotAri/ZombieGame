@tool
class_name KitBox
extends StaticBody3D
## A plain solid box in a material: a fence panel, a counter, a pole, a road.
## Made fresh from its settings (in the editor too). Untick Solid for something
## you can walk through (a decoration). With Models it looks like one of them
## instead (the kit's furniture: a shaped stand-in until there's a model),
## stretched to Size; it's solid where the model's own collision shapes are, or
## the box if it has none (HOW_TO_MODEL.md, "Props").

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const ViewDistance := preload("res://core/view_distance.gd")
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
@export_group("Model")
## What it looks like: model scenes, stretched to Size. With several, each spot
## picks one (always the same one there). Meshes named Paint take Material.
## Empty: the plain box.
@export var models: Array[PackedScene] = []:
	set(value):
		models = value
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
		elif node is KitProp:
			(node as KitProp).darken(amount)


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
	if models.is_empty():
		km.box(size, at, KitMesh.all(material if material else DEFAULT_MATERIAL), solid)
		_generated = km.add_to(self)
		return
	_generated = add_model(self, models, size, at.origin, material, solid)


## The look from models on body (a box's or a container's), stretched to size
## around center, painted in material; and body's collision: the model's own
## shapes, or the box. Returns what it added.
static func add_model(body: CollisionObject3D, choices: Array, box_size: Vector3, center: Vector3,
		paint_with: Material, collide: bool) -> Array[Node]:
	var prop := KitProp.make(null, choices, box_size, center)
	prop.name = "Model"
	body.add_child(prop, false, Node.INTERNAL_MODE_BACK)
	# (Out of the tree, the look only comes once it's in: the prop holds on to
	# these till then.)
	prop.paint(paint_with)
	prop.limit_view(ViewDistance.meters_for_size(box_size))
	var added: Array[Node] = [prop]
	if collide:
		# No shapes of the model's own: the box. (Added to `added` whenever that
		# is: it's the same array the caller keeps, to clear on a rebuild.)
		prop.take_shapes_when_ready(body, func() -> void:
			var km := KitMesh.new()
			km.box(box_size, Transform3D(Basis.IDENTITY, center), [null, null, null, null, null, null])
			added.append_array(km.add_to(body)))
	return added
