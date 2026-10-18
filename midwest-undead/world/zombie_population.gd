extends Node
## How many zombies there are, and where new ones come from.
##
## Zombies never turn up where you'd see it happen: a new one goes on a random
## spot of the map that's out of your view or hidden from your eyes (behind a
## hill, a building, a tree trunk), at least MIN_DISTANCE from you and
## CAMP_MARGIN from any base camp (hidden_spot). Spots are random points on the
## navigation mesh, on the ground (not on roofs: world/ground.gd).
##
## At the start: extra zombies scattered around the map like that, on top of
## the ones main.gd places at the map scene's ZombieSpawn markers. A marker's
## zombie you'd see appear (or within MIN_DISTANCE of you) moves to a hidden
## spot nearby first.
##
## While you play: whenever fewer than `population` are still up, another one
## turns up now and then on a hidden spot, more often at night. Nothing sends them anywhere: they roam like
## the rest (zombie.gd), so over time some drift back into places you cleared.
## A horde (world/horde.gd) can push the count over `population`; nobody new
## turns up until it's back under.
##
## Bodies stay where they fell until you're well away (BODY_CLEANUP_DISTANCE)
## and not looking at them, then they're cleared away. Only the living are
## saved (main.gd).
## main.gd creates it and owns the tuning (the Inspector's "Zombies" group).

const Zombie := preload("res://characters/zombie/zombie.gd")
const Ground := preload("res://world/ground.gd")
const NavTiles := preload("res://world/nav_tiles.gd")
const GameData := preload("res://core/game_data.gd")

const CHECK_INTERVAL := 1.0
const MIN_DISTANCE := 30.0 # meters from you: nothing turns up closer
const CAMP_MARGIN := 40.0 # zombies turn up at least this far from any base camp
const MOVE_NEAR := 40.0 # a marker's zombie you'd see moves to a hidden spot within this of it
## Points on a zombie checked for whether you'd see it: feet, middle, head.
const LOOK_HEIGHTS: Array[float] = [0.3, 1.0, 1.7]
const BODY_CLEANUP_DISTANCE := 60.0

var population := 100 # zombies up at once that it tops back up to
var respawn_seconds_day := 30.0
var respawn_seconds_night := 10.0

var _main: Node # main.gd: owns the zombies list and _add_zombie
var _player: Node3D
var _day_night: Node
var _camps: Node # world/camps.gd
var bounds := Rect2() # the walkable area, (x, z): the whole map
var _triangles: Array[PackedVector3Array] = [] # the navigation mesh, for picking random spots
var _cumulative_area: PackedFloat32Array = []
var _check_timer := 0.0
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new() # during play: its own dice


func setup(main: Node, nav_region: NavTiles, player: Node3D, day_night: Node, camps: Node) -> void:
	_main = main
	_player = player
	_day_night = day_night
	_camps = camps
	var box := nav_region.bounds
	bounds = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for mesh in nav_region.meshes():
		_index_triangles(mesh, nav_region.global_transform)


## The extra zombies at the start. Call once, after main.gd has placed its own:
## those you'd see appear move out of sight first.
func populate(count: int, rng: RandomNumberGenerator, start: Vector3) -> void:
	for zombie: Node3D in _main.get("zombies"):
		var at := zombie.global_position
		if at.distance_to(start) < MIN_DISTANCE or seen(at):
			var spot := hidden_spot(rng, at, MOVE_NEAR)
			if spot == Vector3.INF:
				spot = hidden_spot(rng)
			if spot != Vector3.INF:
				zombie.global_position = spot + Vector3(0, 0.1, 0)
	for i in count:
		var pos := hidden_spot(rng)
		if pos != Vector3.INF:
			_main.call("_add_zombie", pos + Vector3(0, 0.1, 0), rng)
	_spawn_timer = respawn_seconds_day # nobody new in the first moments


## Could you see a zombie standing at pos? In your view (on screen) with
## nothing solid between your eyes and its feet, middle or head.
func seen(pos: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var space := get_viewport().get_world_3d().direct_space_state
	for height in LOOK_HEIGHTS:
		var point := pos + Vector3(0, height, 0)
		if not camera.is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, GameData.LAYER_WORLD)
		if space.intersect_ray(query).is_empty():
			return true
	return false


