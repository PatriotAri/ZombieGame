extends Node
## Building: scaffolding, guard posts, fences, fence gates, garden plots and ammo
## benches (made by the woodworker and the machinist). Base objects like these
## only go inside a zone, and only while it's clear of zombies. Hold one and
## press use:
##   - Looking at the ground, it goes there, facing you.
##   - Looking at scaffolding you built, scaffolding or a guard post snaps on top
##     of it. A guard post on top makes it a guard tower: a ladder runs down the
##     side facing you (walk into it to climb; player.gd). A guard post on the
##     ground is just a guard post.
##   - Looking at a fence or gate you built, a fence or gate lines up at its
##     nearer end, to run a wall along.
## A see-through copy shows where it'll go before you place it: green if it fits,
## red if it doesn't (player.gd draws it with show_ghost()).
## Like barricades, none of it has health and zombies can't break it. Placing,
## taking down, or opening a gate re-bakes the navigation mesh (shared with
## fortifications.gd, so only one bake runs at a time).
## Saved: every piece, what it stands on, and whether gates are open.

const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")
const StructurePiece := preload("res://world/structure_piece.gd")
const GateLeaf := preload("res://world/gate_leaf.gd")
const Zones := preload("res://world/zones.gd")

const KINDS := ["scaffold", "guard_post", "fence", "fence_gate", "garden_plot", "ammo_bench", "shell_bench", "rifle_bench"]
## The ammo benches, and the round each one's brass is colored like (pistol, shells, rifle).
const BENCHES := {"ammo_bench": Color(0.75, 0.6, 0.2), "shell_bench": Color(0.7, 0.12, 0.1), "rifle_bench": Color(0.6, 0.5, 0.25)}
const GARDEN := Vector3(3.0, 0.35, 2.0)
const BENCH := Vector3(1.8, 1.0, 0.8)
const SOIL := Color(0.25, 0.18, 0.12)
const LEAVES := Color(0.3, 0.55, 0.22)
const BUILD_RANGE := 6.0
const SCAFFOLD := Vector3(2.4, 3.0, 2.4)
const POST_HEIGHT := 2.5 # floor to roof
const RAIL_HEIGHT := 1.0
const POST_GAP := 1.1 # the opening in the railing: the ladder side (or the way in)
const FENCE := Vector3(3.0, 2.2, 0.15)
const MAX_STACK := 3 # scaffolding this many high, at most
const LADDER_OUT := 0.12 # how far the ladder stands off the scaffolding
const CLIMB_REACH := 1.0 # how far out from the ladder you can be and still climb
const WOOD := Color(0.58, 0.45, 0.28)
const WOOD_DARK := Color(0.4, 0.3, 0.19)
const STEEL := Color(0.42, 0.43, 0.45)
const PLYWOOD := Color(0.55, 0.45, 0.3)

var pieces: Array[StructurePiece] = []
var _nav_region: NavigationRegion3D
var _fortifications: Node # owns the shared navigation re-bake
var zones: Zones # set by main.gd once the zones exist (for the clear-zone rule)
var _materials := {} # Color -> StandardMaterial3D, shared by every piece
var _ghost: Node3D
var _ghost_key := "" # what the ghost currently shows, so it's only rebuilt when that changes
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("structures")


func setup(nav_region: NavigationRegion3D, fortifications: Node) -> void:
	_nav_region = nav_region
	_fortifications = fortifications


static func is_buildable(item_id: String) -> bool:
	return item_id in KINDS


# --- Where it would go ----------------------------------------------------------

## Where the held piece would go for a look from `origin` along `dir`. Returns
## {"ok", "xform", "on" (the scaffolding it'd stand on, or null), "ladder"
## (meters of ladder it'd get, 0 for none), "text" (the prompt: what it'd do, or
## why it can't)}.
func preview(kind: String, origin: Vector3, dir: Vector3, viewer: Vector3, exclude: Array[RID]) -> Dictionary:
	var result := _where(kind, origin, dir, viewer, exclude)
	if result.has("aimed"):
		var problem := _zone_problem((result["xform"] as Transform3D).origin)
		if problem != "":
			result["ok"] = false
			result["text"] = problem
	return result


## Base objects only go inside a zone, and only while it's clear: why not here,
## or "" if it's fine.
func _zone_problem(at: Vector3) -> String:
	if zones == null:
		return ""
	var zone := zones.zone_at(at)
	if zone == "":
		return "Base objects only go inside a zone"
	if zones.status_of(zone) != Zones.Status.SAFE:
		return zones.full_name(zone) + " isn't clear"
	return ""


