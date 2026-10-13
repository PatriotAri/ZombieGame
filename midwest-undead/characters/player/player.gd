extends CharacterBody3D
## First-person survivor: movement, stamina, hunger, crouching, melee, guns
## (pistol, shotgun, scoped rifle; hold aim to look down the sights or through
## the scope), a battery-powered flashlight, an inventory, picking things up, trading, and the
## noise all of that makes.
## The node tree (camera, flashlight, weapon models) lives in player.tscn.
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
const Sound := preload("res://core/sound.gd")
const Settings := preload("res://core/settings.gd")
const Fortifications := preload("res://world/fortifications.gd")

@export_group("Movement")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
@export var jump_velocity := 4.5
## Meters per second up or down a ladder.
@export var climb_speed := 2.5

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
## Spare rounds on top of the 7 loaded in the pistol.
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
@export_group("Pistol")
@export var pistol_damage := 55.0
@export var pistol_range := 60.0
@export var pistol_cooldown := 0.3
@export var pistol_reload_time := 1.6
@export_group("Shotgun")
## Each pellet. A blast fires shotgun_pellets of them in a cone.
@export var shotgun_pellet_damage := 20.0
@export var shotgun_pellets := 9
@export var shotgun_range := 28.0
## Half-angle of the pellets' cone, in degrees: from the hip, and aiming.
@export var shotgun_spread := 5.0
@export var shotgun_aimed_spread := 3.5
@export var shotgun_cooldown := 0.95
@export var shotgun_reload_time := 2.6
@export_group("Rifle")
@export var rifle_damage := 140.0
@export var rifle_range := 160.0
## Degrees off where you point, from the hip. Through the scope it's dead on.
@export var rifle_hip_spread := 3.0
@export var rifle_cooldown := 1.3
@export var rifle_reload_time := 2.8
## Field of view through the scope (degrees; the normal view is 75).
@export_range(5.0, 60.0) var rifle_scope_fov := 20.0

const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STAMINA_REGEN_DELAY := 0.8 # seconds after exertion before stamina refills
const INTERACT_RANGE := 2.5
const PISTOL_MAG := 7
const SHOTGUN_MAG := 5
const RIFLE_MAG := 5
const AIM_SPEED := 10.0 # how fast the view zooms in and out
## Zoomed in further than this (degrees), the rifle's view is the scope's.
const SCOPE_FOV_THRESHOLD := 40.0

const FISTS := {"name": "Fists", "damage": 20.0, "range": 1.7, "cooldown": 0.45, "stamina": 8.0, "knockback": 2.0}
const CROWBAR := {"name": "Crowbar", "damage": 45.0, "range": 2.3, "cooldown": 0.7, "stamina": 15.0, "knockback": 4.0}

var health := 100.0 # set to max_health in _ready
var stamina := 100.0
var money := 0 # US dollars
var inventory := Inventory.new()
## Rounds loaded in each gun (not in the inventory). The pistol starts loaded.
var mags := {"pistol": PISTOL_MAG, "shotgun": 0, "rifle": 0}
var aiming := false # holding aim with a gun in your hands
## What's in your hands: "hands" (empty, you punch) or an item id with a "use"
## in game_data.gd. The use button does whatever that item does.
var held := "pistol"
var is_dead := false
## What killed you, for the death message: "bitten", "shot" or "starved".
var death_cause := ""
var is_crouching := false
var hunger := 20.0 # 0 = just ate, 100 = starving; set to starting_hunger in _ready
var flashlight_charge := 1.0 # what's left in the batteries in the flashlight, 0-1
var menu_open := false # set by the inventory/shop screens; freezes your controls

var prompt_text := "" # read by the HUD

# Nodes from player.tscn. @onready fills these in just before _ready runs.
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var weapon_pivot: Node3D = $Camera3D/WeaponPivot
@onready var fist_mesh: MeshInstance3D = $Camera3D/WeaponPivot/Fists
@onready var crowbar_mesh: MeshInstance3D = $Camera3D/WeaponPivot/Crowbar
@onready var pistol_pivot: Node3D = $Camera3D/PistolPivot
@onready var muzzle_flash: OmniLight3D = $Camera3D/PistolPivot/MuzzleFlash
var gun_pivots := {} # gun id -> its model in your hands (the shotgun's and rifle's are made in _ready)
var _gun_rest := Vector3.ZERO # where the gun models sit when you're not aiming
var _base_fov := 75.0
@onready var item_pivot: Node3D = $Camera3D/ItemPivot # health packs, food: anything you use up
@onready var held_item_mesh: MeshInstance3D = $Camera3D/ItemPivot/HeldItem

