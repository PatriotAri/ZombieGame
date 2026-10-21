extends Node3D
## Where zombies (and NPCs) can walk: the navigation mesh, in square tiles.
##
## A navigation mesh is the "where can you walk" map. Godot works it out by
## scanning the geometry and leaving out anything too steep, too tall to step
## onto, or too close to a wall for someone of the given size. Doing that for a
## whole 1 km map at once takes seconds, so the map is cut into TILE-sized
## squares, each its own navigation region: at startup they're all baked at once
## (in parallel), and when something changes in play (you board up a window,
## build a fence) only the tiles it touches are baked again, in the background.
## The tiles' edges line up, so paths run from one to the next as if it were one.
##
## Everything that should block or carry zombies goes under this node: the map
## (its buildings and kit pieces), planks, barricades and what you build. The
## terrain is added to every bake by hand (Terrain3D's ground has no nodes for
## Godot's own scan to find), leaving out ground under deep water (ponds and
## creeks: world/water.gd), so paths go around it.
## world/game_map.gd creates it (as nav_region) and calls setup() and bake_all().

signal bake_finished # after any bake in play (not the startup one)

const TILE := 256.0 # meters: the same as the terrain's regions
## Each tile is baked from a little past its edges and then trimmed back, so
## neighbouring tiles meet exactly.
const BORDER := 2.0
const CELL_SIZE := 0.25 # meters: 2 cells = a zombie's radius, so doorways stay open
const Water := preload("res://world/water.gd")

var bounds := AABB() # what's baked: the whole map, from below its lowest ground to above its roofs
var _terrain: Node # Terrain3D, or null
var _regions := {} # Vector2i tile -> NavigationRegion3D
var _terrain_faces := {} # Vector2i tile -> PackedVector3Array (the terrain doesn't change in play)
var _dirty := {} # tiles to bake again (changed since their last bake)
var _baking := {} # tile -> the NavigationMesh being baked for it right now
var _variant_tasks: Array[int] = [] # WorkerThreadPool tasks of bake_variant() still running


## map_bounds: the map's extent (x, z) and the height range to bake (y).
func setup(map_bounds: AABB, terrain: Node) -> void:
	bounds = map_bounds
	_terrain = terrain
	for tile in tiles():
		var region := NavigationRegion3D.new()
		region.name = "NavTile_%d_%d" % [tile.x, tile.y]
		region.navigation_mesh = _new_mesh(tile)
		add_child(region)
		_regions[tile] = region


## Every tile the map covers.
func tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var from := Vector2i(floori(bounds.position.x / TILE), floori(bounds.position.z / TILE))
	var to := Vector2i(ceili(bounds.end.x / TILE), ceili(bounds.end.z / TILE))
	for x in range(from.x, to.x):
		for z in range(from.y, to.y):
			result.append(Vector2i(x, z))
	return result


## Each tile's navigation mesh, for reading its polygons (world/zombie_population.gd).
func meshes() -> Array[NavigationMesh]:
	var result: Array[NavigationMesh] = []
	for tile: Vector2i in _regions:
		result.append((_regions[tile] as NavigationRegion3D).navigation_mesh)
	return result


## Bakes every tile now, all at once on worker threads, and waits for them.
func bake_all() -> void:
	var shared := _parse()
	var list := tiles()
	var meshes_out: Array[NavigationMesh] = []
	var sources: Array[NavigationMeshSourceGeometryData3D] = []
	for tile in list:
		meshes_out.append(_new_mesh(tile))
		sources.append(_source(tile, shared))
	var task := WorkerThreadPool.add_group_task(func(i: int) -> void:
			NavigationServer3D.bake_from_source_geometry_data(meshes_out[i], sources[i]),
			list.size(), -1, true, "Navigation tiles")
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in list.size():
		(_regions[list[i]] as NavigationRegion3D).navigation_mesh = meshes_out[i]


## Something changed inside area (a world-space box): bake the tiles it touches
## again, in the background. Changes while a tile is baking are picked up by
## one more bake straight after.
func rebake(area: AABB) -> void:
	for tile in tiles():
		if _tile_box(tile).grow(BORDER).intersects(area):
			_dirty[tile] = true
	_next()


## Every tile again (in the background).
func rebake_all() -> void:
	for tile in tiles():
		_dirty[tile] = true
	_next()