func _where(kind: String, origin: Vector3, dir: Vector3, viewer: Vector3, exclude: Array[RID]) -> Dictionary:
	var result := {"ok": false, "xform": Transform3D(), "on": null, "ladder": 0.0, "text": ""}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * BUILD_RANGE, GameData.LAYER_WORLD, exclude)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	var label := GameData.item_name(kind).to_lower()
	if hit.is_empty():
		result["text"] = "Look at the ground to build"
		return result
	result["aimed"] = true # it's pointing at something: the zone rule applies
	var thing: Object = hit["collider"]
	if thing is GateLeaf:
		thing = (thing as GateLeaf).piece

	if thing is StructurePiece and (thing as StructurePiece).kind == "scaffold" and kind in ["scaffold", "guard_post"]:
		var base := thing as StructurePiece
		var basis := base.global_basis
		if kind == "guard_post":
			basis = _facing(basis, base.global_position, viewer) # the ladder goes on your side
		result["xform"] = Transform3D(basis, base.global_position + Vector3.UP * SCAFFOLD.y)
		result["on"] = base
		if base.above != null:
			result["text"] = "There's already something on top"
		elif kind == "scaffold" and _stack_height(base) >= MAX_STACK:
			result["text"] = "Scaffolding doesn't go any higher"
		elif not _room(kind, result["xform"], [base.get_rid()]):
			result["text"] = "No room on top"
		else:
			result["ok"] = true
			if kind == "guard_post":
				result["ladder"] = _ground_height(base, base.global_position.y + SCAFFOLD.y)
				result["text"] = "make a guard tower"
			else:
				result["text"] = "stack the scaffolding"
		return result

	if thing is StructurePiece and (thing as StructurePiece).kind in ["fence", "fence_gate"] and kind in ["fence", "fence_gate"]:
		var other := thing as StructurePiece
		var along := other.global_basis.x
		var side := 1.0 if (hit["position"] - other.global_position).dot(along) >= 0.0 else -1.0
		result["xform"] = Transform3D(other.global_basis, other.global_position + along * side * FENCE.x)
		result["ok"] = _room(kind, result["xform"], [other.get_rid()])
		result["text"] = ("line up the " + label) if result["ok"] else "No room there"
		return result

	if thing is StructurePiece:
		result.erase("aimed")
		result["text"] = "Can't build on that"
		return result
	if (hit["normal"] as Vector3).y < 0.8:
		result.erase("aimed")
		result["text"] = "Look at the ground to build"
		return result
	# On the ground, facing you. Scaffolding and posts square up to the compass so
	# rows of them line up.
	var to_viewer := viewer - (hit["position"] as Vector3)
	var yaw := atan2(to_viewer.x, to_viewer.z)
	if kind in ["scaffold", "guard_post"]:
		yaw = snappedf(yaw, PI / 2.0)
	result["xform"] = Transform3D(Basis(Vector3.UP, yaw), hit["position"])
	result["ok"] = _room(kind, result["xform"], [])
	result["text"] = ("build the " + label) if result["ok"] else "No room for the " + label
	return result


## The base turned a quarter at a time, so its +z side (the ladder, or the way
## in) faces the viewer.
func _facing(basis: Basis, at: Vector3, viewer: Vector3) -> Basis:
	var to_viewer := Vector3(viewer.x - at.x, 0.0, viewer.z - at.z).normalized()
	var best := basis
	var best_dot := -INF
	for k in 4:
		var turned := basis.rotated(Vector3.UP, k * PI / 2.0)
		var d := turned.z.dot(to_viewer)
		if d > best_dot:
			best = turned
			best_dot = d
	return best


func _stack_height(piece: StructurePiece) -> int:
	var n := 1
	while piece.below != null:
		piece = piece.below
		n += 1
	return n


## How far `top_y` is above the ground the stack stands on.
func _ground_height(piece: StructurePiece, top_y: float) -> float:
	while piece.below != null:
		piece = piece.below
	return top_y - piece.global_position.y


