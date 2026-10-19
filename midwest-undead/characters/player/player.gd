extends CharacterBody3D
## First-person survivor: movement, stamina, hunger, crouching, melee, guns
## (hold aim to look down the sights, or through a scope), a battery-powered
## flashlight, an inventory, picking things up, trading, and the noise all of
## that makes. Every gun and melee weapon is a file in items/data/ (WeaponData):
## its stats and the model in your hands come from there.
## The node tree (camera, flashlight, fists) lives in player.tscn.
## TUNING: open player.tscn, select the Player node, and use the Inspector.

signal died
signal damaged
signal notify(text: String)
signal container_opened(spot: Node)
## You pressed interact on a living NPC that offers something (trade, talk...).
## main.gd decides what to open.
signal npc_interacted(npc: HumanNPC)
## You pressed interact on an object that offers something (e.g. the logbook).
signal object_interacted(obj: Node)

const GameData := preload("res://core/game_data.gd")
const Controls := preload("res://core/controls.gd")
const Inventory := preload("res://items/inventory.gd")
const LootSpot := preload("res://items/loot_spot.gd")
const GroundItem := preload("res://items/ground_item.gd")
const Fall := preload("res://characters/fall.gd")
const Sound := preload("res://core/sound.gd")
const Settings := preload("res://core/settings.gd")
const Water := preload("res://world/water.gd")
const Cover := preload("res://world/cover.gd")
const Ground := preload("res://world/ground.gd")
const Hands := preload("res://characters/player/hands.gd")
const PlayerLights := preload("res://characters/player/player_lights.gd")
const PlayerBuilding := preload("res://characters/player/player_building.gd")

@export_group("Movement")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
## A jump: 0.75 m high and 0.55 s in the air (~2.2 m ahead walking, ~3.9 m
## sprinting), with gravity times jump_gravity_scale from the jump until you
## land. Falling off a ledge without jumping uses normal gravity.
@export var jump_velocity := 5.42
@export var jump_gravity_scale := 2.0
## Meters per second up or down a ladder.
@export var climb_speed := 2.5
## Walking uphill: speed drops by this much per unit of slope (rise over run)
## along the way you're going, so a 45 degree climb is half speed. Downhill and
## across a slope aren't slowed. Past 45 degrees you can't climb at all: you
## slide back down (CharacterBody3D's floor_max_angle).
@export_range(0.0, 1.0, 0.05) var slope_slowdown := 0.5
## Wading through shallow water (world/water.gd): speed times this.
@export_range(0.1, 1.0, 0.05) var wade_speed_factor := 0.6
## Swimming in deep water: meters per second. No sprinting, jumping or guns.
@export var swim_speed := 1.6

@export_group("Look")
## Baselines: the pause menu's sensitivity sliders multiply these (1.0x = as set here).
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.002
## Right-stick turn speed at full tilt, in radians per second.
@export_range(0.5, 10.0, 0.1) var stick_look_speed := 3.0
## Default up/down direction; the pause menu's "Invert look" flips it.
@export var invert_look_y := false

@export_group("Health & Stamina")
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var sprint_stamina_per_sec := 18.0
@export var stamina_regen_per_sec := 20.0
@export var health_pack_heal := 40.0

@export_group("Starting Kit")
## US dollars.
@export var starting_money := 40
## A gun (an item id) you start with, loaded. Empty: none.
@export var starting_gun := "pistol"
## Spare rounds for it, on top of the ones loaded.
@export var starting_spare_ammo := 0

@export_group("Noise radius (meters)")
## Zombies inside a sound's radius come to check it out. Crouch-walking is silent.
@export var noise_walk := 5.0
@export var noise_sprint := 14.0
@export var noise_melee_hit := 9.0
@export var noise_search := 4.0
@export var noise_gunshot := 40.0

@export_group("Consumables")
## Seconds to bandage up with a health pack (getting hurt interrupts it).
@export var heal_time := 1.5
## Seconds to eat a can of food (getting hurt interrupts it).
@export var eat_time := 1.2
@export var food_heal := 15.0
## Eating also restores this much stamina.
@export var food_stamina := 100.0
## How much a can of food takes off your hunger (0 = full, 100 = starving).
@export var food_hunger := 35.0

@export_group("Hunger")
## Hunger rises with in-game time: 4 per hour means fed to starving in about a
## day (25 game hours, ~50 real minutes at the default clock speed). Roughly
## three cans of food a day keep it down.
@export var hunger_per_game_hour := 4.0
@export_range(0.0, 100.0) var starting_hunger := 20.0
## From here on you're hungry: stamina comes back at half speed.
@export_range(0.0, 100.0) var hungry_at := 60.0
## At 100 hunger you're starving and slowly lose health.
@export var starving_damage_per_sec := 0.4

@export_group("Flashlight")
## Real seconds of light from one set of batteries.
@export var battery_life := 240.0
## Below this charge (0-1) the beam dims and flickers.
@export_range(0.0, 1.0) var low_battery := 0.2
## Spare sets of batteries you start with (one set is already in the flashlight).
@export var starting_spare_batteries := 0
## Enough to try boarding up and barricading; more from the trader and containers.
@export var starting_planks := 2
@export var starting_barricades := 1

@export_group("Guns")
## Hits above about 1.4 m on a zombie or a person do this much more damage.
@export var headshot_multiplier := 2.5
## Moving while aiming is this much of your walking speed (and you can't sprint).
@export_range(0.1, 1.0) var aim_move_factor := 0.65
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STAMINA_REGEN_DELAY := 0.8 # seconds after exertion before stamina refills
const INTERACT_RANGE := 2.5
const AIM_SPEED := 10.0 # how fast the view zooms in and out
## Zoomed in further than this (degrees), the rifle's view is the scope's.
const SCOPE_FOV_THRESHOLD := 40.0

