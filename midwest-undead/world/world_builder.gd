extends RefCounted
## What every part of the town needs while it's being built: the random number
## generators, the navigation region the geometry goes under, and the lists the
## rest of the game reads afterwards (containers, doors, shop interiors, cars).
## main.gd makes one and hands it to each area builder in world/areas/.
##
## ORDER MATTERS. The town comes out the same every time because every random
## roll happens in the same order. Saves rely on it: containers, zombies and
## doors are saved by their position in these lists. Adding a roll in the
## middle of the build reshuffles everything after it (and breaks old saves),
## so new random things go at the end, or use their own generator (like doors).

const LootSpot := preload("res://items/loot_spot.gd")
const Door := preload("res://world/door.gd")
const GroundItem := preload("res://items/ground_item.gd")

var main: Node3D # characters, lights and doors go here, outside the navigation bake
var nav_region: NavigationRegion3D # static geometry goes here, so zombies path around it
var rng := RandomNumberGenerator.new()
## Separate from rng so adding doors didn't reshuffle the rest of the town.
var door_rng := RandomNumberGenerator.new()

var loot_spots: Array = []
var doors: Array[Door] = [] # every door and gate leaf, in build order (for saving)
var interior_points: Array[Vector3] = [] # inside shops, where zombies can lurk
var car_spots: Array[Vector3] = [] # so nothing else gets spawned inside a car
var door_spots: Array[Vector3] = [] # shop doorways on Main Street, kept clear of streetlights
## The first shop of each Main Street block, i.e. the one on the corner with 7th
## Street, keyed by Vector2i(side, dir): side +1 = east of Main, dir -1 = north.
var corner_shops := {}


func _init(main_node: Node3D, region: NavigationRegion3D, town_seed: int) -> void:
	main = main_node
	nav_region = region
	rng.seed = town_seed
	door_rng.seed = town_seed + 1


func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


## A visible mesh with no collision (decoration).
func add_mesh(mesh: PrimitiveMesh, pos: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	mesh.material = material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation.y = yaw
	nav_region.add_child(inst)
	return inst


## A solid box you can't walk through: mesh + matching collision shape.
func add_box(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw

	var box := BoxMesh.new()
	box.size = size
	box.material = material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = box
	body.add_child(inst)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	nav_region.add_child(body)
	return body


## A solid box you can search. Still under nav_region, so zombies path around it.
func add_loot(size: Vector3, pos: Vector3, color: Color, label: String, yaw := 0.0) -> LootSpot:
	var spot := LootSpot.new()
	spot.position = pos
	spot.rotation.y = yaw
	spot.setup(size, color, label)
	nav_region.add_child(spot)
	loot_spots.append(spot)
	return spot


## Doors go straight under Main, not nav_region, so the navigation bake ignores
## them (see door.gd).
func add_door(door: Door, open: bool) -> void:
	main.add_child(door)
	if open:
		door.set_open(true, false)
	doors.append(door)


func add_ground_item(id: String, amount: int, pos: Vector3, yaw := INF) -> void:
	var item := GroundItem.new()
	item.position = pos
	item.rotation.y = rng.randf_range(0.0, TAU) if yaw == INF else yaw
	item.setup(id, amount)
	main.add_child(item) # not under nav_region: items shouldn't affect zombie paths


## A random point on Main Street between two z values that isn't inside a car.
func street_spot(z_from: float, z_to: float) -> Vector3:
	var pos := Vector3(rng.randf_range(-4.5, 4.5), 0.02, rng.randf_range(z_from, z_to))
	for attempt in 20:
		if not near_car(pos, 3.0):
			break
		pos = Vector3(rng.randf_range(-4.5, 4.5), 0.02, rng.randf_range(z_from, z_to))
	return pos


func near_car(pos: Vector3, min_dist: float) -> bool:
	for car in car_spots:
		if Vector2(pos.x - car.x, pos.z - car.z).length() < min_dist:
			return true
	return false
