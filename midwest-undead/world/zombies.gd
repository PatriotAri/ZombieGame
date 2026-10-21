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

const Zombie := preload("res://characters/zombie/zombie.gd")
const ZombieScene := preload("res://characters/zombie/zombie.tscn")
const GameMap := preload("res://world/game_map.gd")
const Ground := preload("res://world/ground.gd")
const SaveGame := preload("res://core/save_game.gd")

## Street zombies (a ZombieSpawn with a spread) don't start this close to a car or other container.
const ZOMBIE_CONTAINER_CLEARANCE := 2.5
## Time a frame for the turns of the zombies that don't need one every frame.
const BUDGET_USEC := 3000
const GLIDE_DISTANCE := 50.0
const OPENING_MARGIN := 3.0
const OPENING_CELL := 8.0 # meters: the grid doors and windows are looked up on
## The most one turn covers (one put off and off doesn't jump).
const MAX_TURN := 0.25

var all: Array[Zombie] = [] # every zombie up (and bodies not yet cleared away)
var rng: RandomNumberGenerator # the game's dice (main.gd's)
var _map: GameMap
var _cursor := 0 # where in the crowd the next frame's turns start
var _openings := {} # Vector2i (OPENING_CELL squares) -> PackedVector3Array: the map's doors and windows
## Time a frame for the waiting turns (BUDGET_USEC; tests change it). However
## little, one gets its turn every frame, so the crowd always moves on.
var budget_usec := BUDGET_USEC
## Last frame (for tests and the performance readout): turns given, and how
## many of them glided.
var turns := 0
var glides := 0


func _ready() -> void:
	Saveable.section(self, "zombies", _save_zombies, _load_zombies, Saveable.ZOMBIES)


func setup(map: GameMap, dice: RandomNumberGenerator) -> void:
	_map = map
	rng = dice
	for door in map.doors:
		_add_opening(door.closed_transform().origin)
	for window in map.windows:
		_add_opening(window.global_position)


func _physics_process(delta: float) -> void:
	var count := all.size()
	if count == 0:
		return
	var camera := get_viewport().get_camera_3d()
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


func _add_opening(at: Vector3) -> void:
	var cell := _cell_of(at)
	var here: PackedVector3Array = _openings.get(cell, PackedVector3Array())
	here.append(at)
	_openings[cell] = here # (a packed array is a copy: put it back)


func _near_opening(at: Vector3) -> bool:
	var cell := _cell_of(at)
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for opening: Vector3 in _openings.get(Vector2i(x, y), PackedVector3Array()):
				if opening.distance_squared_to(at) < OPENING_MARGIN * OPENING_MARGIN:
					return true
	return false


static func _cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / OPENING_CELL), floori(at.z / OPENING_CELL))


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
	var data := [] # the ones still up
	for zombie in all:
		if is_instance_valid(zombie) and not zombie.is_dead:
			var entry := {"position": SaveGame.vec_to_array(zombie.global_position),
					"yaw": zombie.rotation.y, "health": zombie.health, "kind": zombie.kind}
			if zombie.march_to != Vector3.INF:
				entry["march"] = SaveGame.vec_to_array(zombie.march_to)
			data.append(entry)
	return data


## Throws away the fresh ones and puts up exactly what the save recorded.
## (Nothing is aiming at a zombie yet: the game hasn't run a frame.)
func _load_zombies(data: Array) -> void:
	for zombie in all:
		zombie.get_parent().remove_child(zombie) # out of the "zombies" group right away
		zombie.queue_free()
	all.clear()
	for entry: Dictionary in data:
		var zombie := add(SaveGame.array_to_vec(entry["position"]), null, str(entry.get("kind", "walker")))
		zombie.rotation.y = float(entry.get("yaw", 0.0))
		zombie.health = float(entry.get("health", zombie.max_health))
		if entry.has("march"):
			zombie.march_to = SaveGame.array_to_vec(entry["march"])
