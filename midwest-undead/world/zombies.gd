extends Node3D
## The zombies: every one up (and the bodies not yet cleared away), adding
## them, the ones a new game starts with (at the map's ZombieSpawn markers and
## in its mines), and saving them. world/zombie_population.gd tops them up over
## time and world/horde.gd sends them across the map; both add theirs here.
##
## It also gives out their turns to think and move (_physics_process), so 400
## of them fit in a frame: near you (MID_DISTANCE), after someone or reeling
## from a hit, a zombie has a turn every frame; further off, every few frames
## (Zombie.tick_every()), taking turns round the crowd within BUDGET_USEC a
## frame (a turn put off is just longer, next frame). Past GLIDE_DISTANCE and
## not after anyone, it glides along its path instead of going through the
## physics engine (Zombie._glide_along_path), except within OPENING_MARGIN of a
## door or window, and its body (its animation) stops while you can't see it.
## Each one's body is driven from here too (HumanoidBody.step()).
##
## Far off, a zombie is only data (Dormant: where it is, what it's doing), not
## a zombie in the game at all, so a crowd across the map costs next to
## nothing. Once a second (STEP): one past DORMANT_PAST from you, idle, more
## than PEOPLE_NEAR from anyone else it could attack (guards, bandits: the
## "zombie_targets" group) and where you can't see it becomes data; data
## within AWAKE_WITHIN of you, or PEOPLE_NEAR of them, becomes a zombie again
## where you can't see it (within WAKE_ANYWAY, wherever). Meanwhile they keep
## roaming and marching with the horde, a second's walk along their paths at a
## time; a door that's shut or a window stops them (they'd have to break in:
## only a real zombie does that).

const Zombie := preload("res://characters/zombie/zombie.gd")
const ZombieScene := preload("res://characters/zombie/zombie.tscn")
const GameMap := preload("res://world/game_map.gd")
const Ground := preload("res://world/ground.gd")
const SaveGame := preload("res://core/save_game.gd")
const DayNight := preload("res://world/day_night.gd")
const Player := preload("res://characters/player/player.gd")
const Door := preload("res://world/door.gd")

## Street zombies (a ZombieSpawn with a spread) don't start this close to a car or other container.
const ZOMBIE_CONTAINER_CLEARANCE := 2.5
## Time a frame for the turns of the zombies that don't need one every frame.
const BUDGET_USEC := 3000
const GLIDE_DISTANCE := 50.0
const OPENING_MARGIN := 3.0
const OPENING_CELL := 8.0 # meters: the grid doors and windows are looked up on
## The most one turn covers (one put off and off doesn't jump).
const MAX_TURN := 0.25
const DORMANT_PAST := 120.0
const AWAKE_WITHIN := 100.0
const WAKE_ANYWAY := 60.0
const PEOPLE_NEAR := 60.0
const STEP := 1.0 # seconds between moving the data and deciding who's data
const SWITCHES_PER_STEP := 20 # making a hundred zombies at once would stutter
const PATHS_PER_STEP := 10 # new legs for the data, each a path to work out


## A zombie that's only data, for now.
class Dormant:
	var position: Vector3
	var yaw := 0.0
	var health := 100.0
	var kind := "walker"
	var speed := 1.6 # its walking speed
	var march_to := Vector3.INF # in a horde: where it's walking to
	var march_map := RID() # the horde's outdoor map (world/horde.gd)
	var roam_chance_day := 0.05
	var roam_chance_night := 0.5
	var path := PackedVector3Array() # the leg it's on
	var path_index := 0
	var rest := 0.0 # seconds before it sets off again

var all: Array[Zombie] = [] # every zombie up (and bodies not yet cleared away)
var rng: RandomNumberGenerator # the game's dice (main.gd's)
var _map: GameMap
var _cursor := 0 # where in the crowd the next frame's turns start
var _openings := {} # Vector2i (OPENING_CELL squares) -> Array of [where, the door or window]
## Time a frame for the waiting turns (BUDGET_USEC; tests change it). However
## little, one gets its turn every frame, so the crowd always moves on.
var budget_usec := BUDGET_USEC
## Last frame (for tests and the performance readout): turns given, and how
## many of them glided.
var turns := 0
var glides := 0
var dormant: Array[Dormant] = []
## (Vector3) -> bool: could you see a zombie standing there
## (world/zombie_population.gd's seen()). Without it, nobody becomes data.
var seen := Callable()
var _day_night: DayNight
var _step_left := STEP


func _ready() -> void:
	Saveable.section(self, "zombies", _save_zombies, _load_zombies, Saveable.ZOMBIES)


