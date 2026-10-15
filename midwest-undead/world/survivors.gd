extends Node
## Survivors holed up in boarded-up houses around town. Each is a file in
## characters/npcs/survivors/ (SurvivorData: who they are and what they say):
## four, plus Walt the machinist (who makes sheet metal, and ammo benches once
## the woodworker is at the station). Every door and window of their house is
## planked shut from outside (set "boarded at start" in the map scene): pull
## the planks off the door to get in. Each is in the
## bedroom, by the bed, with a couple of cans of food and two health packs on the
## floor beside them (ground items in the map scene).
## Where each one starts, and their spot in the station's back yard, are
## SpawnPoints in the map scene (roles "survivor" and "survivor_home", with the
## person's name).
## Talk to one and they join you, if the base has room (base_camp.gd; if not,
## they stay put and say so), the way their join talk says (a "join" reply, or
## hearing it out; quests/conversation.gd plays it). They make their own way to the police station
## (once you're out of sight of them and of the station), and live in the back
## yard, each with a bedroll. Talk to them there to put them on a garden plot or
## ammo bench, or (the machinist) to have something made.
## main.gd creates it once the map is loaded and sends conversations here.
## Saved: where each one has got to, by name. (Their planks and supplies are saved with
## the rest of the fortifications and ground items.)

const Building := preload("res://world/building.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")
const Survivor := preload("res://characters/npcs/survivor.gd")
const SurvivorScene := preload("res://characters/npcs/survivor.tscn")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const Recipes := preload("res://core/recipes.gd")
const Conversation := preload("res://quests/conversation.gd")

const DIR := "res://characters/npcs/survivors/"
## Saves from before survivors were files list them in this order.
const OLD_SAVE_ORDER := ["Marisol Vega", "Dale Hutchins", "Priya Raman", "Gus Lindqvist", "Walt Brenner"]

const OUT_OF_SIGHT := 40.0
const CHECK_INTERVAL := 0.5
## When the base is full (base_camp.gd), whoever you find stays put and says so.
const FULL_LINES: Array[String] = [
	"Seems like there's not enough to go around right now. I'd be better off on my own.",
	"Come find me again later if things change.",
]
const STATION_NAMES := {"garden_plot": "garden", "ammo_bench": "ammo bench", "shell_bench": "shell bench",
		"rifle_bench": "rifle bench"}
const MACHINIST_NEEDS_WOODWORKER := "I can press scrap into sheet metal for you. Ammo benches need frames, though: get a woodworker set up at the station and I'll make those too."


var survivors: Array[Survivor] = []
var houses: Array[Building] = [] # the house each one is holed up in (null if their spot isn't in one)
var _people: Array[SurvivorData] = [] # each survivor's file
var _homes: Array[Vector3] = [] # each survivor's spot in the station yard
var _player: Node3D
var _dialogue: Node
var _choices: Node # ui/choice_menu.gd
var _conversation: Conversation
var _crafting: Node # ui/craft_menu.gd
var _base: Node # base_camp.gd
var _woodworker: Node # woodworker_rescue.gd
var _bedrolls := {} # survivor -> its bedroll in the yard
var _timer := 0.0


## spots: the map's SpawnPoints. Puts everyone in place.
func setup(spots: Array) -> void:
	for person in _load_people():
		var start := _spot(spots, "survivor", person.display_name)
		var home := _spot(spots, "survivor_home", person.display_name)
		if start == null or home == null:
			push_warning("%s has no \"survivor\" or \"survivor_home\" SpawnPoint in the map scene." % person.display_name)
			continue
		var survivor := SurvivorScene.instantiate() as Survivor
		survivor.display_name = person.display_name
		survivor.outfit_color = person.outfit_color
		survivor.skin_color = person.skin_color
		survivor.job = "" if person.job == "none" else person.job
		survivor.position = start.global_position
		survivor.rotation.y = start.global_rotation.y
		get_parent().add_child(survivor)
		survivors.append(survivor)
		_people.append(person)
		_homes.append(home.global_position)
		var house: Node = start.get_parent()
		while house != null and not house is Building:
			house = house.get_parent()
		houses.append(house as Building)


## Every survivor file, by file name.
func _load_people() -> Array[SurvivorData]:
	var people: Array[SurvivorData] = []
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for file: String in files:
		file = file.trim_suffix(".remap") # exported games list "x.tres.remap"
		if not file.ends_with(".tres"):
			continue
		var person := load(DIR + file) as SurvivorData
		if person == null or person.display_name == "":
			push_warning("%s isn't a survivor with a name: skipped." % (DIR + file))
			continue
		people.append(person)
	return people


func _spot(spots: Array, role: String, person_name: String) -> SpawnPoint:
	for spot: SpawnPoint in spots:
		if spot.role == role and spot.person == person_name:
			return spot
	return null


## Who's talking to them, and the base they'd join (main.gd creates these after
## the town).
func attach(player: Node3D, dialogue: Node, choices: Node, crafting: Node, base: Node, woodworker: Node) -> void:
	_player = player
	_dialogue = dialogue
	_choices = choices
	_conversation = Conversation.new(player, dialogue, choices)
	_crafting = crafting
	_base = base
	_woodworker = woodworker


