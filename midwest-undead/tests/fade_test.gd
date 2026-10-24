extends SceneTree
## Queue D: every scene change fades to black over 1 s, shows "Loading...", then
## cuts straight into the next scene; presses during the fade do nothing.
## Times are game time (frames at the runner's fixed 60 per second), which is
## what the fade's tween runs on: without a window the game runs faster than
## real time.
const SceneFade := preload("res://ui/scene_fade.gd")
const SaveGame := preload("res://core/save_game.gd")
var f := 0
var fails := 0
var t0 := 0 # the frame of the press
var mark := {}

func secs_since_press() -> float:
	return (f - t0) / 60.0

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func fade() -> Node:
	return root.get_node_or_null(SceneFade.NAME)

func _initialize() -> void:
	change_scene_to_file("res://ui/main_menu.tscn")

func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			check(current_scene.scene_file_path == "res://ui/main_menu.tscn", "main menu up")
			current_scene.call("_new_game")
			current_scene.call("_new_game") # a second press
			check(root.get_children().filter(func(n): return n.name.begins_with(SceneFade.NAME)).size() == 1, "one fade, however many presses")
			t0 = f
		35:
			var a: float = fade()._black.color.a
			var secs := secs_since_press()
			check(absf(a - secs) < 0.15 and current_scene.scene_file_path.ends_with("main_menu.tscn"), "%.2f s in: %.2f dark (black in 1 s), still the menu" % [secs, a])
			var ev := InputEventKey.new(); ev.physical_keycode = KEY_ESCAPE; ev.keycode = KEY_ESCAPE; ev.pressed = true
			Input.parse_input_event(ev)
	if f > 35 and not mark.has("game") and current_scene and current_scene.scene_file_path.ends_with("main.tscn"):
		mark["game"] = roundi(secs_since_press() * 1000.0)
		check(mark["game"] >= 950, "the game loads after the fade (%d ms of game time after the press)" % mark["game"])
		check(fade() == null or fade().is_queued_for_deletion(), "...and cuts straight in (the black's gone)")
		mark["at"] = f
		current_scene.get_node("PauseMenu").call("pause") if current_scene.has_node("PauseMenu") else null
		current_scene.player.health = 0.0
	if mark.has("at") and f == mark["at"] + 5:
		check(fade() == null, "fade gone")
		var pm = current_scene.find_children("*", "", true, false).filter(func(n): return n.has_method("_to_main_menu"))
		check(pm.size() == 1, "pause menu found")
		paused = true
		pm[0].call("_to_main_menu")
		check(fade() != null and fade()._loading.visible == false, "back to the main menu: fading (over the paused game)")
	if mark.has("at") and f == mark["at"] + 40:
		check(fade() != null and fade()._black.color.a > 0.2, "fade runs while paused (%.2f)" % fade()._black.color.a)
	if mark.has("at") and f > mark["at"] + 40 and current_scene and current_scene.scene_file_path.ends_with("main_menu.tscn"):
		check(not paused, "unpaused on the main menu")
		print("FAILS: %d" % fails)
		return true
	if f > 3000:
		check(false, "timed out")
		print("FAILS: %d" % fails)
		return true
	return false
