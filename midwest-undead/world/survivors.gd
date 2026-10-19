extends Node
## Survivors holed up in boarded-up houses around town. Each is a file in
## characters/npcs/survivors/ (SurvivorData: who they are and what they say):
## four, plus Walt the machinist (who makes sheet metal, and ammo benches once
## the woodworker is at the station). Every door and window of their house is
## planked shut from outside (set "boarded at start" in the map scene): pull
## the planks off the door to get in. Each is in the
## bedroom, by the bed, with a couple of cans of food and two health packs on the
## floor beside them (ground items in the map scene).
## Where each one starts is a SpawnPoint in the map scene (role "survivor",
## with the person's name); a "survivor_home" SpawnPoint gives them their own
## spot at the police station (otherwise they stand round the camp).
## Talk to one and they join you, if a camp has room (world/camps.gd; if not,
## they stay put and say so), the way their join talk says (a "join" reply, or
## hearing it out; quests/conversation.gd plays it). With room at more than one
## camp, you pick which. They make their own way there (once you're out of
## sight of them and of the camp), and live there, each with a bedroll. Talk to
## them there to put them on a garden plot or ammo bench, post them on a guard
## post, or (the machinist) to have something made.
## main.gd creates it once the map is loaded and sends conversations here.
## Saved: where each one has got to and which camp they live at, by name.
## (Their planks and supplies are saved with the rest of the fortifications and
## ground items.)

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
## When every camp is full (camps.gd), whoever you find stays put and says so.
const FULL_LINES: Array[String] = [
	"Seems like there's not enough to go around right now. I'd be better off on my own.",
	"Come find me again later if things change.",
]
const MACHINIST_NEEDS_WOODWORKER := "I can press scrap into sheet metal for you. Ammo benches need frames, though: get a woodworker set up at the station and I'll make those too."


var survivors: Array[Survivor] = []
var houses: Array[Building] = [] # the house each one is holed up in (null if their spot isn't in one)
var _people: Array[SurvivorData] = [] # each survivor's file
var _player: Node3D
var _dialogue: Node
var _choices: Node # ui/choice_menu.gd
var _conversation: Conversation
var _crafting: Node # ui/craft_menu.gd
var _camps: Node # camps.gd
var _woodworker: Node # woodworker_rescue.gd
var _bedrolls := {} # survivor -> its bedroll in the yard
var _timer := 0.0


## spots: the map's SpawnPoints. Puts everyone in place.
func setup(spots: Array) -> void:
	for person in _load_people():
		var start := _spot(spots, "survivor", person.display_name)
		if start == null:
			push_warning("%s has no \"survivor\" SpawnPoint in the map scene." % person.display_name)
			continue
		var survivor := SurvivorScene.instantiate() as Survivor
		survivor.display_name = person.display_name
		if person.model:
			survivor.model = person.model
		survivor.outfit_color = person.outfit_color
		survivor.skin_color = person.skin_color
		survivor.job = "" if person.job == "none" else person.job
		survivor.position = start.global_position
		survivor.rotation.y = start.global_rotation.y
		get_parent().add_child(survivor)
		survivors.append(survivor)
		_people.append(person)
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


## Their own spots at the police station: name -> where (the "survivor_home" SpawnPoints).
static func station_homes(spots: Array) -> Dictionary:
	var homes := {}
	for spot: SpawnPoint in spots:
		if spot.role == "survivor_home" and spot.person != "":
			homes[spot.person] = spot.global_position
	return homes


## Who's talking to them, and the camps they'd join (main.gd creates these after
## the town).
func attach(player: Node3D, dialogue: Node, choices: Node, crafting: Node, camps: Node, woodworker: Node) -> void:
	_player = player
	_dialogue = dialogue
	_choices = choices
	_conversation = Conversation.new(player, dialogue, choices)
	_crafting = crafting
	_camps = camps
	_woodworker = woodworker


## Zombies the map put inside a survivor's house go outside it instead (they
## can't have got in: it's boarded up). Call once every zombie is placed.
func move_zombies_out(zombies: Array) -> void:
	for zombie: Node3D in zombies:
		for house in houses:
			if house == null:
				continue
			var local := house.global_transform.affine_inverse() * zombie.global_position
			if house.contains_local(Vector2(local.x, local.z)):
				# Out front, clawing at the boards.
				var spread := house.global_basis.z * randf_range(-2.0, 2.0)
				zombie.global_position = house.outside_front_door(3.0) + spread + Vector3(0, 0.1, 0)
				break


