extends CharacterBody3D
## A shambler with three moods:
##   IDLE        - shuffles around near where it stands, and now and then sets off
##                 roaming (more at night): a long walk that keeps roughly the way
##                 it was going, drifting along with others nearby. Nobody steers
##                 them anywhere; over time they just spread around town, back
##                 into places you'd cleared too.
##   INVESTIGATE - heard something, or lost sight of its target; walks there and lingers
##   HUNT        - chasing the closest target it can currently see
## Targets are anything in the "zombie_targets" group (the player and the guards).
## Every sense tick it re-picks the closest visible target, so getting shot doesn't
## pull it off whoever it's already chasing; damage only matters if it had no target.
## Sight needs a clear line (buildings and cars block it), mostly in front of it.
## Sound goes through walls. A closed door in its way gets bashed until it breaks
## (only while it's going somewhere: hunting or investigating, not idly wandering).
## In a horde (world/horde.gd) it has somewhere to walk to across town
## (march_to): while idle it heads there instead of shuffling or roaming, and
## once it arrives it's an ordinary zombie. It finds its way on the horde's
## outdoor map (march_map), so it goes around buildings rather than up against
## their doors. Hunting and investigating come first (on the town's map, doors
## and all); afterwards it picks the walk back up, unless it's ended up
## somewhere it can't get across from (indoors).
## Its paths can also run through windows (world/fortifications.gd): it smashes the
## glass, then climbs over the sill. Boarded windows and doors stop it for good.
## A fence or fence gate you built (unless it's plated) between it and someone
## it's after, or a noise it heard, gets bashed the same way (_bash_blocker);
## once it's down it walks through the gap (_through_gap).
## Its kind (walker, runner, crawler...) is a file in characters/zombie/kinds/
## (ZombieKind): health, speeds, shape, skin, voice, and its model. Set `kind`
## to its id before adding it to the tree; main.gd rolls it.
## Its body (characters/humanoid_body.gd) is the kind's model, or the mannequin
## stand-in: animated by what it's doing (_animate), flinching where it's hit,
## going limp (a ragdoll) when it dies. Each one gets its own colors and a
## slightly different size. Blood sprays and splatters where it's hit
## (effects/blood.gd), and marks its body.
## Its head has its own small hitbox (HeadShape, kept on the head as it moves):
## a shot that hits that is a headshot.
## Bodies are cleared away once you're well away and not looking
## (world/zombie_population.gd).
## The node tree lives in zombie.tscn.
## TUNING: open zombie.tscn, select the Zombie node, and use the Inspector.

const Player := preload("res://characters/player/player.gd")
const GameData := preload("res://core/game_data.gd")
const WindowPane := preload("res://world/window_pane.gd")
const Sound := preload("res://core/sound.gd")
const Water := preload("res://world/water.gd")
const Ground := preload("res://world/ground.gd")
const HumanoidBody := preload("res://characters/humanoid_body.gd")
const Blood := preload("res://effects/blood.gd")

enum State { IDLE, INVESTIGATE, HUNT }

## A ZombieKind's id (characters/zombie/kinds/).
@export var kind := "walker"

@export_range(1.0, 100.0) var sight_range := 20.0 ## In daylight.
## Sight range multiplier at full night (0.45 = 9 m out of 20).
@export_range(0.0, 1.0) var night_sight_factor := 0.45
@export var damage_per_second := 20.0
## Damage to a door it's pushing against. Doors have 150 health, so one zombie
## gets through in about 8 seconds; a crowd much faster.
@export var door_damage_per_second := 18.0
## Seconds it keeps searching a spot before losing interest.
@export var linger_time := 4.0
## Each time it's idle and decides what to do next, the chance it sets off
## roaming (a long walk) instead of shuffling. Higher = zombies spread around
## town, and back into places you've cleared, faster.
@export_range(0.0, 1.0) var roam_chance_day := 0.05
@export_range(0.0, 1.0) var roam_chance_night := 0.5

