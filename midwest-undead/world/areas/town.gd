extends RefCounted
## Main Street: the ground, Main Street and 7th Street (the cross street), four
## rows of storefronts with their doors, alleys and dumpsters, the street sign at
## the corner, the dead streetlights, abandoned cars, and the water tower.
## Never instanced: main.gd calls build().

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")

const ASPHALT := Color(0.16, 0.16, 0.17)
const SIDEWALK := Color(0.5, 0.49, 0.46)
const GRASS := Color(0.32, 0.34, 0.2)
const CARDBOARD := Color(0.55, 0.42, 0.25)
const DUMPSTER := Color(0.15, 0.3, 0.2)
const BUILDING_COLORS := [
	Color(0.48, 0.22, 0.17), # red brick
	Color(0.58, 0.42, 0.3),  # tan brick
	Color(0.4, 0.38, 0.36),  # gray stone
	Color(0.62, 0.58, 0.5),  # painted siding
]
## 7th Street (the cross street), as an (x, z) rectangle: from past the Westside
## safe house to Oak Lane, east of the police station.
const CROSS_STREET := Rect2(-170.0, -5.0, 290.0, 10.0)
const MAIN_STREET := Rect2(-5.0, -85.0, 10.0, 170.0)
const CAR_COLORS := [
	Color(0.55, 0.1, 0.1),
	Color(0.15, 0.2, 0.35),
	Color(0.7, 0.7, 0.68),
	Color(0.2, 0.3, 0.2),
	Color(0.1, 0.1, 0.1),
]


## door_open_chance: how likely each shop's front door is to start open.
static func build(b: WorldBuilder, door_open_chance: float) -> void:
	# Ground for the whole map (the zone grid is ~780 m across), with room to spare.
	b.add_box(Vector3(840, 1, 840), Vector3(0, -0.5, 0), GRASS)
	# Main Street runs north-south; a cross street runs east-west.
	b.add_box(Vector3(MAIN_STREET.size.x, 0.02, MAIN_STREET.size.y), Vector3(0, 0.01, 0), ASPHALT)
	b.add_box(Vector3(CROSS_STREET.size.x, 0.02, CROSS_STREET.size.y),
			Vector3(CROSS_STREET.get_center().x, 0.01, CROSS_STREET.get_center().y), ASPHALT)
	for side: int in [-1, 1]:
		for dir: int in [-1, 1]:
			b.add_box(Vector3(3, 0.1, 75), Vector3(side * 6.5, 0.05, dir * 42.5), SIDEWALK)
			_build_block(b, side, dir, door_open_chance)
	_build_street_sign(b)
	_build_streetlights(b)
	_build_cars(b)
	_build_water_tower(b, Vector3(-45, 0, -65))


## Main Street and the cross street, as (x, z) rectangles for the map screen.
static func map_roads() -> Array[Rect2]:
	return [MAIN_STREET, CROSS_STREET]


## One row of storefronts on one side of Main Street.
static func _build_block(b: WorldBuilder, side: int, dir: int, door_open_chance: float) -> void:
	var rng := b.rng
	var depth := 12.0
	var z := 6.0
	while z < 76.0:
		if rng.randf() < 0.2:
			# An alley between buildings, usually with a dumpster in it.
			z += 3.0
			if rng.randf() < 0.7:
				b.add_loot(Vector3(2.0, 1.3, 1.2), Vector3(side * 9.8, 0.65, dir * (z - 1.5)),
						DUMPSTER, "Dumpster")
		var width := rng.randf_range(8.0, 13.0)
		var height := rng.randf_range(5.0, 9.5)
		var color: Color = BUILDING_COLORS[rng.randi_range(0, BUILDING_COLORS.size() - 1)]
		var center_z := dir * (z + width / 2.0)
		var building := Building.new()
		building.position = Vector3(side * 8.0, 0.0, center_z) # street face on the sidewalk's edge
		building.rotation.y = 0.0 if side == 1 else PI # local +x always points away from the street
		b.nav_region.add_child(building)
		building.build(depth, width - 0.2, height, color, rng)
		if not b.corner_shops.has(Vector2i(side, dir)):
			b.corner_shops[Vector2i(side, dir)] = building
		b.loot_spots.append_array(building.loot_spots)
		b.interior_points.append_array(building.interior_points)
		b.add_door(building.make_door(), b.door_rng.randf() < door_open_chance)
		b.door_spots.append(building.transform * Vector3(0.0, 0.0, building.door_z))
		# Sometimes a pile of boxes someone dragged out and abandoned, kept clear of the door.
		if rng.randf() < 0.3:
			var door_world_z := center_z + building.door_z * (1.0 if side == 1 else -1.0)
			var box_z := center_z + (width / 2.0 - 1.0) * (1.0 if door_world_z < center_z else -1.0)
			b.add_loot(Vector3(0.8, 0.7, 0.8), Vector3(side * 7.0, 0.45, box_z), CARDBOARD, "Cardboard boxes")
		z += width