## Empty hands. (Weapons are files: items/data/.)
const FISTS := {"damage": 20.0, "range": 1.7, "cooldown": 0.45, "stamina": 8.0, "knockback": 2.0}

var health := 100.0 # set to max_health in _ready
var stamina := 100.0
var money := 0 # US dollars
var inventory := Inventory.new()
## Rounds loaded in each gun (not in the inventory), by gun id.
var mags := {}
var aiming := false # holding aim with a gun in your hands
## What's in your hands: "hands" (empty, you punch) or an item id with a "use"
## in its file (items/data/). The use button does whatever that item does.
var held := "hands"
var is_dead := false
## What killed you, for the death message: "bitten", "shot" or "starved".
var death_cause := ""
var _fall := Fall.new()
var is_crouching := false
var _jumping := false # in the air from a jump (heavier gravity, jump_gravity_scale)
var swimming := false # in deep water (world/water.gd): floating chest-deep
## Under water (your head is: a flooded mine tunnel, or diving): your breath
## runs out in BREATH seconds, and then you drown, DROWN_DAMAGE a second.
## Back in the air it comes back BREATH_BACK times as fast.
const BREATH := 25.0
const DROWN_DAMAGE := 10.0
const BREATH_BACK := 3.0
var breath := BREATH
var head_under := false
var water_depth := 0.0 # meters of water at your feet (0 when dry)
var _water_surface := NAN
var in_cover := false # crouched in tall crops or bushes (world/cover.gd): zombies can't see you
var _cover_timer := 0.0
## The map's edge has no ground past it. Falling out below the lowest ground
## (FELL_BELOW meters) puts you back where you last stood.
const FELL_BELOW := 30.0
var _safe_spot := Vector3.INF
var _safe_timer := 0.0
var hunger := 20.0 # 0 = just ate, 100 = starving; set to starting_hunger in _ready
var menu_open := false # set by the inventory/shop screens; freezes your controls

var prompt_text := "" # read by the HUD

# Nodes from player.tscn. @onready fills these in just before _ready runs.
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
## What's in your hands and how it moves: weapon models and their animations.
@onready var hands: Hands = $Camera3D/Hands
var _base_fov := 75.0

var attack_cooldown := 0.0
var reload_timer := 0.0
var _use_left := 0.0 # time left bandaging / eating
var stamina_regen_wait := 0.0
var is_sprinting := false
var step_timer := 0.0
# Controller: sprint and crouch toggle with a press (holding a stick click or B
# while also steering both sticks isn't practical). Keyboard keys are held instead.
var sprint_latched := false
var crouch_latched := false
var suppress_next_attack := false # the click that re-grabs the mouse shouldn't fire
var _last_physics_frame := 0 # to notice when we've just come back from a pause or menu
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var day_night: Node # for hunger, which runs on in-game time
## The flashlight, the helmet lamp and a carried lantern (player_lights.gd).
var lights: PlayerLights
## Wearing the helmet lamp (the backpack puts it on: wear_lamp).
var lamp_worn: bool:
	get:
		return lights.lamp_worn
## Dynamite (world/dynamite.gd): use lights it, and letting go throws it,
## THROW_SPEED m/s; the fuse burns while you hold it (it goes off in your
## hand if you hold on too long). Crouching, use sets it down lit instead.
const THROW_SPEED := 13.0
var _cooking := false
var _cook_left := 0.0
var _underground := false # down a mine: your hands are drawn on its layer (KitMine.contains)
var _layer_wait := 0.0
var _hunger_stage := 0 # 0 fed, 1 hungry, 2 starving: to announce each change once
var _growl_timer := 0.0
var _hurt_sound_wait := 0.0 # zombies hurt you every frame; grunt at most this often
var _ladders: Array[Area3D] = [] # the ladders you're touching (structures.gd tells us)
## Fortifying, building and salvaging (player_building.gd).
var building := PlayerBuilding.new(self)
var _look_target: Node3D # what _looked_at() saw, and on which physics frame
var _look_frame := -1
var _look_nothing := false


