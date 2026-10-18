@tool
class_name KitFurnish
extends RefCounted
## Furnishing a Building's rooms (its Furnish Rooms button, or Map Tools): each
## room with a Kind gets that kind's furniture (RECIPES), placed where it fits:
## against a wall (its back to it), in the middle, round a table, beside or
## facing something already placed, or in rows facing the room's front (the
## wall furthest from its doors). Nothing goes in a doorway's way, in front of
## a window if it's taller than the sill, or on the stairs, and each piece keeps
## a little room in front of it. The same room always comes out the same (it's
## seeded by the room's Point); move the point to get another arrangement.
##
## Containers whose own Loot Table is "standard" take the room's (ROOM_LOOT):
## a kitchen's cabinets hold food, a police office's lockers ammunition.
## Never instanced: building.gd calls plan().

const FURNITURE := "res://world/kit/furniture/"
const STEP := 0.05 # meters: how finely spots are tried, sliding in from a wall
const CLEAR := 0.5 # free floor kept in front of each piece
const SAMPLE := 0.2 # meters between the points checked under a piece

## Each piece: its size's width and depth seen from the front, and which way its
## back faces in its own scene (the kit's newer pieces: -Z).
const PIECES := {
	"bed": {"back": Vector3(-1, 0, 0)}, "desk": {"back": Vector3(1, 0, 0)},
	"kitchen_cabinet": {"back": Vector3(-1, 0, 0)}, "counter": {"back": Vector3(-1, 0, 0)},
}

## What each kind of room gets, in order: [piece, how, how many]. How:
## "wall" against a wall; "center" in the middle; "around" chairs round the
## last table; "beside" along the wall next to the last piece; "facing" on the
## wall across from the last piece; "front" on the room's front wall;
## "rows" in rows facing the front; "fill" as many as fit against the walls.
const RECIPES := {
	"Bedroom": [["bed", "wall", 1], ["nightstand", "beside", 1], ["dresser", "wall", 1], ["chair", "wall", 1]],
	"Kitchen": [["fridge", "wall", 1], ["stove", "beside", 1], ["sink_cabinet", "beside", 1], ["kitchen_cabinet", "wall", 1],
			["table", "center", 1], ["chair", "around", 4]],
	"Living room": [["couch", "wall", 1], ["tv", "facing", 1], ["armchair", "wall", 2], ["coffee_table", "center", 1],
			["bookcase", "wall", 1]],
	"Dining room": [["table", "center", 1], ["chair", "around", 6], ["dresser", "wall", 1]],
	"Bathroom": [["toilet", "wall", 1], ["bathroom_sink", "beside", 1], ["bathtub", "wall", 1]],
	"Laundry": [["washer", "wall", 1], ["washer", "beside", 1], ["sink_cabinet", "wall", 1], ["cardboard_boxes", "wall", 1]],
	"Garage": [["car", "center", 1], ["workbench", "wall", 1], ["shelf", "wall", 1], ["cardboard_boxes", "wall", 2]],
	"Basement storage": [["shelf", "wall", 2], ["workbench", "wall", 1], ["cardboard_boxes", "fill", 4]],
	"Store floor": [["counter", "front", 1], ["grocery_shelf", "rows", 30]],
	"Stockroom": [["shelf", "wall", 2], ["cardboard_boxes", "fill", 5]],
	"Office": [["desk", "wall", 1], ["chair", "around", 1], ["filing_cabinet", "wall", 2], ["bookcase", "wall", 1]],
	"Diner seating": [["counter", "wall", 1], ["stool", "around", 4], ["booth", "fill", 6]],
	"Diner kitchen": [["stove", "wall", 1], ["stove", "beside", 1], ["fridge", "wall", 1], ["fridge", "beside", 1],
			["kitchen_cabinet", "wall", 1], ["sink_cabinet", "wall", 1]],
	"Sanctuary": [["altar", "front", 1], ["pew", "rows", 16]],
	"Classroom": [["chalkboard", "front", 1], ["desk", "front", 1], ["school_desk", "rows", 20], ["bookcase", "wall", 1]],
	"Police office": [["desk", "wall", 1], ["chair", "around", 1], ["desk", "wall", 1], ["chair", "around", 1],
			["filing_cabinet", "wall", 2], ["gun_locker", "wall", 1]],
	"Cells": [["bed", "wall", 1], ["toilet", "wall", 1]],
	"Restroom": [["toilet", "wall", 1], ["toilet", "beside", 1], ["bathroom_sink", "wall", 1], ["bathroom_sink", "beside", 1]],
	"Barn stalls": [["feed_trough", "wall", 2], ["hay_bale", "fill", 4]],
	"Hayloft": [["hay_bale", "fill", 12]],
	"Workshop": [["workbench", "wall", 2], ["shelf", "wall", 1], ["cardboard_boxes", "fill", 2]],
	"Machine bay": [["tractor", "center", 1], ["workbench", "wall", 1], ["hay_bale", "fill", 3]],
}