## Nothing solid (or anyone) in the way of the piece at xform.
func _room(kind: String, xform: Transform3D, exclude: Array[RID]) -> bool:
	var size := _size(kind)
	var shape := BoxShape3D.new()
	# A little smaller than the piece, and lifted off what it stands on, so
	# touching the ground, a curb or its neighbor doesn't count.
	shape.size = Vector3(size.x - 0.3, size.y - 0.25, maxf(size.z - 0.3, 0.1))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15 + shape.size.y / 2.0, 0))
	query.collision_mask = GameData.LAYER_WORLD | GameData.LAYER_GLASS | GameData.LAYER_PLAYER \
			| GameData.LAYER_ZOMBIES | GameData.LAYER_NPC
	query.exclude = exclude
	return get_viewport().get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _size(kind: String) -> Vector3:
	match kind:
		"scaffold":
			return SCAFFOLD
		"guard_post":
			return Vector3(SCAFFOLD.x, POST_HEIGHT + 0.1, SCAFFOLD.z)
		"garden_plot":
			return Vector3(GARDEN.x, 0.6, GARDEN.z)
		"ammo_bench", "shell_bench", "rifle_bench":
			return Vector3(BENCH.x, 1.2, BENCH.z)
	return FENCE


# --- Building and taking down -------------------------------------------------

## Builds what preview() said. quiet: loading a save (no sound, no re-bake).
func build(kind: String, xform: Transform3D, on: StructurePiece, quiet := false) -> StructurePiece:
	var piece := StructurePiece.new()
	piece.kind = kind
	piece.transform = xform
	_model(kind, piece, null)
	_collision(kind, piece)
	if on:
		piece.below = on
		on.above = piece
	_nav_region.add_child(piece) # in the bake: zombies path around it
	pieces.append(piece)
	if kind == "fence_gate":
		_add_leaf(piece)
	if kind == "guard_post" and on:
		_add_ladder(piece, _ground_height(on, xform.origin.y))
	if not quiet:
		Sound.play_at(piece, "hammer", piece.global_position + Vector3.UP, 0.0, 30.0)
		_fortifications.call("rebake")
	return piece


## Takes a piece down. Returns the item to give back, or "" if something on top
## of it has to come down first.
func take_down(piece: StructurePiece) -> String:
	if piece.above != null:
		return ""
	if piece.below:
		piece.below.above = null
	pieces.erase(piece)
	if piece.ladder:
		_let_go(piece.ladder)
	Sound.play_at(piece, "hammer", piece.global_position + Vector3.UP, -3.0, 25.0)
	piece.get_parent().remove_child(piece) # gone before the re-bake reads the scene
	piece.queue_free()
	_fortifications.call("rebake")
	return piece.kind


func toggle_gate(piece: StructurePiece, quiet := false) -> void:
	piece.gate_open = not piece.gate_open
	var angle := -PI / 2.0 if piece.gate_open else 0.0
	if quiet:
		piece.leaf.rotation.y = angle
		return
	var tween := piece.create_tween()
	tween.tween_property(piece.leaf, "rotation:y", angle, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _fortifications.call("rebake")) # once it's swung
	Sound.play_at(piece, "door_open" if piece.gate_open else "door_close", piece.global_position + Vector3.UP, -4.0, 20.0)


## Anyone climbing a ladder that's about to vanish has to let go of it.
func _let_go(ladder: Area3D) -> void:
	for body in ladder.get_overlapping_bodies():
		if body.has_method("exit_ladder"):
			body.call("exit_ladder", ladder)


# --- Saving --------------------------------------------------------------------

func save_state() -> Array:
	var data := []
	for piece in pieces:
		var p := piece.global_position
		data.append({"kind": piece.kind, "position": [p.x, p.y, p.z], "yaw": piece.global_rotation.y,
				"on": pieces.find(piece.below) if piece.below else -1, "open": piece.gate_open})
	return data


func load_state(data: Array) -> void:
	var built := [] # one per saved entry (null if skipped), so "on" indices still line up
	for entry: Dictionary in data:
		var kind: String = entry.get("kind", "")
		if not is_buildable(kind):
			built.append(null)
			continue
		var p: Array = entry.get("position", [0, 0, 0])
		var xform := Transform3D(Basis(Vector3.UP, float(entry.get("yaw", 0.0))), Vector3(float(p[0]), float(p[1]), float(p[2])))
		var on_index := int(entry.get("on", -1))
		var on: StructurePiece = built[on_index] if on_index >= 0 and on_index < built.size() else null
		if on_index >= 0 and on == null:
			built.append(null) # what it stood on is gone
			continue
		var piece := build(kind, xform, on, true)
		built.append(piece)
		if kind == "fence_gate" and bool(entry.get("open", false)):
			toggle_gate(piece, true)
	if not data.is_empty():
		_fortifications.call("rebake")