func _ready() -> void:
	add_to_group("player")
	add_to_group("zombie_targets")
	# The same speed along the ground on a slope as on the flat, so slope_slowdown
	# alone decides how much a hill slows you.
	floor_constant_speed = true
	health = max_health
	stamina = max_stamina
	hunger = starting_hunger
	_hunger_stage = _stage_for(hunger)
	money = starting_money
	for id: String in GameData.item_ids():
		if is_gun(id):
			mags[id] = 0
	var gun := GameData.weapon(starting_gun)
	if gun and gun.is_gun():
		inventory.add(starting_gun)
		inventory.add(gun.ammo, starting_spare_ammo)
		mags[starting_gun] = gun.magazine
		held = starting_gun
	else:
		held = "hands"
	inventory.add("batteries", starting_spare_batteries)
	inventory.add("planks", starting_planks)
	inventory.add("barricade", starting_barricades)
	lights = PlayerLights.new()
	lights.name = "Lights"
	add_child(lights)
	lights.setup(flashlight, camera, self, inventory, notify.emit, battery_life, low_battery)
	_base_fov = camera.fov
	hands.setup(self)
	_refresh_weapon_visuals(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Zombies call this to decide whether you're worth chasing.
func is_targetable() -> bool:
	return not is_dead


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or menu_open:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(motion.relative * mouse_sensitivity * Settings.mouse_sensitivity * _zoom_factor(), Settings.invert_mouse_y)
		return
	# A real click (not the scroll wheel) re-grabs the mouse after it was freed.
	if event is InputEventMouseButton and event.is_pressed() \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Only swallow the next attack if this click *was* an attack click; otherwise
		# a right-click here would eat your next real shot.
		suppress_next_attack = event.is_action_pressed("use_held")
		return

	var from_pad := event is InputEventJoypadButton
	if event.is_action_pressed("interact"):
		# Handled here (not polled) so the inventory/shop screens can swallow the
		# press that closes them.
		var target := _looked_at()
		if event.is_action_pressed("reload") and not _has_interaction(target):
			_start_reload() # one button for both (X on a controller): nothing to use, so it reloads
		elif (_can_salvage() and not building.salvage_yield(target).is_empty()) or _can_dig(target):
			building.start_salvage(target) # a tap still opens it; holding strips it, or digs it out
		else:
			_interact()
	elif event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	elif event.is_action_pressed("use_health_pack"):
		_quick_heal()
	elif event.is_action_pressed("item_next"):
		_cycle(1)
	elif event.is_action_pressed("item_prev"):
		_cycle(-1)
	elif event.is_action_pressed("reload"):
		_start_reload()
	elif from_pad and event.is_action_pressed("sprint"):
		sprint_latched = not sprint_latched
		crouch_latched = false
	elif from_pad and event.is_action_pressed("crouch"):
		crouch_latched = not crouch_latched
		sprint_latched = false
	else:
		# Number keys pick from what you can hold directly (numbered on the inventory screen).
		for i in range(1, 10):
			if event.is_action_pressed("slot_%d" % i):
				var bar := holdable()
				if i <= bar.size():
					select(bar[i - 1])
				break


## Turn the body left/right and tilt only the head up/down. invert: that
## device's Invert setting (mouse or controller). Aiming scales it by the
## "While aiming" setting.
func _look(amount: Vector2, invert: bool) -> void:
	if aiming:
		amount *= Settings.aim_sensitivity
	rotate_y(-amount.x)
	var inverted := invert_look_y != invert
	camera.rotate_x(-amount.y * (-1.0 if inverted else 1.0))
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not _ladders.is_empty(): # (a ladder that's gone, a built one torn down say, lets go)
		_ladders = _ladders.filter(func(l: Area3D) -> bool: return is_instance_valid(l))
	var climbing := not _ladders.is_empty()
	_update_water()
	_update_breath(delta)
	_update_layers(delta)
	_check_fell_out(delta)
	if climbing:
		velocity.y = 0.0 # holding on: no falling (_climb moves you up and down)
		_jumping = false
	elif swimming:
		# Float chest-deep: drift up or down to SWIM_DEPTH below the surface.
		# Crouch dives, jump swims up (under a flooded tunnel's roof, say).
		_jumping = false
		if (Input.is_action_pressed("crouch") or crouch_latched) and not menu_open:
			velocity.y = -swim_speed
		elif Input.is_action_pressed("jump") and not menu_open:
			velocity.y = swim_speed
		else:
			velocity.y = clampf((_water_surface - Water.SWIM_DEPTH - global_position.y) * 4.0, -2.0, 2.0)
	elif not is_on_floor():
		velocity.y -= gravity * (jump_gravity_scale if _jumping else 1.0) * delta
	else:
		_jumping = false

	_update_aim(delta)
	if menu_open:
		# Hands are busy: stand still, but the world keeps going.
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		move_and_slide()
		var fell := _fall.update(self, max_health, gravity, climbing or swimming)
		if fell > 0.0:
			take_damage(fell, "fell")
		_update_stamina(delta, false)
		_update_hunger(delta)
		_update_flashlight(delta)
		building.update_barricade_ghost() # hides it while a menu is up
		building.update_build_view()
		building.salvage_target = null
		return

	# Coming back from the pause menu or a trade/inventory screen: the button that
	# closed it (A on "Resume", say) is still "just pressed" this frame, and would
	# otherwise also make you jump or fire. Ignore one-shot presses for one frame.
	var frame := Engine.get_physics_frames()
	var just_resumed := frame - _last_physics_frame > 1
	_last_physics_frame = frame

	# Right stick look. get_vector applies the stick deadzone for us.
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		var speed := Vector2(Settings.stick_sensitivity_x, Settings.stick_sensitivity_y)
		_look(stick * speed * stick_look_speed * delta * _zoom_factor(), Settings.invert_stick_y)

	# The use button is polled (not event-driven) so the analog trigger fires once per pull.
	if Input.is_action_just_pressed("use_held") and not just_resumed:
		if suppress_next_attack:
			suppress_next_attack = false
		else:
			_use_held()

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
	if _use_left > 0.0:
		_use_left -= delta
		if _use_left <= 0.0:
			_finish_use()
	if _cooking:
		_cook_left -= delta
		if _cook_left <= 0.0: # held on too long
			_cooking = false
			take_item("dynamite")
			Dynamite.explode(get_tree(), global_position + Vector3.UP)
		elif not Input.is_action_pressed("use_held") or held != "dynamite":
			_throw_dynamite()

	is_crouching = Input.is_action_pressed("crouch") or crouch_latched
	_cover_timer -= delta
	if _cover_timer <= 0.0:
		_cover_timer = 0.2
		in_cover = is_crouching and Cover.hides(get_tree(), global_position)
	var eye := CROUCH_EYE_HEIGHT if is_crouching else EYE_HEIGHT
	camera.position.y = move_toward(camera.position.y, eye, 4.0 * delta)

	if Input.is_action_just_pressed("jump") and not just_resumed and is_on_floor() and not is_crouching and not swimming:
		velocity.y = jump_velocity
		_jumping = true

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() < 0.1:
		sprint_latched = false # stopping ends a controller sprint
	# transform.basis converts "forward relative to me" into world directions.
	# Not normalized, so a half-tilted stick walks at half speed.
	var direction := transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	var sprinting := (Input.is_action_pressed("sprint") or sprint_latched) and not is_crouching \
			and stamina > 0.0 and direction != Vector3.ZERO and not aiming and not swimming
	is_sprinting = sprinting
	var speed := walk_speed
	if swimming:
		speed = swim_speed
	elif is_crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	if aiming:
		speed *= aim_move_factor
	if not swimming:
		if water_depth > Water.WADE_DEPTH:
			speed *= wade_speed_factor
		speed *= _slope_factor(direction, slope_slowdown)
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	if climbing:
		_climb(input_dir)
	move_and_slide()
	var fell := _fall.update(self, max_health, gravity, climbing or swimming)
	if fell > 0.0:
		take_damage(fell, "fell")

	_update_stamina(delta, sprinting)
	_update_hunger(delta)
	_update_flashlight(delta)
	_update_footsteps(delta, sprinting)
	building.update_build_view()
	building.update_salvage(delta)
	_update_prompt()
	building.update_barricade_ghost()
	_hurt_sound_wait = maxf(_hurt_sound_wait - delta, 0.0)


## Remembers solid ground now and then; fell out of the map: back to it.
func _check_fell_out(delta: float) -> void:
	_safe_timer -= delta
	if is_on_floor() and _safe_timer <= 0.0:
		_safe_timer = 1.0
		_safe_spot = global_position
	if global_position.y < Ground.height_range().x - FELL_BELOW and _safe_spot != Vector3.INF:
		global_position = _safe_spot + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO


## Water at your feet (world/water.gd): how deep, and whether that's swimming.
## A little give either way, so you don't flicker in and out of swimming at the edge.
func _update_water() -> void:
	_water_surface = Water.surface_at(get_tree(), global_position)
	water_depth = 0.0 if is_nan(_water_surface) else maxf(_water_surface - global_position.y, 0.0)
	swimming = water_depth >= (Water.SWIM_DEPTH - 0.15 if swimming else Water.SWIM_DEPTH)


## Down a mine, what you see of yourself (your hands, what's in them) is drawn
## on the underground layer, out of the sun's light like the mine (KitMine).
func _update_layers(delta: float) -> void:
	_layer_wait -= delta
	if _layer_wait > 0.0:
		return
	_layer_wait = 0.25
	var under := KitMine.contains(global_position + Vector3.UP)
	if under == _underground and not under:
		return # (down there it keeps at it: what's in your hands changes)
	_underground = under
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).layers = GameData.RENDER_UNDERGROUND if under else 1


