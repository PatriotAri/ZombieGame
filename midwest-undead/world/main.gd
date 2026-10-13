extends Node3D
## The game scene's root. Loads the town (world/town/town.tscn: open it, or one
## of its districts in world/town/districts/, to change the town in the editor),
## then adds the loot, the player, the zombies, the NPCs, the HUD and the menus,
## and handles saving and loading. The pieces live in their own scripts:
##   world/town/          the town itself: buildings, containers, doors, items, props
##   world/kit/           the building kit the town is made of (see HOW_TO_BUILD.md)
##   world/markers/       markers in the town: where people and zombies start, places
##   world/loot.gd        the containers' loot tables
##   quests/              the main story and side quests (see QUESTS.md)
##   ui/hud.gd            everything on screen during play
##
## What's fixed and what's random: the town, its containers and the items lying
## around are exactly what the town scene has. What's in the containers (beyond
## their fixed items), which zombies turn up at the ZombieSpawn markers, the
## extra zombies and the ones arriving over time are random every new game.
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
const Building := preload("res://world/building.gd")
const DayNight := preload("res://world/day_night.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const ShopkeeperScene := preload("res://characters/npcs/shopkeeper.tscn")
const PoliceChief := preload("res://characters/npcs/police_chief.gd")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const Guard := preload("res://characters/npcs/guard.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")
const DialogueBox := preload("res://ui/dialogue_box.gd")
const QuestManager := preload("res://quests/quest_manager.gd")
const JournalMenu := preload("res://ui/journal_menu.gd")
const SaveGame := preload("res://core/save_game.gd")
const SavePoint := preload("res://world/save_point.gd")
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
const TraderArrival := preload("res://world/trader_arrival.gd")
const WoodworkerRescue := preload("res://world/woodworker_rescue.gd")
const Survivors := preload("res://world/survivors.gd")
const BaseCamp := preload("res://world/base_camp.gd")
const Salvage := preload("res://world/salvage.gd")
const Recipes := preload("res://core/recipes.gd")
const CraftMenu := preload("res://ui/craft_menu.gd")
const ChoiceMenu := preload("res://ui/choice_menu.gd")
const Survivor := preload("res://characters/npcs/survivor.gd")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const Hud := preload("res://ui/hud.gd")
const Loot := preload("res://world/loot.gd")
const SkyShader := preload("res://world/sky_clouds.gdshader")
const Fortifications := preload("res://world/fortifications.gd")
const Fortification := preload("res://world/fortification.gd")
const Structures := preload("res://world/structures.gd")
const StructurePiece := preload("res://world/structure_piece.gd")
const GateLeaf := preload("res://world/gate_leaf.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")
const ZombieSpawn := preload("res://world/markers/zombie_spawn.gd")
const Place := preload("res://world/markers/place.gd")

@export_group("World")
## The town to play in. Edit world/town/town.tscn (or its districts) to change it.
@export var town_scene: PackedScene = preload("res://world/town/town.tscn")
## More zombies scattered around town at the start (never inside a zone), on top
## of the ones at the town's ZombieSpawn markers.
@export_range(0, 300) var extra_zombies := 60
## How many zombies are up at once. When there are fewer, new ones turn up on the
## outskirts of town now and then (see world/zombie_population.gd).
@export_range(0, 400) var zombie_population := 100
## Every zombie (at the start and arriving later) has these chances of being a
## crawler or a runner instead of an ordinary walker (characters/zombie/zombie.gd).
@export_range(0.0, 1.0) var crawler_chance := 0.08
@export_range(0.0, 1.0) var runner_chance := 0.03
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
## Street zombies (a ZombieSpawn with a spread) don't start this close to a car or other container.
const ZOMBIE_CONTAINER_CLEARANCE := 2.5

var player: Player
## Where you start: the town's "player" SpawnPoint.
var player_spawn := Transform3D.IDENTITY
var nav_region: NavigationRegion3D # all town geometry lives under this node
var town: Node3D # the town scene, under nav_region
var day_night: DayNight
# What's in the town, found when it's loaded. Everything that's saved carries a
# "town_id" (its path in the town scene), so saves find it again.
var loot_spots: Array[LootSpot] = []
var doors: Array[Door] = [] # moved out of the town, under main (see _load_town)
var windows: Array[WindowPane] = []
var spawn_points: Array[SpawnPoint] = []
var zombie_spawns: Array[ZombieSpawn] = []
var places: Array[Place] = []
var salvage_others: Array[Node3D] = [] # things with a "salvage_label" that aren't containers (beds)
var hud: Hud
var zones: Zones
var map_menu: MapMenu
var backpack_menu: BackpackMenu
var discoveries: Discoveries
var zombie_population_node: ZombiePopulation
var trader_arrival: TraderArrival # the wagon trader who comes once Zone 1 is cleared
var woodworker_rescue: WoodworkerRescue # the woodworker held at the bandit camp
var survivors: Survivors # the ones holed up in boarded-up houses
var base_camp: BaseCamp # how many the base holds, jobs, the supply crate
var salvage: Salvage # stripping cars and furniture for materials
var craft_menu: CraftMenu
var choice_menu: ChoiceMenu
var dialogue: DialogueBox
var quests: QuestManager # the main story and side quests (quests/)
var journal_menu: JournalMenu
var chief: PoliceChief
var trader: Shopkeeper
var safe_house_point := Vector3.ZERO # the "Safe House" place (quest marker target)
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
	Controls.setup()
	Settings.load_settings() # before anything can play a sound: it creates the Effects bus
	rng.randomize()
	_build_environment()
	_setup_navigation()
	_load_town()
	Loot.fill(loot_spots, rng)
	fortifications = Fortifications.new()
	add_child(fortifications)
	fortifications.setup(nav_region, windows, doors) # planks on what's boarded at start, before the bake
	# Bake the walkable area from the town's collision shapes. Runs once at startup
	# and blocks briefly; fine for one small town.
	nav_region.bake_navigation_mesh(false)
	structures = Structures.new()
	add_child(structures)
	structures.setup(nav_region, fortifications)
	_spawn_npcs()
	survivors = Survivors.new()
	add_child(survivors)
	survivors.setup(spawn_points)
	hud = Hud.new()
	add_child(hud)
	_spawn_player()
	_spawn_zombies()
	zones = Zones.new()
	zones.bandits = bandits
	add_child(zones)
	zones.status_changed.connect(_on_zone_status_changed)
	structures.zones = zones
	# More zombies around town, and new ones over time.
	zombie_population_node = ZombiePopulation.new()
	add_child(zombie_population_node)
	zombie_population_node.population = zombie_population
	zombie_population_node.respawn_seconds_day = zombie_respawn_seconds_day
	zombie_population_node.respawn_seconds_night = zombie_respawn_seconds_night
	zombie_population_node.setup(self, nav_region, player, day_night, zones)
	zombie_population_node.populate(extra_zombies, rng, player_spawn.origin)
	survivors.move_zombies_out(zombies)
	hud.setup(player, day_night)
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
	discoveries.setup(player, _discoverable_places())
	zones.discoveries = discoveries
	discoveries.discovered.connect(func(names: Array[String]) -> void:
		hud.show_toast("Discovered: " + ", ".join(names)))
	map_menu = MapMenu.new()
	add_child(map_menu)
	map_menu.setup(player, zones, discoveries, _map_rects("map_road"), _map_buildings(),
			_map_rects("map_fence"), _map_streets())
	backpack_menu = BackpackMenu.new()
	add_child(backpack_menu)
	backpack_menu.setup(player)
	player.object_interacted.connect(func(obj: Node) -> void:
		if obj is SavePoint:
			save_menu.open(player, _save_game)
		elif obj is Door:
			(obj as Door).toggle()
		elif obj is Fortification:
			var back := fortifications.take_down(obj as Fortification)
			if back == "":
				hud.show_toast("The used planks splinter apart. Nothing left to save.")
			else:
				player.give_item(back)
		elif obj is GateLeaf:
			structures.toggle_gate((obj as GateLeaf).piece)
		elif obj is StructurePiece:
			var item := structures.take_down(obj as StructurePiece)
			if item == "":
				hud.show_toast("Take down what's on top of it first.")
			else:
				player.give_item(item))
	# Getting hurt never closes a menu or a conversation: only Esc (each menu
	# handles its own) or dying does.
	for menu: Callable in [inventory_menu.close, shop_menu.close, dialogue.close, save_menu.close, map_menu.close,
			backpack_menu.close, craft_menu.close, choice_menu.close]:
		player.died.connect(menu)

	quests = QuestManager.new()
	add_child(quests)
	quests.objective_changed.connect(hud.set_objective)
	quests.story_beat.connect(hud.show_story)
	quests.setup(self, player, dialogue, choice_menu, zones, day_night)
	journal_menu = JournalMenu.new()
	add_child(journal_menu)
	journal_menu.setup(player, quests)
	player.died.connect(journal_menu.close)
	safe_house_point = _place_position("Safe House")
	for trigger in get_tree().get_nodes_in_group("safe_house_trigger"):
		# Walking into the safe house's yard (or the house) is what "reaching" it means.
		(trigger as Area3D).body_entered.connect(func(body: Node3D) -> void:
			if body.is_in_group("player") and not quests.happened("safe_house_reached"):
				# You stumbled in on them: everything inside comes to see what made that noise.
				get_tree().call_group("noise_listeners", "hear_noise", safe_house_point, 30.0)
				quests.event("safe_house_reached"))

	trader_arrival = TraderArrival.new()
	add_child(trader_arrival)
	trader_arrival.setup(player, zones, day_night, _place_position("Police Station"),
			_spawn_transform("wagon"), _spawn_transform("wagon_trader"))
	trader_arrival.zone_cleared.connect(quests.event.bind("zone_cleared:" + TraderArrival.ZONE))
	trader_arrival.seen.connect(quests.event.bind("trader_found"))

	woodworker_rescue = WoodworkerRescue.new()
	add_child(woodworker_rescue)
	woodworker_rescue.setup(player, dialogue, _spawn_transform("woodworker_captive"),
			_spawn_transform("woodworker_home"))
	woodworker_rescue.freed.connect(quests.event.bind("woodworker_untied"))
	woodworker_rescue.seen.connect(quests.event.bind("woodworker_found"))
	salvage = Salvage.new()
	add_child(salvage)
	salvage.setup(loot_spots, salvage_others)
	base_camp = BaseCamp.new()
	add_child(base_camp)
	base_camp.setup(get_tree().get_first_node_in_group("base_supply_crate") as Node3D, survivors,
			woodworker_rescue, structures, day_night, player)
	survivors.attach(player, dialogue, choice_menu, craft_menu, base_camp, woodworker_rescue)

	# Coming from "Load": the town is freshly loaded; now put the saved state on top.
	if not SaveGame.pending_load.is_empty():
		_apply_save(SaveGame.pending_load)
		SaveGame.pending_load = {}
		hud.show_toast("Game loaded.")


# --- The town --------------------------------------------------------------------

## Puts the town scene under nav_region and finds what the game needs in it.
## Doors move out first, under main, so the navigation bake ignores them (zombie
## paths run through doorways; see door.gd). Everything that's saved gets its
## "town_id" before that, while it still has its place in the town.
func _load_town() -> void:
	town = town_scene.instantiate() as Node3D
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
		elif node is Door:
			doors.append(node)
		if node.has_meta("salvage_label") and not node is LootSpot:
			salvage_others.append(node)
	for door in doors:
		# Where it is in the town (the town's own nodes aren't in the tree yet).
		var xform := door.transform
		var parent := door.get_parent()
		while parent != town:
			if parent is Node3D:
				xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		door.get_parent().remove_child(door)
		door.owner = null # no longer part of the town scene
		door.transform = town.transform * xform
		door_holder.add_child(door, true)
	nav_region.add_child(town)
	var start := _spawn_point("player")
	player_spawn = Transform3D(Basis(Vector3.UP, start.global_rotation.y), start.global_position) if start \
			else Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0))


