extends RefCounted
## Fills the town's containers and scatters loose items in the street.
## Never instanced: main.gd calls fill_containers() once the town and the
## police station are built, and scatter() after the navigation bake.

const WorldBuilder := preload("res://world/world_builder.gd")
const LootSpot := preload("res://items/loot_spot.gd")

const CROWBAR_MIN_DISTANCE := 40.0


## start: where the player starts. health_pack, ammo and trade_goods are each
## container's chance of holding them.
static func fill_containers(b: WorldBuilder, start: Vector3, health_pack: float, ammo: float,
		trade_goods: float) -> void:
	var rng := b.rng
	var loot_spots := b.loot_spots
	# One crowbar in the whole town, at least 40 m from where you start, so you have
	# to venture in for it. Half the time it's in a container, half on the ground
	# up Main Street (north, -z).
	var crowbar_spot: LootSpot = null
	if rng.randf() < 0.5:
		var far_spots := loot_spots.filter(func(s: LootSpot) -> bool:
			return s.global_position.distance_to(start) >= CROWBAR_MIN_DISTANCE)
		if far_spots.is_empty(): # can happen with a different town seed
			far_spots = loot_spots
		crowbar_spot = far_spots[rng.randi_range(0, far_spots.size() - 1)]
	else:
		b.add_ground_item("crowbar", 1, b.street_spot(-75.0, -40.0))
	for spot: LootSpot in loot_spots:
		if spot == crowbar_spot:
			spot.inventory.add("crowbar")
		if rng.randf() < health_pack:
			spot.inventory.add("health_pack")
		if rng.randf() < ammo:
			spot.inventory.add("pistol_ammo", rng.randi_range(3, 7))
		if rng.randf() < trade_goods:
			if rng.randf() < 0.5:
				spot.inventory.add("canned_food", rng.randi_range(1, 2))
			else:
				spot.inventory.add("batteries", rng.randi_range(1, 3))


## Loose items lying in the street.
static func scatter(b: WorldBuilder, count: int) -> void:
	var rng := b.rng
	for i in count:
		var pos := b.street_spot(-75.0, 50.0)
		var roll := rng.randf()
		if roll < 0.45:
			b.add_ground_item("pistol_ammo", rng.randi_range(3, 7), pos)
		elif roll < 0.7:
			b.add_ground_item("health_pack", 1, pos)
		elif roll < 0.85:
			b.add_ground_item("canned_food", 1, pos)
		else:
			b.add_ground_item("batteries", rng.randi_range(1, 2), pos)
