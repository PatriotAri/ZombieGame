@tool
extends RefCounted
## The pitched roofs a KitBuilding can have: gable, hip, shed and gambrel, over
## any outline whose walls meet at right angles. The outline is split into
## rectangles (the main block, then each wing: _split()); each gets a roof of
## the shape, its ridge along the main block's long side, and each wing's ridge
## running into the block it joins, where the two roofs meet in a valley.
## Never instanced: KitBuilding calls build().
##
## In a rectangle's own frame, u runs along its ridge and v across it.

const KitMesh := preload("res://world/kit/kit_mesh.gd")

const THICK := 0.15 # the roof's thickness
const GAMBREL_STEEP := 60.0 # degrees: a gambrel's lower slopes
const GAMBREL_KNEE := 0.35 # how far in (of the half-span) a gambrel's slopes change


## Whether an outline can have a pitched roof: every wall along x or z.
static func fits(outline: PackedVector2Array) -> bool:
	for i in outline.size():
		var d := outline[(i + 1) % outline.size()] - outline[i]
		if absf(d.x) > 0.01 and absf(d.y) > 0.01:
			return false
	return true


## The roof over outline, its eaves at height base: its slopes (top in
## roof_mat, underside in under_mat) and its gable ends (wall_mat outside,
## inside_mat in the attic). shape: "gable", "hip", "shed" or "gambrel".
## shed_low: the side a shed roof slopes down to ("front", "back", "left",
## "right"). Returns the rectangles ({"rect", "along_x", "ends"}) and the peak
## height, for dormers and chimneys: {"parts": [...], "top": y}.
static func build(km: KitMesh, outline: PackedVector2Array, base: float, shape: String, pitch_deg: float,
		overhang: float, shed_low: String, roof_mat: Material, under_mat: Material, wall_mat: Material,
		inside_mat: Material) -> Dictionary:
	var parts := _split(outline)
	var top := base
	var tan_p := tan(deg_to_rad(pitch_deg))
	for part: Dictionary in parts:
		var r: Rect2 = part["rect"]
		var f := {"km": km, "along_x": part["along_x"], "base": base, "tan": tan_p, "o": overhang,
				"roof": roof_mat, "under": under_mat, "wall": wall_mat, "inside": inside_mat}
		var u0 := r.position.x if part["along_x"] else r.position.y
		var u1 := r.end.x if part["along_x"] else r.end.y
		var v0 := r.position.y if part["along_x"] else r.position.x
		var v1 := r.end.y if part["along_x"] else r.end.x
		var ends: Array = part["ends"]
		match shape:
			"hip":
				top = maxf(top, _hip(f, u0, u1, v0, v1, ends))
			"shed":
				top = maxf(top, _shed(f, r, shed_low, ends))
			"gambrel":
				top = maxf(top, _gambrel(f, u0, u1, v0, v1, ends))
			_:
				top = maxf(top, _gable(f, u0, u1, v0, v1, ends))
	return {"parts": parts, "top": top}


# --- Splitting the outline -----------------------------------------------------------

## The outline as rectangles that don't overlap, biggest first (on the grid of
## its corners' x and z), each with which way its ridge runs and whether each
## end (along the ridge) joins another rectangle: {"rect": Rect2 (x, z),
## "along_x": bool, "ends": [joins at its low end, at its high end]}.
static func _split(outline: PackedVector2Array) -> Array[Dictionary]:
	var xs := _unique(outline, 0)
	var zs := _unique(outline, 1)
	var inside := {} # Vector2i cell -> true, not yet roofed
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var middle := Vector2((xs[i] + xs[i + 1]) / 2.0, (zs[j] + zs[j + 1]) / 2.0)
			if Geometry2D.is_point_in_polygon(middle, outline):
				inside[Vector2i(i, j)] = true
	var rects: Array[Rect2] = []
	while not inside.is_empty():
		var best := Rect2()
		var best_cells := Rect2i()
		for i0 in xs.size() - 1:
			for j0 in zs.size() - 1:
				if not inside.has(Vector2i(i0, j0)):
					continue
				for i1 in range(i0, xs.size() - 1):
					if not inside.has(Vector2i(i1, j0)):
						break
					for j1 in range(j0, zs.size() - 1):
						var all := true
						for i in range(i0, i1 + 1):
							if not inside.has(Vector2i(i, j1)):
								all = false
								break
						if not all:
							break
						var r := Rect2(xs[i0], zs[j0], xs[i1 + 1] - xs[i0], zs[j1 + 1] - zs[j0])
						if r.get_area() > best.get_area() + 0.0001:
							best = r
							best_cells = Rect2i(i0, j0, i1 - i0 + 1, j1 - j0 + 1)
		for i in range(best_cells.position.x, best_cells.end.x):
			for j in range(best_cells.position.y, best_cells.end.y):
				inside.erase(Vector2i(i, j))
		rects.append(best)
	var parts: Array[Dictionary] = []
	for k in rects.size():
		var r := rects[k]
		var along_x := r.size.x >= r.size.y
		if k > 0:
			# A wing: its ridge runs out from the biggest rectangle it joins.
			var longest := 0.0
			for other in rects.slice(0, k):
				for side in 4:
					var shared := _shared(r, side, other)
					if shared > longest + 0.01:
						longest = shared
						along_x = side >= 2 # joined on an x side (2, 3): its ends there, so its ridge runs along x
		var ends := [false, false]
		for other in rects:
			if other == r:
				continue
			ends[0] = ends[0] or _shared(r, 0 if not along_x else 2, other) > 0.01
			ends[1] = ends[1] or _shared(r, 1 if not along_x else 3, other) > 0.01
		parts.append({"rect": r, "along_x": along_x, "ends": ends})
	return parts


