extends Node3D
## The game scene's root. Builds a gray-box Midwest town a couple of months into
## the outbreak, then adds loot, the player, the zombies, the HUD and the menus,
## and handles saving and loading. Everything is generated in code, so the scene
## file (main.tscn) stays tiny. The pieces live in their own scripts:
##   world/world_builder.gd    shared state and helpers while the town is built
##   world/areas/*.gd          Main Street, the police station, the safe house, the bandit camp
##   world/loot.gd             what's in the containers and on the street
##   ui/hud.gd                 everything on screen during play
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
const PauseMenu := preload("res://ui/pause_menu.gd")
const InventoryMenu := preload("res://ui/inventory_menu.gd")
const ShopMenu := preload("res://ui/shop_menu.gd")
const Building := preload("res://world/building.gd")
const DayNight := preload("res://world/day_night.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const PoliceChief := preload("res://characters/npcs/police_chief.gd")
const DialogueBox := preload("res://ui/dialogue_box.gd")
const MainQuest := preload("res://quests/main_quest.gd")
const SaveGame := preload("res://core/save_game.gd")
const SavePoint := preload("res://world/save_point.gd")
const SaveMenu := preload("res://ui/save_menu.gd")
const Bandit := preload("res://characters/npcs/bandit.gd")
const Door := preload("res://world/door.gd")
const Settings := preload("res://core/settings.gd")
const Zones := preload("res://world/zones.gd")
const MapMenu := preload("res://ui/map_menu.gd")
const BackpackMenu := preload("res://ui/backpack_menu.gd")
const Discoveries := preload("res://world/discoveries.gd")
const Hud := preload("res://ui/hud.gd")
const WorldBuilder := preload("res://world/world_builder.gd")
const Loot := preload("res://world/loot.gd")
const Town := preload("res://world/areas/town.gd")
const PoliceStation := preload("res://world/areas/police_station.gd")
const SafeHouse := preload("res://world/areas/safe_house.gd")
const BanditCamp := preload("res://world/areas/bandit_camp.gd")
const Housing := preload("res://world/areas/housing.gd")
const SkyShader := preload("res://world/sky_clouds.gdshader")
const Fortifications := preload("res://world/fortifications.gd")
const Fortification := preload("res://world/fortification.gd")
const Grocery := preload("res://world/areas/grocery.gd")
const GasStation := preload("res://world/areas/gas_station.gd")

@export_group("World")
## Same seed = same town layout and loot every run. Change it for a different town.
@export var town_seed := 1979
@export_range(0, 100) var outdoor_zombies := 14
## Chance of a zombie at each of the ~2 spots inside every shop.
@export_range(0.0, 1.0) var indoor_zombie_chance := 0.12
## Loose items lying in the streets.
@export_range(0, 60) var ground_items := 12
@export_range(0.0, 1.0) var container_health_pack_chance := 0.4
@export_range(0.0, 1.0) var container_ammo_chance := 0.35
@export_range(0.0, 1.0) var container_trade_goods_chance := 0.35
## Chance a shop's front door is standing open when you arrive.
@export_range(0.0, 1.0) var door_open_chance := 0.35

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

var player: Player
## Where you start: on the cross street, one block west of the police station
## compound (toward Main Street), facing east so the station is the first thing
## you see. Rotation -90 degrees turns the player's forward (-z) to face +x.
var player_spawn := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(24.0, 0.1, 0.0))
var nav_region: NavigationRegion3D # all town geometry lives under this node
var builder: WorldBuilder
var day_night: DayNight
# These are the builder's own lists (the same arrays), named here for saving.
var loot_spots: Array = []
var doors: Array[Door] = []
var hud: Hud
var zones: Zones
var map_menu: MapMenu
var backpack_menu: BackpackMenu
var discoveries: Discoveries
var dialogue: DialogueBox
var quest: MainQuest
var chief: PoliceChief
var trader: Shopkeeper
var safe_house_point := Vector3.ZERO # middle of the safe house yard (quest marker target)
var safe_house_zombie_points: Array[Vector3] = []
var bandits: Array[Bandit] = []
var zombies: Array[Zombie] = [] # every zombie spawned, dead or alive, in spawn order (for saving)
## Everything added after the original town rolls its own dice, so it never
## reshuffles what came before it (see world_builder.gd).
var housing_rng := RandomNumberGenerator.new()
var grocery_rng := RandomNumberGenerator.new()
var gas_station_rng := RandomNumberGenerator.new()
var fortify_rng := RandomNumberGenerator.new() # planks in containers
var fortifications: Fortifications
## Chance each container holds some planks.
const CONTAINER_PLANKS_CHANCE := 0.15
var house_zombie_points: Array[Vector3] = [] # inside the houses and the gas station
var save_menu: SaveMenu
var inventory_menu: InventoryMenu
var shop_menu: ShopMenu


