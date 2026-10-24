extends SceneTree
const SaveGame := preload("res://core/save_game.gd")
var main: Node
var p: Node
var f := 0
var fails := 0
var runner: Node3D
var crawler: Node3D
var start_pos: Vector3
func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		var counts := {"walker": 0, "runner": 0, "crawler": 0}
		for z in main.zombies:
			counts[z.kind] += 1
		print("    this town: ", counts, " of ", main.zombies.size())
		# The roll over many zombies.
		var big := {"walker": 0, "runner": 0, "crawler": 0}
		var dice := RandomNumberGenerator.new()
		for i in 20000:
			big[ZombieKind.roll(dice).id] += 1
		check(absf(big["crawler"] / 20000.0 - 0.08) < 0.01 and absf(big["runner"] / 20000.0 - 0.03) < 0.007, "roll gives ~8%% crawlers, ~3%% runners: %s" % [big])
		p = main.player
		for z in main.zombies:
			z.set_physics_process(false); z.global_position = Vector3(500, 0, 500)
		p.global_position = Vector3(-100, 0.1, -50); p.rotation.y = 0.0; p.camera.rotation.x = 0.0
		p.set_physics_process(false)
		runner = main._add_zombie(Vector3(-100, 0.1, -66), null, "runner")
		crawler = main._add_zombie(Vector3(-97, 0.1, -58), null, "crawler")
		check(runner.health == 100.0 and crawler.health == 60.0, "health: runner %d, crawler %d" % [runner.health, crawler.health])
		crawler._animate(false)
		check(runner.visual.scale.x < 0.85 and crawler.body.current == "crawl_idle", "runner thin, crawler lying flat")
	if f == 30:
		for z in [runner, crawler]:
			z.target = p
			z.state = z.State.HUNT
		start_pos = runner.global_position
	if f == 45:
		var v: float = Vector2(runner.velocity.x, runner.velocity.z).length()
		check(runner.state == runner.State.HUNT and absf(v - 7.0) < 0.3, "runner hunting at %.1f" % v)
		check(runner.body.current == "run", "runner running flat out (%s)" % runner.body.current)
	if f == 75: # 0.75 s of chasing
		check(crawler.state == crawler.State.HUNT and crawler.speed == 0.8, "crawler hunting at %.1f" % crawler.speed)
		# A shot at chest height misses a crawler; one aimed at it hits.
		var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
		var high := PhysicsRayQueryParameters3D.create(p.camera.global_position, crawler.global_position + Vector3(0, 1.2, 0) + (crawler.global_position - p.camera.global_position).normalized() * 0.01, 4)
		var high_hit := space.intersect_ray(high)
		var low := PhysicsRayQueryParameters3D.create(p.camera.global_position, crawler.aim_point() + (crawler.aim_point() - p.camera.global_position).normalized() * 2.0, 4)
		var low_hit := space.intersect_ray(low)
		check(high_hit.is_empty() or high_hit["collider"] != crawler, "chest-height shot passes over a crawler")
		check(not low_hit.is_empty() and low_hit["collider"] == crawler, "a shot aimed low hits it")
		crawler.body.animator.advance(0.0); crawler.body._place_head_shape()
		var head: Vector3 = crawler.head_point()
		var ahead: float = (head - crawler.global_position).dot(-crawler.global_basis.z)
		check(crawler.is_headshot(head) and ahead > 0.3 and not crawler.is_headshot(crawler.global_position + Vector3(0, 0.3, 0)), "crawler head is at the front (%.2f m ahead)" % ahead)
		main.save_game(SaveGame.new_path())
		var data := SaveGame.read(SaveGame.latest())
		var kinds: Array = data["zombies"].map(func(z: Dictionary) -> String: return z.get("kind", "?"))
		check("runner" in kinds and "crawler" in kinds, "kinds saved")
		SaveGame.pending_load = data
		root.remove_child(main); main.free()
		main = load("res://world/main.tscn").instantiate()
		root.add_child(main)
	if f == 100:
		var back = main.zombies.map(func(z: Node) -> String: return z.kind)
		check("runner" in back and "crawler" in back, "kinds restored on load")
		print("FAILS: %d" % fails)
		return true
	return false