## Your breath: going while your head's under water, then you drown.
func _update_breath(delta: float) -> void:
	var eye := camera.global_position
	var surface := Water.surface_at(get_tree(), eye)
	head_under = not is_nan(surface) and surface > eye.y
	if head_under:
		breath = maxf(breath - delta, 0.0)
		if breath <= 0.0:
			take_damage(DROWN_DAMAGE * delta, "drowned")
	else:
		breath = minf(breath + delta * BREATH_BACK, BREATH)


## Speed multiplier for the ground you're on: 1 on the flat, downhill or across
## a slope; less going uphill (slowdown per unit of rise over run).
func _slope_factor(direction: Vector3, slowdown: float) -> float:
	if not is_on_floor() or direction == Vector3.ZERO:
		return 1.0
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	return clampf(1.0 - slowdown * Ground.uphill_rise(get_floor_normal(), flat), 0.2, 1.0)


## cause is what the death message blames if this kills you: zombies bite
## (the default), bandits pass "shot".
func take_damage(amount: float, cause := "bitten") -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	damaged.emit()
	if _hurt_sound_wait <= 0.0:
		Sound.play_ui(self, "player_hurt", -4.0)
		_hurt_sound_wait = 0.6
	if _use_left > 0.0:
		_cancel_use()
		notify.emit("Interrupted!") # can't bandage up or eat while something's biting you
	if health <= 0.0:
		_die(cause)


func _die(cause: String) -> void:
	death_cause = cause
	is_dead = true
	building.update_barricade_ghost() # hides the previews: the barricade's, and the building piece's
	building.update_build_view()
	_ladders.clear()
	lights.all_off()
	hands.visible = false
	aiming = false
	camera.fov = _base_fov
	camera.position.y = 0.3 # collapse to the ground
	died.emit()


## Hunger and flashlight for the HUD, e.g. "Hunger 64 (hungry)    Flashlight 38%  +2".
func hunger_text() -> String:
	var text := "Hunger %d" % floori(hunger)
	match _hunger_stage:
		1:
			text += " (hungry)"
		2:
			text += " (STARVING)"
	return text


## For the inventory screen: the flashlight's charge and the spare batteries.
func flashlight_text() -> String:
	return lights.text()