## A node's path in the town scene, from the town's root ("MainStreet/Shop3/FrontDoor").
func _town_path(node: Node) -> String:
	var parts := PackedStringArray()
	while node != town:
		parts.insert(0, str(node.name))
		node = node.get_parent()
	return "/".join(parts)


## The first SpawnPoint with this role, or null (with a warning).
func _spawn_point(role: String) -> SpawnPoint:
	for spot in spawn_points:
		if spot.role == role:
			return spot
	push_warning("The town scene has no SpawnPoint with the role \"%s\"." % role)
	return null


## Where a SpawnPoint is, turned only about the vertical (an NPC stands upright).
func _spawn_transform(role: String) -> Transform3D:
	var spot := _spawn_point(role)
	if spot == null:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)


func _place_position(place_name: String) -> Vector3:
	for place in places:
		if place.place_name == place_name:
			return place.global_position
	push_warning("The town scene has no Place called \"%s\"." % place_name)
	return Vector3.ZERO


func _map_buildings() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for node in town.find_children("*", "Node3D", true, false):
		if node is Building and (node as Building).size_depth > 0.0:
			result.append((node as Building).ground_corners())
	return result


## One rectangle on the ground (x, z) for each node in the group, covering its
## box collision shapes: the roads ("map_road") and the compound fence ("map_fence").
func _map_rects(group: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(group):
		var rect := Rect2()
		var first := true
		for col: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
			if not col.shape is BoxShape3D:
				continue
			var half := (col.shape as BoxShape3D).size / 2.0
			for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z),
					Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
				var p := col.global_transform * corner
				if first:
					rect = Rect2(p.x, p.z, 0, 0)
					first = false
				else:
					rect = rect.expand(Vector2(p.x, p.z))
		if not first:
			result.append(rect)
	return result


