@tool
extends RefCounted
## Reshaping and painting the terrain along a path: what a road's or a creek's
## Apply does (world/map/road.gd, world/map/creek.gd). Works in the editor (and
## in tests); the Map Tools plugin (addons/map_tools/) wraps each Apply in an
## undo step using snapshot() and restore(). Never instanced.

const MAP_HEIGHT := 0
const MAP_CONTROL := 1
const MAP_ALL := 3


## The map's Terrain3D (a child of the map's root, so a child of one of node's
## ancestors), or null.
static func find_terrain(node: Node) -> Node:
	var n := node
	while n:
		for child in n.get_children():
			if child.is_class("Terrain3D"):
				return child
		n = n.get_parent()
	return null


static func height_at(terrain: Node, pos: Vector3) -> float:
	var h: float = terrain.data.get_height(pos)
	return 0.0 if is_nan(h) else h


## Copies of the height and paint maps of every region touching rect (x, z),
## to put back with restore() (undo).
static func snapshot(terrain: Node, rect: Rect2) -> Dictionary:
	var shot := {}
	for loc in _regions_in(terrain, rect):
		var region = terrain.data.get_region(loc)
		if region:
			shot[loc] = [region.height_map.duplicate(), region.control_map.duplicate()]
	return shot


static func restore(terrain: Node, shot: Dictionary) -> void:
	for loc: Vector2i in shot:
		var region = terrain.data.get_region(loc)
		if region == null:
			continue
		region.height_map = (shot[loc][0] as Image).duplicate()
		region.control_map = (shot[loc][1] as Image).duplicate()
		region.edited = true
		region.modified = true
	_refresh(terrain)


## Paints a ground texture (an id in the terrain's texture list) at pos, solid:
## no blending, and the autoshader off there (so it isn't grass or rock by slope).
static func paint(terrain: Node, pos: Vector3, texture_id: int) -> void:
	terrain.data.set_control_base_id(pos, texture_id)
	terrain.data.set_control_overlay_id(pos, texture_id)
	terrain.data.set_control_blend(pos, 0.0)
	terrain.data.set_control_auto(pos, false)


## Calls shape(vertex: Vector3 (with its current height), nearest: Dictionary
## (a sample), distance: float) for every terrain vertex within reach of the
## samples' line, each with the nearest sample. Each sample needs "pos" (a
## Vector3; its x and z are used). shape sets heights and paint itself.
static func along(terrain: Node, samples: Array, reach: float, shape: Callable) -> void:
	if samples.is_empty():
		return
	var spacing: float = terrain.vertex_spacing
	var rect := bounds(samples, reach)
	# Exactly on the terrain's vertices: set_height() rounds down to the pixel,
	# so -150.00003 would land on the row next to -150.
	var corner := (rect.position / spacing).floor() * spacing
	rect = Rect2(corner, rect.end - corner)
	var cols := int(ceil(rect.size.x / spacing)) + 1
	var rows := int(ceil(rect.size.y / spacing)) + 1
	var best_d := PackedFloat32Array()
	best_d.resize(cols * rows)
	best_d.fill(INF)
	var best_i := PackedInt32Array()
	best_i.resize(cols * rows)
	var cells := int(ceil(reach / spacing))
	for i in samples.size():
		var p: Vector3 = samples[i]["pos"]
		var cx := int(round((p.x - rect.position.x) / spacing))
		var cz := int(round((p.z - rect.position.y) / spacing))
		for gz in range(maxi(cz - cells, 0), mini(cz + cells + 1, rows)):
			var vz := rect.position.y + gz * spacing
			for gx in range(maxi(cx - cells, 0), mini(cx + cells + 1, cols)):
				var vx := rect.position.x + gx * spacing
				var d := Vector2(vx - p.x, vz - p.z).length()
				var k := gz * cols + gx
				if d < best_d[k]:
					best_d[k] = d
					best_i[k] = i
	for gz in rows:
		for gx in cols:
			var k := gz * cols + gx
			if best_d[k] > reach:
				continue
			var v := Vector3(round(rect.position.x / spacing + gx) * spacing, 0.0, round(rect.position.y / spacing + gz) * spacing)
			if not terrain.data.has_regionp(v):
				continue
			v.y = height_at(terrain, v)
			shape.call(v, samples[best_i[k]], best_d[k])


## The (x, z) rectangle a path (a Path3D's curve) covers.
static func path_rect(path: Path3D) -> Rect2:
	if path.curve == null or path.curve.point_count == 0:
		return Rect2(path.global_position.x, path.global_position.z, 0, 0)
	var points := path.curve.get_baked_points()
	var first := path.global_transform * points[0]
	var rect := Rect2(first.x, first.z, 0, 0)
	for p in points:
		var g := path.global_transform * p
		rect = rect.expand(Vector2(g.x, g.z))
	return rect


## The (x, z) rectangle the samples cover, grown by reach.
static func bounds(samples: Array, reach: float) -> Rect2:
	var first: Vector3 = samples[0]["pos"]
	var rect := Rect2(first.x, first.z, 0, 0)
	for s: Dictionary in samples:
		rect = rect.expand(Vector2(s["pos"].x, s["pos"].z))
	return rect.grow(reach + 1.0)


## After changing heights or paint: mark the regions changed (so they're saved
## with the scene) and update what's drawn.
static func finish(terrain: Node, rect: Rect2) -> void:
	for loc in _regions_in(terrain, rect):
		var region = terrain.data.get_region(loc)
		if region:
			region.edited = true
			region.modified = true
	_refresh(terrain)


static func _refresh(terrain: Node) -> void:
	terrain.data.update_maps(MAP_ALL, false, false)
	terrain.data.calc_height_range(true)
	if terrain.collision and terrain.collision.is_enabled():
		terrain.collision.update(true)


static func _regions_in(terrain: Node, rect: Rect2) -> Array[Vector2i]:
	var size: float = terrain.region_size * terrain.vertex_spacing
	var result: Array[Vector2i] = []
	for x in range(floori(rect.position.x / size), floori(rect.end.x / size) + 1):
		for z in range(floori(rect.position.y / size), floori(rect.end.y / size) + 1):
			result.append(Vector2i(x, z))
	return result
