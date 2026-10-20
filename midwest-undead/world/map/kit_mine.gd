@tool
class_name KitMine
extends StaticBody3D
## A mine to explore: tunnels and chambers laid out on a grid of 2.5 m cells,
## under the hills. Tunnels are one cell wide and 3 m high, held up by timber
## frames, some with rails and mine carts; chambers are big rooms, taller than
## a tunnel. Levels are 4 m apart (level 0 is the node's own height, -1 the
## one under it). It's dark inside: no sun or moon reaches it (its meshes are
## on their own render layer, GameData.RENDER_UNDERGROUND, which those lights
## leave out) and the sky's light is shut out (reflection probes), but for a
## little way in from each entrance.
##
## Draw it with Map Tools (Mines): New mine, then Draw tunnel and Draw chamber
## on a Level, and Mark entrance on the tunnel ends that come out of the hill.
## Its plan shows over everything while it's selected. Put the node where the
## first entrance's floor meets the hillside and press Apply: the ground is
## opened where the mine comes through it (as for a mine entrance). Or edit
## its Tunnels and Chambers here.
##
## Everything under it (lockers, crates, carts...) is drawn on the underground
## layer too, in the game; only the entrances' portals are out in the sun.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const GameData := preload("res://core/game_data.gd")
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const Darkness := preload("res://world/darkness.gd")
const MineShaftBuilder := preload("res://world/map/mine_shaft_builder.gd")
const MinePlan := preload("res://world/map/mine_plan.gd")
const ROCK := preload("res://world/kit/materials/mine_rock.tres")
const DIRT := preload("res://world/kit/materials/mine_floor.tres")
const TIMBER := preload("res://world/kit/materials/timber.tres")
const STEEL := preload("res://world/kit/materials/steel.tres")
const STONE := preload("res://world/kit/materials/stone_gray.tres") # an entrance's face, a shaft's collar
const PLANKS := preload("res://world/kit/materials/wood_planks.tres")
const LADDER := preload("res://world/props/ladder.tscn")
const CART := "res://world/kit/furniture/mine_cart.tscn"
const LOCKER := "res://world/kit/furniture/miner_locker.tscn"
const CACHE := "res://world/kit/furniture/supply_cache.tscn"
const CELL := 2.5 # meters: a tunnel's width
const LEVEL := 4.0 # meters from one level's floor to the next
const TUNNEL_HEIGHT := 3.0
const THICK := 0.4 # walls, floors and ceilings
const FRAME_EVERY := 2 # cells between timber frames
const GAUGE := 0.6 # between the rails
const DARK := Color(0.012, 0.012, 0.015)
const LIT_CELLS := 2 # cells in from an entrance that the daylight still reaches
const APRON := 1.5 # meters the floor runs on out of an entrance, to meet the ground
const HEADWALL := 3.0 # meters of rock face over an entrance's opening
const WING := 2.0 # meters of rock face beside it
const COLLAR := 1.0 # meters of stone round a shaft's top, out from its walls' inside
const CLIMB_REACH := 1.0 # how far out from a ladder you can be and still climb
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var tunnels: Array[MineTunnel] = []:
	set(value):
		_watch(tunnels, value)
		tunnels = value
		_changed()
@export var chambers: Array[MineChamber] = []:
	set(value):
		_watch(chambers, value)
		chambers = value
		_changed()
@export var shafts: Array[MineShaft] = []:
	set(value):
		_watch(shafts, value)
		shafts = value
		_changed()
## Cells a cave-in blocks, dug through with a pickaxe (world/map/mine_cave_in.gd).
@export var cave_ins: Array[Vector3i] = []:
	set(value):
		cave_ins = value
		_changed()
@export var floods: Array[MineFlood] = []:
	set(value):
		_watch(floods, value)
		floods = value
		_changed()
## Miners' lockers and supply caches it puts in by itself, in dead ends and
## round chambers (besides any you place: Map Tools, Place locker / cache).
@export_range(0, 40) var scatter_loot := 0:
	set(value):
		scatter_loot = value
		_changed()
## Zombies it fills itself with at the start of a new game, per 100 m of its
## tunnels and chambers (besides any at ZombieSpawn markers placed in it: Map
## Tools, Place zombies). Some are miners (characters/zombie/kinds/miner.tres).
@export_range(0.0, 20.0, 0.5) var zombie_density := 0.0

## Map Tools: the plan's overlay (editor only, never saved).
var show_plan := false:
	set(value):
		show_plan = value
		_draw_plan()
var plan_level := 0:
	set(value):
		plan_level = value
		_draw_plan()
var draft: Array[Vector3i] = []: # a tunnel or chamber being drawn: its cells
	set(value):
		draft = value
		_draw_plan()

