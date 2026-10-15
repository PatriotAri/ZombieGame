extends Node
## Hordes. Every 10 to 18 days, at a random hour, a horde turns up together on
## one edge of town (a random side well out of your sight) and walks across to
## the far side, where it breaks up into ordinary roaming zombies. Nothing sends
## it anywhere in particular, and there's no warning: you find out when you see
## or hear it. On the way, any that see or hear someone go after them like any
## zombie, then carry on across (zombie.gd: march_to).
##
## It goes around buildings, not through them: zombies only break a door down
## when they're after someone or heard something, so a horde just walking
## across would jam up against the first closed door on its way. When a horde
## sets off, an "outdoor" copy of the walkable area is baked with every door
## (that isn't broken) as a solid wall, and marching zombies find their way on
## that (zombie.gd: march_map). Windows aren't on it either.
##
## The first horde is 20 strong, and each one after brings 3 to 7 more, up to
## 40. Once one has been 40 strong, each is a random 25 to 40.
##
## They come on top of the town's usual number: zombie_population.gd doesn't
## top the town back up until there are fewer than its population again.
## main.gd creates it and saves it.
## TUNING: the constants below.

const ZombiePopulation := preload("res://world/zombie_population.gd")
const Zombie := preload("res://characters/zombie/zombie.gd")
const Door := preload("res://world/door.gd")
const SaveGame := preload("res://core/save_game.gd")

const DAYS_BETWEEN := Vector2i(10, 18)
const FIRST_SIZE := 20
const GROWTH := Vector2i(3, 7) # more each time, until...
const MAX_SIZE := 40
const LATER_SIZE := Vector2i(25, 40) # ...after one has been MAX_SIZE strong
const SPREAD := 25.0 # meters from the middle of the group that each one starts
const PER_FRAME := 5 # zombies put in the world each frame (100 at once would stutter)
const CHECK_INTERVAL := 1.0
const RETRY_SECONDS := 30.0 # nowhere out of your sight to start from: try again after this
const DOOR_THICKNESS := 0.4 # the wall each door is on the outdoor map

var next_day := 0 # when the next horde comes
var next_hour := 0.0
var last_size := 0 # the last horde's size (0: none yet)
var peaked := false # one has been MAX_SIZE strong
var outdoor_map := RID() # see the top; made the first time it's needed
var _outdoor_region := RID()
var _outdoor_mesh: NavigationMesh
var _baking := false
var _outdoor_ready := false
var _sending := 0 # a horde this size waits on the bake
var _pending: Array[Dictionary] = [] # {"position", "march"}: still to put in the world
var _main: Node # main.gd: _add_zombie, zombies, doors
var _population: ZombiePopulation # the walkable area, random spots on it
var _nav_region: NavigationRegion3D
var _player: Node3D
var _day_night: Node
var _check_timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup(main: Node, population: ZombiePopulation, nav_region: NavigationRegion3D, player: Node3D, day_night: Node) -> void:
	_main = main
	_population = population
	_nav_region = nav_region
	_player = player
	_day_night = day_night
	_rng.randomize()
	_schedule()


func _exit_tree() -> void:
	if _outdoor_region.is_valid():
		NavigationServer3D.free_rid(_outdoor_region)
	if outdoor_map.is_valid():
		NavigationServer3D.free_rid(outdoor_map)


func _process(delta: float) -> void:
	if _outdoor_ready:
		for i in mini(PER_FRAME, _pending.size()):
			var entry: Dictionary = _pending.pop_back()
			var zombie: Zombie = _main.call("_add_zombie", entry["position"], _rng)
			zombie.march_to = entry["march"]
			zombie.march_map = outdoor_map
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	var day: int = _day_night.day
	if day > next_day or (day == next_day and float(_day_night.hour) >= next_hour):
		send()


## Sends the next horde: bakes the outdoor map, then picks where it starts.
func send() -> void:
	if _sending > 0:
		return # already on its way
	_sending = _next_size()
	_bake_outdoor()