var attack_cooldown := 0.0
var reload_timer := 0.0
var reload_tween: Tween
var _use_left := 0.0 # time left bandaging / eating
var _use_tween: Tween
var _item_pivot_rest := Vector3.ZERO
var stamina_regen_wait := 0.0
var step_timer := 0.0
# Controller: sprint and crouch toggle with a press (holding a stick click or B
# while also steering both sticks isn't practical). Keyboard keys are held instead.
var sprint_latched := false
var crouch_latched := false
var suppress_next_attack := false # the click that re-grabs the mouse shouldn't fire
var _last_physics_frame := 0 # to notice when we've just come back from a pause or menu
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var day_night: Node # for hunger, which runs on in-game time
var _flashlight_energy := 1.0 # the beam's full brightness, from player.tscn
var _hunger_stage := 0 # 0 fed, 1 hungry, 2 starving: to announce each change once
var _growl_timer := 0.0
var _hurt_sound_wait := 0.0 # zombies hurt you every frame; grunt at most this often
var fortifications: Node # world/fortifications.gd, found through its group
var structures: Node # world/structures.gd, found through its group
var _build_view := {} # where the held piece would go this frame (structures.preview), or empty
var _ladders: Array[Area3D] = [] # the ladders you're touching (structures.gd tells us)
var salvage: Node # world/salvage.gd, found through its group
var _salvage_target: Node3D = null # what you're holding interact on with the crowbar
var _salvage_held := 0.0
var _salvage_sound_wait := 0.0
const SALVAGE_TAP := 0.3 # let go sooner than this and it's an ordinary interact
var _barricade_ghost: MeshInstance3D # where a held barricade would go
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	add_to_group("zombie_targets")
	health = max_health
	stamina = max_stamina
	hunger = starting_hunger
	_hunger_stage = _stage_for(hunger)
	money = starting_money
	inventory.add("pistol")
	inventory.add("pistol_ammo", starting_spare_ammo)
	inventory.add("batteries", starting_spare_batteries)
	inventory.add("planks", starting_planks)
	inventory.add("barricade", starting_barricades)
	_flashlight_energy = flashlight.light_energy
	_item_pivot_rest = item_pivot.position
	_base_fov = camera.fov
	_gun_rest = pistol_pivot.position
	gun_pivots = {"pistol": pistol_pivot, "shotgun": _make_long_gun(false), "rifle": _make_long_gun(true)}
	_refresh_weapon_visuals()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Zombies call this to decide whether you're worth chasing.
func is_targetable() -> bool:
	return not is_dead


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or menu_open:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(motion.relative * mouse_sensitivity * Settings.mouse_sensitivity * _zoom_factor())
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
		if held == "crowbar" and not _salvage_yield(target).is_empty():
			_salvage_target = target # a tap still opens it; holding strips it (_update_salvage)
			_salvage_held = 0.0
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