func _ready() -> void:
	Controls.setup()
	Settings.load_settings() # before anything can play a sound: it creates the Effects bus
	_build_environment()
	_setup_navigation()
	# The build order below is the order of every random roll: keep it (see world_builder.gd).
	builder = WorldBuilder.new(self, nav_region, town_seed)
	loot_spots = builder.loot_spots
	doors = builder.doors
	Town.build(builder, door_open_chance)
	var station := PoliceStation.build(builder)
	trader = station["trader"]
	chief = station["chief"]
	trader.day_night = day_night # restocks each morning
	Loot.fill_containers(builder, player_spawn.origin, container_health_pack_chance,
			container_ammo_chance, container_trade_goods_chance)
	# After the loot: the safe house crates get fixed supplies, not random loot.
	var safe_house := SafeHouse.build(builder, func() -> void: quest.reached_safe_house())
	safe_house_point = safe_house["point"]
	safe_house_zombie_points = safe_house["zombie_points"]
	BanditCamp.build(builder)
	# Last of the build, with its own generator, so it doesn't reshuffle anything above.
	housing_rng.seed = town_seed + 2
	house_zombie_points = Housing.build(builder, housing_rng, door_open_chance,
			container_health_pack_chance, container_ammo_chance, container_trade_goods_chance)
	grocery_rng.seed = town_seed + 3
	Grocery.build(builder, grocery_rng)
	gas_station_rng.seed = town_seed + 4
	house_zombie_points.append_array(GasStation.build(builder, gas_station_rng, door_open_chance,
			container_health_pack_chance, container_ammo_chance, container_trade_goods_chance))
	# Bake the walkable area from the town's collision shapes. Runs once at startup
	# and blocks briefly; fine for one small town.
	nav_region.bake_navigation_mesh(false)
	fortifications = Fortifications.new()
	add_child(fortifications)
	fortifications.setup(nav_region, nav_region.get_children().filter(func(n: Node) -> bool: return n is Building))
	# Planks to find, rolled last with their own generator (see world_builder.gd).
	fortify_rng.seed = town_seed + 5
	for spot: LootSpot in loot_spots:
		if fortify_rng.randf() < CONTAINER_PLANKS_CHANCE:
			spot.inventory.add("planks", fortify_rng.randi_range(1, 2))
	Loot.scatter(builder, ground_items)
	hud = Hud.new()
	add_child(hud)
	_spawn_player()
	_spawn_zombies()
	bandits = BanditCamp.spawn(builder)
	for point in house_zombie_points:
		if housing_rng.randf() < indoor_zombie_chance:
			_add_zombie(point + Vector3(0, 0.1, 0), housing_rng)
	zones = Zones.new()
	zones.bandits = bandits
	add_child(zones)
	zones.status_changed.connect(_on_zone_status_changed)
	hud.setup(player, day_night)
	add_child(PauseMenu.new())
	# Added last on purpose: Godot sends input to later nodes first, so while a menu
	# is open it gets Esc/E before the pause menu and the player do.
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
	map_menu.setup(player, zones, discoveries, Town.map_roads() + Housing.map_roads(), _map_buildings(),
			[PoliceStation.map_fence()], _map_streets())
	backpack_menu = BackpackMenu.new()
	add_child(backpack_menu)
	backpack_menu.setup(player)
	player.object_interacted.connect(func(obj: Node) -> void:
		if obj is SavePoint:
			save_menu.open(player, _save_game)
		elif obj is Door:
			(obj as Door).toggle()
		elif obj is Fortification:
			player.give_item(fortifications.take_down(obj as Fortification)))
	# Getting hurt never closes a menu or a conversation: only Esc (each menu
	# handles its own) or dying does.
	for menu: Callable in [inventory_menu.close, shop_menu.close, dialogue.close, save_menu.close, map_menu.close,
			backpack_menu.close]:
		player.died.connect(menu)

	quest = MainQuest.new()
	add_child(quest)
	quest.objective_changed.connect(hud.set_objective)
	quest.story_beat.connect(hud.show_story)
	quest.setup(player, chief, safe_house_point, dialogue)

	# Coming from "Load": the town is freshly rebuilt; now put the saved state on top.
	if not SaveGame.pending_load.is_empty():
		_apply_save(SaveGame.pending_load)
		SaveGame.pending_load = {}
		hud.show_toast("Game loaded.")


