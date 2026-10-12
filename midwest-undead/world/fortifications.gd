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
## Saved state: which openings are boarded, every window's damage, and where the
## barricades stand. Openings are numbered in build order, so saves line up.

const GameData := preload("res://core/game_data.gd")
const Building := preload("res://world/building.gd")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const Fortification := preload("res://world/fortification.gd")
const Sound := preload("res://core/sound.gd")

const BARRICADE_SIZE := Vector3(2.4, 1.6, 0.2) # width, height, thickness
const WOOD := Color(0.58, 0.45, 0.28)
const WOOD_DARK := Color(0.42, 0.31, 0.19)
const LINK_REACH := 0.9 # how far out from the wall, each side, a window's path link ends
## Navigation layer for the window links. Zombies use it; bandits don't (they
## can't climb through windows, so they'd only get stuck).
const WINDOW_LINK_LAYER := 2

var nav_region: NavigationRegion3D
## One per boardable opening: the Building's record (see Building.boardables) plus
## "transform" (world: see _opening_transform),
## "area" (what the planks aim at), "link" (windows only), "planks" (or null).
var openings: Array[Dictionary] = []
var barricades: Array[Fortification] = []
var _baking := false
var _rebake_again := false


func _ready() -> void:
	add_to_group("fortifications")


## buildings: every Building, in build order. Call after the first navigation bake.
func setup(region: NavigationRegion3D, buildings: Array) -> void:
	nav_region = region
	nav_region.bake_finished.connect(_on_bake_finished)
	for building: Building in buildings:
		for record in building.boardables:
			_add_opening(building, record)


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

func board(index: int, quiet := false) -> void:
	var o := openings[index]
	if o["planks"] != null:
		return
	var planks := _make_planks(o)
	planks.opening = index
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
		rebake()


func place_barricade(xform: Transform3D, quiet := false) -> void:
	var body := Fortification.new()
	body.kind = "barricade"
	body.transform = xform
	var half := BARRICADE_SIZE / 2.0
	for x: float in [-half.x + 0.1, half.x - 0.1]: # posts
		_board_mesh(body, Vector3(0.14, BARRICADE_SIZE.y, 0.14), Vector3(x, half.y, 0.0), 0.0, WOOD_DARK)
	for i in 4: # rails, a little crooked
		_board_mesh(body, Vector3(BARRICADE_SIZE.x, 0.22, 0.06),
				Vector3(0.0, 0.3 + i * 0.36, 0.05), [0.03, -0.05, 0.02, -0.03][i], WOOD)
	_box_collision(body, BARRICADE_SIZE, Vector3(0, half.y, 0))
	nav_region.add_child(body)
	barricades.append(body)
	if not quiet:
		Sound.play_at(body, "hammer", body.global_position, 0.0, 30.0)
		rebake()


## Takes down planks or a barricade. Returns the item to give back.
func take_down(piece: Fortification) -> String:
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
	Sound.play_at(piece, "hammer", piece.global_position, -3.0, 25.0)
	piece.get_parent().remove_child(piece) # gone before the re-bake reads the scene
	piece.queue_free()
	rebake()
	return piece.item_id()


# --- Saving --------------------------------------------------------------------

func save_state() -> Dictionary:
	var boarded := []
	var windows := {}
	for i in openings.size():
		if openings[i]["planks"] != null:
			boarded.append(i)
		if openings[i]["kind"] == "window":
			var pane: WindowPane = openings[i]["window"]
			if pane.is_broken or pane.health < pane.max_health:
				windows[str(i)] = pane.save_state()
	var placed := []
	for b in barricades:
		placed.append([b.global_position.x, b.global_position.y, b.global_position.z, b.rotation.y])
	return {"boarded": boarded, "windows": windows, "barricades": placed}


