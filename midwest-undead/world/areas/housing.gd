extends RefCounted
## The neighborhood around the police station: a row of houses across 7th Street
## (the cross street), more along it east of the compound, one in the gap on the
## west side (past it are the Main Street shops), and Elm Street behind the station
## with houses on both sides, joined to 7th by Oak Lane. Plus houses along 7th
## Street west of Main, out toward the Westside safe house.
## Every house can be entered, has a door, and has a kitchen cabinet and a
## dresser to search; some have a zombie inside.
## Never instanced: main.gd calls build(), then spawn_zombies() at the end.
##
## Everything random here uses its own generator (rng), so adding or changing
## houses never reshuffles the rest of the town, and older saves still load:
## their containers, doors and zombies come first, the houses' come after.

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")
const Loot := preload("res://world/loot.gd")

const ASPHALT := Color(0.16, 0.16, 0.17)
const HOUSE_COLORS := [
	Color(0.7, 0.68, 0.6),   # white siding, gone gray
	Color(0.55, 0.62, 0.66), # pale blue
	Color(0.62, 0.55, 0.42), # tan
	Color(0.5, 0.35, 0.3),   # brick
	Color(0.48, 0.52, 0.42), # sage
]
const ELM_STREET := Rect2(20.0, 39.0, 100.0, 8.0) # (x, z), as on the map
const OAK_LANE := Rect2(112.0, 5.0, 8.0, 34.0) # Elm Street's link to the cross street

## Rows of houses: x range, the z of their front walls, and which way they face
## (the street side). rotation +PI/2 means the house sits north of its front
## wall (facing south); -PI/2 means it sits south of it (facing north).
## depth is how far back each house goes.
const ROWS := [
	{"from": 26.0, "to": 110.0, "front": -6.0, "rotation": PI / 2.0, "depth": 11.0},  # across the cross street
	{"from": 72.0, "to": 110.0, "front": 6.0, "rotation": -PI / 2.0, "depth": 10.0},  # cross street, east of the compound
	{"from": 22.0, "to": 34.0, "front": 7.0, "rotation": -PI / 2.0, "depth": 10.0},   # the gap west of the compound
	{"from": 72.0, "to": 110.0, "front": 38.0, "rotation": PI / 2.0, "depth": 9.0},   # Elm Street, north side
	{"from": 22.0, "to": 34.0, "front": 38.0, "rotation": PI / 2.0, "depth": 7.0},    # Elm Street, north side, west end
	{"from": 22.0, "to": 110.0, "front": 48.0, "rotation": -PI / 2.0, "depth": 11.0}, # Elm Street, south side
	# 7th Street west of Main, out to the safe house (which starts at x = -143).
	{"from": -138.0, "to": -26.0, "front": 6.0, "rotation": -PI / 2.0, "depth": 11.0},  # south side
	# North side: none close to the bandit camp (leash 15 m + sight 25 m from
	# x = -28), and none past x = -138, where the gas station is.
	{"from": -138.0, "to": -70.0, "front": -6.0, "rotation": PI / 2.0, "depth": 11.0},  # north side
]


## Builds every house and fills its containers. Returns the spots inside where
## a zombie might be (for spawn_zombies, once the navigation mesh is baked).
static func build(b: WorldBuilder, rng: RandomNumberGenerator, door_open_chance: float,
		health_pack: float, ammo: float, trade_goods: float) -> Array[Vector3]:
	b.add_box(Vector3(ELM_STREET.size.x, 0.02, ELM_STREET.size.y),
			Vector3(ELM_STREET.get_center().x, 0.01, ELM_STREET.get_center().y), ASPHALT)
	b.add_box(Vector3(OAK_LANE.size.x, 0.02, OAK_LANE.size.y),
			Vector3(OAK_LANE.get_center().x, 0.01, OAK_LANE.get_center().y), ASPHALT)

	var first_spot := b.loot_spots.size()
	var interior: Array[Vector3] = []
	for row: Dictionary in ROWS:
		var x: float = row["from"]
		while true:
			var width := rng.randf_range(9.0, 12.0)
			if x + width > row["to"]:
				# Last one: shrink it to fill the row if there's room for a house at all.
				width = row["to"] - x
				if width < 8.0:
					break
			var house := Building.new()
			house.position = Vector3(x + width / 2.0, 0.0, row["front"])
			house.rotation.y = row["rotation"]
			b.nav_region.add_child(house)
			var color: Color = HOUSE_COLORS[rng.randi_range(0, HOUSE_COLORS.size() - 1)]
			# One storey plus an attic; floor flush with the ground (no sidewalk).
			house.build(row["depth"], width - 0.2, rng.randf_range(4.5, 6.0), color, rng,
					true, Building.BOARDED_CHANCE, 0.02, true)
			b.loot_spots.append_array(house.loot_spots)
			interior.append_array(house.interior_points)
			b.add_door(house.make_door(), rng.randf() < door_open_chance)
			x += width + rng.randf_range(3.0, 6.0) # a yard between houses

	for spot in b.loot_spots.slice(first_spot):
		Loot.roll_container(spot, rng, health_pack, ammo, trade_goods)
	return interior


## Elm Street and Oak Lane, as (x, z) rectangles for the map screen.
static func map_roads() -> Array[Rect2]:
	return [ELM_STREET, OAK_LANE]
