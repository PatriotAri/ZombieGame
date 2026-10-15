@tool
extends Path3D
## A crop field: draw its outline as a path (click its corners; it closes
## itself), choose the crop and the way the rows run, and press Apply in the
## Map Tools panel to plow the ground under it. The crop stands in straight
## rows inside the outline, following the slope. Crouching in it hides you from
## zombies (world/cover.gd). Change the outline and Apply again any time.
## (To paint crops freely instead, use the Map Tools plant brush with a crop.)
##
## The rows are made from the outline when the map loads (nothing big is saved
## in the scene); the plowing is saved with the terrain.

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const PLOWED := 7 # the terrain's "Plowed field" texture

## Which crop (a PlantData file of kind Crop).
@export var crop: PlantData:
	set(value):
		crop = value
		rebuild_later()
## Degrees: the way the rows run (0 = along x, east-west; 90 = north-south).
@export_range(0.0, 180.0, 1.0) var row_angle := 0.0:
	set(value):
		row_angle = value
		rebuild_later()
## Meters between rows, and between plants along a row.
@export_range(0.3, 3.0, 0.05) var row_spacing := 0.9:
	set(value):
		row_spacing = value
		rebuild_later()
@export_range(0.15, 2.0, 0.05) var plant_spacing := 0.35:
	set(value):
		plant_spacing = value
		rebuild_later()

var _built: MultiMeshInstance3D
var _rebuild_queued := false
var _outline := PackedVector2Array() # world (x, z)


func _ready() -> void:
	add_to_group("cover")
	if curve == null:
		curve = Curve3D.new()
	if Engine.is_editor_hint():
		curve_changed.connect(rebuild_later)
		rebuild_later()
	else:
		_rebuild()


func rebuild_later() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## The field's corners on the ground (x, z).
func outline() -> PackedVector2Array:
	var result := PackedVector2Array()
	if curve == null:
		return result
	for i in curve.point_count:
		var p := global_transform * curve.get_point_position(i)
		result.append(Vector2(p.x, p.z))
	return result


## Inside the field (world/cover.gd asks: crouching here hides you).
func covers(pos: Vector3) -> bool:
	return _outline.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(pos.x, pos.z), _outline)


## Plows the ground inside the outline. Returns the (x, z) area changed.
func apply(terrain: Node) -> Rect2:
	var corners := outline()
	if corners.size() < 3:
		return Rect2()
	var rect := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		rect = rect.expand(c)
	var spacing: float = terrain.vertex_spacing
	for x in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing) + 1):
		for z in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing) + 1):
			var p := Vector2(x * spacing, z * spacing)
			if Geometry2D.is_point_in_polygon(p, corners):
				TerrainEdit.paint(terrain, Vector3(p.x, 0.0, p.y), PLOWED)
	TerrainEdit.finish(terrain, rect)
	rebuild_later()
	return rect


func _rebuild() -> void:
	_rebuild_queued = false
	_outline = outline()
	if _built:
		remove_child(_built)
		_built.queue_free()
		_built = null
	if crop == null or crop.scene == null or _outline.size() < 3:
		return
	var model := crop.scene.instantiate()
	var mesh: Mesh = (model as MeshInstance3D).mesh if model is MeshInstance3D else null
	model.free()
	if mesh == null:
		return
	var terrain := TerrainEdit.find_terrain(self)
	var xforms: Array[Transform3D] = []
	var rows := Vector2.RIGHT.rotated(deg_to_rad(row_angle)) # along a row
	var across := Vector2(-rows.y, rows.x)
	var rect := Rect2(_outline[0], Vector2.ZERO)
	for c in _outline:
		rect = rect.expand(c)
	var reach := rect.size.length()
	var middle := rect.get_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var r := -reach / 2.0
	while r <= reach / 2.0:
		var a := -reach / 2.0
		while a <= reach / 2.0:
			var p := middle + across * r + rows * (a + rng.randf_range(-0.05, 0.05))
			if Geometry2D.is_point_in_polygon(p, _outline):
				var y := TerrainEdit.height_at(terrain, Vector3(p.x, 0, p.y)) if terrain else global_position.y
				var s := rng.randf_range(crop.scale_min, crop.scale_max)
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y, p.y)))
			a += plant_spacing
		r += row_spacing
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	_built = MultiMeshInstance3D.new()
	_built.name = "Built"
	_built.multimesh = mm
	_built.top_level = true
	_built.visibility_range_end = crop.view_distance
	_built.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if crop.shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_built) # not owned: made fresh each time, never saved