## The loot table a room's "standard" containers take instead.
const ROOM_LOOT := {
	"Bedroom": "bedroom", "Kitchen": "kitchen", "Diner kitchen": "kitchen", "Bathroom": "bathroom", "Restroom": "bathroom",
	"Office": "office", "Classroom": "office", "Garage": "workshop", "Workshop": "workshop", "Machine bay": "workshop",
	"Laundry": "workshop", "Basement storage": "workshop", "Police office": "police", "Cells": "police",
	"Barn stalls": "farm", "Hayloft": "farm", "Store floor": "grocery", "Stockroom": "grocery", "Diner seating": "snack",
}

static var _sizes := {} # piece -> its Size (read from its scene once)


## Where a room's furniture goes: [{"piece", "xform" (the building's space)}].
static func plan(building: Node3D, room: KitRoom) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if room == null or not RECIPES.has(room.kind):
		return placed
	var f := Furnisher.new(building, room)
	for step: Array in RECIPES[room.kind]:
		f.place(step[0], step[1], step[2])
	return f.placed


## A piece's scene.
static func scene_of(piece: String) -> PackedScene:
	return load(FURNITURE + piece + ".tscn")


## A piece's width (along its front) and depth (front to back), and how far to
## turn its scene so its back faces -Z.
static func footprint(piece: String) -> Dictionary:
	if not _sizes.has(piece):
		var node := scene_of(piece).instantiate()
		_sizes[piece] = node.get("size")
		node.free()
	var size: Vector3 = _sizes[piece]
	var back: Vector3 = PIECES.get(piece, {}).get("back", Vector3(0, 0, -1))
	var turn := 0.0
	if back.x < -0.5:
		turn = -PI / 2.0
	elif back.x > 0.5:
		turn = PI / 2.0
	elif back.z > 0.5:
		turn = PI
	var sideways := absf(back.x) > 0.5
	return {"width": size.z if sideways else size.x, "depth": size.x if sideways else size.z, "height": size.y, "turn": turn}