## How long a stretch of r's side meets other. Sides: 0 low z, 1 high z, 2 low
## x, 3 high x (a ridge along x has its ends on sides 2 and 3).
static func _shared(r: Rect2, side: int, other: Rect2) -> float:
	match side:
		0, 1:
			var z := r.position.y if side == 0 else r.end.y
			var oz := other.end.y if side == 0 else other.position.y
			if absf(z - oz) > 0.01:
				return 0.0
			return maxf(0.0, minf(r.end.x, other.end.x) - maxf(r.position.x, other.position.x))
		_:
			var x := r.position.x if side == 2 else r.end.x
			var ox := other.end.x if side == 2 else other.position.x
			if absf(x - ox) > 0.01:
				return 0.0
			return maxf(0.0, minf(r.end.y, other.end.y) - maxf(r.position.y, other.position.y))


static func _unique(outline: PackedVector2Array, axis: int) -> Array[float]:
	var values: Array[float] = []
	for p in outline:
		var v := p.x if axis == 0 else p.y
		if not values.any(func(w: float) -> bool: return absf(w - v) < 0.01):
			values.append(v)
	values.sort()
	return values


# --- The shapes ----------------------------------------------------------------------

## A point in the building's space from a rectangle's (u along the ridge, v across).
static func _p(f: Dictionary, u: float, v: float, y: float) -> Vector3:
	return Vector3(u, y, v) if f["along_x"] else Vector3(v, y, u)


## A slope (corners in u, v, y): faces up, whichever way round they're given.
static func _slope(f: Dictionary, corners: Array) -> void:
	var pts := PackedVector3Array()
	for c: Vector3 in corners:
		pts.append(_p(f, c.x, c.y, c.z))
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).y < 0.0:
		pts.reverse()
	(f["km"] as KitMesh).plate(pts, THICK, f["roof"], f["under"], f["wall"])


## An end wall (a gable) at u = at, facing out along u (out: -1 or +1).
static func _end_wall(f: Dictionary, at: float, out: float, corners: Array) -> void:
	var pts := PackedVector3Array()
	for c: Vector2 in corners: # (v, y)
		pts.append(_p(f, at, c.x, c.y))
	var facing := _p(f, out, 0.0, 0.0) - _p(f, 0.0, 0.0, 0.0)
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(facing) < 0.0:
		pts.reverse()
	(f["km"] as KitMesh).plate(pts, KitMesh.WALL, f["wall"], f["inside"], null)


## How far past u0 / u1 the roof reaches: into the rectangle it joins (as far
## as its own half-span, to meet that roof), or the overhang.
static func _reach(f: Dictionary, s: float, joins: bool) -> float:
	return s if joins else f["o"]


static func _gable(f: Dictionary, u0: float, u1: float, v0: float, v1: float, ends: Array) -> float:
	var s := (v1 - v0) / 2.0
	var vm := (v0 + v1) / 2.0
	var base: float = f["base"]
	var o: float = f["o"]
	var ridge: float = base + s * f["tan"]
	var eave: float = base - o * f["tan"]
	var a := u0 - _reach(f, s, ends[0])
	var b := u1 + _reach(f, s, ends[1])
	for side: float in [-1.0, 1.0]:
		var edge := vm + side * (s + o)
		_slope(f, [Vector3(a, edge, eave), Vector3(b, edge, eave), Vector3(b, vm, ridge), Vector3(a, vm, ridge)])
	for e in 2:
		if not ends[e]:
			_end_wall(f, u0 if e == 0 else u1, -1.0 if e == 0 else 1.0, [Vector2(v0, base), Vector2(v1, base), Vector2(vm, ridge)])
	return ridge


