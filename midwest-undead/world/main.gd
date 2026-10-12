extends Node3D
## Builds a gray-box Midwest town a couple of months into the outbreak: Main Street,
## enterable shops, a fortified police station with guards and a trader, then adds
## loot, the player, the zombies, and the HUD.
## Everything is generated in code, so the scene file (main.tscn) stays tiny.
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
const GroundItem := preload("res://items/ground_item.gd")
const Building := preload("res://world/building.gd")
const DayNight := preload("res://world/day_night.gd")
const Guard := preload("res://characters/npcs/guard.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const PoliceChief := preload("res://characters/npcs/police_chief.gd")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")
const DialogueBox := preload("res://ui/dialogue_box.gd")
const MainQuest := preload("res://quests/main_quest.gd")
const SaveGame := preload("res://core/save_game.gd")
const SavePoint := preload("res://world/save_point.gd")
const SaveMenu := preload("res://ui/save_menu.gd")
const Bandit := preload("res://characters/npcs/bandit.gd")
const BanditScene := preload("res://characters/npcs/bandit.tscn")
const ShopkeeperScene := preload("res://characters/npcs/shopkeeper.tscn")
const Door := preload("res://world/door.gd")
const Settings := preload("res://core/settings.gd")

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
@export_range(0.0, 23.99) var start_hour := 17.0
## Real seconds per in-game hour. 40 = a 16-minute day.
@export_range(1.0, 600.0) var seconds_per_game_hour := 40.0
## How bright the darkest night is. Raise it if nights are too dark on your screen.
@export var night_ambient := Color(0.05, 0.06, 0.1)

const ASPHALT := Color(0.16, 0.16, 0.17)
const SIDEWALK := Color(0.5, 0.49, 0.46)
const GRASS := Color(0.32, 0.34, 0.2)
const CARDBOARD := Color(0.55, 0.42, 0.25)
const DUMPSTER := Color(0.15, 0.3, 0.2)
const PLYWOOD := Color(0.55, 0.45, 0.3)
const TIMBER := Color(0.35, 0.27, 0.18)
const CONCRETE := Color(0.55, 0.57, 0.6)
const BUILDING_COLORS := [
	Color(0.48, 0.22, 0.17), # red brick
	Color(0.58, 0.42, 0.3),  # tan brick
	Color(0.4, 0.38, 0.36),  # gray stone
	Color(0.62, 0.58, 0.5),  # painted siding
]
const CAR_COLORS := [
	Color(0.55, 0.1, 0.1),
	Color(0.15, 0.2, 0.35),
	Color(0.7, 0.7, 0.68),
	Color(0.2, 0.3, 0.2),
	Color(0.1, 0.1, 0.1),
]

# The police station sits on the north side of the cross street, east of Main Street.
const STATION_X := 52.0 # center of its street face
const STATION_FRONT_Z := 9.0
const COMPOUND_MIN := Vector2(36.0, 6.0) # fence corners (x, z)
const COMPOUND_MAX := Vector2(68.0, 30.0)
const GATE_HALF_WIDTH := 5.0
const GATE_COLOR := Color(0.3, 0.32, 0.34) # steel

# The Westside safe house: the far west end of the cross street, mirroring the
# station on the east end, so reaching it means crossing the whole town.
const SAFE_HOUSE_X := -62.0
const SAFE_HOUSE_FRONT_Z := 9.0

# The bandit camp: in the open field south of the cross street, behind the west
# side of Main Street; walking the cross street to the safe house takes you within
# sight of it. Placement is set by distance (checked in testing): bandits never
# stray more than their leash (15 m) from camp, see at most 25 m in daylight, and
# their shots carry 25 m. The camp is ~51 m from the nearest safe house zombie and
# ~94 m from the station, so neither is within reach. Moving the camp (or raising
# leash/sight)? Keep leash + sight comfortably under those distances.
const CAMP_CENTER := Vector3(-28.0, 0.0, -35.0)
const BANDIT_COUNT := 5

## Autosave once you're this close to the safe house while it's your objective.
const AUTOSAVE_DISTANCE := 20.0

const HELP_KEYBOARD := "WASD move  ·  Shift sprint  ·  Ctrl crouch  ·  Space jump  ·  Click use held item  ·  Wheel / 1-9 pick item  ·  R reload  ·  E search/pick up/trade/open  ·  Q quick heal  ·  F flashlight  ·  Esc pause"
const HELP_GAMEPAD := "L stick move  ·  R stick look  ·  L3 sprint  ·  B crouch  ·  A jump  ·  RT use held item  ·  Y / D-pad pick item  ·  RB reload  ·  X search/pick up/trade/open  ·  LB quick heal  ·  D-pad up flashlight  ·  Start pause"

var player: Player
## Where you start: on the cross street, one block west of the police station
## compound (toward Main Street), facing east so the station is the first thing
## you see. Rotation -90 degrees turns the player's forward (-z) to face +x.
var player_spawn := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(24.0, 0.1, 0.0))
var nav_region: NavigationRegion3D # all town geometry lives under this node
var loot_spots: Array = []
var interior_points: Array[Vector3] = [] # inside shops, where zombies can lurk
var car_spots: Array[Vector3] = [] # so nothing else gets spawned inside a car
var door_spots: Array[Vector3] = [] # shop doorways on Main Street, kept clear of streetlights
var day_night: DayNight
var rng := RandomNumberGenerator.new()
## Separate from rng so adding doors didn't reshuffle the rest of the town.
var door_rng := RandomNumberGenerator.new()
var doors: Array[Door] = [] # every door and gate leaf, in build order (for saving)
var _gate_nav_blocker: StaticBody3D # stands in for the shut gate during the navigation bake

