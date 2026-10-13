extends Node
## Survivors holed up in boarded-up houses around town: four, plus Walt the
## machinist (who makes ammo benches once the woodworker is at the station). Every door and
## window of their house is planked shut from outside (fortifications.gd): pull
## the planks off the door to get in. Each is in the bedroom, by the bed, with a
## couple of cans of food and two health packs on the floor beside them.
## Talk to one and they join you, if the base has room (base_camp.gd; if not,
## they stay put and say so). They make their own way to the police station
## (once you're out of sight of them and of the station), and live in the back
## yard, each with a bedroll. Talk to them there to put them on a garden plot or
## ammo bench, or (the machinist) to have something made.
## main.gd creates it once the town is built and sends conversations here.
## Saved: where each one has got to. (Their planks and supplies are saved with
## the rest of the fortifications and ground items.)

const Building := preload("res://world/building.gd")
const Survivor := preload("res://characters/npcs/survivor.gd")
const SurvivorScene := preload("res://characters/npcs/survivor.tscn")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const Recipes := preload("res://core/recipes.gd")

const OUT_OF_SIGHT := 40.0
const CHECK_INTERVAL := 0.5
## When the base is full (base_camp.gd), whoever you find stays put and says so.
const FULL_LINES: Array[String] = [
	"Seems like there's not enough to go around right now. I'd be better off on my own.",
	"Come find me again later if things change.",
]
const MACHINIST_NEEDS_WOODWORKER := "I can make you an ammo bench, but not the frame for it. Get a woodworker set up at the station and I'll get to work."
## Who, and roughly where: each takes the house nearest their spot. "job":
## what they do at the base besides working a station.
const PEOPLE := [
	{"name": "Marisol Vega", "near": Vector3(-120, 0, 12), "home": Vector3(44.0, 0.1, 26.5),
			"outfit": Color(0.35, 0.55, 0.6), "skin": Color(0.62, 0.46, 0.36),
			"join": ["Don't shoot! ...Okay. Okay, you're real. That's a first in a while.",
				"I'm Marisol. I was a nurse at County General, back when there was a County General.",
				"The police station's still holding? Then I'm going. Somebody there will need patching up."],
			"home_lines": ["Quiet back here, behind the station. I'd almost forgotten what quiet sounds like."]},
	{"name": "Dale Hutchins", "near": Vector3(-110, 0, -12), "home": Vector3(48.5, 0.1, 26.5),
			"outfit": Color(0.42, 0.38, 0.25), "skin": Color(0.74, 0.58, 0.47),
			"join": ["Who's there? ...You're not one of them. Thank God.",
				"Dale Hutchins. Had a farm out past the grain elevator. Boarded myself in here when the town went.",
				"Station's got walls and people? I'll take it. I can still swing a shovel."],
			"home_lines": ["Never thought I'd miss the smell of a feedlot."]},
	{"name": "Priya Raman", "near": Vector3(-80, 0, -12), "home": Vector3(55.5, 0.1, 26.5),
			"outfit": Color(0.5, 0.28, 0.35), "skin": Color(0.55, 0.4, 0.3),
			"join": ["Is it... is it over out there? No. Of course it isn't.",
				"Priya. I was home from college for the summer. My parents went out for supplies the first day.",
				"If there are people at the police station, I want to be with people. I'll go."],
			"home_lines": ["I'm keeping a list of everyone who makes it through the gate. Someone should remember."]},
	{"name": "Gus Lindqvist", "near": Vector3(-50, 0, 12), "home": Vector3(60.0, 0.1, 26.5),
			"outfit": Color(0.25, 0.3, 0.38), "skin": Color(0.78, 0.63, 0.52),
			"join": ["Easy on those planks. Took me all afternoon to put them up.",
				"Gus. I fix engines. Fixed, anyway. Not much driving these days.",
				"The police station, huh? Tell the Chief I'll keep that generator running."],
			"home_lines": ["Generator's running rough. I'll get to it."]},
	{"name": "Walt Brenner", "job": "machinist", "near": Vector3(-135, 0, -12), "home": Vector3(40.0, 0.1, 26.5),
			"outfit": Color(0.3, 0.32, 0.3), "skin": Color(0.7, 0.55, 0.45),
			"join": ["Hands where I can see 'em. ...Fine. You're no bandit.",
				"Walt Brenner. Ran the machine shop on Route 9 for thirty years. Lathes, presses, reloading gear.",
				"Got people at the police station? Then I'll come. Somebody's got to keep you in bullets."],
			"home_lines": []},
]

var survivors: Array[Survivor] = []
var houses: Array[Building] = []
var _player: Node3D
var _dialogue: Node
var _choices: Node # ui/choice_menu.gd
var _crafting: Node # ui/craft_menu.gd
var _base: Node # base_camp.gd
var _woodworker: Node # woodworker_rescue.gd
var _bedrolls := {} # survivor -> its bedroll in the yard
var _timer := 0.0