# --- The preview -----------------------------------------------------------------

## A see-through copy of the held piece where preview() says it goes, green or
## red; kind "" hides it.
func show_ghost(kind: String, view: Dictionary) -> void:
	if kind == "":
		if _ghost:
			_ghost.visible = false
		return
	var ladder: float = view.get("ladder", 0.0)
	var key := "%s/%.2f" % [kind, ladder]
	if key != _ghost_key:
		if _ghost:
			_ghost.queue_free()
		if _ghost_material == null:
			_ghost_material = StandardMaterial3D.new()
			_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost = Node3D.new()
		add_child(_ghost)
		_model(kind, _ghost, _ghost_material)
		if kind == "fence_gate":
			_leaf_model(_ghost, _ghost_material)
		if ladder > 0.0:
			_ladder_model(_ghost, ladder, _ghost_material)
		_ghost_key = key
		for mesh in _ghost.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = true
	_ghost.global_transform = view["xform"]
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if view["ok"] else Color(1.0, 0.25, 0.2, 0.35)


# --- Models and collision ----------------------------------------------------------

## The look of each piece, in its own space: origin on the ground (or the top of
## the scaffolding below) in the middle, +z toward the side you placed it from.
## mat: one material for everything (the see-through preview), or null for wood.
func _model(kind: String, parent: Node3D, mat: StandardMaterial3D) -> void:
	var half := SCAFFOLD / 2.0
	match kind:
		"scaffold":
			for x: float in [-half.x + 0.06, half.x - 0.06]:
				for z: float in [-half.z + 0.06, half.z - 0.06]:
					_box(parent, Vector3(0.1, SCAFFOLD.y, 0.1), Vector3(x, half.y, z), 0.0, 0.0, STEEL, mat)
			for side in 4: # a diagonal brace on each face, and a rail around the middle
				var turn := side * PI / 2.0
				var out := Vector3(0, 0, half.z - 0.06).rotated(Vector3.UP, turn)
				_box(parent, Vector3(SCAFFOLD.x * 1.15, 0.07, 0.05), out + Vector3(0, half.y, 0), turn, 0.85, STEEL, mat)
				_box(parent, Vector3(SCAFFOLD.x, 0.06, 0.05), out + Vector3(0, half.y, 0), turn, 0.0, STEEL, mat)
			for i in 6: # boards across the top
				var z := -half.z + SCAFFOLD.z * (i + 0.5) / 6.0
				_box(parent, Vector3(SCAFFOLD.x, 0.06, SCAFFOLD.z / 6.0 - 0.03), Vector3(0, SCAFFOLD.y - 0.03, z), 0.0, 0.0, WOOD, mat)
		"guard_post":
			_box(parent, Vector3(SCAFFOLD.x, 0.05, SCAFFOLD.z), Vector3(0, 0.025, 0), 0.0, 0.0, WOOD, mat) # floor
			for x: float in [-half.x + 0.07, half.x - 0.07]:
				for z: float in [-half.z + 0.07, half.z - 0.07]:
					_box(parent, Vector3(0.12, POST_HEIGHT, 0.12), Vector3(x, POST_HEIGHT / 2.0, z), 0.0, 0.0, WOOD_DARK, mat)
			for rail in _rails():
				_box(parent, rail["size"], rail["pos"], 0.0, 0.0, PLYWOOD, mat)
			_box(parent, Vector3(SCAFFOLD.x + 0.4, 0.1, SCAFFOLD.z + 0.4), Vector3(0, POST_HEIGHT, 0), 0.0, 0.0, WOOD_DARK, mat) # roof
		"fence":
			for x: float in [-FENCE.x / 2.0, FENCE.x / 2.0]:
				_box(parent, Vector3(0.14, FENCE.y + 0.1, 0.14), Vector3(x, (FENCE.y + 0.1) / 2.0, 0), 0.0, 0.0, WOOD_DARK, mat)
			_box(parent, Vector3(FENCE.x, FENCE.y, 0.06), Vector3(0, FENCE.y / 2.0, 0), 0.0, 0.0, PLYWOOD, mat)
		"fence_gate":
			for x: float in [-FENCE.x / 2.0, FENCE.x / 2.0]:
				_box(parent, Vector3(0.16, FENCE.y + 0.2, 0.16), Vector3(x, (FENCE.y + 0.2) / 2.0, 0), 0.0, 0.0, WOOD_DARK, mat)
		"garden_plot": # a raised bed of soil with rows of something growing
			var g := GARDEN / 2.0
			for z: float in [-g.z, g.z]:
				_box(parent, Vector3(GARDEN.x, GARDEN.y, 0.08), Vector3(0, g.y, z), 0.0, 0.0, WOOD, mat)
			for x: float in [-g.x, g.x]:
				_box(parent, Vector3(0.08, GARDEN.y, GARDEN.z), Vector3(x, g.y, 0), 0.0, 0.0, WOOD, mat)
			_box(parent, Vector3(GARDEN.x - 0.1, 0.05, GARDEN.z - 0.1), Vector3(0, GARDEN.y - 0.06, 0), 0.0, 0.0, SOIL, mat)
			for row in 3:
				for k in 6:
					var at := Vector3(-g.x + 0.3 + k * (GARDEN.x - 0.6) / 5.0, GARDEN.y + 0.08, -g.z + 0.45 + row * 0.55)
					_box(parent, Vector3(0.22, 0.18, 0.22), at, k * 0.7, 0.0, LEAVES, mat)
		"ammo_bench", "shell_bench", "rifle_bench": # a heavy workbench with a press and a vise
			var b := BENCH / 2.0
			for x: float in [-b.x + 0.08, b.x - 0.08]:
				for z: float in [-b.z + 0.08, b.z - 0.08]:
					_box(parent, Vector3(0.08, BENCH.y - 0.08, 0.08), Vector3(x, (BENCH.y - 0.08) / 2.0, z), 0.0, 0.0, WOOD_DARK, mat)
			_box(parent, Vector3(BENCH.x, 0.08, BENCH.z), Vector3(0, BENCH.y - 0.04, 0), 0.0, 0.0, WOOD, mat)
			_box(parent, Vector3(BENCH.x - 0.2, 0.05, BENCH.z - 0.15), Vector3(0, 0.25, 0), 0.0, 0.0, WOOD_DARK, mat) # shelf
			_box(parent, Vector3(0.2, 0.55, 0.2), Vector3(-0.55, BENCH.y + 0.27, -0.15), 0.0, 0.0, STEEL, mat) # reloading press
			_box(parent, Vector3(0.08, 0.3, 0.45), Vector3(-0.55, BENCH.y + 0.5, 0.05), 0.0, 0.0, STEEL, mat) # its lever
			_box(parent, Vector3(0.25, 0.15, 0.18), Vector3(0.6, BENCH.y + 0.08, 0.1), 0.0, 0.0, STEEL, mat) # vise
			_box(parent, Vector3(0.3, 0.1, 0.2), Vector3(0.1, BENCH.y + 0.05, -0.1), 0.3, 0.0, BENCHES[kind], mat) # rounds


