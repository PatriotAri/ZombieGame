@tool
extends RefCounted
## A building's porches (world/kit/kit_porch.gd), for KitBuilding to build:
## a deck at the ground floor's height along each of a porch's walls, steps
## down, a railing or screens round the edge, a roof on posts, and posts
## under the deck down to the ground. Never instanced.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const KitRoof := preload("res://world/kit/kit_roof.gd")
const TerrainEdit := preload("res://world/map/terrain_edit.gd")


## One porch: a deck at the ground floor's height along each of its walls
## (meeting the next one's on the diagonal at a corner), steps down, a railing
## or screens round the edge, and a roof on posts.
static func build(building: KitBuilding, km: KitMesh, porch: KitPorch, roof_mat: Material, made: Array[Node]) -> void:
	var deck := building.floor_top(0)
	var sides := _sides(building, porch, porch.depth)
	var eaves := _sides(building, porch, porch.depth + KitBuilding.PORCH_EAVE)
	var roofed := porch.kind != "Open"
	var wall_y := roof_y(building)
	var slope := tan(deg_to_rad(KitBuilding.PORCH_PITCH))
	for i in sides.size():
		var side: Dictionary = sides[i]
		var a: Vector2 = side["a"]
		var b: Vector2 = side["b"]
		var a_out: Vector2 = side["a_out"]
		var b_out: Vector2 = side["b_out"]
		# The deck, down into the ground (posts under it on a slope: _foundation).
		km.slab(PackedVector2Array([a_out, b_out, b, a]), [], deck, deck + 0.3, KitBuilding.DECK, null, KitBuilding.TIMBER, null)
		if roofed:
			var e: Dictionary = eaves[i]
			var corners := PackedVector3Array([Vector3(a.x, wall_y, a.y), Vector3(b.x, wall_y, b.y),
					_point(e["b_out"], side, wall_y, slope), _point(e["a_out"], side, wall_y, slope)])
			if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y < 0.0:
				corners.reverse()
			km.plate(corners, KitBuilding.PORCH_ROOF, roof_mat, KitBuilding.DECK, KitBuilding.TIMBER)
		# Round its edge: the outer side, and an end that doesn't meet another side.
		var gap := _steps_gap(building, porch, side)
		var runs := [[a_out, b_out, gap]]
		if not side["joined_a"]:
			runs.append([a, a_out, Vector2.INF])
		if not side["joined_b"]:
			runs.append([b_out, b, Vector2.INF])
		for run: Array in runs:
			_edge(building, km, porch, run[0], run[1], run[2], side, wall_y, slope, made)
		if gap != Vector2.INF:
			_steps(building, km, side, gap, deck)