func _next_size() -> int:
	if peaked:
		return _rng.randi_range(LATER_SIZE.x, LATER_SIZE.y)
	if last_size == 0:
		return FIRST_SIZE
	return mini(last_size + _rng.randi_range(GROWTH.x, GROWTH.y), MAX_SIZE)


func _schedule() -> void:
	next_day = int(_day_night.day) + _rng.randi_range(DAYS_BETWEEN.x, DAYS_BETWEEN.y)
	next_hour = _rng.randf_range(0.0, 24.0)


# --- The outdoor map ------------------------------------------------------------

## The town's walkable area again, with every door that isn't broken as a wall.
## Baked fresh each horde (on a thread), so it has whatever you've built since.
func _bake_outdoor() -> void:
	if _baking:
		return
	_baking = true
	_outdoor_mesh = _nav_region.navigation_mesh.duplicate()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_outdoor_mesh, source, _nav_region)
	for door: Door in _main.get("doors"):
		if door.is_broken:
			continue
		var size := Vector3(maxf(door.leaf_size.x, DOOR_THICKNESS), door.leaf_size.y, door.leaf_size.z)
		source.add_faces(_box_faces(size), door.closed_transform() * Transform3D(Basis.IDENTITY, door.leaf_offset))
	NavigationServer3D.bake_from_source_geometry_data_async(_outdoor_mesh, source,
			func() -> void: _on_outdoor_baked.call_deferred())


