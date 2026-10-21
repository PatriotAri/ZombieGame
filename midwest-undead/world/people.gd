extends Node3D
## The people: you, and the map's NPCs at their SpawnPoints (world/game_map.gd).
## What pressing interact on someone opens (the talk menu) is decided here,
## and the bandits and the Quartermaster's stock go in the save. main.gd makes
## it, spawns everyone, and once the quests and the menus are there calls
## setup_talk().

const Player := preload("res://characters/player/player.gd")
const PlayerScene := preload("res://characters/player/player.tscn")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const ShopkeeperScene := preload("res://characters/npcs/shopkeeper.tscn")
const PoliceChief := preload("res://characters/npcs/police_chief.gd")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const Guard := preload("res://characters/npcs/guard.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")
const Bandit := preload("res://characters/npcs/bandit.gd")
const BanditScene := preload("res://characters/npcs/bandit.tscn")
const Survivor := preload("res://characters/npcs/survivor.gd")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const Recipes := preload("res://core/recipes.gd")
const SaveIds := preload("res://core/save_ids.gd")
const SaveGame := preload("res://core/save_game.gd")
const GameMap := preload("res://world/game_map.gd")
const DayNight := preload("res://world/day_night.gd")
const GameUI := preload("res://ui/game_ui.gd")
const QuestManager := preload("res://quests/quest_manager.gd")
const Camps := preload("res://world/camps.gd")
const Survivors := preload("res://world/survivors.gd")
const WoodworkerRescue := preload("res://world/woodworker_rescue.gd")

var player: Player
var chief: PoliceChief
var trader: Shopkeeper # the Quartermaster (null on a map without a "trader" SpawnPoint)
var bandits: Array[Bandit] = []
# For the talk menu (setup_talk()).
var _quests: QuestManager
var _ui: GameUI
var _camps: Camps
var _survivors: Survivors
var _woodworker_rescue: WoodworkerRescue


func _ready() -> void:
	Saveable.section(self, "bandits", _save_bandits, _load_bandits, Saveable.BANDITS)


## You, at at.
func spawn_player(at: Transform3D) -> Player:
	player = PlayerScene.instantiate() as Player
	player.transform = at
	add_child(player)
	return player


## The map's NPCs, at their SpawnPoints: the Quartermaster and the Chief in the
## station, the guards on their towers, the bandits at their camp, and the
## people who didn't make it at the safe house. After the navigation bake, so
## they can find their way around.
func spawn_npcs(map: GameMap, day_night: DayNight) -> void:
	for spot in map.spawn_points:
		var xform := Transform3D(Basis(Vector3.UP, spot.global_rotation.y), spot.global_position)
		match spot.role:
			"trader":
				trader = ShopkeeperScene.instantiate() as Shopkeeper
				trader.transform = xform
				trader.day_night = day_night # restocks each morning
				add_child(trader)
				Saveable.section(trader, "shop", trader.save_state, trader.load_state, Saveable.SHOP)
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
				bandit.set_meta(SaveIds.KEY, spot.get_meta(SaveIds.KEY))
				add_child(bandit)
				bandits.append(bandit)
			"corpse":
				var body := HumanNPCScene.instantiate() as HumanNPC
				body.zombies_target = false
				body.outfit_color = spot.outfit_color
				body.transform = xform
				add_child(body)
				body.die()


## What talking to someone needs; from now on pressing interact on them opens it.
func setup_talk(quests: QuestManager, ui: GameUI, camps: Camps, survivors: Survivors,
		woodworker_rescue: WoodworkerRescue) -> void:
	_quests = quests
	_ui = ui
	_camps = camps
	_survivors = survivors
	_woodworker_rescue = woodworker_rescue
	player.npc_interacted.connect(_on_talk)


## Whether a bandit is after target.
func bandit_after(target: Node3D) -> bool:
	for bandit in bandits:
		if not bandit.is_dead and bandit.state == Bandit.State.COMBAT and bandit.target == target:
			return true
	return false


## Pressing interact on an NPC. Anything a quest has for them (an offer, a step
## to talk to them, a reminder) comes first; next to their own business
## (trading, building...) it's a choice. With nothing about quests, they do
## their own thing.
func _on_talk(npc: HumanNPC) -> void:
	npc.talking = true # (until your menus close)
	if npc is Woodworker and (npc as Woodworker).state == Woodworker.State.CAPTIVE:
		_woodworker_rescue.untie() # (the rescue itself is the woodworker's own scene)
		return
	var options := _quests.talk_options(npc)
	var own := _own_business(npc)
	if options.is_empty():
		if own.is_empty():
			_quests.afterword(npc) # what they say once their quests are done
		else:
			own[1].call()
		return
	if own.is_empty() and options.size() == 1:
		options[0][1].call()
		return
	if not own.is_empty():
		options.append(own)
	options.append(["Never mind", Callable()])
	_ui.choice_menu.open(player, npc.display_name, "", options)


## What an NPC does when it's not about quests: [label, callable], or [] if nothing.
func _own_business(npc: HumanNPC) -> Array:
	if npc is Guard and npc.has_meta("survivor"): # one of your survivors on a guard post
		return ["Come down off guard duty", func() -> void: _camps.stand_down(npc.get_meta("survivor"))]
	if npc is Woodworker and (npc as Woodworker).state == Woodworker.State.HOME:
		return ["Build something", func() -> void: _ui.craft_menu.open(player, npc.display_name, Recipes.WOODWORKER)]
	if npc is Survivor:
		return ["Talk", func() -> void: _survivors.talk(npc as Survivor)]
	if npc is Shopkeeper:
		return ["Trade", func() -> void: _ui.shop_menu.open(player, npc as Shopkeeper)]
	return []


## By the key of the SpawnPoint each started at.
func _save_bandits() -> Dictionary:
	var data := {}
	for bandit in bandits:
		var key := str(bandit.get_meta(SaveIds.KEY, ""))
		if key != "":
			data[key] = {"position": SaveGame.vec_to_array(bandit.global_position),
					"yaw": bandit.rotation.y, "health": bandit.health, "dead": bandit.is_dead}
	return data


func _load_bandits(data: Dictionary) -> void:
	for bandit in bandits:
		var entry: Dictionary = data.get(str(bandit.get_meta(SaveIds.KEY, "")), {})
		if entry.is_empty():
			continue
		bandit.global_position = SaveGame.array_to_vec(entry["position"])
		bandit.rotation.y = float(entry.get("yaw", 0.0))
		if entry.get("dead", false):
			bandit.drop_loot_on_death = false # their drops are already in ground_items
			bandit.die()
		else:
			bandit.health = float(entry.get("health", bandit.max_health))
