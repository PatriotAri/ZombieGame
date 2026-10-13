extends RefCounted
## A gas station on 7th Street, across the road from the Westside safe house: a
## canopy over two pumps by the road, a small store behind it (a register and a
## snack shelf to search), and a tall sign.
## Never instanced: main.gd calls build(). Uses its own random generator, so it
## doesn't reshuffle the rest of the town.

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")
const Loot := preload("res://world/loot.gd")
const SafeHouse := preload("res://world/areas/safe_house.gd")

const CENTER_X := SafeHouse.SAFE_HOUSE_X # straight across from the safe house
const STORE_FRONT_Z := -21.0 # north side of 7th Street (-z is north)
const CANOPY_Z := -12.5 # middle of the canopy, between the road and the store
const CONCRETE := Color(0.62, 0.62, 0.6)
const STEEL := Color(0.75, 0.75, 0.78)
const STORE_COLOR := Color(0.78, 0.76, 0.7)
const PUMP_COLOR := Color(0.7, 0.15, 0.12)


## Returns the spots inside the store where a zombie might be.
static func build(b: WorldBuilder, rng: RandomNumberGenerator, door_open_chance: float,
		health_pack: float, ammo: float, trade_goods: float) -> Array[Vector3]:
	# The forecourt: a concrete slab from the road to the store (thin, so you
	# step onto it like the road), the canopy on four posts, two pumps.
	b.add_box(Vector3(18.0, 0.02, 15.0), Vector3(CENTER_X, 0.01, -13.0), CONCRETE)
	b.add_box(Vector3(14.0, 0.3, 8.0), Vector3(CENTER_X, 4.65, CANOPY_Z), STEEL)
	for x: float in [-6.0, 6.0]:
		for z: float in [-3.0, 3.0]:
			b.add_box(Vector3(0.3, 4.5, 0.3), Vector3(CENTER_X + x, 2.25, CANOPY_Z + z), STEEL)
	for x: float in [-2.5, 2.5]:
		b.add_box(Vector3(0.6, 1.5, 1.0), Vector3(CENTER_X + x, 0.75, CANOPY_Z), PUMP_COLOR)

	# The store faces the road, like the houses along 7th.
	var store := Building.new()
	store.position = Vector3(CENTER_X, 0.0, STORE_FRONT_Z)
	store.rotation.y = PI / 2.0 # it sits north of its front wall, facing south
	b.nav_region.add_child(store)
	var first_spot := b.loot_spots.size()
	store.build(8.0, 10.0, 4.2, STORE_COLOR, rng, true, Building.BOARDED_CHANCE, 0.02)
	b.loot_spots.append_array(store.loot_spots)
	for spot in store.loot_spots:
		spot.label = "Register" if spot.label == "Counter" else "Snack shelf"
	for spot in b.loot_spots.slice(first_spot):
		Loot.roll_container(spot, rng, health_pack, ammo, trade_goods)
		if spot.label == "Snack shelf":
			spot.inventory.add("canned_food", rng.randi_range(0, 2))
	b.add_door(store.make_door(), rng.randf() < door_open_chance)

	# A tall sign by the road, visible down 7th Street.
	b.add_box(Vector3(0.3, 7.0, 0.3), Vector3(CENTER_X + 10.0, 3.5, -7.0), STEEL)
	var sign := Label3D.new()
	sign.text = "GAS"
	sign.font_size = 160
	sign.pixel_size = 0.01
	sign.outline_size = 16
	sign.modulate = Color(1.0, 0.85, 0.3)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # readable from both ends of the street
	sign.position = Vector3(CENTER_X + 10.0, 7.6, -7.0)
	b.main.add_child(sign)
	return store.interior_points


static func map_position() -> Vector2:
	return Vector2(CENTER_X, STORE_FRONT_Z - 12.0)
