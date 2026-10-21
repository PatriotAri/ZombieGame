extends Node3D
## The map the game is played on, and what's on it: loads the map scene
## (world/map/map.tscn), the sky and the time of day over it, the navigation
## zombies walk by, the painted trees' trunks, and what's in the containers;
## then finds what the rest of the game needs on it (containers, doors,
## windows, spawn points, places, mines) and answers questions about it. Its
## containers, doors and mines go in the save by their keys (core/save_ids.gd).
## main.gd makes one and calls build(), then, once the planks that are up at
## the start are on, bake_navigation().

const DayNight := preload("res://world/day_night.gd")
const Settings := preload("res://core/settings.gd")
const GameData := preload("res://core/game_data.gd")
const SkyShader := preload("res://world/sky_clouds.gdshader")
const NavTiles := preload("res://world/nav_tiles.gd")
const Ground := preload("res://world/ground.gd")
const Cover := preload("res://world/cover.gd")
const Plants := preload("res://world/map/plants.gd")
const Loot := preload("res://world/loot.gd")
const StaticMerge := preload("res://world/static_merge.gd")
const Instancer := preload("res://world/instancer.gd")
const SaveIds := preload("res://core/save_ids.gd")
const LootSpot := preload("res://items/loot_spot.gd")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")
const ZombieSpawn := preload("res://world/markers/zombie_spawn.gd")
const Place := preload("res://world/markers/place.gd")

# Set by main.gd (its Inspector settings) before build().
var map_scene: PackedScene
var start_hour := 8.0
var seconds_per_game_hour := 120.0
var night_ambient := Color(0.05, 0.06, 0.1)

var town: Node3D # the map scene, under nav_region
var terrain: Node # the map's Terrain3D node, or null
var nav_region: NavTiles # all map geometry lives under this node (the navigation bake reads it)
var day_night: DayNight
## Where you start: the map's "player" SpawnPoint.
var player_spawn := Transform3D.IDENTITY
# What's on the map, found when it's loaded. Everything that's saved carries a
# "save_key" (core/save_ids.gd), so saves find it again.
var loot_spots: Array[LootSpot] = []
var doors: Array[Door] = [] # moved out of the map, under this node (see _load)
var mines: Array[KitMine] = [] # their generators' fuel and cages are saved
var windows: Array[WindowPane] = []
var spawn_points: Array[SpawnPoint] = []
var zombie_spawns: Array[ZombieSpawn] = []
var places: Array[Place] = []
var salvage_others: Array[Node3D] = [] # things with a "salvage_label" that aren't containers (beds)
var _trunks: Array[RID] = [] # painted trees' solid trunks (world/map/plants.gd)


## Everything but the navigation bake. rng rolls what's in the containers.
func build(rng: RandomNumberGenerator) -> void:
	_build_environment()
	nav_region = NavTiles.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	_load()
	_setup_navigation()
	if terrain:
		# Painted trees get solid trunks (not in the navigation: zombies just
		# bump around them), and plants that hide you are known to world/cover.gd.
		var trees := Node3D.new()
		trees.name = "TreeTrunks" # what a bullet or a look reports hitting
		add_child(trees)
		_trunks = Plants.build_trunks(terrain, get_world_3d().space, trees)
		Cover.mesh_ids = Plants.hiding_ids()
	Loot.fill(loot_spots, rng)
	_save_things()


## Bake the walkable area from the map's terrain and collision shapes: every
## tile at once, on all the processor's cores (world/nav_tiles.gd).
func bake_navigation() -> void:
	nav_region.bake_all()


func _exit_tree() -> void:
	Plants.free_trunks(_trunks)
	_trunks.clear()


## Sky (with drifting clouds, see sky_clouds.gdshader), fog, sun and moon. Their
## colors and angles are set every frame by day_night.
func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A flat ambient color is easier to control across day and night than sky light.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	# Hill-country haze: about 70% clear at 100 m, 17% at 500 m, so ridges across
	# the map fade into the distance (and the hills past its edge, world/map/).
	env.fog_density = 0.0035
	# Fog would otherwise cover the sky completely, hiding the clouds. At this
	# strength it still blends the horizon into the haze.
	env.fog_sky_affect = 0.35

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	# Its shadows (off, medium, high) are the Shadows setting: Settings.apply_graphics.
	sun.add_to_group("sun")
	sun.light_cull_mask &= ~GameData.RENDER_UNDERGROUND # not in the mines (kit_mine.gd)
	add_child(sun)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # don't draw a second sun disk
	moon.light_cull_mask &= ~GameData.RENDER_UNDERGROUND
	add_child(moon)

	day_night = DayNight.new()
	day_night.start_hour = start_hour
	day_night.seconds_per_game_hour = seconds_per_game_hour
	day_night.night_ambient = night_ambient
	add_child(day_night)
	day_night.setup(env, sky_mat, sun, moon)
	Settings.apply_graphics() # shadows, view distance, resolution


## Where zombies can walk covers the whole map: the terrain's regions across,
## and from below its lowest ground to well above its highest (roofs and towers
## included). Without a terrain, a 512 m square around the middle.
func _setup_navigation() -> void:
	var rect := Ground.map_rect()
	if rect.size == Vector2.ZERO:
		rect = Rect2(-256, -256, 512, 512)
	var heights := Ground.height_range()
	nav_region.setup(AABB(Vector3(rect.position.x, heights.x - 5.0, rect.position.y),
			Vector3(rect.size.x, heights.y - heights.x + 45.0, rect.size.y)), terrain)


