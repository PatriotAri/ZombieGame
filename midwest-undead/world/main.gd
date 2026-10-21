extends Node3D
## The game scene's root: makes the game's pieces in order and connects them,
## and handles what's left over (the story's wiring, autosave, dying and
## starting again, the items lying around). The pieces live in their own
## scripts:
##   world/game_map.gd    the map: loads world/map/map.tscn (open it to change
##                        the map in the editor; see HOW_TO_MAP.md), the sky,
##                        the navigation, and finds what's on it
##   world/zombies.gd     every zombie: adding them, the ones a game starts with
##   world/people.gd      you and the NPCs, and the talk menu
##   ui/game_ui.gd        the HUD and the menus, and what opens them
##   world/map/           the map: the terrain (Terrain3D) and everything placed on it
##   world/kit/           the building kit buildings are made of (see HOW_TO_BUILD.md)
##   world/markers/       markers on the map: where people and zombies start, places
##   world/nav_tiles.gd   where zombies can walk (the navigation mesh, in tiles)
##   world/ground.gd      how high the ground is anywhere
##   world/loot.gd        rolls the containers' loot tables (items/loot/)
##   world/save_io.gd     what a save holds, gathered and put back
##   world/map_summary.gd what the map screen shows of the map
##   quests/              the main story and side quests (see QUESTS.md)
## Each piece is handed what it needs in its setup().
##
## What's fixed and what's random: the map, its containers and the items lying
## around are exactly what the map scene has. What's in the containers (beyond
## their fixed items), which zombies turn up at the ZombieSpawn markers, the
## extra zombies, the ones arriving over time and the hordes (world/horde.gd)
## are random every new game.
##
## TUNING: select the Main node in the Scene dock and use the Inspector. Every
## @export below shows up there, grouped. Values you change in the Inspector are
## saved into main.tscn and override the defaults written here.
## The player, zombies and NPCs are their own scenes: tune them in player.tscn,
## zombie.tscn, guard.tscn and shopkeeper.tscn (open the scene, select its root
## node, use the Inspector).

const Player := preload("res://characters/player/player.gd")
const Controls := preload("res://core/controls.gd")
const GameData := preload("res://core/game_data.gd")
const GroundItem := preload("res://items/ground_item.gd")
const Settings := preload("res://core/settings.gd")
const SaveGame := preload("res://core/save_game.gd")
const SaveIO := preload("res://world/save_io.gd")
const SceneFade := preload("res://ui/scene_fade.gd")
const GameMap := preload("res://world/game_map.gd")
const Zombies := preload("res://world/zombies.gd")
const People := preload("res://world/people.gd")
const GameUI := preload("res://ui/game_ui.gd")
const DayNight := preload("res://world/day_night.gd")
const Fortifications := preload("res://world/fortifications.gd")
const Structures := preload("res://world/structures.gd")
const Survivors := preload("res://world/survivors.gd")
const Zones := preload("res://world/zones.gd")
const Camps := preload("res://world/camps.gd")
const ZombiePopulation := preload("res://world/zombie_population.gd")
const Horde := preload("res://world/horde.gd")
const Discoveries := preload("res://world/discoveries.gd")
const MapSummary := preload("res://world/map_summary.gd")
const QuestManager := preload("res://quests/quest_manager.gd")
const TraderArrival := preload("res://world/trader_arrival.gd")
const WoodworkerRescue := preload("res://world/woodworker_rescue.gd")
const Salvage := preload("res://world/salvage.gd")

@export_group("World")
## The map to play on. Edit world/map/map.tscn to change it (HOW_TO_MAP.md).
@export var map_scene: PackedScene = preload("res://world/map/map.tscn")
## More zombies scattered around the map at the start (where you can't see
## them, 30 m+ from you), on top of the ones at the map's ZombieSpawn markers.
@export_range(0, 300) var extra_zombies := 60
## How many zombies are up at once. When there are fewer, new ones turn up now
## and then somewhere you can't see (see world/zombie_population.gd).
@export_range(0, 400) var zombie_population := 100
## Seconds between new arrivals while there are fewer than zombie_population.
@export var zombie_respawn_seconds_day := 30.0
@export var zombie_respawn_seconds_night := 10.0

@export_group("Time of Day")
## 8:00 AM: a full day of light to get your bearings before the first night.
@export_range(0.0, 23.99) var start_hour := 8.0
## Real seconds per in-game hour. 120 = a 48-minute day: 24 minutes of
## daylight (6 AM to 6 PM), then 24 of night.
@export_range(1.0, 600.0) var seconds_per_game_hour := 120.0
## How bright the darkest night is. Raise it if nights are too dark on your screen.
@export var night_ambient := Color(0.05, 0.06, 0.1)

## Autosave once you're this close to the safe house while it's your objective.
const AUTOSAVE_DISTANCE := 20.0

