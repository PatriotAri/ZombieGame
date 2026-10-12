extends HumanNPC
## A survivor on a guard tower with a rifle. Every so often it picks the nearest
## zombie it has a clear shot at and fires. Shots can miss, every shot is loud
## (pulling more zombies toward the station), and after a few rounds it has to
## stop and reload. It won't fire if you or another person is in the line of fire.
## TUNING: open guard.tscn, select the Guard node, and use the Inspector.

@export_group("Rifle")
@export var fire_range := 45.0
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

var exclude: Array[RID] = [] # set by main.gd: the guard's own tower, so its railing doesn't block its aim
var rounds := 5

var _cooldown := 0.0
var _reload_left := 0.0

@onready var rifle: Node3D = $Rifle
@onready var muzzle_flash: OmniLight3D = $Rifle/MuzzleFlash


func _npc_ready() -> void:
	rounds = magazine_size
	_cooldown = randf() * fire_interval


func _npc_physics(delta: float) -> void:
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			rounds = magazine_size
			rifle.rotation_degrees = Vector3.ZERO
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
		var aim := zombie.global_position + Vector3(0, 1.2, 0)
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


func _fire_at(target: Node3D) -> void:
	var aim := target.global_position + Vector3(0, 1.2, 0)
	# Turn toward it. Skip when it's almost straight below, where look_at has no
	# sensible direction and would throw an error.
	var flat := Vector3(aim.x - global_position.x, 0.0, aim.z - global_position.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)
	var to_aim := aim - rifle.global_position
	if to_aim.length() > 0.1:
		rifle.look_at(aim, Vector3.FORWARD if absf(to_aim.normalized().y) > 0.99 else Vector3.UP)

	var end := aim
	if randf() < hit_chance:
		var headshot := randf() < headshot_chance
		target.call("take_hit", damage * (2.5 if headshot else 1.0), global_position, 1.0, self)
	else:
		end += Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 1.0), randf_range(-1.5, 1.5))

	var muzzle := rifle.global_transform * Vector3(0, 0, -0.9)
	_tracer(muzzle, end)
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: muzzle_flash.visible = false)
	get_tree().call_group("noise_listeners", "hear_noise", global_position, noise_radius)

	rounds -= 1
	if rounds <= 0:
		# Out of rounds: lower the rifle and reload. A gap the zombies can exploit.
		_reload_left = reload_time
		rifle.rotation_degrees = Vector3(-50, 0, 0)