## The guard post's railing: three full sides and two short pieces either side of
## the gap on +z.
func _rails() -> Array:
	var half := SCAFFOLD / 2.0
	var y := RAIL_HEIGHT / 2.0
	var short := (SCAFFOLD.x - POST_GAP) / 2.0
	return [
		{"size": Vector3(SCAFFOLD.x, RAIL_HEIGHT, 0.05), "pos": Vector3(0, y, -half.z + 0.03)},
		{"size": Vector3(0.05, RAIL_HEIGHT, SCAFFOLD.z), "pos": Vector3(-half.x + 0.03, y, 0)},
		{"size": Vector3(0.05, RAIL_HEIGHT, SCAFFOLD.z), "pos": Vector3(half.x - 0.03, y, 0)},
		{"size": Vector3(short, RAIL_HEIGHT, 0.05), "pos": Vector3(-half.x + short / 2.0, y, half.z - 0.03)},
		{"size": Vector3(short, RAIL_HEIGHT, 0.05), "pos": Vector3(half.x - short / 2.0, y, half.z - 0.03)},
	]


func _collision(kind: String, piece: StructurePiece) -> void:
	match kind:
		"scaffold": # solid: you stand on top, zombies go round
			_shape(piece, SCAFFOLD, Vector3(0, SCAFFOLD.y / 2.0, 0))
		"guard_post": # the railing, the corner posts and the roof (the floor is whatever's under it)
			for rail in _rails():
				_shape(piece, rail["size"], rail["pos"])
			var half := SCAFFOLD / 2.0
			for x: float in [-half.x + 0.07, half.x - 0.07]:
				for z: float in [-half.z + 0.07, half.z - 0.07]:
					_shape(piece, Vector3(0.12, POST_HEIGHT, 0.12), Vector3(x, POST_HEIGHT / 2.0, z))
			_shape(piece, Vector3(SCAFFOLD.x + 0.4, 0.1, SCAFFOLD.z + 0.4), Vector3(0, POST_HEIGHT, 0))
		"fence":
			_shape(piece, FENCE, Vector3(0, FENCE.y / 2.0, 0))
		"fence_gate":
			for x: float in [-FENCE.x / 2.0, FENCE.x / 2.0]:
				_shape(piece, Vector3(0.16, FENCE.y + 0.2, 0.16), Vector3(x, (FENCE.y + 0.2) / 2.0, 0))
		"garden_plot":
			_shape(piece, GARDEN, Vector3(0, GARDEN.y / 2.0, 0))
		"ammo_bench", "shell_bench", "rifle_bench":
			_shape(piece, BENCH, Vector3(0, BENCH.y / 2.0, 0))