var map: GameMap
var zombies: Zombies
var people: People
var ui: GameUI
var player: Player # (people's)
var day_night: DayNight # (the map's)
var fortifications: Fortifications
var structures: Structures # what you build: scaffolding, guard posts, fences, gates
var survivors: Survivors # the ones holed up in boarded-up houses
var zones: Zones
var camps: Camps # the base camps: who lives where, jobs, guards, supply crates
var zombie_population_node: ZombiePopulation
var horde: Horde # every couple of weeks, a horde crosses the map
var discoveries: Discoveries
var quests: QuestManager # the main story and side quests (quests/)
var trader_arrival: TraderArrival # the wagon trader who comes once enough zombies are killed round the station
var woodworker_rescue: WoodworkerRescue # the woodworker held at the bandit camp
var salvage: Salvage # stripping cars and furniture for materials
var safe_house_point := Vector3.ZERO # the "Safe House" place (quest marker target)
## A new game's random rolls: what's in the containers, which zombies turn up.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Controls.setup()
	Settings.load_settings() # before anything can play a sound: it creates the Effects bus
	rng.randomize()
	_setup_world()
	_setup_characters()
	_setup_camps_and_zombies()
	_setup_ui()
	_setup_story()
	Saveable.section(self, "ground_items", _save_ground_items, _load_ground_items, Saveable.GROUND_ITEMS)
	# Coming from "Load": the map is freshly loaded; now put the saved state on top.
	if not SaveGame.pending_load.is_empty():
		_apply_save(SaveGame.pending_load)
		SaveGame.pending_load = {}
		ui.show_toast("Game loaded.")


## The map, its navigation, loot, boarded-up openings and what you can build.
func _setup_world() -> void:
	map = GameMap.new()
	map.name = "Map"
	map.map_scene = map_scene
	map.start_hour = start_hour
	map.seconds_per_game_hour = seconds_per_game_hour
	map.night_ambient = night_ambient
	add_child(map)
	map.build(rng)
	day_night = map.day_night
	fortifications = Fortifications.new()
	add_child(fortifications)
	fortifications.setup(map.nav_region, map.windows, map.doors) # planks on what's boarded at start, before the bake
	map.bake_navigation()
	structures = Structures.new()
	add_child(structures)
	structures.setup(map.nav_region, fortifications)


## The people, you among them, then the zombies.
func _setup_characters() -> void:
	people = People.new()
	people.name = "People"
	add_child(people)
	people.spawn_npcs(map, day_night) # after the navigation bake, so they can find their way around
	survivors = Survivors.new()
	add_child(survivors)
	survivors.setup(map.spawn_points)
	player = people.spawn_player(map.player_spawn)
	player.died.connect(_on_player_died)
	zombies = Zombies.new()
	zombies.name = "Zombies"
	add_child(zombies)
	zombies.setup(map, rng)
	zombies.spawn_at_markers()
	zombies.spawn_in_mines()


## Zones, base camps, more zombies over time and the hordes.
func _setup_camps_and_zombies() -> void:
	zones = Zones.new()
	add_child(zones)
	zones.setup(map.town, player)
	camps = Camps.new()
	add_child(camps)
	camps.setup(map.base_camp_marker(), Survivors.station_homes(map.spawn_points), survivors, null, structures,
			zones, day_night, player)
	structures.camps = camps
	# More zombies around the map, and new ones over time.
	zombie_population_node = ZombiePopulation.new()
	add_child(zombie_population_node)
	zombie_population_node.population = zombie_population
	zombie_population_node.respawn_seconds_day = zombie_respawn_seconds_day
	zombie_population_node.respawn_seconds_night = zombie_respawn_seconds_night
	zombie_population_node.setup(zombies, map.nav_region, player, day_night, camps)
	zombie_population_node.populate(extra_zombies, rng, map.player_spawn.origin)
	horde = Horde.new()
	add_child(horde)
	horde.setup(zombies, map.doors, zombie_population_node, map.nav_region, player, day_night)
	survivors.move_zombies_out(zombies.all)


## The HUD and the menus (after you: see ui/game_ui.gd), and what you find.
func _setup_ui() -> void:
	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.build(player, day_night, _save_game)
	discoveries = Discoveries.new()
	add_child(discoveries)
	discoveries.setup(player, MapSummary.discoverable(map.places))
	ui.setup_map(map, zones, camps, discoveries)
	ui.setup_camps(camps, structures)


