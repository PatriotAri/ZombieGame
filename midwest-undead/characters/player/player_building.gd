extends RefCounted
## What the player fortifies, builds and salvages (player.gd keeps one: its
## `building`, and passes it what's in your hands and where you're looking):
##   - planks board up the door or window you aim at, or mend a fence or gate;
##     sheet metal plates one; a barricade goes down a couple of meters ahead,
##     with a see-through preview (world/fortifications.gd);
##   - a building piece (scaffolding, guard posts, fences...) shows where it
##     would go, and goes there (world/structures.gd);
##   - holding interact with the crowbar strips something for materials
##     (world/salvage.gd), and with the pickaxe digs through a cave-in.

const Player := preload("res://characters/player/player.gd")
const GameData := preload("res://core/game_data.gd")
const Controls := preload("res://core/controls.gd")
const Sound := preload("res://core/sound.gd")
const StructurePiece := preload("res://world/structure_piece.gd")
const Fortifications := preload("res://world/fortifications.gd")
const SALVAGE_TAP := 0.3 # let go sooner than this and it's an ordinary interact

var p: Player
var fortifications: Node # world/fortifications.gd, found through its group
var structures: Node # world/structures.gd, found through its group
var salvage: Node # world/salvage.gd, found through its group
var build_view := {} # where the held piece would go this frame (structures.preview), or empty
var salvage_target: Node3D = null # what you're holding interact on with the crowbar (or the pickaxe)
var salvage_held := 0.0
var _salvage_sound_wait := 0.0
var _barricade_ghost: MeshInstance3D # where a held barricade would go
var _ghost_material: StandardMaterial3D
var _barricade_spot := Transform3D() # where it'd go, and whether it fits there (_barricade_fits)
var _barricade_ok := false
var _barricade_frame := -1


func _init(player: Player) -> void:
	p = player


## Holding interact on target (the crowbar can strip it, or the pickaxe dig it):
## a tap still opens it; holding strips it or digs (update_salvage).
func start_salvage(target: Node3D) -> void:
	salvage_target = target
	salvage_held = 0.0


## The prompt's salvaging or digging part for target, added to `prompt`.
## key: the interact button's name.
func salvage_prompt(target: Node3D, key: String, prompt: String) -> String:
	# With the pickaxe, a cave-in says how far through it you are.
	if p._can_dig(target):
		var done: float = target.call("dug")
		prompt = "Digging...  %d%%" % roundi(100.0 * done) if salvage_target == target and salvage_held >= SALVAGE_TAP \
				else "Hold %s: dig through the cave-in%s" % [key, "  (%d%% done)" % roundi(100.0 * done) if done > 0.0 else ""]
	# With the crowbar, things you can strip for materials say so.
	var got := salvage_yield(target) if p._can_salvage() else []
	if not got.is_empty():
		if salvage_target == target and salvage_held >= SALVAGE_TAP:
			prompt = "Salvaging...  %d%%" % roundi(100.0 * salvage_held / float(salvage.get("TIME")))
		else:
			var line := "Hold %s: salvage %d %s" % [key, got[1], GameData.item_name(got[0]).to_lower()]
			prompt = line if prompt == "" else prompt + "   ·   " + line
	return prompt


# --- Fortifying (planks and barricades; see world/fortifications.gd) ---------------

func _fortifications() -> Node:
	if fortifications == null:
		fortifications = p.get_tree().get_first_node_in_group("fortifications")
	return fortifications


## The door or window you're aiming at (index into fortifications.openings), or -1.
## The first thing the ray hits must be the opening itself, not a wall in front of it.
func _aimed_opening() -> int:
	var fort := _fortifications()
	if fort == null:
		return -1
	var origin := p.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - p.camera.global_basis.z * (p.INTERACT_RANGE + 0.5),
			GameData.LAYER_WORLD | GameData.LAYER_GLASS | GameData.LAYER_OPENINGS)
	query.collide_with_areas = true
	var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
	return fort.opening_of(hit["collider"]) if not hit.is_empty() else -1