## Turn the body left/right and tilt only the head up/down.
func _look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	var inverted := invert_look_y != Settings.invert_y
	camera.rotate_x(-amount.y * (-1.0 if inverted else 1.0))
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_ladders = _ladders.filter(func(l: Area3D) -> bool: return is_instance_valid(l))
	var climbing := not _ladders.is_empty()
	if climbing:
		velocity.y = 0.0 # holding on: no falling (_climb moves you up and down)
	elif not is_on_floor():
		velocity.y -= gravity * delta

	_update_aim(delta)
	if menu_open:
		# Hands are busy: stand still, but the world keeps going.
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		move_and_slide()
		_update_stamina(delta, false)
		_update_hunger(delta)
		_update_flashlight(delta)
		_update_barricade_ghost() # hides it while a menu is up
		_update_build_view()
		_salvage_target = null
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
		_look(stick * stick_look_speed * Settings.stick_sensitivity * delta * _zoom_factor())

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

	is_crouching = Input.is_action_pressed("crouch") or crouch_latched
	var eye := CROUCH_EYE_HEIGHT if is_crouching else EYE_HEIGHT
	camera.position.y = move_toward(camera.position.y, eye, 4.0 * delta)

	if Input.is_action_just_pressed("jump") and not just_resumed and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() < 0.1:
		sprint_latched = false # stopping ends a controller sprint
	# transform.basis converts "forward relative to me" into world directions.
	# Not normalized, so a half-tilted stick walks at half speed.
	var direction := transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	var sprinting := (Input.is_action_pressed("sprint") or sprint_latched) and not is_crouching \
			and stamina > 0.0 and direction != Vector3.ZERO and not aiming
	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	if aiming:
		speed *= aim_move_factor
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	if climbing:
		_climb(input_dir)
	move_and_slide()

	_update_stamina(delta, sprinting)
	_update_hunger(delta)
	_update_flashlight(delta)
	_update_footsteps(delta, sprinting)
	_update_build_view()
	_update_salvage(delta)
	_update_prompt()
	_update_barricade_ghost()
	_hurt_sound_wait = maxf(_hurt_sound_wait - delta, 0.0)


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
	if _barricade_ghost:
		_barricade_ghost.visible = false
	_update_build_view() # hides the building preview
	_ladders.clear()
	flashlight.visible = false
	weapon_pivot.visible = false
	for pivot: Node3D in gun_pivots.values():
		pivot.visible = false
	item_pivot.visible = false
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
	var text := "Flashlight %d%%" % ceili(flashlight_charge * 100.0)
	if inventory.has("batteries"):
		text += "  (+%d batteries)" % inventory.count("batteries")
	return text


## Text for the HUD describing what's in your hands, e.g. "Pistol 5/7  (+12)".
func held_label() -> String:
	if is_gun(held):
		var gun := _gun(held)
		var text := "%s %d/%d  (+%d)" % [GameData.item_name(held), mags[held], gun["mag"], inventory.count(gun["ammo"])]
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
	attack_cooldown = 0.25 # short delay to raise the new item
	_refresh_weapon_visuals()


## Everything that listens (zombies, bandits) is told about the sound; each one
## decides whether it was close enough to hear it.
func make_noise(radius: float) -> void:
	get_tree().call_group("noise_listeners", "hear_noise", global_position, radius)


# --- Saving ------------------------------------------------------------------

## Everything about you that a save file needs, as plain data.
func save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": camera.rotation.x,
		"health": health,
		"stamina": stamina,
		"money": money,
		"inventory": inventory.to_dict(),
		"mags": mags.duplicate(),
		"held": held,
		"flashlight": flashlight.visible,
		"flashlight_charge": flashlight_charge,
		"hunger": hunger,
	}