## The quests, and the story's people and places.
func _setup_story() -> void:
	quests = QuestManager.new()
	add_child(quests)
	ui.setup_story(quests)
	quests.setup(map, player, ui.dialogue, ui.choice_menu, camps, day_night)
	safe_house_point = map.place_position("Safe House")
	for trigger in get_tree().get_nodes_in_group("safe_house_trigger"):
		# Walking into the safe house's yard (or the house) is what "reaching" it means.
		(trigger as Area3D).body_entered.connect(func(body: Node3D) -> void:
			if body.is_in_group("player") and not quests.happened("safe_house_reached"):
				# You stumbled in on them: everything inside comes to see what made that noise.
				get_tree().call_group("noise_listeners", "hear_noise", safe_house_point, 30.0)
				quests.event("safe_house_reached"))

	trader_arrival = TraderArrival.new()
	add_child(trader_arrival)
	trader_arrival.setup(player, camps, day_night, camps.station.center,
			map.spawn_transform("wagon"), map.spawn_transform("wagon_trader"))
	trader_arrival.seen.connect(quests.event.bind("trader_found"))

	woodworker_rescue = WoodworkerRescue.new()
	add_child(woodworker_rescue)
	woodworker_rescue.setup(player, ui.dialogue, map.spawn_transform("woodworker_captive"),
			map.spawn_transform("woodworker_home"))
	woodworker_rescue.freed.connect(quests.event.bind("woodworker_untied"))
	woodworker_rescue.seen.connect(quests.event.bind("woodworker_found"))
	salvage = Salvage.new()
	add_child(salvage)
	salvage.setup(map.loot_spots, map.salvage_others)
	camps.attach_woodworker(woodworker_rescue)
	survivors.attach(player, ui.dialogue, ui.choice_menu, ui.craft_menu, camps, woodworker_rescue)
	people.setup_talk(quests, ui, camps, survivors, woodworker_rescue)


func _process(_delta: float) -> void:
	_check_autosave()


## _input sees every event before anything else handles it, so it's the place to
## notice which device you're using and switch the on-screen button hints.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or \
			(event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		Controls.using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or \
			(event is InputEventMouseMotion and event.relative.length() > 4.0):
		Controls.using_gamepad = false


func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead and event.is_action_pressed("restart"):
		_load_or_restart()


## After death: back to the newest save (yours or the autosave) if there is one,
## otherwise start over.
func _load_or_restart() -> void:
	if not SaveGame.request_load(get_tree()):
		SceneFade.change_to(get_tree(), scene_file_path)


## You died: the death screen, then (if there's a save) back to it.
func _on_player_died() -> void:
	var has_save := SaveGame.exists() # checked once, not every frame
	ui.show_death(has_save)
	if has_save:
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_inside_tree() and player.is_dead:
				_load_or_restart())


# --- Saving and loading --------------------------------------------------------

## Autosave the first time you get within AUTOSAVE_DISTANCE of the tracked
## quest's waypoint, on steps that ask for it (the safe house, in the story).
## Not while something is hunting you: a save made mid-fight could lock you
## into a fight you can't win. It keeps checking, and saves as soon as you're
## clear (if you're still close).
func _check_autosave() -> void:
	if player.is_dead:
		return
	var target := quests.autosave_target()
	if target == Vector3.INF or player.global_position.distance_to(target) > AUTOSAVE_DISTANCE:
		return
	if _player_threatened():
		return
	quests.mark_autosaved()
	if _save_game(SaveGame.AUTOSAVE):
		ui.show_toast("Autosaved")


## Is any zombie or bandit currently after you?
func _player_threatened() -> bool:
	return zombies.hunting(player) or people.bandit_after(player)


## Saves the game to `path` (the logbook's new save or the one you picked, or
## the autosave): world/save_io.gd gathers it.
func _save_game(path: String) -> bool:
	var data := SaveIO.collect(self)
	data["clock"] = day_night.clock_text() # (what the save list shows)
	data["objective"] = quests.objective_text()
	return SaveGame.write(data, path)


## Put a save on top of the freshly loaded town (world/save_io.gd).
func _apply_save(data: Dictionary) -> void:
	SaveIO.apply(self, data)


## An item lying on the ground, outside the navigation (items don't change zombie paths).
func add_ground_item(id: String, amount: int, pos: Vector3, yaw: float) -> void:
	var item := GroundItem.new()
	item.position = pos
	item.rotation.y = yaw
	item.setup(id, amount)
	add_child(item)


func _save_ground_items() -> Array:
	var ground := []
	for item in get_tree().get_nodes_in_group("ground_items"):
		if not item.is_queued_for_deletion(): # (picked up this frame)
			ground.append({"id": item.item_id, "amount": item.amount,
					"position": SaveGame.vec_to_array(item.global_position), "yaw": item.rotation.y})
	return ground


## Throws away the fresh ones and puts down exactly what the save recorded.
func _load_ground_items(data: Array) -> void:
	for item in get_tree().get_nodes_in_group("ground_items"):
		item.remove_from_group("ground_items")
		item.queue_free()
	for entry: Dictionary in data:
		if GameData.has_item(str(entry.get("id", ""))):
			add_ground_item(entry["id"], int(entry.get("amount", 1)),
					SaveGame.array_to_vec(entry["position"]), float(entry.get("yaw", 0.0)))
