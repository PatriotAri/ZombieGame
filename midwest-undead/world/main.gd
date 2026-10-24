extends Node3D
## The game scene's root. Loads the map (world/map/map.tscn: open it to change
## the map in the editor; see HOW_TO_MAP.md), then adds the loot, the player,
## the zombies, the NPCs, the HUD and the menus, and handles saving and loading.
## The pieces live in their own scripts:
##   world/map/           the map: the terrain (Terrain3D) and everything placed on it
##   world/kit/           the building kit buildings are made of (see HOW_TO_BUILD.md)
##   world/markers/       markers on the map: where people and zombies start, places
##   world/nav_tiles.gd   where zombies can walk (the navigation mesh, in tiles)
##   world/ground.gd      how high the ground is anywhere
##   world/loot.gd        rolls the containers' loot tables (items/loot/)
##   world/save_io.gd     what a save holds, gathered and put back
##   core/game_events.gd  what just happened (a kill, an item picked up...), for quests
##   world/quest_world.gd the quest markers and people quests point at, by id
##   world/map_summary.gd what the map screen shows of the map
##   quests/              the main story and side quests (see QUESTS.md)
##   ui/hud.gd            everything on screen during play
##   ui/perf_overlay.gd   the performance readout (F3)
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
const Zombie := preload("res://characters/zombie/zombie.gd")
const PlayerScene := preload("res://characters/player/player.tscn")
const ZombieScene := preload("res://characters/zombie/zombie.tscn")
const Controls := preload("res://core/controls.gd")
const GameData := preload("res://core/game_data.gd")
const LootSpot := preload("res://items/loot_spot.gd")
const GroundItem := preload("res://items/ground_item.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const InventoryMenu := preload("res://ui/inventory_menu.gd")
const ShopMenu := preload("res://ui/shop_menu.gd")
const DayNight := preload("res://world/day_night.gd")
const Guard := preload("res://characters/npcs/guard.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")
const DialogueBox := preload("res://ui/dialogue_box.gd")
const QuestManager := preload("res://quests/quest_manager.gd")
const JournalMenu := preload("res://ui/journal_menu.gd")
const SaveGame := preload("res://core/save_game.gd")
const SaveIO := preload("res://world/save_io.gd")
const MapSummary := preload("res://world/map_summary.gd")
const SceneFade := preload("res://ui/scene_fade.gd")
const SaveMenu := preload("res://ui/save_menu.gd")
const Bandit := preload("res://characters/npcs/bandit.gd")
const BanditScene := preload("res://characters/npcs/bandit.tscn")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const Settings := preload("res://core/settings.gd")
const Zones := preload("res://world/zones.gd")
const MapMenu := preload("res://ui/map_menu.gd")
const BackpackMenu := preload("res://ui/backpack_menu.gd")
const Discoveries := preload("res://world/discoveries.gd")
const ZombiePopulation := preload("res://world/zombie_population.gd")
const StaticMerge := preload("res://world/static_merge.gd")
const Instancer := preload("res://world/instancer.gd")
const Horde := preload("res://world/horde.gd")
const Survivors := preload("res://world/survivors.gd")
const Camps := preload("res://world/camps.gd")
const Salvage := preload("res://world/salvage.gd")
const CraftMenu := preload("res://ui/craft_menu.gd")
const ChoiceMenu := preload("res://ui/choice_menu.gd")
const Hud := preload("res://ui/hud.gd")
const PerfOverlay := preload("res://ui/perf_overlay.gd")
const Loot := preload("res://world/loot.gd")
const SkyShader := preload("res://world/sky_clouds.gdshader")
const Fortifications := preload("res://world/fortifications.gd")
const Structures := preload("res://world/structures.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")
const ZombieSpawn := preload("res://world/markers/zombie_spawn.gd")
const Place := preload("res://world/markers/place.gd")
const Ground := preload("res://world/ground.gd")
const NavTiles := preload("res://world/nav_tiles.gd")
const Cover := preload("res://world/cover.gd")
const Plants := preload("res://world/map/plants.gd")
const GameEvents := preload("res://core/game_events.gd")
const QuestWorld := preload("res://world/quest_world.gd")
const SaveIds := preload("res://core/save_ids.gd")

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

## Street zombies (a ZombieSpawn with a spread) don't start this close to a car or other container.
const ZOMBIE_CONTAINER_CLEARANCE := 2.5

var player: Player
## Where you start: the map's "player" SpawnPoint.
var player_spawn := Transform3D.IDENTITY
var nav_region: NavTiles # all map geometry lives under this node (the navigation bake reads it)
var town: Node3D # the map scene, under nav_region
var terrain: Node # the map's Terrain3D node, or null
var _trunks: Array[RID] = [] # painted trees' solid trunks (world/map/plants.gd)
var day_night: DayNight
# What's on the map, found when it's loaded. Everything that's saved carries a
# "town_id" (its path in the map scene), so saves find it again.
var loot_spots: Array[LootSpot] = []
var doors: Array[Door] = [] # moved out of the map, under main (see _load_town)
var mines: Array[KitMine] = [] # their generators' fuel and cages are saved
var windows: Array[WindowPane] = []
var spawn_points: Array[SpawnPoint] = []
var zombie_spawns: Array[ZombieSpawn] = []
var places: Array[Place] = []
var person_markers: Array[KitPersonMarker] = [] # who stands where at the start (person files)
var _town_keys := {} # every save key given out so far (core/save_ids.gd)
var salvage_others: Array[Node3D] = [] # things with a "salvage_label" that aren't containers (beds)
var hud: Hud
var zones: Zones
var map_menu: MapMenu
var backpack_menu: BackpackMenu
var discoveries: Discoveries
var zombie_population_node: ZombiePopulation
var horde: Horde # every couple of weeks, a horde crosses the map
var survivors: Survivors # the ones holed up in boarded-up houses
var camps: Camps # the base camps: who lives where, jobs, guards, supply crates
var salvage: Salvage # stripping cars and furniture for materials
var craft_menu: CraftMenu
var choice_menu: ChoiceMenu
var dialogue: DialogueBox
var quests: QuestManager # the main story and side quests (quests/)
var game_events: GameEvents # what just happened, for anything listening
var quest_world: QuestWorld # quest markers and people, by id
var journal_menu: JournalMenu
var bandits: Array[Bandit] = []
var zombies: Array[Zombie] = [] # every zombie up (and bodies not yet cleared away)
## A new game's random rolls: what's in the containers, which zombies turn up.
var rng := RandomNumberGenerator.new()
var fortifications: Fortifications
var structures: Structures # what you build: scaffolding, guard posts, fences, gates
var save_menu: SaveMenu
var inventory_menu: InventoryMenu
var shop_menu: ShopMenu


func _ready() -> void:
	add_to_group("main") # (what you interact with finds the menus it opens through it)
	Controls.setup()
	Settings.load_settings() # before anything can play a sound: it creates the Effects bus
	rng.randomize()
	game_events = GameEvents.new() # first: everything after this can report what happens
	game_events.name = "GameEvents"
	add_child(game_events)
	_build_environment()
	_setup_world()
	_setup_characters()
	_setup_camps_and_zombies()
	_setup_menus()
	_setup_story()
	# Coming from "Load": the map is freshly loaded; now put the saved state on top.
	if not SaveGame.pending_load.is_empty():
		_apply_save(SaveGame.pending_load)
		SaveGame.pending_load = {}
		hud.show_toast("Game loaded.")


## The map, its navigation, loot, boarded-up openings and what you can build.
func _setup_world() -> void:
	nav_region = NavTiles.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	_load_town()
	_setup_navigation()
	if terrain:
		# Painted trees get solid trunks (not in the navigation: zombies just
		# bump around them), and plants that hide you are known to world/cover.gd.
		var trees := Node3D.new()
		trees.name = "TreeTrunks" # what a bullet or a look reports hitting
		add_child(trees)
		_trunks = Plants.build_trunks(terrain, get_world_3d().space, trees)
		Cover.mesh_ids = Plants.hiding_ids()
	Loot.fill(loot_spots, rng)
	fortifications = Fortifications.new()
	add_child(fortifications)
	fortifications.setup(nav_region, windows, doors) # planks on what's boarded at start, before the bake
	# Bake the walkable area from the map's terrain and collision shapes: every
	# tile at once, on all the processor's cores (world/nav_tiles.gd).
	nav_region.bake_all()
	structures = Structures.new()
	add_child(structures)
	structures.setup(nav_region, fortifications)


## The people (and the HUD, which the player reports to), then the zombies.
func _setup_characters() -> void:
	_spawn_npcs()
	survivors = Survivors.new()
	add_child(survivors)
	survivors.setup(spawn_points)
	hud = Hud.new()
	add_child(hud)
	add_child(PerfOverlay.new())
	_spawn_player()
	_spawn_zombies()
	_spawn_mine_zombies()


## Zones, base camps, more zombies over time and the hordes.
func _setup_camps_and_zombies() -> void:
	zones = Zones.new()
	add_child(zones)
	zones.setup(town, player)
	zones.zone_entered.connect(func(zone_name: String) -> void: hud.show_toast("Entering " + zone_name))
	camps = Camps.new()
	add_child(camps)
	camps.setup(_base_camp_marker(), Survivors.station_homes(spawn_points), survivors, structures,
			zones, day_night, player)
	structures.camps = camps
	# More zombies around the map, and new ones over time.
	zombie_population_node = ZombiePopulation.new()
	add_child(zombie_population_node)
	zombie_population_node.population = zombie_population
	zombie_population_node.respawn_seconds_day = zombie_respawn_seconds_day
	zombie_population_node.respawn_seconds_night = zombie_respawn_seconds_night
	zombie_population_node.setup(self, nav_region, player, day_night, camps)
	zombie_population_node.populate(extra_zombies, rng, player_spawn.origin)
	horde = Horde.new()
	add_child(horde)
	horde.setup(self, zombie_population_node, nav_region, player, day_night)
	survivors.move_zombies_out(zombies)
	hud.setup(player, day_night)


## The pause menu and the screens you open in play, and what opens them.
func _setup_menus() -> void:
	add_child(PauseMenu.new())
	# Added last on purpose: Godot sends input to later nodes first, so while a menu
	# is open it gets Esc/E before the pause menu and the player do.
	craft_menu = CraftMenu.new()
	add_child(craft_menu)
	choice_menu = ChoiceMenu.new()
	add_child(choice_menu)
	inventory_menu = InventoryMenu.new()
	add_child(inventory_menu)
	shop_menu = ShopMenu.new()
	add_child(shop_menu)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	player.container_opened.connect(func(spot: Node) -> void: inventory_menu.open(player, spot as LootSpot))
	player.npc_interacted.connect(_on_npc_interacted)
	save_menu = SaveMenu.new()
	add_child(save_menu)
	discoveries = Discoveries.new()
	add_child(discoveries)
	discoveries.setup(player, MapSummary.discoverable(places))
	discoveries.discovered.connect(func(names: Array[String]) -> void:
		hud.show_toast("Discovered: " + ", ".join(names)))
	map_menu = MapMenu.new()
	add_child(map_menu)
	map_menu.setup(player, zones, camps, discoveries, MapSummary.rects(get_tree(), "map_road"), MapSummary.buildings(town),
			MapSummary.rects(get_tree(), "map_fence"), MapSummary.streets(places))
	backpack_menu = BackpackMenu.new()
	add_child(backpack_menu)
	backpack_menu.setup(player)
	player.object_interacted.connect(_on_object_interacted)
	# Getting hurt never closes a menu or a conversation: only Esc (each menu
	# handles its own) or dying does.
	for menu: Callable in [inventory_menu.close, shop_menu.close, dialogue.close, save_menu.close, map_menu.close,
			backpack_menu.close, craft_menu.close, choice_menu.close]:
		player.died.connect(menu)


## The quests, and the story's people and places.
func _setup_story() -> void:
	quest_world = QuestWorld.new()
	add_child(quest_world)
	quest_world.setup(town, player)
	quests = QuestManager.new()
	add_child(quests)
	quests.objective_changed.connect(hud.set_objective)
	quests.story_beat.connect(hud.show_story)
	quests.setup(self, player, dialogue, choice_menu, quest_world, day_night)
	journal_menu = JournalMenu.new()
	add_child(journal_menu)
	journal_menu.setup(player, quests)
	player.died.connect(journal_menu.close)
	salvage = Salvage.new()
	add_child(salvage)
	salvage.setup(loot_spots, salvage_others)
	survivors.attach(player, dialogue, choice_menu, craft_menu, camps)


## Pressing interact on something that isn't a person, an item or a container:
## it does its own thing (its interact(player): the logbook opens the save
## menu, a door swings, planks come down...).
func _on_object_interacted(obj: Node) -> void:
	if obj.has_method("interact"):
		obj.call("interact", player)


# --- The map ---------------------------------------------------------------------

## Puts the map scene under nav_region and finds what the game needs in it.
## Doors move out first, under main, so the navigation bake ignores them (zombie
## paths run through doorways; see door.gd); garage doors stay in it.
## Everything that's saved gets its "town_id" before that, while it still has
## its place in the map.
func _load_town() -> void:
	town = map_scene.instantiate() as Node3D
	for node in town.find_children("*", "", true, false):
		if node.is_class("Terrain3D"):
			terrain = node
			break
	Ground.terrain = terrain
	Cover.terrain = terrain
	# Buildings and kit pieces make their walls, glass and doors from their
	# settings; have them do it now, so the doors and windows are there to find.
	for node in town.find_children("*", "", true, false):
		if node.has_method("ensure_built"):
			node.call("ensure_built")
	var door_holder := Node3D.new()
	door_holder.name = "Doors"
	add_child(door_holder)
	for node in town.find_children("*", "", true, false):
		if node is LootSpot or node is Door or node is WindowPane or node is SpawnPoint \
				or node.has_meta("salvage_label"):
			node.set_meta("town_id", _town_path(node))
		if node is LootSpot:
			loot_spots.append(node)
		elif node is WindowPane:
			windows.append(node)
		elif node is SpawnPoint:
			spawn_points.append(node)
		elif node is ZombieSpawn:
			zombie_spawns.append(node)
		elif node is Place:
			places.append(node)
		elif node is KitPersonMarker:
			person_markers.append(node)
		elif node is Door:
			doors.append(node)
		if node.has_meta("salvage_label") and not node is LootSpot:
			salvage_others.append(node)
		if node is KitMine:
			node.set_meta("town_id", _town_path(node))
			mines.append(node)
	var moving: Array[Node3D] = [] # moving parts that aren't doors: a mine's cage and its gates
	for node in town.find_children("*", "", true, false):
		if node.is_in_group(&"not_in_navigation"):
			moving.append(node)
	var to_move: Array = [] # (untyped: doors and the rest)
	to_move.append_array(doors.filter(func(d: Door) -> bool: return not d.in_navigation)) # (a garage door stays in the bake: door.gd)
	to_move.append_array(moving)
	for door: Node3D in to_move:
		# Where it is in the map (the map's own nodes aren't in the tree yet).
		var xform := door.transform
		var parent := door.get_parent()
		while parent != town:
			if parent is Node3D:
				xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		door.get_parent().remove_child(door)
		door.owner = null # no longer part of the map scene
		door.transform = town.transform * xform
		door_holder.add_child(door, true)
	nav_region.add_child(town)
	Ground.deepest = INF # the game reaches down to the lowest mine floor
	for mine in town.find_children("*", "KitMine", true, false):
		Ground.deepest = minf(Ground.deepest, (mine as KitMine).lowest_floor())
	StaticMerge.merge(town) # buildings and kit pieces as a few big meshes (fewer draw calls)
	Instancer.batch(self) # the same doors, windows and furniture drawn together (GPU instancing)
	var start := _spawn_point("player")
	player_spawn = Transform3D(Basis(Vector3.UP, start.global_rotation.y), start.global_position) if start \
			else Transform3D(Basis.IDENTITY, Ground.snap(Vector3.ZERO, 0.1))


## What a save calls a node in the map scene (core/save_ids.gd): its save id
## ("#3fa9c2d1/FrontDoor" for a building's door), or its path from the map's
## root ("Buildings/Shop3/FrontDoor") if it has none. Two the same (a copy
## pasted outside the editor's save): the later one goes by its path, with a warning.
func _town_path(node: Node) -> String:
	var key := SaveIds.key(node, town)
	if _town_keys.has(key):
		push_warning("Two things on the map share the save id in \"%s\": save the map in the editor to fix it." % key)
		var parts := PackedStringArray()
		while node != town:
			parts.insert(0, str(node.name))
			node = node.get_parent()
		key = "/".join(parts)
	_town_keys[key] = true
	return key


## The first SpawnPoint with this role, or null (with a warning).
func _spawn_point(role: String) -> SpawnPoint:
	for spot in spawn_points:
		if spot.role == role:
			return spot
	push_warning("The map scene has no SpawnPoint with the role \"%s\"." % role)
	return null


## The police station's camp marker (a KitBaseCamp in the map scene), or null.
func _base_camp_marker() -> KitBaseCamp:
	for node in town.find_children("*", "Marker3D", true, false):
		if node is KitBaseCamp:
			return node
	return null


## Pressing interact on an NPC. Anything a quest has for them (an offer, a step
## to talk to them, a reminder) comes first; next to their own business
## (trading, building...) it's a choice. With nothing about quests, they do
## their own thing.
func _on_npc_interacted(npc: HumanNPC) -> void:
	npc.talking = true # (until your menus close)
	if npc.captive:
		_untie(npc)
		return
	var options := quests.talk_options(npc)
	var own := _own_business(npc)
	if options.is_empty():
		if own.is_empty():
			# What they say once their quests are done, or else their own lines.
			if not quests.afterword(npc) and npc.person and npc.person.talk:
				quests.play(npc.person.talk, npc.npc_id)
		else:
			own[1].call()
		return
	if own.is_empty() and options.size() == 1:
		options[0][1].call()
		return
	if not own.is_empty():
		options.append(own)
	options.append(["Never mind", Callable()])
	choice_menu.open(player, npc.display_name, "", options)


## Untying someone held captive: they say their person file's Untie Talk, and
## they're free (quests hear person_freed).
func _untie(npc: HumanNPC) -> void:
	var lines := npc.person.untie_talk if npc.person else null
	var free := func() -> void:
		if npc.captive:
			npc.set_captive(false)
			GameEvents.send(&"person_freed", {"npc_id": npc.npc_id})
	if lines:
		quests.play(lines, npc.npc_id, free)
	else:
		free.call()


## What an NPC does when it's not about quests (each kind says: its
## own_business()): [label, callable], or [] if nothing.
func _own_business(npc: HumanNPC) -> Array:
	return npc.own_business(self)


func _process(_delta: float) -> void:
	_check_autosave()


func _exit_tree() -> void:
	Plants.free_trunks(_trunks)
	_trunks.clear()


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


# --- World -------------------------------------------------------------------

## Sky (with drifting clouds, see sky_clouds.gdshader), fog, sun and moon. Their
## colors and angles are set every frame by day_night.
func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A flat ambient color is easier to control across day and night than sky light.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	# Hill-country haze: about 70% clear at 100 m, 17% at 500 m, so ridges across
	# the map fade into the distance (and the hills past its edge, world/map/).
	env.fog_density = 0.0035
	# Fog would otherwise cover the sky completely, hiding the clouds. At this
	# strength it still blends the horizon into the haze.
	env.fog_sky_affect = 0.35

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	# Its shadows (off, medium, high) are the Shadows setting: Settings.apply_graphics.
	sun.add_to_group("sun")
	sun.light_cull_mask &= ~GameData.RENDER_UNDERGROUND # not in the mines (kit_mine.gd)
	add_child(sun)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # don't draw a second sun disk
	moon.light_cull_mask &= ~GameData.RENDER_UNDERGROUND
	add_child(moon)

	day_night = DayNight.new()
	day_night.start_hour = start_hour
	day_night.seconds_per_game_hour = seconds_per_game_hour
	day_night.night_ambient = night_ambient
	add_child(day_night)
	day_night.setup(env, sky_mat, sun, moon)
	Settings.apply_graphics() # shadows, view distance, resolution


## Where zombies can walk covers the whole map: the terrain's regions across,
## and from below its lowest ground to well above its highest (roofs and towers
## included). Without a terrain, a 512 m square around the middle.
func _setup_navigation() -> void:
	var rect := Ground.map_rect()
	if rect.size == Vector2.ZERO:
		rect = Rect2(-256, -256, 512, 512)
	var heights := Ground.height_range()
	nav_region.setup(AABB(Vector3(rect.position.x, heights.x - 5.0, rect.position.y),
			Vector3(rect.size.x, heights.y - heights.x + 45.0, rect.size.y)), terrain)


# --- Saving and loading --------------------------------------------------------

## Autosave when a quest asks for it (an Autosave action), but not while
## something is hunting you: a save made mid-fight could lock you into a fight
## you can't win. It keeps checking, and saves as soon as you're clear.
func _check_autosave() -> void:
	if player.is_dead or not quests.wants_autosave() or _player_threatened():
		return
	quests.autosaved()
	if save_game(SaveGame.autosave_path()):
		hud.show_toast("Autosaved")


## Is any zombie or bandit currently after you?
func _player_threatened() -> bool:
	for zombie: Zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.state == Zombie.State.HUNT and zombie.target == player:
			return true
	for bandit in bandits:
		if not bandit.is_dead and bandit.state == Bandit.State.COMBAT and bandit.target == player:
			return true
	return false


## Saves the game to `path` (the logbook's new save or the one you picked, or
## the autosave): world/save_io.gd gathers it.
func save_game(path: String) -> bool:
	return SaveGame.write(SaveIO.collect(self), path)


## Put a save on top of the freshly loaded town (world/save_io.gd).
func _apply_save(data: Dictionary) -> void:
	game_events.muted = true # putting the save back isn't anything happening
	SaveIO.apply(self, data)
	game_events.muted = false
	quest_world.resettle()


## An item lying on the ground, outside nav_region (items don't change zombie paths).
func add_ground_item(id: String, amount: int, pos: Vector3, yaw: float) -> void:
	var item := GroundItem.new()
	item.position = pos
	item.rotation.y = yaw
	item.setup(id, amount)
	add_child(item)


# --- Characters --------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerScene.instantiate() as Player
	player.transform = player_spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.damaged.connect(hud.flash_hurt)
	player.notify.connect(hud.show_toast)


## The map's NPCs: everyone at a person marker (from their person file: the
## Quartermaster, the Chief...), and those at SpawnPoints: guards on their
## towers, the bandits at their camp, and the people who didn't make it (corpses). After the navigation bake, so they can find
## their way around.
func _spawn_npcs() -> void:
	for spot in person_markers:
		if spot.person == null or not spot.start_here:
			continue
		var someone := spot.person.make()
		someone.transform = Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)
		if "day_night" in someone:
			someone.set("day_night", day_night) # a trader restocks each morning
		add_child(someone)
		if spot.captive:
			someone.set_captive(true)
	for spot in spawn_points:
		var xform := Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)
		match spot.role:
			"guard":
				var guard := GuardScene.instantiate() as Guard
				# Its own tower (what the marker sits under) doesn't block its aim.
				var tower := spot.get_parent()
				for part: CollisionObject3D in tower.find_children("*", "CollisionObject3D", true, false):
					guard.exclude.append(part.get_rid())
				if tower is CollisionObject3D:
					guard.exclude.append((tower as CollisionObject3D).get_rid())
				guard.guard_from = spot.watch_from
				guard.guard_to = spot.watch_to
				guard.transform = xform
				add_child(guard)
			"bandit":
				var bandit := BanditScene.instantiate() as Bandit
				bandit.home = (spot.get_parent() as Node3D).global_position # their camp
				bandit.transform = xform
				bandit.set_meta("spawn_id", spot.get_meta("town_id"))
				add_child(bandit)
				bandits.append(bandit)
			"corpse":
				var body := HumanNPCScene.instantiate() as HumanNPC
				body.zombies_target = false
				body.outfit_color = spot.outfit_color
				body.transform = xform
				add_child(body)
				body.die()