func load_state(data: Dictionary) -> void:
	var pos: Array = data.get("position", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(data.get("yaw", rotation.y))
	camera.rotation.x = float(data.get("pitch", 0.0))
	health = float(data.get("health", max_health))
	stamina = float(data.get("stamina", max_stamina))
	money = int(data.get("money", money))
	inventory.from_dict(data.get("inventory", {}))
	var saved_mags: Dictionary = data.get("mags", {"pistol": data.get("pistol_mag", PISTOL_MAG)})
	for id: String in mags:
		mags[id] = clampi(int(saved_mags.get(id, 0)), 0, _gun(id)["mag"])
	flashlight_charge = clampf(float(data.get("flashlight_charge", 1.0)), 0.0, 1.0)
	flashlight.visible = bool(data.get("flashlight", false)) and flashlight_charge > 0.0
	hunger = clampf(float(data.get("hunger", starting_hunger)), 0.0, 100.0)
	_hunger_stage = _stage_for(hunger)
	var saved_held: String = data.get("held", "hands")
	held = saved_held if saved_held == "hands" or inventory.has(saved_held) else "hands"
	_refresh_weapon_visuals()


# --- Inventory ---------------------------------------------------------------

func give_item(id: String, amount := 1) -> void:
	inventory.add(id, amount)
	_refresh_weapon_visuals()


## Removes up to amount; returns how many actually left your inventory.
func take_item(id: String, amount := 1) -> int:
	var taken := inventory.remove(id, amount)
	if is_gun(id) and taken > 0 and not inventory.has(id):
		# Unload the gun as it leaves your hands, so the loaded rounds stay with you.
		inventory.add(_gun(id)["ammo"], mags[id])
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
			_try_board()
		"barricade":
			_try_barricade()
		"build":
			_try_build()


## Bandaging and eating take a moment: the item comes up toward your face, and
## the effect lands when the timer runs out (see _physics_process).
func _start_use(duration: float) -> void:
	if _use_left > 0.0 or attack_cooldown > 0.0:
		return
	_use_left = duration
	Sound.play_ui(self, "eat" if GameData.item_use(held) == "eat" else "bandage", -4.0)
	_use_tween = create_tween()
	_use_tween.tween_property(item_pivot, "position", Vector3(0.0, -0.15, -0.35), 0.2)


func _finish_use() -> void:
	_use_left = 0.0
	_reset_item_pivot()
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
	_reset_item_pivot()


func _reset_item_pivot() -> void:
	if _use_tween:
		_use_tween.kill()
	if is_node_ready():
		item_pivot.position = _item_pivot_rest


# --- Interaction (pick up / open / trade) ------------------------------------

func _looked_at() -> Node3D:
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
		prompt_text = _fortify_prompt()
	# With the crowbar, things you can strip for materials say so.
	var got := _salvage_yield(target) if held == "crowbar" else []
	if not got.is_empty():
		if _salvage_target == target and _salvage_held >= SALVAGE_TAP:
			prompt_text = "Salvaging...  %d%%" % roundi(100.0 * _salvage_held / float(salvage.get("TIME")))
		else:
			var line := "Hold %s: salvage %d %s" % [key, got[1], GameData.item_name(got[0]).to_lower()]
			prompt_text = line if prompt_text == "" else prompt_text + "   ·   " + line


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


## Anything (an NPC, the logbook...) with an interact_prompt() that isn't empty.
## Dead NPCs offer nothing.
func _offers_interaction(target: Node3D) -> bool:
	if target == null or not target.has_method("interact_prompt"):
		return false
	if target is HumanNPC and (target as HumanNPC).is_dead:
		return false
	return target.call("interact_prompt") != ""


# --- Fortifying (planks and barricades; see world/fortifications.gd) ---------------

func _fortifications() -> Node:
	if fortifications == null:
		fortifications = get_tree().get_first_node_in_group("fortifications")
	return fortifications


## The door or window you're aiming at (index into fortifications.openings), or -1.
## The first thing the ray hits must be the opening itself, not a wall in front of it.
func _aimed_opening() -> int:
	var fort := _fortifications()
	if fort == null:
		return -1
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * (INTERACT_RANGE + 0.5),
			GameData.LAYER_WORLD | GameData.LAYER_GLASS | GameData.LAYER_OPENINGS)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return fort.opening_of(hit["collider"]) if not hit.is_empty() else -1


## Where a held barricade would stand: a couple of meters ahead, on the ground,
## facing you.
func _barricade_transform() -> Transform3D:
	var forward := -global_basis.z
	forward.y = 0.0
	var spot := global_position + forward.normalized() * 2.2
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 3.0, GameData.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spot.y = (hit["position"] as Vector3).y
	return Transform3D(Basis(Vector3.UP, rotation.y), spot)


func _fortify_prompt() -> String:
	var fort := _fortifications()
	if fort == null:
		return ""
	var key := Controls.hint("use_held")
	if GameData.item_use(held) == "board":
		var index := _aimed_opening()
		if index >= 0 and not fort.is_boarded(index):
			return "%s: board up the %s" % [key, fort.describe(index)]
	elif held == "barricade":
		return "%s: place barricade" % key if fort.can_place_barricade(_barricade_transform()) else "No room for a barricade here"
	elif not _build_view.is_empty():
		return ("%s: %s" % [key, _build_view["text"]]) if _build_view["ok"] else _build_view["text"]
	return ""