## Street names for the map screen, as [name, (x, z)]. Always shown.
func _map_streets() -> Array:
	var result := []
	for place in places:
		if place.kind == "street":
			result.append([place.place_name, Vector2(place.global_position.x, place.global_position.z) + place.label_offset])
	return result


## Places you find by going near them (world/discoveries.gd); the map names each
## one only after that. center and label_at are (x, z); radius is in meters.
func _discoverable_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place in places:
		if place.kind == "discoverable":
			var center := Vector2(place.global_position.x, place.global_position.z)
			result.append({"name": place.place_name, "center": center, "radius": place.radius,
					"label_at": center + place.label_offset})
	return result


## Pressing interact on an NPC. Anything a quest has for them (an offer, a step
## to talk to them, a reminder) comes first; next to their own business
## (trading, building...) it's a choice. With nothing about quests, they do
## their own thing.
func _on_npc_interacted(npc: HumanNPC) -> void:
	if npc is Woodworker and (npc as Woodworker).state == Woodworker.State.CAPTIVE:
		woodworker_rescue.untie() # (the rescue itself is the woodworker's own scene)
		return
	var options := quests.talk_options(npc)
	var own := _own_business(npc)
	if options.is_empty():
		if own.is_empty():
			quests.afterword(npc) # what they say once their quests are done
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