static var _all: Array[KitMine] = [] # the mines in the game (contains())
var _generated: Array[Node] = []
var _plan: MeshInstance3D
var _dirty := true
var _queued := false
# Worked out from the tunnels and chambers by _collect():
var _cells := {} # Vector3i cell -> {"top": its height, "chamber": bool, "floor", "rise", "up": a ramp's (MineTunnel.steps())}
var _columns := {} # Vector2i (x, z) -> Array[Vector2] open spans (floor, ceiling), low to high
var _open := {} # Vector4i (x, z, side x, side z) -> true: an entrance's open end
var _lit := {} # Vector2i column -> true: daylight still reaches it
var _portals: Array = [] # [Vector3i cell, Vector2i outward]
var _mouths := {} # Vector2i column -> Vector2i outward: an entrance's mouth
var _dug := {} # Vector3i cell -> true: a cave-in dug through (in the game; saved)
var _roofless := {} # Vector2i column -> the top of a shaft that comes out on the surface (meters)


func _ready() -> void:
	ensure_built()
	if not Engine.is_editor_hint():
		underground(self)


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and not self in _all:
		_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


## Whether a point (in the map's space) is inside any mine's open space:
## characters there are drawn on the underground layer (zombie.gd, player.gd).
static func contains(pos: Vector3) -> bool:
	for mine in _all:
		if mine.inside(pos):
			return true
	return false


func inside(pos: Vector3) -> bool:
	var local := to_local(pos)
	var spans: Variant = _columns.get(Vector2i(roundi(local.x / CELL), roundi(local.z / CELL)))
	if spans == null:
		return false # (most places: no new empty array for the miss)
	for span: Vector2 in spans:
		if local.y > span.x - 0.5 and local.y < span.y:
			return true
	return false


## Somewhere a zombie can stand at the start (in the map's space): an open
## cell's floor, not in the daylight, a cave-in, a flood or a shaft, and if
## `near` is given, within `reach` cells of it. Vector3.INF if there's nowhere.
func zombie_spot(dice: RandomNumberGenerator, near := Vector3i.MAX, reach := 0) -> Vector3:
	var flooded := {}
	for flood in floods:
		if flood == null:
			continue
		var r := flood.rect()
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				flooded[Vector3i(x, flood.corner_a.y, z)] = true
	var spots: Array[Vector3i] = []
	for cell: Vector3i in _cells:
		if _lit.has(Vector2i(cell.x, cell.z)) or cell in cave_ins or flooded.has(cell) or _cells[cell].has("shaft") or _is_ramp(cell):
			continue
		if near != Vector3i.MAX and (cell.y != near.y or maxi(absi(cell.x - near.x), absi(cell.z - near.z)) > reach):
			continue
		spots.append(cell)
	if spots.is_empty():
		return Vector3.INF
	var cell := spots[dice.randi() % spots.size()]
	var at := cell_position(cell) + Vector3(dice.randf_range(-0.6, 0.6), 0.1, dice.randf_range(-0.6, 0.6))
	at.y = _cells[cell]["floor"] + 0.1
	return to_global(at)


## How many zombies Zombie Density fills it with.
func zombie_count() -> int:
	return roundi(_cells.size() * CELL / 100.0 * zombie_density)


## Builds it now if anything changed (main.gd calls this before the map is in
## the tree; in the game it's built once).
func ensure_built() -> void:
	if _dirty:
		_rebuild()


## Draws everything under node on the underground layer only: out of the
## sun's and moon's light (main.gd), still in every lamp's.
static func underground(node: Node) -> void:
	if node.has_meta("daylight"):
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = GameData.RENDER_UNDERGROUND
	for child in node.get_children(true):
		underground(child)


## Its generators' fuel and its cages' stops (main.gd saves them).
func save_state() -> Dictionary:
	var data := {"generators": [], "cages": [], "dug": _dug.keys().map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])}
	for generator in find_children("*", "MineGenerator", true, false):
		(data["generators"] as Array).append(generator.save_state())
	for cage in _cages():
		(data["cages"] as Array).append(cage.save_state())
	return data


func load_state(data: Dictionary) -> void:
	var generators := find_children("*", "MineGenerator", true, false)
	var saved: Array = data.get("generators", [])
	for i in mini(generators.size(), saved.size()):
		generators[i].load_state(saved[i])
	var cages := _cages()
	saved = data.get("cages", [])
	for i in mini(cages.size(), saved.size()):
		cages[i].load_state(saved[i])
	for c: Array in data.get("dug", []):
		var cell := Vector3i(int(c[0]), int(c[1]), int(c[2]))
		for cave_in in find_children("*", "MineCaveIn", true, false):
			if (cave_in as MineCaveIn).cell == cell:
				(cave_in as MineCaveIn).dig_out()


## Its cages (in the game they're moved out from under it: main.gd).
func _cages() -> Array:
	return _generated.filter(func(n: Node) -> bool: return is_instance_valid(n) and n is MineCage)


## Where floor `level` is, in the mine's own space.
static func cell_position(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL, cell.y * LEVEL, cell.z * CELL)


## The cell a point (in the mine's own space) is in, on `level`.
static func cell_at(local: Vector3, level: int) -> Vector3i:
	return Vector3i(roundi(local.x / CELL), level, roundi(local.z / CELL))


## The lowest floor, in the map's space (the game reaches down to it: ground.gd).
func lowest_floor() -> float:
	_collect()
	var low := 0.0
	for cell: Vector3i in _cells:
		low = minf(low, _cells[cell]["floor"])
	return global_position.y + low - THICK


