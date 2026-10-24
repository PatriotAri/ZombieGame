extends SceneTree
## Mines phase 4 in the game: scattered lockers and caches with the mine loot
## tables; the helmet lamp (worn, brighter, batteries last twice as long);
## the lantern (carried light, set down, picked up); dynamite thrown at
## zombies (and you hurt too), set down at a cave-in (blown clear), wrecking
## your own fence and barricade; held too long, it goes off in your hand.
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var fails := 0
var mine: KitMine
var p: Node
var phase := 0
var t0 := 0
var zs: Array = []
var charge0 := 0.0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func pts(a: Array) -> Array[Vector3i]:
	var r: Array[Vector3i] = []
	r.assign(a)
	return r

func _initialize() -> void:
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	mine = KitMine.new()
	mine.name = "TestMine"
	var t1 := MineTunnel.make(pts([Vector3i(0, 0, 0), Vector3i(0, 0, -10)]))
	t1.entrance_at_start = true
	mine.tunnels = [t1, MineTunnel.make(pts([Vector3i(0, 0, -4), Vector3i(5, 0, -4)]))]
	var caves: Array[Vector3i] = [Vector3i(0, 0, -8)]
	mine.cave_ins = caves
	mine.scatter_loot = 2
	mine.position = Vector3(0, 0, -40)
	map_root.add_child(mine)
	mine.owner = map_root
	var packed := PackedScene.new()
	packed.pack(map_root)
	map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func g(cell: Vector3i, up := 0.05) -> Vector3:
	return mine.to_global(KitMine.cell_position(cell)) + Vector3(0, up, 0)