const VIEW_DOT := 0.5 # cos(60 degrees): it sees a 120 degree cone in front of it
const PROXIMITY_RANGE := 2.0 # this close, it notices you no matter what
const EYE_HEIGHT := 1.6
const CRAWLER_EYE_HEIGHT := 0.4
## Each one's size: its kind's times a random amount in this range.
const SIZE_RANGE := Vector2(0.92, 1.08)
## How its animations keep pace with it (m/s at normal speed, from the
## mannequin's animations): walking, running, crawling. Faster than RUN_FROM is a run.
const WALK_PACE := 1.2
const RUN_PACE := 2.8
const CRAWL_PACE := 0.6
const RUN_FROM := 3.0
## Climbing in through a window takes this long: a chance to hit it.
const CLIMB_TIME := 1.5
const ATTACK_RANGE := 1.3
const ATTACK_HEIGHT := 1.5 # can't bite something more than this far above or below it
const SENSE_INTERVAL := 0.2 # sight checks are raycasts; 5 per second is plenty
const REPATH_INTERVAL := 0.3 # while hunting (the target moves)
const CALM_REPATH_INTERVAL := 2.0 # otherwise (the destination stays put)
# Roaming (see _next_wander).
const ROAM_LEG := Vector2(15.0, 45.0) # meters per leg, min and max
const ROAM_SPEED := 0.45 # times its walking speed
const MARCH_SPEED := 1.2 # m/s in a horde (or its own speed, if slower), so the group keeps together
const MARCH_ARRIVED := 6.0 # meters from march_to that counts as there
const BLOCKER_REACH := 2.5 # meters: how close a fence in its way has to be for it to bash it
## Hills and water slow zombies more than you (player.gd has the player's):
## uphill, speed drops by SLOPE_SLOWDOWN per unit of rise over run (a 45 degree
## climb is 30% speed); wading, speed times WADE_FACTOR. In deep water they
## sink and stumble along the bottom (DEEP_FACTOR), and drown after DROWN_SECONDS.
const SLOPE_SLOWDOWN := 0.7
const WADE_FACTOR := 0.4
const DEEP_FACTOR := 0.3
const DROWN_SECONDS := 4.0
const WATER_CHECK := 0.25 # seconds between looking for water underfoot
## Seconds after breaking a fence that it walks straight through the gap (the
## navigation mesh takes a few seconds to catch up with the wreck).
const GAP_TIME := 8.0
const UNSTICK_AFTER := 1.5 # seconds hardly moving (jammed in a crowd, against a wall) before it gives up getting closer
const SHUFFLE_SPEED := 0.35
const ROAM_TURN := 0.8 # radians: how far each leg can veer from the last
const HERD_RADIUS := 15.0 # roamers this close pull its heading toward theirs
const HERD_PULL := 0.7
# Away from the camera and not after anyone, it only thinks and moves every
# few physics frames (covering the same ground): every MID_TICK frames past
# MID_DISTANCE, every FAR_TICK past FAR_DISTANCE, every VERY_FAR_TICK past
# VERY_FAR_DISTANCE. A town's worth of zombies (or a horde) costs much less, and
# nobody's close enough to see the difference.
const MID_DISTANCE := 40.0
const MID_TICK := 2
const FAR_DISTANCE := 80.0
const FAR_TICK := 3
const VERY_FAR_DISTANCE := 130.0
const VERY_FAR_TICK := 6
## Working out a path is the costliest thing a zombie does (up to about a
## millisecond on the town's map), so all zombies together start at most this
## many per physics frame. Without a limit, a crowd that all wants a new path at
## once makes the game stutter; the rest wait a frame or two (_walk_to).
const PATHS_PER_FRAME := 4

var state := State.IDLE
var max_health := 100.0 # its kind's
var health := 100.0 # set to max_health in _ready
var kind_data: ZombieKind # the file for `kind`
var eye_height := EYE_HEIGHT
var is_dead := false
var speed := 1.6
var target: Node3D = null # who it's hunting
var day_night: Node
var _attacking := false # biting someone this tick (for its animation)
var _bashing := false # beating on a door, window or fence
var _bashed_last := false # ...last tick
var _vault_tween: Tween
var _last_blow: Array = [] # [impulse, where]: the hit that killed it, for its fall