# HUD
var status_label: Label
var clock_label: Label
var help_label: Label
var hotbar_box: HBoxContainer
var _hotbar_shown := "" # what the hotbar currently displays, so it's only rebuilt on change
var prompt_label: Label
var toast_label: Label
var message_label: Label
var objective_label: Label
var story_label: Label
var story_tween: Tween
var dialogue: DialogueBox
var quest: MainQuest
var chief: PoliceChief
var safe_house_point := Vector3.ZERO # middle of the safe house yard (quest marker target)
var safe_house_zombie_points: Array[Vector3] = []
var safe_house_crates: Array = []
var trader: Shopkeeper
var bandits: Array[Bandit] = []
var zombies: Array[Zombie] = [] # every zombie spawned, dead or alive, in spawn order (for saving)
var bandit_spawns: Array[Vector3] = []
var save_menu: SaveMenu
var _has_save_on_death := false
var hurt_overlay: ColorRect
var inventory_menu: InventoryMenu
var shop_menu: ShopMenu
var toast_tween: Tween
var hurt_tween: Tween


func _ready() -> void:
	Controls.setup()
	Settings.load_settings() # before anything can play a sound: it creates the Effects bus
	rng.seed = town_seed
	door_rng.seed = town_seed + 1
	_build_environment()
	_setup_navigation()
	_build_town()
	_build_police_station()
	_assign_loot()
	_build_safe_house() # after _assign_loot: its crates get fixed supplies, not random loot
	_build_bandit_camp()
	# Bake the walkable area from the town's collision shapes. Runs once at startup
	# and blocks briefly; fine for one small town.
	nav_region.bake_navigation_mesh(false)
	_gate_nav_blocker.queue_free() # the real gate (and its nav links) takes over now
	_scatter_ground_items()
	_build_hud()
	_spawn_player()
	_spawn_zombies()
	_spawn_bandits()
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
	player.object_interacted.connect(func(obj: Node) -> void:
		if obj is SavePoint:
			save_menu.open(player, _save_game)
		elif obj is Door:
			(obj as Door).toggle())
	# Getting bitten snaps you out of any menu or conversation.
	player.damaged.connect(inventory_menu.close)
	player.damaged.connect(shop_menu.close)
	player.damaged.connect(dialogue.interrupt)
	player.damaged.connect(save_menu.close)

	quest = MainQuest.new()
	add_child(quest)
	quest.objective_changed.connect(func(text: String) -> void:
		objective_label.text = "Objective:  " + text if text != "" else "")
	quest.story_beat.connect(_show_story)
	quest.setup(player, chief, safe_house_point, dialogue)

	# Coming from "Load": the town is freshly rebuilt; now put the saved state on top.
	if not SaveGame.pending_load.is_empty():
		_apply_save(SaveGame.pending_load)
		SaveGame.pending_load = {}
		_show_toast("Game loaded.")


## Pressing interact on an NPC: open whatever that kind of NPC offers.
func _on_npc_interacted(npc: HumanNPC) -> void:
	if npc is Shopkeeper:
		shop_menu.open(player, npc as Shopkeeper)
	elif npc is PoliceChief:
		quest.talk_to_chief()


func _process(_delta: float) -> void:
	var crouch := "   (crouching)" if player.is_crouching else ""
	status_label.text = "Health %d    Stamina %d%s\n%s\n%s    Health packs: %d    $%d" % [
		ceili(player.health), floori(player.stamina), crouch, player.condition_text(),
		player.held_label(), player.inventory.count("health_pack"), player.money,
	]
	prompt_label.text = player.prompt_text
	clock_label.text = day_night.clock_text()
	_check_autosave()
	help_label.text = HELP_GAMEPAD if Controls.using_gamepad else HELP_KEYBOARD
	_update_hotbar()
	if player.is_dead:
		var cause := "You starved." if player.starved else "You were bitten."
		if _has_save_on_death:
			message_label.text = "%s\nLoading your last save...   (%s to load now)" % [cause, Controls.hint("restart")]
		else:
			message_label.text = "%s You never saved.\nPress %s to start over." % [cause, Controls.hint("restart")]


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

