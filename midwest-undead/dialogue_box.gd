extends CanvasLayer
## A conversation box along the bottom of the screen: speaker name, one line at a
## time, press to continue. Your controls freeze while it's open (the world keeps
## running). Call start() with the lines and, optionally, what to do when it ends.

const Controls := preload("res://controls.gd")

var _lines: Array[String] = []
var _index := 0
var _on_finished := Callable()
var _player: Node

var _name_label: Label
var _text_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 6 # above the HUD and menus, below the pause menu
	visible = false
	_build_ui()


func is_open() -> bool:
	return visible


## player: the player node (its controls freeze while talking).
## on_finished: called when the last line is dismissed (or the talk is interrupted).
func start(speaker: String, lines: Array[String], player: Node, on_finished := Callable()) -> void:
	if visible or lines.is_empty():
		return
	_lines = lines
	_index = 0
	_on_finished = on_finished
	_player = player
	_player.set("menu_open", true)
	_name_label.text = speaker
	visible = true
	_show_line()


## Ends the conversation early, e.g. if you get attacked mid-sentence. The
## on_finished step still runs, so the story never gets stuck half-way.
func interrupt() -> void:
	if visible:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("use_held"):
		# Handled here so the same press doesn't also make you jump, shoot, or
		# start talking to the NPC again.
		get_viewport().set_input_as_handled()
		_index += 1
		if _index >= _lines.size():
			_finish()
		else:
			_show_line()


func _show_line() -> void:
	_text_label.text = _lines[_index]
	var more := "continue" if _index < _lines.size() - 1 else "close"
	_hint_label.text = "%s: %s   (%d/%d)" % [Controls.hint("continue"), more, _index + 1, _lines.size()]


func _finish() -> void:
	visible = false
	_player.set("menu_open", false)
	var callback := _on_finished
	_on_finished = Callable()
	if callback.is_valid():
		callback.call()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.88)
	style.border_color = Color(0.9, 0.75, 0.35, 0.8)
	style.border_width_top = 2
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.offset_left = -380.0
	panel.offset_right = 380.0
	panel.offset_top = -250.0
	panel.offset_bottom = -110.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(720, 60)
	column.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint_label)