## A box's triangles, centered on the origin. (Not a BoxMesh: the bake would
## have to read that back from the graphics card.)
static func _box_faces(size: Vector3) -> PackedVector3Array:
	var h := size / 2.0
	var c := [] # the 8 corners: bit 0 = +x, bit 1 = +y, bit 2 = +z
	for i in 8:
		c.append(Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	var faces := PackedVector3Array()
	for quad: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		faces.append_array([c[quad[0]], c[quad[1]], c[quad[2]], c[quad[0]], c[quad[2]], c[quad[3]]])
	return faces


func _on_outdoor_baked() -> void:
	if not is_inside_tree():
		return
	_baking = false
	if not outdoor_map.is_valid():
		var town_map := _nav_region.get_navigation_map()
		outdoor_map = NavigationServer3D.map_create()
		NavigationServer3D.map_set_cell_size(outdoor_map, NavigationServer3D.map_get_cell_size(town_map))
		NavigationServer3D.map_set_cell_height(outdoor_map, NavigationServer3D.map_get_cell_height(town_map))
		NavigationServer3D.map_set_active(outdoor_map, true)
		_outdoor_region = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(_outdoor_region, outdoor_map)
		NavigationServer3D.region_set_transform(_outdoor_region, _nav_region.global_transform)
	NavigationServer3D.region_set_navigation_mesh(_outdoor_region, _outdoor_mesh)
	# The map takes the new mesh in over the next few physics steps (on a thread):
	# wait until it answers with a spot on it.
	var probe := _nav_region.global_transform * _outdoor_mesh.get_vertices()[_outdoor_mesh.get_polygon(0)[0]]
	while NavigationServer3D.map_get_iteration_id(outdoor_map) == 0 \
			or NavigationServer3D.map_get_closest_point(outdoor_map, probe).distance_to(probe) > 0.5:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	_outdoor_ready = true
	for zombie: Zombie in _main.get("zombies"):
		if zombie.march_to != Vector3.INF:
			zombie.march_map = outdoor_map # (after loading a save)
	if _sending > 0:
		_send_now()


func _send_now() -> void:
	var plan := _plan(_sending)
	if plan.is_empty():
		_sending = 0
		_check_timer = RETRY_SECONDS
		return
	_pending.append_array(plan)
	last_size = _sending
	peaked = peaked or _sending >= MAX_SIZE
	_sending = 0
	_schedule()


# --- Where it starts --------------------------------------------------------------

## Where each one starts and where it walks to: a group on one side of town,
## each heading for the matching spot on the far side. The side is wherever a
## random good spot for the group's middle turned up (_anchor), so it's random
## among the sides that are far enough from you: the town is small, and from
## some places only one side is.
func _plan(size: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var center := Vector3(_population.bounds.get_center().x, 0.0, _population.bounds.get_center().y)
	var anchor := _anchor(center)
	if anchor == Vector3.INF:
		return plan
	var across := Vector3(center.x - anchor.x, 0.0, center.z - anchor.z).normalized()
	var anchor_goal := _goal(anchor, center, across)
	for i in size:
		var start := _near(anchor)
		var goal := _goal(start, center, across)
		if not _reaches(start, goal):
			start = anchor # cut off (a yard, an island of the map): start with the middle instead
			goal = anchor_goal
		plan.append({"position": start + Vector3(0, 0.1, 0), "march": goal})
	return plan


## The matching spot on the far side: mirrored across the middle of town, along
## the way it's going.
func _goal(start: Vector3, center: Vector3, across: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(outdoor_map, start + across * 2.0 * (center - start).dot(across))


## Can it walk from start to goal on the outdoor map?
func _reaches(start: Vector3, goal: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(outdoor_map, start, goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) < Zombie.MARCH_ARRIVED


## The middle of the group: on the outskirts, outdoors, far from you, with a
## way across.
func _anchor(center: Vector3) -> Vector3:
	var inner := _population.bounds.grow(-ZombiePopulation.OUTSKIRTS)
	for attempt in 400:
		var pos := _population.random_point(_rng)
		if pos.y > ZombiePopulation.MAX_SPAWN_HEIGHT or inner.has_point(Vector2(pos.x, pos.z)):
			continue
		if pos.distance_to(_player.global_position) < ZombiePopulation.MIN_SPAWN_DISTANCE + SPREAD:
			continue
		var outdoors := NavigationServer3D.map_get_closest_point(outdoor_map, pos)
		var across := Vector3(center.x - pos.x, 0.0, center.z - pos.z).normalized()
		if outdoors.distance_to(pos) > 0.5 or not _reaches(outdoors, _goal(outdoors, center, across)):
			continue
		return outdoors
	return Vector3.INF


## A walkable spot within SPREAD of the group's middle.
func _near(anchor: Vector3) -> Vector3:
	for attempt in 10:
		var angle := _rng.randf() * TAU
		var wanted := anchor + Vector3(cos(angle), 0.0, sin(angle)) * SPREAD * sqrt(_rng.randf())
		var pos := NavigationServer3D.map_get_closest_point(outdoor_map, wanted)
		if Vector2(pos.x - wanted.x, pos.z - wanted.z).length() < 2.0 and pos.y <= ZombiePopulation.MAX_SPAWN_HEIGHT \
				and pos.distance_to(_player.global_position) >= ZombiePopulation.MIN_SPAWN_DISTANCE:
			return pos
	return anchor # crowded in: they shove apart


# --- Saving -----------------------------------------------------------------------

func save_state() -> Dictionary:
	var pending := []
	for entry in _pending:
		pending.append({"position": SaveGame.vec_to_array(entry["position"]), "march": SaveGame.vec_to_array(entry["march"])})
	return {"next_day": next_day, "next_hour": next_hour, "last_size": last_size, "peaked": peaked,
			"sending": _sending, "pending": pending}


## After main.gd has put the zombies back. A save from before hordes has none:
## the first comes 10 to 18 days after the day it was saved on.
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		_schedule()
		return
	next_day = int(data.get("next_day", next_day))
	next_hour = float(data.get("next_hour", next_hour))
	last_size = int(data.get("last_size", 0))
	peaked = bool(data.get("peaked", false))
	_sending = int(data.get("sending", 0))
	_pending.clear()
	for entry: Dictionary in data.get("pending", []):
		_pending.append({"position": SaveGame.array_to_vec(entry["position"]), "march": SaveGame.array_to_vec(entry["march"])})
	var marching: bool = (_main.get("zombies") as Array).any(func(z: Zombie) -> bool: return z.march_to != Vector3.INF)
	if marching or _sending > 0 or not _pending.is_empty():
		_bake_outdoor() # a horde on its way: the marchers need their map back
