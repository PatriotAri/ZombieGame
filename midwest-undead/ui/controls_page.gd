extends VBoxContainer
## The Controls page (pause menu and main menu): every action with its keyboard /
## mouse key and its controller button. Most can be changed (Controls.REBINDABLE):
## pick one, then press the new key or button. Changes save right away
## (core/controls.gd). The rest (Controls.FIXED) are listed below them. Emits
## `back` when you press Back.

signal back

const Controls := preload("res://core/controls.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

## Seconds to press something before a change gives up.
const CAPTURE_TIME := 5.0
const FONT_SIZE := 17

var _back_button: Button
var _status: Label
var _buttons := {} # [action, gamepad] -> Button
var _first: Button # top of the list, for focus_first
# The change being made: which action, on which device, and time left to press.
var _capture_action := ""
var _capture_gamepad := false
var _capture_left := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the pause menu shows it while paused
	add_theme_constant_override("separation", 10)
	MenuStyle.add_title(self, "CONTROLS")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 440) # the page fits a 648-pixel-tall window
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # D-pad / arrows down the list keep it in view
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for heading in ["", "Keyboard / mouse", "Controller"]:
		MenuStyle.add_heading(grid, heading)
	for row: Array in Controls.REBINDABLE:
		_add_label(grid, row[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_binding(grid, row[0], false, row[2])
		_add_binding(grid, row[0], true, row[3])
	for row: Array in Controls.FIXED:
		_add_label(grid, row[0]).modulate = Color(1, 1, 1, 0.6) # can't be changed
		_add_fixed(grid, row[1])
		_add_fixed(grid, row[2])
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", FONT_SIZE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(860, 48)
	add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(buttons)
	MenuStyle.add_button(buttons, "Reset to defaults", _reset)
	_back_button = MenuStyle.add_button(buttons, "Back", leave)
	refresh()


func focus_first() -> void:
	_first.grab_focus()


func leave() -> void:
	_stop_capture()
	back.emit()


## Every button's text from what the actions are set to now.
func refresh() -> void:
	for pair: Array in _buttons:
		(_buttons[pair] as Button).text = Controls.binding_text(pair[0], pair[1])
	if _capture_action == "":
		_status.text = _default_status()


func _default_status() -> String:
	var line := "Pick one to change it, then press the new key or button."
	var shared := _first_event("interact", true)
	if shared and InputMap.action_has_event("reload", shared):
		line += "  %s is set to both Interact and Reload: it interacts when you're looking at something you can use, and reloads when you're not." \
				% Controls.event_name(shared)
	return line


## The first controller (gamepad true) or keyboard / mouse input an action is set to, or null.
func _first_event(action: String, gamepad: bool) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) == gamepad:
			return ev
	return null


func _add_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(label)
	return label


## A key or button that can't be changed: dimmed, lined up with the buttons.
func _add_fixed(parent: Control, text: String) -> void:
	var label := _add_label(parent, text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 200
	label.modulate = Color(1, 1, 1, 0.6)


## A cell: a button to change it, or (fixed on that device) just its name.
func _add_binding(parent: Control, action: String, gamepad: bool, changeable: bool) -> void:
	if not changeable:
		_add_fixed(parent, Controls.binding_text(action, gamepad))
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 34)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(_start_capture.bind(action, gamepad))
	parent.add_child(button)
	_buttons[[action, gamepad]] = button
	if _first == null:
		_first = button


func _start_capture(action: String, gamepad: bool) -> void:
	_capture_action = action
	_capture_gamepad = gamepad
	_capture_left = CAPTURE_TIME
	var button: Button = _buttons[[action, gamepad]]
	button.text = "..."
	_status.text = ("Press a controller button or trigger for %s  (Esc or a click cancels)" if gamepad
			else "Press a key or mouse button for %s  (Esc cancels)") % _label_of(action)


func _stop_capture() -> void:
	if _capture_action == "":
		return
	var button: Button = _buttons[[_capture_action, _capture_gamepad]]
	_capture_action = ""
	refresh()
	button.grab_focus()


func _process(delta: float) -> void:
	if _capture_action == "":
		return
	_capture_left -= delta
	if _capture_left <= 0.0:
		_stop_capture()


## While a change is being made, every press is the new binding (or cancels it),
## so nothing else (menus, focus) reacts to it.
func _input(event: InputEvent) -> void:
	if _capture_action == "" or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	var cancel: bool = event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if _capture_gamepad and event is InputEventMouseButton and event.pressed:
		cancel = true
	if cancel:
		_stop_capture()
		return
	var ev := Controls.bindable(event, _capture_gamepad)
	if ev == null:
		return # a release, a stick, the other kind of device: keep waiting
	var action := _capture_action
	var gamepad := _capture_gamepad
	Controls.bind(action, ev)
	_stop_capture()
	var others := Controls.also_on(action, ev)
	if others.is_empty():
		_status.text = "%s: %s" % [_label_of(action), Controls.event_name(ev)]
	elif gamepad and _is_interact_reload(action, others):
		_status.text = "%s is Interact and Reload: it interacts when you're looking at something you can use, and reloads when you're not." \
				% Controls.event_name(ev)
	else:
		_status.text = "%s is also %s: pressing it does both." % [Controls.event_name(ev), ", ".join(others)]


## Interact and Reload sharing one controller button (player.gd sorts out which).
func _is_interact_reload(action: String, others: PackedStringArray) -> bool:
	var other := "reload" if action == "interact" else "interact" if action == "reload" else ""
	return other != "" and others.size() == 1 and others[0] == _label_of(other)


func _label_of(action: String) -> String:
	for row: Array in Controls.REBINDABLE:
		if row[0] == action:
			return row[1]
	return action


func _reset() -> void:
	_stop_capture()
	Controls.reset_to_defaults()
	refresh()
