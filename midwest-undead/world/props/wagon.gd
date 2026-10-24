extends StaticBody3D
## A covered wagon (the wagon trader's): a box bed on four wheels, hoops of
## canvas over it, a hitch pole out the front, and a lantern for the night.
## Made in code when it's put in the world (a quest's Spawn Scene, or placed
## on the map as wagon.tscn). Its front is -Z.

const WOOD := Color(0.45, 0.32, 0.2)
const WOOD_DARK := Color(0.3, 0.21, 0.13)
const CANVAS := Color(0.78, 0.74, 0.62)


func _ready() -> void:
	_box(Vector3(1.9, 0.5, 4.0), Vector3(0, 0.95, 0), WOOD) # bed
	_box(Vector3(1.9, 0.45, 0.08), Vector3(0, 1.42, -2.0), WOOD_DARK) # front board
	_box(Vector3(1.9, 0.45, 0.08), Vector3(0, 1.42, 2.0), WOOD_DARK) # tailboard
	_box(Vector3(0.08, 0.1, 2.6), Vector3(0, 0.75, -3.2), WOOD_DARK) # hitch pole
	_box(Vector3(2.0, 1.3, 3.6), Vector3(0, 2.0, 0.1), CANVAS) # canvas cover
	_box(Vector3(1.4, 0.3, 3.6), Vector3(0, 2.75, 0.1), CANVAS)
	for x: float in [-1.05, 1.05]:
		for z: float in [-1.4, 1.4]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.55
			mesh.bottom_radius = 0.55
			mesh.height = 0.12
			mesh.radial_segments = 16
			mesh.rings = 1
			mesh.material = _material(WOOD_DARK)
			wheel.mesh = mesh
			wheel.position = Vector3(x, 0.55, z)
			wheel.rotation.z = PI / 2.0
			add_child(wheel)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.9, 4.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 1.45, 0)
	add_child(col)
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0.0, 2.2, -2.2)
	lantern.light_color = Color(1.0, 0.75, 0.45)
	lantern.light_energy = 0.7
	lantern.omni_range = 8.0
	add_child(lantern)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
