extends CharacterBody3D
## First-person survivor: movement, stamina, crouching, melee, the pistol,
## an inventory, picking things up, trading, and the noise all of that makes.
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

@export_group("Movement")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
@export var jump_velocity := 4.5

@export_group("Look")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.002
## Right-stick turn speed at full tilt, in radians per second.
@export_range(0.5, 10.0, 0.1) var stick_look_speed := 3.0
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

@export_group("Pistol")
@export var pistol_damage := 55.0
@export var headshot_multiplier := 2.5
@export var pistol_range := 60.0
@export var pistol_cooldown := 0.3
@export var pistol_reload_time := 1.6

const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STAMINA_REGEN_DELAY := 0.8 # seconds after exertion before stamina refills
const INTERACT_RANGE := 2.5
const PISTOL_MAG := 7

const FISTS := {"name": "Fists", "damage": 20.0, "range": 1.7, "cooldown": 0.45, "stamina": 8.0, "knockback": 2.0}
const CROWBAR := {"name": "Crowbar", "damage": 45.0, "range": 2.3, "cooldown": 0.7, "stamina": 15.0, "knockback": 4.0}

var health := 100.0 # set to max_health in _ready
var stamina := 100.0
var money := 0 # US dollars
var inventory := Inventory.new()
var pistol_mag := PISTOL_MAG # rounds loaded in the gun (not in the inventory)
## What's in your hands: "hands" (empty, you punch) or an item id with a "use"
## in game_data.gd. The use button does whatever that item does.
var held := "pistol"
var is_dead := false
var is_crouching := false
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


func _ready() -> void:
	add_to_group("player")
	add_to_group("zombie_targets")
	health = max_health
	stamina = max_stamina
	money = starting_money
	inventory.add("pistol")
	inventory.add("pistol_ammo", starting_spare_ammo)
	_item_pivot_rest = item_pivot.position
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
		_look(motion.relative * mouse_sensitivity)
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
		_interact()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
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
		# Number keys pick a hotbar slot directly.
		for i in range(1, 10):
			if event.is_action_pressed("slot_%d" % i):
				var bar := hotbar()
				if i <= bar.size():
					select(bar[i - 1])
				break


## Turn the body left/right and tilt only the head up/down.
func _look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	camera.rotate_x(-amount.y * (-1.0 if invert_look_y else 1.0))
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if menu_open:
		# Hands are busy: stand still, but the world keeps going.
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		move_and_slide()
		_update_stamina(delta, false)
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
		_look(stick * stick_look_speed * delta)

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
			and stamina > 0.0 and direction != Vector3.ZERO
	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()

	_update_stamina(delta, sprinting)
	_update_footsteps(delta, sprinting)
	_update_prompt()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	damaged.emit()
	if _use_left > 0.0:
		_cancel_use()
		notify.emit("Interrupted!") # can't bandage up or eat while something's biting you
	if health <= 0.0:
		is_dead = true
		flashlight.visible = false
		weapon_pivot.visible = false
		pistol_pivot.visible = false
		item_pivot.visible = false
		camera.position.y = 0.3 # collapse to the ground
		died.emit()


## Text for the HUD describing what's in your hands, e.g. "Pistol 5/7  (+12)".
func held_label() -> String:
	match held:
		"pistol":
			var text := "Pistol %d/%d  (+%d)" % [pistol_mag, PISTOL_MAG, inventory.count("pistol_ammo")]
			return text + "  reloading..." if reload_timer > 0.0 else text
		"hands":
			return "Fists"
	var label := GameData.item_name(held)
	if inventory.count(held) > 1:
		label += " x%d" % inventory.count(held)
	if _use_left > 0.0:
		label += "  eating..." if GameData.item_use(held) == "eat" else "  bandaging..."
	return label


## Everything you can hold, in hotbar order: empty hands first, then each usable
## item you're carrying (ammo and batteries can't be held, so they're skipped).
func hotbar() -> Array[String]:
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
		"pistol_mag": pistol_mag,
		"held": held,
		"flashlight": flashlight.visible,
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
	pistol_mag = int(data.get("pistol_mag", PISTOL_MAG))
	flashlight.visible = bool(data.get("flashlight", false))
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
	if id == "pistol" and taken > 0 and not inventory.has("pistol"):
		# Unload the gun as it leaves your hands, so the loaded rounds stay with you.
		inventory.add("pistol_ammo", pistol_mag)
		pistol_mag = 0
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


## Step through the hotbar (wheel, Y, D-pad left/right). Wraps around.
func _cycle(step: int) -> void:
	var bar := hotbar()
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