## Sky, fog, sun and moon. Their colors and angles are set every frame by day_night.
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
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
	# Only bake the town itself, not the whole 400 m field (much faster).
	nav_mesh.filter_baking_aabb = AABB(Vector3(-90, -1, -90), Vector3(180, 30, 180))
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)


func _build_town() -> void:
	_add_box(Vector3(400, 1, 400), Vector3(0, -0.5, 0), GRASS)
	# Main Street runs north-south; a cross street runs east-west.
	_add_box(Vector3(10, 0.02, 170), Vector3(0, 0.01, 0), ASPHALT)
	_add_box(Vector3(170, 0.02, 10), Vector3(0, 0.01, 0), ASPHALT)
	for side: int in [-1, 1]:
		for dir: int in [-1, 1]:
			_add_box(Vector3(3, 0.1, 75), Vector3(side * 6.5, 0.05, dir * 42.5), SIDEWALK)
			_build_block(side, dir)
	_build_streetlights()
	_build_cars()
	_build_water_tower(Vector3(-45, 0, -65))


## One row of storefronts on one side of Main Street.
func _build_block(side: int, dir: int) -> void:
	var depth := 12.0
	var z := 6.0
	while z < 76.0:
		if rng.randf() < 0.2:
			# An alley between buildings, usually with a dumpster in it.
			z += 3.0
			if rng.randf() < 0.7:
				_add_loot(Vector3(2.0, 1.3, 1.2), Vector3(side * 9.8, 0.65, dir * (z - 1.5)),
						DUMPSTER, "Dumpster")
		var width := rng.randf_range(8.0, 13.0)
		var height := rng.randf_range(5.0, 9.5)
		var color: Color = BUILDING_COLORS[rng.randi_range(0, BUILDING_COLORS.size() - 1)]
		var center_z := dir * (z + width / 2.0)
		var building := Building.new()
		building.position = Vector3(side * 8.0, 0.0, center_z) # street face on the sidewalk's edge
		building.rotation.y = 0.0 if side == 1 else PI # local +x always points away from the street
		nav_region.add_child(building)
		building.build(depth, width - 0.2, height, color, rng)
		loot_spots.append_array(building.loot_spots)
		interior_points.append_array(building.interior_points)
		_add_door(building.make_door(), door_rng.randf() < door_open_chance)
		door_spots.append(building.transform * Vector3(0.0, 0.0, building.door_z))
		# Sometimes a pile of boxes someone dragged out and abandoned, kept clear of the door.
		if rng.randf() < 0.3:
			var door_world_z := center_z + building.door_z * (1.0 if side == 1 else -1.0)
			var box_z := center_z + (width / 2.0 - 1.0) * (1.0 if door_world_z < center_z else -1.0)
			_add_loot(Vector3(0.8, 0.7, 0.8), Vector3(side * 7.0, 0.45, box_z), CARDBOARD, "Cardboard boxes")
		z += width


func _build_streetlights() -> void:
	# The power has been out for weeks, so these are just poles now.
	var z := -78.0
	while z <= 78.0:
		if absf(z) > 7.0:
			for side: int in [-1, 1]:
				var pos := Vector3(side * 7.6, 2.5, z)
				if not _near_door(pos, 2.5):
					_add_box(Vector3(0.15, 5.0, 0.15), pos, Color(0.2, 0.2, 0.2))
		z += 16.0


## A pole this close to a doorway pinches the navmesh shut in front of it (walls
## and poles both get an agent_radius margin), so zombies couldn't path inside.
func _near_door(pos: Vector3, min_dist: float) -> bool:
	for door in door_spots:
		if Vector2(pos.x - door.x, pos.z - door.z).length() < min_dist:
			return true
	return false


func _build_cars() -> void:
	for i in 9:
		var pos := Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-75.0, 40.0))
		for attempt in 10: # re-roll so cars don't end up inside each other
			if not _near_car(pos, 5.0):
				break
			pos = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-75.0, 40.0))
		car_spots.append(pos)
		var yaw := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var color: Color = CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)]
		_add_loot(Vector3(1.9, 0.8, 4.4), pos + Vector3(0, 0.55, 0), color, "Car", yaw)
		_add_box(Vector3(1.7, 0.6, 2.2), pos + Vector3(0, 1.25, 0), color.darkened(0.3), yaw)


