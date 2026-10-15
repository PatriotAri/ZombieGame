@tool
extends StaticBody3D
## A boulder or rock outcrop: a lumpy rock shape made from a number (shape), with
## collision to match. Place it with the Map Tools panel's "New rock" button,
## then move, turn and scale it (stretch it flat for a ledge, tall for a crag,
## sink it into the hillside for an outcrop); change shape for another one.
## Copies (Ctrl+D) with different shapes make a rock pile.

const RockTexture := preload("res://world/map/textures/rock_alb_ht.png")
const DETAIL := 2 # how finely the shape is made (higher: rounder, more triangles)

## Which shape (any number).
@export var shape := 1:
	set(value):
		shape = value
		_rebuild()
## How rough the shape is (0 smooth, 1 very jagged).
@export_range(0.0, 1.0, 0.05) var roughness := 0.45:
	set(value):
		roughness = value
		_rebuild()

static var _material: StandardMaterial3D
var _mesh_instance: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for node in [_mesh_instance, _shape]:
		if node:
			remove_child(node)
			node.queue_free()
	var noise := FastNoiseLite.new()
	noise.seed = shape
	noise.frequency = 0.9
	var verts := PackedVector3Array()
	for tri: Array in _ball():
		for p: Vector3 in tri:
			var n := noise.get_noise_3dv(p * 1.3)
			var squash := Vector3(1.0, 0.7, 1.0) # wider than tall
			verts.append(p * squash * (1.0 + n * roughness))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		st.add_vertex(v)
	st.generate_normals()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = _rock_material()
	add_child(_mesh_instance) # not owned: made fresh from the shape number, never saved
	var hull := ConvexPolygonShape3D.new()
	hull.points = verts
	_shape = CollisionShape3D.new()
	_shape.shape = hull
	add_child(_shape)


static func _rock_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = RockTexture
		_material.albedo_color = Color(0.85, 0.85, 0.82)
		_material.uv1_triplanar = true # no UVs needed: the texture wraps from all sides
		_material.uv1_world_triplanar = true
		_material.uv1_scale = Vector3.ONE * 0.25
		_material.roughness = 0.95
	return _material


## A unit ball of triangles (an icosahedron split DETAIL times).
static func _ball() -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
			[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
			[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var tris := []
	for fc: Array in faces:
		tris.append([v[fc[0]].normalized(), v[fc[1]].normalized(), v[fc[2]].normalized()])
	for d in DETAIL:
		var next := []
		for tri: Array in tris:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var ab := ((a + b) / 2.0).normalized()
			var bc := ((b + c) / 2.0).normalized()
			var ca := ((c + a) / 2.0).normalized()
			next.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
		tris = next
	return tris