func _try_board() -> void:
	var fort := _fortifications()
	var index := _aimed_opening()
	if fort == null or index < 0:
		notify.emit("Aim at a door or window to board it up.")
	elif fort.is_boarded(index):
		notify.emit("That's already boarded up.")
	else:
		fort.board(index, false, held == "used_planks")
		take_item(held)
		attack_cooldown = 0.6


func _try_barricade() -> void:
	var fort := _fortifications()
	var xform := _barricade_transform()
	if fort == null or not fort.can_place_barricade(xform):
		notify.emit("No room for a barricade there.")
		return
	fort.place_barricade(xform)
	take_item("barricade")
	attack_cooldown = 0.6


# --- Building (scaffolding, guard posts, fences; see world/structures.gd) ----------

func _structures() -> Node:
	if structures == null:
		structures = get_tree().get_first_node_in_group("structures")
	return structures


## Where the piece you're holding would go, and its see-through preview.
func _update_build_view() -> void:
	var builder := _structures()
	if builder == null:
		return
	if is_dead or menu_open or GameData.item_use(held) != "build":
		_build_view = {}
		builder.call("show_ghost", "", {})
		return
	var skip: Array[RID] = [get_rid()]
	_build_view = builder.call("preview", held, camera.global_position, -camera.global_basis.z, global_position, skip)
	builder.call("show_ghost", held, _build_view)


func _try_build() -> void:
	if _build_view.is_empty() or attack_cooldown > 0.0:
		return
	if not _build_view["ok"]:
		notify.emit(_build_view["text"] + ".")
		return
	_structures().call("build", held, _build_view["xform"], _build_view["on"])
	take_item(held)
	attack_cooldown = 0.6
	_update_build_view()


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
	if not is_on_floor() and global_position.y < top_y - 0.1:
		velocity.x = 0.0
		velocity.z = 0.0


# --- Salvaging (world/salvage.gd) --------------------------------------------------

## [item, amount] that thing would give you, or [].
func _salvage_yield(thing: Node3D) -> Array:
	if salvage == null:
		salvage = get_tree().get_first_node_in_group("salvage")
	if salvage == null or thing == null:
		return []
	return salvage.call("yield_of", thing)


## Holding interact on something with the crowbar: strip it once the bar fills.
## Let go early and it was just a press (open it as usual).
func _update_salvage(delta: float) -> void:
	if _salvage_target == null:
		return
	if not is_instance_valid(_salvage_target) or held != "crowbar" or _looked_at() != _salvage_target:
		_salvage_target = null # looked away or switched hands: cancelled
		return
	if not Input.is_action_pressed("interact"):
		if _salvage_held < SALVAGE_TAP:
			_interact()
		_salvage_target = null
		return
	_salvage_held += delta
	_salvage_sound_wait -= delta
	if _salvage_held >= SALVAGE_TAP and _salvage_sound_wait <= 0.0:
		_salvage_sound_wait = 0.6
		Sound.play_ui(self, "melee_hit", -6.0, 0.2) # prying and banging
		make_noise(float(salvage.get("NOISE")))
	if _salvage_held >= float(salvage.get("TIME")):
		var got: Array = salvage.call("strip", _salvage_target)
		_salvage_target = null
		if not got.is_empty():
			give_item(got[0], got[1])
			notify.emit("Salvaged %d %s." % [got[1], GameData.item_name(got[0]).to_lower()])


## Ladders (structures.gd calls these as you touch them and let go).
func enter_ladder(ladder: Area3D) -> void:
	if not ladder in _ladders:
		_ladders.append(ladder)


func exit_ladder(ladder: Area3D) -> void:
	_ladders.erase(ladder)


## A see-through preview of the barricade while you hold one: green where it fits,
## red where it doesn't.
func _update_barricade_ghost() -> void:
	var fort := _fortifications()
	var show := held == "barricade" and not is_dead and not menu_open and fort != null
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
		add_child(_barricade_ghost)
	_barricade_ghost.visible = show
	if show:
		var xform := _barricade_transform()
		_barricade_ghost.global_transform = xform * Transform3D(Basis.IDENTITY, Vector3(0, Fortifications.BARRICADE_SIZE.y / 2.0, 0))
		var ok: bool = fort.can_place_barricade(xform)
		_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.35)