func _build_water_tower(base: Vector3) -> void:
	var leg_color := Color(0.35, 0.36, 0.38)
	for x: float in [-2.5, 2.5]:
		for z: float in [-2.5, 2.5]:
			_add_box(Vector3(0.3, 14.0, 0.3), base + Vector3(x, 7.0, z), leg_color)
	var tank := CylinderMesh.new()
	tank.top_radius = 4.0
	tank.bottom_radius = 4.0
	tank.height = 5.0
	_add_mesh(tank, base + Vector3(0, 16.5, 0), Color(0.6, 0.62, 0.64))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.2
	roof.bottom_radius = 4.2
	roof.height = 2.0
	_add_mesh(roof, base + Vector3(0, 20.0, 0), leg_color)


# --- Police station ----------------------------------------------------------

## A fenced compound on the cross street: the station (with a trader inside),
## a plywood fence with a wide gate, and two guard towers covering the street.
func _build_police_station() -> void:
	var station := Building.new()
	station.position = Vector3(STATION_X, 0.0, STATION_FRONT_Z)
	station.rotation.y = -PI / 2.0 # local +x (into the building) points north, away from the street
	nav_region.add_child(station)
	# No shop furniture or zombies inside; floor flush with the ground (no sidewalk here).
	station.build(14.0, 20.0, 7.0, CONCRETE, rng, false, Building.BOARDED_CHANCE, 0.02)

	var sign := Label3D.new()
	sign.text = "POLICE"
	sign.font_size = 80
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.position = Vector3(-0.06, 4.1, station.door_z) # just in front of the facade, over the door
	sign.rotation.y = -PI / 2.0 # Label3D reads from its +Z side; turn that to face the street
	station.add_child(sign)
	_add_door(station.make_door(), false)

	# Inside: a counter across the room, the trader behind it, and a generator-powered lamp.
	_add_box(Vector3(0.8, 1.0, 6.0), station.transform * Vector3(8.0, 0.6, 0.0), TIMBER, station.rotation.y)
	trader = ShopkeeperScene.instantiate() as Shopkeeper
	trader.position = station.transform * Vector3(9.3, 0.1, 0.0) # faces -z: toward the counter and door
	add_child(trader)
	# The logbook on the counter (top at y = 1.1), off to one side: save / load.
	var logbook := SavePoint.new()
	logbook.position = station.transform * Vector3(8.0, 1.1, 2.0)
	logbook.rotation.y = station.rotation.y + 0.3
	nav_region.add_child(logbook)
	# The Chief's corner: a desk with the dead radio, back right past the counter.
	var desk_yaw := station.rotation.y
	_add_box(Vector3(1.0, 0.85, 2.2), station.transform * Vector3(12.6, 0.525, 6.5), TIMBER, desk_yaw)
	_add_box(Vector3(0.35, 0.22, 0.5), station.transform * Vector3(12.6, 1.06, 6.0), Color(0.15, 0.17, 0.15), desk_yaw)
	chief = PoliceChiefScene.instantiate() as PoliceChief
	chief.position = station.transform * Vector3(11.4, 0.1, 6.5) # in front of the desk, facing the room
	add_child(chief)

	var lamp := OmniLight3D.new()
	lamp.position = station.transform * Vector3(6.0, 3.0, 0.0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.5
	lamp.omni_range = 11.0
	add_child(lamp)

	# Plywood fence around the compound, with a gate facing the street.
	var fence_h := 2.2
	var x0 := COMPOUND_MIN.x
	var x1 := COMPOUND_MAX.x
	var z0 := COMPOUND_MIN.y
	var z1 := COMPOUND_MAX.y
	var gate0 := STATION_X - GATE_HALF_WIDTH
	var gate1 := STATION_X + GATE_HALF_WIDTH
	_add_box(Vector3(gate0 - x0, fence_h, 0.15), Vector3((x0 + gate0) / 2.0, fence_h / 2.0, z0), PLYWOOD)
	_add_box(Vector3(x1 - gate1, fence_h, 0.15), Vector3((gate1 + x1) / 2.0, fence_h / 2.0, z0), PLYWOOD)
	_add_box(Vector3(x1 - x0, fence_h, 0.15), Vector3((x0 + x1) / 2.0, fence_h / 2.0, z1), PLYWOOD)
	for x in [x0, x1]:
		_add_box(Vector3(0.15, fence_h, z1 - z0), Vector3(x, fence_h / 2.0, (z0 + z1) / 2.0), PLYWOOD)
	_build_gate(gate0, gate1, z0, fence_h)

	# Guard towers in the two front corners, covering the street and the gate.
	for tower_x in [x0 + 2.5, x1 - 2.5]:
		var base := Vector3(tower_x, 0.0, z0 + 2.5)
		var tower_rids := _build_guard_tower(base)
		var guard := GuardScene.instantiate() as Guard
		guard.exclude = tower_rids
		guard.position = base + Vector3(0, 4.2, 0)
		add_child(guard) # starts facing -z (the street); turns toward targets as it fires


## Two steel leaves that slide sideways behind the fence. Zombies can't break it.
## The navigation bake sees a wall where the gate is (_gate_nav_blocker, removed
## right after baking), so with the gate shut zombies have no path into the
## compound; while it's open, NavigationLinks across the gap give them one.
func _build_gate(gate0: float, gate1: float, fence_z: float, height: float) -> void:
	var z := fence_z + 0.2 # just inside the fence line, so open leaves slide behind it
	var half := (gate1 - gate0) / 2.0
	var leaf := Vector3(half + 0.2, height, 0.1) # overlaps the fence a little at the outer end
	var leaves: Array[Door] = []
	for s: int in [-1, 1]:
		var center := Vector3((gate0 + gate1) / 2.0 + s * (half + 0.2) / 2.0, height / 2.0, z)
		var gate := Door.new()
		gate.label = "gate"
		gate.breakable = false
		gate.setup(leaf, Vector3.ZERO, GATE_COLOR, Transform3D(Basis.IDENTITY, center), 0.0,
				Vector3(s * half, 0.0, 0.0))
		leaves.append(gate)
	leaves[0].linked = [leaves[1]]
	leaves[1].linked = [leaves[0]]

	var x := gate0 + 1.0
	while x <= gate1 - 1.0:
		var link := NavigationLink3D.new()
		# Ends just off the navmesh edges on either side of the gap. Kept short on
		# purpose: zombies repath every 0.3 s, and a start point far behind one that's
		# already in the gap would turn it around (path_desired_distance is 0.6 m).
		link.start_position = Vector3(x, 0.0, fence_z - 0.5) # street side
		link.end_position = Vector3(x, 0.0, fence_z + 0.7) # compound side
		link.enabled = false
		add_child(link)
		leaves[0].nav_links.append(link)
		x += 2.0

	for gate in leaves:
		_add_door(gate, false)

	_gate_nav_blocker = StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(gate1 - gate0, height, 0.15)
	var col := CollisionShape3D.new()
	col.shape = shape
	_gate_nav_blocker.add_child(col)
	_gate_nav_blocker.position = Vector3((gate0 + gate1) / 2.0, height / 2.0, z)
	nav_region.add_child(_gate_nav_blocker)


## Doors go straight under Main, not nav_region, so the navigation bake ignores
## them (see door.gd).
func _add_door(door: Door, open: bool) -> void:
	add_child(door)
	if open:
		door.set_open(true, false)
	doors.append(door)


## Four timber legs, a platform at 4 m and a waist-high railing. Returns the
## physics ids of its parts so the guard's aim ignores its own tower.
func _build_guard_tower(base: Vector3) -> Array[RID]:
	var rids: Array[RID] = []
	for x: float in [-1.2, 1.2]:
		for z: float in [-1.2, 1.2]:
			rids.append(_add_box(Vector3(0.25, 4.0, 0.25), base + Vector3(x, 2.0, z), TIMBER).get_rid())
	rids.append(_add_box(Vector3(3.0, 0.2, 3.0), base + Vector3(0, 4.1, 0), TIMBER).get_rid())
	for s: float in [-1.45, 1.45]:
		rids.append(_add_box(Vector3(3.0, 0.9, 0.1), base + Vector3(0, 4.65, s), PLYWOOD).get_rid())
		rids.append(_add_box(Vector3(0.1, 0.9, 3.0), base + Vector3(s, 4.65, 0), PLYWOOD).get_rid())
	return rids


# --- Westside safe house -------------------------------------------------------

## A boarded-up house at the far west end of the cross street that was meant to
## be safe. Its barricade has been broken through, the survivors are dead, and
## the undead are still inside. Walking into the yard triggers the discovery.
func _build_safe_house() -> void:
	var house := Building.new()
	house.position = Vector3(SAFE_HOUSE_X, 0.0, SAFE_HOUSE_FRONT_Z)
	house.rotation.y = -PI / 2.0 # like the station: faces the cross street (south)
	nav_region.add_child(house)
	# Mostly boarded up; floor flush with the ground like the station.
	house.build(12.0, 14.0, 6.0, Color(0.5, 0.42, 0.34), rng, false, 0.85, 0.02)
	var door_x := SAFE_HOUSE_X - house.door_z # world x of the doorway

	var sign := Label3D.new()
	sign.text = "SAFE HOUSE\nSURVIVORS INSIDE"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(0.85, 0.15, 0.1) # spray paint
	sign.position = Vector3(-0.06, 4.3, house.door_z + 3.0)
	sign.rotation = Vector3(0.0, -PI / 2.0, 0.08) # facing the street, a little crooked
	house.add_child(sign)

	# Plywood barricade across the yard, broken through right in front of the door.
	var z := SAFE_HOUSE_FRONT_Z - 4.0
	var x0 := SAFE_HOUSE_X - 9.0
	var x1 := SAFE_HOUSE_X + 9.0
	_add_box(Vector3((door_x - 2.5) - x0, 2.0, 0.15), Vector3((x0 + door_x - 2.5) / 2.0, 1.0, z), PLYWOOD)
	_add_box(Vector3(x1 - (door_x + 2.5), 2.0, 0.15), Vector3((door_x + 2.5 + x1) / 2.0, 1.0, z), PLYWOOD)
	# The breached panels, knocked flat (low enough to step over).
	_add_box(Vector3(2.4, 0.08, 1.9), Vector3(door_x - 1.2, 0.04, z - 1.1), PLYWOOD, 0.3)
	_add_box(Vector3(2.2, 0.08, 1.9), Vector3(door_x + 1.3, 0.04, z - 0.9), PLYWOOD, -0.4)

	# The people who didn't make it.
	var corpse_spots: Array[Vector3] = [
		house.transform * Vector3(-2.0, 0.1, 2.5), house.transform * Vector3(3.0, 0.1, -3.5),
		house.transform * Vector3(6.5, 0.1, 4.0), house.transform * Vector3(8.0, 0.1, -2.0),
	]
	for spot in corpse_spots:
		var body := HumanNPCScene.instantiate() as HumanNPC
		body.zombies_target = false
		body.outfit_color = Color.from_hsv(rng.randf(), 0.35, 0.4)
		body.position = spot
		body.rotation.y = rng.randf_range(0.0, TAU)
		add_child(body)
		body.die()

	# What they left behind: supplies worth the trip, if you can get to them.
	var crate_color := Color(0.4, 0.33, 0.2)
	for local in [Vector3(10.5, 0.55, -5.0), Vector3(10.5, 0.55, 5.0)]:
		_add_loot(Vector3(1.0, 0.9, 1.4), house.transform * local, crate_color, "Supply crate", house.rotation.y)
		safe_house_crates.append(loot_spots[-1])
	safe_house_crates[0].inventory.add("pistol_ammo", 12)
	safe_house_crates[0].inventory.add("health_pack", 2)
	safe_house_crates[1].inventory.add("canned_food", 3)
	safe_house_crates[1].inventory.add("batteries", 4)

	# The horde: some still inside, some milling around the yard.
	for local in [Vector3(3.0, 0.15, -4.0), Vector3(4.5, 0.15, 3.5), Vector3(7.0, 0.15, -1.0),
			Vector3(9.0, 0.15, 3.0), Vector3(-1.5, 0.15, -5.0), Vector3(-2.5, 0.15, 4.5),
			Vector3(-3.0, 0.15, 0.5)]:
		safe_house_zombie_points.append(house.transform * local)

	# Walking into the yard (or the house) is what "reaching" it means.
	safe_house_point = house.transform * Vector3(-1.5, 0.0, house.door_z)
	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = GameData.LAYER_PLAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(16.0, 4.0, 20.0) # local x: yard to back wall; z: house width plus margin
	var col := CollisionShape3D.new()
	col.shape = shape
	trigger.add_child(col)
	trigger.position = house.transform * Vector3(4.0, 2.0, 0.0)
	trigger.rotation.y = house.rotation.y
	add_child(trigger)
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			quest.reached_safe_house())