## Fits pieces into one room, one after another.
class Furnisher:
	var building: Node3D
	var room: KitRoom
	var map: Dictionary
	var level: int
	var placed: Array[Dictionary] = []
	var _bodies: Array[Rect2] = [] # what's placed (and what's in the way: stairs)
	var _fronts: Array[Rect2] = [] # the floor kept free in front of each piece
	var _doors: Array[Rect2] = [] # in front of doorways: nothing at all
	var _windows: Array = [] # [Rect2, sill height]: nothing taller than the sill
	var _walls: Array[Dictionary] = [] # spots against the walls: {"at", "dir" (into the wall)}
	var _cells: Array[Vector2] = [] # the room's floor, cell middles
	var _front_dir := Vector2.ZERO # toward the room's front (away from its doors)
	var _last := {} # the last piece placed: its rect, dir, piece
	var _table := Rect2() # the last table (or desk, counter) placed: chairs go round it
	var _rng := RandomNumberGenerator.new()
	var _inner: Array = [] # this floor's inner walls

	func _init(b: Node3D, r: KitRoom) -> void:
		building = b
		room = r
		level = r.level
		map = b.call("_room_map", level)
		_inner = (b.get("inner_walls") as Array).filter(func(w: KitInnerWall) -> bool: return w != null and w.level == level)
		_rng.seed = hash(Vector2i((r.point * 4.0).round())) + level
		var origin: Vector2 = map["origin"]
		var cells: Dictionary = map["cells"]
		var cell: float = b.get("ROOM_CELL")
		for c: Vector2i in cells:
			if cells[c] != room:
				continue
			var mid := origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell
			_cells.append(mid)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if cells.get(c + d) != room:
					_walls.append({"at": mid, "dir": Vector2(d)})
		_shuffle(_walls)
		_keep_clear()

	## A seeded shuffle (Array.shuffle() uses the global generator).
	func _shuffle(list: Array) -> void:
		for i in range(list.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t: Variant = list[i]
			list[i] = list[j]
			list[j] = t

	## Doorways, windows and stairs on this floor.
	func _keep_clear() -> void:
		var doors: Array[Vector2] = []
		var outside_doors: Array[Vector2] = []
		for op: KitOpening in building.get("openings"):
			if op == null or op.level != level:
				continue
			var ends: Array = building.call("edge_ends", building.call("edge_of", op))
			_opening(op, ends[0], ends[1], doors)
			if op.kind != "window":
				outside_doors.append(doors[doors.size() - 1])
		for wall: KitInnerWall in building.get("inner_walls"):
			if wall == null or wall.level != level:
				continue
			for op in wall.openings:
				if op:
					_opening(op, wall.start, wall.end, doors)
		if level < 0:
			for cellar: KitCellarDoor in building.get("cellar_doors"):
				if cellar and cellar.wall < int(building.call("edge_count")):
					var ends: Array = building.call("edge_ends", cellar.wall)
					var op := KitOpening.make("front", "doorway", cellar.offset, building.get("STAIR_WIDTH"), 0.0, 2.1)
					_opening(op, ends[0], ends[1], doors)
		var width: float = building.get("STAIR_WIDTH")
		for flight: Dictionary in building.call("_flights"):
			var k: int = flight["level"]
			if k != level and k != level - 1:
				continue
			var run: float = building.call("_run", k)
			var frame := Transform2D(float(flight["angle"]), flight["start"])
			# Its own floor: the flight and a way onto it; the floor above: the
			# hole and the landing past the top.
			var from := -1.2 if k == level else 0.0
			var to: float = run if k == level else run + float(building.get("LANDING")) + 0.4
			_bodies.append(_box_of(frame, Vector2(from, -width / 2.0 - 0.1), Vector2(to, width / 2.0 + 0.1)))
		# The room's front: away from where its doors are (its doors to outside,
		# if it has any: they're where people come in).
		var near := func(d: Vector2) -> bool: return _cells.any(func(c: Vector2) -> bool: return c.distance_to(d) < 0.8)
		doors = doors.filter(near)
		var outside := outside_doors.filter(near)
		if not outside.is_empty():
			doors = outside
		if not doors.is_empty() and not _cells.is_empty():
			var middle := Vector2.ZERO
			for c in _cells:
				middle += c
			middle /= _cells.size()
			var door := Vector2.ZERO
			for d in doors:
				door += d
			door /= doors.size()
			var away := middle - door
			_front_dir = Vector2(signf(away.x), 0) if absf(away.x) >= absf(away.y) else Vector2(0, signf(away.y))

	func _opening(op: KitOpening, a: Vector2, b: Vector2, doors: Array[Vector2]) -> void:
		var along := (b - a).normalized()
		var middle := (a + b) / 2.0 + along * op.offset
		var frame := Transform2D(atan2(-along.x, along.y), middle) # x across the wall, y along it
		if op.kind == "window":
			_windows.append([_box_of(frame, Vector2(-0.9, -op.width / 2.0), Vector2(0.9, op.width / 2.0)), op.bottom])
		else:
			_doors.append(_box_of(frame, Vector2(-1.4, -op.width / 2.0 - 0.3), Vector2(1.4, op.width / 2.0 + 0.3)))
			doors.append(middle)

	## The box (in the building's x, z) round a rectangle in frame.
	static func _box_of(frame: Transform2D, lo: Vector2, hi: Vector2) -> Rect2:
		var box := Rect2(frame * lo, Vector2.ZERO)
		for c: Vector2 in [Vector2(lo.x, hi.y), Vector2(hi.x, lo.y), hi]:
			box = box.expand(frame * c)
		return box

	## Places `count` of a piece the way `how` says (as many as fit, up to count).
	func place(piece: String, how: String, count: int) -> void:
		var fp := KitFurnish.footprint(piece)
		for i in count:
			var done := false
			match how:
				"wall", "fill":
					done = _on_wall(piece, fp, func(_s: Dictionary) -> bool: return true)
				"front":
					done = _front_dir != Vector2.ZERO and _on_front_wall(piece, fp)
					if not done:
						done = _on_wall(piece, fp, func(_s: Dictionary) -> bool: return true)
				"beside":
					done = not _last.is_empty() and _on_wall(piece, fp, _beside)
					if not done:
						done = _on_wall(piece, fp, func(_s: Dictionary) -> bool: return true)
				"facing":
					done = not _last.is_empty() and _on_wall(piece, fp, func(s: Dictionary) -> bool: return s["dir"] == -(_last["dir"] as Vector2))
					if not done:
						done = _on_wall(piece, fp, func(_s: Dictionary) -> bool: return true)
				"center":
					done = _in_middle(piece, fp)
				"around":
					done = _around(piece, fp, i)
				"rows":
					_rows(piece, fp, count)
					return
			if not done and how != "around":
				return # no room for more

	## Against a wall: tries the room's wall spots (those pick allows), sliding
	## in from the wall until the piece fits. True if it went somewhere.
	func _on_wall(piece: String, fp: Dictionary, pick: Callable) -> bool:
		for spot: Dictionary in _walls:
			if not pick.call(spot):
				continue
			var dir: Vector2 = spot["dir"]
			var at: Vector2 = spot["at"]
			var d := 0.0
			while d < 0.8:
				var middle := at + dir * (0.125 - float(fp["depth"]) / 2.0 - d)
				if _try(piece, fp, middle, dir):
					return true
				d += STEP
		return false

	## On the room's front wall, as near its middle as it fits.
	func _on_front_wall(piece: String, fp: Dictionary) -> bool:
		var middle := Vector2.ZERO
		for c in _cells:
			middle += c
		middle /= _cells.size()
		var across := Vector2(-_front_dir.y, _front_dir.x)
		var keep := _walls
		_walls = _walls.filter(func(s: Dictionary) -> bool: return s["dir"] == _front_dir)
		_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return absf(((a["at"] as Vector2) - middle).dot(across)) < absf(((b["at"] as Vector2) - middle).dot(across)))
		var done := _on_wall(piece, fp, func(_s: Dictionary) -> bool: return true)
		_walls = keep
		return done

	## Along the same wall as the last piece, next to it.
	func _beside(spot: Dictionary) -> bool:
		if spot["dir"] != _last["dir"]:
			return false
		var r: Rect2 = _last["rect"]
		return r.grow(1.2).has_point(spot["at"])

	## In the middle of the room: the free spot nearest its middle, the piece
	## turned along the room's longer side.
	func _in_middle(piece: String, fp: Dictionary) -> bool:
		if _cells.is_empty():
			return false
		var box := Rect2(_cells[0], Vector2.ZERO)
		for c in _cells:
			box = box.expand(c)
		var middle := box.get_center()
		var dir := Vector2(0, -1) if box.size.x >= box.size.y else Vector2(-1, 0) # its back toward
		var order := _cells.duplicate()
		order.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(middle) < b.distance_squared_to(middle))
		for c: Vector2 in order.slice(0, 200):
			for d: Vector2 in [dir, Vector2(dir.y, dir.x)]:
				if _try(piece, fp, c, d, 0.6):
					return true
		return false

	## Round the last table (or desk, or counter): chairs at its sides, facing it.
	func _around(piece: String, fp: Dictionary, i: int) -> bool:
		if not _table.has_area():
			return false
		var r := _table
		var c := r.get_center()
		var spots := [Vector2(c.x, r.position.y - 0.3), Vector2(c.x, r.end.y + 0.3), Vector2(r.position.x - 0.3, c.y),
				Vector2(r.end.x + 0.3, c.y)]
		if r.size.x > 1.5:
			spots = [Vector2(c.x - r.size.x / 4.0, r.position.y - 0.3), Vector2(c.x + r.size.x / 4.0, r.end.y + 0.3),
					Vector2(c.x + r.size.x / 4.0, r.position.y - 0.3), Vector2(c.x - r.size.x / 4.0, r.end.y + 0.3)] + spots.slice(2)
		elif r.size.y > 1.5:
			spots = [Vector2(r.position.x - 0.3, c.y - r.size.y / 4.0), Vector2(r.end.x + 0.3, c.y + r.size.y / 4.0),
					Vector2(r.position.x - 0.3, c.y + r.size.y / 4.0), Vector2(r.end.x + 0.3, c.y - r.size.y / 4.0)] + spots.slice(0, 2)
		if i >= spots.size():
			return false
		var at: Vector2 = spots[i]
		var away := at - c # its back away from the table
		var dir := Vector2(signf(away.x), 0) if absf(away.x) / maxf(r.size.x, 0.01) > absf(away.y) / maxf(r.size.y, 0.01) else Vector2(0, signf(away.y))
		at += dir * (float(fp["depth"]) / 2.0 - 0.15)
		return _try(piece, fp, at, dir, 0.0, true)

	## Rows across the room facing its front (its back away from it), with an
	## aisle down the middle and round the sides.
	func _rows(piece: String, fp: Dictionary, count: int) -> void:
		var front := _front_dir if _front_dir != Vector2.ZERO else Vector2(1, 0)
		var box := Rect2(_cells[0], Vector2.ZERO)
		for c in _cells:
			box = box.expand(c)
		var across := Vector2(-front.y, front.x)
		var w: float = fp["width"]
		var depth: float = fp["depth"]
		var solid_piece := w * depth > 0.5
		# Between solid rows, room for zombies to path down (the navigation keeps 0.5 m off things).
		var pitch := depth + (1.2 if solid_piece else 0.5)
		var aisle := 1.7 if solid_piece else 0.9
		# Along `front`: from the front wall back; across: both sides of the aisle.
		var front_edge := box.get_center().dot(front) + absf((box.size / 2.0).dot(front)) - 1.6 # leave the front free
		var back_edge := box.get_center().dot(front) - absf((box.size / 2.0).dot(front)) + 0.6
		var half_across := absf((box.size / 2.0).dot(across))
		var mid_across := box.get_center().dot(across)
		var made := 0
		var t := front_edge - depth / 2.0
		while t - depth / 2.0 > back_edge and made < count:
			for side: float in [-1.0, 1.0]:
				var s := aisle / 2.0 + w / 2.0
				while s + w / 2.0 < half_across - 0.3 and made < count: # (the middle aisle's the way through)
					var at := front * t + across * (mid_across + side * s)
					if _try(piece, fp, at, -front, 0.0, true):
						made += 1
					s += w + (0.05 if solid_piece else 0.35)
			t -= pitch

	## Puts the piece here (middle, its back toward dir) if it fits. clear:
	## the free floor kept in front of it (CLEAR, or as given). squeeze: its
	## front may be blocked (a chair at a table).
	func _try(piece: String, fp: Dictionary, middle: Vector2, dir: Vector2, clear := -1.0, squeeze := false) -> bool:
		var w: float = fp["width"]
		var d: float = fp["depth"]
		var half := Vector2(w, d) / 2.0 if absf(dir.y) > 0.5 else Vector2(d, w) / 2.0
		var rect := Rect2(middle - half, half * 2.0)
		var keep := CLEAR if clear < 0.0 else clear
		# In front (-dir): as wide as it, keep deep.
		var front_rect: Rect2
		if absf(dir.y) > 0.5:
			front_rect = Rect2(rect.position.x, rect.position.y - keep if dir.y > 0.0 else rect.end.y, rect.size.x, keep)
		else:
			front_rect = Rect2(rect.position.x - keep if dir.x > 0.0 else rect.end.x, rect.position.y, keep, rect.size.y)
		if not _fits(rect, float(fp["height"])):
			return false
		for b in _bodies:
			if b.intersects(rect):
				return false
		if not squeeze:
			for fr in _fronts:
				if fr.intersects(rect):
					return false
			for b in _bodies:
				if b.intersects(front_rect):
					return false
		var yaw := atan2(-dir.x, -dir.y) + float(fp["turn"]) # its front toward -dir
		var y: float = building.call("floor_top", level)
		var xform := Transform3D(Basis(Vector3.UP, yaw), Vector3(middle.x, y, middle.y))
		var entry := {"piece": piece, "xform": xform}
		placed.append(entry)
		_bodies.append(rect.grow(-0.01))
		if keep > 0.0:
			_fronts.append(front_rect)
		_last = {"rect": rect, "dir": dir, "piece": piece}
		if piece in ["table", "coffee_table", "counter", "desk"]:
			_table = rect
		return true

	## The whole rectangle's on this room's floor: off the walls, out of the
	## doorways, and (if taller than a sill) not in front of a window.
	func _fits(rect: Rect2, height: float) -> bool:
		for door in _doors:
			if door.intersects(rect):
				return false
		for win: Array in _windows:
			if height > float(win[1]) - 0.05 and (win[0] as Rect2).intersects(rect):
				return false
		var nx := maxi(1, ceili(rect.size.x / SAMPLE))
		var nz := maxi(1, ceili(rect.size.y / SAMPLE))
		var wall: float = building.get("WALL")
		for i in nx + 1:
			for j in nz + 1:
				var p := rect.position + Vector2(rect.size.x * i / nx, rect.size.y * j / nz)
				if building.call("_room_at", map, p) != room:
					return false
				if building.call("_distance_to_outline", p) < wall + 0.02:
					return false
				for inner: KitInnerWall in _inner:
					if Geometry2D.get_closest_point_to_segment(p, inner.start, inner.end).distance_to(p) < wall / 2.0 + 0.02:
						return false
		return true