func view(at: Vector3, yaw: float, pitch := 0.0) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.rotation.y = yaw
	p.camera.rotation.x = pitch

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = main.player
		p.health = 1e6
		for zz in main.zombies: zz.set_physics_process(false); zz.global_position = Vector3(-900, 0, 900)
		mine = main.town.get_node("TestMine")
		var t: Node = main.terrain
		var rect := Rect2(-40, -110, 90, 75)
		for x in range(int(rect.position.x), int(rect.end.x) + 1):
			for zc in range(int(rect.position.y), int(rect.end.y) + 1):
				t.data.set_height(Vector3(x, 0, zc), clampf((-zc - 38.25) * 1.5, 0.0, 12.0))
		TerrainEdit.finish(t, rect)
		mine.apply(t)
		# Scattered loot: a locker and a cache, in the game's containers.
		var loot: Array = mine.find_children("*", "KitContainer", true, false)
		var tables := loot.map(func(c: Node) -> String: return c.get("loot_table"))
		check(loot.size() == 2 and "miner" in tables and "mine_cache" in tables, "Scatter Loot 2: a miner's locker and a supply cache (%s)" % str(tables))
		check(loot.all(func(c: Node) -> bool: return c in main.loot_spots), "they're the game's containers (searched, saved)")
		# The helmet lamp.
		p.give_item("helmet_lamp")
		p.give_item("batteries", 2)
		p.wear_lamp(true)
		p._toggle_flashlight()
		check(p.lamp_worn and p.lights._lamp.visible and not p.flashlight.visible, "worn, the light key switches the helmet lamp")
		check(p.lights._lamp.light_energy > p.lights._flashlight_energy * 1.5, "it's brighter than the flashlight")
		charge0 = p.lights.lamp_charge
		phase = 1
		t0 = f
	if phase == 1 and f == t0 + 120:
		var used: float = charge0 - p.lights.lamp_charge
		var flashlight_would: float = 2.0 / p.battery_life
		check(absf(used - flashlight_would / 2.0) < 0.002, "its batteries last twice as long (%.4f used in 2 s; the flashlight %.4f)" % [used, flashlight_would])
		p._toggle_flashlight()
		check(not p.lights._lamp.visible and not p.flashlight.visible, "and it switches off")
		# The lantern: held, it lights round you; set down; picked back up.
		p.give_item("lantern")
		p.select("lantern")
	if phase == 1 and f == t0 + 125:
		check(p.lights._lantern.visible, "holding a lantern lights all round you")
		var piece: Node = main.structures.build("lantern", Transform3D(Basis.IDENTITY, g(Vector3i(0, 0, -2), 0.0)), null)
		p.take_item("lantern")
		check(piece.find_children("*", "OmniLight3D", true, false).size() > 0, "set down, it stays lit")
		check(piece.call("interact_prompt") == "pick up the lantern", "\"%s\"" % piece.call("interact_prompt"))
		var back: Dictionary = main.structures.take_down(piece)
		check(back.get("lantern", 0) == 1, "picked up, you get it back")
		p.select("hands")
		# Dynamite thrown down the side tunnel at three zombies.
		for i in 3:
			var z: Node = main._add_zombie(g(Vector3i(5, 0, -4), 0.2) + Vector3(0, 0, -0.6 + i * 0.6))
			z.set_physics_process(false)
			zs.append(z)
		p.health = 100.0
		p.give_item("dynamite", 3)
		p.select("dynamite")
		view(g(Vector3i(1, 0, -4)), -PI / 2.0, 0.05)
		phase = 2
		t0 = f
	if phase == 2 and f == t0 + 30:
		Input.action_press("use_held")
	if phase == 2 and f == t0 + 34:
		check(p._cooking, "use lights it")
	if phase == 2 and f == t0 + 60: # held half a second
		Input.action_release("use_held")
	if phase == 2 and f == t0 + 62:
		check(not p._cooking and p.inventory.count("dynamite") == 2, "let go: thrown (2 left)")
		check(main.find_children("*", "Dynamite", true, false).size() == 1, "a lit stick in the air")
	if phase == 2 and f > t0 + 62 and f % 20 == 0:
		var sticks := main.find_children("*", "Dynamite", true, false)
		if sticks.size():
			print("    stick at ", mine.to_local(sticks[0].global_position), " fuse ", sticks[0].fuse)
	if phase == 2 and f == t0 + 300:
		print("    zombies: ", zs.map(func(z): return [z.health, z.is_dead, mine.to_local(z.global_position)] if is_instance_valid(z) else "gone"))
		check(zs.all(func(z: Node) -> bool: return not is_instance_valid(z) or z.is_dead), "the blast killed the zombies")
		check(is_equal_approx(p.health, 100.0), "10 m off, you're clear of it (%.0f health)" % p.health)
		Dynamite.explode(self, p.global_position + Vector3(4.0, 0.5, 0))
		check(p.health < 80.0 and p.health > 30.0, "4 m off, it hurts you (%.0f health)" % p.health)
		check(main.find_children("*", "Dynamite", true, false).is_empty(), "and the stick's gone")
		# Set down by the cave-in, crouching, then get clear.
		p.health = 1e6
		view(g(Vector3i(0, 0, -7)), 0.0)
		Input.action_press("crouch")
		phase = 3
		t0 = f
	if phase == 3 and f == t0 + 10:
		p._use_held()
		Input.action_release("crouch")
		check(p.inventory.count("dynamite") == 1, "crouching, use sets one down lit")
	if phase == 3 and f == t0 + 20:
		view(g(Vector3i(3, 0, -4)), 0.0) # round the corner
	if phase == 3 and f == t0 + 10 + 60 * 7:
		check(mine.find_children("*", "MineCaveIn", true, false).size() == 1, "7 s on: not yet (an 8 s fuse)")
	if phase == 3 and f == t0 + 10 + 60 * 9:
		check(mine.find_children("*", "MineCaveIn", true, false).is_empty(), "the cave-in's blown clear")
		# Your own fence and a barricade, outside: wrecked.
		var fence: Node = main.structures.build("fence", Transform3D(Basis.IDENTITY, Vector3(10, 0, -20)), null)
		main.fortifications.place_barricade(Transform3D(Basis.IDENTITY, Vector3(13, 0, -20)))
		var barricades: int = main.fortifications.barricades.size()
		Dynamite.explode(self, Vector3(11.5, 0.5, -20))
		check(fence.broken, "the blast wrecks your own fence")
		check(main.fortifications.barricades.size() == barricades - 1, "and your barricade")
		# Held too long: it goes off in your hand.
		p.health = 500.0
		view(Vector3(30, 0.1, -20), 0.0)
		p.select("dynamite")
		phase = 4
		t0 = f
	if phase == 4 and f == t0 + 10:
		Input.action_press("use_held")
	if phase == 4 and f == t0 + 10 + 60 * 5:
		Input.action_release("use_held")
		check(p.inventory.count("dynamite") == 0 and p.health < 500.0 - 100.0, "held 5 s: it went off in your hand (%.0f health)" % p.health)
		print("FAILS: %d" % fails)
		quit()
		return true
	if f > 8000:
		print("  FAIL timed out in phase %d" % phase)
		print("FAILS: %d" % (fails + 1))
		quit()
		return true
	return false
