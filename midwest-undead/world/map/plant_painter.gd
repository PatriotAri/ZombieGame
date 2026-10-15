@tool
extends RefCounted
## What the Map Tools panel's plant brushes do (addons/map_tools/): paint a
## natural forest, paint or place one kind of plant, and erase. Plants go into
## the terrain's instancer (world/map/plants.gd). Never instanced.
##
## The forest brush mixes the plants by their forest_share: trees at the
## density you set, undergrowth (bushes, ferns, logs) three times as thick
## between them. Toward the edge of the brush it thins out, so painted woods
## fade into the fields instead of stopping at a line. Nothing goes on slopes
## steeper than each plant's max_slope, under deep water, or closer than its
## spacing to another plant of the same kind (trees to trees, bushes to
## undergrowth...).

const Plants := preload("res://world/map/plants.gd")
const Water := preload("res://world/water.gd")
const INSTANCER_CELL := 32
const UNDERGROWTH_FACTOR := 3.0 # undergrowth this many times as thick as trees


## Paints forest in a circle. density: trees per 100 square meters (1 to 4 is
## open woods to thick forest). Returns how many plants it added.
static func paint_forest(terrain: Node, center: Vector3, radius: float, density: float, rng: RandomNumberGenerator) -> int:
	var trees: Array[PlantData] = []
	var under: Array[PlantData] = []
	for plant in Plants.all():
		if plant.forest_share > 0.0 and plant.mesh_id >= 0:
			(trees if plant.kind == "Tree" else under).append(plant)
	var area := PI * radius * radius
	var added := _scatter(terrain, center, radius, trees, area / 100.0 * density, true, rng)
	added += _scatter(terrain, center, radius, under, area / 100.0 * density * UNDERGROWTH_FACTOR, true, rng)
	return added


## Paints one kind of plant in a circle: density per 100 square meters.
static func paint_one(terrain: Node, center: Vector3, radius: float, plant: PlantData, density: float, rng: RandomNumberGenerator) -> int:
	return _scatter(terrain, center, radius, [plant], PI * radius * radius / 100.0 * density, false, rng)


## Puts one plant exactly at pos (if the slope allows it).
static func place_one(terrain: Node, pos: Vector3, plant: PlantData, rng: RandomNumberGenerator) -> bool:
	var p := Vector3(pos.x, _height(terrain, pos), pos.z)
	if not _fits(terrain, p, plant):
		return false
	var one: Array[Transform3D] = [_transform(p, plant, rng)]
	terrain.instancer.add_transforms(plant.mesh_id, one, PackedColorArray([_tint(rng)]), true)
	return true


## Removes plants in a circle: only those whose kind is in kinds ("Tree",
## "Undergrowth", "Crop"). Returns how many it removed.
static func erase(terrain: Node, center: Vector3, radius: float, kinds: Array) -> int:
	var plants := Plants.by_mesh_id()
	var removed := 0
	var region_meters: float = terrain.region_size * terrain.vertex_spacing
	for region in _regions_near(terrain, center, radius):
		var offset := Vector3(region.location.x * region_meters, 0.0, region.location.y * region_meters)
		var instances: Dictionary = region.instances
		var changed := false
		for id: int in instances:
			var plant: PlantData = plants.get(id)
			if plant == null or not plant.kind in kinds:
				continue
			for cell: Vector2i in instances[id]:
				var data: Array = instances[id][cell]
				var keep_xforms: Array[Transform3D] = []
				var keep_colors := PackedColorArray()
				var xforms: Array = data[0]
				var colors: PackedColorArray = data[1]
				for i in xforms.size():
					var g: Vector3 = (xforms[i] as Transform3D).origin + offset
					if Vector2(g.x - center.x, g.z - center.z).length() <= radius:
						removed += 1
						changed = true
					else:
						keep_xforms.append(xforms[i])
						keep_colors.append(colors[i] if i < colors.size() else Color.WHITE)
				if keep_xforms.size() != xforms.size():
					instances[id][cell] = [keep_xforms, keep_colors, true]
		if changed:
			region.instances = instances
			region.edited = true
			region.modified = true
	if removed > 0:
		terrain.instancer.update_mmis(true)
	return removed


## Copies of the painted plants of every region within radius of center, to
## put back with restore() (undo).
static func snapshot(terrain: Node, center: Vector3, radius: float) -> Dictionary:
	var shot := {}
	for region in _regions_near(terrain, center, radius):
		shot[region.location] = region.instances.duplicate(true)
	return shot


static func restore(terrain: Node, shot: Dictionary) -> void:
	for loc: Vector2i in shot:
		var region = terrain.data.get_region(loc)
		if region:
			region.instances = (shot[loc] as Dictionary).duplicate(true)
			region.edited = true
			region.modified = true
	terrain.instancer.update_mmis(true)


