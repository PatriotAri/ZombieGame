@tool
class_name KitProp
extends Node3D
## One thing's look, swappable for a model: a door, a fence, a tent, a car...
## Select it (or the thing that has a Models list: a piece of furniture, a
## building's doors and windows) and set Models in the Inspector.
##
## Models: model scenes (HOW_TO_MODEL.md, "Props"). With several, each spot
## picks one at random, always the same one for the same spot (it goes by where
## it stands, so loading a game shows the same). Empty: the stand-in, what's
## under this node's StandIn child (world/props/make_props.gd makes those).
##
## The code using it can ask for the look to be stretched to fit a box (a
## door's opening, a box's Size), paint the model's "Paint" meshes in a
## material, darken it (damage, searched), see through it (a placement
## preview), and take the model's own collision shapes for its body (a model
## without any gets the thing's box).

## Model scenes to pick from. Empty: the stand-in under StandIn.
@export var models: Array[PackedScene] = []:
	set(value):
		models = value
		if is_inside_tree():
			refresh()

## Stretch the look to this size (meters; zero: as it is), its middle at fit_center.
var fit_size := Vector3.ZERO
var fit_center := Vector3.ZERO
## Showing now: the picked model, or the StandIn node.
var look: Node3D

static var _overlays := {} # darkness (0-100) -> shared overlay material


## A prop from scene (a KitProp scene, or null for an empty one) with these
## models instead of its own (empty: its own), fitted to size around center.
## Add it to the tree yourself; it shows its look then.
static func make(scene: PackedScene, override: Array = [], size := Vector3.ZERO, center := Vector3.ZERO) -> KitProp:
	var prop: KitProp = scene.instantiate() if scene else KitProp.new()
	if not override.is_empty():
		prop.models.assign(override)
	prop.fit_size = size
	prop.fit_center = center
	return prop


## Which of models a spot gets: the same every time for the same place.
static func pick(choices: Array, at: Vector3) -> PackedScene:
	var usable := choices.filter(func(s: Variant) -> bool: return s is PackedScene)
	if usable.is_empty():
		return null
	var key := Vector3i((at * 10.0).round())
	return usable[posmod(hash(key), usable.size())]


func _ready() -> void:
	refresh()


## Puts up the look: a model picked from models, or the stand-in.
func refresh() -> void:
	var old := get_node_or_null("Model")
	if old:
		remove_child(old)
		old.queue_free()
	var stand_in := get_node_or_null("StandIn") as Node3D
	var scene := pick(models, global_position if is_inside_tree() else position)
	if scene:
		look = scene.instantiate() as Node3D
		look.name = "Model"
		add_child(look) # not owned: never saved into the scene it's in
		if stand_in:
			stand_in.visible = false
	else:
		look = stand_in
		if stand_in:
			stand_in.visible = true
	_fit()


## Stretched to fit_size around fit_center.
func _fit() -> void:
	if look == null or fit_size == Vector3.ZERO:
		return
	look.transform = Transform3D.IDENTITY
	var box := _bounds(look, Transform3D.IDENTITY)
	if box.size.x < 0.001 or box.size.y < 0.001 or box.size.z < 0.001:
		return
	var s := fit_size / box.size
	look.scale = s
	look.position = fit_center - box.get_center() * s


## The meshes' bounding box under node, in the space xform maps node into.
static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if node is VisualInstance3D and node is GeometryInstance3D:
		var mesh_box := (node as VisualInstance3D).get_aabb()
		box = xform * mesh_box
		first = false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_box := _bounds(child, xform * (child as Node3D).transform)
		if child_box.size == Vector3.ZERO:
			continue
		box = child_box if first else box.merge(child_box)
		first = false
	return box


## Every mesh in the look.
func meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if look:
		if look is MeshInstance3D:
			found.append(look)
		found.assign(found + look.find_children("*", "MeshInstance3D", true, false))
	return found


## Meshes named Paint (or starting with it) take this material.
func paint(material: Material) -> void:
	if material == null:
		return
	for mesh in meshes():
		if mesh.name.begins_with("Paint"):
			mesh.material_override = material


## Darker by amount (0: as it is, 1: black), for any model.
func darken(amount: float) -> void:
	var step := clampi(roundi(amount * 100.0), 0, 100)
	var overlay: Material = null
	if step > 0:
		if not _overlays.has(step):
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0, 0, 0, step / 100.0)
			_overlays[step] = mat
		overlay = _overlays[step]
	for mesh in meshes():
		mesh.material_overlay = overlay


## Drawn in one see-through material (a placement preview): no shadows, no lights.
func ghost(material: Material) -> void:
	for mesh in meshes():
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if look:
		for light in look.find_children("*", "Light3D", true, false):
			(light as Light3D).visible = false


## Hides the parts named like part (a window's Glass once it's smashed); a
## model with no such part hides altogether.
func hide_part(part: String) -> void:
	if look == null:
		return
	var parts := look.find_children(part + "*", "Node3D", true, false)
	if parts.is_empty():
		look.visible = false
	for node in parts:
		(node as Node3D).visible = false


## Moves the model's own collision shapes onto body (where they are now).
## Returns false when it has none (the caller gives body its box).
func take_shapes(body: CollisionObject3D) -> bool:
	if look == null or look.name != "Model":
		return false
	var shapes := look.find_children("*", "CollisionShape3D", true, false)
	shapes.append_array(look.find_children("*", "CollisionPolygon3D", true, false))
	for shape in shapes:
		var at := (shape as Node3D).global_transform if shape.is_inside_tree() else Transform3D.IDENTITY
		shape.get_parent().remove_child(shape)
		body.add_child(shape)
		if shape.is_inside_tree():
			(shape as Node3D).global_transform = at
	# The model's own bodies (an imported model's "-col" parts) are empty now.
	for inner in look.find_children("*", "CollisionObject3D", true, false):
		(inner as CollisionObject3D).collision_layer = 0
		(inner as CollisionObject3D).collision_mask = 0
	return not shapes.is_empty()
