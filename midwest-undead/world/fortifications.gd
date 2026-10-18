extends Node
## Making places safe: planks over doors and windows, and freestanding barricades.
## Neither has health; zombies can't get through or break them. The player places
## them with held items (player.gd) and can take them down again (main.gd).
##
## It also owns the zombies' way in through windows: every unboarded ground-floor
## window gets a NavigationLink, so a zombie whose path is shorter through it walks
## up, smashes the glass (window_pane.gd) and climbs in (zombie.gd). Boarding the
## window turns its link off.
##
## Barricades and planks change where zombies can walk, so placing or removing one
## re-bakes the navigation mesh, on a background thread (no hitch). Doors aren't in
## the bake (zombie paths run through them so they can bash them), but planks are,
## so a boarded doorway is a wall to the pathfinding.
##
## Every door and window in the map scene can be boarded (a door's or window's
## boardable setting turns that off: the compound gate, upstairs windows). Ones set "boarded at
## start" get their planks when a new game starts, like the survivors' houses.
##
## Saved state: which openings are boarded, every window's damage, and where the
## barricades stand. Openings are saved by their place in the map scene (main.gd
## gives each one a "town_id").

const GameData := preload("res://core/game_data.gd")
const Building := preload("res://world/building.gd")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const Fortification := preload("res://world/fortification.gd")
const Sound := preload("res://core/sound.gd")
const Ground := preload("res://world/ground.gd")
const NavTiles := preload("res://world/nav_tiles.gd")
const ViewDistance := preload("res://core/view_distance.gd")
const VIEW_METERS := 80.0 # boards past this aren't drawn (core/view_distance.gd)

const BARRICADE_SIZE := Vector3(2.4, 1.6, 0.2) # width, height, thickness
## How they look (set Models on these to swap in models; HOW_TO_MODEL.md, "Props").
const WINDOW_PLANKS := preload("res://world/props/window_planks.tscn")
const DOOR_PLANKS := preload("res://world/props/door_planks.tscn")
const BARRICADE := preload("res://world/props/barricade.tscn")
## The stand-ins' colors (world/props/make_props.gd).
const WOOD := Color(0.58, 0.45, 0.28)
const WOOD_DARK := Color(0.42, 0.31, 0.19)
const LINK_REACH := 0.9 # how far out from the wall, each side, a window's path link ends
## Navigation layer for the window links. Zombies use it; bandits don't (they
## can't climb through windows, so they'd only get stuck).
const WINDOW_LINK_LAYER := 2

var nav_region: NavTiles # where planks and barricades go (they're in the navigation bake)
## One per boardable opening: {"kind": "door"/"window", "door"/"window": the node,
## "id": its town_id (for saving), "width", "height", "transform" (world: see
## _add_opening), "area" (what the planks aim at), "link" (windows only),
## "planks" (or null), "at_start": boarded when a new game starts}.
var openings: Array[Dictionary] = []
var barricades: Array[Fortification] = []


func _ready() -> void:
	add_to_group("fortifications")


## windows and doors: every WindowPane and Door on the map. Boards up the ones
## set "boarded at start" (quietly: call before the first navigation bake).
func setup(region: NavTiles, windows: Array, doors: Array) -> void:
	nav_region = region
	for pane: WindowPane in windows:
		if not pane.boardable:
			continue
		var size := pane.pane_size()
		# x out of the building: the pane's outside is its -X.
		var xform := Transform3D(pane.global_basis * Basis(Vector3.UP, PI), pane.global_position)
		_add_opening({"kind": "window", "window": pane, "width": size.z, "height": size.y,
				"transform": xform, "at_start": pane.boarded_at_start}, _floor_y(pane))
	for door: Door in doors:
		if not door.boardable:
			continue
		var closed := door.closed_transform()
		# A door's outside is its -X too (it swings in, toward +X).
		var xform := Transform3D(closed.basis * Basis(Vector3.UP, PI), closed * door.leaf_offset)
		_add_opening({"kind": "door", "door": door, "width": door.leaf_size.z + 0.1,
				"height": door.leaf_size.y, "transform": xform, "at_start": door.boarded_at_start}, 0.0)
	for i in openings.size():
		if openings[i]["at_start"]:
			board(i, true)