# --- Scattering ---------------------------------------------------------------------

static func _scatter(terrain: Node, center: Vector3, radius: float, choices: Array, count: float, fade: bool, rng: RandomNumberGenerator) -> int:
	if choices.is_empty() or count <= 0.0:
		return 0
	var total_share := 0.0
	for plant: PlantData in choices:
		total_share += maxf(plant.forest_share, 0.001)
	var kind: String = (choices[0] as PlantData).kind
	var widest := 0.0
	for plant: PlantData in choices:
		widest = maxf(widest, plant.spacing)
	var near := _positions(terrain, center, radius + widest, kind) # same-kind plants already there
	var batches := {} # mesh id -> [transforms, colors]
	var added := 0
	var tries := int(ceil(count * 3.0)) # some tries fail (spacing, slope)
	var want := int(round(count + rng.randf() - 0.5))
	for attempt in tries:
		if added >= want:
			break
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf())
		if fade and rng.randf() > 1.0 - pow(r / radius, 3.0) * 0.8:
			continue # thinner toward the edge
		var plant := _pick(choices, total_share, rng)
		var p := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = _height(terrain, p)
		if not _fits(terrain, p, plant) or _crowded(p, plant.spacing, near):
			continue
		near.append(p)
		if not batches.has(plant.mesh_id):
			var xforms: Array[Transform3D] = []
			batches[plant.mesh_id] = [xforms, PackedColorArray()]
		(batches[plant.mesh_id][0] as Array).append(_transform(p, plant, rng))
		var colors: PackedColorArray = batches[plant.mesh_id][1]
		colors.append(_tint(rng))
		batches[plant.mesh_id][1] = colors
		added += 1
	for id: int in batches:
		terrain.instancer.add_transforms(id, batches[id][0], batches[id][1], true)
	return added


static func _pick(choices: Array, total: float, rng: RandomNumberGenerator) -> PlantData:
	var roll := rng.randf() * total
	for plant: PlantData in choices:
		roll -= maxf(plant.forest_share, 0.001)
		if roll <= 0.0:
			return plant
	return choices[choices.size() - 1]


## On the map, not too steep for it, not under deep water.
static func _fits(terrain: Node, p: Vector3, plant: PlantData) -> bool:
	if not terrain.data.has_regionp(p):
		return false
	var normal: Vector3 = terrain.data.get_normal(p)
	if normal.is_finite() and rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))) > plant.max_slope:
		return false
	var tree := terrain.get_tree() if terrain.is_inside_tree() else null
	return tree == null or Water.depth_at(tree, p) < Water.SWIM_DEPTH * 0.5


static func _crowded(p: Vector3, spacing: float, near: Array) -> bool:
	for q: Vector3 in near:
		if Vector2(q.x - p.x, q.z - p.z).length_squared() < spacing * spacing:
			return true
	return false


static func _transform(p: Vector3, plant: PlantData, rng: RandomNumberGenerator) -> Transform3D:
	var s := rng.randf_range(plant.scale_min, plant.scale_max)
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p)


## A little color variation from plant to plant.
static func _tint(rng: RandomNumberGenerator) -> Color:
	var v := rng.randf_range(0.85, 1.1)
	return Color(v * rng.randf_range(0.95, 1.05), v, v * rng.randf_range(0.95, 1.05))


static func _height(terrain: Node, p: Vector3) -> float:
	var h: float = terrain.data.get_height(p)
	return 0.0 if is_nan(h) else h


## World positions of plants of this kind already within radius of center.
static func _positions(terrain: Node, center: Vector3, radius: float, kind: String) -> Array:
	var result := []
	var plants := Plants.by_mesh_id()
	var region_meters: float = terrain.region_size * terrain.vertex_spacing
	for region in _regions_near(terrain, center, radius):
		var offset := Vector3(region.location.x * region_meters, 0.0, region.location.y * region_meters)
		var instances: Dictionary = region.instances
		for id: int in instances:
			var plant: PlantData = plants.get(id)
			if plant == null or plant.kind != kind:
				continue
			for cell: Vector2i in instances[id]:
				for xform: Transform3D in (instances[id][cell] as Array)[0]:
					var g := xform.origin + offset
					if Vector2(g.x - center.x, g.z - center.z).length() <= radius:
						result.append(g)
	return result


static func _regions_near(terrain: Node, center: Vector3, radius: float) -> Array:
	var result := []
	var region_meters: float = terrain.region_size * terrain.vertex_spacing
	for x in range(floori((center.x - radius) / region_meters), floori((center.x + radius) / region_meters) + 1):
		for z in range(floori((center.z - radius) / region_meters), floori((center.z + radius) / region_meters) + 1):
			var region = terrain.data.get_region(Vector2i(x, z))
			if region and not region.deleted:
				result.append(region)
	return result