func load_state(data: Dictionary) -> void:
	var windows: Dictionary = data.get("windows", {})
	for key in windows:
		var i := int(key)
		if i < openings.size() and openings[i]["kind"] == "window":
			(openings[i]["window"] as WindowPane).load_state(windows[key])
	for i in data.get("boarded", []):
		if int(i) < openings.size():
			board(int(i), true)
	for b in data.get("barricades", []):
		place_barricade(Transform3D(Basis(Vector3.UP, float(b[3])), Vector3(float(b[0]), float(b[1]), float(b[2]))), true)
	if not data.get("boarded", []).is_empty() or not data.get("barricades", []).is_empty():
		rebake()


# --- Building the pieces ---------------------------------------------------------

## The opening's frame in the world: origin in the middle of the opening (in the
## wall), x pointing out of the building, z along the wall.
func _opening_transform(building: Building, record: Dictionary) -> Transform3D:
	var outward: Vector3 = record["outward"]
	# Building space has +x pointing into the building; turn it round for the front wall.
	var turn := Basis(Vector3.UP, PI) if outward.x < 0.0 else Basis.IDENTITY
	return Transform3D(building.global_basis * turn, building.global_transform * (record["center"] as Vector3))


func _add_opening(building: Building, record: Dictionary) -> void:
	var o := record.duplicate()
	o["transform"] = _opening_transform(building, record)
	o["planks"] = null
	var index := openings.size()

	# What the planks aim at: a box filling the opening, a little thicker than the wall.
	var area := Area3D.new()
	area.collision_layer = GameData.LAYER_OPENINGS
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("opening", index)
	_box_collision(area, Vector3(0.6, record["height"], record["width"]), Vector3.ZERO)
	add_child(area)
	area.global_transform = o["transform"]
	o["area"] = area

	if record["kind"] == "window":
		var xform: Transform3D = o["transform"]
		var out := xform.basis.x
		var floor_y: float = building.global_position.y + building.FLOOR_Y
		var link := NavigationLink3D.new()
		link.navigation_layers = WINDOW_LINK_LAYER
		link.start_position = Vector3(xform.origin.x, floor_y, xform.origin.z) + out * LINK_REACH
		link.end_position = Vector3(xform.origin.x, floor_y, xform.origin.z) - out * LINK_REACH
		link.set_meta("window", record["window"])
		link.set_meta("sill_y", xform.origin.y - float(record["height"]) / 2.0)
		add_child(link)
		o["link"] = link
	openings.append(o)


## Boards nailed across the outside of the opening, and one solid box that blocks it.
func _make_planks(o: Dictionary) -> Fortification:
	var body := Fortification.new()
	body.kind = "planks"
	var width: float = o["width"]
	var height: float = o["height"]
	var count := 4 if o["kind"] == "door" else 3
	for i in count:
		var y := -height / 2.0 + height * (i + 0.5) / count
		_board_mesh(body, Vector3(0.05, 0.22, width + 0.3), Vector3(0.0, y, 0.0), [0.04, -0.06, 0.03, -0.04][i], WOOD)
	_box_collision(body, Vector3(0.1, height + 0.1, width + 0.2), Vector3.ZERO)
	nav_region.add_child(body) # in the bake: zombies path around a boarded opening
	var xform: Transform3D = o["transform"]
	body.global_transform = Transform3D(xform.basis, xform.origin + xform.basis.x * 0.17) # just outside the wall
	return body


func _board_mesh(parent: Node3D, size: Vector3, pos: Vector3, tilt: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = pos
	inst.rotation.x = tilt
	parent.add_child(inst)


func _box_collision(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)


# --- Navigation ------------------------------------------------------------------

## Re-bake on a thread. Changes that land while one is running wait for it, then
## bake once more. structures.gd uses this too, so only one bake runs at a time.
func rebake() -> void:
	if _baking:
		_rebake_again = true
		return
	_baking = true
	nav_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	_baking = false
	if _rebake_again:
		_rebake_again = false
		rebake()
