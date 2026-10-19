@tool
class_name MineCage
extends AnimatableBody3D
## A mine's cage elevator, in a cage shaft (MineShaft, kind Cage): a steel
## cage that carries whoever's in it, zombies too, between the stops (the
## shaft's bottom, the levels tunnels come in on, and the surface if it comes
## out there). It needs power: a running generator anywhere in the mine
## (world/map/mine_generator.gd). Pull the lever inside to go on to the next
## stop; the call button by each stop's gate brings it there. A stop's gates
## are shut unless the cage is at it, so nobody walks into the empty shaft.
## Moving, it clanks: zombies near it hear.
## KitMine builds it; main.gd keeps it (and its gates) out of the navigation
## bake, as it does doors.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")
const SPEED := 1.6 # meters a second
const HEIGHT := 2.6
const NOISE := 20.0
const STEEL := preload("res://world/kit/materials/steel.tres")
const IRON := Color(0.18, 0.18, 0.19)

var mine: Node # the KitMine (its generators power this)
var stops: Array[float] = [] # the stops' floors, in the mine's space, low to high
var at := 0 # the stop it's at, or heading for
var gates: Array = [] # per stop: [StaticBody3D]
var _moving := false
var _going_up := true
var _offset := 0.0 # the mine's height in the map (set once it's placed)
var _noise_wait := 0.0
static var _moving_count := 0 # cages on the move (zombies keep stepping meanwhile: zombie.gd)


## Builds the cage, `width` across, with bars on the sides no tunnel comes in by.
func build(width: float, barred: Array) -> void:
	sync_to_physics = true
	collision_layer = GameData.LAYER_WORLD
	var km := KitMesh.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	km.box(Vector3(width, 0.1, width), Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0)), KitMesh.all(STEEL)) # floor
	km.box(Vector3(width, 0.08, width), Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, 0)), KitMesh.all(iron)) # roof
	var half := width / 2.0 - 0.04
	for x: float in [-half, half]:
		for z: float in [-half, half]:
			km.box(Vector3(0.08, HEIGHT, 0.08), Transform3D(Basis.IDENTITY, Vector3(x, HEIGHT / 2.0, z)), KitMesh.all(iron))
	for side: Vector2i in barred:
		var out := Vector3(side.x, 0, side.y) * half
		var along := Vector3(absi(side.y), 0, absi(side.x))
		for i in 7: # bars
			var t := -half + (i + 1) * width / 8.0
			km.box(Vector3(0.03, HEIGHT, 0.03), Transform3D(Basis.IDENTITY, out + along * t + Vector3(0, HEIGHT / 2.0, 0)), KitMesh.all(iron), false)
		km.box(along * width + Vector3(absi(side.x), 0, absi(side.y)) * 0.06 + Vector3(0, HEIGHT, 0),
				Transform3D(Basis.IDENTITY, out + Vector3(0, HEIGHT / 2.0, 0)), [null, null, null, null, null, null]) # (solid)
	for node in km.add_to(self):
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
	# The lever, by a corner post.
	var lever := MineControl.new()
	lever.name = "Lever"
	lever.collision_layer = GameData.LAYER_ITEMS # (found by interact's ray; nobody bumps into it)
	lever.collision_mask = 0
	var lk := KitMesh.new()
	lk.box(Vector3(0.12, 0.9, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), KitMesh.all(iron))
	lk.box(Vector3(0.05, 0.45, 0.05), Transform3D(Basis.from_euler(Vector3(0.5, 0, 0)), Vector3(0, 1.05, 0.08)), KitMesh.all(STEEL))
	for node in lk.add_to(lever):
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
	lever.position = Vector3(half - 0.2, 0, half - 0.2)
	lever.prompt = _lever_prompt
	lever.action = func(player: Node) -> void: _send(_next(), player)
	add_child(lever)


func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint())
	_offset = global_position.y - stops[at]
	_open_gates()


func powered() -> bool:
	if not is_instance_valid(mine):
		return false
	for generator in mine.find_children("*", "MineGenerator", true, false):
		if (generator as MineGenerator).running():
			return true
	return false


## The stop the lever sends it to: on the way it was going, turning at the ends.
func _next() -> int:
	if stops.size() < 2:
		return at
	var up := _going_up
	if at >= stops.size() - 1:
		up = false
	elif at <= 0:
		up = true
	return at + (1 if up else -1)


func _lever_prompt() -> String:
	if _moving:
		return ""
	var to := _next()
	var way := "up" if to > at else "down"
	return "pull the lever: %s to %s" % [way, _stop_name(to)] if powered() else "pull the lever (no power)"


func _stop_name(i: int) -> String:
	return "the top" if i == stops.size() - 1 else "the bottom" if i == 0 else "level %d" % roundi(stops[i] / 4.0)


## A call button's words, for stop i.
func call_prompt(i: int) -> String:
	if at == i and not _moving:
		return ""
	return "call the cage" if powered() else "call the cage (no power)"


## Sends it to stop i (a lever or a call button). player: who's told if there's no power.
func _send(i: int, player: Node = null) -> void:
	if _moving or i == at:
		return
	if not powered():
		if player:
			player.emit_signal("notify", "Nothing happens. It needs power: a generator running somewhere in the mine.")
		return
	_going_up = i > at
	_close_gates(at)
	at = i
	_set_moving(true)
	Sound.play_at(self, "gate_slide", global_position + Vector3.UP, 0.0, 25.0)


func go_to(i: int, player: Node = null) -> void:
	_send(i, player)


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var target := stops[at] + _offset
	global_position.y = move_toward(global_position.y, target, SPEED * delta)
	_noise_wait -= delta
	if _noise_wait <= 0.0:
		_noise_wait = 1.5
		get_tree().call_group("noise_listeners", "hear_noise", global_position, NOISE)
		Sound.play_at(self, "cage_move", global_position + Vector3.UP, -2.0, 30.0)
	if is_equal_approx(global_position.y, target):
		_set_moving(false)
		_open_gates()
		Sound.play_at(self, "gate_slide", global_position + Vector3.UP, 0.0, 25.0)


func _open_gates() -> void:
	for i in gates.size():
		for gate: StaticBody3D in gates[i]:
			_set_gate(gate, i == at and not _moving)


func _close_gates(i: int) -> void:
	for gate: StaticBody3D in gates[i]:
		_set_gate(gate, false)


## An open gate lets bodies through and is slid up out of the way.
static func _set_gate(gate: StaticBody3D, open: bool) -> void:
	gate.collision_layer = 0 if open else GameData.LAYER_WORLD
	for child in gate.get_children(true):
		if child is MeshInstance3D:
			(child as MeshInstance3D).position.y = 1.9 if open else 0.0


## Whether any cage is moving: someone standing still in it has to keep stepping to ride along.
static func any_moving() -> bool:
	return _moving_count > 0


func _set_moving(on: bool) -> void:
	if on != _moving:
		_moving_count += 1 if on else -1
	_moving = on


func _exit_tree() -> void:
	_set_moving(false)


func save_state() -> Dictionary:
	return {"at": at}


func load_state(data: Dictionary) -> void:
	at = clampi(int(data.get("at", at)), 0, stops.size() - 1)
	_set_moving(false)
	global_position.y = stops[at] + _offset
	_open_gates()