# --- Bandit camp ---------------------------------------------------------------

## Two tents, a campfire, a wrecked car for cover, and their stash. The five
## bandits themselves are spawned in _spawn_bandits().
func _build_bandit_camp() -> void:
	var canvas := Color(0.33, 0.35, 0.22)
	_add_box(Vector3(3.0, 1.8, 2.4), CAMP_CENTER + Vector3(-5.0, 0.9, 3.5), canvas, 0.2)
	_add_box(Vector3(3.0, 1.8, 2.4), CAMP_CENTER + Vector3(4.5, 0.9, 4.0), canvas, -0.3)
	_add_box(Vector3(1.9, 0.9, 4.4), CAMP_CENTER + Vector3(0.0, 0.45, 7.5), Color(0.35, 0.2, 0.15), 1.4) # burned-out car
	_add_box(Vector3(0.9, 0.25, 0.9), CAMP_CENTER + Vector3(0.0, 0.125, 0.0), Color(0.12, 0.1, 0.08)) # fire pit
	var fire := OmniLight3D.new()
	fire.position = CAMP_CENTER + Vector3(0.0, 0.8, 0.0)
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 2.0
	fire.omni_range = 10.0
	add_child(fire)

	_add_loot(Vector3(1.2, 0.8, 0.9), CAMP_CENTER + Vector3(-1.5, 0.4, 5.0), Color(0.3, 0.25, 0.15), "Bandit stash")
	var stash: LootSpot = loot_spots[-1]
	stash.inventory.add("pistol_ammo", 16)
	stash.inventory.add("health_pack", 1)
	stash.inventory.add("canned_food", 2)
	stash.inventory.add("batteries", 2)

	for offset in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(-2, 0, 2), Vector3(2.5, 0, 1.5), Vector3(0, 0, -4)]:
		bandit_spawns.append(CAMP_CENTER + offset + Vector3(0, 0.15, 0))