func is_open(cell: Vector3i) -> bool:
	_collect()
	return _cells.has(cell)


func _watch(old: Array, new: Array) -> void:
	for item: Resource in old:
		if item and item.changed.is_connected(_changed):
			item.changed.disconnect(_changed)
	for item: Resource in new:
		if item and not item.changed.is_connected(_changed):
			item.changed.connect(_changed)


func _changed() -> void:
	_dirty = true
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


# --- The layout ------------------------------------------------------------------------

## Which cells are open, and how high, from the tunnels and chambers.
func _collect() -> void:
	_cells.clear()
	_columns.clear()
	_open.clear()
	_lit.clear()
	_portals.clear()
	_mouths.clear()
	_roofless.clear()
	for tunnel in tunnels:
		if tunnel == null:
			continue
		for step in tunnel.steps():
			if not _cells.has(step["cell"]):
				_cells[step["cell"]] = {"top": TUNNEL_HEIGHT, "chamber": false, "floor": step["floor"], "rise": step["rise"],
						"up": step["up"]}
	for chamber in chambers:
		if chamber == null:
			continue
		for cell in chamber.cells():
			var top: float = _cells[cell]["top"] if _cells.has(cell) else 0.0
			_cells[cell] = {"top": maxf(chamber.height, top), "chamber": true, "floor": cell.y * LEVEL, "rise": 0.0,
					"up": Vector2i.ZERO}
	for shaft in shafts:
		if shaft == null or shaft.top < shaft.bottom:
			continue
		for level in range(shaft.bottom, shaft.top + 1):
			# Each level's piece reaches into the next one's, so they're one space.
			var high := shaft.rise() if level == shaft.top else LEVEL + 0.01
			_cells[Vector3i(shaft.column.x, level, shaft.column.y)] = {"top": high, "chamber": false, "floor": level * LEVEL,
					"rise": 0.0, "up": Vector2i.ZERO, "shaft": shaft}
		if shaft.to_surface:
			_roofless[shaft.column] = shaft.top * LEVEL + shaft.rise()
	for tunnel in tunnels:
		if tunnel == null:
			continue
		var cells := tunnel.cells()
		if cells.size() < 2:
			continue
		if tunnel.entrance_at_start:
			_entrance(cells, false)
		if tunnel.entrance_at_end:
			_entrance(cells, true)
	for cell: Vector3i in _cells:
		var column := Vector2i(cell.x, cell.z)
		if not _columns.has(column):
			_columns[column] = []
		(_columns[column] as Array).append(_span(cell))
	for column: Vector2i in _columns:
		var spans: Array = _columns[column]
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array = [spans[0]]
		for span: Vector2 in spans.slice(1):
			var last: Vector2 = merged[-1]
			if span.x < last.y - 0.001: # overlapping (a tunnel inside a tall chamber): one space
				merged[-1] = Vector2(last.x, maxf(last.y, span.y))
			else:
				merged.append(span)
		_columns[column] = merged


## A cell's open space, floor to ceiling (a ramp's from its low edge's floor
## to its high edge's ceiling).
func _span(cell: Vector3i) -> Vector2:
	var c: Dictionary = _cells[cell]
	return Vector2(c["floor"], c["floor"] + c["rise"] + c["top"])


func _is_ramp(cell: Vector3i) -> bool:
	return _cells[cell]["rise"] > 0.0


## A tunnel end that opens out of the hill: no end wall, a portal, daylight.
func _entrance(cells: Array[Vector3i], at_end: bool) -> void:
	var ordered := cells.duplicate()
	if at_end:
		ordered.reverse()
	var mouth: Vector3i = ordered[0]
	var inner: Vector3i = ordered[1]
	var out := Vector2i(mouth.x - inner.x, mouth.z - inner.z)
	_open[Vector4i(mouth.x, mouth.z, out.x, out.y)] = true
	_portals.append([mouth, out])
	_mouths[Vector2i(mouth.x, mouth.z)] = out
	for i in mini(LIT_CELLS, ordered.size()):
		_lit[Vector2i(ordered[i].x, ordered[i].z)] = true


## The parts of span not open in the column beside it (where a wall goes).
static func _walled(span: Vector2, beside: Array) -> Array[Vector2]:
	var parts: Array[Vector2] = [span]
	for open: Vector2 in beside:
		var next: Array[Vector2] = []
		for part in parts:
			if open.y <= part.x or open.x >= part.y:
				next.append(part)
				continue
			if open.x > part.x:
				next.append(Vector2(part.x, open.x))
			if open.y < part.y:
				next.append(Vector2(open.y, part.y))
		parts = next
	return parts.filter(func(p: Vector2) -> bool: return p.y - p.x > 0.01)


static func _overlaps(spans: Array, part: Vector2) -> bool:
	for open: Vector2 in spans:
		if open.x < part.y and open.y > part.x:
			return true
	return false


