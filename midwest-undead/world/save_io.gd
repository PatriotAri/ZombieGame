extends RefCounted
## Saving and loading the game (main.gd's _save_game and _apply_save use it):
## everything that can change during play, gathered from the game scene's root
## (main.gd) into a Dictionary for core/save_game.gd, and put back on a freshly
## loaded map. Things on the map go by their "town_id". Never instanced.

const SaveGame := preload("res://core/save_game.gd")
const GameData := preload("res://core/game_data.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")


## Everything to save, from `main` (main.gd).
static func collect(main: Node) -> Dictionary:
	var containers := {}
	for spot in main.loot_spots:
		containers[spot.get_meta("town_id")] = {"opened": spot.opened, "inventory": spot.inventory.to_dict()}
	var ground := []
	for item in main.get_tree().get_nodes_in_group("ground_items"):
		if not item.is_queued_for_deletion(): # (picked up this frame)
			ground.append({"id": item.item_id, "amount": item.amount,
					"position": SaveGame.vec_to_array(item.global_position), "yaw": item.rotation.y})
	var zombie_data := [] # the ones still up
	for zombie in main.zombies:
		if is_instance_valid(zombie) and not zombie.is_dead:
			var entry := {"position": SaveGame.vec_to_array(zombie.global_position),
					"yaw": zombie.rotation.y, "health": zombie.health, "kind": zombie.kind}
			if zombie.march_to != Vector3.INF:
				entry["march"] = SaveGame.vec_to_array(zombie.march_to)
			zombie_data.append(entry)
	var door_data := {}
	for door in main.doors:
		door_data[door.get_meta("town_id")] = door.save_state()
	var mine_data := {}
	for mine in main.mines:
		mine_data[mine.get_meta("town_id")] = mine.save_state()
	var bandit_data := {} # by the SpawnPoint each started at
	for bandit in main.bandits:
		bandit_data[bandit.get_meta("spawn_id")] = {"position": SaveGame.vec_to_array(bandit.global_position),
				"yaw": bandit.rotation.y, "health": bandit.health, "dead": bandit.is_dead}
	return {
		"clock": main.day_night.clock_text(),
		"objective": main.quests.objective_text(),
		"time": {"hour": main.day_night.hour, "day": main.day_night.day},
		"quest": main.quests.save_state(),
		"player": main.player.save_state(),
		"containers": containers,
		"ground_items": ground,
		"zombies": zombie_data,
		"horde": main.horde.save_state(),
		"bandits": bandit_data,
		"doors": door_data,
		"mines": mine_data,
		"fortifications": main.fortifications.save_state(),
		"structures": main.structures.save_state(),
		"discovered": main.discoveries.save_state(),
		"traders": _traders(main),
		"wagon_trader": main.trader_arrival.save_state(),
		"woodworker": main.woodworker_rescue.save_state(),
		"survivors": main.survivors.save_state(),
		"camps": main.camps.save_state(),
		"salvaged": main.salvage.save_state(),
	}


## Puts a save on top of the freshly loaded map. Order matters a little: the
## world first, then the people in it, then you.
static func apply(main: Node, data: Dictionary) -> void:
	var time: Dictionary = data.get("time", {})
	main.day_night.hour = float(time.get("hour", main.day_night.hour))
	main.day_night.day = int(time.get("day", main.day_night.day))
	main.quests.begin_load() # no story moments while the save goes back on
	main.quests.load_state(data.get("quest", {}))

	var containers: Dictionary = data.get("containers", {})
	for spot in main.loot_spots:
		var saved: Dictionary = containers.get(spot.get_meta("town_id"), {})
		if saved.is_empty():
			continue # new to the map since the save: keeps its fresh contents
		spot.inventory.from_dict(saved.get("inventory", {}))
		if saved.get("opened", false):
			spot.open() # darkens it like when you searched it

	var door_data: Dictionary = data.get("doors", {})
	for door in main.doors:
		if door_data.has(door.get_meta("town_id")):
			door.load_state(door_data[door.get_meta("town_id")])
	var mine_data: Dictionary = data.get("mines", {})
	for mine in main.mines:
		if mine_data.has(mine.get_meta("town_id")):
			mine.load_state(mine_data[mine.get_meta("town_id")])
	main.fortifications.load_state(data.get("fortifications", {}))
	main.structures.load_state(data.get("structures", []))
	main.discoveries.load_state(data.get("discovered", []))

	# Ground items and zombies: throw away the fresh ones and recreate exactly
	# what the save recorded. (Nothing is aiming at a zombie yet: the game
	# hasn't run a frame.)
	for item in main.get_tree().get_nodes_in_group("ground_items"):
		item.remove_from_group("ground_items")
		item.queue_free()
	for entry: Dictionary in data.get("ground_items", []):
		if GameData.has_item(str(entry.get("id", ""))):
			main.add_ground_item(entry["id"], int(entry.get("amount", 1)),
					SaveGame.array_to_vec(entry["position"]), float(entry.get("yaw", 0.0)))
	for zombie in main.zombies:
		zombie.get_parent().remove_child(zombie) # out of the "zombies" group right away
		zombie.queue_free()
	main.zombies.clear()
	for entry: Dictionary in data.get("zombies", []):
		var zombie = main._add_zombie(SaveGame.array_to_vec(entry["position"]), null, str(entry.get("kind", "walker")))
		zombie.rotation.y = float(entry.get("yaw", 0.0))
		zombie.health = float(entry.get("health", zombie.max_health))
		if entry.has("march"):
			zombie.march_to = SaveGame.array_to_vec(entry["march"])
	main.horde.load_state(data.get("horde", {}))

	var bandit_data: Dictionary = data.get("bandits", {})
	for bandit in main.bandits:
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

	main.trader_arrival.load_state(data.get("wagon_trader", {}))
	main.woodworker_rescue.load_state(data.get("woodworker", {}))
	main.survivors.load_state(data.get("survivors", {}))
	main.camps.load_state(data.get("camps", {}))
	main.salvage.load_state(data.get("salvaged", []))
	_load_traders(main, data.get("traders", {})) # (after the people quests bring in are back)
	main.quests.end_load()
	main.player.load_state(data.get("player", {}))


## Every trader's stock, by their npc_id: {id: {"stock", "restocked_day"}}.
static func _traders(main: Node) -> Dictionary:
	var traders := {}
	for person in main.get_tree().get_nodes_in_group("named_npcs"):
		if person is Shopkeeper and not person.is_dead:
			traders[person.npc_id] = {"stock": person.stock.to_dict(), "restocked_day": person.restocked_day}
	return traders


static func _load_traders(main: Node, traders: Dictionary) -> void:
	for person in main.get_tree().get_nodes_in_group("named_npcs"):
		if person is Shopkeeper and traders.has(person.npc_id):
			var saved: Dictionary = traders[person.npc_id]
			person.stock.from_dict(saved.get("stock", {}))
			person.restocked_day = int(saved.get("restocked_day", main.day_night.day))
