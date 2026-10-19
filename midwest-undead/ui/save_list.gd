extends VBoxContainer
## The list of saved games, newest first (core/save_game.gd), as a page:
##   Mode.LOAD (main menu, pause menu): pick a save to load it.
##   Mode.SAVE (the logbook): "New save" adds one, with a name if you give it
##     one; pick a save to overwrite it (asks first; it keeps its name), or
##     Load it. The autosave can't be overwritten by hand.
## Every save can be renamed (but the autosave) and deleted (asks first).
## Emits `back` when you press Back.

signal back

enum Mode { LOAD, SAVE }

const SaveGame := preload("res://core/save_game.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

const ROW_WIDTH := 560.0
const LIST_HEIGHT := 380.0

var mode := Mode.LOAD
## SAVE mode: called with the path to save to; returns true if it saved.
var save_callback := Callable()
var _status: Label
var _rows: VBoxContainer
var _new_button: Button
var _name_row: HBoxContainer # New save: the name box, under the button
var _name_edit: LineEdit
var _back_button: Button


func _init(list_mode := Mode.LOAD, title := "LOAD GAME") -> void:
	mode = list_mode
	add_theme_constant_override("separation", 10)
	MenuStyle.add_title(self, title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", MenuStyle.HEADING_COLOR)
	add_child(_status)
	if mode == Mode.SAVE:
		_new_button = MenuStyle.add_button(self, "New save", _ask_name)
		_name_row = HBoxContainer.new()
		_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_name_row.add_theme_constant_override("separation", 6)
		_name_row.visible = false
		add_child(_name_row)
		_name_edit = _name_box(_name_row, "")
		_name_edit.text_submitted.connect(func(_text: String) -> void: _save_new())
		_small_button(_name_row, "Save", _save_new, 46)
		_small_button(_name_row, "Cancel", _hide_name, 46)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_WIDTH + 20.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # a controller scrolls the list by moving down it
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(back_row)
	_back_button = MenuStyle.add_button(back_row, "Back", leave)


## Fills the list (call when the page is shown).
func refresh(status := "") -> void:
	_status.text = status
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var saves := SaveGame.list()
	if saves.is_empty():
		var none := Label.new()
		none.text = "No saved games yet."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.custom_minimum_size.x = ROW_WIDTH
		_rows.add_child(none)
	for save in saves:
		_rows.add_child(_row(save))


func focus_first() -> void:
	if _new_button:
		_new_button.grab_focus()
		return
	for row in _rows.get_children():
		for child in row.get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).grab_focus()
				return
	_back_button.grab_focus()


## Back (or Esc / B): stops typing a name first, if you are.
func leave() -> void:
	if not cancel_edit():
		back.emit()


## Stops typing a save's name (New save's, or a rename), keeping it as it was.
## False if you weren't.
func cancel_edit() -> bool:
	if _name_row and _name_row.visible:
		_hide_name()
		return true
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and _rows.is_ancestor_of(focused):
		refresh()
		focus_first()
		return true
	return false


## One save: its details on a big button (load it, or overwrite it), plus Load
## (SAVE mode) and Delete.
func _row(save: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var main := Button.new()
	main.text = "%s\n%s" % [save["title"], save["detail"]]
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.custom_minimum_size = Vector2(ROW_WIDTH - 300.0, 76)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_font_size_override("font_size", 16)
	row.add_child(main)
	if mode == Mode.LOAD:
		main.pressed.connect(_load.bind(save["path"]))
	else:
		if save["autosave"]:
			main.disabled = true # the game's own; it overwrites it itself
			main.tooltip_text = "The game saves here by itself."
		else:
			main.pressed.connect(_confirm.bind(row, "Overwrite this save?", _save_over.bind(save["path"], save["name"])))
		_small_button(row, "Load", _load.bind(save["path"]))
	var rename := _small_button(row, "Rename", _rename.bind(row, save))
	if save["autosave"]:
		rename.disabled = true # (and the buttons line up with the other rows')
		rename.tooltip_text = "The game names this one itself."
	_small_button(row, "Delete", _confirm.bind(row, "Delete this save?", _delete.bind(save["path"])))
	return row


func _small_button(row: HBoxContainer, text: String, action: Callable, height := 76.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, height)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	row.add_child(button)
	return button


## Swaps a row for "question  [Yes] [No]".
func _confirm(row: HBoxContainer, question: String, action: Callable) -> void:
	var saved := row.get_children()
	for child in saved:
		child.visible = false
	var label := Label.new()
	label.text = question
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 76
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var yes := _small_button(row, "Yes", action)
	var no := _small_button(row, "No", func() -> void:
		for child in [label, yes]:
			child.queue_free()
		row.get_child(row.get_child_count() - 1).queue_free() # this No button
		for child in saved:
			child.visible = true
		(saved[0] as Button).grab_focus.call_deferred())
	no.grab_focus.call_deferred() # the safe choice under your thumb


## A box to type a save's name in.
func _name_box(row: HBoxContainer, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = "Name (optional)"
	edit.max_length = SaveGame.NAME_LENGTH
	edit.custom_minimum_size = Vector2(ROW_WIDTH - 200.0, 46)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.select_all_on_focus = true
	row.add_child(edit)
	return edit


## Swaps a row for "[its name]  [Save] [Cancel]".
func _rename(row: HBoxContainer, save: Dictionary) -> void:
	var saved := row.get_children()
	for child in saved:
		child.visible = false
	var edit := _name_box(row, save["name"])
	edit.custom_minimum_size.y = 76
	var done := func() -> void:
		refresh("Renamed." if SaveGame.rename(save["path"], edit.text) else "Couldn't rename that save.")
		focus_first()
	edit.text_submitted.connect(func(_text: String) -> void: done.call())
	_small_button(row, "Save", done)
	_small_button(row, "Cancel", func() -> void:
		for child in row.get_children():
			if not child in saved:
				child.queue_free()
		for child in saved:
			child.visible = true
		(saved[0] as Button).grab_focus.call_deferred())
	edit.grab_focus.call_deferred()


## New save: ask for a name first (it's optional).
func _ask_name() -> void:
	_name_edit.text = ""
	_name_row.visible = true
	_name_edit.grab_focus.call_deferred()


func _hide_name() -> void:
	_name_row.visible = false
	_new_button.grab_focus()


func _load(path: String) -> void:
	if not SaveGame.request_load(get_tree(), path):
		refresh("That save can't be loaded.")


func _save_new() -> void:
	var path := SaveGame.new_path()
	var ok: bool = save_callback.call(path)
	if ok and SaveGame.clean_name(_name_edit.text) != "":
		SaveGame.rename(path, _name_edit.text)
	_name_row.visible = false
	refresh("Saved." if ok else "Couldn't save.")
	_new_button.grab_focus()


## Saving over a save keeps the name it had.
func _save_over(path: String, save_name: String) -> void:
	var ok: bool = save_callback.call(path)
	if ok and save_name != "":
		SaveGame.rename(path, save_name)
	refresh("Saved." if ok else "Couldn't save.")
	focus_first()


func _delete(path: String) -> void:
	SaveGame.delete(path)
	refresh("Deleted.")
	focus_first()