func _spawn_bandits() -> void:
	for pos in bandit_spawns.slice(0, BANDIT_COUNT):
		var bandit := BanditScene.instantiate() as Bandit
		bandit.home = CAMP_CENTER
		bandit.position = pos
		bandit.rotation.y = rng.randf_range(0.0, TAU)
		add_child(bandit)
		bandits.append(bandit)


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
		_show_toast("Autosaved")


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
		"shop_stock": trader.stock.to_dict(),
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

	# Ground items, zombies: throw away the freshly spawned ones and recreate
	# exactly what the save recorded.
	for item in get_tree().get_nodes_in_group("ground_items"):
		item.remove_from_group("ground_items")
		item.queue_free()
	for entry: Dictionary in data.get("ground_items", []):
		if GameData.ITEMS.has(entry.get("id", "")):
			_add_ground_item(entry["id"], int(entry.get("amount", 1)),
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
	player.load_state(data.get("player", {}))


# --- Loot --------------------------------------------------------------------

## Fills each container's inventory.
func _assign_loot() -> void:
	# One crowbar in the whole town, at least ~40 m north of where you start, so you
	# have to venture in for it. Half the time it's in a container, half on the ground.
	var crowbar_spot: LootSpot = null
	if rng.randf() < 0.5:
		var far_spots := loot_spots.filter(func(s: LootSpot) -> bool: return s.global_position.z < 20.0)
		if far_spots.is_empty(): # can happen with a different town seed
			far_spots = loot_spots
		crowbar_spot = far_spots[rng.randi_range(0, far_spots.size() - 1)]
	else:
		_add_ground_item("crowbar", 1, _street_spot(-70.0, 15.0))
	for spot: LootSpot in loot_spots:
		if spot == crowbar_spot:
			spot.inventory.add("crowbar")
		if rng.randf() < container_health_pack_chance:
			spot.inventory.add("health_pack")
		if rng.randf() < container_ammo_chance:
			spot.inventory.add("pistol_ammo", rng.randi_range(3, 7))
		if rng.randf() < container_trade_goods_chance:
			if rng.randf() < 0.5:
				spot.inventory.add("canned_food", rng.randi_range(1, 2))
			else:
				spot.inventory.add("batteries", rng.randi_range(1, 3))


## Loose items lying in the street.
func _scatter_ground_items() -> void:
	for i in ground_items:
		var pos := _street_spot(-75.0, 50.0)
		var roll := rng.randf()
		if roll < 0.45:
			_add_ground_item("pistol_ammo", rng.randi_range(3, 7), pos)
		elif roll < 0.7:
			_add_ground_item("health_pack", 1, pos)
		elif roll < 0.85:
			_add_ground_item("canned_food", 1, pos)
		else:
			_add_ground_item("batteries", rng.randi_range(1, 2), pos)


## A random point on Main Street between two z values that isn't inside a car.
func _street_spot(z_from: float, z_to: float) -> Vector3:
	var pos := Vector3(rng.randf_range(-4.5, 4.5), 0.02, rng.randf_range(z_from, z_to))
	for attempt in 20:
		if not _near_car(pos, 3.0):
			break
		pos = Vector3(rng.randf_range(-4.5, 4.5), 0.02, rng.randf_range(z_from, z_to))
	return pos


func _near_car(pos: Vector3, min_dist: float) -> bool:
	for car in car_spots:
		if Vector2(pos.x - car.x, pos.z - car.z).length() < min_dist:
			return true
	return false


func _add_ground_item(id: String, amount: int, pos: Vector3, yaw := INF) -> void:
	var item := GroundItem.new()
	item.position = pos
	item.rotation.y = rng.randf_range(0.0, TAU) if yaw == INF else yaw
	item.setup(id, amount)
	add_child(item) # not under nav_region: items shouldn't affect zombie paths


# --- Characters --------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerScene.instantiate() as Player
	player.transform = player_spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.notify.connect(_show_toast)


func _spawn_zombies() -> void:
	for i in outdoor_zombies:
		var pos: Vector3
		if rng.randf() < 0.65:
			pos = _street_spot(-75.0, 35.0) + Vector3(0, 0.08, 0)
		else:
			# On the cross street, but not right where you start (x = 24) or in front
			# of the police station.
			pos = Vector3(rng.randf_range(-70.0, 6.0), 0.1, rng.randf_range(-4.0, 4.0))
		_add_zombie(pos)
	# A few more already shut inside the shops.
	for point in interior_points:
		if rng.randf() < indoor_zombie_chance:
			_add_zombie(point + Vector3(0, 0.1, 0))
	# The safe house horde.
	for point in safe_house_zombie_points:
		_add_zombie(point)


func _add_zombie(pos: Vector3) -> void:
	var zombie := ZombieScene.instantiate() as Zombie
	zombie.position = pos
	zombie.rotation.y = rng.randf_range(0.0, TAU)
	add_child(zombie)
	zombies.append(zombie)


func _on_player_died() -> void:
	message_label.visible = true # text is set in _process, so the button hint stays current
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_has_save_on_death = SaveGame.exists() # checked once, not every frame
	if _has_save_on_death:
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_inside_tree() and player.is_dead:
				_load_or_restart())