static func _hip(f: Dictionary, u0: float, u1: float, v0: float, v1: float, ends: Array) -> float:
	var s := (v1 - v0) / 2.0
	var vm := (v0 + v1) / 2.0
	var base: float = f["base"]
	var o: float = f["o"]
	var ridge: float = base + s * f["tan"]
	var eave: float = base - o * f["tan"]
	# The ridge stops a half-span short of each hipped end (they meet in a point
	# on a square); a joined end carries on into the other roof instead.
	var r0 := u0 + s if not ends[0] else u0 - s
	var r1 := u1 - s if not ends[1] else u1 + s
	if r0 > r1:
		r0 = (u0 + u1) / 2.0
		r1 = r0
	var e0 := u0 - o if not ends[0] else r0
	var e1 := u1 + o if not ends[1] else r1
	for side: float in [-1.0, 1.0]:
		var edge := vm + side * (s + o)
		_slope(f, [Vector3(e0, edge, eave), Vector3(e1, edge, eave), Vector3(r1, vm, ridge), Vector3(r0, vm, ridge)])
	if not ends[0]:
		_slope(f, [Vector3(e0, vm - s - o, eave), Vector3(e0, vm + s + o, eave), Vector3(r0, vm, ridge)])
	if not ends[1]:
		_slope(f, [Vector3(e1, vm - s - o, eave), Vector3(e1, vm + s + o, eave), Vector3(r1, vm, ridge)])
	return ridge


static func _gambrel(f: Dictionary, u0: float, u1: float, v0: float, v1: float, ends: Array) -> float:
	var s := (v1 - v0) / 2.0
	var vm := (v0 + v1) / 2.0
	var base: float = f["base"]
	var o: float = f["o"]
	var knee_run := s * GAMBREL_KNEE
	var steep := tan(deg_to_rad(GAMBREL_STEEP))
	var knee: float = base + knee_run * steep
	var ridge: float = knee + (s - knee_run) * f["tan"] * 0.6
	var eave: float = base - o * steep * 0.5
	var a := u0 - _reach(f, s, ends[0])
	var b := u1 + _reach(f, s, ends[1])
	for side: float in [-1.0, 1.0]:
		var edge := vm + side * (s + o)
		var bend := vm + side * (s - knee_run)
		_slope(f, [Vector3(a, edge, eave), Vector3(b, edge, eave), Vector3(b, bend, knee), Vector3(a, bend, knee)])
		_slope(f, [Vector3(a, bend, knee), Vector3(b, bend, knee), Vector3(b, vm, ridge), Vector3(a, vm, ridge)])
	for e in 2:
		if not ends[e]:
			_end_wall(f, u0 if e == 0 else u1, -1.0 if e == 0 else 1.0, [Vector2(v0, base), Vector2(v1, base),
					Vector2(v1 - knee_run, knee), Vector2(vm, ridge), Vector2(v0 + knee_run, knee)])
	return ridge


## One slope across the whole rectangle, down to shed_low; walls fill in under
## its high side and its two ends.
static func _shed(f: Dictionary, r: Rect2, shed_low: String, _ends: Array) -> float:
	# Shed roofs slope across the axis shed_low names, whatever the ridge rule said.
	var g := f.duplicate()
	g["along_x"] = shed_low in ["left", "right"] # sloping across z: its "ridge" (top edge) runs along x
	var u0 := r.position.x if g["along_x"] else r.position.y
	var u1 := r.end.x if g["along_x"] else r.end.y
	var v0 := r.position.y if g["along_x"] else r.position.x
	var v1 := r.end.y if g["along_x"] else r.end.x
	var low_at_v0 := shed_low in ["left", "front"]
	var base: float = g["base"]
	var o: float = g["o"]
	var rise: float = (v1 - v0) * g["tan"]
	var low := v0 if low_at_v0 else v1
	var high := v1 if low_at_v0 else v0
	var out := -1.0 if low_at_v0 else 1.0 # toward the low side, along v
	_slope(g, [Vector3(u0 - o, low + out * o, base - o * g["tan"]), Vector3(u1 + o, low + out * o, base - o * g["tan"]),
			Vector3(u1 + o, high - out * o, base + rise + o * g["tan"]), Vector3(u0 - o, high - out * o, base + rise + o * g["tan"])])
	for e in 2:
		_end_wall(g, u0 if e == 0 else u1, -1.0 if e == 0 else 1.0, [Vector2(low, base), Vector2(high, base), Vector2(high, base + rise)])
	# The wall under the high side: a rectangle facing out (away from the low side).
	var pts := PackedVector3Array([_p(g, u0, high, base), _p(g, u1, high, base), _p(g, u1, high, base + rise), _p(g, u0, high, base + rise)])
	var facing := _p(g, 0.0, -out, 0.0) - _p(g, 0.0, 0.0, 0.0)
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(facing) < 0.0:
		pts.reverse()
	(g["km"] as KitMesh).plate(pts, KitMesh.WALL, g["wall"], g["inside"], null)
	return base + rise


