extends CharacterBody3D
## A shambler with three moods:
##   IDLE        - shuffles around near where it stands
##   INVESTIGATE - heard something, or lost sight of its target; walks there and lingers
##   HUNT        - chasing the closest target it can currently see
## Targets are anything in the "zombie_targets" group (the player and the guards).
## Every sense tick it re-picks the closest visible target, so getting shot doesn't
## pull it off whoever it's already chasing; damage only matters if it had no target.
## Sight needs a clear line (buildings and cars block it), mostly in front of it.
## Sound goes through walls. The node tree lives in zombie.tscn.
## TUNING: open zombie.tscn, select the Zombie node, and use the Inspector.

const Player := preload("res://player.gd")
const GameData := preload("res://game_data.gd")

enum State { IDLE, INVESTIGATE, HUNT }

@export var max_health := 100.0
@export_range(1.0, 100.0) var sight_range := 20.0 ## In daylight.
## Sight range multiplier at full night (0.45 = 9 m out of 20).
@export_range(0.0, 1.0) var night_sight_factor := 0.45
@export var damage_per_second := 20.0
## Each zombie picks a random walking speed in this range.
@export var min_speed := 1.2
@export var max_speed := 2.2
## Seconds it keeps searching a spot before losing interest.
@export var linger_time := 4.0

const VIEW_DOT := 0.5 # cos(60 degrees): it sees a 120 degree cone in front of it
const PROXIMITY_RANGE := 2.0 # this close, it notices you no matter what
const EYE_HEIGHT := 1.6
const ATTACK_RANGE := 1.3
const ATTACK_HEIGHT := 1.5 # can't bite something more than this far above or below it
const SENSE_INTERVAL := 0.2 # sight checks are raycasts; 5 per second is plenty
const REPATH_INTERVAL := 0.3

var state := State.IDLE
var health := 100.0 # set to max_health in _ready
var is_dead := false
var speed := 1.6
var target: Node3D = null # who it's hunting
var day_night: Node
var materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []

var investigate_pos := Vector3.ZERO
var last_seen_pos := Vector3.ZERO
var wander_target := Vector3.ZERO
var linger_timer := 0.0
var wander_timer := 0.0
var sense_timer := 0.0
var repath_timer := 0.0
var stagger_timer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual # all meshes hang off this, so they can tip over on death
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var clothes: MeshInstance3D = $Visual/Body


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("noise_listeners")
	speed = randf_range(min_speed, maxf(max_speed, min_speed)) # some shuffle, some lurch
	health = max_health
	# Stagger timers so dozens of zombies don't all raycast and repath on the same frame.
	sense_timer = randf() * SENSE_INTERVAL
	repath_timer = randf() * REPATH_INTERVAL
	wander_timer = randf_range(1.0, 6.0)
	wander_target = global_position
	_unique_materials()


