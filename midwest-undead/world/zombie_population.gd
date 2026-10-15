extends Node
## How many zombies there are, and where new ones come from.
##
## At the start: extra zombies scattered around the map (outside the zones, away
## from where you begin), on top of the ones main.gd places at the map scene's
## ZombieSpawn markers. Placed at random spots on the navigation mesh, on the
## ground (not on roofs: world/ground.gd).
##
## While you play: whenever fewer than `population` are still up, another one
## turns up now and then on the outskirts of the map, far from you and away from
## the zones, more often at night. Nothing sends them anywhere: they roam like
## the rest (zombie.gd), so over time some drift back into places you cleared.
## A horde (world/horde.gd) can push the count over `population`; nobody new
## turns up until it's back under.
##
## Bodies are cleared away a while after they fall, once you're well away. The
## living are saved (main.gd).
## main.gd creates it and owns the tuning (the Inspector's "Zombies" group).

const Zones := preload("res://world/zones.gd")
const Zombie := preload("res://characters/zombie/zombie.gd")
const Ground := preload("res://world/ground.gd")
const NavTiles := preload("res://world/nav_tiles.gd")

const CHECK_INTERVAL := 1.0
const MIN_SPAWN_DISTANCE := 110.0 # from you: far enough that you never see one appear
const START_MIN_DISTANCE := 50.0 # extras at the start: this far from where you begin
const ZONE_MARGIN := 40.0 # new ones turn up at least this far from any zone
const OUTSKIRTS := 35.0 # ...and within this of the edge of the walkable area
const BODY_CLEANUP_DISTANCE := 70.0
const BODY_CLEANUP_DELAY := 60.0 # seconds dead before a body can be cleared away

var population := 100 # zombies up at once that it tops back up to
var respawn_seconds_day := 30.0
var respawn_seconds_night := 10.0

var _main: Node # main.gd: owns the zombies list and _add_zombie
var _player: Node3D
var _day_night: Node
var _zones: Zones
var bounds := Rect2() # the walkable area, (x, z): the whole map
var _triangles: Array[PackedVector3Array] = [] # the navigation mesh, for picking random spots
var _cumulative_area: PackedFloat32Array = []
var _check_timer := 0.0
var _spawn_timer := 0.0
var _died_at := {} # zombie -> seconds since it died
var _rng := RandomNumberGenerator.new() # during play: its own dice


func setup(main: Node, nav_region: NavTiles, player: Node3D, day_night: Node, zones: Zones) -> void:
	_main = main
	_player = player
	_day_night = day_night
	_zones = zones
	var box := nav_region.bounds
	bounds = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for mesh in nav_region.meshes():
		_index_triangles(mesh, nav_region.global_transform)


## The extra zombies at the start. Call once, after main.gd has placed its own.
func populate(count: int, rng: RandomNumberGenerator, start: Vector3) -> void:
	var placed := 0
	for attempt in count * 20:
		if placed >= count:
			break
		var pos := random_point(rng)
		if not Ground.is_ground_level(pos) or _zones.zone_at(pos) != "" or pos.distance_to(start) < START_MIN_DISTANCE:
			continue
		_main.call("_add_zombie", pos + Vector3(0, 0.1, 0), rng)
		placed += 1
	_spawn_timer = respawn_seconds_day # nobody new in the first moments


func _process(delta: float) -> void:
	_check_timer -= delta
	_spawn_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_clear_bodies(CHECK_INTERVAL)
	if _spawn_timer > 0.0 or _alive() >= population:
		return
	var night := 1.0 - float(_day_night.call("light_level"))
	_spawn_timer = lerpf(respawn_seconds_day, respawn_seconds_night, night)
	var pos := _outskirts_point()
	if pos != Vector3.INF:
		_main.call("_add_zombie", pos + Vector3(0, 0.1, 0), _rng)


func _alive() -> int:
	return get_tree().get_nodes_in_group("zombies").size() # the dead leave the group


## A random spot near the edge of the map, far from you and from every zone, or
## Vector3.INF if none turned up this time (it tries again next spawn).
func _outskirts_point() -> Vector3:
	var inner := bounds.grow(-OUTSKIRTS)
	for attempt in 30:
		var pos := random_point(null)
		if not Ground.is_ground_level(pos):
			continue
		if inner.has_point(Vector2(pos.x, pos.z)):
			continue # not on the outskirts
		if pos.distance_to(_player.global_position) < MIN_SPAWN_DISTANCE or _near_zone(pos):
			continue
		return pos
	return Vector3.INF


func _near_zone(pos: Vector3) -> bool:
	for zone: Dictionary in Zones.ZONES:
		for rect: Rect2 in Zones.zone_rects(zone):
			if rect.grow(ZONE_MARGIN).has_point(Vector2(pos.x, pos.z)):
				return true
	return false


## Bodies: gone once they've been down a while and you're well away.
func _clear_bodies(elapsed: float) -> void:
	var zombies: Array = _main.get("zombies")
	for i in range(zombies.size() - 1, -1, -1):
		var zombie: Zombie = zombies[i]
		if not zombie.is_dead:
			continue
		_died_at[zombie] = float(_died_at.get(zombie, 0.0)) + elapsed
		if _died_at[zombie] >= BODY_CLEANUP_DELAY \
				and zombie.global_position.distance_to(_player.global_position) > BODY_CLEANUP_DISTANCE:
			_died_at.erase(zombie)
			zombies.remove_at(i)
			zombie.queue_free()


# --- Random spots on the navigation mesh --------------------------------------

func _index_triangles(mesh: NavigationMesh, xform: Transform3D) -> void:
	var verts := mesh.get_vertices()
	var total := 0.0
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
