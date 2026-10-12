extends CanvasLayer
## Esc (or Start on a controller) toggles the pause menu.
## Pausing works by setting get_tree().paused = true, which freezes every node whose
## process_mode is the default (Inherit -> Pausable): the player, zombies, physics, tweens.
## This menu sets its own process_mode to ALWAYS so it keeps running while paused.
## "Settings" swaps the button list for a page of sliders (look sensitivity and
## volume); changes apply as you drag and are saved when you leave the page.

const SaveGame := preload("res://core/save_game.gd")
const Settings := preload("res://core/settings.gd")

var resume_button: Button
var _load_button: Button
var _settings_button: Button
var _main_page: VBoxContainer
var _settings_page: VBoxContainer
var _invert_check: CheckButton
var _sliders := {} # setting key -> HSlider, to refresh after "Reset to defaults"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10 # draw above the HUD (which is on the default layer 1)
	visible = false
	_build_ui()


## Esc / Start opens and closes it. While paused, B (ui_cancel) also resumes.
## Opening uses its own "pause" action rather than ui_cancel, because B is crouch.
func _unhandled_input(event: InputEvent) -> void:
	var paused := get_tree().paused
	if paused and _settings_page.visible and event.is_action_pressed("ui_cancel"):
		_close_settings() # B / Esc on the settings page goes back, not all the way out
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or (paused and event.is_action_pressed("ui_cancel")):
		if paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled() # nothing else should also react to this press


func pause() -> void:
	get_tree().paused = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_button.disabled = not SaveGame.exists()
	resume_button.grab_focus() # so arrow keys / Enter work too


func resume() -> void:
	if _settings_page.visible:
		_close_settings()
	get_tree().paused = false
	visible = false
	# Only grab the mouse again if you're alive and not in the inventory screen;
	# both of those need a free cursor.
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.get("is_dead") and not player.get("menu_open"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _load() -> void:
	SaveGame.request_load(get_tree())


## Starts over from the beginning. Your save file is kept, so you can still load it.
func _restart() -> void:
	get_tree().paused = false # pause state survives a scene reload, so clear it first
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# CenterContainer keeps its child centered at any window size.
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override("separation", 12)
	center.add_child(_main_page)
	_add_title(_main_page, "PAUSED")
	resume_button = _add_button(_main_page, "Resume", resume)
	_load_button = _add_button(_main_page, "Load last save", _load)
	_settings_button = _add_button(_main_page, "Settings", _open_settings)
	_add_button(_main_page, "New game", _restart)
	_add_button(_main_page, "Quit to desktop", _quit)

	_settings_page = VBoxContainer.new()
	_settings_page.add_theme_constant_override("separation", 10)
	_settings_page.visible = false
	center.add_child(_settings_page)
	_add_title(_settings_page, "SETTINGS")
	_add_heading(_settings_page, "Controls")
	_add_slider(_settings_page, "Mouse sensitivity", "mouse_sensitivity", 0.1, 3.0, 0.05, _times)
	_add_slider(_settings_page, "Controller sensitivity", "stick_sensitivity", 0.1, 3.0, 0.05, _times)
	_invert_check = CheckButton.new()
	_invert_check.text = "Invert look up/down"
	_invert_check.add_theme_font_size_override("font_size", 18)
	_invert_check.button_pressed = Settings.invert_y
	_invert_check.toggled.connect(func(on: bool) -> void: Settings.set_value("invert_y", on))
	_settings_page.add_child(_invert_check)
	_add_heading(_settings_page, "Audio")
	_add_slider(_settings_page, "Master volume", "master_volume", 0.0, 1.0, 0.01, _percent)
	_add_slider(_settings_page, "Effects volume", "sfx_volume", 0.0, 1.0, 0.01, _percent)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_page.add_child(buttons)
	_add_button(buttons, "Reset to defaults", _reset_settings)
	_add_button(buttons, "Back", _close_settings)


# --- Settings page -------------------------------------------------------------

func _open_settings() -> void:
	_main_page.visible = false
	_settings_page.visible = true
	_sliders["mouse_sensitivity"].grab_focus()


## Leaving the page is when settings get written to disk (not on every slider tick).
func _close_settings() -> void:
	Settings.save_settings()
	_settings_page.visible = false
	_main_page.visible = true
	_settings_button.grab_focus()


func _reset_settings() -> void:
	Settings.reset_to_defaults()
	for key: String in _sliders:
		_sliders[key].value = Settings.get_value(key)
	_invert_check.button_pressed = Settings.invert_y


## One row: name on the left, slider in the middle, current value on the right.
## Arrow keys / D-pad / left stick move a focused slider.
func _add_slider(parent: Control, text: String, key: String, min_value: float, max_value: float,
		step: float, format: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 220
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(260, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.add_theme_font_size_override("font_size", 18)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_value(key, value)
		value_label.text = format.call(value))
	slider.value = Settings.get_value(key)
	value_label.text = format.call(slider.value) # value_changed doesn't fire if it was already equal
	_sliders[key] = slider


func _times(value: float) -> String:
	return "%.2fx" % value


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _add_title(parent: Control, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	parent.add_child(title)


func _add_heading(parent: Control, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45)) # matches the objective text
	parent.add_child(heading)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