## Puts the map scene under nav_region and finds what the game needs in it.
## Doors move out first, under this node, so the navigation bake ignores them (zombie
## paths run through doorways; see door.gd); garage doors stay in it.
## Everything that's saved gets its "save_key" before that, while it's still
## part of the map scene (core/save_ids.gd).
func _load() -> void:
	town = map_scene.instantiate() as Node3D
	for node in town.find_children("*", "", true, false):
		if node.is_class("Terrain3D"):
			terrain = node
			break
	Ground.terrain = terrain
	Cover.terrain = terrain
	# Buildings and kit pieces make their walls, glass and doors from their
	# settings; have them do it now, so the doors and windows are there to find.
	for node in town.find_children("*", "", true, false):
		if node.has_method("ensure_built"):
			node.call("ensure_built")
	var door_holder := Node3D.new()
	door_holder.name = "Doors"
	add_child(door_holder)
	var unsaved := 0
	for node in town.find_children("*", "", true, false):
		if SaveIds.is_saveable(node):
			var key := SaveIds.key_of(node, town)
			node.set_meta(SaveIds.KEY, key)
			node.set_meta(SaveIds.MADE_IN_GAME, SaveIds.is_made_in_game(node))
			if key == "":
				unsaved += 1
		if node is LootSpot:
			loot_spots.append(node)
		elif node is WindowPane:
			windows.append(node)
		elif node is SpawnPoint:
			spawn_points.append(node)
		elif node is ZombieSpawn:
			zombie_spawns.append(node)
		elif node is Place:
			places.append(node)
		elif node is Door:
			doors.append(node)
		if node.has_meta("salvage_label") and not node is LootSpot:
			salvage_others.append(node)
		if node is KitMine:
			mines.append(node)
	if unsaved > 0:
		push_warning(("%d things on the map have no save ID, so they won't be saved: open the map scene "
				+ "(and any scene placed in it that holds them) in the editor and save it.") % unsaved)
	var moving: Array[Node3D] = [] # moving parts that aren't doors: a mine's cage and its gates
	for node in town.find_children("*", "", true, false):
		if node.is_in_group(&"not_in_navigation"):
			moving.append(node)
	var to_move: Array = [] # (untyped: doors and the rest)
	to_move.append_array(doors.filter(func(d: Door) -> bool: return not d.in_navigation)) # (a garage door stays in the bake: door.gd)
	to_move.append_array(moving)
	for door: Node3D in to_move:
		# Where it is in the map (the map's own nodes aren't in the tree yet).
		var xform := door.transform
		var parent := door.get_parent()
		while parent != town:
			if parent is Node3D:
				xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		door.get_parent().remove_child(door)
		door.owner = null # no longer part of the map scene
		door.transform = town.transform * xform
		door_holder.add_child(door, true)
	nav_region.add_child(town)
	Ground.deepest = INF # the game reaches down to the lowest mine floor
	for mine in town.find_children("*", "KitMine", true, false):
		Ground.deepest = minf(Ground.deepest, (mine as KitMine).lowest_floor())
	StaticMerge.merge(town) # buildings and kit pieces as a few big meshes (fewer draw calls)
	Instancer.batch(self) # the same doors, windows and furniture drawn together (GPU instancing)
	var start := spawn_point("player")
	player_spawn = Transform3D(Basis(Vector3.UP, start.global_rotation.y), start.global_position) if start \
			else Transform3D(Basis.IDENTITY, Ground.snap(Vector3.ZERO, 0.1))


## The containers, doors and mines go in the save by their keys.
func _save_things() -> void:
	for spot in loot_spots:
		_save_thing(spot, spot.save_state, spot.load_state)
	for door in doors:
		_save_thing(door, door.save_state, door.load_state)
	for mine in mines:
		_save_thing(mine, mine.save_state, mine.load_state)


func _save_thing(node: Node3D, saves: Callable, loads: Callable) -> void:
	var key := str(node.get_meta(SaveIds.KEY, ""))
	if key != "":
		Saveable.thing(node, key, saves, loads)


# --- Questions about the map ---------------------------------------------------

## The first SpawnPoint with this role, or null (with a warning).
func spawn_point(role: String) -> SpawnPoint:
	for spot in spawn_points:
		if spot.role == role:
			return spot
	push_warning("The map scene has no SpawnPoint with the role \"%s\"." % role)
	return null


## Where a SpawnPoint is, turned only about the vertical (an NPC stands upright).
func spawn_transform(role: String) -> Transform3D:
	var spot := spawn_point(role)
	if spot == null:
		return Transform3D(Basis.IDENTITY, Ground.snap(Vector3.ZERO))
	return Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)


## The police station's camp marker (a KitBaseCamp in the map scene), or null.
func base_camp_marker() -> KitBaseCamp:
	for node in town.find_children("*", "Marker3D", true, false):
		if node is KitBaseCamp:
			return node
	return null


## Where the Place called place_name is, or the middle (with a warning).
func place_position(place_name: String) -> Vector3:
	for place in places:
		if place.place_name == place_name:
			return place.global_position
	push_warning("The map scene has no Place called \"%s\"." % place_name)
	return Vector3.ZERO


## The mine a marker's in (under), or null.
func mine_of(node: Node) -> KitMine:
	while node != null and node != town:
		if node is KitMine:
			return node
		node = node.get_parent()
	return null


## Whether a container is within min_dist of pos (across the ground).
func near_container(pos: Vector3, min_dist: float) -> bool:
	for spot in loot_spots:
		if Vector2(pos.x - spot.global_position.x, pos.z - spot.global_position.z).length() < min_dist:
			return true
	return false