## A random spot on the ground where a zombie can turn up unseen: out of your
## sight, MIN_DISTANCE from you, CAMP_MARGIN from every camp. near / radius:
## only within radius of near. Vector3.INF if none turned up (try again later).
func hidden_spot(rng: RandomNumberGenerator, near := Vector3.INF, radius := 0.0) -> Vector3:
	for attempt in 60:
		var pos := random_point(rng) if near == Vector3.INF else _in_circle(rng, near, radius)
		if not Ground.is_ground_level(pos) or _near_camp(pos):
			continue
		if pos.distance_to(_player.global_position) < MIN_DISTANCE or seen(pos):
			continue
		return pos
	return Vector3.INF


func _process(delta: float) -> void:
	_check_timer -= delta
	_spawn_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_clear_bodies()
	if _spawn_timer > 0.0 or _alive() >= population:
		return
	var night := 1.0 - float(_day_night.call("light_level"))
	_spawn_timer = lerpf(respawn_seconds_day, respawn_seconds_night, night)
	var pos := hidden_spot(_rng)
	if pos != Vector3.INF:
		_main.call("_add_zombie", pos + Vector3(0, 0.1, 0), _rng)


func _alive() -> int:
	return get_tree().get_nodes_in_group("zombies").size() # the dead leave the group


## A random point on the ground within radius of center.
func _in_circle(rng: RandomNumberGenerator, center: Vector3, radius: float) -> Vector3:
	var angle := (rng.randf() if rng else randf()) * TAU
	var dist := radius * sqrt(rng.randf() if rng else randf())
	var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * dist
	if Ground.terrain:
		pos.y = Ground.height_at(pos)
	return pos


func _near_camp(pos: Vector3) -> bool:
	for camp in _camps.get("camps"):
		if Vector2(camp.center.x - pos.x, camp.center.z - pos.z).length() < CAMP_MARGIN:
			return true
	return false


## Bodies: gone once they've stopped falling, you're well away, and they're off
## screen (so you never see one vanish).
func _clear_bodies() -> void:
	var zombies: Array = _main.get("zombies")
	for i in range(zombies.size() - 1, -1, -1):
		var zombie: Zombie = zombies[i]
		if not zombie.is_dead or not zombie.body.is_settled or zombie.body.on_screen():
			continue
		if zombie.global_position.distance_to(_player.global_position) > BODY_CLEANUP_DISTANCE:
			zombies.remove_at(i)
			zombie.queue_free()


# --- Random spots on the navigation mesh --------------------------------------

func _index_triangles(mesh: NavigationMesh, xform: Transform3D) -> void:
	var verts := mesh.get_vertices()
	# Carries on from the tiles before (one running total for random_point's
	# search, not one per tile).
	var total: float = _cumulative_area[_cumulative_area.size() - 1] if not _cumulative_area.is_empty() else 0.0
	for p in mesh.get_polygon_count():
		var poly := mesh.get_polygon(p)
		for k in range(1, poly.size() - 1): # a fan of triangles
			var a := xform * verts[poly[0]]
			var b := xform * verts[poly[k]]
			var c := xform * verts[poly[k + 1]]
			var area := (b - a).cross(c - a).length() / 2.0
			if area <= 0.0001:
				continue
			_triangles.append(PackedVector3Array([a, b, c]))
			total += area
			_cumulative_area.append(total)


## Anywhere walkable, every square meter equally likely. rng null = any randomness.
func random_point(rng: RandomNumberGenerator) -> Vector3:
	if _triangles.is_empty():
		return Vector3.ZERO
	var r1 := rng.randf() if rng else randf()
	var r2 := rng.randf() if rng else randf()
	var r3 := rng.randf() if rng else randf()
	var pick := r1 * _cumulative_area[_cumulative_area.size() - 1]
	var tri := _triangles[mini(_cumulative_area.bsearch(pick), _triangles.size() - 1)]
	# A uniform point in the triangle.
	var s := sqrt(r2)
	return tri[0] * (1.0 - s) + tri[1] * (s * (1.0 - r3)) + tri[2] * (s * r3)
