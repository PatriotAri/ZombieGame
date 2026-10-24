extends SceneTree
## Queue C: controller defaults (X reload + interact, Y map, View inventory, RB
## free), rebinding on the Controls page (capture, cancel, save, load, reset),
## the sensitivity settings (mouse, stick X / Y, while aiming, inverts), and X
## reloading when there's nothing to interact with.
const Controls := preload("res://core/controls.gd")
const Settings := preload("res://core/settings.gd")
const ControlsPage := preload("res://ui/controls_page.gd")
const GroundItem := preload("res://items/ground_item.gd")
var main: Node
var p: Node
var page: Node
var f := 0
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func pad(button: JoyButton, down := true) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new(); ev.button_index = button; ev.pressed = down
	return ev

func key(code: Key, down := true) -> InputEventKey:
	var ev := InputEventKey.new(); ev.physical_keycode = code; ev.keycode = code; ev.pressed = down
	return ev

func _initialize() -> void:
	Controls.reset_to_defaults()
	Settings.reset_to_defaults()
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		5:
			p = main.player
			p.set_physics_process(false)
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			check(Controls.binding_text("reload", true) == "X" and Controls.binding_text("interact", true) == "X", "X: reload and interact")
			check(Controls.binding_text("map", true) == "Y" and Controls.binding_text("inventory", true) == "View", "Y: map, View: inventory")
			check(Controls.also_on("menu_stack", pad(JOY_BUTTON_RIGHT_SHOULDER)).is_empty(), "RB does nothing in play (just menu_stack)")
			check(Controls.binding_text("reload", false) == "R" and Controls.binding_text("map", false) == "M" and Controls.binding_text("inventory", false) == "Tab", "keyboard unchanged: R, M, Tab")
			# X: nothing in front of you, a pistol with rounds out: reloads.
			p.select("pistol"); p.give_item("pistol_ammo", 30); p.mags["pistol"] = 2
			p.camera.rotation.x = deg_to_rad(80) # at the sky
			p._unhandled_input(pad(JOY_BUTTON_X))
			check(p.reload_timer > 0.0, "X looking at nothing: reloads")
			p.reload_timer = 0.0; p.hands.cancel_reload()
			# X looking at an item on the ground: picks it up, doesn't reload.
			p.camera.rotation.x = deg_to_rad(-60)
			var ahead: Vector3 = p.camera.global_position - p.camera.global_basis.z * 1.5
			main.add_ground_item("canned_food", 1, ahead - Vector3(0, 0.2, 0), 0.0)
		8:
			var before: int = p.inventory.count("canned_food")
			check(p._looked_at() is GroundItem, "looking at a can on the ground")
			p._unhandled_input(pad(JOY_BUTTON_X))
			check(p.inventory.count("canned_food") == before + 1 and p.reload_timer <= 0.0, "X at the can: picks it up, no reload")
			p._unhandled_input(key(KEY_R))
			check(p.reload_timer > 0.0, "R still reloads")
			p.reload_timer = 0.0; p.hands.cancel_reload()
			# Look: mouse, stick X / Y, aiming, inverts.
			Settings.set_value("mouse_sensitivity", 2.0)
			var pitch: float = p.camera.rotation.x
			var yaw: float = p.rotation.y
			p._look(Vector2(0.01, 0.01), Settings.invert_mouse_y)
			check(is_equal_approx(p.rotation.y, yaw - 0.01), "look turns you")
			var down: float = p.camera.rotation.x - pitch
			Settings.set_value("invert_mouse_y", true)
			pitch = p.camera.rotation.x
			p._look(Vector2(0, 0.01), Settings.invert_mouse_y)
			check(signf(p.camera.rotation.x - pitch) == -signf(down), "invert mouse flips up/down")
			pitch = p.camera.rotation.x
			p._look(Vector2(0, 0.01), Settings.invert_stick_y)
			check(signf(p.camera.rotation.x - pitch) == signf(down), "...and not the stick's")
			Settings.set_value("aim_sensitivity", 0.5)
			p.aiming = true
			yaw = p.rotation.y
			p._look(Vector2(0.02, 0), false)
			check(is_equal_approx(p.rotation.y, yaw - 0.01), "while aiming: x0.5")
			p.aiming = false
			Settings.save_settings()
			Settings.set_value("stick_sensitivity_y", 2.5); Settings.set_value("stick_sensitivity_x", 0.4)
			Settings.save_settings()
			Settings.reset_to_defaults(); Settings.load_settings()
			check(Settings.stick_sensitivity_x == 0.4 and Settings.stick_sensitivity_y == 2.5 and Settings.aim_sensitivity == 0.5 \
					and Settings.invert_mouse_y and not Settings.invert_stick_y, "settings saved and loaded")
			# The Controls page.
			page = ControlsPage.new()
			root.add_child(page)
			check(page._buttons.size() == 34, "the page: a button for each changeable one (%d)" % page._buttons.size())
			check("both Interact and Reload" in page._status.text, "it says X does both")
			page._start_capture("jump", true)
			Input.parse_input_event(pad(JOY_BUTTON_Y))
		10:
			check(Controls.binding_text("jump", true) == "Y" and Controls.binding_text("jump", false) == "Space", "jump on Y (Space kept)")
			check("Map" in page._status.text, "...and it says Y is the map too: \"%s\"" % page._status.text)
			page._start_capture("reload", false)
			Input.parse_input_event(key(KEY_ESCAPE))
		12:
			check(Controls.binding_text("reload", false) == "R" and page._capture_action == "", "Esc cancels")
			page._start_capture("reload", false)
			Input.parse_input_event(pad(JOY_BUTTON_A)) # a controller button for a keyboard slot: ignored
			Input.parse_input_event(key(KEY_G))
		14:
			check(Controls.binding_text("reload", false) == "G", "reload on G")
			page._start_capture("aim", true)
			var lt := InputEventJoypadMotion.new(); lt.axis = JOY_AXIS_TRIGGER_RIGHT; lt.axis_value = 0.9
			Input.parse_input_event(lt)
		16:
			check(Controls.binding_text("aim", true) == "RT", "aim on RT (a trigger)")
			page._start_capture("interact", true)
			page._capture_left = 0.01
		18:
			check(page._capture_action == "" and Controls.binding_text("interact", true) == "X", "nothing pressed: gives up")
			# Saved: back to defaults in memory, then load the file.
			for row: Array in Controls.REBINDABLE: InputMap.action_erase_events(row[0])
			Controls.setup()
			check(Controls.binding_text("reload", false) == "G" and Controls.binding_text("jump", true) == "Y" and Controls.binding_text("aim", true) == "RT",
					"loaded from the file: G, Y, RT")
			check(Controls.hint("reload") in ["G", "X"], "hints follow")
			page._reset()
			check(Controls.binding_text("reload", false) == "R" and Controls.binding_text("jump", true) == "A" and Controls.binding_text("aim", true) == "LT"
					and not FileAccess.file_exists(Controls.PATH), "reset: defaults, file gone")
			Settings.reset_to_defaults(); Settings.save_settings()
			print("FAILS: %d" % fails)
			return true
	return false