func setup(map: GameMap, dice: RandomNumberGenerator, day_night: DayNight) -> void:
	_map = map
	rng = dice
	_day_night = day_night
	for door in map.doors:
		_add_opening(door.closed_transform().origin, door)
	for window in map.windows:
		_add_opening(window.global_position, window)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = STEP
		_move_dormant(STEP)
		if camera:
			_switch(camera.global_position)
	var count := all.size()
	if count == 0:
		return
	turns = 0
	glides = 0
	var spent := 0
	var put_off := -1
	for k in count:
		var i := (_cursor + k) % count
		var zombie := all[i]
		if not is_instance_valid(zombie) or zombie.is_dead:
			continue
		zombie.waited += delta
		zombie.frames_waited += 1
		var dist_sq := zombie.global_position.distance_squared_to(camera.global_position) if camera else 0.0
		if dist_sq <= GLIDE_DISTANCE * GLIDE_DISTANCE or zombie.body.on_screen():
			zombie.body.step(delta) # (held still while it's far off and out of sight)
		var every := zombie.tick_every(dist_sq)
		if every == 1:
			_turn(zombie, delta, dist_sq)
		elif zombie.frames_waited >= every:
			if spent > budget_usec:
				if put_off < 0:
					put_off = i
				continue
			var started := Time.get_ticks_usec()
			_turn(zombie, delta, dist_sq)
			spent += Time.get_ticks_usec() - started
	_cursor = put_off if put_off >= 0 else 0


func _turn(zombie: Zombie, delta: float, dist_sq: float) -> void:
	var glide := dist_sq > GLIDE_DISTANCE * GLIDE_DISTANCE and zombie.state != Zombie.State.HUNT \
			and not _near_opening(zombie.global_position)
	var turn := minf(zombie.waited, MAX_TURN)
	zombie.think(turn, turn / delta, glide)
	zombie.waited = 0.0
	zombie.frames_waited = 0
	turns += 1
	if glide:
		glides += 1


func _add_opening(at: Vector3, opening: Node3D) -> void:
	var cell := _cell_of(at)
	if not _openings.has(cell):
		_openings[cell] = []
	(_openings[cell] as Array).append([at, opening])


func _near_opening(at: Vector3) -> bool:
	return not _openings_near(at).is_empty()


## The doors and windows within OPENING_MARGIN of at: [where, which] each.
func _openings_near(at: Vector3) -> Array:
	var found := []
	var cell := _cell_of(at)
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for entry: Array in _openings.get(Vector2i(x, y), []):
				if (entry[0] as Vector3).distance_squared_to(at) < OPENING_MARGIN * OPENING_MARGIN:
					found.append(entry)
	return found


## Whether a data zombie stepping from from to to would be getting through a
## door that's shut or a window: closer to one than it was, within
## OPENING_MARGIN. (Away from one is always fine: it can't get stuck.)
func _blocked_step(from: Vector3, to: Vector3) -> bool:
	for entry: Array in _openings_near(to):
		var opening := entry[1] as Node3D
		if opening is Door and (opening.is_open or opening.is_broken):
			continue
		var at: Vector3 = entry[0]
		if to.distance_squared_to(at) < from.distance_squared_to(at):
			return true
	return false


static func _cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / OPENING_CELL), floori(at.z / OPENING_CELL))


## How many zombies are up, data ones included.
func alive_count() -> int:
	return get_tree().get_nodes_in_group("zombies").size() + dormant.size() # (the dead leave the group)


## Whether any zombie is walking with a horde, data ones included.
func any_marching() -> bool:
	return all.any(func(z: Zombie) -> bool: return is_instance_valid(z) and z.march_to != Vector3.INF) \
			or dormant.any(func(d: Dormant) -> bool: return d.march_to != Vector3.INF)


## The horde's outdoor map for everyone walking with it (world/horde.gd, after
## loading a save).
func set_march_map(outdoor: RID) -> void:
	for zombie in all:
		if is_instance_valid(zombie) and zombie.march_to != Vector3.INF:
			zombie.march_map = outdoor
	for d in dormant:
		if d.march_to != Vector3.INF:
			d.march_map = outdoor


# --- Zombies that are only data --------------------------------------------------

## Who becomes data, and who becomes a zombie again (see the top). eye: the camera.
func _switch(eye: Vector3) -> void:
	var people := _people()
	var switched := 0
	for i in range(all.size() - 1, -1, -1):
		if switched >= SWITCHES_PER_STEP or not seen.is_valid():
			break
		var zombie := all[i]
		if not is_instance_valid(zombie) or zombie.is_dead or not _can_rest(zombie):
			continue
		var at := zombie.global_position
		if at.distance_squared_to(eye) <= DORMANT_PAST * DORMANT_PAST or _near(at, people) \
				or zombie.body.on_screen() or seen.call(at):
			continue
		dormant.append(_record(zombie))
		all.remove_at(i)
		zombie.remove_from_group("zombies")
		zombie.queue_free()
		switched += 1
	for i in range(dormant.size() - 1, -1, -1):
		if switched >= SWITCHES_PER_STEP:
			break
		var d := dormant[i]
		var dist_sq := d.position.distance_squared_to(eye)
		if dist_sq >= AWAKE_WITHIN * AWAKE_WITHIN and not _near(d.position, people):
			continue
		if dist_sq > WAKE_ANYWAY * WAKE_ANYWAY and seen.is_valid() and seen.call(d.position):
			continue # wait until it's out of sight
		_wake(d)
		dormant.remove_at(i)
		switched += 1