## A porch's sides, one per wall: {"n", "a", "b" (along the outline),
## "a_out", "b_out" (`out` meters out, meeting the next side's on the
## diagonal), "out" (the way out from the wall), "joined_a", "joined_b"}.
static func _sides(building: KitBuilding, porch: KitPorch, out_by: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := building.edge_count()
	var walls := Array(porch.walls).filter(func(n: int) -> bool: return n >= 0 and n < count)
	for i in walls.size():
		var n: int = walls[i]
		var ends := building.edge_ends(n)
		var along := (ends[1] - ends[0]).normalized()
		var out := Vector2(-along.y, along.x)
		var a := ends[0]
		var b := ends[1]
		if walls.size() == 1 and porch.length > 0.0:
			var middle := (ends[0] + ends[1]) / 2.0 + along * porch.offset
			a = middle - along * porch.length / 2.0
			b = middle + along * porch.length / 2.0
		var joined_a: bool = i > 0 and walls[i - 1] == posmod(n - 1, count)
		var joined_b: bool = i < walls.size() - 1 and walls[i + 1] == (n + 1) % count
		var a_out := a + out * out_by
		var b_out := b + out * out_by
		if joined_a:
			a_out = _meet(building, a_out, along, n - 1, out_by)
		if joined_b:
			b_out = _meet(building, b_out, along, n + 1, out_by)
		result.append({"n": n, "a": a, "b": b, "a_out": a_out, "b_out": b_out, "out": out, "along": along,
				"joined_a": joined_a, "joined_b": joined_b})
	return result


## Where a line (through p, along `along`) meets wall n's line moved `by` out.
static func _meet(building: KitBuilding, p: Vector2, along: Vector2, n: int, by: float) -> Vector2:
	var ends := building.edge_ends(posmod(n, building.edge_count()))
	var other := (ends[1] - ends[0]).normalized()
	var hit: Variant = Geometry2D.line_intersects_line(p, along, ends[0] + Vector2(-other.y, other.x) * by, other)
	return hit if hit is Vector2 else p


## A point of a porch's roof: wall_y at the wall, lower going out.
static func _point(p: Vector2, side: Dictionary, wall_y: float, slope: float) -> Vector3:
	var away: float = (p - (side["a"] as Vector2)).dot(side["out"])
	return Vector3(p.x, wall_y - away * slope, p.y)


## Whether a porch runs along wall n.
static func on_wall(building: KitBuilding, n: int) -> bool:
	return building.porches.any(func(p: KitPorch) -> bool: return p != null and p.kind != "Open" and n in p.walls)


## The porch roof's height against the wall: under the main roof's eaves.
static func roof_y(building: KitBuilding) -> float:
	var y := KitBuilding.STOREY - 0.3
	if building.floors == 1 and building.upper_height <= 0.0 and building._pitched():
		var tan_p := tan(deg_to_rad(building.roof_pitch))
		var eave := KitBuilding.STOREY - building.roof_overhang * tan_p - KitRoof.THICK / cos(deg_to_rad(building.roof_pitch))
		y = minf(y, eave - 0.05 + building.roof_overhang * tan(deg_to_rad(KitBuilding.PORCH_PITCH)))
	return y


## Where the steps leave a side's outer edge: the gap's two ends (Vector2.INF: not this side).
static func _steps_gap(building: KitBuilding, porch: KitPorch, side: Dictionary) -> Vector2:
	if porch.steps_wall != side["n"]:
		return Vector2.INF
	var ends := building.edge_ends(side["n"])
	var along: Vector2 = side["along"]
	var middle := ((ends[0] + ends[1]) / 2.0).dot(along) + porch.steps_offset
	var lo: float = (side["a_out"] as Vector2).dot(along) + KitBuilding.POST
	var hi: float = (side["b_out"] as Vector2).dot(along) - KitBuilding.POST
	var half := (KitBuilding.SCREEN_DOOR_WIDTH if porch.kind == "Screened" else KitBuilding.STAIR_WIDTH) / 2.0 + 0.05
	middle = clampf(middle, lo + half, hi - half)
	return Vector2(middle - half, middle + half)


## One edge of a porch, from p to q (a gap along it, in the side's along
## distances, left open: the steps): posts, a railing, screens, a screen door.
static func _edge(building: KitBuilding, km: KitMesh, porch: KitPorch, p: Vector2, q: Vector2, gap: Vector2, side: Dictionary,
		wall_y: float, slope: float, made: Array[Node]) -> void:
	var deck := building.floor_top(0)
	var length := p.distance_to(q)
	if length < 0.05:
		return
	var dir := (q - p) / length
	var along: Vector2 = side["along"]
	var pieces: Array[Vector2] = [] # [from, to] distances from p
	if gap != Vector2.INF and absf(dir.dot(along)) > 0.99:
		var g0 := (gap.x - p.dot(along)) * signf(dir.dot(along))
		var g1 := (gap.y - p.dot(along)) * signf(dir.dot(along))
		pieces.append(Vector2(0.0, minf(g0, g1)))
		pieces.append(Vector2(maxf(g0, g1), length))
	else:
		pieces.append(Vector2(0.0, length))
	var roofed := porch.kind != "Open"
	var screened := porch.kind == "Screened"
	var frame_basis := Basis(Vector3(-dir.y, 0, dir.x), Vector3.UP, Vector3(dir.x, 0, dir.y))
	var under := func(at: Vector2) -> float: return _point(at, side, wall_y, slope).y - KitBuilding.PORCH_ROOF / cos(deg_to_rad(KitBuilding.PORCH_PITCH))
	for piece in pieces:
		if piece.y - piece.x < 0.05:
			continue
		var from := p + dir * piece.x
		var to := p + dir * piece.y
		var mid := (from + to) / 2.0
		var span := piece.y - piece.x
		if roofed: # posts at its ends and every POST_SPACING or so between
			var count := maxi(1, ceili(span / KitBuilding.POST_SPACING))
			for k in count + 1:
				var at := from.lerp(to, float(k) / count)
				var top: float = under.call(at)
				km.box(Vector3(KitBuilding.POST, top - deck, KitBuilding.POST), KitBuilding._at(Vector3(at.x, (deck + top) / 2.0, at.y)), KitMesh.all(KitBuilding.TIMBER))
		if screened:
			# Screen from a low rail to the roof (solid: zombies can't get through).
			var lo := deck + 0.25
			var corners := PackedVector3Array([Vector3(from.x, lo, from.y), Vector3(to.x, lo, to.y),
					Vector3(to.x, under.call(to), to.y), Vector3(from.x, under.call(from), from.y)])
			km.plate(corners, 0.02, KitBuilding.SCREEN, KitBuilding.SCREEN, null)
			km.box(Vector3(0.06, 0.25, span), Transform3D(frame_basis, Vector3(mid.x, deck + 0.125, mid.y)), KitMesh.all(KitBuilding.TIMBER))
			km.box(Vector3(0.05, 0.06, span), Transform3D(frame_basis, Vector3(mid.x, deck + KitBuilding.RAIL_HEIGHT, mid.y)), KitMesh.all(KitBuilding.TIMBER), false)
		elif porch.railing:
			km.box(Vector3(0.07, 0.06, span), Transform3D(frame_basis, Vector3(mid.x, deck + KitBuilding.RAIL_HEIGHT, mid.y)), KitMesh.all(KitBuilding.TIMBER), false)
			km.box(Vector3(0.05, 0.05, span), Transform3D(frame_basis, Vector3(mid.x, deck + 0.12, mid.y)), KitMesh.all(KitBuilding.TIMBER), false)
			var balusters := floori(span / 0.3)
			for k in range(1, balusters):
				var at := from + dir * (span * k / balusters)
				km.box(Vector3(0.04, KitBuilding.RAIL_HEIGHT - 0.12, 0.04), KitBuilding._at(Vector3(at.x, deck + 0.06 + KitBuilding.RAIL_HEIGHT / 2.0, at.y)), KitMesh.all(KitBuilding.TIMBER), false)
			# Solid all the way up, unseen: nobody steps over it.
			km.box(Vector3(0.07, KitBuilding.RAIL_HEIGHT + 0.1, span), Transform3D(frame_basis, Vector3(mid.x, deck + (KitBuilding.RAIL_HEIGHT + 0.1) / 2.0, mid.y)),
					[null, null, null, null, null, null])
	if screened and gap != Vector2.INF and pieces.size() == 2:
		# The screen door in the gap, and screen over it.
		var g0 := p + dir * pieces[0].y
		var g1 := p + dir * pieces[1].x
		var top := minf(deck + KitBuilding.SCREEN_DOOR_HEIGHT, minf(under.call(g0), under.call(g1)) - 0.05)
		km.plate(PackedVector3Array([Vector3(g0.x, top, g0.y), Vector3(g1.x, top, g1.y),
				Vector3(g1.x, under.call(g1), g1.y), Vector3(g0.x, under.call(g0), g0.y)]), 0.02, KitBuilding.SCREEN, KitBuilding.SCREEN, null)
		var mid := (g0 + g1) / 2.0
		# Its frame: X in toward the wall (it swings in, onto the porch).
		var into := -(side["out"] as Vector2)
		var basis := Basis(Vector3(into.x, 0, into.y), Vector3.UP, Vector3(into.x, 0, into.y).cross(Vector3.UP))
		var width := g0.distance_to(g1)
		var entry := {"top": top, "bottom": deck, "width": width, "frame": Transform3D(basis, Vector3(mid.x, (deck + top) / 2.0, mid.y))}
		var door := KitMesh.make_door(entry, Color(0.55, 0.42, 0.28))
		door.look_scene = KitBuilding.ScreenDoorLook
		door.label = "screen door"
		door.name = "Porch%dScreenDoor" % (building.porches.find(porch) + 1)
		made.append(door)


## Steps from a side's outer edge (across gap) down to the ground.
static func _steps(building: KitBuilding, km: KitMesh, side: Dictionary, gap: Vector2, deck: float) -> void:
	if deck < 0.12:
		return # a step up is nothing
	var along: Vector2 = side["along"]
	var out: Vector2 = side["out"]
	var edge: Vector2 = side["a_out"]
	var start := edge + along * ((gap.x + gap.y) / 2.0 - edge.dot(along))
	var flight := {"level": 0, "start": start + out * (deck * KitBuilding.STAIR_RUN_PER_RISE), "angle": atan2(-out.y, -out.x)}
	building._ramp(km, flight, 0.0, deck, (gap.y - gap.x) - 0.1, KitBuilding.DECK, KitBuilding.TIMBER)



## Posts under each porch's outer corners, down to the ground where it's lower than the deck.
static func posts(building: KitBuilding, km: KitMesh, terrain: Node) -> void:
	for porch in building.porches:
		if porch == null:
			continue
		for side in _sides(building, porch, porch.depth - 0.1):
			for p: Vector2 in [side["a_out"], side["b_out"]]:
				var world := building.global_transform * Vector3(p.x, 0, p.y)
				var depth := world.y - TerrainEdit.height_at(terrain, world)
				if depth > 0.05:
					depth += 0.3
					km.box(Vector3(0.2, depth, 0.2), KitBuilding._at(Vector3(p.x, -depth / 2.0, p.y)), KitMesh.all(KitBuilding.TIMBER))