func _map_buildings() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for node in nav_region.get_children():
		if node is Building:
			result.append((node as Building).footprint)
	return result


## Street names for the map screen, as [name, (x, z)]. Always shown.
func _map_streets() -> Array:
	return [
		["Main Street", Vector2(0.0, -82.0)],
		["Elm Street", Housing.ELM_STREET.get_center() + Vector2(0.0, 18.0)],
		["7th Street", Vector2(-100.0, 0.0)],
	]


## Places you find by going near them (world/discoveries.gd); the map names each
## one only after that. center and label_at are (x, z); radius is in meters.
func _discoverable_places() -> Array[Dictionary]:
	var compound_center := (PoliceStation.COMPOUND_MIN + PoliceStation.COMPOUND_MAX) / 2.0
	var grocery := Grocery.map_position(builder)
	var places: Array[Dictionary] = [
		{"name": "Police Station", "center": compound_center, "radius": 30.0,
				"label_at": Vector2(PoliceStation.STATION_X, PoliceStation.COMPOUND_MAX.y + 4.0)},
		{"name": "Safe House", "center": Vector2(safe_house_point.x, safe_house_point.z), "radius": 25.0,
				"label_at": Vector2(SafeHouse.SAFE_HOUSE_X, SafeHouse.SAFE_HOUSE_FRONT_Z + 16.0)},
		{"name": "Gas Station", "center": Vector2(GasStation.CENTER_X, GasStation.CANOPY_Z), "radius": 25.0,
				"label_at": GasStation.map_position()},
	]
	if grocery != Vector2.INF:
		places.append({"name": "Grocery Store", "center": grocery, "radius": 18.0, "label_at": grocery})
	return places


## Pressing interact on an NPC: open whatever that kind of NPC offers.
func _on_npc_interacted(npc: HumanNPC) -> void:
	if npc is Shopkeeper:
		shop_menu.open(player, npc as Shopkeeper)
	elif npc is PoliceChief:
		quest.talk_to_chief()


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


## After death: back to the last save if there is one, otherwise start over.
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

## Autosave the first time you get within AUTOSAVE_DISTANCE of the safe house
## while it's your objective (not the Chief: he's safe in the station anyway).
## Not while something is hunting you: a save made mid-fight could lock you
## into a fight you can't win. It keeps checking, and saves as soon as you're
## clear (if you're still close).
func _check_autosave() -> void:
	if player.is_dead or quest.stage != MainQuest.Stage.REACH_SAFE_HOUSE \
			or quest.stage in quest.autosaved_stages:
		return
	var target := quest.objective_position()
	if target == Vector3.INF or player.global_position.distance_to(target) > AUTOSAVE_DISTANCE:
		return
	if _player_threatened():
		return
	quest.autosaved_stages.append(quest.stage)
	if _save_game():
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


## The logbook's Save button. Collects everything that can change during play.
func _save_game() -> bool:
	var containers := []
	for spot: LootSpot in loot_spots:
		containers.append({"opened": spot.opened, "inventory": spot.inventory.to_dict()})
	var ground := []
	for item in get_tree().get_nodes_in_group("ground_items"):
		if not item.is_queued_for_deletion(): # (picked up this frame)
			ground.append({"id": item.item_id, "amount": item.amount,
					"position": SaveGame.vec_to_array(item.global_position), "yaw": item.rotation.y})
	var zombie_data := []
	for zombie in zombies:
		zombie_data.append({"position": SaveGame.vec_to_array(zombie.global_position),
				"yaw": zombie.rotation.y, "health": zombie.health, "dead": zombie.is_dead})
	var door_data := []
	for door in doors:
		door_data.append(door.save_state())
	var bandit_data := []
	for bandit in bandits:
		bandit_data.append({"position": SaveGame.vec_to_array(bandit.global_position),
				"yaw": bandit.rotation.y, "health": bandit.health, "dead": bandit.is_dead})
	return SaveGame.write({
		"clock": day_night.clock_text(),
		"objective": quest.objective_text(),
		"time": {"hour": day_night.hour, "day": day_night.day},
		"quest": quest.save_state(),
		"player": player.save_state(),
		"containers": containers,
		"ground_items": ground,
		"zombies": zombie_data,
		"bandits": bandit_data,
		"doors": door_data,
		"fortifications": fortifications.save_state(),
		"discovered": discoveries.save_state(),
		"shop_stock": trader.stock.to_dict(),
		"shop_restocked_day": trader.restocked_day,
	})


