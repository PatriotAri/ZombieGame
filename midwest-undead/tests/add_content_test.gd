extends SceneTree
## New content as files only: a melee weapon, a loot table, a zombie kind, a
## survivor without markers. The test files (zz_*) are written into the game's
## content folders and deleted again: at the end, on quitting, and at the start
## (in case an earlier run was killed). Two real survivors have SpawnPoints on
## the test map (tests/support/test_map.gd).
const TestMap := preload("res://tests/support/test_map.gd")
const FILES := ["res://items/data/zz_bat.tres", "res://items/loot/zz_test.tres",
		"res://characters/zombie/kinds/zz_brute.tres", "res://characters/npcs/survivors/zz_nobody.tres"]
const GIVE_UP := 600 # frames: never stuck with the files left in
var main: Node
var f := 0
var fails := 0
var z: Node
func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	_remove_files()
	var bat := WeaponData.new()
	bat.id = "zz_bat"; bat.display_name = "Test bat"; bat.weapon_kind = "melee"
	bat.damage = 200.0; bat.reach = 2.3; bat.cooldown = 0.5; bat.stamina_cost = 5.0; bat.noise = 9.0
	bat.color = Color(0.6, 0.4, 0.2); bat.size = Vector3(0.06, 0.06, 0.8); bat.order = 45
	bat.held_position = Vector3(0.35, -0.35, -0.55)
	ResourceSaver.save(bat, "res://items/data/zz_bat.tres")
	var pick := LootPick.new(); pick.item = "zz_bat"
	var roll := LootRoll.new(); roll.chance = 1.0; roll.items = [pick]
	var table := LootTable.new(); table.rolls = [roll]
	ResourceSaver.save(table, "res://items/loot/zz_test.tres")
	var brute := ZombieKind.new()
	brute.id = "zz_brute"; brute.spawn_chance = 0.5; brute.health = 300.0
	brute.min_speed = 0.5; brute.max_speed = 0.6; brute.body_scale = Vector3(1.4, 1.2, 1.4); brute.voice_pitch = 0.6
	ResourceSaver.save(brute, "res://characters/zombie/kinds/zz_brute.tres")
	var person := SurvivorData.new()
	person.display_name = "Zz Nobody"
	ResourceSaver.save(person, "res://characters/npcs/survivors/zz_nobody.tres")
	var map := TestMap.begin()
	TestMap.spawn_point(map, "survivor", Vector3(-60, 0, -60), "Dale Hutchins")
	TestMap.spawn_point(map, "survivor", Vector3(-64, 0, -60), "Gus Lindqvist")
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)

func _finalize() -> void:
	_remove_files()

func _remove_files() -> void:
	for path: String in FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		var GameData = load("res://core/game_data.gd")
		check(GameData.has_item("zz_bat") and GameData.item_name("zz_bat") == "Test bat", "new weapon file is an item")
		var ids: Array = GameData.item_ids()
		check(ids.find("zz_bat") > ids.find("crowbar") and ids.find("zz_bat") < ids.find("pistol_ammo"), "sorted by its order (45: after the crowbar)")
		var p = main.player
		p.give_item("zz_bat")
		p.select("zz_bat")
		check(p.holdable().has("zz_bat") and p.hands.models.has("zz_bat"), "held: it has a model in your hands")
		check(GameData.item_use("zz_bat") == "melee", "use: melee")
		for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(500, 0, 500)
		p.global_position = Vector3(24, 0.1, 0); p.rotation.y = 0.0; p.camera.rotation.x = 0.0
		z = main._add_zombie(p.global_position - p.global_basis.z * 1.6, null, "walker")
	if f == 10:
		var p = main.player
		p.camera.look_at(z.global_position + Vector3(0, 1.0, 0))
		p.attack_cooldown = 0.0
		p._try_melee()
	if f == 40:
		check(main.player.hands.shown == "zz_bat" and main.player.hands.models["zz_bat"].visible, "its model is the one showing in your hands")
		check(z.is_dead, "one swing (200 damage) kills a walker")
		# Loot table file.
		var Spot = load("res://items/loot_spot.gd")
		var spot = Spot.new()
		spot.loot_table = "zz_test"
		var rng := RandomNumberGenerator.new()
		load("res://world/loot.gd").fill([spot], rng)
		check(spot.inventory.count("zz_bat") == 1, "new loot table drops it: %s" % spot.inventory.to_dict())
		var prop := {}
		for pr in spot.get_property_list():
			if pr["name"] == "loot_table": prop = pr
		check(String(prop.get("hint_string", "")).contains("zz_test"), "and it's in the container's list")
		spot.free()
		# Zombie kind file.
		var counts := {}
		var dice := RandomNumberGenerator.new()
		for i in 10000:
			var k: String = ZombieKind.roll(dice).id
			counts[k] = counts.get(k, 0) + 1
		check(absf(counts.get("zz_brute", 0) / 10000.0 - 0.5) < 0.03 and absf(counts.get("crawler", 0) / 10000.0 - 0.08) < 0.01, "new kind rolls at its chance: %s" % counts)
		var b = main._add_zombie(Vector3(30, 0.1, 0), null, "zz_brute")
		# (Each zombie is also 0.92-1.08 times its kind's size: zombie.gd SIZE_RANGE.)
		var ratio: Vector3 = b.visual.scale / Vector3(1.4, 1.2, 1.4)
		var big := is_equal_approx(ratio.x, ratio.y) and is_equal_approx(ratio.y, ratio.z) and ratio.x >= 0.92 and ratio.x <= 1.08
		check(b.health == 300.0 and big and b.speed >= 0.5 and b.speed <= 0.6, "a brute: 300 health, its body scale (%s), slow (%.2f)" % [b.visual.scale, b.speed])
		# Survivor file without markers: skipped with a warning, the rest fine.
		var names: Array = main.survivors.survivors.map(func(sv: Node) -> String: return sv.display_name)
		check(names.size() == 2 and not "Zz Nobody" in names, "survivor without SpawnPoints is skipped (the two with them are there: %s)" % [names])
		_remove_files()
		print("FAILS: %d" % fails)
		return true
	if f > GIVE_UP:
		fails += 1
		print("  FAIL gave up after %d frames" % GIVE_UP)
		_remove_files()
		print("FAILS: %d" % fails)
		return true
	return false