## Text for the HUD describing what's in your hands, e.g. "Pistol 5/7  (+12)".
func held_label() -> String:
	if is_gun(held):
		var gun := GameData.weapon(held)
		var text := "%s %d/%d  (+%d)" % [GameData.item_name(held), mags[held], gun.magazine, inventory.count(gun.ammo)]
		return text + "  reloading..." if reload_timer > 0.0 else text
	if held == "hands":
		return "Fists"
	var label := GameData.item_name(held)
	if inventory.count(held) > 1:
		label += " x%d" % inventory.count(held)
	if _use_left > 0.0:
		label += "  eating..." if GameData.item_use(held) == "eat" else "  bandaging..."
	return label


## Everything you can hold, in order: empty hands first, then each usable item
## you're carrying (ammo and batteries can't be held, so they're skipped). The
## number keys pick from this list, and the inventory screen (Tab) shows it.
func holdable() -> Array[String]:
	var bar: Array[String] = ["hands"]
	for id in inventory.ids():
		if GameData.item_use(id) != "":
			bar.append(id)
	return bar


## Put something in your hands. Cancels a reload or a half-finished bandage.
func select(id: String) -> void:
	if id == held or not (id == "hands" or inventory.has(id)):
		return
	held = id
	_cancel_reload()
	_cancel_use()
	# Not usable until it's up (hands.gd puts the old one away and draws this).
	attack_cooldown = hands.show_held(held) if is_node_ready() and not is_dead else 0.0
	_refresh_weapon_visuals()


## Everything that listens (zombies, bandits) is told about the sound; each one
## decides whether it was close enough to hear it.
func make_noise(radius: float) -> void:
	get_tree().call_group("noise_listeners", "hear_noise", global_position, radius)


# --- Saving ------------------------------------------------------------------

## Everything about you that a save file needs, as plain data.
func save_state() -> Dictionary:
	var data := {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": camera.rotation.x,
		"health": health,
		"stamina": stamina,
		"money": money,
		"inventory": inventory.to_dict(),
		"mags": mags.duplicate(),
		"held": held,
		"hunger": hunger,
	}
	lights.save_into(data) # "flashlight", "flashlight_charge", "lamp_worn", "lamp_on", "lamp_charge"
	return data


func load_state(data: Dictionary) -> void:
	var pos: Array = data.get("position", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(data.get("yaw", rotation.y))
	camera.rotation.x = float(data.get("pitch", 0.0))
	health = float(data.get("health", max_health))
	stamina = float(data.get("stamina", max_stamina))
	money = int(data.get("money", money))
	inventory.from_dict(data.get("inventory", {}))
	var saved_mags: Dictionary = data.get("mags", {"pistol": data.get("pistol_mag", 0)})
	for id: String in mags:
		mags[id] = clampi(int(saved_mags.get(id, 0)), 0, GameData.weapon(id).magazine)
	lights.load_from(data)
	hunger = clampf(float(data.get("hunger", starting_hunger)), 0.0, 100.0)
	_hunger_stage = _stage_for(hunger)
	var saved_held: String = data.get("held", "hands")
	held = saved_held if saved_held == "hands" or inventory.has(saved_held) else "hands"
	_refresh_weapon_visuals(false)


# --- Inventory ---------------------------------------------------------------

func give_item(id: String, amount := 1) -> void:
	inventory.add(id, amount)
	_refresh_weapon_visuals()


## Removes up to amount; returns how many actually left your inventory.
func take_item(id: String, amount := 1) -> int:
	var taken := inventory.remove(id, amount)
	if is_gun(id) and taken > 0 and not inventory.has(id):
		# Unload the gun as it leaves your hands, so the loaded rounds stay with you.
		inventory.add(GameData.weapon(id).ammo, mags[id])
		mags[id] = 0
	_drop_held_if_gone()
	return taken


## If what you're holding just left your inventory (sold, stored, used up),
## go back to empty hands.
func _drop_held_if_gone() -> void:
	if held != "hands" and not inventory.has(held):
		_cancel_reload()
		_cancel_use()
		held = "hands"
	_refresh_weapon_visuals()


## Step through what you can hold (wheel, D-pad left/right). Wraps around.
func _cycle(step: int) -> void:
	var bar := holdable()
	var index := bar.find(held)
	select(bar[posmod(index + step, bar.size())])


## Q / LB: grab a health pack and start using it, whatever you were holding.
func _quick_heal() -> void:
	if not inventory.has("health_pack"):
		notify.emit("No health packs.")
		return
	select("health_pack")
	attack_cooldown = 0.0 # skip the usual raise delay: this is the "panic button"
	_use_held()


# --- Using the held item -----------------------------------------------------

## The use button: shoot, swing, bandage, or eat, depending on what you hold.
func _use_held() -> void:
	match "melee" if held == "hands" else GameData.item_use(held):
		"shoot":
			if swimming:
				notify.emit("You can't shoot while swimming.")
				return
			_try_shoot()
		"melee":
			_try_melee()
		"heal":
			if health >= max_health:
				notify.emit("Already at full health.")
			else:
				_start_use(heal_time)
		"eat":
			_start_use(eat_time)
		"board":
			building.try_board()
		"barricade":
			building.try_barricade()
		"build":
			building.try_build()
		"plate":
			building.try_plate()
		"throw":
			_try_dynamite()


## Bandaging and eating take a moment: the item comes up toward your face, and
## the effect lands when the timer runs out (see _physics_process).
func _start_use(duration: float) -> void:
	if _use_left > 0.0 or attack_cooldown > 0.0:
		return
	_use_left = duration
	Sound.play_ui(self, "eat" if GameData.item_use(held) == "eat" else "bandage", -4.0)
	hands.raise_item()


func _finish_use() -> void:
	_use_left = 0.0
	_lower_item()
	if not inventory.has(held):
		return
	inventory.remove(held)
	match GameData.item_use(held):
		"heal":
			health = minf(health + health_pack_heal, max_health)
			notify.emit("Patched up.")
		"eat":
			health = minf(health + food_heal, max_health)
			stamina = minf(stamina + food_stamina, max_stamina)
			hunger = maxf(hunger - food_hunger, 0.0)
			_hunger_stage = _stage_for(hunger)
			notify.emit("That hit the spot.")
	attack_cooldown = 0.3
	_drop_held_if_gone() # last one used: back to empty hands


func _cancel_use() -> void:
	_use_left = 0.0
	_lower_item()


func _lower_item() -> void:
	if is_node_ready():
		hands.lower_item()


# --- Interaction (pick up / open / trade) ------------------------------------

## Cast once a physics frame (the prompt, salvaging and fortifying all ask);
## afresh outside the physics step (a button press: aim where you're aiming now).
func _looked_at() -> Node3D:
	var frame := Engine.get_physics_frames()
	if Engine.is_in_physics_frame() and frame == _look_frame:
		if _look_nothing:
			return null
		if is_instance_valid(_look_target):
			return _look_target
	_look_target = _cast_look()
	_look_nothing = _look_target == null
	_look_frame = frame if Engine.is_in_physics_frame() else -1
	return _look_target


func _cast_look() -> Node3D:
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, end,
			GameData.LAYER_WORLD | GameData.LAYER_ITEMS | GameData.LAYER_NPC)
	query.collide_with_areas = true # ground items are areas
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var thing := hit["collider"] as Node3D
	# Part of something bigger (a car's roof, under the car): that's what you're looking at.
	if thing and thing.get_meta("part_of_parent", false):
		return thing.get_parent() as Node3D
	return thing