## Picks the houses, boards them up, and puts everyone (and their supplies) in
## place. Uses no random numbers, so the rest of the town comes out the same.
func setup(buildings: Array, fortifications: Node, builder: RefCounted) -> void:
	for person: Dictionary in PEOPLE:
		var house := _nearest_house(buildings, person["near"])
		houses.append(house)
		fortifications.call("board_building", house)

		var survivor := SurvivorScene.instantiate() as Survivor
		survivor.display_name = person["name"]
		survivor.outfit_color = person["outfit"]
		survivor.skin_color = person["skin"]
		survivor.job = person.get("job", "")
		var spot := house.transform * (house.bed_center + Vector3(0, 0.1, house.bed_toward_room * 1.3))
		survivor.position = spot
		# Facing the front of the house (its door side).
		var toward_door := house.global_basis * Vector3(-1, 0, 0)
		survivor.rotation.y = atan2(-toward_door.x, -toward_door.z)
		get_parent().add_child(survivor)
		survivors.append(survivor)

		# Supplies on the floor beside them.
		var side := house.global_basis * Vector3(1, 0, 0) # toward the back wall
		var along := house.global_basis * Vector3(0, 0, house.bed_toward_room) # away from the bed
		var floor_at := Vector3(spot.x, house.global_position.y + house.FLOOR_Y + 0.05, spot.z)
		builder.call("add_ground_item", "canned_food", 1, floor_at + side * 0.6 + along * 0.3, 0.4)
		builder.call("add_ground_item", "canned_food", 1, floor_at + side * 0.8 + along * 0.6, 1.9)
		builder.call("add_ground_item", "health_pack", 1, floor_at - side * 0.6 + along * 0.3, 0.2)
		builder.call("add_ground_item", "health_pack", 1, floor_at - side * 0.8 + along * 0.65, 2.6)
	fortifications.call("rebake")


## Who's talking to them, and the base they'd join (main.gd creates these after
## the town).
func attach(player: Node3D, dialogue: Node, choices: Node, crafting: Node, base: Node, woodworker: Node) -> void:
	_player = player
	_dialogue = dialogue
	_choices = choices
	_crafting = crafting
	_base = base
	_woodworker = woodworker


## Zombies the town put inside a survivor's house go outside it instead (they
## can't have got in: it's boarded up). Call once every zombie is placed.
func move_zombies_out(zombies: Array) -> void:
	for zombie: Node3D in zombies:
		for house in houses:
			var local := house.global_transform.affine_inverse() * zombie.global_position
			if local.x > 0.0 and local.x < house.size_depth and absf(local.z) < house.size_width / 2.0:
				# Out front, clawing at the boards.
				zombie.global_position = house.global_transform * Vector3(-3.0, 0.1, house.door_z + randf_range(-2.0, 2.0))
				break


## Interact on a survivor.
func talk(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0:
		return
	var person: Dictionary = PEOPLE[i]
	match survivor.state:
		Survivor.State.WAITING:
			if _base.call("is_full"):
				_dialogue.call("start", survivor.display_name, FULL_LINES, _player)
				return
			var lines: Array[String] = []
			lines.assign(person["join"])
			_dialogue.call("start", survivor.display_name, lines, _player, _recruited.bind(survivor))
		Survivor.State.HOME:
			if survivor.job == "machinist":
				var home: bool = _woodworker.call("state") == Woodworker.State.HOME
				_crafting.call("open", _player, survivor.display_name, Recipes.MACHINIST if home else [],
						"" if home else MACHINIST_NEEDS_WOODWORKER)
			else:
				_offer_jobs(survivor, person)


## A survivor at the base: what are they doing, and do you want them on a station?
func _offer_jobs(survivor: Survivor, person: Dictionary) -> void:
	var line: String = person["home_lines"][0]
	var piece := survivor.work_piece if survivor.working and is_instance_valid(survivor.work_piece) else null
	if piece != null:
		line = "I'm on the %s. %s" % ["garden" if piece.get("kind") == "garden_plot" else "ammo bench", line]
	var options := []
	for station: Array in [["garden_plot", "Work a garden plot"], ["ammo_bench", "Work an ammo bench"]]:
		var free: bool = _base.call("free_station", station[0]) != null
		var label: String = station[1] if free else station[1] + "  (none free)"
		options.append([label, func() -> void: _base.call("assign", survivor, station[0]), free])
	options.append(["Stop working", func() -> void: _base.call("unassign", survivor), piece != null])
	options.append(["Never mind", Callable(), true])
	_choices.call("open", _player, survivor.display_name, line, options)


func _recruited(survivor: Survivor) -> void:
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
		var home: Vector3 = PEOPLE[i]["home"]
		if survivor.state == Survivor.State.TRAVELLING and at.distance_to(survivor.global_position) > OUT_OF_SIGHT \
				and at.distance_to(home) > OUT_OF_SIGHT:
			_send_home(i)


func recruited_count() -> int:
	return survivors.filter(func(s: Survivor) -> bool: return s.state != Survivor.State.WAITING).size()


func save_state() -> Array:
	return survivors.map(func(s: Survivor) -> int: return s.state)


func load_state(data: Array) -> void:
	for i in mini(data.size(), survivors.size()):
		var saved := int(data[i])
		if saved == Survivor.State.HOME:
			_send_home(i)
		elif saved == Survivor.State.TRAVELLING:
			survivors[i].state = Survivor.State.TRAVELLING


## Back to their spot in the yard (off a job, or just arrived).
func go_home_spot(survivor: Survivor) -> void:
	var i := survivors.find(survivor)
	if i < 0 or survivor.state != Survivor.State.HOME:
		return
	survivor.global_position = PEOPLE[i]["home"]
	survivor.rotation.y = 0.0 # facing the back of the station


## At home in the station's back yard, with a bedroll.
func _send_home(i: int) -> void:
	var survivor := survivors[i]
	var home: Vector3 = PEOPLE[i]["home"]
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


func _nearest_house(buildings: Array, near: Vector3) -> Building:
	var best: Building = null
	var best_dist := INF
	for b in buildings:
		var building := b as Building
		if building == null or not building.is_house or building in houses:
			continue
		var dist := building.global_position.distance_to(near)
		if dist < best_dist:
			best = building
			best_dist = dist
	return best