func _on_player_damaged() -> void:
	hurt_overlay.color.a = 0.35
	if hurt_tween:
		hurt_tween.kill()
	hurt_tween = create_tween()
	hurt_tween.tween_property(hurt_overlay, "color:a", 0.0, 0.5)


## A big story moment in the middle of the screen, fading after a few seconds.
func _show_story(text: String) -> void:
	story_label.text = text
	story_label.modulate.a = 1.0
	if story_tween:
		story_tween.kill()
	story_tween = create_tween()
	story_tween.tween_interval(6.0)
	story_tween.tween_property(story_label, "modulate:a", 0.0, 1.5)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Red flash when hurt. Added first so it sits behind the text.
	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	status_label = Label.new()
	status_label.position = Vector2(20, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(status_label)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(clock_label)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -300.0
	clock_label.offset_right = -20.0
	clock_label.offset_top = 16.0

	var crosshair := Label.new()
	crosshair.text = "+"
	layer.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Full-screen labels with centered text; offset_top pushes the center down.
	prompt_label = _make_centered_label(18)
	layer.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.offset_top = 90.0

	toast_label = _make_centered_label(22)
	layer.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label.offset_bottom = -300.0

	# Hotbar: one box per item you can hold, the held one highlighted.
	hotbar_box = HBoxContainer.new()
	hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_box.add_theme_constant_override("separation", 6)
	hotbar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hotbar_box)
	hotbar_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar_box.offset_top = -86.0
	hotbar_box.offset_bottom = -46.0

	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(help_label)
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help_label.offset_left = 16.0
	help_label.offset_top = -36.0
	help_label.offset_bottom = -12.0

	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	objective_label.add_theme_constant_override("outline_size", 6)
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	layer.add_child(objective_label)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_label.offset_top = 16.0
	objective_label.offset_bottom = 44.0

	story_label = _make_centered_label(28)
	story_label.add_theme_constant_override("outline_size", 8)
	story_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	layer.add_child(story_label)
	story_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_label.offset_bottom = -220.0 # sits in the upper part of the screen

	message_label = _make_centered_label(36)
	message_label.visible = false
	layer.add_child(message_label)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Rebuilds the hotbar boxes only when something about them changed.