func _update_prompt() -> void:
	prompt_text = ""
	var key := Controls.hint("interact")
	var target := _looked_at()
	if target is GroundItem:
		prompt_text = "%s: pick up %s" % [key, (target as GroundItem).get_label()]
	elif target is LootSpot:
		var spot := target as LootSpot
		if not spot.opened:
			prompt_text = "%s: search %s" % [key, spot.label]
		elif spot.inventory.is_empty():
			prompt_text = "%s: open %s (empty)" % [key, spot.label]
		else:
			prompt_text = "%s: open %s" % [key, spot.label]
	elif _offers_interaction(target):
		prompt_text = "%s: %s" % [key, target.call("interact_prompt")]
	if prompt_text == "":
		prompt_text = building.fortify_prompt()
	prompt_text = building.salvage_prompt(target, key, prompt_text)


func _interact() -> void:
	var target := _looked_at()
	if target is GroundItem:
		var item := target as GroundItem
		give_item(item.item_id, item.amount)
		notify.emit("Picked up " + item.get_label())
		Sound.play_ui(self, "pickup", -6.0)
		item.queue_free()
	elif target is LootSpot:
		var spot := target as LootSpot
		if spot.open():
			make_noise(noise_search) # rummaging isn't quiet
			Sound.play_ui(self, "rummage", -4.0)
		container_opened.emit(spot)
	elif _offers_interaction(target):
		if target is HumanNPC:
			npc_interacted.emit(target)
		else:
			object_interacted.emit(target)


## Whether interact would do something with target: pick it up, search or open
## it, talk to it, use it, or (holding the crowbar) salvage it.
func _has_interaction(target: Node3D) -> bool:
	if target is GroundItem or target is LootSpot or _offers_interaction(target):
		return true
	return _can_salvage() and not building.salvage_yield(target).is_empty()


## Anything (an NPC, the logbook...) with an interact_prompt() that isn't empty.
## Dead NPCs offer nothing.
func _offers_interaction(target: Node3D) -> bool:
	if target == null or not target.has_method("interact_prompt"):
		return false
	if target is HumanNPC and (target as HumanNPC).is_dead:
		return false
	return target.call("interact_prompt") != ""


# --- Dynamite (world/dynamite.gd) -------------------------------------------------

## Lights the dynamite in your hand (thrown when you let go), or, crouching,
## lights it and sets it down at your feet.
func _try_dynamite() -> void:
	if _cooking or attack_cooldown > 0.0:
		return
	if swimming:
		notify.emit("Not in the water.")
		return
	Sound.play_ui(self, "fuse_hiss", -2.0)
	if is_crouching and is_on_floor():
		var at := global_position - global_basis.z * 0.6 + Vector3.UP * 0.1
		_spawn_dynamite(Dynamite.lit(at, Dynamite.PLACE_FUSE))
		take_item("dynamite")
		attack_cooldown = 0.6
		notify.emit("You light the fuse and set it down. %d seconds: get clear." % int(Dynamite.PLACE_FUSE))
		return
	_cooking = true
	_cook_left = Dynamite.THROW_FUSE
	notify.emit("Lit! Let go to throw it.")


func _throw_dynamite() -> void:
	_cooking = false
	var forward := -camera.global_basis.z
	var at := camera.global_position + forward * 0.5
	_spawn_dynamite(Dynamite.lit(at, _cook_left, forward * THROW_SPEED + Vector3.UP * 2.5 + velocity))
	take_item("dynamite")
	attack_cooldown = 0.6


func _spawn_dynamite(stick: Dynamite) -> void:
	get_parent().add_child(stick)


# --- Ladders -------------------------------------------------------------------