## What an NPC does when it's not about quests: [label, callable], or [] if nothing.
func _own_business(npc: HumanNPC) -> Array:
	if npc is Woodworker and (npc as Woodworker).state == Woodworker.State.HOME:
		return ["Build something", func() -> void: craft_menu.open(player, npc.display_name, Recipes.WOODWORKER)]
	if npc is Survivor:
		return ["Talk", func() -> void: survivors.talk(npc as Survivor)]
	if npc is Shopkeeper:
		return ["Trade", func() -> void: shop_menu.open(player, npc as Shopkeeper)]
	return []


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
		get_tree().reload_current_scene()


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
	env.fog_density = 0.02
	# Fog would otherwise cover the sky completely, hiding the clouds. At this
	# strength it still blends the horizon into the haze.
	env.fog_sky_affect = 0.35

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # don't draw a second sun disk
	add_child(moon)

	day_night = DayNight.new()
	day_night.start_hour = start_hour
	day_night.seconds_per_game_hour = seconds_per_game_hour
	day_night.night_ambient = night_ambient
	add_child(day_night)
	day_night.setup(env, sky_mat, sun, moon)


## A navigation mesh is the "where can zombies walk" map. Godot generates it by
## scanning the geometry under nav_region and subtracting anything too tall,
## too steep, or too close to a wall for an agent of the given size.
func _setup_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	# Use collision shapes, not visuals, so decorations like windows are ignored.
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Agent size: multiples of the default 0.25 m cell size avoid rounding warnings.
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	# Only bake where there's town (Main Street, the station's neighborhood, out to
	# the safe house), not the whole field (much faster). Build somewhere new
	# outside this box and zombies won't be able to walk there.
	nav_mesh.filter_baking_aabb = AABB(Vector3(-180, -1, -90), Vector3(305, 30, 180))
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)


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
## the autosave). Collects everything that can change during play. Things in the
## town go by their town_id.
func _save_game(path: String) -> bool:
	var containers := {}
	for spot in loot_spots:
		containers[spot.get_meta("town_id")] = {"opened": spot.opened, "inventory": spot.inventory.to_dict()}
	var ground := []
	for item in get_tree().get_nodes_in_group("ground_items"):
		if not item.is_queued_for_deletion(): # (picked up this frame)
			ground.append({"id": item.item_id, "amount": item.amount,
					"position": SaveGame.vec_to_array(item.global_position), "yaw": item.rotation.y})
	var zombie_data := [] # the ones still up
	for zombie in zombies:
		if is_instance_valid(zombie) and not zombie.is_dead:
			zombie_data.append({"position": SaveGame.vec_to_array(zombie.global_position),
					"yaw": zombie.rotation.y, "health": zombie.health, "kind": zombie.kind})
	var door_data := {}
	for door in doors:
		door_data[door.get_meta("town_id")] = door.save_state()
	var bandit_data := {} # by the SpawnPoint each started at
	for bandit in bandits:
		bandit_data[bandit.get_meta("spawn_id")] = {"position": SaveGame.vec_to_array(bandit.global_position),
				"yaw": bandit.rotation.y, "health": bandit.health, "dead": bandit.is_dead}
	return SaveGame.write({
		"clock": day_night.clock_text(),
		"objective": quests.objective_text(),
		"time": {"hour": day_night.hour, "day": day_night.day},
		"quest": quests.save_state(),
		"player": player.save_state(),
		"containers": containers,
		"ground_items": ground,
		"zombies": zombie_data,
		"bandits": bandit_data,
		"doors": door_data,
		"fortifications": fortifications.save_state(),
		"structures": structures.save_state(),
		"discovered": discoveries.save_state(),
		"shop_stock": trader.stock.to_dict(),
		"shop_restocked_day": trader.restocked_day,
		"wagon_trader": trader_arrival.save_state(),
		"woodworker": woodworker_rescue.save_state(),
		"survivors": survivors.save_state(),
		"base": base_camp.save_state(),
		"salvaged": salvage.save_state(),
	}, path)


