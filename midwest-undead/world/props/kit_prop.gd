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

# What it was asked for before its look existed (a prop is often set up before
# it's in the tree, and its look only comes in _ready): applied whenever the
# look is put up, so a refresh (new models) keeps them too.
var _paint: Material
var _view_meters := 0.0
var _shapes_body: CollisionObject3D
var _no_shapes: Callable # called if the model brought no collision shapes

const Instancer := preload("res://world/instancer.gd")
const ViewDistance := preload("res://core/view_distance.gd")
static var _overlays := {} # darkness (0-100) -> shared overlay material
static var _flat := {} # a look's source -> its flattened mesh (shared by every copy)
static var _plain: StandardMaterial3D # the flattened meshes' material: their colors in their vertices


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
	if not Engine.is_editor_hint():
		_flatten()
	if _paint:
		_apply_paint()
	if _view_meters > 0.0:
		_apply_view()


## In the game: the look's many small meshes (a stand-in's boxes, a model's
## parts) as one mesh, its plain-colored parts in one material with their
## colors in the vertices: a draw or two instead of dozens. Parts named Paint
## (painted per thing) or Glass (hidden when smashed), see-through ones, and
## anything animated stay as they are.
func _flatten() -> void:
	if look == null or look is MeshInstance3D or not look.find_children("*", "AnimationPlayer", true, false).is_empty():
		return
	var parts: Array[MeshInstance3D] = []
	var painted: Array[MeshInstance3D] = []
	for node in look.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skeleton != NodePath("") or not mesh.visible \
				or mesh.name.begins_with("Glass") or _see_through(mesh):
			continue
		(painted if mesh.name.begins_with("Paint") else parts).append(mesh)
	var key := (look.scene_file_path if look.scene_file_path != "" else scene_file_path + "/" + str(look.name))
	if key == "/" + str(look.name):
		key = "" # made in code: not shared
	_merge_parts(parts, "Flat", key, false)
	_merge_parts(painted, "Paint", key + ":paint" if key != "" else "", true)


## Puts parts in one mesh, name, under the look (shared by key, if any).
## as_one: all in one surface, in the first part's material (painted over
## anyway: the Paint parts).
func _merge_parts(parts: Array[MeshInstance3D], name: String, key: String, as_one: bool) -> void:
	if parts.size() < 2:
		return
	var flat: ArrayMesh = _flat.get(key) if key != "" else null
	if flat == null:
		flat = _combine(parts, look, parts[0].get_active_material(0) if as_one else null)
		if key != "":
			_flat[key] = flat
	var one := MeshInstance3D.new()
	one.mesh = flat
	for part in parts:
		part.get_parent().remove_child(part)
		part.queue_free()
	one.name = name # (once the parts, one maybe called it, are gone)
	look.add_child(one)


static func _see_through(mesh: MeshInstance3D) -> bool:
	for i in mesh.mesh.get_surface_count():
		var mat := mesh.get_active_material(i) as BaseMaterial3D
		if mat and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false


