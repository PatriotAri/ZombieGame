extends RefCounted
## How high the ground is anywhere on the map: the Terrain3D node's heights
## (world/map/map.tscn), which are there whether or not that spot has collision.
## world/game_map.gd hands it the terrain when the map loads. Never instanced.
##
## "Ground level" means standing on the terrain itself, not on a roof, a floor
## upstairs or the top of a wall: spawning (world/zombie_population.gd and
## world/horde.gd) only uses spots at ground level.

## How far above or below the terrain still counts as on it (sidewalks, porches
## and ground floors sit a little above it).
const GROUND_LEVEL_TOLERANCE := 1.0

static var terrain: Node = null # Terrain3D, or null (then the ground is y = 0)
static var deepest := INF # the lowest mine floor (world/game_map.gd sets it): height_range() reaches down to it


## The terrain's height under a point (y = 0 without a terrain, or off its edge).
static func height_at(pos: Vector3) -> float:
	if terrain == null or not is_instance_valid(terrain):
		return 0.0
	var h: float = terrain.data.get_height(pos)
	return 0.0 if is_nan(h) else h


## Standing on the terrain, not on something built on it.
static func is_ground_level(pos: Vector3) -> bool:
	return absf(pos.y - height_at(pos)) <= GROUND_LEVEL_TOLERANCE


## The same point, moved up or down onto the terrain.
static func snap(pos: Vector3, lift := 0.0) -> Vector3:
	return Vector3(pos.x, height_at(pos) + lift, pos.z)


## The map's extent on the ground (x, z), from the terrain's regions; an empty
## rectangle without a terrain.
static func map_rect() -> Rect2:
	if terrain == null or not is_instance_valid(terrain):
		return Rect2()
	var size: float = terrain.region_size * terrain.vertex_spacing
	var rect := Rect2()
	var first := true
	for loc: Vector2i in terrain.data.region_locations:
		var r := Rect2(Vector2(loc) * size, Vector2(size, size))
		rect = r if first else rect.merge(r)
		first = false
	return rect


## How steeply you'd be climbing, going `dir` on ground facing `normal`:
## rise over run uphill, 0 across or downhill. The player and zombies slow
## down by it (each by its own amount).
static func uphill_rise(normal: Vector3, dir: Vector3) -> float:
	return maxf(-dir.dot(Vector3(normal.x, 0.0, normal.z)), 0.0) / maxf(normal.y, 0.1)


## The lowest and highest ground on the map (Vector2(min, max)), the lowest
## taking in the mines (anything under that has fallen out of the world).
static func height_range() -> Vector2:
	if terrain == null or not is_instance_valid(terrain):
		return Vector2(minf(0.0, deepest), 0.0)
	var heights: Vector2 = terrain.data.get_height_range()
	return Vector2(minf(heights.x, deepest), heights.y)