## Put a save on top of the freshly loaded town. Order matters a little: the
## world first, then the people in it, then you.
func _apply_save(data: Dictionary) -> void:
	var time: Dictionary = data.get("time", {})
	day_night.hour = float(time.get("hour", day_night.hour))
	day_night.day = int(time.get("day", day_night.day))
	quests.begin_load() # no story moments while the save goes back on
	quests.load_state(data.get("quest", {}))

	var containers: Dictionary = data.get("containers", {})
	for spot in loot_spots:
		var saved: Dictionary = containers.get(spot.get_meta("town_id"), {})
		if saved.is_empty():
			continue # new to the town since the save: keeps its fresh contents
		spot.inventory.from_dict(saved.get("inventory", {}))
		if saved.get("opened", false):
			spot.open() # darkens it like when you searched it

	var door_data: Dictionary = data.get("doors", {})
	for door in doors:
		if door_data.has(door.get_meta("town_id")):
			door.load_state(door_data[door.get_meta("town_id")])
	fortifications.load_state(data.get("fortifications", {}))
	structures.load_state(data.get("structures", []))
	discoveries.load_state(data.get("discovered", []))

	# Ground items and zombies: throw away the fresh ones and recreate exactly
	# what the save recorded. (Nothing is aiming at a zombie yet: the game
	# hasn't run a frame.)
	for item in get_tree().get_nodes_in_group("ground_items"):
		item.remove_from_group("ground_items")
		item.queue_free()
	for entry: Dictionary in data.get("ground_items", []):
		if GameData.ITEMS.has(entry.get("id", "")):
			add_ground_item(entry["id"], int(entry.get("amount", 1)),
					SaveGame.array_to_vec(entry["position"]), float(entry.get("yaw", 0.0)))
	for zombie in zombies:
		zombie.get_parent().remove_child(zombie) # out of the "zombies" group right away
		zombie.queue_free()
	zombies.clear()
	for entry: Dictionary in data.get("zombies", []):
		var zombie := _add_zombie(SaveGame.array_to_vec(entry["position"]), null, str(entry.get("kind", "walker")))
		zombie.rotation.y = float(entry.get("yaw", 0.0))
		zombie.health = float(entry.get("health", zombie.max_health))

	var bandit_data: Dictionary = data.get("bandits", {})
	for bandit in bandits:
		var entry: Dictionary = bandit_data.get(bandit.get_meta("spawn_id"), {})
		if entry.is_empty():
			continue
		bandit.global_position = SaveGame.array_to_vec(entry["position"])
		bandit.rotation.y = float(entry.get("yaw", 0.0))
		if entry.get("dead", false):
			bandit.drop_loot_on_death = false # their drops are already in ground_items
			bandit.die()
		else:
			bandit.health = float(entry.get("health", bandit.max_health))

	trader.stock.from_dict(data.get("shop_stock", trader.stock.to_dict()))
	trader.restocked_day = int(data.get("shop_restocked_day", day_night.day))
	trader_arrival.load_state(data.get("wagon_trader", {}))
	woodworker_rescue.load_state(data.get("woodworker", {}))
	survivors.load_state(data.get("survivors", []))
	base_camp.load_state(data.get("base", {}))
	salvage.load_state(data.get("salvaged", []))
	# What the world says has happened (for saves from before quests kept their own record).
	if trader_arrival.cleared:
		quests.event("zone_cleared:" + TraderArrival.ZONE)
	if trader_arrival.was_seen:
		quests.event("trader_found")
	if woodworker_rescue.state() != Woodworker.State.CAPTIVE:
		quests.event("woodworker_untied")
	if woodworker_rescue.was_seen:
		quests.event("woodworker_found")
	quests.end_load()
	player.load_state(data.get("player", {}))


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