## A sign post on the north-east corner of the intersection. Visual only (no
## collision), so it can't pinch the navigation mesh at the corner.
static func _build_street_sign(b: WorldBuilder) -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 3.0
	var base := Vector3(6.0, 0.1, -5.7)
	b.add_mesh(pole, base + Vector3(0, 1.5, 0), Color(0.3, 0.32, 0.3))
	# Each name twice, back to back and one-sided: a single double-sided label
	# reads mirrored from behind. A Label3D faces along its +z.
	for entry: Array in [["7TH ST", 2.75, 0.0], ["MAIN ST", 2.45, PI / 2.0]]:
		for flip: float in [0.0, PI]:
			var label := Label3D.new()
			label.text = entry[0]
			label.font_size = 36
			label.pixel_size = 0.01
			label.outline_size = 0
			label.double_sided = false
			label.modulate = Color(0.95, 0.95, 0.95)
			label.position = base + Vector3(0, entry[1], 0)
			label.rotation.y = entry[2] + flip
			b.main.add_child(label)


static func _build_streetlights(b: WorldBuilder) -> void:
	# The power has been out for weeks, so these are just poles now.
	var z := -78.0
	while z <= 78.0:
		if absf(z) > 7.0:
			for side: int in [-1, 1]:
				var pos := Vector3(side * 7.6, 2.5, z)
				if not _near_door(b, pos, 2.5):
					b.add_box(Vector3(0.15, 5.0, 0.15), pos, Color(0.2, 0.2, 0.2))
		z += 16.0


## A pole this close to a doorway pinches the navmesh shut in front of it (walls
## and poles both get an agent_radius margin), so zombies couldn't path inside.
static func _near_door(b: WorldBuilder, pos: Vector3, min_dist: float) -> bool:
	for door in b.door_spots:
		if Vector2(pos.x - door.x, pos.z - door.z).length() < min_dist:
			return true
	return false


static func _build_cars(b: WorldBuilder) -> void:
	var rng := b.rng
	for i in 9:
		var pos := Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-75.0, 40.0))
		for attempt in 10: # re-roll so cars don't end up inside each other
			if not b.near_car(pos, 5.0):
				break
			pos = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-75.0, 40.0))
		b.car_spots.append(pos)
		var yaw := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var color: Color = CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)]
		b.add_loot(Vector3(1.9, 0.8, 4.4), pos + Vector3(0, 0.55, 0), color, "Car", yaw)
		b.add_box(Vector3(1.7, 0.6, 2.2), pos + Vector3(0, 1.25, 0), color.darkened(0.3), yaw)


static func _build_water_tower(b: WorldBuilder, base: Vector3) -> void:
	var leg_color := Color(0.35, 0.36, 0.38)
	for x: float in [-2.5, 2.5]:
		for z: float in [-2.5, 2.5]:
			b.add_box(Vector3(0.3, 14.0, 0.3), base + Vector3(x, 7.0, z), leg_color)
	var tank := CylinderMesh.new()
	tank.top_radius = 4.0
	tank.bottom_radius = 4.0
	tank.height = 5.0
	b.add_mesh(tank, base + Vector3(0, 16.5, 0), Color(0.6, 0.62, 0.64))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.2
	roof.bottom_radius = 4.2
	roof.height = 2.0
	b.add_mesh(roof, base + Vector3(0, 20.0, 0), leg_color)
