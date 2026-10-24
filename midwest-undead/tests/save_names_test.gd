extends SceneTree
## Naming saves: the name box on New save (typing in it doesn't open other
## screens), overwriting keeps the name, Rename on every save but the
## autosave (in the logbook and on Load pages), Esc stops typing first.
const SaveGame := preload("res://core/save_game.gd")
const SaveList := preload("res://ui/save_list.gd")
var main: Node
var f := 0
var fails := 0
var made: Array[String] = []
var lst: Node
var before := 0.0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func key(code: Key, ch: String) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch.unicode_at(0) if down else 0
		ev.pressed = down
		Input.parse_input_event(ev)

func first_save() -> Dictionary:
	var saves := SaveGame.list()
	return saves[0] if not saves.is_empty() else {}

func row_button(row: Node, text: String) -> Button:
	for c in row.get_children():
		if c is Button and c.text == text and c.visible:
			return c
	return null

func row_of(path: String) -> Node:
	var i := SaveGame.list().map(func(s): return s["path"]).find(path)
	return lst._rows.get_child(i) if i >= 0 else null

func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
			main.save_menu.open(main.player, main._save_game)
			lst = main.save_menu._list
			lst._new_button.pressed.emit()
		7:
			check(lst._name_row.visible and get_root().gui_get_focus_owner() == lst._name_edit, "New save: a name box, ready to type in")
			key(KEY_J, "j"); key(KEY_M, "m")
		9:
			check(lst._name_edit.text == "jm" and not main.journal_menu.visible and not main.map_menu.visible,
					"typing J and M goes in the name, not to the journal or the map (\"%s\")" % lst._name_edit.text)
			lst._name_edit.text = "  My Base  "
			lst._name_edit.text_submitted.emit(lst._name_edit.text)
			var s := first_save()
			made.append(s.get("path", ""))
			check(s.get("name", "") == "My Base" and s["title"] == "My Base" and "Day " in s["detail"] and not lst._name_row.visible,
					"saved with its name (title \"%s\"; detail \"%s\")" % [s.get("title"), str(s.get("detail")).replace("\n", " | ")])
			# Overwriting keeps the name.
			lst._save_over(made[0], s["name"])
			check(first_save().get("name") == "My Base", "saved over: the name stays")
			# Rename it.
			before = first_save()["saved_unix"]
			row_button(row_of(made[0]), "Rename").pressed.emit()
		11:
			var edit: LineEdit = get_root().gui_get_focus_owner() as LineEdit
			check(edit != null and edit.text == "My Base", "Rename: a box with its name in it")
			if edit:
				edit.text = "Night two\nat the barn"
				edit.text_submitted.emit(edit.text)
			var s := first_save()
			check(s.get("name") == "Night two at the barn", "renamed (one line): %s" % s.get("name"))
			check(before > 0.0 and is_equal_approx(float(SaveGame.read(made[0])["saved_unix"]), before), "renaming doesn't change when it was saved")
			# Esc while renaming: stops renaming, the logbook stays open.
			row_button(row_of(made[0]), "Rename").pressed.emit()
		13:
			var edit: LineEdit = get_root().gui_get_focus_owner() as LineEdit
			if edit:
				edit.text = "should not stick"
			var esc := InputEventAction.new(); esc.action = "ui_cancel"; esc.pressed = true
			main.save_menu._unhandled_input(esc)
			check(main.save_menu.visible and first_save().get("name") == "Night two at the barn", "Esc while renaming: renaming stops, the logbook stays, the name's unchanged")
			main.save_menu._unhandled_input(esc)
			check(not main.save_menu.visible, "Esc again: the logbook closes")
			# No name, and a long one.
			main.save_menu.open(main.player, main._save_game)
			lst._new_button.pressed.emit()
			lst._name_edit.text = ""
			lst._save_new()
			var s := first_save()
			made.append(s["path"])
			check(s["name"] == "" and s["title"].begins_with("Day "), "no name: the day and time as before (%s)" % s["title"])
			check(SaveGame.rename(s["path"], "x".repeat(80)) and SaveGame.read(s["path"])["name"].length() == SaveGame.NAME_LENGTH, "names are cut to %d characters" % SaveGame.NAME_LENGTH)
			check(SaveGame.rename(s["path"], "   ") and not SaveGame.read(s["path"]).has("name"), "a blank name takes the name away")
			# The autosave.
			main._save_game(SaveGame.autosave_path())
			check(not SaveGame.rename(SaveGame.autosave_path(), "mine"), "the autosave can't be renamed")
			lst.refresh()
			var auto_row: Node = row_of(SaveGame.autosave_path())
			check(auto_row != null and row_button(auto_row, "Rename") != null and row_button(auto_row, "Rename").disabled, "...its Rename button is greyed out")
			# A Load page (main menu, pause menu) has Rename too.
			var page := SaveList.new()
			root.add_child(page)
			page.refresh()
			var renames := 0
			for row in page._rows.get_children():
				for c in row.get_children():
					if c is Button and c.text == "Rename" and not c.disabled: renames += 1
			check(renames == SaveGame.list().filter(func(s): return not s["autosave"]).size() and renames >= 2, "Load page: Rename on each save but the autosave (%d)" % renames)
			page.queue_free()
			main.save_menu.close()
			for path in made: SaveGame.delete(path)
			print("FAILS: %d" % fails)
			quit()
	return false
