@tool
extends Path3D
## A road. Draw it as a path (click points along where it goes, in the 3D view
## with the path tool), choose its style (a RoadStyle file: paved, gravel,
## dirt track...), and press Apply in the Map Tools panel: the ground under it
## is levelled side to side, cut away above it on a hillside and built up below
## it, and painted (the road surface, the shoulders). Paved roads also get a
## surface with markings on top. Change the path and Apply again any time.
##
## Heights: the road follows the ground (its points' heights don't matter),
## with bumps smoothed out over the style's `smoothing` distance. A bridge is a
## RoadSpan child (world/map/road_span.gd): there the road is a flat deck at
## the span's height, and the ground under it is left alone.
##
## The road's surface, markings and bridge decks are made from the path when
## the map loads (nothing big is saved in the scene); the ground changes are
## saved with the terrain.

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const RoadSpan := preload("res://world/map/road_span.gd")

const STEP := 1.0 # meters between samples along the road
const RAMP := 12.0 # meters each side of a span over which the road climbs to its deck
const LIFT := 0.04 # a paved surface sits this far above the ground (no flicker)
const LINE_LIFT := 0.01 # markings above the surface
const LINE_WIDTH := 0.12
const DECK_THICKNESS := 0.6
const CUT_REACH := 25.0 # meters beyond the shoulders that cuts and fills can reach
const DASH := 3.0 # center line: 3 m dashes...
const DASH_CYCLE := 12.0 # ...every 12 m

@export var style: RoadStyle:
	set(value):
		style = value
		rebuild_later()

var _built: Node3D # the surface, markings and decks (made, not saved)
var _rebuild_queued := false
static var _materials := {} # Color -> StandardMaterial3D, shared by every road


func _ready() -> void:
	if curve == null:
		curve = Curve3D.new()
	if Engine.is_editor_hint():
		curve_changed.connect(rebuild_later)
		rebuild_later()
	else:
		_rebuild() # now: the bridge decks' collision has to be there for the navigation bake


func rebuild_later() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func spans() -> Array[RoadSpan]:
	var result: Array[RoadSpan] = []
	for child in get_children():
		if child is RoadSpan:
			result.append(child)
	return result


## Points along the road every STEP meters: {"pos": Vector3 (world, at the
## road's surface height), "offset": meters along, "dir": Vector3 (flat, unit),
## "span": true on a bridge deck}.
func samples(terrain: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if curve == null or curve.point_count < 2 or style == null:
		return result
	var length := curve.get_baked_length()
	var count := maxi(2, ceili(length / STEP) + 1)
	var ground := PackedFloat32Array()
	for i in count:
		var offset := length * i / (count - 1)
		var pos := global_transform * curve.sample_baked(offset, true)
		var ahead := global_transform * curve.sample_baked(minf(offset + 0.5, length), true)
		var behind := global_transform * curve.sample_baked(maxf(offset - 0.5, 0.0), true)
		var dir := Vector3(ahead.x - behind.x, 0.0, ahead.z - behind.z).normalized()
		if terrain:
			pos.y = TerrainEdit.height_at(terrain, pos)
		ground.append(pos.y)
		result.append({"pos": pos, "offset": offset, "dir": dir, "span": false})
	# Smooth the ground's bumps out.
	var window := maxi(1, int(style.smoothing / STEP / 2.0))
	for i in count:
		var total := 0.0
		var n := 0
		for k in range(maxi(0, i - window), mini(count, i + window + 1)):
			total += ground[k]
			n += 1
		result[i]["pos"].y = total / n
	# Bridge decks, and the ramps up to them.
	for span in spans():
		var at := curve.get_closest_offset(to_local(span.global_position))
		var half := span.length / 2.0
		for s: Dictionary in result:
			var away := absf(float(s["offset"]) - at) - half
			if away <= 0.0:
				s["span"] = true
				s["pos"].y = span.global_position.y
			elif away < RAMP:
				s["pos"].y = lerpf(span.global_position.y, s["pos"].y, away / RAMP)
	return result


## Shapes and paints the ground under the road (see the top). Returns the (x, z)
## area it changed. The Map Tools plugin wraps this in an undo step.
func apply(terrain: Node) -> Rect2:
	var list := samples(terrain)
	if list.is_empty():
		return Rect2()
	var half_road := style.width / 2.0
	var half := half_road + style.shoulder_width
	var reach := half + CUT_REACH
	TerrainEdit.along(terrain, list, reach, func(v: Vector3, s: Dictionary, d: float) -> void:
		if s["span"]:
			return # the ground under a bridge stays as it is
		var road_y: float = s["pos"].y
		var h := road_y
		if d > half:
			var out := d - half
			h = clampf(v.y, road_y - out * style.fill_slope, road_y + out * style.cut_slope)
		if not is_equal_approx(h, v.y):
			terrain.data.set_height(v, h)
		if d <= half_road:
			if style.surface == "Painted" and style.ruts:
				if absf(d - style.rut_spacing / 2.0) <= style.rut_width / 2.0:
					TerrainEdit.paint(terrain, v, style.surface_texture)
			else:
				TerrainEdit.paint(terrain, v, style.surface_texture)
		elif d <= half and style.shoulder_width > 0.0:
			TerrainEdit.paint(terrain, v, style.shoulder_texture))
	var rect := TerrainEdit.bounds(list, reach)
	TerrainEdit.finish(terrain, rect)
	rebuild_later()
	return rect


# --- What's drawn ------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_queued = false
	if _built:
		remove_child(_built) # out now, so the new one can have its name
		_built.queue_free()
		_built = null
	if style == null:
		return
	var list := samples(TerrainEdit.find_terrain(self))
	if list.size() < 2:
		return
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built) # not owned: made fresh each time, never saved
	_built.top_level = true # its meshes are in world space
	var paved := style.surface == "Paved"
	if paved:
		_ribbon(list, func(s: Dictionary) -> bool: return true, style.width, 0.0, LIFT, style.surface_color)
		_markings(list)
	else:
		_ribbon(list, func(s: Dictionary) -> bool: return s["span"], style.width, 0.0, LIFT, style.surface_color)
	_decks(list)


