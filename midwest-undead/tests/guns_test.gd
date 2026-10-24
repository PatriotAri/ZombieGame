extends SceneTree
## Guns: a shotgun reloads shell by shell and hits hard up close; the rifle
## scopes (its model hidden) and kills with one body shot; the pistol zooms a
## little; loaded rounds are saved and come back out when you give a gun up;
## the wagon trader sells both guns and their ammo, the guns back only now and
## then; survivors on ammo benches fill the morning crate. On a test map with
## the station camp and three survivors (tests/support/test_map.gd).
const SaveGame := preload("res://core/save_game.gd")
const Recipes := preload("res://core/recipes.gd")
const TestMap := preload("res://tests/support/test_map.gd")
const PEOPLE := ["Dale Hutchins", "Gus Lindqvist", "Marisol Vega"]
var main: Node
var p: Node
var f := 0
var fails := 0
var z: Node3D
func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map := TestMap.begin()
	TestMap.base_camp(map, Vector3(0, 0, 20))
	for i in PEOPLE.size():
		TestMap.spawn_point(map, "survivor", Vector3(-60 - i * 4.0, 0, -60), PEOPLE[i])
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)
func _zombie_ahead(dist: float) -> Node3D:
	# Freeze every zombie far away, put one right in front of the player.
	for zz in main.zombies:
		zz.set_physics_process(false); zz.global_position = Vector3(500, 0, 500)
	var one: Node3D = main._add_zombie(p.global_position - p.global_basis.z * dist, null, "walker")
	one.set_physics_process(false)
	return one
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		p = main.player
		p.global_position = Vector3(0, 0.1, -60); p.rotation.y = 0.0; p.camera.rotation.x = 0.0
		p.give_item("shotgun"); p.give_item("shotgun_shells", 10)
		p.give_item("rifle"); p.give_item("rifle_rounds", 6)
		check(p.holdable().has("shotgun") and p.holdable().has("rifle"), "guns can be held")
		p.select("shotgun")
		check(p.mags["shotgun"] == 0, "a new shotgun comes empty")
		p._start_reload()
	if f == 5 + int(60 * 2.8):
		check(p.mags["shotgun"] == 5 and p.inventory.count("shotgun_shells") == 5, "shotgun reloaded: %d in, %d left" % [p.mags["shotgun"], p.inventory.count("shotgun_shells")])
		z = _zombie_ahead(4.0)
		p.camera.look_at(z.global_position + Vector3(0, 1.0, 0))
	if f == 10 + int(60 * 2.8):
		p.attack_cooldown = 0.0
		var hp: float = z.health
		p._try_shoot()
		check(z.health < hp - 60.0 or z.is_dead, "shotgun at 4 m: %.0f -> %.0f damage (%s)" % [hp, z.health, "dead" if z.is_dead else "alive"])
		check(p.mags["shotgun"] == 4, "used one shell")
		# Rifle: one body shot kills.
		p.select("rifle")
		p.mags["rifle"] = 5
		z = _zombie_ahead(40.0)
	if f == 20 + int(60 * 2.8):
		p.camera.look_at(z.global_position + Vector3(0, 1.0, 0))
		Input.action_press("aim")
	if f == 60 + int(60 * 2.8):
		check(p.aiming and p.camera.fov < 25.0 and p.is_scoped(), "rifle scope: fov %.1f, scoped %s" % [p.camera.fov, p.is_scoped()])
		check(not p.hands.models["rifle"].visible, "rifle model hidden while scoped")
		p.camera.look_at(z.global_position + Vector3(0, 1.0, 0))
		p.attack_cooldown = 0.0
		p._try_shoot()
		check(z.is_dead, "rifle one body shot at 40 m kills (health %.0f)" % z.health)
		Input.action_release("aim")
		p.select("pistol")
		Input.action_press("aim")
	if f == 100 + int(60 * 2.8):
		check(p.camera.fov > 55.0 and p.camera.fov < 65.0 and not p.is_scoped(), "pistol aims with a small zoom (fov %.1f)" % p.camera.fov)
		Input.action_release("aim")
		# Save and load keep loaded rounds.
		p.select("shotgun")
		main.save_game(SaveGame.new_path())
		var data := SaveGame.read(SaveGame.latest())
		check(data["player"]["mags"]["shotgun"] == 4 and data["player"]["mags"]["rifle"] == 4, "mags saved %s" % data["player"]["mags"])
		# Selling a loaded gun keeps the rounds.
		var shells_before: int = p.inventory.count("shotgun_shells")
		p.take_item("shotgun")
		check(p.inventory.count("shotgun_shells") == shells_before + 4 and p.mags["shotgun"] == 0, "giving up the shotgun unloads it")
		# The wagon trader.
		var t: Node = load("res://characters/npcs/wagon_trader.tscn").instantiate()
		t.position = Vector3(10, 0.1, 10)
		t.day_night = main.day_night # (restock goes by the day)
		main.add_child(t)
		check(t.stock.count("shotgun") == 1 and t.stock.count("rifle") == 1 and t.stock.count("shotgun_shells") == 15 \
				and t.stock.count("rifle_rounds") == 8, "wagon trader has both guns and their ammo")
		check(t.buy_price("shotgun") > 0 and t.buy_price("rifle") > 0, "priced: shotgun $%d, rifle $%d" % [t.buy_price("shotgun"), t.buy_price("rifle")])
		t.stock.remove("shotgun"); t.stock.remove("rifle")
		var back := 0
		for day in 40:
			t.restock()
			if t.stock.count("shotgun") > 0:
				back += 1
				t.stock.remove("shotgun")
		check(back > 3 and back < 20, "shotgun came back on %d of 40 mornings (25%% chance)" % back)
		# Benches.
		var ids := Recipes.MACHINIST.map(func(r: Dictionary) -> String: return r["id"])
		check("shell_bench" in ids and "rifle_bench" in ids, "machinist makes %s" % [ids])
		var st: Node = main.structures
		var camps: Node = main.camps
		var sv: Node = main.survivors
		var kinds := ["ammo_bench", "shell_bench", "rifle_bench"]
		check(sv.survivors.size() == 3, "three survivors to put to work")
		for i in 3:
			st.build(kinds[i], Transform3D(Basis.IDENTITY, camps.station.center + Vector3(6 + i * 3.0, 0, 6)), null, true)
			sv._send_to(sv.survivors[i], camps.station)
			sv._send_home(i) # (there already: no walk)
			check(camps.assign(sv.survivors[i], kinds[i]), "survivor on the %s" % kinds[i])
		var crate_inv: RefCounted = camps.station.crate.inventory
		var before := [crate_inv.count("pistol_ammo"), crate_inv.count("shotgun_shells"), crate_inv.count("rifle_rounds")]
		main.day_night.day += 1; main.day_night.hour = 8.0
		camps._resupply()
		var got := [crate_inv.count("pistol_ammo") - before[0], crate_inv.count("shotgun_shells") - before[1], crate_inv.count("rifle_rounds") - before[2]]
		check(got == [10, 4, 2], "morning output pistol/shells/rifle: %s" % [got])
		print("FAILS: %d" % fails)
		return true
	return false
