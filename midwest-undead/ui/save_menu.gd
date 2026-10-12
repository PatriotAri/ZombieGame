extends CanvasLayer
## The logbook screen: save your game, or load the last save.
## main.gd supplies the save callback (it knows how to collect the game state).

const SaveGame := preload("res://core/save_game.gd")

var _player: Node
var _save_callback := Callable()
var _info: Label
var _save_button: Button
var _load_button: Button


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


## save_callback: returns true if the game was saved.
func open(player: Node, save_callback: Callable) -> void:
	_player = player
	_save_callback = save_callback
	_player.set("menu_open", true)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_save_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_player.set("menu_open", false)
	if not _player.get("is_dead"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var data := SaveGame.read()
	if data.is_empty():
		_info.text = "No saved game yet."
	else:
		_info.text = "Last save: %s\n%s" % [data.get("clock", "?"), data.get("objective", "")]
	_load_button.disabled = data.is_empty()


func _on_save() -> void:
	if _save_callback.call():
		_refresh()
		_info.text = "Saved.\n" + _info.text


func _on_load() -> void:
	SaveGame.request_load(get_tree())


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "LOGBOOK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(380, 60)
	box.add_child(_info)

	_save_button = _add_button(box, "Save game", _on_save)
	_load_button = _add_button(box, "Load last save", _on_load)
	_add_button(box, "Close", close)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