var investigate_pos := Vector3.ZERO
var last_seen_pos := Vector3.ZERO
var wander_target := Vector3.ZERO
var roam_heading := Vector3.FORWARD # the way it's been roaming (flat, unit length)
var roaming := false # on a roaming leg right now (others read this to herd)
var march_to := Vector3.INF # in a horde: where it's walking to (INF: not in one; main.gd saves it)
var march_map := RID() # in a horde: the outdoor map it walks there on (horde.gd)
var _march_time_left := INF # gives up on the walk when this runs out (set when it starts)
var _stuck_time := 0.0
static var _paths_frame := -1 # the physics frame _paths_left counts for
static var _paths_left := 0 # path requests still allowed this physics frame (PATHS_PER_FRAME)
var _gap_time := 0.0 # > 0: just broke a fence, so it heads straight through (_through_gap)
var _water_depth := 0.0 # water at its feet (world/water.gd), checked every WATER_CHECK
var _water_timer := 0.0
var _drowning := 0.0 # seconds in deep water so far
var linger_timer := 0.0
var wander_timer := 0.0
var sense_timer := 0.0
var repath_timer := 0.0
var stagger_timer := 0.0
var groan_timer := 0.0
# The window it's heading through (see _handle_window), and the climb over its sill.
var _window_link: NavigationLink3D = null
var _window_entry := Vector3.ZERO
var _window_exit := Vector3.ZERO
var _vaulting := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _far_phase := 0 # which of the frames is its turn when it skips some (spread across zombies)
var _far_frame := 0
var _far_delta := 0.0 # time saved up between its turns
var _step_scale := 1.0 # how many frames' worth this physics step moves it

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual # its body, scaled to its size
@onready var body: HumanoidBody = $Visual/Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var head_shape: CollisionShape3D = $HeadShape


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("noise_listeners")
	floor_constant_speed = true # hills slow it by SLOPE_SLOWDOWN only
	kind_data = ZombieKind.find(kind)
	kind = kind_data.id
	speed = randf_range(kind_data.min_speed, maxf(kind_data.max_speed, kind_data.min_speed)) # some shuffle, some lurch
	max_health = kind_data.health
	health = max_health
	_apply_kind()
	# Stagger timers so dozens of zombies don't all raycast and repath on the same frame.
	sense_timer = randf() * SENSE_INTERVAL
	repath_timer = randf() * REPATH_INTERVAL
	wander_timer = randf_range(1.0, 6.0)
	groan_timer = randf_range(2.0, 12.0)
	wander_target = global_position
	roam_heading = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_far_phase = randi() % VERY_FAR_TICK # (a multiple of MID_TICK and FAR_TICK)
	# Layer 1 is the ground; layer 2 is the links through windows (fortifications.gd).
	agent.navigation_layers = 1 | 2
	agent.link_reached.connect(_on_link_reached)


## Its kind's body, shape and colors.
func _apply_kind() -> void:
	body.setup(kind_data.model)
	body.head_shape = head_shape
	body.settled.connect(func() -> void: Blood.pool(get_parent(), body.head_center().lerp(global_position, 0.6)))
	visual.scale = kind_data.body_scale * randf_range(SIZE_RANGE.x, SIZE_RANGE.y)
	var skin := kind_data.skin_color if kind_data.skin_color.a > 0.0 else Color(0.45, 0.52, 0.4)
	skin = skin.lightened(randf_range(-0.1, 0.1)) if randf() < 0.5 else skin.darkened(randf_range(0.0, 0.15))
	body.set_colors(skin, Color.from_hsv(randf(), randf_range(0.15, 0.4), randf_range(0.2, 0.45)),
			Color.from_hsv(randf_range(0.55, 0.7), randf_range(0.1, 0.35), randf_range(0.12, 0.3)))
	if _crawls():
		eye_height = CRAWLER_EYE_HEIGHT
		# Lying face down, head forward (its animations do the pose).
		var shape := CapsuleShape3D.new()
		shape.radius = 0.3
		shape.height = 1.6
		collision.shape = shape
		collision.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.3, 0.05))


## Where shots should aim: the middle of its body (guards use this).
func aim_point() -> Vector3:
	return global_position + (Vector3(0, 0.3, 0) if _crawls() else Vector3(0, 1.2, 0))


## A hit here counts as a headshot: it's on the head's hitbox.
func is_headshot(hit_pos: Vector3) -> bool:
	return hit_pos.distance_to(head_shape.global_position) < (head_shape.shape as SphereShape3D).radius + 0.03


## The middle of its head (guards aiming a headshot).
func head_point() -> Vector3:
	return body.head_center()


## Its groans: its kind's pitch.
func _voice_pitch() -> float:
	return kind_data.voice_pitch


func _crawls() -> bool:
	return kind_data.posture == "crawling"


## How fast it goes after someone.
func _hunt_speed() -> float:
	return kind_data.hunt_speed if kind_data.hunt_speed > 0.0 else speed


