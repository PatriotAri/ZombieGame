extends Node
## Building: scaffolding, guard posts, fences, fence gates, garden plots, ammo
## benches and camp kits (made by the woodworker and the machinist), and
## lanterns (found in mines: set down, not built). They go anywhere on the
## map. Hold one and press use:
##   - Looking at the ground, it goes there, facing you.
##   - Looking at scaffolding you built, scaffolding or a guard post snaps on top
##     of it. A guard post on top makes it a guard tower: a ladder runs down the
##     side facing you (walk into it to climb; player.gd). A guard post on the
##     ground is just a guard post.
##   - Looking at a fence or gate you built, a fence or gate lines up at its
##     nearer end, to run a wall along.
##   - A camp kit sets up a new base camp (world/camp_site.gd, world/camps.gd):
##     on the ground, at least camps.RANGE from every other camp.
## A see-through copy shows where it'll go before you place it: green if it fits,
## red if it doesn't (player.gd draws it with show_ghost()).
## Fences and fence gates can be broken (structure_piece.gd): zombies bash them
## like doors, they darken as they're hit, planks repair them, sheet metal
## (from the machinist) plates them so nothing breaks them, and a broken one is
## a wreck you can walk through and take down for some materials. Everything
## else has no health and can't be broken. Placing, taking down, opening a
## gate, or one breaking re-bakes the navigation mesh (shared with
## fortifications.gd, so only one bake runs at a time).
## Saved: every piece, what it stands on, whether gates are open, and each
## fence's or gate's health, plating and whether it's broken.
## How each looks is a prop scene in world/props/ (PROPS and the ones below it):
## set Models on one to swap in a model (HOW_TO_MODEL.md, "Props"). A model's
## own collision shapes are used; without any, the boxes in _collision().
## Pressing interact on a piece takes it down (on a gate's leaf, opens or shuts
## it); on a camp kit, main.gd packs up the camp (camp_take_down_requested).

## You pressed interact on a camp kit: main.gd packs up the camp.
signal camp_take_down_requested(piece: StructurePiece)

const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")
const StructurePiece := preload("res://world/structure_piece.gd")
const GateLeaf := preload("res://world/gate_leaf.gd")
const CampSite := preload("res://world/camp_site.gd")
const Ground := preload("res://world/ground.gd")
const ClimbArea := preload("res://world/climb_area.gd")
const Player := preload("res://characters/player/player.gd")

const KINDS := ["scaffold", "guard_post", "fence", "fence_gate", "garden_plot", "ammo_bench", "shell_bench", "rifle_bench", "camp_kit", "lantern"]
## A lantern is set down, not built: no hammering, and it's too small to change
## zombies' paths. Held, it lights all round you (player.gd).
const LANTERN := Vector3(0.24, 0.42, 0.24)
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
## The stand-ins' colors (world/props/make_props.gd).
const WOOD := Color(0.58, 0.45, 0.28)
const WOOD_DARK := Color(0.4, 0.3, 0.19)
const STEEL := Color(0.42, 0.43, 0.45)
const PLYWOOD := Color(0.55, 0.45, 0.3)
const METAL := Color(0.5, 0.52, 0.55)
const DARKEN_STEPS := 8 # damage shows in this many shades (each a shared material)
## Planks back from taking down a wreck: [item, how many]. A gate's hinges are scrap.
const WRECK_ITEMS := {"fence": {"used_planks": 2}, "fence_gate": {"used_planks": 2, "scrap_metal": 1}}
## Health one plank puts back (a third of a fence).
const PLANK_REPAIR := 2500.0
const PROPS := {
	"scaffold": preload("res://world/props/scaffold.tscn"),
	"guard_post": preload("res://world/props/guard_post.tscn"),
	"fence": preload("res://world/props/fence.tscn"),
	"fence_gate": preload("res://world/props/gate_posts.tscn"),
	"garden_plot": preload("res://world/props/garden_plot.tscn"),
	"ammo_bench": preload("res://world/props/ammo_bench.tscn"),
	"shell_bench": preload("res://world/props/shell_bench.tscn"),
	"rifle_bench": preload("res://world/props/rifle_bench.tscn"),
	"lantern": preload("res://world/props/lantern.tscn"),
}
const GATE_LEAF := preload("res://world/props/gate_leaf.tscn")
const FENCE_PLATING := preload("res://world/props/fence_plating.tscn")
const GATE_PLATING := preload("res://world/props/gate_plating.tscn")
const WRECK := preload("res://world/props/fence_wreck.tscn")
const LADDER := preload("res://world/props/ladder.tscn")

