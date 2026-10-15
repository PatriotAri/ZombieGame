@tool
extends RefCounted
## The plants you paint on the map (world/map/plants/: one PlantData file
## each). Painted plants live in the terrain (Terrain3D's instancer: thousands
## of them drawn in batches); this keeps the terrain's mesh list in step with
## the plant files, and in the game gives trees their solid trunks and tells
## world/cover.gd which plants hide you. Never instanced.

const DIR := "res://world/map/plants/"
const TRUNK_HEIGHT := 5.0 # meters of solid trunk from the ground up
const INSTANCER_CELL := 32
const GameData := preload("res://core/game_data.gd")


## Every plant file, by mesh id order (those without one yet last).
static func all() -> Array[PlantData]:
	var result: Array[PlantData] = []
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for file: String in files:
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var plant := load(DIR + file) as PlantData
		if plant:
			result.append(plant)
	result.sort_custom(func(a: PlantData, b: PlantData) -> bool:
		return (a.mesh_id if a.mesh_id >= 0 else 9999) < (b.mesh_id if b.mesh_id >= 0 else 9999))
	return result


## mesh id -> PlantData.
static func by_mesh_id() -> Dictionary:
	var result := {}
	for plant in all():
		if plant.mesh_id >= 0:
			result[plant.mesh_id] = plant
	return result


## Makes the terrain's mesh list match the plant files: each plant gets a slot
## (new ones the next free number, written back into their file), with its
## model, how far it's drawn and its shadows. Returns how many were new.
## (The Map Tools panel's "Update plant list".)
static func sync(assets: Resource) -> int:
	var added := 0
	var used := {}
	for plant in all():
		if plant.mesh_id >= 0:
			used[plant.mesh_id] = true
	for plant in all():
		if plant.mesh_id < 0:
			var id := 0
			while used.has(id):
				id += 1
			plant.mesh_id = id
			used[id] = true
			ResourceSaver.save(plant, plant.resource_path)
			added += 1
		var asset = assets.get_mesh_asset(plant.mesh_id)
		if asset == null:
			asset = ClassDB.instantiate("Terrain3DMeshAsset")
		asset.name = plant.display_name
		asset.id = plant.mesh_id
		asset.scene_file = plant.scene
		asset.lod0_range = plant.view_distance
		asset.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if plant.shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		assets.set_mesh_asset(plant.mesh_id, asset)
	return added


## The mesh ids of plants that hide you when you crouch in them (world/cover.gd).
static func hiding_ids() -> Array[int]:
	var result: Array[int] = []
	for plant in all():
		if plant.hides and plant.mesh_id >= 0:
			result.append(plant.mesh_id)
	return result


## In the game: a solid trunk for every painted tree, so they stop people and
## bullets and block sight. Made straight in the physics engine (one static
## body per terrain region, a cylinder per tree), not as nodes: there can be
## tens of thousands. Collisions report owner (a node) as what was hit.
## Returns the bodies, to free when the map goes (free_trunks).
static func build_trunks(terrain: Node, space: RID, owner: Node) -> Array[RID]:
	var bodies: Array[RID] = []
	var plants := by_mesh_id()
	var shapes := {} # radius (cm) -> cylinder shape RID
	var region_meters: float = terrain.region_size * terrain.vertex_spacing
	for region in terrain.data.get_regions_active():
		var body := RID()
		var offset := Vector3(region.location.x * region_meters, 0.0, region.location.y * region_meters)
		var instances: Dictionary = region.instances
		for id: int in instances:
			var plant: PlantData = plants.get(id)
			if plant == null or plant.trunk_radius <= 0.0:
				continue
			for cell: Vector2i in instances[id]:
				for xform: Transform3D in (instances[id][cell] as Array)[0]:
					var size := xform.basis.get_scale().x
					var radius_cm := maxi(5, int(round(plant.trunk_radius * size * 20.0)) * 5)
					if not shapes.has(radius_cm):
						var shape := PhysicsServer3D.cylinder_shape_create()
						PhysicsServer3D.shape_set_data(shape, {"radius": radius_cm / 100.0, "height": TRUNK_HEIGHT})
						shapes[radius_cm] = shape
					if not body.is_valid():
						body = PhysicsServer3D.body_create()
						PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
						PhysicsServer3D.body_set_collision_layer(body, GameData.LAYER_WORLD)
						PhysicsServer3D.body_set_collision_mask(body, 0)
						PhysicsServer3D.body_attach_object_instance_id(body, owner.get_instance_id())
						PhysicsServer3D.body_set_space(body, space)
						bodies.append(body)
					var at := offset + xform.origin + Vector3(0, TRUNK_HEIGHT / 2.0, 0)
					PhysicsServer3D.body_add_shape(body, shapes[radius_cm], Transform3D(Basis.IDENTITY, at))
	for shape: RID in shapes.values():
		bodies.append(shape) # freed along with the bodies
	return bodies


static func free_trunks(rids: Array[RID]) -> void:
	for rid in rids:
		PhysicsServer3D.free_rid(rid)