func _physics_process(delta: float) -> void:
	if _vaulting:
		return # a tween is carrying it over a windowsill
	_step_scale = 1.0
	var every := _update_every()
	if every > 1:
		_far_delta += delta
		_far_frame += 1
		if _far_frame % every != _far_phase % every:
			return
		_step_scale = _far_delta / delta
		delta = _far_delta
		_far_delta = 0.0
	else:
		_far_delta = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _update_water(delta):
		return # drowned
	if global_position.y < Ground.height_range().x - 30.0:
		die(false) # fell out of the map (past its edge)
		return

	_attacking = false
	_bashed_last = _bashing # (doors and windows are bashed after it picks its animation)
	_bashing = false
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
	_update_groan(delta)

	var moving := false
	match state:
		State.HUNT:
			if not _is_valid_target(target):
				_set_idle()
			else:
				var to_target := _flat(target.global_position - global_position)
				if to_target.length() > ATTACK_RANGE * 0.8:
					moving = _walk_to(target.global_position, _hunt_speed(), delta)
					if not moving and to_target.length() > ATTACK_RANGE * 1.5:
						# As close as it gets: a fence in the way? (Or one it just broke.)
						if not _bash_blocker(target.global_position, delta):
							moving = _through_gap(target.global_position, _hunt_speed())
				else:
					_face(to_target)
				var height_gap := absf(target.global_position.y - global_position.y)
				if to_target.length() < ATTACK_RANGE and height_gap < ATTACK_HEIGHT \
						and target.has_method("take_damage") and _can_reach(target):
					target.call("take_damage", damage_per_second * delta)
					_attacking = true
		State.INVESTIGATE:
			moving = _walk_to(investigate_pos, speed, delta)
			# Jammed against a wall or a crowd short of the spot counts as there:
			# as close as it's going to get. Unless a fence or gate is what's in
			# the way: then it beats on that, and doesn't lose interest meanwhile.
			if not moving or _stuck_time >= UNSTICK_AFTER:
				if _bash_blocker(investigate_pos, delta):
					pass
				elif _through_gap(investigate_pos, speed):
					moving = true
				else:
					linger_timer -= delta
					if linger_timer <= 0.0:
						_set_idle()
		State.IDLE:
			if march_to != Vector3.INF:
				_march_time_left -= delta
				if _march_time_left <= 0.0:
					_end_march() # long overdue: stuck somewhere, so it gives up on the horde's walk
			wander_timer -= delta
			if wander_timer <= 0.0:
				_next_wander()
			var walk_speed := minf(speed, MARCH_SPEED) if march_to != Vector3.INF \
					else speed * (ROAM_SPEED if roaming else SHUFFLE_SPEED)
			moving = _walk_to(wander_target, walk_speed, delta)
			if roaming and not moving and _navigation_ready():
				roaming = false # got there: stand around a while
				if march_to != Vector3.INF and _flat(march_to - global_position).length() > MARCH_ARRIVED:
					wander_timer = 0.5 # not there yet (its path came up short): set off again
				else:
					_end_march()
					wander_timer = randf_range(3.0, 12.0) * lerpf(1.0, 0.5, 1.0 - _light())

	_animate(moving)
	if not moving:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		# Standing still on solid ground: nothing to move, so skip the physics
		# step. Most zombies are standing around most of the time.
		if is_on_floor() and velocity.length_squared() < 0.0001:
			return
	var before := global_position
	_move(_step_scale)
	var bashing := false
	if moving and state != State.IDLE:
		bashing = _bash_doors(delta) or _bash_door_underfoot(delta)
		bashing = _handle_window(delta) or bashing
	_bashing = _bashing or bashing
	if bashing: # held up by a door or window it's breaking: that's not stuck
		_stuck_time = 0.0
	elif moving and (state == State.INVESTIGATE or (state == State.IDLE and march_to != Vector3.INF)):
		_check_stuck(before, delta)


## Hunting or investigating and as close as its path gets, short of where it's
## going: if something it can bash (a fence or gate you built, structure_piece.gd)
## is right there between it and that spot (within BLOCKER_REACH, and no
## further than the spot), it beats on it. (Fences are in the
## navigation mesh, so paths go around them and never run into one the way they
## run into doors.) True if it's bashing something.
func _bash_blocker(toward: Vector3, delta: float) -> bool:
	var from := global_position + Vector3(0, 0.6, 0)
	var to := _flat(toward - global_position)
	if to.length() < 0.1:
		return false
	var dir := to.normalized()
	# No further than the spot itself: a fence beyond it isn't in the way.
	var reach := minf(BLOCKER_REACH, to.length())
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, GameData.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var thing: Object = hit["collider"]
	if not (thing.has_method("can_be_bashed") and thing.call("can_be_bashed")):
		return false
	_face(dir)
	thing.call("bash", door_damage_per_second * delta)
	_bashing = true
	if not thing.call("can_be_bashed"):
		_gap_time = GAP_TIME # broke it
	return true


