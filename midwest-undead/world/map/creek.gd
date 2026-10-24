@tool
extends Path3D
## A creek. Draw it as a path from where it starts (upstream) to where it ends
## (downstream), set its width and depth, and press Apply in the Map Tools
## panel: a channel is carved along it and lined with creek stones, and the
## water runs along the bed, always downhill. Where it drops steeply the water
## turns to white rapids by itself; for a waterfall, add a CreekFalls child
## (world/map/creek_falls.gd) where the ledge should be.
##
## Wading: the water is depth deep in the middle (shallow water slows you;
## SWIM_DEPTH or deeper is swimming: world/water.gd).
## The bed's heights are worked out when you press Apply and kept with the
## creek (so applying again doesn't dig it any deeper); the water surface is
## made from them when the map loads.

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const CreekFalls := preload("res://world/map/creek_falls.gd")
const WaterShader := preload("res://world/map/water.gdshader")

const STEP := 1.0 # meters between samples along the creek
const SMOOTHING := 6 # samples each way that the ground under it is averaged over
const FALL_MIN := 0.5 # meters: a drop this big in one step draws as a falling sheet

## Meters across the water where it starts and where it ends (it widens in between).
@export_range(0.5, 30.0, 0.1) var width_start := 3.0:
	set(value):
		width_start = value
		rebuild_later()
@export_range(0.5, 30.0, 0.1) var width_end := 5.0:
	set(value):
		width_end = value
		rebuild_later()
## Meters of water in the middle of the channel.
@export_range(0.1, 4.0, 0.05) var depth := 0.6:
	set(value):
		depth = value
		rebuild_later()
## Meters each side over which the banks slope back up to the ground.
@export_range(0.5, 15.0, 0.5) var bank := 3.0
## Drop per meter (0.06 = 6 cm per meter) above which the water is rapids.
@export_range(0.01, 0.5, 0.01) var rapids_grade := 0.06:
	set(value):
		rapids_grade = value
		rebuild_later()
# Kept with the creek (saved, not shown in the Inspector), so applying again
# doesn't dig any deeper:
@export_storage var bed := PackedFloat32Array() # the bed, every STEP meters (set by Apply)
@export_storage var ground_before := PackedFloat32Array() # the ground along it before the first Apply
@export_storage var applied_points := PackedVector3Array() # the path when it was applied
@export_storage var applied_depth := 0.0 # the depth it was last applied at

var _built: Node3D
var _rebuild_queued := false
var _rect := Rect2() # water_rect(), once worked out
var _water: PackedFloat32Array # water surface heights, every STEP meters (bed + depth)
var _last_ground := PackedFloat32Array() # what work_out_bed() last started from
static var _material: ShaderMaterial


func _ready() -> void:
	add_to_group("water")
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


func falls() -> Array[CreekFalls]:
	var result: Array[CreekFalls] = []
	for child in get_children():
		if child is CreekFalls:
			result.append(child)
	return result


func width_at(offset: float) -> float:
	var length := maxf(curve.get_baked_length(), 0.01)
	return lerpf(width_start, width_end, clampf(offset / length, 0.0, 1.0))


## The water surface over pos, or NAN if pos isn't over the water (world/water.gd).
func surface_at(pos: Vector3) -> float:
	if _water.is_empty():
		return NAN
	var local := to_local(pos)
	var offset := curve.get_closest_offset(local)
	var on := curve.sample_baked(offset)
	if Vector2(local.x - on.x, local.z - on.z).length() > width_at(offset) / 2.0:
		return NAN
	var i := clampi(int(round(offset / STEP)), 0, _water.size() - 1)
	return _water[i]


## The (x, z) area the water covers, for skipping the lookup far from it.
## Worked out once in the game (it doesn't move); afresh in the editor.
func water_rect() -> Rect2:
	if _rect.has_area() and not Engine.is_editor_hint():
		return _rect
	_rect = TerrainEdit.path_rect(self).grow(maxf(width_start, width_end))
	return _rect


## The bed every STEP meters along the creek, from the ground as it is now:
## the ground, a little smoothed, minus depth; never rising downstream; level
## for a pool above each falls, dropping at the falls.
func work_out_bed(terrain: Node) -> PackedFloat32Array:
	var length := curve.get_baked_length()
	var count := maxi(2, ceili(length / STEP) + 1)
	var ground := PackedFloat32Array()
	if ground_before.size() == count and _points() == applied_points:
		ground = ground_before # the same path as last time: the ground as it was then
	else:
		for i in count:
			var pos := global_transform * curve.sample_baked(length * i / (count - 1), true)
			var g := TerrainEdit.height_at(terrain, pos) if terrain else pos.y
			if terrain and _carved(terrain, pos):
				g += applied_depth # an earlier Apply dug this deep: the ground was that much higher
			ground.append(g)
	_last_ground = ground
	var result := PackedFloat32Array()
	for i in count:
		var total := 0.0
		var n := 0
		for k in range(maxi(0, i - SMOOTHING), mini(count, i + SMOOTHING + 1)):
			total += ground[k]
			n += 1
		result.append(total / n - depth)
	for i in range(1, count): # water runs downhill
		result[i] = minf(result[i], result[i - 1])
	for fall in falls():
		var at := int(round(curve.get_closest_offset(to_local(fall.global_position)) / STEP))
		var lip := clampi(at - int(fall.pool / STEP), 0, count - 1)
		for i in range(lip, mini(at, count)):
			result[i] = result[lip] # the pool above the falls stays level...
		# ...and everything below it is as low as the ground takes it (the drop).
	return result