## Zombies at the map's ZombieSpawn markers: each one turns up with its marker's
## chance. A marker on the ground spreads them over the ground (hills and all).
func _spawn_zombies() -> void:
	for spawn in zombie_spawns:
		var mine := _mine_of(spawn)
		for i in spawn.count:
			if rng.randf() >= spawn.chance:
				continue
			if mine: # spread over the mine's open cells round it, miners among them
				var near := KitMine.cell_at(mine.to_local(spawn.global_position), roundi(mine.to_local(spawn.global_position).y / KitMine.LEVEL))
				var spot := mine.zombie_spot(rng, near, maxi(1, ceili(maxf(spawn.spread.x, spawn.spread.y) / KitMine.CELL)))
				if spot != Vector3.INF:
					_add_zombie(spot, null, ZombieKind.roll_in_mine(rng).id)
				continue
			var pos := spawn.global_position
			if spawn.spread != Vector2.ZERO:
				for attempt in 20: # not inside a car
					pos = spawn.global_transform * Vector3(rng.randf_range(-spawn.spread.x, spawn.spread.x), 0.0,
							rng.randf_range(-spawn.spread.y, spawn.spread.y))
					if Ground.is_ground_level(spawn.global_position):
						pos = Ground.snap(pos, 0.1)
					if not _near_container(pos, ZOMBIE_CONTAINER_CLEARANCE):
						break
			_add_zombie(pos)