var pieces: Array[StructurePiece] = []
var _nav_region: Node3D # world/nav_tiles.gd: pieces go under it, so the navigation bake sees them
var _fortifications: Node # owns the shared navigation re-bake
var camps: Node # world/camps.gd, set by main.gd (camps keep their distance)
var _ghost: Node3D
var _ghost_key := "" # what the ghost currently shows, so it's only rebuilt when that changes
var _ghost_material: StandardMaterial3D
var _room_query: PhysicsShapeQueryParameters3D # _room()'s, made once (its box resized each time)


func _ready() -> void:
	add_to_group("structures")


func setup(nav_region: Node3D, fortifications: Node) -> void:
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
	if kind == "camp_kit" and result["ok"] and camps:
		var problem: String = camps.call("placement_problem", (result["xform"] as Transform3D).origin)
		if problem == "" and _too_steep(result["xform"]):
			problem = "Too steep for a camp"
		if problem != "":
			result["ok"] = false
			result["text"] = problem
		else:
			result["text"] = "set up a new base camp"
	return result


func _where(kind: String, origin: Vector3, dir: Vector3, viewer: Vector3, exclude: Array[RID]) -> Dictionary:
	var result := {"ok": false, "xform": Transform3D(), "on": null, "ladder": 0.0, "text": ""}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * BUILD_RANGE, GameData.LAYER_WORLD, exclude)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	var label := GameData.item_name(kind).to_lower()
	if hit.is_empty():
		result["text"] = "Look at the ground to build"
		return result
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
		result["text"] = "Can't build on that"
		return result
	if (hit["normal"] as Vector3).y < 0.8:
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
	var verb := "set down the " if kind == "lantern" else "build the "
	result["text"] = (verb + label) if result["ok"] else "No room for the " + label
	return result


## A camp's corners more than 0.8 m apart in height: too steep to set up on.
func _too_steep(xform: Transform3D) -> bool:
	var half := CampSite.SIZE / 2.0
	var low := INF
	var high := -INF
	for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
		var h := Ground.height_at(xform * corner)
		if is_nan(h):
			continue
		low = minf(low, h)
		high = maxf(high, h)
	return high - low > 0.8


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
	if _room_query == null: # (asked every frame while you hold a piece: made once)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = BoxShape3D.new()
		_room_query.collision_mask = GameData.LAYER_WORLD | GameData.LAYER_GLASS | GameData.LAYER_PLAYER \
				| GameData.LAYER_ZOMBIES | GameData.LAYER_NPC
	var shape := _room_query.shape as BoxShape3D
	# A little smaller than the piece, and lifted off what it stands on, so
	# touching the ground, a curb or its neighbor doesn't count.
	shape.size = Vector3(size.x - 0.3, size.y - 0.25, maxf(size.z - 0.3, 0.1))
	# A camp is big: lifted clear of the bumps in the ground under it (how
	# level it has to be is checked separately: _too_steep).
	var lift := 0.7 if kind == "camp_kit" else 0.15
	_room_query.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0, lift + shape.size.y / 2.0, 0))
	_room_query.exclude = exclude
	return get_viewport().get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


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
		"camp_kit":
			return CampSite.SIZE
		"lantern":
			return LANTERN + Vector3(0.3, 0.25, 0.3) # (_room shrinks it by that)
	return FENCE


# --- Building and taking down -------------------------------------------------

## Builds what preview() said. quiet: loading a save (no sound, no re-bake).
func build(kind: String, xform: Transform3D, on: StructurePiece, quiet := false) -> StructurePiece:
	var piece := StructurePiece.new()
	piece.kind = kind
	piece.structures = self
	piece.transform = xform
	if on:
		piece.below = on
		on.above = piece
	_nav_region.add_child(piece) # in the bake: zombies path around it
	Interactable.of(piece).interacted.connect(_on_piece_interacted.bind(piece))
	if not _model(kind, piece, null).take_shapes(piece):
		_collision(kind, piece)
	if KitMine.contains(piece.global_position + Vector3.UP * 0.3):
		KitMine.underground(piece) # down a mine: out of the sun's light, like the mine
	pieces.append(piece)
	if kind == "fence_gate":
		_add_leaf(piece)
	if kind == "guard_post" and on:
		_add_ladder(piece, _ground_height(on, xform.origin.y))
	if not quiet and kind != "lantern":
		Sound.play_at(piece, "hammer", piece.global_position + Vector3.UP, 0.0, 30.0)
		_fortifications.call("rebake", piece.global_position)
	return piece


