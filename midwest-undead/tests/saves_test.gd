extends SceneTree
const SaveGame := preload("res://core/save_game.gd")
const SaveList := preload("res://ui/save_list.gd")
var main: Node
var f := 0
var fails := 0
var paths := {}
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
		main.player.global_position = Vector3(10, 0.2, 0)
		paths["a"] = SaveGame.new_path(); main.save_game(paths["a"])
		OS.delay_msec(1100) # saved_at has 1 s resolution
		main.player.global_position = Vector3(20, 0.2, 0)
		paths["b"] = SaveGame.new_path(); main.save_game(paths["b"])
		OS.delay_msec(1100)
		main.player.global_position = Vector3(30, 0.2, 0)
		main.save_game(SaveGame.autosave_path())
		var l := SaveGame.list()
		check(l.size() == 3, "3 saves: " + str(l.map(func(s: Dictionary) -> String: return s["path"].get_file())))
		check(l[0]["autosave"] and l[1]["path"] == paths["b"] and l[2]["path"] == paths["a"], "newest first, autosave marked")
		check(paths["a"] != paths["b"], "new saves get new files")
		print("    title: ", l[1]["title"], " | ", l[1]["detail"].replace("\n", " | "))
		# Overwrite a, delete b.
		OS.delay_msec(1100)
		main.player.global_position = Vector3(40, 0.2, 0)
		main.save_game(paths["a"])
		SaveGame.delete(paths["b"])
		l = SaveGame.list()
		check(l.size() == 2 and l[0]["path"] == paths["a"], "overwrite moves it to the top, delete removes")
		check(SaveGame.latest() == paths["a"], "latest is the overwritten one")
		# The list pages build rows.
		var page := SaveList.new()
		root.add_child(page)
		page.refresh()
		check(page._rows.get_child_count() == 2, "load page shows 2 saves")
		var logbook := SaveList.new(SaveList.Mode.SAVE, "LOGBOOK")
		logbook.save_callback = main.save_game
		root.add_child(logbook)
		logbook.refresh()
		logbook._save_new()
		check(SaveGame.list().size() == 3 and logbook._rows.get_child_count() == 3, "logbook New save adds one")
		var auto_row = logbook._rows.get_children().filter(func(r: Node) -> bool: return (r.get_child(0) as Button).text.begins_with("Autosave"))[0]
		check((auto_row.get_child(0) as Button).disabled, "autosave can't be overwritten from the logbook")
		page.queue_free(); logbook.queue_free()
		# Load the older save "a" (player at x=40) specifically.
		SaveGame.pending_load = SaveGame.read(paths["a"])
		root.remove_child(main); main.free()
		main = load("res://world/main.tscn").instantiate()
		root.add_child(main)
	if f == 15:
		check(absf(main.player.global_position.x - 40.0) < 0.5, "loaded the picked save (player x=%.1f)" % main.player.global_position.x)
		# The menus build with saves present.
		var menu: Node = load("res://ui/main_menu.tscn").instantiate()
		root.add_child(menu)
		var texts = menu._buttons.get_children().filter(func(n: Node) -> bool: return n is Button).map(func(b: Button) -> String: return b.text)
		check("Continue" in texts and "Load game" in texts, "main menu: %s" % [texts])
		menu._show_page(menu._load_page)
		check(menu._load_page._rows.get_child_count() == 3, "main menu load page lists 3")
		var pause: Node = main.get_children().filter(func(n: Node) -> bool: return n.get_script() and n.get_script().resource_path.ends_with("pause_menu.gd"))[0]
		pause.pause()
		pause._show_page(pause._load_page)
		check(not pause._load_button.disabled and pause._load_page._rows.get_child_count() == 3, "pause menu load page lists 3")
		pause._load_page.leave()
		pause.resume()
		menu.queue_free()
		preload("res://tests/support/test_saves.gd").clear()
		print("FAILS: %d" % fails)
		return true
	return false