## Put a save on top of the freshly built town. Order matters a little: the
## world first, then the people in it, then you.
func _apply_save(data: Dictionary) -> void:
	var time: Dictionary = data.get("time", {})
	day_night.hour = float(time.get("hour", day_night.hour))
	day_night.day = int(time.get("day", day_night.day))
	quest.load_state(data.get("quest", {}))

	var containers: Array = data.get("containers", [])
	for i in mini(containers.size(), loot_spots.size()):
		var spot: LootSpot = loot_spots[i]
		spot.inventory.from_dict(containers[i].get("inventory", {}))
		if containers[i].get("opened", false):
			spot.open() # darkens it like when you searched it

	# Older saves have no doors: those keep their freshly built state.
	var door_data: Array = data.get("doors", [])
	for i in mini(door_data.size(), doors.size()):
		doors[i].load_state(door_data[i])
	fortifications.load_state(data.get("fortifications", {}))
	if data.has("discovered"):
		discoveries.load_state(data["discovered"])
	else: # older saves: you've met the Chief, and maybe been to the safe house
		discoveries.mark("Police Station")
		if quest.stage >= MainQuest.Stage.REPORT_BACK:
			discoveries.mark("Safe House")

	# Ground items, zombies: throw away the freshly spawned ones and recreate
	# exactly what the save recorded.
	for item in get_tree().get_nodes_in_group("ground_items"):
		item.remove_from_group("ground_items")
		item.queue_free()
	for entry: Dictionary in data.get("ground_items", []):
		if GameData.ITEMS.has(entry.get("id", "")):
			builder.add_ground_item(entry["id"], int(entry.get("amount", 1)),
					SaveGame.array_to_vec(entry["position"]), float(entry.get("yaw", 0.0)))

	# Zombies, like bandits: the town spawns the same ones in the same order every
	# time, so each saved entry goes back onto the zombie it came from. Nothing is
	# freed, so nobody is ever left aiming at a deleted node. Older saves listed
	# only the living (no "dead" flags): those fill the first zombies and the rest
	# are laid down dead.
	var zombie_data: Array = data.get("zombies", [])
	for i in zombies.size():
		var zombie := zombies[i]
		if i >= zombie_data.size():
			zombie.die(false)
			continue
		var entry: Dictionary = zombie_data[i]
		zombie.global_position = SaveGame.array_to_vec(entry["position"])
		zombie.rotation.y = float(entry.get("yaw", 0.0))
		if entry.get("dead", false):
			zombie.die(false)
		else:
			zombie.health = float(entry.get("health", zombie.max_health))

	var bandit_data: Array = data.get("bandits", [])
	for i in mini(bandit_data.size(), bandits.size()):
		var bandit := bandits[i]
		var entry: Dictionary = bandit_data[i]
		bandit.global_position = SaveGame.array_to_vec(entry["position"])
		bandit.rotation.y = float(entry.get("yaw", 0.0))
		if entry.get("dead", false):
			bandit.drop_loot_on_death = false # their drops are already in ground_items
			bandit.die()
		else:
			bandit.health = float(entry.get("health", bandit.max_health))

	trader.stock.from_dict(data.get("shop_stock", trader.stock.to_dict()))
	trader.restocked_day = int(data.get("shop_restocked_day", day_night.day))
	player.load_state(data.get("player", {}))


# --- Characters --------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerScene.instantiate() as Player
	player.transform = player_spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.damaged.connect(hud.flash_hurt)
	player.notify.connect(hud.show_toast)


func _spawn_zombies() -> void:
	var rng := builder.rng
	for i in outdoor_zombies:
		var pos: Vector3
		if rng.randf() < 0.65:
			pos = builder.street_spot(-75.0, 35.0) + Vector3(0, 0.08, 0)
		else:
			# On the cross street west of Main (it runs out to the safe house), not
			# where you start (x = 24) or in front of the police station.
			pos = Vector3(rng.randf_range(-140.0, 6.0), 0.1, rng.randf_range(-4.0, 4.0))
		_add_zombie(pos)
	# A few more already shut inside the shops.
	for point in builder.interior_points:
		if rng.randf() < indoor_zombie_chance:
			_add_zombie(point + Vector3(0, 0.1, 0))
	# The safe house horde.
	for point in safe_house_zombie_points:
		_add_zombie(point)


## rng: whose dice pick its facing; the town's unless said otherwise.
func _add_zombie(pos: Vector3, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = builder.rng
	var zombie := ZombieScene.instantiate() as Zombie
	zombie.position = pos
	zombie.rotation.y = rng.randf_range(0.0, TAU)
	add_child(zombie)
	zombies.append(zombie)


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
