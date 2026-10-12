extends HumanNPC
## A hostile survivor guarding a camp. Bandits stay within leash_radius of their
## camp (main.gd sets `home`), so they never wander off to the police station or
## the safe house. Each one shoots the closest enemy it can see: you, or any
## zombie that gets too close. Gunshots are loud, which can pull zombies into
## the fight; and zombies happily go after bandits too.
## When a bandit dies it drops what it was carrying.
## TUNING: open bandit.tscn, select the Bandit node, and use the Inspector.

enum State { IDLE, ALERT, COMBAT }

const GroundItem := preload("res://items/ground_item.gd")

@export_group("Senses")
@export var sight_range := 25.0 ## In daylight.
@export_range(0.0, 1.0) var night_sight_factor := 0.5
## Never strays farther than this from camp, whatever it's chasing.
@export var leash_radius := 15.0

@export_group("Gun")
@export var fire_range := 25.0
@export var fire_interval := 1.2
## Chance a shot hits at point-blank range. It falls off with distance, and is
## cut further if you're moving: these are scavengers, not marksmen.
@export_range(0.0, 1.0) var hit_chance := 0.5
@export var damage := 10.0
## Seconds between first spotting someone and opening fire.
@export var reaction_time := 1.0
@export_range(1, 30) var magazine_size := 8
@export var reload_time := 2.5
## Their gunshots draw zombies (and other bandits) within this radius.
@export var noise_radius := 25.0

@export_group("Movement")
@export var move_speed := 3.0

const EYE_HEIGHT := 1.6
const SENSE_INTERVAL := 0.25
const ALERT_TIME := 6.0 # how long it stays on edge after hearing something

var home := Vector3.ZERO # camp center, set by main.gd before the bandit is added
var drop_loot_on_death := true # off when restoring an already-dead bandit from a save
var state := State.IDLE
var target: Node3D = null
var rounds := 8

var _sense_timer := 0.0
var _cooldown := 0.0
var _reload_left := 0.0
var _alert_pos := Vector3.ZERO
var _alert_timer := 0.0
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _day_night: Node

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var gun: Node3D = $Gun
@onready var muzzle_flash: OmniLight3D = $Gun/MuzzleFlash


func _npc_ready() -> void:
	add_to_group("bandits")
	add_to_group("noise_listeners")
	rounds = magazine_size
	_sense_timer = randf() * SENSE_INTERVAL
	_cooldown = randf() * fire_interval
	_wander_target = global_position
	_wander_timer = randf_range(2.0, 6.0)


func _npc_physics(delta: float) -> void:
	_cooldown -= delta
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			rounds = magazine_size
			gun.rotation_degrees = Vector3.ZERO

	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = SENSE_INTERVAL
		_pick_target()

	var move_to := Vector3.INF
	var move_speed_now := move_speed
	match state:
		State.COMBAT:
			var dist := global_position.distance_to(target.global_position)
			_face(target.global_position)
			if dist > fire_range * 0.8:
				move_to = target.global_position # close the distance (within the leash)
			if dist <= fire_range and _cooldown <= 0.0 and _reload_left <= 0.0:
				_shoot_at(target)
		State.ALERT:
			move_to = _alert_pos
			_alert_timer -= delta
			if _alert_timer <= 0.0:
				state = State.IDLE
		State.IDLE:
			# Mill around camp.
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(4.0, 9.0)
				_wander_target = home + Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
			move_to = _wander_target
			move_speed_now = move_speed * 0.4

	_walk(move_to, move_speed_now)


## Zombies, the player, and other bandits all call this through the
## "noise_listeners" group whenever they make a sound.
func hear_noise(pos: Vector3, radius: float) -> void:
	if is_dead or state == State.COMBAT:
		return
	if global_position.distance_to(pos) <= radius:
		state = State.ALERT
		_alert_pos = pos
		_alert_timer = ALERT_TIME


## Getting shot reveals the shooter, if it wasn't already fighting someone.
func take_hit(amount: float, from_pos: Vector3, knockback: float, attacker: Node3D = null) -> void:
	super(amount, from_pos, knockback, attacker)
	if is_dead or state == State.COMBAT:
		return
	if attacker != null and _is_enemy(attacker):
		target = attacker
		state = State.COMBAT
	else:
		hear_noise(from_pos, INF)


func die() -> void:
	if is_dead:
		return
	super()
	if drop_loot_on_death:
		_drop_loot()


# --- Targeting ---------------------------------------------------------------