## Floor height inside, under the window (its window link ends there). Kit
## buildings and walls tell the pane how far down the floor is.
func _floor_y(pane: Node3D) -> float:
	if pane.has_meta("floor_drop"):
		return pane.global_position.y - float(pane.get_meta("floor_drop"))
	var node := pane.get_parent()
	while node != null and not node is Building:
		node = node.get_parent()
	if node == null:
		return Ground.height_at(pane.global_position) # not in a building: the ground
	return (node as Building).global_position.y + (node as Building).floor_y


# --- Queries (player.gd) ---------------------------------------------------------

## The opening an "openings" area belongs to, or -1.
func opening_of(area: Object) -> int:
	return int(area.get_meta("opening", -1)) if area else -1


func is_boarded(index: int) -> bool:
	return openings[index]["planks"] != null


func describe(index: int) -> String:
	return "door" if openings[index]["kind"] == "door" else "window"


## Room for a barricade here? (Nothing solid in the way, people included.)
func can_place_barricade(xform: Transform3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(BARRICADE_SIZE.x, BARRICADE_SIZE.y - 0.25, BARRICADE_SIZE.z + 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Lifted a little off the ground, so the ground, a curb or a road doesn't count.
	query.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15 + shape.size.y / 2.0, 0))
	query.collision_mask = GameData.LAYER_WORLD | GameData.LAYER_GLASS | GameData.LAYER_PLAYER \
			| GameData.LAYER_ZOMBIES | GameData.LAYER_NPC
	return get_viewport().get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Changes -------------------------------------------------------------------

## used: nailed up from used planks (taking them down again destroys them).
func board(index: int, quiet := false, used := false) -> void:
	var o := openings[index]
	if o["planks"] != null:
		return
	var planks := _make_planks(o)
	planks.opening = index
	planks.used = used
	o["planks"] = planks
	if o["kind"] == "door":
		var door: Door = o["door"]
		if door.is_open and not door.is_broken:
			door.set_open(false, not quiet) # shut it first; a broken one just hangs there
		door.boarded = true
	else:
		(o["window"] as WindowPane).planked = true
		(o["link"] as NavigationLink3D).enabled = false
	if not quiet:
		Sound.play_at(planks, "hammer", planks.global_position, 0.0, 30.0)
		rebake(planks.global_position)


func place_barricade(xform: Transform3D, quiet := false) -> void:
	var body := Fortification.new()
	body.kind = "barricade"
	body.transform = xform
	nav_region.add_child(body)
	if not _add_look(body, BARRICADE):
		_box_collision(body, BARRICADE_SIZE, Vector3(0, BARRICADE_SIZE.y / 2.0, 0))
	barricades.append(body)
	if not quiet:
		Sound.play_at(body, "hammer", body.global_position, 0.0, 30.0)
		rebake(body.global_position)


## Planks gone without a trace (loading a save where you'd taken them down).
func _unboard(index: int) -> void:
	var piece: Fortification = openings[index]["planks"]
	take_down(piece, true)


## Takes down planks or a barricade. Returns the item to give back: a
## barricade, used planks, or "" (used planks splinter coming down again).
func take_down(piece: Fortification, quiet := false) -> String:
	if piece.kind == "planks":
		var o := openings[piece.opening]
		o["planks"] = null
		if o["kind"] == "door":
			(o["door"] as Door).boarded = false
		else:
			(o["window"] as WindowPane).planked = false
			(o["link"] as NavigationLink3D).enabled = true
	else:
		barricades.erase(piece)
	var at := piece.global_position
	if not quiet:
		Sound.play_at(piece, "hammer", at, -3.0, 25.0)
	piece.get_parent().remove_child(piece) # gone before the re-bake reads the scene
	piece.queue_free()
	if not quiet:
		rebake(at)
	return piece.item_id()


# --- Saving --------------------------------------------------------------------

func save_state() -> Dictionary:
	var boarded := []
	var used := [] # the boarded ones nailed up from used planks
	var windows := {}
	for o in openings:
		if o["planks"] != null:
			boarded.append(o["id"])
			if (o["planks"] as Fortification).used:
				used.append(o["id"])
		if o["kind"] == "window":
			var pane: WindowPane = o["window"]
			if pane.is_broken or pane.health < pane.max_health:
				windows[o["id"]] = pane.save_state()
	var placed := []
	for b in barricades:
		placed.append([b.global_position.x, b.global_position.y, b.global_position.z, b.rotation.y])
	return {"boarded": boarded, "used": used, "windows": windows, "barricades": placed}


