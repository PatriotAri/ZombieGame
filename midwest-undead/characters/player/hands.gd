extends Node3D
## What you see in your hands in first person, and how it all moves: every
## weapon's model (items/held_model.gd), your fists, and items you use up
## (health packs, food, planks). player.gd says what you're holding and when you
## fire, reload or swing; this does the showing.
##
## Everything in your hands sways a little behind your view as you turn, bobs as
## you walk, tilts away while you sprint or swim, dips when you land, and drops
## out of sight and back up when you switch (draw and holster).
## TUNING: open player.tscn, select Camera3D/Hands, and use the Inspector.

const GameData := preload("res://core/game_data.gd")
const HeldModel := preload("res://items/held_model.gd")

const HOLSTER_TIME := 0.15 # seconds to put away what you were holding
const DRAW_TIME := 0.25 # bringing up fists or an item (weapons: their draw_time)
const DRAW_DROP := Vector3(0.0, -0.3, 0.05) # how far down things go when put away
const DRAW_TILT := Vector3(-35.0, 0.0, 0.0)
const AIM_SPEED := 10.0 # how fast a gun comes up to the aiming spot

@export_group("Sway")
## How far things lag behind as you turn (degrees per radian per second).
@export_range(0.0, 10.0, 0.1) var look_sway := 2.0
## The most they lag, in degrees.
@export_range(0.0, 20.0, 0.5) var look_sway_max := 5.0
@export_group("Bob")
## Meters up and down and side to side at walking speed.
@export_range(0.0, 0.05, 0.001) var bob_amount := 0.012
## Steps per meter walked (a full side-to-side is two steps).
@export_range(0.1, 2.0, 0.05) var bob_steps_per_meter := 0.75
## While aiming, sway and bob are this much of the usual.
@export_range(0.0, 1.0, 0.05) var aim_steady := 0.2
@export_group("Poses")
## Sprinting or swimming: what's in your hands turns by this much (degrees,
## about where you hold it: muzzle down, toward the middle, rolled) and drops a little.
@export var sprint_tilt := Vector3(-15.0, 30.0, 15.0)
## How hard a landing dips things (meters per m/s you were falling).
@export_range(0.0, 0.03, 0.001) var landing_dip := 0.008

var player # characters/player/player.gd (untyped: it preloads this script)
var models := {} # weapon id (and "hands") -> HeldModel
var shown := "" # what's in your hands now
var _switching_to := "" # where a switch is headed (shown changes halfway)
var _switch_tween: Tween
var _use_tween: Tween
var _drawn := 1.0 # 1 = up, 0 = put away
var _last_look := Vector2.ZERO # body yaw, camera pitch last frame
var _sway := Vector2.ZERO # degrees
var _bob_phase := 0.0
var _bob := 0.0 # 0-1: how much bob right now
var _sprint := 0.0 # 0-1: how far into the sprint pose
var _was_on_floor := true
var _fall_speed := 0.0
var _dip := 0.0 # meters down
var _dip_speed := 0.0

@onready var fists: Node3D = $Fists
@onready var item_pivot: Node3D = $ItemPivot
@onready var held_item_mesh: MeshInstance3D = $ItemPivot/HeldItem
var _item_rest := Vector3.ZERO


## Makes every weapon's model, hidden until you hold it.
func setup(owner_player: Node3D) -> void:
	player = owner_player
	_item_rest = item_pivot.position
	var fist_model := HeldModel.new()
	fist_model.name = "Fists"
	add_child(fist_model)
	var fist_at := fists.position
	fists.position = Vector3.ZERO
	fists.name = "FistsMesh"
	fist_model.setup(fists, null, fist_at)
	models["hands"] = fist_model
	for id: String in GameData.item_ids():
		var weapon := GameData.weapon(id)
		if weapon == null:
			continue
		var instance: Node3D = weapon.held_model.instantiate() if weapon.held_model else box_model(weapon)
		no_shadows(instance)
		var held := HeldModel.new()
		held.name = "Held_" + id
		add_child(held)
		held.setup(instance, weapon, weapon.held_position)
		models[id] = held
	for held: Node3D in models.values():
		held.visible = false
	item_pivot.visible = false
	_last_look = _look_angles()


## Put id in your hands. animate: put away what you're holding and bring id up
## (the usual); false: just show it (loading a game). Returns the seconds until
## it's up and usable.
func show_held(id: String, animate := true) -> float:
	if id == (_switching_to if _switching_to != "" else shown):
		return 0.0
	_kill(_switch_tween)
	if not animate or shown == "":
		_switching_to = ""
		_swap(id)
		_drawn = 1.0
		return 0.0
	_switching_to = id
	var draw_time := _draw_time(id)
	_switch_tween = create_tween()
	var old := models.get(shown) as HeldModel
	if old and old.holster(HOLSTER_TIME):
		_switch_tween.tween_interval(HOLSTER_TIME)
	else:
		_switch_tween.tween_property(self, "_drawn", 0.0, HOLSTER_TIME * _drawn)
	_switch_tween.tween_callback(func() -> void:
		_swap(id)
		var new := models.get(id) as HeldModel
		# The model's own draw animation, or the code lowers and raises it.
		_drawn = 1.0 if new and new.draw(draw_time) else 0.0
		_switching_to = "")
	_switch_tween.tween_property(self, "_drawn", 1.0, draw_time)
	return HOLSTER_TIME + draw_time


func _draw_time(id: String) -> float:
	var weapon := GameData.weapon(id)
	return weapon.draw_time if weapon else DRAW_TIME


