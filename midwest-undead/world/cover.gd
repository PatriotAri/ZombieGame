extends RefCounted
## Tall crops and thick bushes hide you while you crouch in them: zombies can't
## see you there unless they're right on top of you (they can still hear you).
## Cover is:
##   - any node in the "cover" group whose covers(pos) says so (a crop field,
##     world/map/crop_field.gd);
##   - plants painted with the terrain's instancer whose mesh ids are in
##     mesh_ids (world/map/plants.gd fills it: crops, bushes, tall grass).
## The player checks it now and then (player.gd: in_cover); zombie.gd reads that.
## Never instanced.

const PLANT_REACH := 0.9 # meters: this close to a painted plant counts as in it
const INSTANCER_CELL := 32 # Terrain3D stores painted plants in 32 m cells

static var terrain: Node = null # Terrain3D (world/game_map.gd sets it), for painted plants
static var mesh_ids: Array[int] = [] # instancer meshes that hide you


## Is pos inside cover?
static func hides(tree: SceneTree, pos: Vector3) -> bool:
	for node in tree.get_nodes_in_group("cover"):
		if node.call("covers", pos):
			return true
	return _near_painted_plant(pos)


static func _near_painted_plant(pos: Vector3) -> bool:
	if terrain == null or not is_instance_valid(terrain) or mesh_ids.is_empty():
		return false
	var region = terrain.data.get_regionp(pos)
	if region == null:
		return false
	var region_meters: float = terrain.region_size * terrain.vertex_spacing
	var offset := Vector3(region.location.x * region_meters, 0.0, region.location.y * region_meters)
	var local := pos - offset # painted plants are stored relative to their region
	var cell := Vector2i(floori(local.x / terrain.vertex_spacing) / INSTANCER_CELL,
			floori(local.z / terrain.vertex_spacing) / INSTANCER_CELL)
	var instances: Dictionary = region.instances
	for id: int in mesh_ids:
		var cells: Dictionary = instances.get(id, {})
		if not cells.has(cell):
			continue
		for xform: Transform3D in (cells[cell] as Array)[0]:
			if Vector2(xform.origin.x - local.x, xform.origin.z - local.z).length_squared() < PLANT_REACH * PLANT_REACH:
				return true
	return false
