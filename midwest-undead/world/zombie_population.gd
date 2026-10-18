extends Node
## How many zombies there are, and where new ones come from.
##
## At the start: extra zombies scattered around the map (away from the base
## camps and from where you begin), on top of the ones main.gd places at the map scene's
## ZombieSpawn markers. Placed at random spots on the navigation mesh, on the
## ground (not on roofs: world/ground.gd).
##
## While you play: whenever fewer than `population` are still up, another one
## turns up now and then on the outskirts of the map, far from you and away from
## the camps, more often at night. Nothing sends them anywhere: they roam like
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

const CHECK_INTERVAL := 1.0
const MIN_SPAWN_DISTANCE := 110.0 # from you: far enough that you never see one appear
const START_MIN_DISTANCE := 50.0 # extras at the start: this far from where you begin
const CAMP_MARGIN := 40.0 # zombies turn up at least this far from any base camp
const OUTSKIRTS := 35.0 # ...and within this of the edge of the walkable area
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


## The extra zombies at the start. Call once, after main.gd has placed its own.
func populate(count: int, rng: RandomNumberGenerator, start: Vector3) -> void:
	var placed := 0
	for attempt in count * 20:
		if placed >= count:
			break
		var pos := random_point(rng)
		if not Ground.is_ground_level(pos) or _near_camp(pos) or pos.distance_to(start) < START_MIN_DISTANCE:
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
	_clear_bodies()
	if _spawn_timer > 0.0 or _alive() >= population:
		return
	var night := 1.0 - float(_day_night.call("light_level"))
	_spawn_timer = lerpf(respawn_seconds_day, respawn_seconds_night, night)
	var pos := _outskirts_point()
	if pos != Vector3.INF:
		_main.call("_add_zombie", pos + Vector3(0, 0.1, 0), _rng)


func _alive() -> int:
	return get_tree().get_nodes_in_group("zombies").size() # the dead leave the group


## A random spot near the edge of the map, far from you and from every camp, or
## Vector3.INF if none turned up this time (it tries again next spawn).
func _outskirts_point() -> Vector3:
	var inner := bounds.grow(-OUTSKIRTS)
	for attempt in 30:
		var pos := random_point(null)
		if not Ground.is_ground_level(pos):
			continue
		if inner.has_point(Vector2(pos.x, pos.z)):
			continue # not on the outskirts
		if pos.distance_to(_player.global_position) < MIN_SPAWN_DISTANCE or _near_camp(pos):
			continue
		return pos
	return Vector3.INF


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
