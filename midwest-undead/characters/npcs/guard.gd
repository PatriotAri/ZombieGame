extends HumanNPC
## A survivor on a guard tower with a rifle. Every so often it picks the nearest
## zombie it has a clear shot at and fires. If it's been given something to
## guard (the police station's front gate), it only shoots zombies that come
## within guard_radius of it; everywhere else is yours to deal with. Shots can miss, every shot is loud
## (pulling more zombies toward the station), and after a few rounds it has to
## stop and reload. It won't fire if you or another person is in the line of fire.
## TUNING: open guard.tscn, select the Guard node, and use the Inspector.

const Hearing := preload("res://world/hearing.gd")

@export_group("Rifle")
@export var fire_range := 45.0
## Only zombies this close (meters, along the ground) to what it guards are shot.
@export var guard_radius := 8.0
## Seconds between shots (each one varies +-15% so guards don't fire in sync).
@export var fire_interval := 1.6
@export_range(0.0, 1.0) var hit_chance := 0.75
## Zombies have 100 health, so 70 is two hits, or one headshot.
@export var damage := 70.0
@export_range(0.0, 1.0) var headshot_chance := 0.25
## Gunshots draw zombies within this radius toward the guard.
@export var noise_radius := 25.0
## Shots before reloading (a bolt-action hunting rifle).
@export_range(1, 30) var magazine_size := 5
## Seconds spent reloading with the rifle lowered.
@export var reload_time := 4.0

var exclude: Array[RID] = [] # set by world/people.gd: the guard's own tower, so its railing doesn't block its aim
## What it guards: a line on the ground from guard_from to guard_to (the gate's
## opening). Left at INF, it shoots anything in range.
var guard_from := Vector3.INF
var guard_to := Vector3.INF
var rounds := 5

var _cooldown := 0.0
var _reload_left := 0.0
var _aim_left := 0.0 # seconds it keeps the rifle up after its last target


## One of your survivors on a guard post (world/camps.gd) can be talked to.
func interact_prompt() -> String:
	return "talk to " + display_name if has_meta("survivor") else ""


func _npc_ready() -> void:
	rounds = magazine_size
	_cooldown = randf() * fire_interval


func _npc_physics(delta: float) -> void:
	_aim_left -= delta
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			rounds = magazine_size
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		_cooldown = 0.3 # nothing in sight: look again soon
		return
	_cooldown = fire_interval * randf_range(0.85, 1.15)
	_fire_at(target)


## Rifle up while there's been something to shoot lately, else held low.
func _animation() -> Array:
	if _aim_left > 0.0:
		return ["rifle_aim", 1.0]
	body.aim_pitch = 0.0
	return ["rifle_idle", 1.0]


func _eye() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


## Nearest zombie in range with a clear line of fire.
func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dist := fire_range
	var space := get_world_3d().direct_space_state
	var eye := _eye()
	# Exclude its own tower and itself; include people so it never shoots through them.
	var skip: Array[RID] = exclude.duplicate()
	skip.append(get_rid())
	var mask := GameData.LAYER_WORLD | GameData.LAYER_ZOMBIES | GameData.LAYER_PLAYER | GameData.LAYER_NPC
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Node3D
		# Quick: its aim point is within a couple of meters of its feet, so
		# one this far off can't be in range.
		if eye.distance_squared_to(zombie.global_position) > (best_dist + 2.0) ** 2 \
				or not _near_guarded(zombie.global_position):
			continue
		var aim: Vector3 = zombie.call("aim_point") if zombie.has_method("aim_point") else zombie.global_position + Vector3(0, 1.2, 0)
		var dist := eye.distance_to(aim)
		if dist >= best_dist:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, aim, mask, skip)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] != zombie:
			continue # wall, car, fence, another zombie, or a person in the way
		best = zombie
		best_dist = dist
	return best


## Within guard_radius of the guarded line (or there's nothing to guard).
func _near_guarded(pos: Vector3) -> bool:
	if guard_from == Vector3.INF:
		return true
	var a := Vector2(guard_from.x, guard_from.z)
	var b := Vector2(guard_to.x, guard_to.z)
	var p := Vector2(pos.x, pos.z)
	var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t)) <= guard_radius


func _fire_at(target: Node3D) -> void:
	var aim: Vector3 = target.call("aim_point") if target.has_method("aim_point") else target.global_position + Vector3(0, 1.2, 0)
	# Turn toward it. Skip when it's almost straight below, where look_at has no
	# sensible direction and would throw an error.
	var flat := Vector3(aim.x - global_position.x, 0.0, aim.z - global_position.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)
	_aim_at(aim)
	_aim_left = 3.0

	var end := aim
	if randf() < hit_chance:
		var headshot := randf() < headshot_chance
		var hit_pos: Vector3 = target.call("head_point") if headshot and target.has_method("head_point") else aim
		target.call("take_hit", damage * (2.5 if headshot else 1.0), muzzle(), 1.0, self, hit_pos)
	else:
		end += Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 1.0), randf_range(-1.5, 1.5))

	_tracer(muzzle(), end)
	Sound.play_at(self, "rifle_shot", muzzle(), 0.0, 90.0, 0.06)
	_flash_muzzle()
	body.one_shot("rifle_shoot")
	Hearing.make_noise(self, global_position, noise_radius)

	rounds -= 1
	if rounds <= 0:
		# Out of rounds: lower the rifle and reload. A gap the zombies can exploit.
		_reload_left = reload_time
		body.one_shot("rifle_reload", reload_time)