func _on_piece_interacted(actor: Node3D, piece: StructurePiece) -> void:
	if piece.kind == "camp_kit":
		camp_take_down_requested.emit(piece)
		return
	var player := actor as Player
	if player == null:
		return
	var back := take_down(piece)
	if back.is_empty():
		player.notify.emit("Take down what's on top of it first.")
	for id: String in back:
		player.give_item(id, back[id])


## Takes a piece down. Returns what to give back ({item: how many}): the piece,
## with its sheet metal if it was plated, or a wreck's planks. Empty if
## something on top of it has to come down first.
func take_down(piece: StructurePiece) -> Dictionary:
	if piece.above != null:
		return {}
	if piece.below:
		piece.below.above = null
	pieces.erase(piece)
	if piece.ladder:
		_let_go(piece.ladder)
	var at := piece.global_position
	var lantern := piece.kind == "lantern"
	if not lantern:
		Sound.play_at(piece, "hammer", at + Vector3.UP, -3.0, 25.0)
	piece.get_parent().remove_child(piece) # gone before the re-bake reads the scene
	piece.queue_free()
	if not lantern:
		_fortifications.call("rebake", at)
	if piece.broken:
		return WRECK_ITEMS[piece.kind]
	var back := {piece.kind: 1}
	if piece.plated:
		back["sheet_metal"] = StructurePiece.SHEETS[piece.kind]
	return back


# --- Damage, repair, plating ------------------------------------------------------

## A zombie hit it (structure_piece.gd's bash): darker the more it's taken, and
## a wreck once it's gone.
func damaged(piece: StructurePiece, quiet := false) -> void:
	if piece.health <= 0.0:
		_break(piece, quiet)
	else:
		_shade(piece)


## Planks put back PLANK_REPAIR health each.
func repair(piece: StructurePiece) -> void:
	piece.health = minf(piece.health + PLANK_REPAIR, StructurePiece.MAX_HEALTH)
	_shade(piece)
	Sound.play_at(piece, "hammer", piece.global_position + Vector3.UP, -2.0, 25.0)


## Covered in sheet metal: nothing breaks it from now on (and it's as good as new).
func plate(piece: StructurePiece, quiet := false) -> void:
	piece.plated = true
	piece.health = StructurePiece.MAX_HEALTH
	_shade(piece)
	if piece.kind == "fence":
		_add_prop(piece, FENCE_PLATING)
	elif piece.leaf: # the gate's leaf, so the plates swing with it
		_add_prop(piece.leaf, GATE_PLATING)
	if not quiet:
		Sound.play_at(piece, "hammer", piece.global_position + Vector3.UP, 0.0, 30.0)


## Darker the more damaged, in DARKEN_STEPS shades.
func _shade(piece: StructurePiece) -> void:
	var step := 0 if piece.plated else int((1.0 - piece.health / StructurePiece.MAX_HEALTH) * DARKEN_STEPS)
	for prop in _props(piece):
		prop.darken(0.6 * step / DARKEN_STEPS)


## Every look on a piece (its gate's leaf and plating too).
func _props(piece: Node) -> Array[KitProp]:
	var found: Array[KitProp] = []
	for node in piece.find_children("*", "Node3D", true, false):
		if node is KitProp:
			found.append(node)
	return found


## Broken: no longer stops anyone. The upright parts go, a few boards lie where
## it stood, and taking that down gives some planks back.
func _break(piece: StructurePiece, quiet := false) -> void:
	piece.broken = true
	piece.health = 0.0
	if piece.leaf:
		piece.leaf.queue_free()
		piece.leaf = null
		piece.gate_open = false
	for child in piece.get_children():
		if child is KitProp or child is CollisionShape3D or child is CollisionPolygon3D:
			piece.remove_child(child)
			child.queue_free()
	_add_prop(piece, WRECK)
	# You can still look at it (to take it down) but nothing bumps into it, and
	# the navigation bake doesn't see it (an area, not a body).
	var zone := Area3D.new()
	zone.collision_layer = GameData.LAYER_ITEMS
	zone.collision_mask = 0
	zone.set_meta("part_of_parent", true)
	_shape(zone, Vector3(FENCE.x, 0.6, 0.8), Vector3(0, 0.3, 0))
	piece.add_child(zone)
	if not quiet:
		Sound.play_at(piece, "door_break", piece.global_position + Vector3.UP, 2.0, 35.0, 0.08)
		_fortifications.call("rebake", piece.global_position)