## Shows id's model and hides the rest; an item you use up shows as its model
## (or a box) in item_pivot.
func _swap(id: String) -> void:
	if models.has(shown):
		(models[shown] as HeldModel).cancel_reload()
	shown = id
	for key: String in models:
		var held := models[key] as HeldModel
		held.visible = key == id
		held.position = held.hold_position
		held.rotation = Vector3.ZERO
	lower_item()
	for child in held_item_mesh.get_children():
		child.queue_free()
	held_item_mesh.mesh = null
	item_pivot.visible = GameData.item_use(id) in ["heal", "eat", "board", "barricade"]
	if item_pivot.visible:
		# Things you use up look like they do on the ground (their model, or a box
		# of their size and color), a bit bigger since it's right in front of you.
		var item := GameData.item(id)
		if item.model:
			var model: Node3D = item.model.instantiate()
			model.scale = Vector3.ONE * 1.2
			model.position.y = -item.size.y * 1.2 / 2.0 # models sit on the ground: center it like the box
			no_shadows(model)
			held_item_mesh.add_child(model)
		else:
			held_item_mesh.mesh = (box_model(item, 1.2) as MeshInstance3D).mesh


## The model of what's in your hands right now (null for an item you use up).
func current() -> HeldModel:
	return models.get(shown) as HeldModel


# --- What player.gd asks for -----------------------------------------------------

func fire(id: String, empty: bool) -> void:
	if models.has(id):
		(models[id] as HeldModel).fire(empty)


func reload(id: String, time: float, rounds: int) -> void:
	if models.has(id):
		(models[id] as HeldModel).reload(time, rounds)


## Stops any reload partway, and tidies up after a finished one.
func cancel_reload() -> void:
	for held: HeldModel in models.values():
		held.cancel_reload()


## The slide back on an empty gun, or home on a loaded one.
func set_empty(id: String, empty: bool) -> void:
	if models.has(id):
		(models[id] as HeldModel).set_empty(empty)


## A melee swing (or a punch) with id; hit is called when it lands.
func swing(id: String, hit: Callable) -> void:
	var held := models.get(id) as HeldModel
	if held:
		held.swing(hit)
	else:
		hit.call()


## Bandaging or eating: the item comes up toward your face.
func raise_item() -> void:
	_kill(_use_tween)
	_use_tween = create_tween()
	_use_tween.tween_property(item_pivot, "position", Vector3(0.0, -0.15, -0.35), 0.2)


func lower_item() -> void:
	_kill(_use_tween)
	if is_node_ready():
		item_pivot.position = _item_rest


# --- Moving with you -----------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	var aiming: bool = player.aiming
	var steady := aim_steady if aiming else 1.0

	# Sway: lag behind the way you're turning.
	var look := _look_angles()
	var turn := Vector2(angle_difference(_last_look.x, look.x), look.y - _last_look.y) / maxf(delta, 0.001)
	_last_look = look
	var sway_goal := (turn * look_sway * steady).limit_length(look_sway_max)
	_sway = _sway.lerp(sway_goal, minf(10.0 * delta, 1.0))

	# Bob: a figure of eight as you walk, faster and bigger the faster you go.
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	var on_floor: bool = player.is_on_floor() and not player.swimming
	var bob_goal := clampf(flat / float(player.walk_speed), 0.0, 2.0) if on_floor else 0.0
	_bob = lerpf(_bob, bob_goal, minf(8.0 * delta, 1.0))
	# Half a turn per step: down at every step, side to side over two.
	_bob_phase = fmod(_bob_phase + flat * delta * bob_steps_per_meter * PI, TAU)
	var bob := Vector3(cos(_bob_phase), -absf(sin(_bob_phase)), 0.0) * bob_amount * _bob * steady

	# Sprinting or swimming: tilt away.
	var sprint_goal := 1.0 if (player.is_sprinting or player.swimming) else 0.0
	_sprint = lerpf(_sprint, sprint_goal, minf(8.0 * delta, 1.0))

	# Landing: a quick dip, sprung back.
	if not on_floor:
		_fall_speed = maxf(-player.velocity.y, 0.0)
	elif not _was_on_floor:
		_dip_speed -= _fall_speed * landing_dip * 20.0
	_was_on_floor = on_floor
	_dip_speed += (-_dip * 300.0 - _dip_speed * 25.0) * delta
	_dip += _dip_speed * delta

	var down := 1.0 - _drawn
	position = bob + Vector3(0.0, _dip, 0.0) + Vector3(0.0, -0.04, 0.02) * _sprint + DRAW_DROP * down
	rotation_degrees = Vector3(_sway.y, _sway.x, 0.0) + DRAW_TILT * down

	# The sprint pose turns the weapon about where you hold it (turning all of
	# this node would swing it across the screen).
	var held := current()
	var pose := sprint_tilt * _sprint
	if held:
		held.rotation_degrees = pose
	item_pivot.rotation_degrees = pose
	# A gun comes up to the aiming spot, and isn't drawn at all through a scope.
	if held and held.weapon and held.weapon.is_gun():
		var goal := held.aim_position if aiming else held.hold_position
		held.position = held.position.lerp(goal, minf(AIM_SPEED * delta, 1.0))
		held.visible = not player.is_scoped()


## Body yaw and camera pitch, radians.
func _look_angles() -> Vector2:
	return Vector2(player.rotation.y, player.camera.rotation.x)


func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


## A weapon or item with no model: a box of its size and color.
static func box_model(item: ItemData, scale := 1.0) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color
	var box := BoxMesh.new()
	box.size = item.size * scale
	box.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = box
	return inst


## Things in your hands don't cast shadows (they'd fall across the view oddly).
static func no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		no_shadows(child)