# --- Dormers -------------------------------------------------------------------------

const DORMER_IN := 0.5 # its front wall, this far in from the wall below
const DORMER_WALL := 1.4 # its front wall's height above the eaves
const DORMER_PEAK := 0.45 # its little gable over that


## A dormer on the sloped side (of parts, from build()) nearest point, width
## wide. Returns where its window goes (facing out: the window prop's -X), or
## an empty Dictionary if there's no slope there: {"xform": Transform3D}.
static func dormer(km: KitMesh, parts: Array, point: Vector2, width: float, base: float, pitch_deg: float,
		roof_mat: Material, wall_mat: Material, inside_mat: Material) -> Dictionary:
	var tan_p := tan(deg_to_rad(pitch_deg))
	var hw := width / 2.0
	var best := {}
	var best_dist := 2.5
	for part: Dictionary in parts:
		var r: Rect2 = part["rect"]
		var along_x: bool = part["along_x"]
		var u := point.x if along_x else point.y
		var v := point.y if along_x else point.x
		var u0 := r.position.x if along_x else r.position.y
		var u1 := r.end.x if along_x else r.end.y
		var v0 := r.position.y if along_x else r.position.x
		var v1 := r.end.y if along_x else r.end.x
		if u - hw < u0 + 0.2 or u + hw > u1 - 0.2:
			continue
		for side: float in [-1.0, 1.0]:
			var eave: float = v0 if side < 0.0 else v1
			if absf(v - eave) < best_dist and (v1 - v0) / 2.0 * tan_p > DORMER_WALL + DORMER_PEAK:
				best_dist = absf(v - eave)
				best = {"along_x": along_x, "u": u, "eave": eave, "side": side}
	if best.is_empty():
		return {}
	var f := {"km": km, "along_x": best["along_x"], "roof": roof_mat, "under": inside_mat, "wall": wall_mat, "inside": inside_mat}
	var pu: float = best["u"]
	var side: float = best["side"] # out of the building, along v
	var vf: float = best["eave"] - side * DORMER_IN # its front wall
	var top := base + DORMER_WALL
	var peak := top + DORMER_PEAK
	var back_of := func(height: float) -> float: return best["eave"] - side * (height - base) / tan_p
	# The front: a wall with a little gable on top, facing out.
	var front := PackedVector3Array([_p(f, pu - hw, vf, base), _p(f, pu + hw, vf, base), _p(f, pu + hw, vf, top),
			_p(f, pu, vf, peak), _p(f, pu - hw, vf, top)])
	var out_dir := _p(f, 0.0, side, 0.0) - _p(f, 0.0, 0.0, 0.0)
	if (front[1] - front[0]).cross(front[2] - front[0]).dot(out_dir) < 0.0:
		front.reverse()
	km.plate(front, 0.12, wall_mat, inside_mat, null)
	# The cheeks: from the front wall back to where the main roof is as high as its top.
	for s: float in [-1.0, 1.0]:
		var cheek := PackedVector3Array([_p(f, pu + s * hw, vf, base + DORMER_IN * tan_p), _p(f, pu + s * hw, vf, top),
				_p(f, pu + s * hw, back_of.call(top), top)])
		var away := _p(f, s, 0.0, 0.0) - _p(f, 0.0, 0.0, 0.0)
		if (cheek[1] - cheek[0]).cross(cheek[2] - cheek[0]).dot(away) < 0.0:
			cheek.reverse()
		km.plate(cheek, 0.1, wall_mat, inside_mat, null)
	# Its roof: two little slopes from just past the front back into the main roof.
	var vo := vf + side * 0.15
	var vb: float = back_of.call(peak)
	for s: float in [-1.0, 1.0]:
		_slope(f, [Vector3(pu + s * (hw + 0.12), vo, top - 0.06), Vector3(pu, vo, peak), Vector3(pu, vb, peak), Vector3(pu + s * (hw + 0.12), vb, top - 0.06)])
	var inward := -out_dir.normalized()
	var at := _p(f, pu, vf + side * 0.07, base + DORMER_WALL * 0.55)
	return {"xform": Transform3D(Basis(inward, Vector3.UP, inward.cross(Vector3.UP)), at)}