## Zombies the map put inside a survivor's house go outside it instead (they
## can't have got in: it's boarded up). Call once every zombie is placed.
func move_zombies_out(zombies: Array) -> void:
	for zombie: Node3D in zombies:
		for house in houses:
			if house == null:
				continue
			var local := house.global_transform.affine_inverse() * zombie.global_position
			if local.x > 0.0 and local.x < house.size_depth and absf(local.z) < house.size_width / 2.0:
				# Out front, clawing at the boards.
				zombie.global_position = house.global_transform * Vector3(-3.0, 0.1, house.front_door_z() + randf_range(-2.0, 2.0))
				break


## Interact on a survivor.
func talk(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0:
		return
	var person := _people[i]
	match survivor.state:
		Survivor.State.WAITING:
			if _base.call("is_full"):
				_dialogue.call("start", survivor.display_name, FULL_LINES, _player)
				return
			# With a "join" reply, that's what brings them; without one, hearing them out.
			var by_reply := Conversation.has_action(person.join_talk, "join")
			_conversation.play(person.join_talk, survivor.display_name,
					Callable() if by_reply else _recruited.bind(survivor),
					func(action: String) -> void:
						if action == "join":
							_recruited(survivor))
		Survivor.State.HOME:
			if person.base_talk:
				_conversation.play(person.base_talk, survivor.display_name, _work_menu.bind(survivor, person))
			else:
				_work_menu(survivor, person)


## At the base: the machinist's crafting, or everyone else's stations.
func _work_menu(survivor: Survivor, person: SurvivorData) -> void:
	if survivor.job == "machinist":
		var home: bool = _woodworker.call("state") == Woodworker.State.HOME
		_crafting.call("open", _player, survivor.display_name,
				Recipes.MACHINIST_ANYTIME + (Recipes.MACHINIST if home else []),
				"" if home else MACHINIST_NEEDS_WOODWORKER)
	else:
		_offer_jobs(survivor, person)


## A survivor at the base: what are they doing, and do you want them on a station?
func _offer_jobs(survivor: Survivor, person: SurvivorData) -> void:
	var line := person.base_line
	var piece := survivor.work_piece if survivor.working and is_instance_valid(survivor.work_piece) else null
	if piece != null:
		line = "I'm on the %s. %s" % [STATION_NAMES[piece.get("kind")], line]
	var options := []
	for station: Array in [["garden_plot", "Work a garden plot"], ["ammo_bench", "Work an ammo bench"],
			["shell_bench", "Work a shell bench"], ["rifle_bench", "Work a rifle bench"]]:
		var free: bool = _base.call("free_station", station[0]) != null
		var label: String = station[1] if free else station[1] + "  (none free)"
		options.append([label, func() -> void: _base.call("assign", survivor, station[0]), free])
	options.append(["Stop working", func() -> void: _base.call("unassign", survivor), piece != null])
	options.append(["Never mind", Callable(), true])
	_choices.call("open", _player, survivor.display_name, line, options)


func _recruited(survivor: Survivor) -> void:
	if survivor.state != Survivor.State.WAITING or _base.call("is_full"):
		return
	survivor.state = Survivor.State.TRAVELLING
	_player.emit_signal("notify", "%s is heading to the police station." % survivor.display_name)


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var at := _player.global_position
	for i in survivors.size():
		var survivor := survivors[i]
		var home := _homes[i]
		if survivor.state == Survivor.State.TRAVELLING and at.distance_to(survivor.global_position) > OUT_OF_SIGHT \
				and at.distance_to(home) > OUT_OF_SIGHT:
			_send_home(i)


func recruited_count() -> int:
	return survivors.filter(func(s: Survivor) -> bool: return s.state != Survivor.State.WAITING).size()


## name -> state.
func save_state() -> Dictionary:
	var data := {}
	for survivor in survivors:
		data[survivor.display_name] = survivor.state
	return data


## data: name -> state (or, from older saves, a list in OLD_SAVE_ORDER).
func load_state(data: Variant) -> void:
	var by_name := {}
	if data is Array:
		for i in mini((data as Array).size(), OLD_SAVE_ORDER.size()):
			by_name[OLD_SAVE_ORDER[i]] = data[i]
	elif data is Dictionary:
		by_name = data
	for i in survivors.size():
		if not by_name.has(survivors[i].display_name):
			continue
		var saved := int(by_name[survivors[i].display_name])
		if saved == Survivor.State.HOME:
			_send_home(i)
		elif saved == Survivor.State.TRAVELLING:
			survivors[i].state = Survivor.State.TRAVELLING


## Back to their spot in the yard (off a job, or just arrived).
func go_home_spot(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0 or survivor.state != Survivor.State.HOME:
		return
	survivor.global_position = _homes[i]
	survivor.rotation.y = 0.0 # facing the back of the station


## At home in the station's back yard, with a bedroll.
func _send_home(i: int) -> void:
	var survivor := survivors[i]
	var home := _homes[i]
	survivor.state = Survivor.State.HOME
	go_home_spot(survivor)
	if _bedrolls.has(survivor):
		return
	var bedroll := StaticBody3D.new()
	bedroll.position = home + Vector3(1.0, 0.06, 0.4)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.12, 1.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.36, 0.28)
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	bedroll.add_child(inst)
	get_parent().add_child(bedroll)
	_bedrolls[survivor] = bedroll