## Just broke a fence on its way to toward: walks straight at it while the
## navigation mesh catches up, as long as nothing's in the way and it's on the
## level. True if it's walking.
func _through_gap(toward: Vector3, move_speed: float) -> bool:
	if _gap_time <= 0.0:
		return false
	_gap_time -= get_physics_process_delta_time() * _step_scale
	var to := _flat(toward - global_position)
	if to.length() < 0.5 or absf(toward.y - global_position.y) > 0.5:
		_gap_time = 0.0
		return false
	var from := global_position + Vector3(0, 0.6, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + to.normalized() * minf(to.length(), BLOCKER_REACH),
			GameData.LAYER_WORLD, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	velocity.x = to.normalized().x * move_speed
	velocity.z = to.normalized().z * move_speed
	_face(to)
	return true


## Its path runs through doorways (doors aren't in the navigation mesh), so a
## closed door shows up as something it bumped into while walking. (Anything
## with can_be_bashed() and bash(); planks and barricades have neither.)
## True if it's bashing one.
func _bash_doors(delta: float) -> bool:
	for i in get_slide_collision_count():
		var thing := get_slide_collision(i).get_collider()
		if thing and thing.has_method("can_be_bashed") and thing.call("can_be_bashed"):
			thing.call("bash", door_damage_per_second * delta)
			return true
	return false


## Standing on a shut door its path goes down through (a cellar door, slanted
## over the steps): it's underfoot, not in the way, so beat on that. True if
## it's bashing one.
func _bash_door_underfoot(delta: float) -> bool:
	if not is_on_floor() or agent.get_next_path_position().y > global_position.y - 0.4:
		return false
	var from := global_position + Vector3(0, 0.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0.5, 0), GameData.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var thing: Object = hit.get("collider")
	if thing and thing.has_method("can_be_bashed") and thing.call("can_be_bashed"):
		thing.call("bash", door_damage_per_second * delta)
		return true
	return false


# --- Windows -------------------------------------------------------------------

## The path reached the outside (or inside) end of a window's link.
func _on_link_reached(details: Dictionary) -> void:
	var link: Variant = details.get("owner")
	if link is NavigationLink3D and (link as Node).has_meta("window"):
		_window_link = link
		_window_entry = details.get("link_entry_position", (link as NavigationLink3D).start_position)
		_window_exit = details.get("link_exit_position", (link as NavigationLink3D).end_position)


## At a window on its path: beat on the glass, or climb through once it's gone.
## (It can't reach the glass to bump it: the wall below the window sticks out
## further, so the blows are dealt here rather than by _bash_doors.)
## True if it's beating on the glass.
func _handle_window(delta: float) -> bool:
	if _window_link == null:
		return false
	var pane: WindowPane = _window_link.get_meta("window")
	if not is_instance_valid(pane) or _flat(global_position - _window_entry).length() > 2.0:
		_window_link = null # moved on
	elif pane.can_be_bashed():
		pane.bash(door_damage_per_second * delta)
		return true
	elif pane.is_passable():
		_vault()
	else:
		_window_link = null # boarded up: its next path won't use this window
	return false


## Over the sill and in (or out): it hauls itself up onto the sill, then drops
## down the other side. It takes CLIMB_TIME, and it can be hit the whole time.
func _vault() -> void:
	_vaulting = true
	velocity = Vector3.ZERO
	var sill_y: float = _window_link.get_meta("sill_y")
	var over := (_window_entry + _window_exit) / 2.0
	over.y = sill_y + 0.15
	_face(_flat(_window_exit - global_position))
	body.one_shot("crawl" if _crawls() else "climb", CLIMB_TIME)
	_vault_tween = create_tween()
	_vault_tween.tween_property(self, "global_position", over, CLIMB_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vault_tween.tween_property(self, "global_position", _window_exit + Vector3(0, 0.1, 0), CLIMB_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_vault_tween.tween_callback(func() -> void:
		_vaulting = false
		_window_link = null
		repath_timer = 0.0)


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
		if state != State.HUNT:
			_alert_sound()
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
	var eye := global_position + Vector3(0, eye_height, 0)
	var aim := candidate.global_position + Vector3(0, 1.0, 0)
	# Up close it notices you whichever way it's facing, but still not through walls.
	if dist < PROXIMITY_RANGE:
		return _clear_line(eye, aim, candidate)
	# Crouched in tall crops or bushes: hidden (world/cover.gd). It can still hear you.
	if candidate.get("in_cover"):
		return false

	# Darkness shrinks how far it can see. The player can also crouch to be harder
	# to spot, and a lit flashlight is visible from far away day or night.
	var light := _light()
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


## Nothing solid between its chest and the target's, windows and closed doors
## included. Sight goes through glass, so without this it could bite through a
## shop window it was pressed up against.
func _can_reach(candidate: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.2, 0)
	var to := candidate.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, GameData.LAYER_WORLD | GameData.LAYER_GLASS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Idle and done with what it was doing: shuffle a few steps, or set off roaming.
func _next_wander() -> void:
	if march_to != Vector3.INF and _navigation_ready() and _start_march():
		return
	var night := 1.0 - _light()
	if _navigation_ready() and randf() < lerpf(roam_chance_day, roam_chance_night, night):
		_start_roam_leg()
		return
	roaming = false
	wander_timer = randf_range(4.0, 9.0) * lerpf(1.0, 0.5, night)
	wander_target = global_position + Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))


## One roaming leg: roughly the way it was going, pulled toward the way any
## roamers nearby are going (so loose packs form), with a wobble. If that runs
## into the edge of town or a solid block, it turns around instead.
func _start_roam_leg() -> void:
	var heading := roam_heading
	var nearby := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("zombies"):
		if other != self and other.roaming \
				and global_position.distance_squared_to(other.global_position) < HERD_RADIUS * HERD_RADIUS:
			nearby += other.roam_heading
	if nearby.length_squared() > 0.0001:
		heading = (heading + nearby.normalized() * HERD_PULL).normalized()
	heading = heading.rotated(Vector3.UP, randf_range(-ROAM_TURN, ROAM_TURN))
	var length := randf_range(ROAM_LEG.x, ROAM_LEG.y)
	var map := agent.get_navigation_map()
	var goal := global_position + heading * length
	var reachable := NavigationServer3D.map_get_closest_point(map, goal)
	if _flat(reachable - goal).length() > 6.0:
		heading = (-heading).rotated(Vector3.UP, randf_range(-1.0, 1.0))
		reachable = NavigationServer3D.map_get_closest_point(map, global_position + heading * length)
	roam_heading = heading
	wander_target = reachable
	roaming = true
	# Give up and rethink if it hasn't arrived well after it should have.
	wander_timer = length / maxf(speed * ROAM_SPEED, 0.1) + 15.0


## In a horde: straight for march_to. It counts as roaming, so others roaming
## nearby get pulled along the same way (_start_roam_leg).
## False if it can't get there from here: it's out of the horde.
func _start_march() -> bool:
	if march_map.is_valid() and NavigationServer3D.map_get_iteration_id(march_map) > 0:
		var from := NavigationServer3D.map_get_closest_point(march_map, global_position)
		var path := NavigationServer3D.map_get_path(march_map, from, march_to, true)
		if from.distance_to(global_position) > 1.5 or path.is_empty() \
				or _flat(path[path.size() - 1] - march_to).length() > MARCH_ARRIVED:
			_end_march()
			return false
	var to := _flat(march_to - global_position)
	if to.length_squared() > 0.0001:
		roam_heading = to.normalized()
	if _march_time_left == INF: # gives up if it isn't there well after it should be
		_march_time_left = to.length() / minf(speed, MARCH_SPEED) * 2.0 + 60.0
	wander_target = march_to
	roaming = true
	wander_timer = 60.0 # then finds the way again from wherever it's got to
	return true


func _end_march() -> void:
	march_to = Vector3.INF
	_march_time_left = INF
	_stuck_time = 0.0


## Hardly moving for a while: jammed in a crowd (two in a gap at once, walkers
## behind a crawler, a crowd round the spot they all heard something at) or
## pushing into a wall. Investigating, it then lingers where it is (see
## _physics_process); marching in a horde, it steps aside, then carries on.
func _check_stuck(before: Vector3, delta: float) -> void:
	if _flat(global_position - before).length() > minf(speed, MARCH_SPEED) * delta * 0.25:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if state != State.IDLE or _stuck_time < UNSTICK_AFTER:
		return
	_stuck_time = 0.0
	roaming = false
	wander_target = global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(2.0, 4.0)
	wander_timer = randf_range(1.0, 2.5) # then _next_wander picks the walk back up


## 0 at darkest night, 1 in full day.
func _light() -> float:
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night")
	return day_night.call("light_level") if day_night else 1.0


func _investigate(pos: Vector3) -> void:
	state = State.INVESTIGATE
	roaming = false
	_stuck_time = 0.0
	investigate_pos = pos
	linger_timer = linger_time
	repath_timer = 0.0


func _set_idle() -> void:
	state = State.IDLE
	roaming = false
	_stuck_time = 0.0
	target = null
	wander_timer = randf_range(2.0, 5.0)
	wander_target = global_position


# --- Combat ------------------------------------------------------------------

## Called by the player's attacks and by guards. hit_pos: where it landed (a
## shot), or INF (a blow: the chest). The attacker only becomes the target if
## the zombie wasn't already chasing someone.
func take_hit(damage: float, from_pos: Vector3, knockback: float, attacker: Node3D = null, hit_pos := Vector3.INF) -> void:
	if is_dead:
		return
	health -= damage
	var away := _flat(global_position - from_pos).normalized()
	if hit_pos == Vector3.INF:
		hit_pos = aim_point() - away * 0.25
	velocity.x = away.x * knockback
	velocity.z = away.z * knockback
	stagger_timer = 0.4
	_flash()
	Sound.play_at(self, "zombie_hit", global_position + Vector3.UP, -4.0, 20.0, 0.15, _voice_pitch())
	var shot_dir := (hit_pos - from_pos).normalized()
	Blood.hit(get_parent(), hit_pos, shot_dir, [get_rid()])
	body.wound(hit_pos, -shot_dir)
	if health <= 0.0:
		_last_blow = [shot_dir * (40.0 + knockback * 25.0) + Vector3.UP * 10.0, hit_pos]
		die()
		# Who killed it, for anyone counting (world/camps.gd: kills near a camp).
		get_tree().call_group("kill_listeners", "zombie_killed", global_position, attacker)
		return
	if not _vaulting: # (mid-climb it keeps climbing)
		body.one_shot("crawl_hit" if _crawls() else "hit_" + body.zone_of(hit_pos))
	if state == State.HUNT and _is_valid_target(target):
		return # stay on its current target
	if _is_valid_target(attacker):
		_alert_sound()
		target = attacker
		state = State.HUNT
		last_seen_pos = attacker.global_position
	else:
		_investigate(from_pos)


## It goes limp and falls (a ragdoll), pushed by the blow that killed it.
## loud = false: no death groan (drowned quietly, fell off the map).
func die(loud := true) -> void:
	if is_dead:
		return
	is_dead = true
	target = null
	remove_from_group("zombies") # stops hearing, being hit, and being targeted
	collision.set_deferred("disabled", true) # deferred: physics may be mid-step
	head_shape.set_deferred("disabled", true)
	set_physics_process(false)
	if _vault_tween and _vault_tween.is_valid():
		_vault_tween.kill() # killed mid-climb: falls from the sill
	_vaulting = false
	if loud:
		Sound.play_at(self, "zombie_death", global_position + Vector3.UP, -2.0, 25.0, 0.12, _voice_pitch())
	var blow: Array = _last_blow if not _last_blow.is_empty() else [Vector3.UP * 5.0, aim_point()]
	body.ragdoll(blow[0], blow[1], Vector3(velocity.x, 0.0, velocity.z))


## Every so often it moans: quietly while shuffling around, louder and more
## often while chasing someone. It's how you hear one coming in the dark.
func _update_groan(delta: float) -> void:
	groan_timer -= delta
	if groan_timer > 0.0:
		return
	var hunting := state == State.HUNT
	groan_timer = randf_range(2.5, 5.0) if hunting else randf_range(6.0, 14.0)
	Sound.play_at(self, "zombie_groan", global_position + Vector3(0, eye_height, 0),
			-2.0 if hunting else -9.0, 22.0 if hunting else 16.0, 0.15, _voice_pitch())


## Just spotted (or been hit by) someone.
func _alert_sound() -> void:
	groan_timer = randf_range(2.5, 5.0) # don't moan right on top of the snarl
	Sound.play_at(self, "zombie_alert", global_position + Vector3(0, eye_height, 0), 0.0, 28.0, 0.15, _voice_pitch())


func _set_flash(amount: float) -> void:
	body.set_flash(amount)


## Picks its animation from what it's doing this tick.
func _animate(moving: bool) -> void:
	if body.is_busy():
		return # a flinch or the climb is playing out
	var pace := _flat(velocity).length()
	var action := "idle"
	var speed_scale := 1.0
	if _bashing or _bashed_last:
		action = "bash"
	elif _attacking:
		action = "attack"
	elif moving and pace > 0.1:
		if _crawls():
			action = "crawl"
			speed_scale = pace / CRAWL_PACE
		elif pace > RUN_FROM:
			action = "run"
			speed_scale = pace / RUN_PACE
		else:
			action = "walk"
			speed_scale = pace / WALK_PACE
	if _crawls() and action != "crawl":
		action = "crawl_attack" if action in ["attack", "bash"] else "crawl_idle"
	body.set_action(action, clampf(speed_scale, 0.3, 2.5))


func _flash() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_flash, 1.0, 0.0, 0.25)


