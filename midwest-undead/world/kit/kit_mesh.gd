@tool
extends RefCounted
## Builds the kit's geometry (world/kit/): boxes whose six faces each get a
## material, collected into one mesh (a surface per material) plus the boxes'
## collision shapes. Also builds walls with doorways and windows cut into them.
## Never instanced by hand: building.gd and the kit pieces use it.
##
## A wall here is described in its own frame: X across the wall (its outside is
## -X), Y up from the wall's foot, Z along it, centered on the frame's origin.

const WindowPane := preload("res://world/window_pane.gd")
const Door := preload("res://world/door.gd")

const GLASS := Color(0.55, 0.65, 0.7, 0.22)
const WALL := 0.2 # thickness of every wall the kit makes
const BOARDS := preload("res://world/kit/materials/wood_planks.tres")

## Face order for box(): -X, +X, -Y, +Y, -Z, +Z.
enum { NX, PX, NY, PY, NZ, PZ }

var shapes: Array = [] # [Transform3D, size] for each collision box
var _faces := PackedVector3Array() # triangles for one trimesh collision shape (slabs)
var _tools := {} # Material -> SurfaceTool
var _order: Array[Material] = []


## faces: six materials, in the order above (null = that face isn't drawn).
func box(size: Vector3, xform: Transform3D, faces: Array, collide := true) -> void:
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001:
		return
	var h := size / 2.0
	for i in 6:
		var mat: Material = faces[i]
		if mat == null:
			continue
		var axis := i / 2
		var sgn := 1.0 if i % 2 == 1 else -1.0
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var corners: Array[Vector3] = []
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := Vector3.ZERO
			p[axis] = sgn * h[axis]
			p[u_axis] = c.x * h[u_axis]
			p[v_axis] = c.y * h[v_axis]
			corners.append(xform * p)
		var n := Vector3.ZERO
		n[axis] = sgn
		_quad(mat, corners, (xform.basis * n).normalized())
	if collide:
		shapes.append([xform, size])


## The same material on all six faces.
static func all(mat: Material) -> Array:
	return [mat, mat, mat, mat, mat, mat]


## A wall (see the frame at the top) from y0 to y1, `length` long, with openings
## cut into it. Each opening is {"kind": "door"/"doorway"/"window", "along": its middle
## along the wall, "width", "bottom", "top" (heights in the wall's frame),
## "boarded_up"} and comes back with "frame": where its middle is, in the wall's
## frame. floor_y: the floor's height (no sill piece is made under an opening
## that starts at the floor). outside / inside: the two faces' materials; the
## edges and reveals use outside. capped: also draw its top and bottom (a
## freestanding wall; a building's slabs cover them).
func wall(frame: Transform3D, length: float, y0: float, y1: float, floor_y: float, openings: Array,
		outside: Material, inside: Material, capped := false) -> void:
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["along"] < b["along"])
	var cursor := -length / 2.0
	for op: Dictionary in openings:
		var start: float = op["along"] - op["width"] / 2.0
		var end: float = op["along"] + op["width"] / 2.0
		var bottom: float = op["bottom"]
		var top: float = op["top"]
		var mid: float = op["along"]
		if start > cursor:
			_wall_box(frame, Vector3(WALL, y1 - y0, start - cursor), Vector3(0, (y0 + y1) / 2.0, (cursor + start) / 2.0),
					y0, y1, outside, inside, capped)
		if bottom > floor_y + 0.01:
			_wall_box(frame, Vector3(WALL, bottom - y0, end - start), Vector3(0, (y0 + bottom) / 2.0, mid),
					y0, y1, outside, inside, capped)
		_wall_box(frame, Vector3(WALL, y1 - top, end - start), Vector3(0, (top + y1) / 2.0, mid),
				y0, y1, outside, inside, capped)
		op["frame"] = frame * Transform3D(Basis.IDENTITY, Vector3(0, (bottom + top) / 2.0, mid))
		if op["kind"] == "window" and op.get("boarded_up", false):
			box(Vector3(0.1, top - bottom, end - start), op["frame"], all(BOARDS))
		cursor = maxf(cursor, end)
	if cursor < length / 2.0:
		_wall_box(frame, Vector3(WALL, y1 - y0, length / 2.0 - cursor), Vector3(0, (y0 + y1) / 2.0, (cursor + length / 2.0) / 2.0),
				y0, y1, outside, inside, capped)


## Top and bottom faces only where they show (a sill, a lintel), not where the
## piece meets the wall above or below.
func _wall_box(frame: Transform3D, size: Vector3, center: Vector3, y0: float, y1: float,
		outside: Material, inside: Material, capped: bool) -> void:
	var top_shows := capped or center.y + size.y / 2.0 < y1 - 0.001
	var bottom_shows := capped or center.y - size.y / 2.0 > y0 + 0.001
	box(size, frame * Transform3D(Basis.IDENTITY, center),
			[outside, inside, outside if bottom_shows else null, outside if top_shows else null, outside, outside])