## The cells as few rectangles as it takes (Rect2i: x, z, across, along).
static func _rects(cells: Array) -> Array[Rect2i]:
	var left := {}
	for c: Vector2i in cells:
		left[c] = true
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var result: Array[Rect2i] = []
	for c: Vector2i in sorted:
		if not left.has(c):
			continue
		var w := 1
		while left.has(Vector2i(c.x + w, c.y)):
			w += 1
		var d := 1
		while true:
			var row_full := true
			for x in w:
				if not left.has(Vector2i(c.x + x, c.y + d)):
					row_full = false
					break
			if not row_full:
				break
			d += 1
		for x in w:
			for z in d:
				left.erase(Vector2i(c.x + x, c.y + z))
		result.append(Rect2i(c.x, c.y, w, d))
	return result


static func _rect_center(r: Rect2i, y: float) -> Vector3:
	return Vector3((r.position.x + (r.size.x - 1) / 2.0) * CELL, y, (r.position.y + (r.size.y - 1) / 2.0) * CELL)


# --- Building it ---------------------------------------------------------------------------

func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	_collect()
	var km := KitMesh.new()
	_floors_and_ceilings(km)
	_ramps(km)
	_walls(km)
	_frames(km)
	_rails(km)
	_generated = km.add_to(self)
	for node in _generated:
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
	var outside := KitMesh.new() # the portals and collars, out in the daylight
	_portals_of(outside)
	var inside := KitMesh.new() # the shafts' landings
	for shaft in shafts:
		if shaft and shaft.top >= shaft.bottom:
			MineShaftBuilder.build(self, shaft, inside, outside)
	for node in inside.add_to(self, "Landings"):
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
		_generated.append(node)
	for node in outside.add_to(self, "Portals"):
		node.set_meta("daylight", true) # (underground() leaves it be)
		_generated.append(node)
	_carts()
	_cave_ins()
	_floods()
	_scatter()
	_darkness()
	_draw_plan()


func _floors_and_ceilings(km: KitMesh) -> void:
	var floors := {} # floor height -> columns
	var ceilings := {} # ceiling height -> columns
	for column: Vector2i in _columns:
		for span: Vector2 in _columns[column]:
			if not floors.has(span.x):
				floors[span.x] = []
			(floors[span.x] as Array).append(column)
			if _roofless.has(column) and span.y >= _roofless[column] - 0.001:
				continue # open to the sky
			if not ceilings.has(span.y):
				ceilings[span.y] = []
			(ceilings[span.y] as Array).append(column)
	for y: float in floors:
		for r in _rects(floors[y]):
			km.box(Vector3(r.size.x * CELL, THICK, r.size.y * CELL), Transform3D(Basis.IDENTITY, _rect_center(r, y - THICK / 2.0)),
					[ROCK, ROCK, ROCK, DIRT, ROCK, ROCK])
	for y: float in ceilings:
		for r in _rects(ceilings[y]):
			km.box(Vector3(r.size.x * CELL, THICK, r.size.y * CELL), Transform3D(Basis.IDENTITY, _rect_center(r, y + THICK / 2.0)),
					KitMesh.all(ROCK))


## A ramp's sloping floor and ceiling, a slab for each cell (under and over
## them, the flat floor and ceiling of its span are closed off by its walls).
func _ramps(km: KitMesh) -> void:
	for cell: Vector3i in _cells:
		if not _is_ramp(cell):
			continue
		var c: Dictionary = _cells[cell]
		var up := Vector3(c["up"].x, 0, c["up"].y)
		var rise: float = c["rise"]
		var along := up * CELL + Vector3(0, rise, 0) # its low edge to its high edge
		var z := along.normalized()
		var x := Vector3.UP.cross(z).normalized() # across, level
		var normal := z.cross(x) # (a right-handed frame: faces the right way out)
		var basis := Basis(x, normal, z)
		var middle := cell_position(cell)
		middle.y = c["floor"] + rise / 2.0
		var size := Vector3(CELL, THICK, along.length() + 0.05)
		km.box(size, Transform3D(basis, middle - normal * THICK / 2.0), [ROCK, ROCK, ROCK, DIRT, ROCK, ROCK])
		km.box(size, Transform3D(basis, middle + Vector3(0, c["top"], 0) + normal * THICK / 2.0), KitMesh.all(ROCK))


## Rock walls wherever an open space meets solid ground: beside a closed
## cell, and over or under where the space beside it is lower or higher (a
## tunnel's header where it meets a tall chamber). In runs along each wall line.
func _walls(km: KitMesh) -> void:
	var runs := {} # [side, line, bottom, top, down, up] -> Array of cells along the line
	for column: Vector2i in _columns:
		for span: Vector2 in _columns[column]:
			for side in SIDES:
				if _open.has(Vector4i(column.x, column.y, side.x, side.y)):
					continue
				for part in _walled(span, _columns.get(column + side, [])):
					var along := column.y if side.x != 0 else column.x
					var line := column.x if side.x != 0 else column.y
					# Down to under the floor, up over the ceiling, where it meets them.
					var key := [side, line, part.x, part.y, is_equal_approx(part.x, span.x), is_equal_approx(part.y, span.y)]
					if not runs.has(key):
						runs[key] = []
					(runs[key] as Array).append(along)
	for key: Array in runs:
		var side: Vector2i = key[0]
		var line: int = key[1]
		var part := Vector2(key[2], key[3])
		var bottom: float = part.x - (THICK if key[4] else 0.0)
		var top: float = part.y + (THICK if key[5] else 0.0)
		var cells: Array = runs[key]
		cells.sort()
		var start: int = cells[0]
		for i in cells.size():
			var last: int = cells[i]
			if i + 1 < cells.size() and cells[i + 1] == last + 1:
				continue
			_wall_run(km, side, line, start, last, part, bottom, top)
			if i + 1 < cells.size():
				start = cells[i + 1]