## parts' surfaces in look's space, one surface per material; plain-colored
## ones (no texture, matte) all in _plain, their color in the vertices.
## only: everything in this one material instead.
static func _combine(parts: Array[MeshInstance3D], root: Node3D, only: Material = null) -> ArrayMesh:
	if _plain == null:
		_plain = StandardMaterial3D.new()
		_plain.vertex_color_use_as_albedo = true
	var groups := {} # Material -> [verts, normals, uvs, colors, indices]
	for part in parts:
		var xform := Transform3D.IDENTITY
		var node: Node = part
		while node != root and node is Node3D:
			xform = (node as Node3D).transform * xform
			node = node.get_parent()
		var normal_basis := xform.basis.inverse().transposed()
		for i in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(i)
			var mat := part.get_active_material(i)
			var color := Color.WHITE
			var target: Material = mat
			if only:
				target = only
			elif _is_plain(mat):
				color = (mat as StandardMaterial3D).albedo_color if mat else Color.WHITE
				target = _plain
			if not groups.has(target):
				groups[target] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray(), PackedInt32Array()]
			var g: Array = groups[target]
			# (Packed arrays are values: work on these, then put them back.)
			var out_verts: PackedVector3Array = g[0]
			var out_normals: PackedVector3Array = g[1]
			var out_uvs: PackedVector2Array = g[2]
			var out_colors: PackedColorArray = g[3]
			var out_indices: PackedInt32Array = g[4]
			var base := out_verts.size()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			for v in verts.size():
				out_verts.append(xform * verts[v])
				out_normals.append((normal_basis * normals[v]).normalized() if v < normals.size() else Vector3.UP)
				out_uvs.append(uvs[v] if v < uvs.size() else Vector2.ZERO)
				out_colors.append(color)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for v in verts.size():
					out_indices.append(base + v)
			else:
				for index in indices:
					out_indices.append(base + index)
			groups[target] = [out_verts, out_normals, out_uvs, out_colors, out_indices]
	var mesh := ArrayMesh.new()
	for mat: Material in groups:
		var g: Array = groups[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g[0]
		arrays[Mesh.ARRAY_NORMAL] = g[1]
		arrays[Mesh.ARRAY_TEX_UV] = g[2]
		arrays[Mesh.ARRAY_COLOR] = g[3]
		arrays[Mesh.ARRAY_INDEX] = g[4]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


## A material that's only a color (what make_props.gd gives stand-ins): no
## texture, matte, not see-through, not glowing.
static func _is_plain(mat: Material) -> bool:
	if mat == null:
		return true
	var m := mat as StandardMaterial3D
	return m != null and m.albedo_texture == null and m.metallic == 0.0 and m.roughness == 1.0 \
			and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled \
			and not m.vertex_color_use_as_albedo and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL


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


## Meshes named Paint (or starting with it) take this material, now and
## whenever the look is put up again.
func paint(material: Material) -> void:
	if material == null:
		return
	_paint = material
	_apply_paint()


func _apply_paint() -> void:
	unbatch()
	for mesh in meshes():
		if mesh.name.begins_with("Paint"):
			mesh.material_override = _paint


## Its meshes stop being drawn past meters (core/view_distance.gd), now and
## whenever the look is put up again.
func limit_view(meters: float) -> void:
	_view_meters = meters
	_apply_view()


func _apply_view() -> void:
	for mesh in meshes():
		ViewDistance.limit(mesh, _view_meters)


## The model's collision shapes go to body once the look is up: now, if it
## is, else once body is ready (not in the look's own _ready: body can't take
## children while its children are getting ready). If the model brought none,
## no_shapes is called instead (a box, say).
func take_shapes_when_ready(body: CollisionObject3D, no_shapes: Callable) -> void:
	_shapes_body = body
	_no_shapes = no_shapes
	if look:
		_take_shapes_now()
	else:
		body.ready.connect(_take_shapes_now, CONNECT_ONE_SHOT)


func _take_shapes_now() -> void:
	var body := _shapes_body
	_shapes_body = null
	if not take_shapes(body) and _no_shapes.is_valid():
		_no_shapes.call()


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
	unbatch()
	for mesh in meshes():
		mesh.material_overlay = overlay


## Drawn in one see-through material (a placement preview): no shadows, no lights.
func ghost(material: Material) -> void:
	unbatch()
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
	unbatch()
	var parts := look.find_children(part + "*", "Node3D", true, false)
	if parts.is_empty():
		look.visible = false
	for node in parts:
		(node as Node3D).visible = false


## Out of the batches it's drawn in (world/instancer.gd): it's about to change
## (or move), so it's drawn on its own again.
func unbatch() -> void:
	for mesh in meshes():
		if mesh.has_meta(&"batched"):
			Instancer.unbatch(mesh)


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