# --- Movement ----------------------------------------------------------------

## Steps along a navigation path toward a point. Returns false once arrived (or no path).
func _walk_to(point: Vector3, move_speed: float, delta: float) -> bool:
	var map := march_map if state == State.IDLE and march_to != Vector3.INF and march_map.is_valid() \
			else get_world_3d().navigation_map
	if agent.get_navigation_map() != map: # in a horde: the outdoor map while marching
		agent.set_navigation_map(map)
		repath_timer = 0.0
	if not _navigation_ready():
		return false
	repath_timer -= delta
	var new_point := point.distance_squared_to(agent.target_position) > 1.0
	var waiting := false # wants a path to a new point, but this frame's are used up
	if repath_timer <= 0.0 or new_point:
		if _take_path_request():
			agent.target_position = point
			repath_timer = REPATH_INTERVAL if state == State.HUNT else CALM_REPATH_INTERVAL
		else:
			waiting = new_point
	if agent.is_navigation_finished():
		if waiting: # its old path is done: stand still a frame rather than look arrived
			velocity.x = 0.0
			velocity.z = 0.0
			return true
		return false
	var dir := _flat(agent.get_next_path_position() - global_position)
	if dir.length() < 0.05:
		return false
	dir = dir.normalized()
	var ground := _ground_factor(dir)
	velocity.x = dir.x * move_speed * ground
	velocity.z = dir.z * move_speed * ground
	_face(dir)
	return true


