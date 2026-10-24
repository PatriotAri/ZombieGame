extends SceneTree
## Queue F: weapon slots (primary, sidearm, melee), scroll and 1-3 only
## through them, the backpack for everything else; no quick heal on LB (old
## controls files lose it); no health packs or money on the HUD; the objective
## up for 5 s when it changes.
const Controls := preload("res://core/controls.gd")
const GameData := preload("res://core/game_data.gd")
var main: Node
var p: Node
var f := 0
var fails := 0
var t0 := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	p._unhandled_input(ev)

func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
			print("--- slots")
			check(p.slots == {"primary": "", "sidearm": "pistol", "melee": ""} and p.held == "pistol", "start: the pistol in the sidearm slot, in hand (%s)" % p.slots)
			check(p.weapons() == (["pistol", "hands"] as Array[String]), "weapons: pistol, fists %s" % [p.weapons()])
			p.give_item("shotgun"); p.give_item("rifle"); p.give_item("crowbar"); p.give_item("pickaxe"); p.give_item("health_pack", 2)
			check(p.slots == {"primary": "shotgun", "sidearm": "pistol", "melee": "crowbar"}, "new weapons fill empty slots, not full ones (%s)" % p.slots)
			check(p.weapons() == (["shotgun", "pistol", "crowbar"] as Array[String]), "weapons: primary, sidearm, melee %s" % [p.weapons()])
			p.attack_cooldown = 0.0
			p._cycle(1); var a: String = p.held
			p._cycle(1); var b: String = p.held
			p._cycle(-1); var c: String = p.held
			check(a == "crowbar" and b == "shotgun" and c == "crowbar", "cycling: pistol -> %s -> %s (wraps), back -> %s" % [a, b, c])
			p.select("health_pack")
			p._cycle(1); a = p.held
			p.select("planks")
			p._cycle(-1); b = p.held
			check(a == "shotgun" and b == "crowbar", "from an item: next is the first weapon (%s), previous the last (%s)" % [a, b])
			press("item_next"); a = p.held
			check(a == "shotgun", "the wheel / D-pad (item_next) cycles weapons: crowbar -> %s" % a)
			p._select_slot(2); a = p.held
			p._select_slot(1); b = p.held
			p._select_slot(3); c = p.held
			check(a == "pistol" and b == "shotgun" and c == "crowbar", "1-3: %s, %s, %s" % [b, a, c])
			press("slot_2")
			check(p.held == "pistol", "the 2 key: the sidearm")
			check(not InputMap.has_action("slot_4") or InputMap.action_get_events("slot_4").is_empty(), "4-9 no longer pick items")
			p.equip_weapon("rifle")
			check(p.slots["primary"] == "rifle" and p.weapons()[0] == "rifle", "equip: the rifle in as primary")
			p.equip_weapon("health_pack")
			check(p.slots["primary"] == "rifle", "a health pack isn't a weapon: no slot")
			p.take_item("rifle")
			check(p.slots["primary"] == "shotgun", "the rifle gone: the shotgun fills its slot (%s)" % p.slots)
			p.take_item("pistol")
			check(p.slots["sidearm"] == "" and p.weapons() == (["shotgun", "crowbar"] as Array[String]), "no pistol: no sidearm %s" % [p.weapons()])
			p.take_item("crowbar"); p.take_item("pickaxe")
			check(p.weapons() == (["shotgun", "hands"] as Array[String]), "no melee weapon: fists %s" % [p.weapons()])
			p._select_slot(3)
			check(p.held == "hands", "3 with no melee weapon: fists")
			p._select_slot(2)
			check(p.held == "hands", "2 with no sidearm: nothing happens")
			# Saving.
			p.give_item("pistol"); p.give_item("rifle"); p.give_item("pickaxe")
			p.equip_weapon("rifle")
			var data: Dictionary = p.save_state()
			p.slots = {"primary": "", "sidearm": "", "melee": ""}
			p.load_state(data)
			check(p.slots == {"primary": "rifle", "sidearm": "pistol", "melee": "pickaxe"}, "saved and loaded %s" % p.slots)
			# The backpack.
			print("--- backpack")
			main.backpack_menu.open()
			var bm: Node = main.backpack_menu
			var marked: Array = []
			var texts: Array = []
			for n in bm._list.get_children():
				texts.append(n.text)
				if n is Button and n.icon == bm._mark:
					marked.append(n.text.split("  ")[0])
			check(marked == [GameData.item_name(p.slots["primary"]), "Pistol", "Pickaxe"] and texts.slice(0, 3).all(func(t): return not ("Primary" in t or "Sidearm" in t or "Melee" in t)),
					"the equipped weapons first, each with a square, no slot words: %s" % [texts.slice(0, 4)])
			var other: String = "shotgun" if p.slots["primary"] == "rifle" else "rifle"
			var swap: Button = null
			for n in bm._list.get_children():
				if n is Button and n.text.begins_with(GameData.item_name(other)) and n.icon == bm._no_mark:
					swap = n
			check(swap != null, "the other primary: listed without a square")
			if swap:
				swap.pressed.emit()
			check(p.slots["primary"] == other and p.held == other and not main.backpack_menu.visible, "swapped in, in hand, the screen closed (%s)" % p.slots["primary"])
			main.backpack_menu.open()
			var heal: Button = null
			for n in main.backpack_menu._list.get_children():
				if n is Button and n.text.strip_edges().begins_with("Health pack"):
					heal = n
			if heal:
				heal.pressed.emit()
			check(heal != null and p.held == "health_pack", "items: held from the backpack")
			# LB.
			print("--- controls")
			var pads := InputMap.action_get_events("use_health_pack").filter(func(e): return e is InputEventJoypadButton)
			check(pads.is_empty(), "quick heal: nothing on the controller")
			var keys := InputMap.action_get_events("use_health_pack").filter(func(e): return e is InputEventKey)
			check(keys.size() == 1, "...still Q")
			var backup := FileAccess.get_file_as_string(Controls.PATH) if FileAccess.file_exists(Controls.PATH) else ""
			var old := ConfigFile.new()
			old.set_value("controller", "use_health_pack", [{"button": int(JOY_BUTTON_LEFT_SHOULDER)}])
			old.set_value("controller", "jump", [{"button": int(JOY_BUTTON_Y)}])
			old.save(Controls.PATH)
			Controls.setup()
			var lb := InputMap.action_get_events("use_health_pack").filter(func(e): return e is InputEventJoypadButton)
			var jump := InputMap.action_get_events("jump").filter(func(e): return e is InputEventJoypadButton)
			check(lb.is_empty() and jump.size() == 1 and jump[0].button_index == JOY_BUTTON_Y, "an old controls file: LB dropped from quick heal, the rest kept")
			Controls.bind("use_health_pack", lb_event())
			Controls.setup()
			lb = InputMap.action_get_events("use_health_pack").filter(func(e): return e is InputEventJoypadButton)
			check(lb.size() == 1, "put back on purpose (a new file): kept")
			Controls.reset_to_defaults()
			if backup != "":
				var w := FileAccess.open(Controls.PATH, FileAccess.WRITE); w.store_string(backup); w.close()
				Controls.setup()
			# The HUD.
			print("--- HUD")
			var hud: Node = main.hud
			p.money = 123
			main.backpack_menu.close()
		7:
			var hud: Node = main.hud
			var txt: String = hud.status_label.text
			check(not "Health packs" in txt and not "$" in txt and not "Hunger" in txt and txt.begins_with("Health"), "no health packs, money or hunger: %s" % txt.replace("\n", " | "))
			check(not "hunger" in p.save_state() and p.get("hunger") == null, "no hunger anywhere (player, saves)")
			p.health = 50.0
			p.give_item("canned_food")
			p.select("canned_food")
			p.attack_cooldown = 0.0
			p._use_held()
			p._finish_use()
			check(is_equal_approx(p.health, 50.0 + p.food_heal), "a can of food still heals a little (%.0f)" % p.health)
			hud.set_objective("Find the test")
			t0 = f
			check(hud.objective_label.modulate.a == 1.0 and hud.objective_label.text.ends_with("Find the test"), "a new objective shows")
		_:
			if t0 > 0:
				var hud: Node = main.hud
				var secs := (f - t0) / 60.0
				if f == t0 + 240:
					check(hud.objective_label.modulate.a == 1.0, "4 s on: still up")
					hud.set_objective("Find the test") # the same again (an announce)
				if f == t0 + 360:
					check(hud.objective_label.modulate.a < 0.05, "6 s on: gone (the same one again didn't bring it back) (%.2f)" % hud.objective_label.modulate.a)
					hud.set_objective("Something new")
				if f == t0 + 380:
					check(hud.objective_label.modulate.a == 1.0, "a changed objective: up again")
					print("FAILS: %d" % fails)
					quit()
	return false

func lb_event() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_LEFT_SHOULDER
	return e
