extends SceneTree
## People as data (characters/npcs/person_data.gd, world/markers/person_marker.gd):
## a person marker puts the Quartermaster there from their person file (id,
## name, trading); a marker with Start Here off puts nobody there; a plain
## person's own lines play when there's nothing else to say; a quest brings the
## wagon trader in, moves the Quartermaster and sends a stranger off, each only
## once you're away; a save and load keeps all that, and traders' stock.
const TestMap := preload("res://tests/support/test_map.gd")
const SaveGame := preload("res://core/save_game.gd")
var main: Node
var test_map: PackedScene
var q: Node
var p: Node
var f := 0
var fails := 0
var stranger: PersonData

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	stranger = PersonData.new()
	stranger.id = "stranger"; stranger.display_name = "Stranger"
	stranger.talk = QuestDialogue.of(["Keep walking."] as Array[String])
	var map := TestMap.begin()
	person(map, load("res://characters/npcs/people/quartermaster.tres"), Vector3(5, 0.1, 5), true)
	person(map, load("res://characters/npcs/people/wagon_trader.tres"), Vector3(-5, 0.1, 5), false)
	person(map, stranger, Vector3(0, 0.1, 9), true)
	TestMap.quest_marker(map, "gate", "point", Vector3(120, 0.1, 0))
	TestMap.quest_marker(map, "store", "point", Vector3(-120, 0.1, 0))
	test_map = TestMap.finish(map)
	_start()

func person(map: Node3D, who: PersonData, at: Vector3, here: bool) -> void:
	var m := KitPersonMarker.new()
	m.name = "Person_" + who.id
	m.person = who
	m.start_here = here
	m.position = at
	TestMap.add(map, "People", m)

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)

func quest() -> Quest:
	var quest := Quest.new()
	quest.id = "test_people"; quest.title = "People"
	var spawn := ActionSpawnPerson.new(); spawn.person = load("res://characters/npcs/people/wagon_trader.tres"); spawn.at = "gate"
	var move := ActionMovePerson.new(); move.npc = "quartermaster"; move.to = "store"
	var gone := ActionRemovePerson.new(); gone.npc = "stranger"
	quest.on_start.assign([spawn, move, gone])
	var wait := ObjectiveWaitFor.new() # (never done: the quest stays on)
	var flag := ConditionFlag.new(); flag.flag = "never"
	wait.conditions.assign([flag])
	var s := QuestStage.new(); s.id = "wait"; s.objectives.assign([wait])
	quest.stages.assign([s])
	return quest

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		3:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			var qm: HumanNPC = q.npc("quartermaster")
			check(qm != null and qm.display_name == "Quartermaster" and qm.global_position.distance_to(Vector3(5, 0.1, 5)) < 0.5,
					"the Quartermaster stands at their marker, from their file")
			check(qm != null and qm.interact_prompt().begins_with("trade with"), "...and trades (their scene's own business)")
			check(q.npc("wagon_trader") == null, "a marker with Start Here off: nobody there yet")
			var s: HumanNPC = q.npc("stranger")
			check(s != null and s.interact_prompt() == "talk to Stranger", "a plain person: \"talk to Stranger\"")
			main._on_npc_interacted(s)
			check(main.dialogue.is_open() and main.dialogue._lines == (["Keep walking."] as Array[String]), "...who says their own lines")
			main.dialogue._finish()
			qm.stock.add("pistol_ammo", 9)
			# The quest: you're right by the Quartermaster and the stranger, so they wait.
			q.add_quest(quest())
		30:
			check(q.npc("wagon_trader") != null and q.npc("wagon_trader").global_position.distance_to(q.world.marker("gate").global_position) < 0.5,
					"the quest brings the wagon trader in at the gate")
			check(q.npc("quartermaster").global_position.distance_to(Vector3(5, 0.1, 5)) < 0.5 and q.npc("stranger") != null,
					"you're right there: the Quartermaster hasn't moved, the stranger hasn't gone")
			p.global_position = Vector3(0, 1, -80) # away from all of them
		60:
			check(q.npc("quartermaster").global_position.distance_to(q.world.marker("store").global_position) < 0.5, "you left: the Quartermaster's moved to the store")
			check(q.npc("stranger") == null or q.npc("stranger").is_queued_for_deletion(), "...and the stranger's gone")
			main._save_game(SaveGame.new_path())
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main); main.free()
			main = null
			_start()
		64:
			q = main.quests
			q.add_quest(quest()) # (made in code: added again; the save puts its state back)
			q.load_state(SaveGame.read(SaveGame.latest())["quest"])
			preload("res://world/save_io.gd")._load_traders(main, SaveGame.read(SaveGame.latest())["traders"])
			q.end_load()
		70:
			check(q.npc("wagon_trader") != null and q.npc("wagon_trader").global_position.distance_to(q.world.marker("gate").global_position) < 0.5,
					"loaded: the wagon trader's back at the gate")
			check(q.npc("quartermaster").global_position.distance_to(q.world.marker("store").global_position) < 0.5, "...the Quartermaster at the store")
			check(q.npc("stranger") == null or q.npc("stranger").is_queued_for_deletion(), "...and no stranger")
			check(q.npc("quartermaster").stock.count("pistol_ammo") >= 9, "...and the Quartermaster's stock kept (%d pistol ammo)" % q.npc("quartermaster").stock.count("pistol_ammo"))
			print("FAILS: %d" % fails)
			return true
	return false