## The mine a marker's in (under), or null.
func _mine_of(node: Node) -> KitMine:
	while node != null and node != town:
		if node is KitMine:
			return node
		node = node.get_parent()
	return null


## Each mine's own zombies (its Zombie Density), at the start of a new game.
func _spawn_mine_zombies() -> void:
	for mine in mines:
		for i in mine.zombie_count():
			var spot := mine.zombie_spot(rng)
			if spot != Vector3.INF:
				_add_zombie(spot, null, ZombieKind.roll_in_mine(rng).id)


func _near_container(pos: Vector3, min_dist: float) -> bool:
	for spot in loot_spots:
		if Vector2(pos.x - spot.global_position.x, pos.z - spot.global_position.z).length() < min_dist:
			return true
	return false


## dice: whose dice pick its facing and kind; the game's (rng) unless said
## otherwise. kind: a ZombieKind's id (characters/zombie/kinds/); "" rolls one
## by their spawn chances.
func _add_zombie(pos: Vector3, dice: RandomNumberGenerator = null, kind := "") -> Zombie:
	if dice == null:
		dice = rng
	if kind == "":
		kind = ZombieKind.roll(dice).id
	var zombie := ZombieScene.instantiate() as Zombie
	zombie.kind = kind
	zombie.position = pos
	zombie.rotation.y = dice.randf_range(0.0, TAU)
	add_child(zombie)
	zombies.append(zombie)
	return zombie


func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var has_save := SaveGame.exists() # checked once, not every frame
	hud.show_death(has_save)
	if has_save:
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_inside_tree() and player.is_dead:
				_load_or_restart())
