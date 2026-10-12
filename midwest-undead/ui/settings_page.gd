extends VBoxContainer
## The Settings page (pause menu and main menu): look sensitivity, invert look,
## and volume. Changes apply as you drag; they're written to disk when you leave
## the page. Emits `back` when you press Back (the menu showing it swaps pages).

signal back

const Settings := preload("res://core/settings.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

var _invert_check: CheckButton
var _sliders := {} # setting key -> HSlider, to refresh after "Reset to defaults"


func _init() -> void:
	add_theme_constant_override("separation", 10)
	MenuStyle.add_title(self, "SETTINGS")
	MenuStyle.add_heading(self, "Controls")
	_add_slider("Mouse sensitivity", "mouse_sensitivity", 0.1, 3.0, 0.05, _times)
	_add_slider("Controller sensitivity", "stick_sensitivity", 0.1, 3.0, 0.05, _times)
	_invert_check = CheckButton.new()
	_invert_check.text = "Invert look up/down"
	_invert_check.add_theme_font_size_override("font_size", 18)
	_invert_check.button_pressed = Settings.invert_y
	_invert_check.toggled.connect(func(on: bool) -> void: Settings.set_value("invert_y", on))
	add_child(_invert_check)
	MenuStyle.add_heading(self, "Audio")
	_add_slider("Master volume", "master_volume", 0.0, 1.0, 0.01, _percent)
	_add_slider("Effects volume", "sfx_volume", 0.0, 1.0, 0.01, _percent)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(buttons)
	MenuStyle.add_button(buttons, "Reset to defaults", _reset)
	MenuStyle.add_button(buttons, "Back", leave)


## Called when the page is shown: puts keyboard / controller focus on it.
func focus_first() -> void:
	_sliders["mouse_sensitivity"].grab_focus()


## Leaving the page is when settings get written to disk (not on every slider tick).
func leave() -> void:
	Settings.save_settings()
	back.emit()


func _reset() -> void:
	Settings.reset_to_defaults()
	for key: String in _sliders:
		_sliders[key].value = Settings.get_value(key)
	_invert_check.button_pressed = Settings.invert_y


## One row: name on the left, slider in the middle, current value on the right.
## Arrow keys / D-pad / left stick move a focused slider.
func _add_slider(text: String, key: String, min_value: float, max_value: float, step: float,
		format: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

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