## Speed multiplier for the ground: uphill (SLOPE_SLOWDOWN), shallow water
## (WADE_FACTOR) or deep (DEEP_FACTOR).
func _ground_factor(dir: Vector3) -> float:
	var factor := 1.0
	if _water_depth >= Water.SWIM_DEPTH:
		factor = DEEP_FACTOR
	elif _water_depth > Water.WADE_DEPTH:
		factor = WADE_FACTOR
	if is_on_floor():
		var normal := get_floor_normal()
		var uphill_rise := maxf(-dir.dot(Vector3(normal.x, 0.0, normal.z)), 0.0) / maxf(normal.y, 0.1)
		factor *= clampf(1.0 - SLOPE_SLOWDOWN * uphill_rise, 0.15, 1.0)
	return factor


## Looks for water underfoot now and then. In deep water it drowns after
## DROWN_SECONDS. True if it just drowned.
func _update_water(delta: float) -> bool:
	_water_timer -= delta
	if _water_timer <= 0.0:
		_water_timer = WATER_CHECK
		_water_depth = Water.depth_at(get_tree(), global_position)
	if _water_depth < Water.SWIM_DEPTH:
		_drowning = 0.0
		return false
	_drowning += delta
	if _drowning < DROWN_SECONDS:
		return false
	die()
	return true


