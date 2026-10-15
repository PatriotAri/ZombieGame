extends RefCounted
## Fewer things for the graphics card to draw: when a game starts, the town's
## buildings and kit pieces (walls, floors, stairs, boxes: things that never
## change while you play) are combined into a few big meshes, one per material
## for each 48 m patch of town, instead of hundreds. Their own meshes are then
## hidden; their collision stays as it was. Nothing changes in the editor: this
## only happens in the game. Never instanced: main.gd calls merge().
##
## Left alone: anything that changes or moves (containers, doors, windows,
## items on the ground, things that can be salvaged) and anything without one
## of the kit's scripts.

const PATCH := 48.0 # meters: small enough that off-screen patches aren't drawn
const MERGED_SCRIPTS := ["building.gd", "kit_wall.gd", "kit_floor.gd", "kit_stairs.gd", "kit_box.gd"]


## Combines town's static meshes. Returns how many meshes it hid.
static func merge(town: Node3D) -> int:
	var buckets := {} # [patch x, patch z, material, shadows] -> Bucket
	var hidden := 0
	var to_local := town.global_transform.affine_inverse()
	for node in town.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if not _mergeable(mesh_inst, town):
			continue
		var xform := to_local * mesh_inst.global_transform
		var center := mesh_inst.global_transform * mesh_inst.get_aabb().get_center()
		var patch := Vector2i(floori(center.x / PATCH), floori(center.z / PATCH))
		for s in mesh_inst.mesh.get_surface_count():
			var mat := _material(mesh_inst, s)
			var key := [patch.x, patch.y, mat, mesh_inst.cast_shadow]
			if not buckets.has(key):
				buckets[key] = Bucket.new()
			(buckets[key] as Bucket).add(mesh_inst.mesh.surface_get_arrays(s), xform)
		mesh_inst.visible = false
		hidden += 1
	var holder := Node3D.new()
	holder.name = "MergedMeshes"
	town.add_child(holder)
	for key: Array in buckets:
		var merged := MeshInstance3D.new()
		merged.mesh = (buckets[key] as Bucket).commit()
		merged.material_override = key[2]
		merged.cast_shadow = key[3]
		holder.add_child(merged)
	return hidden


## Static kit geometry, visible, not under anything that changes.
static func _mergeable(mesh_inst: MeshInstance3D, town: Node3D) -> bool:
	if mesh_inst.mesh == null or not mesh_inst.is_visible_in_tree() or mesh_inst.skeleton != NodePath(""):
		return false
	var scripted := false
	var node: Node = mesh_inst.get_parent()
	while node != null and node != town:
		if node.has_meta("salvage_label"):
			return false # can be stripped (it darkens)
		if not scripted and node.get_script():
			if not (node.get_script() as Script).resource_path.get_file() in MERGED_SCRIPTS:
				return false # a container, a door, a window, an item...
			scripted = true
		node = node.get_parent()
	return scripted


static func _material(mesh_inst: MeshInstance3D, surface: int) -> Material:
	if mesh_inst.material_override:
		return mesh_inst.material_override
	var mat := mesh_inst.get_surface_override_material(surface)
	return mat if mat else mesh_inst.mesh.surface_get_material(surface)


## One merged surface being built: vertices, normals, UVs and tangents, moved
## into the town's space.
class Bucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()

	func add(arrays: Array, xform: Transform3D) -> void:
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n = arrays[Mesh.ARRAY_NORMAL]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var t = arrays[Mesh.ARRAY_TANGENT]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var start := verts.size()
		var basis := xform.basis
		var normal_basis := basis.inverse().transposed() # right for stretched pieces too
		for i in v.size():
			verts.append(xform * v[i])
			normals.append((normal_basis * (n[i] as Vector3)).normalized() if n != null else Vector3.UP)
			uvs.append(uv[i] if uv != null else Vector2.ZERO)
			if t != null:
				var tangent := (basis * Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2])).normalized()
				tangents.append_array([tangent.x, tangent.y, tangent.z, t[i * 4 + 3]])
			else:
				tangents.append_array([1.0, 0.0, 0.0, 1.0])
		if idx == null:
			for i in v.size():
				indices.append(start + i)
		else:
			for i: int in idx:
				indices.append(start + i)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
