extends CanvasLayer
## A short list of choices from someone you're talking to, e.g. giving a
## survivor a job. open() takes the speaker, a line, and [text, callable,
## enabled] options; picking one closes the menu and calls it. Esc closes it
## without choosing (so does dying).

const Player := preload("res://characters/player/player.gd")

var player: Player
var _title: Label
var _line: Label
var _list: VBoxContainer


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


func open(p: Player, speaker: String, line: String, options: Array) -> void:
	if p.menu_open or p.is_dead:
		return
	player = p
	_title.text = speaker
	_line.text = line
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var first: Button = null
	for option: Array in options:
		var button := Button.new()
		button.text = option[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(380, 38)
		button.disabled = option.size() > 2 and not option[2]
		button.pressed.connect(_pick.bind(option[1]))
		_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	player.menu_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first:
		(func() -> void:
			if is_instance_valid(first) and first.is_inside_tree():
				first.grab_focus()).call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	player.menu_open = false
	if not player.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pick(action: Callable) -> void:
	close()
	if action.is_valid():
		action.call()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	outer.add_child(_title)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 380
	outer.add_child(_line)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	outer.add_child(_list)