## The path's points, in the world (to tell whether it moved since the last Apply).
func _points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in curve.point_count:
		result.append(global_transform * curve.get_point_position(i))
	return result


## Already a channel here (creek stones from an earlier Apply)?
func _carved(terrain: Node, pos: Vector3) -> bool:
	return applied_depth > 0.0 and terrain.data.get_control_base_id(pos) == 9 \
			and not terrain.data.get_control_auto(pos)


## Carves the channel and paints it (see the top). Returns the (x, z) area changed.
func apply(terrain: Node) -> Rect2:
	bed = work_out_bed(terrain)
	ground_before = _last_ground
	applied_points = _points()
	applied_depth = depth
	var list := _samples()
	if list.is_empty():
		return Rect2()
	var reach := maxf(width_start, width_end) / 2.0 + bank
	TerrainEdit.along(terrain, list, reach, func(v: Vector3, s: Dictionary, d: float) -> void:
		var half: float = s["width"] / 2.0
		var floor_y: float = s["bed"]
		var water_y: float = floor_y + depth
		var h := v.y
		if d <= half:
			h = floor_y + depth * 0.9 * pow(d / half, 2.0) # deepest in the middle
			TerrainEdit.paint(terrain, v, 9) # creek stones
		else:
			var t := clampf((d - half) / bank, 0.0, 1.0)
			h = minf(v.y, lerpf(water_y + 0.15, v.y, smoothstep(0.0, 1.0, t)))
			if t < 0.5:
				TerrainEdit.paint(terrain, v, 3) # dirt banks
		if not is_equal_approx(h, v.y):
			terrain.data.set_height(v, h))
	var rect := TerrainEdit.bounds(list, reach)
	TerrainEdit.finish(terrain, rect)
	rebuild_later()
	return rect


## {"pos", "dir", "offset", "width", "bed"} every STEP meters (bed from `bed`,
## or worked out from the ground if it hasn't been applied yet).
func _samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if curve == null or curve.point_count < 2:
		return result
	var heights := bed
	var length := curve.get_baked_length()
	var count := maxi(2, ceili(length / STEP) + 1)
	if heights.size() != count:
		heights = work_out_bed(TerrainEdit.find_terrain(self))
	for i in count:
		var offset := length * i / (count - 1)
		var pos := global_transform * curve.sample_baked(offset, true)
		var ahead := global_transform * curve.sample_baked(minf(offset + 0.5, length), true)
		var behind := global_transform * curve.sample_baked(maxf(offset - 0.5, 0.0), true)
		result.append({"pos": Vector3(pos.x, heights[i], pos.z), "offset": offset, "width": width_at(offset),
				"dir": Vector3(ahead.x - behind.x, 0.0, ahead.z - behind.z).normalized(), "bed": heights[i]})
	return result


# --- What's drawn ------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_queued = false
	_rect = Rect2()
	if _built:
		remove_child(_built) # out now, so the new one can have its name
		_built.queue_free()
		_built = null
	var list := _samples()
	_water = PackedFloat32Array()
	for s: Dictionary in list:
		_water.append(float(s["bed"]) + depth)
	if list.size() < 2:
		return
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built) # not owned: made fresh each time, never saved
	_built.top_level = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in list.size() - 1:
		var a: Dictionary = list[i]
		var b: Dictionary = list[i + 1]
		var drop := _water[i] - _water[i + 1]
		var foam := clampf(drop / STEP / rapids_grade - 1.0, 0.0, 1.0)
		var ra := Vector3(-a["dir"].z, 0, a["dir"].x) * (float(a["width"]) / 2.0 + 0.3)
		var rb := Vector3(-b["dir"].z, 0, b["dir"].x) * (float(b["width"]) / 2.0 + 0.3)
		var pa := Vector3(a["pos"].x, _water[i], a["pos"].z)
		var pb := Vector3(b["pos"].x, _water[i + 1], b["pos"].z)
		if drop >= FALL_MIN: # a waterfall: level to the lip, then a falling sheet
			var lip := Vector3(pb.x, pa.y, pb.z)
			_quad(st, pa - ra, pa + ra, lip - rb, lip + rb, float(a["offset"]), float(b["offset"]), foam)
			_quad(st, lip - rb, lip + rb, pb - rb, pb + rb, float(b["offset"]), float(b["offset"]) + drop, 1.0)
		else:
			_quad(st, pa - ra, pa + ra, pb - rb, pb + rb, float(a["offset"]), float(b["offset"]), foam)
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _water_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(inst)


func _quad(st: SurfaceTool, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, va: float, vb: float, foam: float) -> void:
	st.set_color(Color(foam, 0, 0))
	for p: Array in [[a0, 0.0, va], [b0, 0.0, vb], [a1, 1.0, va], [a1, 1.0, va], [b0, 0.0, vb], [b1, 1.0, vb]]:
		st.set_uv(Vector2(p[1], float(p[2]) / 8.0))
		st.add_vertex(p[0])


static func _water_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = WaterShader
		_material.set_shader_parameter("flow_speed", 0.25)
	return _material
