extends RefCounted
## Fewer draws for the things that can't be merged into the town's meshes
## (static_merge.gd) because they change: windows, doors, containers, the
## furniture you can strip. The same look shares one mesh (kit_prop.gd
## flattens them), so every copy of it in a 48 m patch is drawn together, as
## one MultiMesh (GPU instancing), instead of one draw each.
##
## The moment one changes (darkened when searched, bashed or stripped, its
## glass smashed, a door swinging, a placement preview) it leaves its batch:
## its own mesh shows again, where it is, and the batch's copy is hidden
## (unbatch()). Never instanced: world/game_map.gd calls batch() once the map is in.

const ViewDistance := preload("res://core/view_distance.gd")
const PATCH := 48.0
const MIN_COPIES := 2 # just one in a patch: nothing to gain
const META := &"batched" # on a batched mesh: [MultiMeshInstance3D, index]


## Batches the looks under root. Returns how many meshes it took in.
static func batch(root: Node3D) -> int:
	var groups := {} # [mesh, override, shadows, range, render layers, patch x, patch z] -> [MeshInstance3D]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if not _batchable(mesh_inst):
			continue
		var at := mesh_inst.global_position
		var key := [mesh_inst.mesh, mesh_inst.material_override, mesh_inst.cast_shadow, mesh_inst.visibility_range_end,
				mesh_inst.layers, floori(at.x / PATCH), floori(at.z / PATCH)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mesh_inst)
	var holder := Node3D.new()
	holder.name = "Batches"
	root.add_child(holder)
	var taken := 0
	for key: Array in groups:
		var members: Array = groups[key]
		if members.size() < MIN_COPIES:
			continue
		var first := members[0] as MeshInstance3D
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = first.mesh
		multi.instance_count = members.size()
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = first.material_override
		instance.cast_shadow = first.cast_shadow
		instance.layers = first.layers
		holder.add_child(instance)
		if first.has_meta("view_meters"):
			# The patch is drawn as one: as far as its far side is in range.
			ViewDistance.limit(instance, float(first.get_meta("view_meters")) + PATCH * 0.75)
		for i in members.size():
			var mesh_inst := members[i] as MeshInstance3D
			multi.set_instance_transform(i, mesh_inst.global_transform)
			mesh_inst.set_meta(META, [instance, i])
			mesh_inst.visible = false
		taken += members.size()
	return taken


## A plain look's mesh: in a KitProp, nothing animated, showing, not merged.
static func _batchable(mesh_inst: MeshInstance3D) -> bool:
	if mesh_inst.mesh == null or not mesh_inst.is_visible_in_tree() or mesh_inst.skeleton != NodePath("") \
			or mesh_inst.material_overlay != null or mesh_inst.has_meta(META):
		return false
	var node := mesh_inst.get_parent()
	while node != null:
		if node is KitProp:
			return true
		node = node.get_parent()
	return false


## Takes a mesh out of its batch (it's about to change): it shows on its own again.
static func unbatch(mesh_inst: MeshInstance3D) -> void:
	if not mesh_inst.has_meta(META):
		return
	var entry: Array = mesh_inst.get_meta(META)
	mesh_inst.remove_meta(META)
	var instance := entry[0] as MultiMeshInstance3D
	if is_instance_valid(instance):
		instance.multimesh.set_instance_transform(entry[1], Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mesh_inst.visible = true