## The glass for a window made by wall(): add it to the tree yourself.
## floor_drop: how far the floor is below the pane's middle (fortifications.gd).
## models: the building's Window Models (empty: world/props/window.tscn's).
static func make_window(op: Dictionary, boardable: bool, boarded_at_start: bool, floor_drop: float,
		models: Array = []) -> WindowPane:
	var pane := WindowPane.new()
	pane.transform = op["frame"]
	pane.setup(Vector3(0.06, op["top"] - op["bottom"], op["width"]), models)
	pane.boardable = boardable
	pane.boarded_at_start = boarded_at_start
	pane.set_meta("floor_drop", floor_drop)
	return pane


## The door for a doorway made by wall(), hinged on its start edge and swinging
## in (+X). Add it to the tree yourself. models: the building's Door Models
## (empty: world/props/door.tscn's).
static func make_door(op: Dictionary, color: Color, models: Array = []) -> Door:
	var height: float = op["top"] - op["bottom"] - 0.02
	var width: float = op["width"]
	var leaf := Vector3(0.08, height, width - 0.1)
	var frame: Transform3D = op["frame"]
	var hinge := frame * Transform3D(Basis.IDENTITY, Vector3(0, -(op["top"] - op["bottom"]) / 2.0, -width / 2.0))
	var door := Door.new()
	door.setup(leaf, Vector3(0.0, height / 2.0, width / 2.0), color, hinge, PI / 2.0, Vector3.ZERO, models)
	return door


## The mesh, a surface per material. Null if nothing was drawn.
func mesh() -> ArrayMesh:
	if _order.is_empty():
		return null
	var result := ArrayMesh.new()
	for mat in _order:
		var st: SurfaceTool = _tools[mat]
		st.generate_tangents() # for normal maps in your own materials
		st.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, mat)
	return result


## A MeshInstance3D with the mesh and the collision shapes, under `body`
## (internal children: never saved in a scene). Returns what it added.
func add_to(body: Node3D, mesh_name := "Mesh") -> Array[Node]:
	var added: Array[Node] = []
	var m := mesh()
	if m:
		var inst := MeshInstance3D.new()
		inst.name = mesh_name
		inst.mesh = m
		body.add_child(inst, false, Node.INTERNAL_MODE_BACK)
		added.append(inst)
	for i in shapes.size():
		var shape := BoxShape3D.new()
		shape.size = shapes[i][1]
		var col := CollisionShape3D.new()
		col.name = "Box%d" % i
		col.shape = shape
		col.transform = shapes[i][0]
		body.add_child(col, false, Node.INTERNAL_MODE_BACK)
		added.append(col)
	if not _faces.is_empty():
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(_faces)
		var col := CollisionShape3D.new()
		col.name = "Slabs"
		col.shape = trimesh
		body.add_child(col, false, Node.INTERNAL_MODE_BACK)
		added.append(col)
	return added


# --- Slabs of any outline ----------------------------------------------------------
# An outline is a PackedVector2Array of (x, z) corners. A hole is a rectangle
# that can be turned: {"xform": Transform2D (its middle; x along it), "size": Vector2}.

## A flat slab over outline, its top at `top`, `thick` deep, with holes cut out
## (staircases). Its top, bottom, the outline's edges and the holes' edges each
## get a material (null: not drawn). collide: also solid (one trimesh shape).
## slits: more holes, but only to split the top into pieces (thin ones under
## inner walls), so top_pick (piece -> Material, or null for top_mat) can give
## each room's floor its own material.
func slab(outline: PackedVector2Array, holes: Array, top: float, thick: float, top_mat: Material,
		bottom_mat: Material, side_mat: Material, hole_mat: Material, collide := true,
		slits: Array = [], top_pick := Callable()) -> void:
	var bottom := top - thick
	for piece in cut(outline, holes + slits):
		var tris := Geometry2D.triangulate_polygon(piece)
		var piece_top := top_mat
		if top_pick.is_valid():
			var picked: Variant = top_pick.call(piece)
			if picked != null:
				piece_top = picked
		for i in range(0, tris.size(), 3):
			for face: Array in [[top, Vector3.UP, piece_top], [bottom, Vector3.DOWN, bottom_mat]]:
				var corners := PackedVector3Array()
				for k in 3:
					var p := piece[tris[i + k]]
					corners.append(Vector3(p.x, face[0], p.y))
				if face[2]:
					_tri(face[2], corners, face[1])
				if collide:
					_faces.append_array(corners)
	var count := outline.size()
	for i in count:
		_side(outline[i], outline[(i + 1) % count], top, bottom, side_mat, collide)
	for hole: Dictionary in holes:
		var corners := hole_corners(hole) # (going the other way round: they face into the hole)
		for i in 4:
			_side(corners[i], corners[(i + 1) % 4], top, bottom, hole_mat, collide)