## Bandaging and eating take a moment: the item comes up toward your face, and
## the effect lands when the timer runs out (see _physics_process).
func _start_use(duration: float) -> void:
	if _use_left > 0.0 or attack_cooldown > 0.0:
		return
	_use_left = duration
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
	return hit["collider"] as Node3D


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


func _interact() -> void:
	var target := _looked_at()
	if target is GroundItem:
		var item := target as GroundItem
		give_item(item.item_id, item.amount)
		notify.emit("Picked up " + item.get_label())
		item.queue_free()
	elif target is LootSpot:
		var spot := target as LootSpot
		if spot.open():
			make_noise(noise_search) # rummaging isn't quiet
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

	# Quick strike, damage lands at the end of it, then a slower return.
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation_degrees", Vector3(-70, 25, 0), 0.08)
	tween.tween_callback(_apply_melee_hit.bind(weapon))
	tween.tween_property(weapon_pivot, "rotation_degrees", Vector3.ZERO, 0.25)


## Hits every zombie or person in range, roughly in front of you, and not behind a
## wall. Friendly NPCs ignore your hits (see HumanNPC.player_can_hurt).
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
		var query := PhysicsRayQueryParameters3D.create(origin, origin + to_target, GameData.LAYER_WORLD)
		if not space.intersect_ray(query).is_empty():
			continue # wall or car in the way
		# call() because this script doesn't know the zombie script's functions.
		victim.call("take_hit", weapon["damage"], global_position, weapon["knockback"], self)
		hit_any = true
	if hit_any:
		make_noise(noise_melee_hit)


## Hitscan: an instant ray from the center of the screen (where the crosshair is).
func _try_shoot() -> void:
	if attack_cooldown > 0.0 or reload_timer > 0.0:
		return
	if pistol_mag <= 0:
		attack_cooldown = 0.3
		notify.emit("Empty. Press %s to reload." % Controls.hint("reload") if inventory.has("pistol_ammo") else "Out of ammo.")
		return
	pistol_mag -= 1
	attack_cooldown = pistol_cooldown
	_pistol_kick()
	make_noise(noise_gunshot)

	var origin := camera.global_position
	var end := origin - camera.global_basis.z * pistol_range
	var query := PhysicsRayQueryParameters3D.create(origin, end,
			GameData.LAYER_WORLD | GameData.LAYER_ZOMBIES | GameData.LAYER_NPC)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target := hit["collider"] as Node3D
	if target and target.has_method("take_hit"):
		var hit_pos: Vector3 = hit["position"]
		var headshot := hit_pos.y - target.global_position.y > 1.4 # heads sit at ~1.4-1.8 m
		var damage := pistol_damage * (headshot_multiplier if headshot else 1.0)
		target.call("take_hit", damage, global_position, 1.5, self)


func _start_reload() -> void:
	if held != "pistol" or reload_timer > 0.0 or pistol_mag >= PISTOL_MAG:
		return
	if not inventory.has("pistol_ammo"):
		notify.emit("No pistol ammo.")
		return
	reload_timer = pistol_reload_time
	reload_tween = create_tween()
	reload_tween.tween_property(pistol_pivot, "rotation_degrees", Vector3(-40, 0, 20), 0.25)
	reload_tween.tween_interval(maxf(pistol_reload_time - 0.5, 0.0))
	reload_tween.tween_property(pistol_pivot, "rotation_degrees", Vector3.ZERO, 0.25)


func _finish_reload() -> void:
	pistol_mag += inventory.remove("pistol_ammo", PISTOL_MAG - pistol_mag)


func _cancel_reload() -> void:
	reload_timer = 0.0
	if reload_tween:
		reload_tween.kill()
	pistol_pivot.rotation_degrees = Vector3.ZERO


func _pistol_kick() -> void:
	pistol_pivot.rotation_degrees = Vector3(14, 0, 0)
	var tween := create_tween()
	tween.tween_property(pistol_pivot, "rotation_degrees", Vector3.ZERO, 0.15)
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: muzzle_flash.visible = false)


## Show the model for whatever's in your hands.
func _refresh_weapon_visuals() -> void:
	if is_dead or not is_node_ready():
		return
	var use := GameData.item_use(held)
	pistol_pivot.visible = held == "pistol"
	weapon_pivot.visible = held == "hands" or held == "crowbar"
	fist_mesh.visible = held == "hands"
	crowbar_mesh.visible = held == "crowbar"
	item_pivot.visible = use == "heal" or use == "eat"
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
		stamina = minf(stamina + stamina_regen_per_sec * delta, max_stamina)


func _update_footsteps(delta: float, sprinting: bool) -> void:
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if not moving or is_crouching:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		make_noise(noise_sprint if sprinting else noise_walk)
		step_timer = 0.3 if sprinting else 0.5