## The town's NPCs, at their SpawnPoints: the Quartermaster and the Chief in the
## station, the guards on their towers, the bandits at their camp, and the
## people who didn't make it at the safe house. After the navigation bake, so
## they can find their way around.
func _spawn_npcs() -> void:
	for spot in spawn_points:
		var xform := Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)
		match spot.role:
			"trader":
				trader = ShopkeeperScene.instantiate() as Shopkeeper
				trader.transform = xform
				trader.day_night = day_night # restocks each morning
				add_child(trader)
			"chief":
				chief = PoliceChiefScene.instantiate() as PoliceChief
				chief.transform = xform
				add_child(chief)
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


## Zombies at the town's ZombieSpawn markers: each one turns up with its marker's chance.
func _spawn_zombies() -> void:
	for spawn in zombie_spawns:
		for i in spawn.count:
			if rng.randf() >= spawn.chance:
				continue
			var pos := spawn.global_position
			if spawn.spread != Vector2.ZERO:
				for attempt in 20: # not inside a car
					pos = spawn.global_transform * Vector3(rng.randf_range(-spawn.spread.x, spawn.spread.x), 0.0,
							rng.randf_range(-spawn.spread.y, spawn.spread.y))
					if not _near_container(pos, ZOMBIE_CONTAINER_CLEARANCE):
						break
			_add_zombie(pos)


func _near_container(pos: Vector3, min_dist: float) -> bool:
	for spot in loot_spots:
		if Vector2(pos.x - spot.global_position.x, pos.z - spot.global_position.z).length() < min_dist:
			return true
	return false


## dice: whose dice pick its facing and kind; the game's (rng) unless said
## otherwise. kind: "walker", "runner" or "crawler"; "" rolls it (crawler_chance,
## runner_chance).
func _add_zombie(pos: Vector3, dice: RandomNumberGenerator = null, kind := "") -> Zombie:
	if dice == null:
		dice = rng
	if kind == "":
		var roll := dice.randf()
		kind = "crawler" if roll < crawler_chance else "runner" if roll < crawler_chance + runner_chance else "walker"
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


## A zone's last zombie (or bandit) just went down, or zombies wandered back in.
func _on_zone_status_changed(zone_name: String, status: Zones.Status) -> void:
	match status:
		Zones.Status.SAFE:
			hud.show_toast("%s is clear." % zones.full_name(zone_name))
		Zones.Status.HOSTILE:
			hud.show_toast("No more zombies in %s, but bandits are still around." % zones.full_name(zone_name))
		Zones.Status.DANGER:
			# Wherever you are: a zone you'd made safe isn't anymore.
			hud.show_toast("Zombies have gotten into %s." % zones.full_name(zone_name))