# --- Weapons -----------------------------------------------------------------

func _melee_weapon() -> Dictionary:
	return CROWBAR if held == "crowbar" else FISTS


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
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation_degrees", Vector3(-70, 25, 0), 0.08)
	tween.tween_callback(_apply_melee_hit.bind(weapon))
	tween.tween_property(weapon_pivot, "rotation_degrees", Vector3.ZERO, 0.25)


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
		if to_target.length() > reach:
			continue
		if forward.dot(to_target.normalized()) < 0.6: # about a 100 degree swing arc
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, origin + to_target,
				GameData.LAYER_WORLD | GameData.LAYER_GLASS)
		if not space.intersect_ray(query).is_empty():
			continue # wall, car, or window in the way
		# call() because this script doesn't know the zombie script's functions.
		victim.call("take_hit", weapon["damage"], global_position, weapon["knockback"], self)
		hit_any = true
	if hit_any:
		make_noise(noise_melee_hit)
		Sound.play_ui(self, "melee_hit", -2.0, 0.15)


## The stats of a gun: its ammo, how many it holds, and how it shoots.
func _gun(id: String) -> Dictionary:
	match id:
		"shotgun":
			return {"ammo": "shotgun_shells", "mag": SHOTGUN_MAG, "damage": shotgun_pellet_damage,
					"pellets": shotgun_pellets, "range": shotgun_range, "spread": shotgun_spread,
					"aimed_spread": shotgun_aimed_spread, "cooldown": shotgun_cooldown, "reload": shotgun_reload_time,
					"aim_fov": 62.0, "noise": noise_gunshot * 1.3, "knockback": 2.5, "kick": 24.0,
					"sound": "shotgun_shot", "pitch": 1.0, "volume": 0.0}
		"rifle":
			return {"ammo": "rifle_rounds", "mag": RIFLE_MAG, "damage": rifle_damage, "pellets": 1,
					"range": rifle_range, "spread": rifle_hip_spread, "aimed_spread": 0.0,
					"cooldown": rifle_cooldown, "reload": rifle_reload_time, "aim_fov": rifle_scope_fov,
					"noise": noise_gunshot * 1.6, "knockback": 3.0, "kick": 18.0,
					"sound": "rifle_shot", "pitch": 1.0, "volume": 0.0}
	return {"ammo": "pistol_ammo", "mag": PISTOL_MAG, "damage": pistol_damage, "pellets": 1,
			"range": pistol_range, "spread": 0.0, "aimed_spread": 0.0, "cooldown": pistol_cooldown,
			"reload": pistol_reload_time, "aim_fov": 60.0, "noise": noise_gunshot, "knockback": 1.5,
			"kick": 14.0, "sound": "gunshot", "pitch": 1.0, "volume": 0.0}


static func is_gun(id: String) -> bool:
	return id in ["pistol", "shotgun", "rifle"]


## For the inventory and trade screens, e.g. "Shotgun  (3/5 loaded)".
func gun_text(id: String) -> String:
	return "%s  (%d/%d loaded)" % [GameData.item_name(id), mags[id], _gun(id)["mag"]]


## Looking through the rifle's scope (the HUD draws the scope over the screen).
func is_scoped() -> bool:
	return aiming and held == "rifle" and camera.fov < SCOPE_FOV_THRESHOLD


## Hold aim (right mouse / LT) with a gun: the view zooms in, the gun comes up to
## the middle of the screen, and you turn slower to match. Not while reloading.
func _update_aim(delta: float) -> void:
	aiming = is_gun(held) and Input.is_action_pressed("aim") and not menu_open and reload_timer <= 0.0
	var goal_fov: float = _gun(held)["aim_fov"] if aiming else _base_fov
	camera.fov = lerpf(camera.fov, goal_fov, minf(AIM_SPEED * delta, 1.0))
	if is_gun(held):
		var pivot: Node3D = gun_pivots[held]
		var goal := Vector3(0.0, -0.16, -0.4) if aiming else _gun_rest
		pivot.position = pivot.position.lerp(goal, minf(AIM_SPEED * delta, 1.0))
		pivot.visible = not is_scoped() # through the scope, the scope is all you see