## On a ladder: forward climbs up (or down, if you're looking down), back climbs
## down. Partway up you hang on (no stepping off into the air); at the bottom
## or the top you can walk off.
func _climb(input_dir: Vector2) -> void:
	var ladder := _ladders[_ladders.size() - 1]
	var top_y: float = ladder.get_meta("top_y", global_position.y)
	var push := -input_dir.y # forward is +1
	if camera.rotation.x < deg_to_rad(-35.0):
		push = -push
	velocity.y = push * climb_speed
	# A mine's ladder has landings on the way up (kit_mine.gd): step off there too.
	var landing := (ladder.get_meta("landings", []) as Array).any(func(y: float) -> bool:
		return absf(global_position.y - y) < 0.25)
	if not is_on_floor() and global_position.y < top_y - 0.1 and not landing:
		velocity.x = 0.0
		velocity.z = 0.0


## Ladders (structures.gd calls these as you touch them and let go).
func enter_ladder(ladder: Area3D) -> void:
	if not ladder in _ladders:
		_ladders.append(ladder)


func exit_ladder(ladder: Area3D) -> void:
	_ladders.erase(ladder)


# --- Weapons -----------------------------------------------------------------

## The held melee weapon's stats (fists if it's empty hands).
func _melee_weapon() -> Dictionary:
	var weapon := GameData.weapon(held)
	if weapon == null or weapon.is_gun():
		return FISTS.merged({"noise": noise_melee_hit})
	return {"damage": weapon.damage, "range": weapon.reach, "cooldown": weapon.cooldown,
			"stamina": weapon.stamina_cost, "knockback": weapon.knockback, "noise": weapon.noise}


## Holding something that can pry things apart for materials.
## Holding something that digs (the pickaxe) and looking at something to dig out (a cave-in).
func _can_dig(target: Node3D) -> bool:
	var weapon := GameData.weapon(held)
	return weapon != null and weapon.digs and target != null and target.has_method("dig")


func _can_salvage() -> bool:
	var weapon := GameData.weapon(held)
	return weapon != null and weapon.salvages


func _try_melee() -> void:
	var weapon := _melee_weapon()
	var cost: float = weapon["stamina"]
	if attack_cooldown > 0.0 or stamina < cost:
		return
	attack_cooldown = weapon["cooldown"]
	stamina -= cost
	stamina_regen_wait = STAMINA_REGEN_DELAY
	Sound.play_ui(self, "melee_swing", -6.0, 0.15)
	# Quick strike, damage lands at the end of it, then a slower return.
	hands.swing(held, _apply_melee_hit.bind(weapon))


## Hits every zombie or person in range, roughly in front of you, and not behind a
## wall or a window. Friendly NPCs ignore your hits (see HumanNPC.player_can_hurt).
func _apply_melee_hit(weapon: Dictionary) -> void:
	if is_dead:
		return
	var reach: float = weapon["range"]
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var space := get_world_3d().direct_space_state
	var hit_any := false
	var victims := get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("npcs")
	for node in victims:
		var victim := node as Node3D
		var to_target := victim.global_position + Vector3(0, 1.0, 0) - origin
		if to_target.length_squared() > reach * reach:
			continue
		if forward.dot(to_target.normalized()) < 0.6: # about a 100 degree swing arc
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, origin + to_target,
				GameData.LAYER_WORLD | GameData.LAYER_GLASS)
		if not space.intersect_ray(query).is_empty():
			continue # wall, car, or window in the way
		# call() because this script doesn't know the zombie script's functions.
		victim.call("take_hit", weapon["damage"], origin, weapon["knockback"], self)
		hit_any = true
	if hit_any:
		make_noise(weapon["noise"])
		Sound.play_ui(self, "melee_hit", -2.0, 0.15)


static func is_gun(id: String) -> bool:
	var weapon := GameData.weapon(id)
	return weapon != null and weapon.is_gun()


## For the inventory and trade screens, e.g. "Shotgun  (3/5 loaded)".
func gun_text(id: String) -> String:
	return "%s  (%d/%d loaded)" % [GameData.item_name(id), mags[id], GameData.weapon(id).magazine]


## Looking through a scope (the HUD draws it over the screen).
func is_scoped() -> bool:
	var weapon := GameData.weapon(held)
	return aiming and weapon != null and weapon.scope and camera.fov < SCOPE_FOV_THRESHOLD


## Hold aim (right mouse / LT) with a gun: the view zooms in, the gun comes up to
## the middle of the screen, and you turn slower to match. Not while reloading.
func _update_aim(delta: float) -> void:
	aiming = is_gun(held) and Input.is_action_pressed("aim") and not menu_open and reload_timer <= 0.0 and not swimming
	var goal_fov: float = GameData.weapon(held).aim_fov if aiming else _base_fov
	camera.fov = lerpf(camera.fov, goal_fov, minf(AIM_SPEED * delta, 1.0))
	# (hands.gd brings the gun up to the middle, and hides it through a scope.)


## Zoomed in, the same mouse movement turns you less (so aiming stays steady).
func _zoom_factor() -> float:
	return camera.fov / _base_fov


