@tool
class_name MineGenerator
extends StaticBody3D
## A generator that powers a mine's cages (world/map/mine_cage.gd): put one
## anywhere under a KitMine (Map Tools: Mines > Place generator). Pour a gas
## can in (interact) and it runs for a game hour (more cans, more hours, up to
## MAX_HOURS). While it runs it's loud: zombies within NOISE meters hear it.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")
const Player := preload("res://characters/player/player.gd")
const FUEL_ITEM := "gas_can"
const HOURS_PER_CAN := 1.0
const MAX_HOURS := 3.0
const NOISE := 35.0 # meters (a gunshot is 40)
const NOISE_EVERY := 2.0 # seconds
const SIZE := Vector3(1.2, 0.9, 0.7)

var fuel := 0.0 # game hours left
var _noise_wait := 0.0
var _hum_wait := 0.0
var _lamp: OmniLight3D
var _day_night: Node


func _ready() -> void:
	var km := KitMesh.new()
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.55, 0.42, 0.12)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.12)
	km.box(Vector3(SIZE.x, 0.08, SIZE.z), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)), KitMesh.all(dark)) # skid
	km.box(Vector3(0.7, 0.55, 0.55), Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.36, 0)), KitMesh.all(dark), false) # engine
	km.box(Vector3(0.45, 0.35, 0.5), Transform3D(Basis.IDENTITY, Vector3(0.35, 0.75, 0)), KitMesh.all(body), false) # tank
	km.box(Vector3(0.4, 0.5, 0.5), Transform3D(Basis.IDENTITY, Vector3(0.35, 0.33, 0)), KitMesh.all(body), false) # alternator
	for x: float in [-SIZE.x / 2.0 + 0.03, SIZE.x / 2.0 - 0.03]: # the frame
		km.box(Vector3(0.05, SIZE.y, 0.05), Transform3D(Basis.IDENTITY, Vector3(x, SIZE.y / 2.0, -SIZE.z / 2.0 + 0.03)), KitMesh.all(dark), false)
		km.box(Vector3(0.05, SIZE.y, 0.05), Transform3D(Basis.IDENTITY, Vector3(x, SIZE.y / 2.0, SIZE.z / 2.0 - 0.03)), KitMesh.all(dark), false)
	km.box(SIZE, Transform3D(Basis.IDENTITY, Vector3(0, SIZE.y / 2.0, 0)), [null, null, null, null, null, null]) # (just its collision)
	for node in km.add_to(self):
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
	_lamp = OmniLight3D.new() # a work light on top: on while it runs
	_lamp.position = Vector3(0, SIZE.y + 0.25, 0)
	_lamp.light_color = Color(1.0, 0.85, 0.6)
	_lamp.light_energy = 1.2
	_lamp.omni_range = 9.0
	_lamp.visible = false
	add_child(_lamp, false, Node.INTERNAL_MODE_BACK)
	set_physics_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		Interactable.attach(self, interact_prompt).interacted.connect(_on_interacted)


func running() -> bool:
	return fuel > 0.0


func interact_prompt() -> String:
	if fuel >= MAX_HOURS - 0.01:
		return "generator (full: %s)" % _left()
	return "pour a gas can into the generator" + (" (%s left)" % _left() if running() else "")


func _on_interacted(actor: Node3D) -> void:
	var player := actor as Player
	if player == null or fuel >= MAX_HOURS - 0.01:
		return
	if player.take_item(FUEL_ITEM) <= 0:
		player.notify.emit("It needs a gas can.")
		return
	var was_running := running()
	fuel = minf(fuel + HOURS_PER_CAN, MAX_HOURS)
	player.notify.emit("The generator %s." % ("runs on" if was_running else "coughs and starts"))
	_update_lamp()


func _left() -> String:
	return "%d min" % ceili(fuel * 60.0)


func _physics_process(delta: float) -> void:
	if not running():
		return
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
	var hour_seconds: float = _day_night.get("seconds_per_game_hour") if _day_night else 120.0
	fuel = maxf(fuel - delta / hour_seconds, 0.0)
	_noise_wait -= delta
	if _noise_wait <= 0.0:
		_noise_wait = NOISE_EVERY
		get_tree().call_group("noise_listeners", "hear_noise", global_position, NOISE)
	_hum_wait -= delta
	if _hum_wait <= 0.0:
		_hum_wait = 1.0
		Sound.play_at(self, "generator_run", global_position + Vector3.UP * 0.5, -2.0, NOISE, 0.02)
	if not running():
		_update_lamp()


func _update_lamp() -> void:
	_lamp.visible = running()


func save_state() -> Dictionary:
	return {"fuel": fuel}


func load_state(data: Dictionary) -> void:
	fuel = float(data.get("fuel", 0.0))
	_update_lamp()
