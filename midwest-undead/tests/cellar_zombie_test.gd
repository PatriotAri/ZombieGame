extends SceneTree
## A zombie that hears something in a basement breaks in through the shut
## cellar door (it's out of the navigation bake, as main.gd has every door) and
## goes down; planks on it hold.
const KitBuilding := preload("res://world/building.gd")
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var fails := 0
var house: Node3D
var door: Node
var z: Node
var baked_at := -1
var base := Vector3(-80, 0, -70)
func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	if f == 3:
		main.player.set_physics_process(false)
		main.player.global_position = Vector3(500, 50, 500)
		for q in main.zombies:
			q.set_physics_process(false); q.global_position = Vector3(500, 0, 500)
		house = KitBuilding.new()
		house.position = Vector3(base.x, TerrainEdit.height_at(main.terrain, base), base.z)
		house.floor_y = 0.2
		house.basement = true
		var cd: Array[KitCellarDoor] = [KitCellarDoor.make(1, 0.0)]
		house.cellar_doors = cd
		main.nav_region.add_child(house)
		house.apply(main.terrain)
		main.nav_region._terrain_faces.clear()
		door = house.get_node("CellarDoor1")
		var xf: Transform3D = door.global_transform
		door.get_parent().remove_child(door)
		main.add_child(door)
		door.global_transform = xf
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if baked_at > 0 and f == baked_at + 90:
		z = main._add_zombie(house.global_transform * Vector3(5.0, 0.1, 5.0 + KitBuilding._cellar_length() + 4.0), null, "walker")
		z.hear_noise(house.global_transform * Vector3(4.0, -2.7, 0.0), 50.0)
	if z and f % 60 == 0:
		print("    %.0f s: at %s, state %d, door %.0f" % [f / 60.0, house.to_local(z.global_position).snappedf(0.1), z.state, door.health])
	if z and (house.to_local(z.global_position).y < -2.0 or f > baked_at + 90 + 60 * 40):
		check(door.is_broken, "it broke the cellar door in (health %.0f)" % door.health)
		check(house.to_local(z.global_position).y < -2.0, "and went down into the basement (%s)" % house.to_local(z.global_position).snappedf(0.1))
		print("FAILS: %d" % fails)
		return true
	return f > 4000