func _update_hotbar() -> void:
	var bar := player.hotbar()
	var texts: Array[String] = []
	for i in bar.size():
		var id := bar[i]
		var label := "Fists" if id == "hands" else GameData.item_name(id)
		if id == "pistol":
			label += " %d/%d" % [player.pistol_mag, Player.PISTOL_MAG]
		elif id != "hands" and player.inventory.count(id) > 1:
			label += " x%d" % player.inventory.count(id)
		if not Controls.using_gamepad and i < 9:
			label = "%d  %s" % [i + 1, label] # number key that selects it
		texts.append(label)
	var signature := "%s|%s" % [str(texts), player.held]
	if signature == _hotbar_shown:
		return
	_hotbar_shown = signature

	for child in hotbar_box.get_children():
		hotbar_box.remove_child(child)
		child.queue_free()
	for i in bar.size():
		var selected := bar[i] == player.held
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.75, 0.35, 0.85) if selected else Color(0.0, 0.0, 0.0, 0.5)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = texts[i]
		label.add_theme_font_size_override("font_size", 15)
		if selected:
			label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		panel.add_child(label)
		hotbar_box.add_child(panel)


func _make_centered_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


# --- Helpers -----------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


## A visible mesh with no collision (decoration).
func _add_mesh(mesh: PrimitiveMesh, pos: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	mesh.material = _material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation.y = yaw
	nav_region.add_child(inst)
	return inst


## A solid box you can't walk through: mesh + matching collision shape.
func _add_box(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw

	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = box
	body.add_child(inst)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	nav_region.add_child(body)
	return body


## A solid box you can search. Still under nav_region, so zombies path around it.
func _add_loot(size: Vector3, pos: Vector3, color: Color, label: String, yaw := 0.0) -> void:
	var spot := LootSpot.new()
	spot.position = pos
	spot.rotation.y = yaw
	spot.setup(size, color, label)
	nav_region.add_child(spot)
	loot_spots.append(spot)