func _wall_run(km: KitMesh, side: Vector2i, line: int, first: int, last: int, part: Vector2, bottom: float, top: float) -> void:
	# Past each end into solid ground (an outside corner), so corners close.
	var before := Vector2i(line, first - 1) if side.x != 0 else Vector2i(first - 1, line)
	var after := Vector2i(line, last + 1) if side.x != 0 else Vector2i(last + 1, line)
	var from := first * CELL - CELL / 2.0 - (0.0 if _overlaps(_columns.get(before, []), part) else THICK)
	var to := last * CELL + CELL / 2.0 + (0.0 if _overlaps(_columns.get(after, []), part) else THICK)
	var out := line * CELL + (CELL / 2.0 + THICK / 2.0) * (side.x + side.y)
	var mid := (from + to) / 2.0
	var size: Vector3
	var at: Vector3
	if side.x != 0:
		size = Vector3(THICK, top - bottom, to - from)
		at = Vector3(out, (bottom + top) / 2.0, mid)
	else:
		size = Vector3(to - from, top - bottom, THICK)
		at = Vector3(mid, (bottom + top) / 2.0, out)
	km.box(size, Transform3D(Basis.IDENTITY, at), KitMesh.all(ROCK))


## Timber frames along the tunnels: two posts and a cap, every few cells
## where both sides are walled.
func _frames(km: KitMesh) -> void:
	var placed := {}
	for tunnel in tunnels:
		if tunnel == null:
			continue
		var cells := tunnel.cells()
		for i in range(1, cells.size() - 1):
			var cell := cells[i]
			if i % FRAME_EVERY != 0 or placed.has(cell) or _cells[cell]["chamber"] or _is_ramp(cell) or _cells[cell].has("shaft"):
				continue
			var way := Vector2i(cells[i + 1].x - cells[i - 1].x, cells[i + 1].z - cells[i - 1].z)
			if way.x != 0 and way.y != 0:
				continue # a corner
			var across := Vector2i(1, 0) if way.x == 0 else Vector2i(0, 1)
			var column := Vector2i(cell.x, cell.z)
			var span := _span(cell)
			if _overlaps(_columns.get(column + across, []), span) or _overlaps(_columns.get(column - across, []), span):
				continue # a side passage here
			placed[cell] = true
			_frame(km, cell_position(cell), Vector3(across.x, 0, across.y), 0.25, 0.3, CELL)


## Each entrance's heavier frame, the rock face round it and the floor on out.
## In the sun's light: they're outside.
func _portals_of(km: KitMesh) -> void:
	for portal: Array in _portals:
		var cell: Vector3i = portal[0]
		var out: Vector2i = portal[1]
		var across := Vector3(absi(out.y), 0, absi(out.x))
		var at := cell_position(cell) + Vector3(out.x, 0, out.y) * (CELL / 2.0 - 0.2)
		_frame(km, at, across, 0.35, 0.4, CELL + 0.8)
		var outward := Vector3(out.x, 0, out.y)
		# A stone face round the opening, over and beside it, where the hole in the
		# hillside (Apply) reaches past the tunnel.
		var face := cell_position(cell) + outward * (CELL / 2.0 + THICK / 2.0)
		var wide := CELL + 2.0 * WING
		var thick := Vector3(absi(out.x), 0, absi(out.y)) * THICK
		km.box(across * wide + thick + Vector3(0, HEADWALL, 0),
				Transform3D(Basis.IDENTITY, face + Vector3(0, TUNNEL_HEIGHT + HEADWALL / 2.0, 0)), KitMesh.all(STONE))
		for s: float in [-1.0, 1.0]:
			km.box(across * WING + thick + Vector3(0, TUNNEL_HEIGHT + THICK, 0),
					Transform3D(Basis.IDENTITY, face + across * s * (CELL + WING) / 2.0 + Vector3(0, (TUNNEL_HEIGHT - THICK) / 2.0, 0)),
					KitMesh.all(STONE))
		# The floor on out, under the portal, to where the ground takes over.
		km.box(across * (CELL + THICK * 2.0) + Vector3(absi(out.x), 0, absi(out.y)) * APRON + Vector3(0, THICK, 0),
				Transform3D(Basis.IDENTITY, cell_position(cell) + outward * (CELL + APRON) / 2.0 + Vector3(0, -THICK / 2.0, 0)),
				[ROCK, ROCK, ROCK, DIRT, ROCK, ROCK])
		# A board over the mouth, on the rock face.
		var board := across * (CELL + 1.4) + Vector3(0, 0.5, 0) + Vector3(absi(out.x), 0, absi(out.y)) * 0.12
		km.box(board, Transform3D(Basis.IDENTITY, face + outward * (THICK / 2.0 + 0.06) + Vector3(0, TUNNEL_HEIGHT + 0.35, 0)),
				KitMesh.all(TIMBER), false)