## Where a held barricade would stand: a couple of meters ahead, on the ground,
## facing you.
func barricade_transform() -> Transform3D:
	var forward := -p.global_basis.z
	forward.y = 0.0
	var spot := p.global_position + forward.normalized() * 2.2
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 3.0, GameData.LAYER_WORLD)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spot.y = (hit["position"] as Vector3).y
	return Transform3D(Basis(Vector3.UP, p.rotation.y), spot)


## Whether a held barricade fits where it'd go (that's _barricade_spot):
## worked out once a physics frame, for the prompt and the preview.
func _barricade_fits() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _barricade_frame:
		_barricade_frame = frame
		_barricade_spot = barricade_transform()
		var fort := _fortifications()
		_barricade_ok = fort != null and fort.can_place_barricade(_barricade_spot)
	return _barricade_ok


func fortify_prompt() -> String:
	var fort := _fortifications()
	if fort == null:
		return ""
	var key := Controls.hint("use_held")
	var use := GameData.item_use(p.held)
	var piece := _aimed_piece() if use == "board" or use == "plate" else null
	if use == "board" and piece and piece.is_damaged():
		return "%s: repair the %s" % [key, GameData.item_name(piece.kind).to_lower()]
	if use == "plate" and piece and not piece.broken:
		if piece.plated:
			return "Already plated"
		var sheets: int = StructurePiece.SHEETS[piece.kind]
		if p.inventory.count("sheet_metal") < sheets:
			return "Plating the %s takes %d sheet metal" % [GameData.item_name(piece.kind).to_lower(), sheets]
		return "%s: plate the %s (%d sheet metal)" % [key, GameData.item_name(piece.kind).to_lower(), sheets]
	if use == "board":
		var index := _aimed_opening()
		if index >= 0 and not fort.is_boarded(index):
			return "%s: board up the %s" % [key, fort.describe(index)]
	elif p.held == "barricade":
		return "%s: place barricade" % key if _barricade_fits() else "No room for a barricade here"
	elif not build_view.is_empty():
		return ("%s: %s" % [key, build_view["text"]]) if build_view["ok"] else build_view["text"]
	return ""


## The fence or gate you built that you're looking at (structure_piece.gd), or null.
func _aimed_piece() -> StructurePiece:
	var target := p._looked_at()
	if target != null and target.get("piece") != null: # a gate's leaf
		target = target.get("piece")
	var piece := target as StructurePiece
	return piece if piece != null and piece.is_breakable() else null


## Holding sheet metal: cover the fence or gate you're looking at (structures.gd).
func try_plate() -> void:
	var piece := _aimed_piece()
	if piece == null or piece.broken:
		p.notify.emit("Aim at a fence or gate you built to plate it.")
		return
	if piece.plated:
		p.notify.emit("That's already plated.")
		return
	var sheets: int = StructurePiece.SHEETS[piece.kind]
	if p.inventory.count("sheet_metal") < sheets:
		p.notify.emit("That takes %d sheet metal." % sheets)
		return
	p.take_item("sheet_metal", sheets)
	_structures().call("plate", piece)
	p.attack_cooldown = 0.6


## Holding planks: mend the fence or gate you're looking at, or board up the door or window.
func try_board() -> void:
	var piece := _aimed_piece()
	if piece and piece.is_damaged(): # planks mend a damaged fence or gate
		_structures().call("repair", piece)
		p.take_item(p.held)
		p.attack_cooldown = 0.6
		return
	var fort := _fortifications()
	var index := _aimed_opening()
	if fort == null or index < 0:
		p.notify.emit("Aim at a door or window to board it up.")
	elif fort.is_boarded(index):
		p.notify.emit("That's already boarded up.")
	else:
		fort.board(index, false, p.held == "used_planks")
		p.take_item(p.held)
		p.attack_cooldown = 0.6


func try_barricade() -> void:
	var fort := _fortifications()
	var xform := barricade_transform()
	if fort == null or not fort.can_place_barricade(xform):
		p.notify.emit("No room for a barricade there.")
		return
	fort.place_barricade(xform)
	p.take_item("barricade")
	p.attack_cooldown = 0.6