## Hitscan: instant rays from the center of the screen (where the crosshair is),
## one per pellet, spread in a cone that's tighter when aiming.
func _try_shoot() -> void:
	if attack_cooldown > 0.0 or reload_timer > 0.0:
		return
	var gun := GameData.weapon(held)
	if mags[held] <= 0:
		attack_cooldown = 0.3
		Sound.play_ui(self, "dry_fire", -4.0)
		notify.emit("Empty. Press %s to reload." % Controls.hint("reload") if inventory.has(gun.ammo) else "Out of ammo.")
		return
	mags[held] -= 1
	attack_cooldown = gun.cooldown
	hands.fire(held, mags[held] == 0)
	make_noise(gun.noise)
	Sound.play_ui(self, gun.sound, gun.sound_volume, 0.05, gun.sound_pitch)

	var spread := deg_to_rad(gun.aimed_spread if aiming else gun.spread)
	var origin := camera.global_position
	var space := get_world_3d().direct_space_state
	var damage_to := {} # target -> total damage from this shot (pellets add up)
	var hit_at := {} # target -> where it was hit (a headshot pellet's spot if any)
	for i in gun.pellets:
		# A random direction inside the cone: tilt off center, then spin round it.
		var dir := -camera.global_basis.z
		if spread > 0.0:
			var off := camera.global_basis.x.rotated(dir, randf() * TAU)
			dir = dir.rotated(off, sqrt(randf()) * spread)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * gun.reach,
				GameData.LAYER_WORLD | GameData.LAYER_ZOMBIES | GameData.LAYER_NPC)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var target := hit["collider"] as Node3D
		if target and target.has_method("take_hit"):
			var hit_pos: Vector3 = hit["position"]
			var headshot: bool = target.call("is_headshot", hit_pos) if target.has_method("is_headshot") \
					else hit_pos.y - target.global_position.y > 1.4 # people's heads sit at ~1.4-1.8 m
			damage_to[target] = float(damage_to.get(target, 0.0)) + gun.damage * (headshot_multiplier if headshot else 1.0)
			if headshot or not hit_at.has(target):
				hit_at[target] = hit_pos
	for target: Node3D in damage_to:
		if is_instance_valid(target):
			target.call("take_hit", damage_to[target], origin, gun.knockback, self, hit_at[target])


func _start_reload() -> void:
	if not is_gun(held) or reload_timer > 0.0:
		return
	var gun := GameData.weapon(held)
	if mags[held] >= gun.magazine:
		return
	if not inventory.has(gun.ammo):
		notify.emit("No %s." % GameData.item_name(gun.ammo).to_lower())
		return
	var time := gun.reload_time
	reload_timer = time
	Sound.play_ui(self, "reload", -4.0, 0.0)
	hands.reload(held, time, mini(gun.magazine - int(mags[held]), inventory.count(gun.ammo)))


func _finish_reload() -> void:
	if not is_gun(held):
		return
	var gun := GameData.weapon(held)
	mags[held] += inventory.remove(gun.ammo, gun.magazine - int(mags[held]))
	hands.cancel_reload() # everything back in place
	hands.set_empty(held, mags[held] == 0)


func _cancel_reload() -> void:
	reload_timer = 0.0
	if is_node_ready():
		hands.cancel_reload()


## Show what's in your hands. animate: put away the old and draw the new if it
## changed (false when loading).
func _refresh_weapon_visuals(animate := true) -> void:
	if is_dead or not is_node_ready():
		return
	hands.show_held(held, animate)
	if is_gun(held):
		hands.set_empty(held, mags[held] == 0)


# --- Stamina & footsteps -----------------------------------------------------

func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		stamina = maxf(stamina - sprint_stamina_per_sec * delta, 0.0)
		stamina_regen_wait = STAMINA_REGEN_DELAY
	elif stamina_regen_wait > 0.0:
		stamina_regen_wait -= delta
	else:
		var regen := stamina_regen_per_sec * (0.5 if hunger >= hungry_at else 1.0)
		stamina = minf(stamina + regen * delta, max_stamina)


func _update_footsteps(delta: float, sprinting: bool) -> void:
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if not moving or is_crouching:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		make_noise(noise_sprint if sprinting else noise_walk)
		Sound.play_ui(self, "footstep", -6.0 if sprinting else -11.0, 0.12)
		step_timer = 0.3 if sprinting else 0.5


# --- Hunger ------------------------------------------------------------------

func _update_hunger(delta: float) -> void:
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night")
	var seconds_per_hour: float = day_night.seconds_per_game_hour if day_night else 120.0
	hunger = minf(hunger + hunger_per_game_hour * delta / seconds_per_hour, 100.0)

	var stage := _stage_for(hunger)
	if stage > _hunger_stage:
		notify.emit("You're getting hungry." if stage == 1 else "You're starving! Find something to eat.")
		_growl_timer = 0.0 # growl right away
	_hunger_stage = stage

	if stage >= 1:
		_growl_timer -= delta
		if _growl_timer <= 0.0:
			Sound.play_ui(self, "stomach_growl", -8.0 if stage == 1 else -3.0)
			_growl_timer = randf_range(40.0, 70.0) if stage == 1 else randf_range(15.0, 25.0)
	if stage == 2:
		# Not take_damage(): starving shouldn't flash red or close menus every frame.
		health = maxf(health - starving_damage_per_sec * delta, 0.0)
		if health <= 0.0:
			_die("starved")


func _stage_for(value: float) -> int:
	if value >= 100.0:
		return 2
	return 1 if value >= hungry_at else 0


# --- Lights (player_lights.gd) ------------------------------------------------

func _toggle_flashlight() -> void:
	lights.toggle()


## Puts the helmet lamp on or takes it off (the backpack).
func wear_lamp(on: bool) -> void:
	lights.wear_lamp(on)


func _update_flashlight(delta: float) -> void:
	lights.update(delta, held == "lantern" and not is_dead)