func _frame(km: KitMesh, at: Vector3, across: Vector3, post: float, beam: float, width: float) -> void:
	var inset := CELL / 2.0 - post / 2.0
	for s: float in [-1.0, 1.0]:
		km.box(Vector3(post, TUNNEL_HEIGHT, post), Transform3D(Basis.IDENTITY, at + across * inset * s + Vector3(0, TUNNEL_HEIGHT / 2.0, 0)),
				KitMesh.all(TIMBER))
	var along := Vector3(absf(across.z), 0, absf(across.x))
	km.box(across * width + along * beam + Vector3(0, beam, 0), Transform3D(Basis.IDENTITY, at + Vector3(0, TUNNEL_HEIGHT - beam / 2.0, 0)),
			KitMesh.all(TIMBER), false)


## Two rails on sleepers down the middle of tunnels that have them (not solid:
## you walk over them).
func _rails(km: KitMesh) -> void:
	for tunnel in tunnels:
		if tunnel == null or not tunnel.rails:
			continue
		var cells := tunnel.cells()
		for i in cells.size() - 1:
			var a := cell_position(cells[i])
			var b := cell_position(cells[i + 1])
			if not is_equal_approx(a.y, b.y) or _is_ramp(cells[i]) or _is_ramp(cells[i + 1]):
				continue # (not on ramps)
			var way := (b - a).normalized()
			var across := Vector3(absf(way.z), 0, absf(way.x))
			var along := Vector3(absf(way.x), 0, absf(way.z))
			# Past the middle at a corner (and at the ends), so the rails meet.
			var corner_a := i == 0 or _turns(cells, i)
			var corner_b := i + 1 == cells.size() - 1 or _turns(cells, i + 1)
			var from := a - way * (GAUGE / 2.0 + 0.03 if corner_a else 0.0)
			var to := b + way * (GAUGE / 2.0 + 0.03 if corner_b else 0.0)
			var length := from.distance_to(to)
			var mid := (from + to) / 2.0
			for s: float in [-1.0, 1.0]:
				km.box(along * length + across * 0.06 + Vector3(0, 0.07, 0),
						Transform3D(Basis.IDENTITY, mid + across * s * GAUGE / 2.0 + Vector3(0, 0.095, 0)), KitMesh.all(STEEL), false)
			for k in 4:
				var at := a.lerp(b, (k + 0.5) / 4.0)
				km.box(along * 0.15 + across * (GAUGE + 0.4) + Vector3(0, 0.06, 0), Transform3D(Basis.IDENTITY, at + Vector3(0, 0.03, 0)),
						KitMesh.all(TIMBER), false)


static func _turns(cells: Array[Vector3i], i: int) -> bool:
	if i <= 0 or i >= cells.size() - 1:
		return false
	var d := Vector2i(cells[i + 1].x - cells[i - 1].x, cells[i + 1].z - cells[i - 1].z)
	return d.x != 0 and d.y != 0


## Mine carts standing at the end of the rails, one behind the other, where
## a tunnel stops dead (a cart fills a tunnel: anywhere else it'd block the way).
func _carts() -> void:
	if not ResourceLoader.exists(CART):
		return
	var scene := load(CART) as PackedScene
	var n := 0
	for tunnel in tunnels:
		if tunnel == null or not tunnel.rails or tunnel.carts <= 0:
			continue
		var cells := tunnel.cells()
		if cells.size() < 2:
			continue
		var left := tunnel.carts
		for at_end: bool in [true, false]:
			var ordered := cells.duplicate() # from the tip back
			if at_end:
				ordered.reverse()
			if not _dead_end(ordered[0], ordered[1]) or (tunnel.entrance_at_end if at_end else tunnel.entrance_at_start):
				continue
			for i in range(0, ordered.size() - 1):
				if left <= 0 or _turns(ordered, i) or (i > 0 and not _plain(ordered[i])):
					break
				var way := cell_position(ordered[i]) - cell_position(ordered[i + 1])
				var cart := scene.instantiate() as Node3D
				n += 1
				cart.name = "Cart%d" % n
				cart.position = cell_position(ordered[i]) + Vector3(0, 0.13, 0)
				cart.rotation.y = atan2(way.x, way.z)
				add_child(cart, false, Node.INTERNAL_MODE_BACK)
				_generated.append(cart)
				left -= 1


## A tunnel's tip with nowhere to go on from it but back the way it came.
func _dead_end(tip: Vector3i, back: Vector3i) -> bool:
	if _cells[tip]["chamber"]:
		return false
	for side in SIDES:
		var next := tip + Vector3i(side.x, 0, side.y)
		if next != back and _overlaps(_columns.get(Vector2i(next.x, next.z), []), _span(tip)):
			return false
	return true