## A see-through preview of the barricade while you hold one: green where it fits,
## red where it doesn't.
func update_barricade_ghost() -> void:
	var fort := _fortifications()
	var show := p.held == "barricade" and not p.is_dead and not p.menu_open and fort != null
	if _barricade_ghost == null:
		if not show:
			return
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var box := BoxMesh.new()
		box.size = Fortifications.BARRICADE_SIZE
		box.material = _ghost_material
		_barricade_ghost = MeshInstance3D.new()
		_barricade_ghost.mesh = box
		_barricade_ghost.top_level = true # placed in world space, not following the camera's tilt
		_barricade_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(_barricade_ghost)
	_barricade_ghost.visible = show
	if show:
		var ok := _barricade_fits()
		_barricade_ghost.global_transform = _barricade_spot * Transform3D(Basis.IDENTITY, Vector3(0, Fortifications.BARRICADE_SIZE.y / 2.0, 0))
		_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.35)


# --- Building (scaffolding, guard posts, fences; see world/structures.gd) ----------

func _structures() -> Node:
	if structures == null:
		structures = p.get_tree().get_first_node_in_group("structures")
	return structures


## Where the piece you're holding would go, and its see-through preview.
func update_build_view() -> void:
	var builder := _structures()
	if builder == null:
		return
	if p.is_dead or p.menu_open or GameData.item_use(p.held) != "build":
		build_view = {}
		builder.call("show_ghost", "", {})
		return
	var skip: Array[RID] = [p.get_rid()]
	build_view = builder.call("preview", p.held, p.camera.global_position, -p.camera.global_basis.z, p.global_position, skip)
	builder.call("show_ghost", p.held, build_view)


func try_build() -> void:
	if build_view.is_empty() or p.attack_cooldown > 0.0:
		return
	if not build_view["ok"]:
		p.notify.emit(build_view["text"] + ".")
		return
	_structures().call("build", p.held, build_view["xform"], build_view["on"])
	p.take_item(p.held)
	p.attack_cooldown = 0.6
	update_build_view()


# --- Salvaging (world/salvage.gd) and digging (world/map/mine_cave_in.gd) ------------

## [item, amount] that thing would give you, or [].
func salvage_yield(thing: Node3D) -> Array:
	if salvage == null:
		salvage = p.get_tree().get_first_node_in_group("salvage")
	if salvage == null or thing == null:
		return []
	return salvage.call("yield_of", thing)


## Holding interact on something with the crowbar (a weapon that salvages):
## strip it once the bar fills.
## Let go early and it was just a press (open it as usual).
func update_salvage(delta: float) -> void:
	if salvage_target == null:
		return
	if not is_instance_valid(salvage_target) or not (p._can_salvage() or p._can_dig(salvage_target)) \
			or p._looked_at() != salvage_target:
		salvage_target = null # looked away or switched hands: cancelled
		return
	if not Input.is_action_pressed("interact"):
		if salvage_held < SALVAGE_TAP:
			p._interact()
		salvage_target = null
		return
	salvage_held += delta
	_salvage_sound_wait -= delta
	if salvage_held >= SALVAGE_TAP and _salvage_sound_wait <= 0.0:
		_salvage_sound_wait = 0.6
		if salvage == null: # (digging with the pickaxe: not looked up yet)
			salvage = p.get_tree().get_first_node_in_group("salvage")
		Sound.play_ui(p, "melee_hit", -6.0, 0.2) # prying and banging
		p.make_noise(float(salvage.get("NOISE")))
	if p._can_dig(salvage_target):
		# The cave-in keeps count: let go and come back, and you carry on where you were.
		if salvage_held >= SALVAGE_TAP and salvage_target.call("dig", delta):
			salvage_target = null
			p.notify.emit("You dig your way through.")
		return
	if salvage_held >= float(salvage.get("TIME")):
		var got: Array = salvage.call("strip", salvage_target)
		salvage_target = null
		if not got.is_empty():
			p.give_item(got[0], got[1])
			p.notify.emit("Salvaged %d %s." % [got[1], GameData.item_name(got[0]).to_lower()])