## Zoomed in, the same mouse movement turns you less (so aiming stays steady).
func _zoom_factor() -> float:
	return camera.fov / _base_fov


## Hitscan: instant rays from the center of the screen (where the crosshair is),
## one per pellet, spread in a cone that's tighter when aiming.
func _try_shoot() -> void:
	if attack_cooldown > 0.0 or reload_timer > 0.0:
		return
	var gun := _gun(held)
	if mags[held] <= 0:
		attack_cooldown = 0.3
		Sound.play_ui(self, "dry_fire", -4.0)
		notify.emit("Empty. Press %s to reload." % Controls.hint("reload") if inventory.has(gun["ammo"]) else "Out of ammo.")
		return
	mags[held] -= 1
	attack_cooldown = gun["cooldown"]
	_gun_kick(gun["kick"])
	make_noise(gun["noise"])
	Sound.play_ui(self, gun["sound"], gun["volume"], 0.05, gun["pitch"])

	var spread := deg_to_rad(gun["aimed_spread"] if aiming else gun["spread"])
	var origin := camera.global_position
	var space := get_world_3d().direct_space_state
	var damage_to := {} # target -> total damage from this shot (pellets add up)
	for i in int(gun["pellets"]):
		# A random direction inside the cone: tilt off center, then spin round it.
		var dir := -camera.global_basis.z
		if spread > 0.0:
			var off := camera.global_basis.x.rotated(dir, randf() * TAU)
			dir = dir.rotated(off, sqrt(randf()) * spread)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * float(gun["range"]),
				GameData.LAYER_WORLD | GameData.LAYER_ZOMBIES | GameData.LAYER_NPC)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var target := hit["collider"] as Node3D
		if target and target.has_method("take_hit"):
			var hit_pos: Vector3 = hit["position"]
			var headshot := hit_pos.y - target.global_position.y > 1.4 # heads sit at ~1.4-1.8 m
			damage_to[target] = float(damage_to.get(target, 0.0)) + float(gun["damage"]) * (headshot_multiplier if headshot else 1.0)
	for target: Node3D in damage_to:
		if is_instance_valid(target):
			target.call("take_hit", damage_to[target], global_position, gun["knockback"], self)


func _start_reload() -> void:
	if not is_gun(held) or reload_timer > 0.0:
		return
	var gun := _gun(held)
	if mags[held] >= gun["mag"]:
		return
	if not inventory.has(gun["ammo"]):
		notify.emit("No %s." % GameData.item_name(gun["ammo"]).to_lower())
		return
	var pivot: Node3D = gun_pivots[held]
	var time: float = gun["reload"]
	reload_timer = time
	Sound.play_ui(self, "reload", -4.0, 0.0)
	reload_tween = create_tween()
	reload_tween.tween_property(pivot, "rotation_degrees", Vector3(-40, 0, 20), 0.25)
	reload_tween.tween_interval(maxf(time - 0.5, 0.0))
	reload_tween.tween_property(pivot, "rotation_degrees", Vector3.ZERO, 0.25)


func _finish_reload() -> void:
	if not is_gun(held):
		return
	var gun := _gun(held)
	mags[held] += inventory.remove(gun["ammo"], int(gun["mag"]) - int(mags[held]))


func _cancel_reload() -> void:
	reload_timer = 0.0
	if reload_tween:
		reload_tween.kill()
	for pivot: Node3D in gun_pivots.values():
		pivot.rotation_degrees = Vector3.ZERO


func _gun_kick(degrees: float) -> void:
	var pivot: Node3D = gun_pivots[held]
	pivot.rotation_degrees = Vector3(degrees, 0, 0)
	var tween := create_tween()
	tween.tween_property(pivot, "rotation_degrees", Vector3.ZERO, 0.15 + degrees / 100.0)
	var flash: OmniLight3D = pivot.get_node("MuzzleFlash")
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: flash.visible = false)


