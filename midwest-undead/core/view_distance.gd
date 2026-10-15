extends RefCounted
## Small things stop being drawn past a distance (the graphics card skips them):
## containers, items on the ground, windows, doors, boards. Each says how far
## it shows from (limit()); the View Distance setting scales them all
## (set_scale()). Never instanced.

const GROUP := &"view_limited"
## The View Distance setting: 1 is as tuned, less draws less.
static var scale := 1.0


## geom stops drawing past `meters` (times the View Distance setting). Not in the editor.
static func limit(geom: GeometryInstance3D, meters: float) -> void:
	if Engine.is_editor_hint():
		return
	geom.set_meta("view_meters", meters)
	geom.add_to_group(GROUP)
	_apply(geom)


## A box-shaped thing: the bigger it is, the further it shows (a dresser ~40 m, a car ~120 m).
static func limit_by_size(geom: GeometryInstance3D, size: Vector3) -> void:
	limit(geom, clampf(maxf(size.x, maxf(size.y, size.z)) * 30.0, 35.0, 150.0))


static func set_scale(tree: SceneTree, value: float) -> void:
	scale = value
	for node in tree.get_nodes_in_group(GROUP):
		_apply(node as GeometryInstance3D)


static func _apply(geom: GeometryInstance3D) -> void:
	geom.visibility_range_end = float(geom.get_meta("view_meters", 0.0)) * scale
	geom.visibility_range_end_margin = 3.0 # don't flicker right at the edge