## One of this physics frame's PATHS_PER_FRAME path requests, if any are left.
static func _take_path_request() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _paths_frame:
		_paths_frame = frame
		_paths_left = PATHS_PER_FRAME
	if _paths_left <= 0:
		return false
	_paths_left -= 1
	return true


## move_and_slide covers one physics frame; on a far zombie's turn it covers the
## frames it skipped.
func _move(frames: float) -> void:
	if frames == 1.0:
		move_and_slide()
		return
	velocity *= frames
	move_and_slide()
	velocity /= frames


## How often it thinks and moves: every physics frame up close or while after
## someone (or reeling from a hit), every MID_TICK frames from MID_DISTANCE,
## every FAR_TICK frames from FAR_DISTANCE and every VERY_FAR_TICK frames from
## VERY_FAR_DISTANCE.
func _update_every() -> int:
	if state == State.HUNT or stagger_timer > 0.0:
		return 1
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1
	var dist_sq := global_position.distance_squared_to(camera.global_position)
	if dist_sq > VERY_FAR_DISTANCE * VERY_FAR_DISTANCE:
		return VERY_FAR_TICK
	if dist_sq > FAR_DISTANCE * FAR_DISTANCE:
		return FAR_TICK
	return MID_TICK if dist_sq > MID_DISTANCE * MID_DISTANCE else 1


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		look_at(global_position + dir.normalized(), Vector3.UP)


## The navigation map updates at the end of a physics frame, so on the very first
## frame it's still empty and path queries would fail with an error.
func _navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