## Whether slab() made anything solid (its collision is one trimesh, not boxes).
func has_slabs() -> bool:
	return not _faces.is_empty()


## A hole's four corners (x, z), going round the opposite way to an outline.
static func hole_corners(hole: Dictionary) -> PackedVector2Array:
	var xf: Transform2D = hole["xform"]
	var h: Vector2 = hole["size"] / 2.0
	return PackedVector2Array([xf * Vector2(-h.x, -h.y), xf * Vector2(h.x, -h.y), xf * Vector2(h.x, h.y), xf * Vector2(-h.x, h.y)])


## outline minus the holes, as pieces (each a plain polygon, no holes in it).
static func cut(outline: PackedVector2Array, holes: Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [outline]
	const FAR := 10000.0
	for hole: Dictionary in holes:
		var xf: Transform2D = hole["xform"]
		var h: Vector2 = hole["size"] / 2.0
		# Round the hole in its own frame: the strips either side of it, and in front of and behind it.
		var regions := [Rect2(-FAR, -FAR, FAR - h.x, 2.0 * FAR), Rect2(h.x, -FAR, FAR, 2.0 * FAR),
				Rect2(-h.x, -FAR, 2.0 * h.x, FAR - h.y), Rect2(-h.x, h.y, 2.0 * h.x, FAR)]
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			var local := xf.affine_inverse() * piece
			for r: Rect2 in regions:
				var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
				for part in Geometry2D.intersect_polygons(local, box):
					if absf(_area(part)) > 0.0001:
						next.append(xf * part)
		pieces = next
	return pieces


## Signed area (x, z): negative for the corner order buildings use (KitBuilding).
static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum / 2.0


## An upright face along a to b, between top and bottom, facing out of the
## outline (corners going the way KitBuilding's do).
func _side(a: Vector2, b: Vector2, top: float, bottom: float, mat: Material, collide: bool) -> void:
	var along := (b - a).normalized()
	var n := Vector3(-along.y, 0, along.x)
	var corners := PackedVector3Array([Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, bottom, b.y),
			Vector3(a.x, top, a.y), Vector3(b.x, bottom, b.y), Vector3(a.x, bottom, a.y)])
	if mat:
		_tri(mat, corners.slice(0, 3), n)
		_tri(mat, corners.slice(3, 6), n)
	if collide:
		_faces.append_array(corners)


## Triangles (corners in threes) in mat, facing n.
func _tri(mat: Material, corners: PackedVector3Array, n: Vector3) -> void:
	var st := _tool(mat)
	for i in range(0, corners.size(), 3):
		var a := corners[i]
		var b := corners[i + 1]
		var d := corners[i + 2]
		# Godot draws a triangle's front where its corners run clockwise.
		var tri := [a, d, b] if (b - a).cross(d - a).dot(n) > 0.0 else [a, b, d]
		for p: Vector3 in tri:
			st.set_normal(n)
			st.set_uv(_uv(p, n))
			st.add_vertex(p)


func _tool(mat: Material) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
		_order.append(mat)
	return _tools[mat]


func _quad(mat: Material, c: Array[Vector3], n: Vector3) -> void:
	var st := _tool(mat)
	for t: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = c[t[0]]
		var b: Vector3 = c[t[1]]
		var d: Vector3 = c[t[2]]
		# Godot draws a triangle's front where its corners run clockwise.
		var tri := [a, d, b] if (b - a).cross(d - a).dot(n) > 0.0 else [a, b, d]
		for p: Vector3 in tri:
			st.set_normal(n)
			st.set_uv(_uv(p, n))
			st.add_vertex(p)


## Flat UVs in meters (for materials that don't use triplanar mapping).
static func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z)
	if a.x >= a.z:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)


## Gives a mesh its own darker copies of its materials (a searched container, a
## stripped bed). Kit materials darken through their tint; plain ones through
## their color.
static func darken(inst: MeshInstance3D, amount: float) -> void:
	if inst.mesh == null:
		return
	for i in inst.mesh.get_surface_count():
		var mat := inst.get_active_material(i)
		if mat == null:
			continue
		var copy := mat.duplicate() as Material
		if copy is ShaderMaterial:
			var tint: Variant = (copy as ShaderMaterial).get_shader_parameter("tint")
			var t: Color = tint if tint is Color else Color.WHITE
			(copy as ShaderMaterial).set_shader_parameter("tint", t.darkened(amount))
		elif copy is BaseMaterial3D:
			(copy as BaseMaterial3D).albedo_color = (copy as BaseMaterial3D).albedo_color.darkened(amount)
		inst.set_surface_override_material(i, copy)