## The gate's leaf: hinged on the -x post, swings open toward +z.
func _add_leaf(piece: StructurePiece) -> void:
	var leaf := GateLeaf.new()
	leaf.piece = piece
	leaf.position = Vector3(-FENCE.x / 2.0 + 0.08, 0, 0)
	piece.add_child(leaf)
	piece.leaf = leaf
	_leaf_model(leaf, null, false)
	_shape(leaf, Vector3(FENCE.x - 0.2, FENCE.y - 0.15, 0.1), Vector3(FENCE.x / 2.0 - 0.08, FENCE.y / 2.0 + 0.05, 0))


## The leaf's boards, centered between the posts. on_piece false: drawn on the
## leaf itself, whose origin is the hinge.
func _leaf_model(parent: Node3D, mat: StandardMaterial3D, on_piece := true) -> void:
	var offset := Vector3.ZERO if on_piece else Vector3(FENCE.x / 2.0 - 0.08, 0, 0)
	var width := FENCE.x - 0.2
	for i in 5:
		var x := -width / 2.0 + width * (i + 0.5) / 5.0
		_box(parent, Vector3(width / 5.0 - 0.04, FENCE.y - 0.15, 0.06), offset + Vector3(x, FENCE.y / 2.0 + 0.05, 0), 0.0, 0.0, WOOD, mat)
	for y: float in [0.5, FENCE.y - 0.3]:
		_box(parent, Vector3(width, 0.14, 0.08), offset + Vector3(0, y, 0.05), 0.0, 0.0, WOOD_DARK, mat)


## A ladder down the +z side of the scaffolding, from the post's floor to the
## ground, and the area you climb it in (player.gd).
func _add_ladder(post: StructurePiece, height: float) -> void:
	_ladder_model(post, height, null)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameData.LAYER_PLAYER
	area.set_meta("top_y", post.global_position.y)
	# From the ground to a little above the floor (so you can step off at the
	# top), and from the scaffolding out to arm's length.
	var reach := CLIMB_REACH + LADDER_OUT
	_shape(area, Vector3(0.9, height + 1.2, reach), Vector3(0, (1.2 - height) / 2.0, SCAFFOLD.z / 2.0 + reach / 2.0))
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("enter_ladder"):
			body.call("enter_ladder", area))
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.has_method("exit_ladder"):
			body.call("exit_ladder", area))
	post.add_child(area)
	post.ladder = area


func _ladder_model(parent: Node3D, height: float, mat: StandardMaterial3D) -> void:
	var z := SCAFFOLD.z / 2.0 + LADDER_OUT
	for x: float in [-0.25, 0.25]:
		_box(parent, Vector3(0.06, height + 1.0, 0.06), Vector3(x, (1.0 - height) / 2.0, z), 0.0, 0.0, WOOD_DARK, mat)
	var rungs := int(height / 0.3)
	for i in rungs:
		_box(parent, Vector3(0.5, 0.04, 0.05), Vector3(0, -height + 0.3 * (i + 1), z), 0.0, 0.0, WOOD, mat)


func _box(parent: Node3D, size: Vector3, pos: Vector3, yaw: float, roll: float, color: Color, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat if mat else _wood(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation = Vector3(0, yaw, roll)
	parent.add_child(inst)


func _shape(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)


func _wood(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_materials[color] = mat
	return _materials[color]