func toggle_gate(piece: StructurePiece, quiet := false) -> void:
	piece.gate_open = not piece.gate_open
	var angle := -PI / 2.0 if piece.gate_open else 0.0
	if quiet:
		piece.leaf.rotation.y = angle
		return
	var tween := piece.create_tween()
	tween.tween_property(piece.leaf, "rotation:y", angle, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _fortifications.call("rebake", piece.global_position)) # once it's swung
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
		var entry := {"kind": piece.kind, "position": [p.x, p.y, p.z], "yaw": piece.global_rotation.y,
				"on": pieces.find(piece.below) if piece.below else -1, "open": piece.gate_open}
		if piece.is_breakable():
			entry["health"] = piece.health
			entry["plated"] = piece.plated
			entry["broken"] = piece.broken
		data.append(entry)
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
		if kind == "fence_gate" and bool(entry.get("open", false)) and not bool(entry.get("broken", false)):
			toggle_gate(piece, true)
		if piece.is_breakable():
			piece.health = float(entry.get("health", StructurePiece.MAX_HEALTH))
			if bool(entry.get("broken", false)):
				piece.health = 0.0
				damaged(piece, true)
			elif bool(entry.get("plated", false)):
				plate(piece, true)
			else:
				_shade(piece)
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
			_add_prop(_ghost, GATE_LEAF).position = Vector3(-FENCE.x / 2.0 + 0.08, 0, 0)
		if ladder > 0.0:
			_ladder_model(_ghost, ladder)
		_ghost_key = key
		for prop in _props(_ghost):
			prop.ghost(_ghost_material)
	_ghost.visible = true
	_ghost.global_transform = view["xform"]
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if view["ok"] else Color(1.0, 0.25, 0.2, 0.35)


# --- Models and collision ----------------------------------------------------------

## The look of a piece (its prop scene) on parent: origin on the ground (or the
## top of the scaffolding below) in the middle, +z toward the side you placed it
## from. mat: the see-through preview (for the camp kit: just its tents, fire
## and table), or null for the real thing. Returns the look.
func _model(kind: String, parent: Node3D, mat: StandardMaterial3D) -> KitProp:
	if kind == "camp_kit":
		var holder := KitProp.new() # the camp's props hang off this (it has no look of its own)
		parent.add_child(holder)
		if mat == null:
			CampSite.build(holder, parent as CollisionObject3D) # the real thing (with its logbook, board and crate)
		else:
			CampSite.preview(holder)
		return holder
	return _add_prop(parent, PROPS[kind])


## A prop scene's look on parent. Returns it.
func _add_prop(parent: Node3D, scene: PackedScene) -> KitProp:
	var prop := KitProp.make(scene)
	prop.name = "Look"
	parent.add_child(prop)
	return prop


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
		"lantern":
			_shape(piece, LANTERN, Vector3(0, LANTERN.y / 2.0, 0))


## The gate's leaf: hinged on the -x post, swings open toward +z.
func _add_leaf(piece: StructurePiece) -> void:
	var leaf := GateLeaf.new()
	leaf.piece = piece
	leaf.position = Vector3(-FENCE.x / 2.0 + 0.08, 0, 0)
	piece.add_child(leaf)
	piece.leaf = leaf
	Interactable.of(leaf).interacted.connect(func(_actor: Node3D) -> void: toggle_gate(piece))
	if not _add_prop(leaf, GATE_LEAF).take_shapes(leaf):
		_shape(leaf, Vector3(FENCE.x - 0.2, FENCE.y - 0.15, 0.1), Vector3(FENCE.x / 2.0 - 0.08, FENCE.y / 2.0 + 0.05, 0))


## A ladder down the +z side of the scaffolding, from the post's floor to the
## ground, and the area you climb it in (player.gd).
func _add_ladder(post: StructurePiece, height: float) -> void:
	_ladder_model(post, height)
	# From the ground to a little above the floor (so you can step off at the
	# top), and from the scaffolding out to arm's length.
	var reach := CLIMB_REACH + LADDER_OUT
	var area := ClimbArea.make(Vector3(0.9, height + 1.2, reach), Vector3(0, (1.2 - height) / 2.0, SCAFFOLD.z / 2.0 + reach / 2.0))
	area.set_meta("top_y", post.global_position.y)
	post.add_child(area)
	post.ladder = area


## The ladder's look, stretched from the ground (height below) to 1 m above the post's floor.
func _ladder_model(parent: Node3D, height: float) -> void:
	var prop := KitProp.make(LADDER, [], Vector3(0.56, height + 1.0, 0.06),
			Vector3(0, (1.0 - height) / 2.0, SCAFFOLD.z / 2.0 + LADDER_OUT))
	prop.name = "Ladder"
	parent.add_child(prop)


func _shape(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)