## Idle, and nothing going on that needs the real thing (a climb, a stagger,
## water).
func _can_rest(zombie: Zombie) -> bool:
	return zombie.state == Zombie.State.IDLE and zombie.stagger_timer <= 0.0 and not zombie._vaulting \
			and zombie._water_depth <= 0.0 and zombie.is_on_floor()


## Where everyone a zombie could attack is, but you (guards, bandits: traders
## and survivors aren't zombie targets).
func _people() -> PackedVector3Array:
	var found := PackedVector3Array()
	for node in get_tree().get_nodes_in_group("zombie_targets"):
		if node is Node3D and not node is Player:
			found.append((node as Node3D).global_position)
	return found


func _near(at: Vector3, people: PackedVector3Array) -> bool:
	for person in people:
		if person.distance_squared_to(at) < PEOPLE_NEAR * PEOPLE_NEAR:
			return true
	return false


func _record(zombie: Zombie) -> Dormant:
	var d := Dormant.new()
	d.position = zombie.global_position
	d.yaw = zombie.rotation.y
	d.health = zombie.health
	d.kind = zombie.kind
	d.speed = zombie.speed
	d.march_to = zombie.march_to
	d.march_map = zombie.march_map
	d.roam_chance_day = zombie.roam_chance_day
	d.roam_chance_night = zombie.roam_chance_night
	if zombie.roaming or zombie.march_to != Vector3.INF: # on its way somewhere: carries on
		d.path = NavigationServer3D.map_get_path(_nav_map(d), d.position,
				zombie.march_to if zombie.march_to != Vector3.INF else zombie.wander_target, true)
	else:
		d.rest = rng.randf_range(3.0, 12.0)
	return d


func _wake(d: Dormant) -> void:
	var zombie := add(d.position + Vector3(0, Zombie.GLIDE_LIFT, 0), rng, d.kind)
	zombie.rotation.y = d.yaw
	zombie.health = d.health
	zombie.march_to = d.march_to
	zombie.march_map = d.march_map
	if d.path_index < d.path.size(): # still on its way
		zombie.roaming = true
		zombie.wander_target = d.path[d.path.size() - 1]


## A second's walk (seconds) for every one that's data: along its leg, or a
## rest, or a new leg (roaming, by its kind's chances, or the horde's march).
func _move_dormant(seconds: float) -> void:
	var light := _day_night.light_level() if _day_night else 1.0
	var paths := 0
	for d in dormant:
		if d.path_index >= d.path.size():
			if d.rest > 0.0:
				d.rest -= seconds
				continue
			if paths >= PATHS_PER_STEP:
				continue # next second
			var goal := d.march_to
			if goal == Vector3.INF:
				if rng.randf() >= lerpf(d.roam_chance_night, d.roam_chance_day, light):
					d.rest = rng.randf_range(3.0, 12.0) # standing around a while longer
					continue
				var angle := rng.randf() * TAU
				goal = d.position + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(Zombie.ROAM_LEG.x, Zombie.ROAM_LEG.y)
			d.path = NavigationServer3D.map_get_path(_nav_map(d), d.position, goal, true)
			d.path_index = 0
			paths += 1
			if d.path.is_empty():
				d.rest = rng.randf_range(3.0, 12.0)
				continue
		var pace := minf(d.speed, Zombie.MARCH_SPEED) if d.march_to != Vector3.INF else d.speed * Zombie.ROAM_SPEED
		var left := pace * seconds
		var from := d.position
		while left > 0.0 and d.path_index < d.path.size():
			var to := d.path[d.path_index] - d.position
			if to.length() <= left:
				d.position = d.path[d.path_index]
				left -= to.length()
				d.path_index += 1
			else:
				d.position += to.normalized() * left
				left = 0.0
		if _blocked_step(from, d.position):
			d.position = from # a door that's shut, or a window, in the way: this leg ends here
			d.path_index = d.path.size()
		if d.path_index >= d.path.size(): # there
			if d.march_to != Vector3.INF \
					and Vector2(d.march_to.x - d.position.x, d.march_to.z - d.position.z).length() <= Zombie.MARCH_ARRIVED:
				d.march_to = Vector3.INF # the horde's walk is over
			d.rest = rng.randf_range(3.0, 12.0)