## Just a stretch of tunnel: open only to the cells before and after it.
func _plain(cell: Vector3i) -> bool:
	if _cells[cell]["chamber"]:
		return false
	var count := 0
	for side in SIDES:
		var next := Vector2i(cell.x + side.x, cell.z + side.y)
		if _overlaps(_columns.get(next, []), _span(cell)):
			count += 1
	return count == 2


func _roofless_rise(column: Vector2i) -> float:
	for shaft in shafts:
		if shaft and shaft.column == column and shaft.to_surface:
			return shaft.rise()
	return 0.0


## A heap of rock and broken timber filling each cave-in's cell, floor to roof.
func _cave_ins() -> void:
	for cell in cave_ins:
		if _dug.has(cell) or not _cells.has(cell):
			continue
		var span := _span(cell)
		var height := span.y - span.x
		var heap := MineCaveIn.new()
		heap.name = "CaveIn%d" % (cave_ins.find(cell) + 1)
		heap.cell = cell
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(cell)
		var km := KitMesh.new()
		km.box(Vector3(CELL, height, CELL * 0.7), Transform3D.IDENTITY.translated(Vector3(0, height / 2.0, 0)),
				[null, null, null, null, null, null]) # (it blocks the whole tunnel)
		for i in 14: # tumbled rocks, bigger at the bottom
			var up := dice.randf() * height
			var s := lerpf(1.3, 0.5, up / height) * dice.randf_range(0.7, 1.1)
			var basis := Basis.from_euler(Vector3(dice.randf_range(-0.6, 0.6), dice.randf() * TAU, dice.randf_range(-0.6, 0.6)))
			km.box(Vector3(s, s * 0.7, s * 0.9), Transform3D(basis, Vector3(dice.randf_range(-1.0, 1.0), up * 0.9 + s * 0.3, dice.randf_range(-0.7, 0.7))),
					KitMesh.all(ROCK), false)
		for i in 3: # broken timbers
			var basis := Basis.from_euler(Vector3(dice.randf_range(-0.9, 0.9), dice.randf_range(-0.4, 0.4) + PI / 2.0 * (i % 2), dice.randf_range(-0.5, 0.5)))
			km.box(Vector3(0.25, 0.25, CELL * 0.9), Transform3D(basis, Vector3(dice.randf_range(-0.6, 0.6), dice.randf_range(0.5, height - 0.5), dice.randf_range(-0.5, 0.5))),
					KitMesh.all(TIMBER), false)
		for node in km.add_to(heap):
			if node is MeshInstance3D:
				(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
		heap.position = cell_position(cell) + Vector3(0, span.x - cell.y * LEVEL, 0)
		heap.dug_out.connect(func(c: Vector3i) -> void: _dug[c] = true)
		add_child(heap, false, Node.INTERNAL_MODE_BACK)
		_generated.append(heap)


## Where a locker or crate goes in a cell: against its first wall, facing in
## (furniture's back is its -Z). Null if the cell has no wall.
func wall_spot(cell: Vector3i, depth: float) -> Variant:
	_collect()
	if not _cells.has(cell):
		return null
	var span := _span(cell)
	for side in SIDES:
		if _overlaps(_columns.get(Vector2i(cell.x + side.x, cell.z + side.y), []), Vector2(span.x, span.x + 2.0)):
			continue
		var at := cell_position(cell) + Vector3(side.x, 0, side.y) * (CELL / 2.0 - depth / 2.0 - 0.05)
		at.y = span.x
		return Transform3D(Basis(Vector3.UP, atan2(-side.x, -side.y)), at)
	return null


## The lockers and caches it scatters (Scatter Loot): dead ends first, then
## the edges of chambers, picked the same way every time (by the layout).
func _scatter() -> void:
	if scatter_loot <= 0:
		return
	var spots: Array[Vector3i] = []
	for tunnel in tunnels:
		if tunnel == null or tunnel.points.size() < 2:
			continue
		var cells := tunnel.cells()
		for tip: Array in [[cells[0], cells[1], tunnel.entrance_at_start], [cells[-1], cells[-2], tunnel.entrance_at_end]]:
			if not tip[2] and _dead_end(tip[0], tip[1]) and not (tunnel.rails and tunnel.carts > 0) and not tip[0] in cave_ins:
				spots.append(tip[0])
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([tunnels.size(), chambers.size(), spots])
	var edges: Array[Vector3i] = []
	for chamber in chambers:
		if chamber == null:
			continue
		for cell in chamber.cells():
			if wall_spot(cell, 0.6) != null and not cell in spots:
				edges.append(cell)
	for i in range(edges.size() - 1, 0, -1): # shuffled, the same way each time
		var j := dice.randi_range(0, i)
		var swap := edges[i]
		edges[i] = edges[j]
		edges[j] = swap
	spots.append_array(edges)
	var placed := 0
	for cell in spots:
		if placed >= scatter_loot:
			break
		var scene := load(LOCKER if placed % 2 == 0 else CACHE) as PackedScene
		var spot: Variant = wall_spot(cell, 0.6)
		if scene == null or spot == null:
			continue
		var piece := scene.instantiate() as Node3D
		placed += 1
		piece.name = "Loot%d" % placed # (the same name each time: saves find it by it)
		piece.transform = spot
		add_child(piece, false, Node.INTERNAL_MODE_BACK)
		_generated.append(piece)


## Each flood's water.
func _floods() -> void:
	for flood in floods:
		if flood == null:
			continue
		var r := flood.rect()
		var room := TUNNEL_HEIGHT
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				var c := Vector3i(x, flood.corner_a.y, z)
				if _cells.has(c):
					room = maxf(room, _cells[c]["top"])
		var water := MineWater.new()
		water.name = "Flood%d" % (floods.find(flood) + 1)
		water.size = Vector2(r.size.x, r.size.y) * CELL
		water.depth = flood.depth
		water.room = room
		water.position = _rect_center(r, flood.corner_a.y * LEVEL)
		add_child(water, false, Node.INTERNAL_MODE_BACK)
		_generated.append(water)


## The dark: a reflection probe over each stretch the daylight doesn't reach,
## shutting out the sky's light (as a basement's, building.gd). They overlap
## a little, so there are no lighter seams where they meet.
func _darkness() -> void:
	var spaces := {} # Vector2 span -> columns
	for column: Vector2i in _columns:
		if _lit.has(column):
			continue
		for span: Vector2 in _columns[column]:
			if _roofless.has(column): # dark below its top level, not up to the sky
				span.y = minf(span.y, _roofless[column] - _roofless_rise(column) + TUNNEL_HEIGHT)
			if not spaces.has(span):
				spaces[span] = []
			(spaces[span] as Array).append(column)
	var n := 0
	for span: Vector2 in spaces:
		for r in _rects(spaces[span]):
			var probe := Darkness.probe(Vector3(r.size.x * CELL + 1.0, span.y - span.x + 0.4, r.size.y * CELL + 1.0),
					_rect_center(r, (span.x + span.y) / 2.0), DARK, 0.3)
			n += 1
			probe.name = "Dark%d" % n
			probe.cull_mask = 0 # nothing to reflect but the dark: cheap to render
			add_child(probe, false, Node.INTERNAL_MODE_BACK)
			_generated.append(probe)


# --- The ground ------------------------------------------------------------------------

## Opens the hillside where the mine comes through it: wherever the ground
## is in a tunnel or chamber, or just over its ceiling. Under plenty of hill
## it stays closed. Returns the (x, z) area changed.
func apply(terrain: Node) -> Rect2:
	_collect()
	var spacing: float = terrain.vertex_spacing
	var reach := CELL / 2.0 + THICK + 0.5
	var rect := Rect2()
	var first := true
	for column: Vector2i in _columns:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p := to_global(Vector3(column.x * CELL + corner.x * (reach + 3.0), 0, column.y * CELL + corner.y * (reach + 3.0)))
			if first:
				rect = Rect2(p.x, p.z, 0, 0)
				first = false
			rect = rect.expand(Vector2(p.x, p.z))
	if first:
		return rect
	for x in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing) + 1):
		for z in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing) + 1):
			var v := Vector3(x * spacing, 0.0, z * spacing)
			var local := to_local(Vector3(v.x, global_position.y, v.z))
			var ground := TerrainEdit.height_at(terrain, v) - global_position.y
			var near := false
			var inside := false
			var middle := Vector2i(roundi(local.x / CELL), roundi(local.z / CELL))
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var column := middle + Vector2i(dx, dz)
					if not _columns.has(column):
						continue
					var off := Vector2(absf(local.x - column.x * CELL), absf(local.z - column.y * CELL))
					if off.x > reach + 3.0 or off.y > reach + 3.0:
						continue
					near = true # (only holes it could have made are closed again)
					if off.x > reach or off.y > reach:
						continue
					if _roofless.has(column) and absf(ground - _roofless[column]) < 3.0 \
							and maxf(off.x, off.y) > CELL / 2.0 + COLLAR - spacing:
						continue # at the top of a shaft, only as far as its collar
					if _mouths.has(column):
						# Out of an entrance, only as far as the floor runs on (a hole
						# hides the ground a vertex further out than itself).
						var out: Vector2i = _mouths[column]
						var ahead := (local.x - column.x * CELL) * out.x + (local.z - column.y * CELL) * out.y
						if ahead > CELL / 2.0 + APRON - spacing:
							continue
					for span: Vector2 in _columns[column]:
						if ground > span.x - 0.2 and ground < span.y + THICK + 1.0:
							inside = true
			if inside:
				terrain.data.set_control_hole(v, true)
			elif near:
				terrain.data.set_control_hole(v, false)
	TerrainEdit.finish(terrain, rect)
	return rect


# --- The plan, in the editor ----------------------------------------------------------------

## Its plan, in the editor (world/map/mine_plan.gd).
func _draw_plan() -> void:
	MinePlan.draw(self)
