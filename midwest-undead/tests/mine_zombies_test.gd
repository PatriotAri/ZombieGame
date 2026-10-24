extends SceneTree
## Mines phase 5 in the game: zombies at a marker in the mine and from its
## Zombie Density, on its open floor (not in rock or the daylight), miners among
## them and none up top; a miner's hard hat stops the first headshot; zombies,
## you and a lantern set down are drawn on the underground layer down there.
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const GameData := preload("res://core/game_data.gd")
var main: Node
var f := 0
var fails := 0
var mine: KitMine
var p: Node
var phase := 0
var t0 := 0
var miner: Node

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
	var t1 := MineTunnel.make(pts([Vector3i(0, 0, 0), Vector3i(0, 0, -12)]))
	t1.entrance_at_start = true
	mine.tunnels = [t1]
	mine.chambers = [MineChamber.make(Vector3i(1, 0, -12), Vector3i(4, 0, -9), 5.0)]
	mine.zombie_density = 6.0
	var marker := KitZombieSpawn.new()
	marker.name = "Zombies"
	marker.count = 5
	marker.spread = Vector2(5, 5)
	marker.position = KitMine.cell_position(Vector3i(2, 0, -10)) + Vector3(0, 0.1, 0)
	mine.add_child(marker)
	mine.position = Vector3(0, 0, -40)
	mine.rotation.y = PI / 2.0 # its mouth facing away from where you start (zombies you'd see are moved)
	map_root.add_child(mine)
	mine.owner = map_root
	marker.owner = map_root
	var packed := PackedScene.new()
	packed.pack(map_root)
	map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = main.player
		p.health = 1e6
		mine = main.town.get_node("TestMine")
		var inside: Array = main.zombies.filter(func(z: Node) -> bool: return mine.inside(z.global_position + Vector3.UP))
		var expect: int = mine.zombie_count() + 5
		check(inside.size() == expect, "%d zombies in the mine (%d from its density, 5 at the marker)" % [inside.size(), mine.zombie_count()])
		var lit: Array = inside.filter(func(z: Node) -> bool: return mine.to_local(z.global_position).z > -2.0 * KitMine.CELL + 1.25)
		for z in main.zombies:
			if z.kind == "miner" and not mine.inside(z.global_position + Vector3.UP):
				print("    miner outside at local ", mine.to_local(z.global_position))
		check(lit.is_empty(), "none in the daylight by the entrance")
		var near_marker: int = inside.filter(func(z: Node) -> bool: return KitMine.cell_at(mine.to_local(z.global_position), 0).x >= 1).size()
		check(near_marker >= 5, "the marker's are in the chamber round it (%d there)" % near_marker)
		var miners: Array = inside.filter(func(z: Node) -> bool: return z.kind == "miner")
		check(miners.size() >= 1, "%d of them miners" % miners.size())
		for z in main.zombies:
			if z.kind == "miner":
				print("    miner at local ", mine.to_local(z.global_position), " inside ", mine.inside(z.global_position + Vector3.UP))
		var up_top: Array = main.zombies.filter(func(z: Node) -> bool: return not mine.inside(z.global_position + Vector3.UP))
		check(up_top.size() > 0 and up_top.all(func(z: Node) -> bool: return z.kind != "miner"), "no miners up top (%d zombies there)" % up_top.size())
		for z in main.zombies: z.set_physics_process(false)
		for z in inside: z.set_physics_process(true)
		miner = miners[0] if miners.size() else null
		phase = 1
		t0 = f
	if phase == 1 and f == t0 + 60:
		for z in main.zombies: z.set_physics_process(false)
		var standing: bool = main.zombies.filter(func(z: Node) -> bool: return mine.inside(z.global_position + Vector3.UP)).all(func(z: Node) -> bool: return z.is_on_floor())
		check(standing, "they stand on the mine's floor (none fell through or stuck in rock)")
		if miner:
			check(miner._hat != null and miner._hat.find_children("*", "SpotLight3D", true, false).size() == 1, "a miner wears a hard hat with a lamp on it")
			check(miner._meshes.size() > 0 and miner._meshes.all(func(m: GeometryInstance3D) -> bool: return m.layers == GameData.RENDER_UNDERGROUND), "drawn on the underground layer down there")
			var health0: float = miner.health
			miner.take_hit(50.0, p.global_position, 0.0, p, miner.head_shape.global_position)
			check(is_equal_approx(miner.health, health0) and miner._hat == null, "the first headshot only knocks the hat off (%.0f health)" % miner.health)
			miner.take_hit(50.0, p.global_position, 0.0, p, miner.head_shape.global_position)
			check(miner.health < health0, "the next one hurts (%.0f)" % miner.health)
		# You, down there; and a lantern set down there.
		p.global_position = mine.to_global(KitMine.cell_position(Vector3i(0, 0, -6))) + Vector3(0, 0.1, 0)
		var lantern: Node = main.structures.build("lantern", Transform3D(Basis.IDENTITY, mine.to_global(KitMine.cell_position(Vector3i(0, 0, -7)))), null, true)
		check(lantern.find_children("*", "GeometryInstance3D", true, false).all(func(m: GeometryInstance3D) -> bool: return m.layers == GameData.RENDER_UNDERGROUND), "a lantern set down in the mine is drawn on its layer")
		phase = 2
		t0 = f
	if phase == 2 and f == t0 + 30:
		var hands: Array = p.find_children("*", "GeometryInstance3D", true, false)
		check(hands.size() > 0 and hands.all(func(m: GeometryInstance3D) -> bool: return m.layers == GameData.RENDER_UNDERGROUND), "your hands too, down there (%d meshes)" % hands.size())
		p.global_position = Vector3(10, 0.2, -20)
	if phase == 2 and f == t0 + 60:
		var hands: Array = p.find_children("*", "GeometryInstance3D", true, false)
		check(hands.all(func(m: GeometryInstance3D) -> bool: return m.layers == 1), "and back to the ordinary layer up top")
		print("FAILS: %d" % fails)
		quit()
		return true
	return false