## On top of a new town (its "boarded at start" planks already up).
func load_state(data: Dictionary) -> void:
	var index := {}
	for i in openings.size():
		index[openings[i]["id"]] = i
	var boarded: Array = data.get("boarded", [])
	var used: Array = data.get("used", [])
	var windows: Dictionary = data.get("windows", {})
	for i in openings.size():
		var o := openings[i]
		var want: bool = o["id"] in boarded
		var was_used: bool = o["id"] in used
		# Planks you'd taken down, or put back up from used planks: off first.
		if o["planks"] != null and (not want or (o["planks"] as Fortification).used != was_used):
			_unboard(i)
		if want:
			board(i, true, was_used)
	for id in windows:
		if index.has(id) and openings[index[id]]["kind"] == "window":
			(openings[index[id]]["window"] as WindowPane).load_state(windows[id])
	for b in data.get("barricades", []):
		place_barricade(Transform3D(Basis(Vector3.UP, float(b[3])), Vector3(float(b[0]), float(b[1]), float(b[2]))), true)
	rebake()


# --- Building the pieces ---------------------------------------------------------

## record: see openings. Its "transform" is the opening's frame in the world:
## origin in the middle of the opening (in the wall), x pointing out of the
## building, z along the wall. floor_y: the floor inside (for a window's link).
func _add_opening(record: Dictionary, floor_y: float) -> void:
	var o := record
	var node: Node = o["door"] if o["kind"] == "door" else o["window"]
	o["id"] = str(node.get_meta("town_id", node.get_path()))
	o["planks"] = null
	var index := openings.size()

	# What the planks aim at: a box filling the opening, a little thicker than the wall.
	var area := Area3D.new()
	area.collision_layer = GameData.LAYER_OPENINGS
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("opening", index)
	_box_collision(area, Vector3(0.6, o["height"], o["width"]), Vector3.ZERO)
	add_child(area)
	area.global_transform = o["transform"]
	o["area"] = area

	if o["kind"] == "window":
		var xform: Transform3D = o["transform"]
		var out := xform.basis.x
		var link := NavigationLink3D.new()
		link.navigation_layers = WINDOW_LINK_LAYER
		link.start_position = Vector3(xform.origin.x, floor_y, xform.origin.z) + out * LINK_REACH
		link.end_position = Vector3(xform.origin.x, floor_y, xform.origin.z) - out * LINK_REACH
		link.set_meta("window", o["window"])
		link.set_meta("sill_y", xform.origin.y - float(o["height"]) / 2.0)
		add_child(link)
		o["link"] = link
	openings.append(o)


## Boards nailed across the outside of the opening (stretched to it), and one
## solid box that blocks it (or the model's own collision shapes).
func _make_planks(o: Dictionary) -> Fortification:
	var body := Fortification.new()
	body.kind = "planks"
	var width: float = o["width"]
	var height: float = o["height"]
	var count := 4 if o["kind"] == "door" else 3
	var xform: Transform3D = o["transform"]
	var at := Transform3D(xform.basis, xform.origin + xform.basis.x * 0.17) # just outside the wall
	body.transform = nav_region.global_transform.affine_inverse() * at
	nav_region.add_child(body) # in the bake: zombies path around a boarded opening
	# The boards reach from the middle of the top one to the middle of the bottom one, plus a board.
	var boards := Vector3(0.06, height - height / count + 0.22, width + 0.3)
	if not _add_look(body, DOOR_PLANKS if o["kind"] == "door" else WINDOW_PLANKS, boards):
		_box_collision(body, Vector3(0.1, height + 0.1, width + 0.2), Vector3.ZERO)
	return body


## The look from a prop scene on body (fitted to size, if given). Returns true
## when the model brought its own collision shapes.
func _add_look(body: Fortification, scene: PackedScene, size := Vector3.ZERO) -> bool:
	var look := KitProp.make(scene, [], size)
	look.name = "Look"
	body.add_child(look)
	for mesh in look.meshes():
		ViewDistance.limit(mesh, VIEW_METERS)
	return look.take_shapes(body)


func _box_collision(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)


# --- Navigation ------------------------------------------------------------------

## How far around a change the navigation is baked again (meters each way).
const REBAKE_REACH := 8.0


## Re-bake the navigation around something that changed at `at` (in the
## background; world/nav_tiles.gd), or everywhere when `at` is left out.
## structures.gd uses this too.
func rebake(at := Vector3.INF) -> void:
	if at == Vector3.INF:
		nav_region.rebake_all()
	else:
		nav_region.rebake(AABB(at - Vector3.ONE * REBAKE_REACH, Vector3.ONE * REBAKE_REACH * 2.0))