## The map d walks on: the horde's while it marches, else the world's.
func _nav_map(d: Dormant) -> RID:
	return d.march_map if d.march_to != Vector3.INF and d.march_map.is_valid() else get_world_3d().navigation_map


## Whether any zombie is after target.
func hunting(target: Node3D) -> bool:
	for zombie: Zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.state == Zombie.State.HUNT and zombie.target == target:
			return true
	return false


## dice: whose dice pick its facing and kind; the game's (rng) unless said
## otherwise. kind: a ZombieKind's id (characters/zombie/kinds/); "" rolls one
## by their spawn chances.
func add(pos: Vector3, dice: RandomNumberGenerator = null, kind := "") -> Zombie:
	if dice == null:
		dice = rng
	if kind == "":
		kind = ZombieKind.roll(dice).id
	var zombie := ZombieScene.instantiate() as Zombie
	zombie.kind = kind
	zombie.position = pos
	zombie.rotation.y = dice.randf_range(0.0, TAU)
	zombie.driven = true
	zombie.frames_waited = dice.randi() % Zombie.VERY_FAR_TICK # (their turns spread over the frames)
	add_child(zombie)
	zombie.body.driven = true
	all.append(zombie)
	return zombie


## Zombies at the map's ZombieSpawn markers: each one turns up with its marker's
## chance. A marker on the ground spreads them over the ground (hills and all).
func spawn_at_markers() -> void:
	for spawn in _map.zombie_spawns:
		var mine := _map.mine_of(spawn)
		for i in spawn.count:
			if rng.randf() >= spawn.chance:
				continue
			if mine: # spread over the mine's open cells round it, miners among them
				var near := KitMine.cell_at(mine.to_local(spawn.global_position), roundi(mine.to_local(spawn.global_position).y / KitMine.LEVEL))
				var spot := mine.zombie_spot(rng, near, maxi(1, ceili(maxf(spawn.spread.x, spawn.spread.y) / KitMine.CELL)))
				if spot != Vector3.INF:
					add(spot, null, ZombieKind.roll_in_mine(rng).id)
				continue
			var pos := spawn.global_position
			if spawn.spread != Vector2.ZERO:
				for attempt in 20: # not inside a car
					pos = spawn.global_transform * Vector3(rng.randf_range(-spawn.spread.x, spawn.spread.x), 0.0,
							rng.randf_range(-spawn.spread.y, spawn.spread.y))
					if Ground.is_ground_level(spawn.global_position):
						pos = Ground.snap(pos, 0.1)
					if not _map.near_container(pos, ZOMBIE_CONTAINER_CLEARANCE):
						break
			add(pos)


## Each mine's own zombies (its Zombie Density), at the start of a new game.
func spawn_in_mines() -> void:
	for mine in _map.mines:
		for i in mine.zombie_count():
			var spot := mine.zombie_spot(rng)
			if spot != Vector3.INF:
				add(spot, null, ZombieKind.roll_in_mine(rng).id)


func _save_zombies() -> Array:
	var data := [] # the ones still up, data ones too
	for zombie in all:
		if is_instance_valid(zombie) and not zombie.is_dead:
			var entry := {"position": SaveGame.vec_to_array(zombie.global_position),
					"yaw": zombie.rotation.y, "health": zombie.health, "kind": zombie.kind}
			if zombie.march_to != Vector3.INF:
				entry["march"] = SaveGame.vec_to_array(zombie.march_to)
			data.append(entry)
	for d in dormant:
		var entry := {"position": SaveGame.vec_to_array(d.position + Vector3(0, Zombie.GLIDE_LIFT, 0)),
				"yaw": d.yaw, "health": d.health, "kind": d.kind}
		if d.march_to != Vector3.INF:
			entry["march"] = SaveGame.vec_to_array(d.march_to)
		data.append(entry)
	return data


## Throws away the fresh ones and puts up exactly what the save recorded.
## (Nothing is aiming at a zombie yet: the game hasn't run a frame.)
func _load_zombies(data: Array) -> void:
	for zombie in all:
		zombie.get_parent().remove_child(zombie) # out of the "zombies" group right away
		zombie.queue_free()
	all.clear()
	dormant.clear()
	for entry: Dictionary in data:
		var zombie := add(SaveGame.array_to_vec(entry["position"]), null, str(entry.get("kind", "walker")))
		zombie.rotation.y = float(entry.get("yaw", 0.0))
		zombie.health = float(entry.get("health", zombie.max_health))
		if entry.has("march"):
			zombie.march_to = SaveGame.array_to_vec(entry["march"])