## The closest enemy it can see right now: the player or a zombie.
func _pick_target() -> void:
	var best: Node3D = null
	var best_dist := INF
	var candidates: Array[Node] = get_tree().get_nodes_in_group("zombies")
	var player := get_tree().get_first_node_in_group("player")
	if player:
		candidates.append(player)
	for node in candidates:
		var candidate := node as Node3D
		if not _is_enemy(candidate):
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist < best_dist and _can_see(candidate, dist):
			best = candidate
			best_dist = dist
	if best:
		if state != State.COMBAT:
			# Just spotted them: a moment to react ("Hey!") before the first shot.
			_cooldown = maxf(_cooldown, reaction_time * randf_range(0.8, 1.5))
		target = best
		state = State.COMBAT
	elif state == State.COMBAT:
		# Lost sight of everyone: go check where the last one was.
		state = State.ALERT
		_alert_pos = target.global_position if is_instance_valid(target) else global_position
		_alert_timer = ALERT_TIME
		target = null


func _is_enemy(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("player"):
		return not node.get("is_dead")
	return node.is_in_group("zombies") # (dead zombies leave the group)


func _can_see(candidate: Node3D, dist: float) -> bool:
	var light := 1.0
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
	if _day_night:
		light = _day_night.call("light_level")
	var sight := sight_range * lerpf(night_sight_factor, 1.0, light)
	if candidate.is_in_group("player"):
		if candidate.get("is_crouching"):
			sight *= 0.6
		var torch: Node = candidate.get("flashlight")
		if torch and torch.get("visible"):
			sight = maxf(sight, sight_range * 1.2)
	if dist > sight:
		return false
	return _clear_shot(candidate)


## Is the first thing along the line from its eyes to the candidate's chest the
## candidate itself? (Glass isn't in the mask, so it sees and shoots through windows.)
func _clear_shot(candidate: Node3D) -> bool:
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var aim := candidate.global_position + Vector3(0, 1.1, 0)
	var mask := GameData.LAYER_WORLD | GameData.LAYER_PLAYER | GameData.LAYER_ZOMBIES | GameData.LAYER_NPC
	var query := PhysicsRayQueryParameters3D.create(eye, aim, mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == candidate


# --- Shooting ----------------------------------------------------------------

func _shoot_at(enemy: Node3D) -> void:
	if not _clear_shot(enemy):
		return
	_cooldown = fire_interval * randf_range(0.8, 1.25)
	var aim := enemy.global_position + Vector3(0, 1.1, 0)
	var to_aim := aim - gun.global_position
	if to_aim.length() > 0.1:
		gun.look_at(aim, Vector3.FORWARD if absf(to_aim.normalized().y) > 0.99 else Vector3.UP)

	var end := aim
	var dist := global_position.distance_to(enemy.global_position)
	var chance := hit_chance * clampf(1.0 - dist / (fire_range * 1.5), 0.15, 1.0)
	var enemy_velocity: Variant = enemy.get("velocity")
	if enemy_velocity is Vector3 and Vector2(enemy_velocity.x, enemy_velocity.z).length() > 2.0:
		chance *= 0.7 # harder to hit someone on the move
	if randf() < chance:
		if enemy.is_in_group("player"):
			enemy.call("take_damage", damage)
		else:
			enemy.call("take_hit", damage, global_position, 0.8, self)
	else:
		end += Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 0.9), randf_range(-1.2, 1.2))

	_tracer(gun.global_transform * Vector3(0, 0, -0.35), end)
	Sound.play_at(self, "gunshot", gun.global_position, -2.0, 70.0, 0.08)
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: muzzle_flash.visible = false)
	get_tree().call_group("noise_listeners", "hear_noise", global_position, noise_radius)

	rounds -= 1
	if rounds <= 0:
		_reload_left = reload_time
		gun.rotation_degrees = Vector3(-50, 0, 0)


# --- Movement ----------------------------------------------------------------

## Walk toward a point along the navmesh, but never past the edge of the leash.
func _walk(point: Vector3, walk_speed: float) -> void:
	var map := agent.get_navigation_map()
	if point == Vector3.INF or NavigationServer3D.map_get_iteration_id(map) == 0:
		_stop()
		return
	var from_home := point - home
	from_home.y = 0.0
	if from_home.length() > leash_radius:
		point = home + from_home.normalized() * leash_radius
	agent.target_position = point
	if agent.is_navigation_finished():
		_stop()
		return
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_stop()
		return
	dir = dir.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	if state != State.COMBAT:
		_face(global_position + dir)


func _stop() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)


## What it was carrying ends up on the ground next to the body.
func _drop_loot() -> void:
	var drops: Array = [["pistol_ammo", randi_range(4, 9)]]
	if randf() < 0.35:
		drops.append(["health_pack", 1])
	if randf() < 0.4:
		drops.append(["canned_food", 1])
	var i := 0
	for drop in drops:
		var item := GroundItem.new()
		var offset := Vector3(cos(i * 2.1), 0.0, sin(i * 2.1)) * 0.7
		item.position = Vector3(global_position.x, 0.02, global_position.z) + offset
		item.setup(drop[0], drop[1])
		get_parent().add_child.call_deferred(item) # deferred: may be mid-physics
		i += 1