## Bakes every tile with extra geometry added (world/horde.gd adds each closed
## door as a wall), on a thread; then calls done with {tile: NavigationMesh}.
## The tiles in use aren't touched.
func bake_variant(extra: NavigationMeshSourceGeometryData3D, done: Callable) -> void:
	var shared := _parse()
	shared.merge(extra)
	var list := tiles()
	var result := {}
	var sources := {}
	for tile in list:
		result[tile] = _new_mesh(tile)
		sources[tile] = _source(tile, shared)
	_variant_tasks.append(WorkerThreadPool.add_task(func() -> void:
		for tile: Vector2i in list:
			NavigationServer3D.bake_from_source_geometry_data(result[tile], sources[tile])
		done.call_deferred(result), true, "Navigation tiles (variant)"))


func _next() -> void:
	for tile: Vector2i in _dirty.keys():
		if _baking.has(tile):
			continue # picked up when that bake is done
		_dirty.erase(tile)
		var mesh := _new_mesh(tile)
		_baking[tile] = mesh
		# No "when done" callback: _process() looks for finished bakes instead.
		# (A script function handed to the navigation server can outlive the
		# script if you quit mid-bake, and crash the game on the way out.)
		NavigationServer3D.bake_from_source_geometry_data_async(mesh, _source(tile, _parse()))


func _process(_delta: float) -> void:
	if _baking.is_empty():
		return # (most frames: nothing baking)
	for tile: Vector2i in _baking.keys():
		if not NavigationServer3D.is_baking_navigation_mesh(_baking[tile]):
			_on_baked(tile, _baking[tile])


## Leaving (quitting, or loading a save): any bake still running on another
## thread has to finish first, or it would be working on freed memory.
func _exit_tree() -> void:
	for task in _variant_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_variant_tasks.clear()
	var waited := 0
	for tile: Vector2i in _baking:
		while NavigationServer3D.is_baking_navigation_mesh(_baking[tile]) and waited < 10000:
			OS.delay_msec(5)
			waited += 5


func _on_baked(tile: Vector2i, mesh: NavigationMesh) -> void:
	_baking.erase(tile)
	(_regions[tile] as NavigationRegion3D).navigation_mesh = mesh
	bake_finished.emit()
	if _dirty.has(tile):
		_next()


## The geometry under this node (collision shapes), read once per bake.
func _parse() -> NavigationMeshSourceGeometryData3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_new_mesh(Vector2i.ZERO), source, self)
	return source


## One tile's bake input: everything parsed, plus the terrain under the tile.
func _source(tile: Vector2i, shared: NavigationMeshSourceGeometryData3D) -> NavigationMeshSourceGeometryData3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	source.merge(shared)
	if _terrain:
		if not _terrain_faces.has(tile):
			_terrain_faces[tile] = _without_deep_water(
					_terrain.generate_nav_mesh_source_geometry(_tile_box(tile).grow(BORDER + 1.0), false), tile)
		source.add_faces(_terrain_faces[tile], Transform3D.IDENTITY)
	return source


## The terrain's triangles, less those under deep water.
func _without_deep_water(faces: PackedVector3Array, tile: Vector2i) -> PackedVector3Array:
	var box := _tile_box(tile).grow(BORDER + 1.0)
	var tile_rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var bodies := []
	for body in get_tree().get_nodes_in_group("water"):
		var rect: Rect2 = body.call("water_rect")
		if rect.intersects(tile_rect):
			bodies.append([rect, body])
	if bodies.is_empty():
		return faces
	var kept := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var c := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		var deep := false
		for pair: Array in bodies:
			if (pair[0] as Rect2).has_point(Vector2(c.x, c.z)):
				var s: float = pair[1].call("surface_at", c)
				if not is_nan(s) and s - c.y >= Water.SWIM_DEPTH:
					deep = true
					break
		if not deep:
			kept.append_array([faces[i], faces[i + 1], faces[i + 2]])
	return kept


func _tile_box(tile: Vector2i) -> AABB:
	return AABB(Vector3(tile.x * TILE, bounds.position.y, tile.y * TILE), Vector3(TILE, bounds.size.y, TILE))


func _new_mesh(tile: Vector2i) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	# Collision shapes, not visuals, so decorations like windows are ignored.
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_SIZE
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 45.0 # steeper than this, nobody climbs (characters slide; see player.gd)
	mesh.border_size = BORDER
	mesh.filter_baking_aabb = _tile_box(tile).grow(BORDER)
	return mesh