## Interact on a survivor.
func talk(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0:
		return
	var person := _people[i]
	match survivor.state:
		Survivor.State.WAITING:
			if (_camps.call("with_room") as Array).is_empty():
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


## A survivor at camp: what are they doing, and do you want them on a station
## or a guard post?
func _offer_jobs(survivor: Survivor, person: SurvivorData) -> void:
	var line := person.base_line
	var camp: Variant = _camps.call("camp_named", survivor.camp_name)
	var piece := survivor.work_piece if survivor.working and is_instance_valid(survivor.work_piece) else null
	if piece != null:
		line = "I'm on the %s. %s" % [_camps.STATION_NAMES[piece.get("kind")], line]
	var options := []
	for station: Array in [["garden_plot", "Work a garden plot"], ["ammo_bench", "Work an ammo bench"],
			["shell_bench", "Work a shell bench"], ["rifle_bench", "Work a rifle bench"]]:
		var free: bool = camp != null and _camps.call("free_station", camp, station[0]) != null
		var label: String = station[1] if free else station[1] + "  (none free)"
		options.append([label, func() -> void: _camps.call("assign", survivor, station[0]), free])
	var posts: Array = _camps.call("free_posts", camp) if camp != null else []
	var guard_label := "Guard a post" if not posts.is_empty() else "Guard a post  (none free within %d m)" % roundi(_camps.RANGE)
	options.append([guard_label, func() -> void: _pick_post(survivor, posts), not posts.is_empty()])
	options.append(["Stop working", func() -> void: _camps.call("unassign", survivor), piece != null])
	options.append(["Never mind", Callable(), true])
	_choices.call("open", _player, survivor.display_name, line, options)


## With more than one free post, you pick (nearest first).
func _pick_post(survivor: Survivor, posts: Array) -> void:
	posts.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(_player.global_position) < b.global_position.distance_to(_player.global_position))
	if posts.size() == 1:
		_camps.call("post_guard", survivor, posts[0])
		return
	var options := []
	for post: Node3D in posts:
		var kind := "tower" if post.get("below") != null else "post"
		var label := "The guard %s %d m %s of you" % [kind, roundi(post.global_position.distance_to(_player.global_position)),
				_compass(post.global_position - _player.global_position)]
		options.append([label, func() -> void: _camps.call("post_guard", survivor, post), true])
	options.append(["Never mind", Callable(), true])
	_choices.call("open", _player, survivor.display_name, "Which one?", options)


static func _compass(dir: Vector3) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var angle := atan2(dir.x, -dir.z) # 0 north, clockwise
	return names[posmod(roundi(angle / (PI / 4.0)), 8)]


## Joining: off to a camp with room (you pick, if there's more than one).
func _recruited(survivor: Survivor) -> void:
	if survivor.state != Survivor.State.WAITING:
		return
	var open: Array = _camps.call("with_room")
	if open.is_empty():
		_dialogue.call("start", survivor.display_name, FULL_LINES, _player)
		return
	if open.size() == 1:
		_send_to(survivor, open[0])
		return
	var options := []
	for camp in open:
		var label := "%s  (%d / %d)" % [camp.name, _camps.call("population", camp), _camps.call("capacity", camp)]
		options.append([label, func() -> void: _send_to(survivor, camp), true])
	_choices.call("open", _player, survivor.display_name, "Where should I head?", options)


func _send_to(survivor: Survivor, camp: Variant) -> void:
	survivor.camp_name = camp.name
	survivor.state = Survivor.State.TRAVELLING
	_player.emit_signal("notify", "%s is heading to %s." % [survivor.display_name, camp.name])


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var at := _player.global_position
	for i in survivors.size():
		var survivor := survivors[i]
		if survivor.state != Survivor.State.TRAVELLING:
			continue
		var home: Vector3 = _camps.call("home_spot", survivor)
		if at.distance_to(survivor.global_position) > OUT_OF_SIGHT and at.distance_to(home) > OUT_OF_SIGHT:
			_send_home(i)


## name -> {"state", "camp"}.
func save_state() -> Dictionary:
	var data := {}
	for survivor in survivors:
		data[survivor.display_name] = {"state": survivor.state, "camp": survivor.camp_name}
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
		var entry: Variant = by_name[survivors[i].display_name]
		var saved := int(entry["state"]) if entry is Dictionary else int(entry)
		if entry is Dictionary:
			survivors[i].camp_name = str(entry.get("camp", ""))
		if survivors[i].camp_name == "" and saved != Survivor.State.WAITING:
			survivors[i].camp_name = _camps.station.name # (older saves: everyone lived at the station)
		if saved == Survivor.State.HOME:
			_send_home(i)
		elif saved == Survivor.State.TRAVELLING:
			survivors[i].state = Survivor.State.TRAVELLING


## Back to their spot at camp (off a job, or just arrived), with their bedroll.
func go_home_spot(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0 or survivor.state != Survivor.State.HOME:
		return
	var home: Vector3 = _camps.call("home_spot", survivor)
	survivor.global_position = home
	var camp: Variant = _camps.call("camp_named", survivor.camp_name)
	if camp != null: # facing the middle of the camp
		var to: Vector3 = camp.center - home
		if Vector2(to.x, to.z).length() > 0.5:
			survivor.rotation.y = atan2(-to.x, -to.z)
	if _bedrolls.has(survivor):
		(_bedrolls[survivor] as Node3D).position = home + Vector3(1.0, 0.06, 0.4)


## At home at their camp, with a bedroll.
func _send_home(i: int) -> void:
	var survivor := survivors[i]
	survivor.state = Survivor.State.HOME
	go_home_spot(survivor)
	if _bedrolls.has(survivor):
		return
	var home: Vector3 = _camps.call("home_spot", survivor)
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
