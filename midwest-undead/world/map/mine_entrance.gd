@tool
extends Node3D
## A mine entrance: a timber-framed opening and the start of a tunnel that ends
## in a cave-in. Put it at the foot of a steep hillside with the Map Tools
## panel's "New mine entrance" button, turn it so the tunnel (its -Z, the blue
## arrow's other way) runs into the hill, sink it so its floor is at the
## ground, and press Apply: the hillside is opened up where the tunnel comes
## through it (holes in the terrain), and stays closed over the tunnel deeper
## in. Move it and Apply again any time (Ctrl+Z undoes).
## (A mine to explore, tunnels and all, is a KitMine: world/map/kit_mine.gd.)

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const Rock := preload("res://world/map/rock.gd")
const TIMBER := Color(0.33, 0.24, 0.15)
const WALL := Color(0.25, 0.22, 0.2)
const THICK := 0.4 # walls, floor and ceiling

## Meters from the mouth to the cave-in.
@export_range(4.0, 40.0, 0.5) var length := 10.0:
	set(value):
		length = value
		_rebuild()
## Meters inside, wall to wall and floor to ceiling.
@export_range(2.0, 6.0, 0.1) var width := 3.4:
	set(value):
		width = value
		_rebuild()
@export_range(2.0, 5.0, 0.1) var height := 3.0:
	set(value):
		height = value
		_rebuild()

var _built: Node3D
static var _materials := {}


func _ready() -> void:
	_rebuild()


## Opens the hillside where the tunnel passes through it (see the top).
## Returns the (x, z) area changed.
func apply(terrain: Node) -> Rect2:
	var spacing: float = terrain.vertex_spacing
	var corners := [global_transform * Vector3(-width / 2.0 - 0.5, 0, 1.5), global_transform * Vector3(width / 2.0 + 0.5, 0, 1.5),
			global_transform * Vector3(-width / 2.0 - 0.5, 0, -length), global_transform * Vector3(width / 2.0 + 0.5, 0, -length)]
	var rect := Rect2(corners[0].x, corners[0].z, 0, 0)
	for c: Vector3 in corners:
		rect = rect.expand(Vector2(c.x, c.z))
	var floor_y := global_position.y
	for x in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing) + 1):
		for z in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing) + 1):
			var v := Vector3(x * spacing, 0.0, z * spacing)
			var local := to_local(Vector3(v.x, floor_y, v.z))
			if absf(local.x) > width / 2.0 + 0.5 or local.z > 1.5 or local.z < -length:
				continue
			var ground := TerrainEdit.height_at(terrain, v)
			# The ground cuts through the tunnel (or sits just over its ceiling):
			# open it. Deeper in, under plenty of hill, leave it closed.
			var inside := ground > floor_y - 0.2 and ground < floor_y + height + THICK + 1.0
			terrain.data.set_control_hole(v, inside)
	TerrainEdit.finish(terrain, rect)
	return rect


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _built:
		remove_child(_built)
		_built.queue_free()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built) # not owned: made fresh each time, never saved
	var body := StaticBody3D.new()
	_built.add_child(body)
	var half := width / 2.0
	# The tunnel: floor, walls, ceiling.
	_box(body, Vector3(width + THICK * 2.0, THICK, length), Vector3(0, -THICK / 2.0, -length / 2.0), WALL)
	_box(body, Vector3(width + THICK * 2.0, THICK, length), Vector3(0, height + THICK / 2.0, -length / 2.0), WALL)
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(THICK, height, length), Vector3(side * (half + THICK / 2.0), height / 2.0, -length / 2.0), WALL)
	# Timber frames: at the mouth and every few meters in.
	var z := 0.0
	while z > -length + 1.0:
		for side: float in [-1.0, 1.0]:
			_box(body, Vector3(0.25, height, 0.25), Vector3(side * (half - 0.15), height / 2.0, z - 0.15), TIMBER)
		_box(body, Vector3(width, 0.3, 0.3), Vector3(0, height - 0.15, z - 0.15), TIMBER)
		z -= 3.0
	# The cave-in: a wall of rubble at the end.
	_box(body, Vector3(width, height, 0.6), Vector3(0, height / 2.0, -length + 0.3), WALL.darkened(0.2))
	for i in 5:
		var rock := Rock.new()
		rock.shape = i + 3
		rock.scale = Vector3.ONE * (0.6 + 0.15 * (i % 3))
		rock.position = Vector3(-half + 0.5 + i * (width - 1.0) / 4.0, 0.3, -length + 1.0 + 0.3 * (i % 2))
		_built.add_child(rock)


func _box(body: StaticBody3D, size: Vector3, pos: Vector3, color: Color) -> void:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_materials[color] = mat
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _materials[color]
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_built.add_child(inst)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