## The shotgun's or the rifle's model in your hands (the pistol's is in player.tscn).
func _make_long_gun(scoped: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "RiflePivot" if scoped else "ShotgunPivot"
	pivot.position = pistol_pivot.position
	pivot.visible = false
	camera.add_child(pivot)
	var wood := Color(0.36, 0.24, 0.14) if not scoped else Color(0.26, 0.2, 0.13)
	var steel := Color(0.16, 0.16, 0.18)
	var parts := [
		[Vector3(0.05, 0.05, 0.62), Vector3(0, 0.02, -0.28), steel], # barrel
		[Vector3(0.07, 0.09, 0.32), Vector3(0, -0.01, 0.05), steel], # receiver
		[Vector3(0.06, 0.1, 0.3), Vector3(0, -0.04, 0.32), wood], # stock
	]
	if scoped:
		parts.append([Vector3(0.05, 0.05, 0.24), Vector3(0, 0.1, -0.02), steel]) # scope
		parts.append([Vector3(0.02, 0.05, 0.02), Vector3(0, 0.06, -0.08), steel]) # its mounts
		parts.append([Vector3(0.02, 0.05, 0.02), Vector3(0, 0.06, 0.06), steel])
	else:
		parts.append([Vector3(0.07, 0.06, 0.2), Vector3(0, -0.04, -0.25), wood]) # pump
	for part: Array in parts:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = mat
		var inst := MeshInstance3D.new()
		inst.mesh = box
		inst.position = part[1]
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(inst)
	var flash := OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.position = Vector3(0, 0.02, -0.62)
	flash.light_color = muzzle_flash.light_color
	flash.light_energy = muzzle_flash.light_energy * 1.4
	flash.omni_range = muzzle_flash.omni_range
	flash.visible = false
	pivot.add_child(flash)
	return pivot


## Show the model for whatever's in your hands.
func _refresh_weapon_visuals() -> void:
	if is_dead or not is_node_ready():
		return
	var use := GameData.item_use(held)
	for id: String in gun_pivots:
		var pivot: Node3D = gun_pivots[id]
		pivot.visible = id == held
		pivot.position = _gun_rest
	weapon_pivot.visible = held == "hands" or held == "crowbar"
	fist_mesh.visible = held == "hands"
	crowbar_mesh.visible = held == "crowbar"
	# (Building pieces show nothing in your hands: the see-through preview of
	# where it'll go is what you look at.)
	item_pivot.visible = use in ["heal", "eat", "board", "barricade"]
	if item_pivot.visible:
		# Consumables reuse their ground-item look (size and color from game_data.gd),
		# a bit bigger since it's right in front of the camera.
		var def: Dictionary = GameData.ITEMS[held]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def["color"]
		var box := BoxMesh.new()
		box.size = (def["size"] as Vector3) * 1.2
		box.material = mat
		held_item_mesh.mesh = box


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


# --- Flashlight --------------------------------------------------------------

func _toggle_flashlight() -> void:
	Sound.play_ui(self, "flashlight_click", -8.0)
	if flashlight.visible:
		flashlight.visible = false
		return
	if flashlight_charge <= 0.0 and not _swap_batteries():
		notify.emit("The flashlight's dead. Find batteries.")
		return
	flashlight.visible = true


## Drains the batteries while it's on. Runs low: dims and flickers. Runs out:
## swaps in a spare set from your inventory, or goes dark.
func _update_flashlight(delta: float) -> void:
	if not flashlight.visible:
		return
	flashlight_charge = maxf(flashlight_charge - delta / battery_life, 0.0)
	if flashlight_charge <= 0.0:
		if _swap_batteries():
			notify.emit("Swapped in fresh batteries (%d left)." % inventory.count("batteries"))
		else:
			flashlight.visible = false
			notify.emit("The flashlight died.")
			return
	var energy := _flashlight_energy
	if flashlight_charge < low_battery:
		energy *= lerpf(0.35, 1.0, flashlight_charge / low_battery)
		if randf() < 0.05:
			energy *= 0.15 # flicker
	flashlight.light_energy = energy


func _swap_batteries() -> bool:
	if inventory.remove("batteries") == 0:
		return false
	flashlight_charge = 1.0
	Sound.play_ui(self, "battery_swap", -6.0)
	return true