## A flat strip along the samples where keep(sample) is true, width wide,
## shifted sideways by side meters and lifted by lift.
func _ribbon(list: Array[Dictionary], keep: Callable, width: float, side: float, lift: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in list.size() - 1:
		var a: Dictionary = list[i]
		var b: Dictionary = list[i + 1]
		if not (keep.call(a) and keep.call(b)):
			continue
		_quad(st, a, b, side - width / 2.0, side + width / 2.0, lift)
		any = true
	if any:
		_add_mesh(st, color)


func _markings(list: Array[Dictionary]) -> void:
	var lift := LIFT + LINE_LIFT
	match style.center_line:
		"Dashed":
			_ribbon(list, func(s: Dictionary) -> bool: return fmod(float(s["offset"]), DASH_CYCLE) < DASH,
					LINE_WIDTH, 0.0, lift, style.center_line_color)
		"Solid":
			_ribbon(list, func(s: Dictionary) -> bool: return true, LINE_WIDTH, 0.0, lift, style.center_line_color)
		"Double":
			for side: float in [-0.12, 0.12]:
				_ribbon(list, func(s: Dictionary) -> bool: return true, LINE_WIDTH, side, lift, style.center_line_color)
	if style.edge_lines:
		for side: float in [-1.0, 1.0]:
			_ribbon(list, func(s: Dictionary) -> bool: return true, LINE_WIDTH,
					side * (style.width / 2.0 - 0.25), lift, style.edge_line_color)


## Bridge decks: the sides of the slab under the surface, and collision.
func _decks(list: Array[Dictionary]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var body: StaticBody3D = null
	var half := style.width / 2.0
	for i in list.size() - 1:
		var a: Dictionary = list[i]
		var b: Dictionary = list[i + 1]
		if not (a["span"] or b["span"]):
			continue
		any = true
		for side: float in [-half, half]: # the slab's two edges, hanging down
			_wall(st, a, b, side, LIFT, LIFT - DECK_THICKNESS)
		if body == null:
			body = StaticBody3D.new()
			_built.add_child(body)
		var pa: Vector3 = a["pos"]
		var pb: Vector3 = b["pos"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(style.width, DECK_THICKNESS, pa.distance_to(pb) + 0.05)
		var col := CollisionShape3D.new()
		col.shape = shape
		var mid := (pa + pb) / 2.0 + Vector3(0, LIFT - DECK_THICKNESS / 2.0, 0)
		col.transform = Transform3D(Basis.looking_at(pb - pa, Vector3.UP), mid)
		body.add_child(col)
	if any:
		_add_mesh(st, style.surface_color.darkened(0.25))


func _right(s: Dictionary) -> Vector3:
	var dir: Vector3 = s["dir"]
	return Vector3(-dir.z, 0.0, dir.x)


func _quad(st: SurfaceTool, a: Dictionary, b: Dictionary, left: float, right: float, lift: float) -> void:
	var up := Vector3(0, lift, 0)
	var a0: Vector3 = a["pos"] + _right(a) * left + up
	var a1: Vector3 = a["pos"] + _right(a) * right + up
	var b0: Vector3 = b["pos"] + _right(b) * left + up
	var b1: Vector3 = b["pos"] + _right(b) * right + up
	st.set_normal(Vector3.UP)
	for p: Vector3 in [a0, b0, a1, a1, b0, b1]:
		st.add_vertex(p)


func _wall(st: SurfaceTool, a: Dictionary, b: Dictionary, side: float, top: float, bottom: float) -> void:
	var at: Vector3 = a["pos"] + _right(a) * side
	var bt: Vector3 = b["pos"] + _right(b) * side
	var out := _right(a) * signf(side)
	st.set_normal(out)
	for p: Vector3 in [at + Vector3(0, top, 0), at + Vector3(0, bottom, 0), bt + Vector3(0, top, 0),
			bt + Vector3(0, top, 0), at + Vector3(0, bottom, 0), bt + Vector3(0, bottom, 0)]:
		st.add_vertex(p)


func _add_mesh(st: SurfaceTool, color: Color) -> void:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED # whichever way the path was drawn
		_materials[color] = mat
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _materials[color]
	_built.add_child(inst)
