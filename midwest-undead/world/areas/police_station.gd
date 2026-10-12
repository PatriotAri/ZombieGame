extends RefCounted
## The fenced police compound on the cross street, east of Main Street: the
## station (trader, logbook, the Chief), a plywood fence with an unbreakable
## sliding gate, and two guard towers covering the street.
## Never instanced: main.gd calls build() and keeps what it returns.

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")
const Door := preload("res://world/door.gd")
const SavePoint := preload("res://world/save_point.gd")
const Guard := preload("res://characters/npcs/guard.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const ShopkeeperScene := preload("res://characters/npcs/shopkeeper.tscn")
const PoliceChief := preload("res://characters/npcs/police_chief.gd")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const GameData := preload("res://core/game_data.gd")

# The station sits on the south side of the cross street, east of Main Street.
# (Directions: +x is east and -z is north, the way the map screen is drawn.)
const STATION_X := 52.0 # center of its street face
const STATION_FRONT_Z := 9.0
const COMPOUND_MIN := Vector2(36.0, 6.0) # fence corners (x, z)
const COMPOUND_MAX := Vector2(68.0, 30.0)
const GATE_HALF_WIDTH := 5.0
const GATE_COLOR := Color(0.3, 0.32, 0.34) # steel
const CONCRETE := Color(0.55, 0.57, 0.6)
const PLYWOOD := Color(0.55, 0.45, 0.3)
const TIMBER := Color(0.35, 0.27, 0.18)


## Returns {"trader", "chief"}.
static func build(b: WorldBuilder) -> Dictionary:
	var result := {}
	var station := Building.new()
	station.position = Vector3(STATION_X, 0.0, STATION_FRONT_Z)
	station.rotation.y = -PI / 2.0 # local +x (into the building) points south, away from the street
	b.nav_region.add_child(station)
	# No shop furniture or zombies inside; floor flush with the ground (no sidewalk here).
	station.build(14.0, 20.0, 7.0, CONCRETE, b.rng, false, Building.BOARDED_CHANCE, 0.02)

	var sign := Label3D.new()
	sign.text = "POLICE"
	sign.font_size = 80
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.position = Vector3(-0.06, 4.1, station.door_z) # just in front of the facade, over the door
	sign.rotation.y = -PI / 2.0 # Label3D reads from its +Z side; turn that to face the street
	station.add_child(sign)
	b.add_door(station.make_door(), false)

	# Inside: a counter across the room, the trader behind it, and a generator-powered lamp.
	b.add_box(Vector3(0.8, 1.0, 6.0), station.transform * Vector3(8.0, 0.6, 0.0), TIMBER, station.rotation.y)
	var trader := ShopkeeperScene.instantiate() as Shopkeeper
	trader.position = station.transform * Vector3(9.3, 0.1, 0.0) # faces -z: toward the counter and door
	b.main.add_child(trader)
	result["trader"] = trader
	# The logbook on the counter (top at y = 1.1), off to one side: save / load.
	var logbook := SavePoint.new()
	logbook.position = station.transform * Vector3(8.0, 1.1, 2.0)
	logbook.rotation.y = station.rotation.y + 0.3
	b.nav_region.add_child(logbook)
	# The Chief's corner: a desk with the dead radio, back right past the counter.
	var desk_yaw := station.rotation.y
	b.add_box(Vector3(1.0, 0.85, 2.2), station.transform * Vector3(12.6, 0.525, 6.5), TIMBER, desk_yaw)
	b.add_box(Vector3(0.35, 0.22, 0.5), station.transform * Vector3(12.6, 1.06, 6.0), Color(0.15, 0.17, 0.15), desk_yaw)
	var chief := PoliceChiefScene.instantiate() as PoliceChief
	chief.position = station.transform * Vector3(11.4, 0.1, 6.5) # in front of the desk, facing the room
	b.main.add_child(chief)
	result["chief"] = chief

	var lamp := OmniLight3D.new()
	lamp.position = station.transform * Vector3(6.0, 3.0, 0.0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.5
	lamp.omni_range = 11.0
	b.main.add_child(lamp)

	# Plywood fence around the compound, with a gate facing the street.
	var fence_h := 2.2
	var x0 := COMPOUND_MIN.x
	var x1 := COMPOUND_MAX.x
	var z0 := COMPOUND_MIN.y
	var z1 := COMPOUND_MAX.y
	var gate0 := STATION_X - GATE_HALF_WIDTH
	var gate1 := STATION_X + GATE_HALF_WIDTH
	b.add_box(Vector3(gate0 - x0, fence_h, 0.15), Vector3((x0 + gate0) / 2.0, fence_h / 2.0, z0), PLYWOOD)
	b.add_box(Vector3(x1 - gate1, fence_h, 0.15), Vector3((gate1 + x1) / 2.0, fence_h / 2.0, z0), PLYWOOD)
	b.add_box(Vector3(x1 - x0, fence_h, 0.15), Vector3((x0 + x1) / 2.0, fence_h / 2.0, z1), PLYWOOD)
	for x in [x0, x1]:
		b.add_box(Vector3(0.15, fence_h, z1 - z0), Vector3(x, fence_h / 2.0, (z0 + z1) / 2.0), PLYWOOD)
	_build_gate(b, gate0, gate1, z0, fence_h)

	# Guard towers in the two front corners, covering the street and the gate.
	for tower_x in [x0 + 2.5, x1 - 2.5]:
		var base := Vector3(tower_x, 0.0, z0 + 2.5)
		var tower_rids := _build_guard_tower(b, base)
		var guard := GuardScene.instantiate() as Guard
		guard.exclude = tower_rids
		guard.position = base + Vector3(0, 4.2, 0)
		b.main.add_child(guard) # starts facing -z (the street); turns toward targets as it fires
	return result


## The compound fence, as an (x, z) rectangle for the map screen.
static func map_fence() -> Rect2:
	return Rect2(COMPOUND_MIN, COMPOUND_MAX - COMPOUND_MIN)


## Two steel leaves that slide sideways behind the fence. Zombies can't break it.
## The navigation bake sees a wall where the gate is (a stand-in on the nav-only
## layer: invisible to physics, so it doesn't block anyone; it stays for every
## re-bake), so with the gate shut zombies have no path into the compound; while
## it's open, NavigationLinks across the gap give them one.
static func _build_gate(b: WorldBuilder, gate0: float, gate1: float, fence_z: float, height: float) -> void:
	var z := fence_z + 0.2 # just inside the fence line, so open leaves slide behind it
	var half := (gate1 - gate0) / 2.0
	var leaf := Vector3(half + 0.2, height, 0.1) # overlaps the fence a little at the outer end
	var leaves: Array[Door] = []
	for s: int in [-1, 1]:
		var center := Vector3((gate0 + gate1) / 2.0 + s * (half + 0.2) / 2.0, height / 2.0, z)
		var gate := Door.new()
		gate.label = "gate"
		gate.breakable = false
		gate.clear_path_when_closing = true
		gate.setup(leaf, Vector3.ZERO, GATE_COLOR, Transform3D(Basis.IDENTITY, center), 0.0,
				Vector3(s * half, 0.0, 0.0))
		leaves.append(gate)
	leaves[0].linked = [leaves[1]]
	leaves[1].linked = [leaves[0]]

	var x := gate0 + 1.0
	while x <= gate1 - 1.0:
		var link := NavigationLink3D.new()
		# Ends just off the navmesh edges on either side of the gap. Kept short on
		# purpose: zombies repath every 0.3 s, and a start point far behind one that's
		# already in the gap would turn it around (path_desired_distance is 0.6 m).
		link.start_position = Vector3(x, 0.0, fence_z - 0.5) # street side
		link.end_position = Vector3(x, 0.0, fence_z + 0.7) # compound side
		link.enabled = false
		b.main.add_child(link)
		leaves[0].nav_links.append(link)
		x += 2.0

	for gate in leaves:
		b.add_door(gate, false)

	var blocker := StaticBody3D.new()
	blocker.collision_layer = GameData.LAYER_NAV_ONLY
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(gate1 - gate0, height, 0.15)
	var col := CollisionShape3D.new()
	col.shape = shape
	blocker.add_child(col)
	blocker.position = Vector3((gate0 + gate1) / 2.0, height / 2.0, z)
	b.nav_region.add_child(blocker)


## Four timber legs, a platform at 4 m and a waist-high railing. Returns the
## physics ids of its parts so the guard's aim ignores its own tower.
static func _build_guard_tower(b: WorldBuilder, base: Vector3) -> Array[RID]:
	var rids: Array[RID] = []
	for x: float in [-1.2, 1.2]:
		for z: float in [-1.2, 1.2]:
			rids.append(b.add_box(Vector3(0.25, 4.0, 0.25), base + Vector3(x, 2.0, z), TIMBER).get_rid())
	rids.append(b.add_box(Vector3(3.0, 0.2, 3.0), base + Vector3(0, 4.1, 0), TIMBER).get_rid())
	for s: float in [-1.45, 1.45]:
		rids.append(b.add_box(Vector3(3.0, 0.9, 0.1), base + Vector3(0, 4.65, s), PLYWOOD).get_rid())
		rids.append(b.add_box(Vector3(0.1, 0.9, 3.0), base + Vector3(s, 4.65, 0), PLYWOOD).get_rid())
	return rids
