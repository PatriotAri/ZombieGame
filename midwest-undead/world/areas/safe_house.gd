extends RefCounted
## The Westside safe house: a boarded-up house at the far west end of the cross
## street that was meant to be safe. Its barricade has been broken through, the
## survivors are dead, and the undead are still inside. Walking into the yard
## triggers the discovery. Never instanced: main.gd calls build().

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")
const GameData := preload("res://core/game_data.gd")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")

# Mirrors the station on the east end, so reaching it means crossing the whole town.
const SAFE_HOUSE_X := -62.0
const SAFE_HOUSE_FRONT_Z := 9.0
const PLYWOOD := Color(0.55, 0.45, 0.3)


## on_reached: called when the player walks into the yard (or the house).
## Returns {"point": the middle of the yard (the quest marker's target),
## "zombie_points": where the horde spawns}.
static func build(b: WorldBuilder, on_reached: Callable) -> Dictionary:
	var rng := b.rng
	var house := Building.new()
	house.position = Vector3(SAFE_HOUSE_X, 0.0, SAFE_HOUSE_FRONT_Z)
	house.rotation.y = -PI / 2.0 # like the station: faces the cross street (north)
	b.nav_region.add_child(house)
	# Mostly boarded up; floor flush with the ground like the station.
	house.build(12.0, 14.0, 6.0, Color(0.5, 0.42, 0.34), rng, false, 0.85, 0.02)
	var door_x := SAFE_HOUSE_X - house.door_z # world x of the doorway

	var sign := Label3D.new()
	sign.text = "SAFE HOUSE\nSURVIVORS INSIDE"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(0.85, 0.15, 0.1) # spray paint
	sign.position = Vector3(-0.06, 4.3, house.door_z + 3.0)
	sign.rotation = Vector3(0.0, -PI / 2.0, 0.08) # facing the street, a little crooked
	house.add_child(sign)

	# Plywood barricade across the yard, broken through right in front of the door.
	var z := SAFE_HOUSE_FRONT_Z - 4.0
	var x0 := SAFE_HOUSE_X - 9.0
	var x1 := SAFE_HOUSE_X + 9.0
	b.add_box(Vector3((door_x - 2.5) - x0, 2.0, 0.15), Vector3((x0 + door_x - 2.5) / 2.0, 1.0, z), PLYWOOD)
	b.add_box(Vector3(x1 - (door_x + 2.5), 2.0, 0.15), Vector3((door_x + 2.5 + x1) / 2.0, 1.0, z), PLYWOOD)
	# The breached panels, knocked flat (low enough to step over).
	b.add_box(Vector3(2.4, 0.08, 1.9), Vector3(door_x - 1.2, 0.04, z - 1.1), PLYWOOD, 0.3)
	b.add_box(Vector3(2.2, 0.08, 1.9), Vector3(door_x + 1.3, 0.04, z - 0.9), PLYWOOD, -0.4)

	# The people who didn't make it.
	var corpse_spots: Array[Vector3] = [
		house.transform * Vector3(-2.0, 0.1, 2.5), house.transform * Vector3(3.0, 0.1, -3.5),
		house.transform * Vector3(6.5, 0.1, 4.0), house.transform * Vector3(8.0, 0.1, -2.0),
	]
	for spot in corpse_spots:
		var body := HumanNPCScene.instantiate() as HumanNPC
		body.zombies_target = false
		body.outfit_color = Color.from_hsv(rng.randf(), 0.35, 0.4)
		body.position = spot
		body.rotation.y = rng.randf_range(0.0, TAU)
		b.main.add_child(body)
		body.die()

	# What they left behind: supplies worth the trip, if you can get to them.
	var crate_color := Color(0.4, 0.33, 0.2)
	var crates := []
	for local in [Vector3(10.5, 0.55, -5.0), Vector3(10.5, 0.55, 5.0)]:
		crates.append(b.add_loot(Vector3(1.0, 0.9, 1.4), house.transform * local, crate_color, "Supply crate", house.rotation.y))
	crates[0].inventory.add("pistol_ammo", 12)
	crates[0].inventory.add("health_pack", 2)
	crates[1].inventory.add("canned_food", 3)
	crates[1].inventory.add("batteries", 4)

	# The horde: some still inside, some milling around the yard.
	var zombie_points: Array[Vector3] = []
	for local in [Vector3(3.0, 0.15, -4.0), Vector3(4.5, 0.15, 3.5), Vector3(7.0, 0.15, -1.0),
			Vector3(9.0, 0.15, 3.0), Vector3(-1.5, 0.15, -5.0), Vector3(-2.5, 0.15, 4.5),
			Vector3(-3.0, 0.15, 0.5)]:
		zombie_points.append(house.transform * local)

	# Walking into the yard (or the house) is what "reaching" it means.
	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = GameData.LAYER_PLAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(16.0, 4.0, 20.0) # local x: yard to back wall; z: house width plus margin
	var col := CollisionShape3D.new()
	col.shape = shape
	trigger.add_child(col)
	trigger.position = house.transform * Vector3(4.0, 2.0, 0.0)
	trigger.rotation.y = house.rotation.y
	b.main.add_child(trigger)
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			on_reached.call())

	return {"point": house.transform * Vector3(-1.5, 0.0, house.door_z), "zombie_points": zombie_points}
