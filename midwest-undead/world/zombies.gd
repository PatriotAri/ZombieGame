extends Node3D
## The zombies: every one up (and the bodies not yet cleared away), adding
## them, the ones a new game starts with (at the map's ZombieSpawn markers and
## in its mines), and saving them. world/zombie_population.gd tops them up over
## time and world/horde.gd sends them across the map; both add theirs here.

const Zombie := preload("res://characters/zombie/zombie.gd")
const ZombieScene := preload("res://characters/zombie/zombie.tscn")
const GameMap := preload("res://world/game_map.gd")
const Ground := preload("res://world/ground.gd")
const SaveGame := preload("res://core/save_game.gd")

## Street zombies (a ZombieSpawn with a spread) don't start this close to a car or other container.
const ZOMBIE_CONTAINER_CLEARANCE := 2.5

var all: Array[Zombie] = [] # every zombie up (and bodies not yet cleared away)
var rng: RandomNumberGenerator # the game's dice (main.gd's)
var _map: GameMap


func _ready() -> void:
	Saveable.section(self, "zombies", _save_zombies, _load_zombies, Saveable.ZOMBIES)


func setup(map: GameMap, dice: RandomNumberGenerator) -> void:
	_map = map
	rng = dice


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
	add_child(zombie)
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