## Materials in a scene are shared by every instance, so flashing one zombie would
## flash them all. Give this zombie its own copies, and its own shirt color.
func _unique_materials() -> void:
	for child in visual.get_children():
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null:
			continue
		var mat := (mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		if mesh_inst == clothes:
			mat.albedo_color = Color.from_hsv(randf(), 0.3, 0.35)
		mesh_inst.material_override = mat
		materials.append(mat)
		base_colors.append(mat.albedo_color)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Reeling from a hit: just slide with the knockback.
	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	sense_timer -= delta
	if sense_timer <= 0.0:
		sense_timer = SENSE_INTERVAL
		_update_sight()

	var moving := false
	match state:
		State.HUNT:
			if not _is_valid_target(target):
				_set_idle()
			else:
				var to_target := _flat(target.global_position - global_position)
				if to_target.length() > ATTACK_RANGE * 0.8:
					moving = _walk_to(target.global_position, speed, delta)
				else:
					_face(to_target)
				var height_gap := absf(target.global_position.y - global_position.y)
				if to_target.length() < ATTACK_RANGE and height_gap < ATTACK_HEIGHT \
						and target.has_method("take_damage"):
					target.call("take_damage", damage_per_second * delta)
		State.INVESTIGATE:
			moving = _walk_to(investigate_pos, speed, delta)
			if not moving:
				linger_timer -= delta
				if linger_timer <= 0.0:
					_set_idle()
		State.IDLE:
			wander_timer -= delta
			if wander_timer <= 0.0:
				wander_timer = randf_range(4.0, 9.0)
				wander_target = global_position + Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
			moving = _walk_to(wander_target, speed * 0.35, delta)

	if not moving:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()


# --- Senses ------------------------------------------------------------------

## Called (through the "zombies" group) whenever someone makes a sound.
func hear_noise(pos: Vector3, radius: float) -> void:
	if is_dead or state == State.HUNT:
		return
	if global_position.distance_to(pos) <= radius:
		_investigate(pos)


## Re-pick the closest target it can see right now.
func _update_sight() -> void:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("zombie_targets"):
		var candidate := node as Node3D
		if not _is_valid_target(candidate):
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist < best_dist and _can_see(candidate, dist):
			best = candidate
			best_dist = dist
	if best:
		target = best
		state = State.HUNT
		last_seen_pos = best.global_position
	elif state == State.HUNT:
		target = null
		_investigate(last_seen_pos) # lost sight of everyone: check where it last saw its target


func _is_valid_target(node: Node3D) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("is_targetable") \
			and node.call("is_targetable")


func _can_see(candidate: Node3D, dist: float) -> bool:
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var aim := candidate.global_position + Vector3(0, 1.0, 0)
	# Up close it notices you whichever way it's facing, but still not through walls.
	if dist < PROXIMITY_RANGE:
		return _clear_line(eye, aim, candidate)

	# Darkness shrinks how far it can see. The player can also crouch to be harder
	# to spot, and a lit flashlight is visible from far away day or night.
	var light := 1.0
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night")
	if day_night:
		light = day_night.call("light_level")
	var sight := sight_range * lerpf(night_sight_factor, 1.0, light)
	var player := candidate as Player
	if player:
		if player.is_crouching:
			sight *= 0.5
		if player.flashlight.visible:
			sight = maxf(sight, sight_range * 1.3)
	if dist > sight:
		return false

	# The one it's already chasing stays tracked even if its path turns it away briefly.
	var forward := -global_basis.z
	if not (state == State.HUNT and candidate == target) \
			and forward.dot(_flat(aim - eye).normalized()) < VIEW_DOT:
		return false

	return _clear_line(eye, aim, candidate)


## Is anything solid between its eyes and the candidate? Other zombies and glass
## aren't in the mask, so they don't block the view.
func _clear_line(eye: Vector3, aim: Vector3, candidate: Node3D) -> bool:
	var mask := GameData.LAYER_WORLD | GameData.LAYER_PLAYER | GameData.LAYER_NPC
	var query := PhysicsRayQueryParameters3D.create(eye, aim, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == candidate


func _investigate(pos: Vector3) -> void:
	state = State.INVESTIGATE
	investigate_pos = pos
	linger_timer = linger_time
	repath_timer = 0.0


func _set_idle() -> void:
	state = State.IDLE
	target = null
	wander_timer = randf_range(2.0, 5.0)
	wander_target = global_position


# --- Combat ------------------------------------------------------------------

## Called by the player's attacks and by guards. The attacker only becomes the
## target if the zombie wasn't already chasing someone.
func take_hit(damage: float, from_pos: Vector3, knockback: float, attacker: Node3D = null) -> void:
	if is_dead:
		return
	health -= damage
	var away := _flat(global_position - from_pos).normalized()
	velocity.x = away.x * knockback
	velocity.z = away.z * knockback
	stagger_timer = 0.4
	_flash()
	if health <= 0.0:
		_die()
		return
	if state == State.HUNT and _is_valid_target(target):
		return # stay on its current target
	if _is_valid_target(attacker):
		target = attacker
		state = State.HUNT
		last_seen_pos = attacker.global_position
	else:
		_investigate(from_pos)


func _die() -> void:
	is_dead = true
	target = null
	remove_from_group("zombies") # stops hearing, being hit, and being targeted
	collision.set_deferred("disabled", true) # deferred: physics may be mid-step
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(visual, "rotation:x", PI / 2.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) # topple backward
	tween.parallel().tween_property(visual, "position:y", 0.3, 0.6)


func _flash() -> void:
	var tween := create_tween().set_parallel(true)
	for i in materials.size():
		materials[i].albedo_color = Color(1.0, 0.85, 0.85)
		tween.tween_property(materials[i], "albedo_color", base_colors[i], 0.25)


# --- Movement ----------------------------------------------------------------

## Steps along a navigation path toward a point. Returns false once arrived (or no path).
func _walk_to(point: Vector3, move_speed: float, delta: float) -> bool:
	if not _navigation_ready():
		return false
	repath_timer -= delta
	if repath_timer <= 0.0 or point.distance_squared_to(agent.target_position) > 1.0:
		agent.target_position = point
		repath_timer = REPATH_INTERVAL
	if agent.is_navigation_finished():
		return false
	var dir := _flat(agent.get_next_path_position() - global_position)
	if dir.length() < 0.05:
		return false
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face(dir)
	return true


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		look_at(global_position + dir.normalized(), Vector3.UP)


## The navigation map updates at the end of a physics frame, so on the very first
## frame it's still empty and path queries would fail with an error.
func _navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
