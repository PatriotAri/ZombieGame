@tool
extends Node3D
## A pond or lake: a sheet of water at this node's height, size meters across.
## Dig the basin with the terrain's sculpting brushes first, then put a Pond
## over it and raise or lower it to the water level you want: the water shows
## wherever the ground is lower than it (the rest of the sheet is hidden under
## the ground, so it doesn't need to fit the shoreline). Turn it to line it up.
## Deep water is swimming; zombies avoid it and drown in it (world/water.gd).

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const WaterShader := preload("res://world/map/water.gdshader")

## Meters across (x) and along (z).
@export var size := Vector2(40.0, 30.0):
	set(value):
		size = value
		_rebuild()

var _built: MeshInstance3D
var _terrain: Node
static var _material: ShaderMaterial


func _ready() -> void:
	add_to_group("water")
	_terrain = TerrainEdit.find_terrain(self)
	_rebuild()


## The water surface over pos, or NAN if pos isn't over the water (world/water.gd).
func surface_at(pos: Vector3) -> float:
	var local := to_local(pos)
	if absf(local.x) > size.x / 2.0 or absf(local.z) > size.y / 2.0:
		return NAN
	var surface := global_position.y
	if _terrain and TerrainEdit.height_at(_terrain, pos) >= surface:
		return NAN # dry land inside the rectangle
	return surface


## The (x, z) area the water covers, for skipping the lookup far from it.
func water_rect() -> Rect2:
	var r := maxf(size.x, size.y) * 0.75 # covers it at any turn
	return Rect2(global_position.x - r, global_position.z - r, r * 2.0, r * 2.0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _built:
		_built.queue_free()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	_built = MeshInstance3D.new()
	_built.mesh = plane
	_built.material_override = _water_material()
	_built.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_built) # not owned: made fresh each time, never saved


static func _water_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = WaterShader
	return _material
