extends Control
## The title screen, the first thing you see (the project's main scene):
## Continue (your last save, if there is one), New game, Settings, Controls, Quit.
## Settings and Controls are the same pages as in the pause menu.
## Behind it: a dusk sky over the town's silhouette, drawn in code.

const Controls := preload("res://core/controls.gd")
const Settings := preload("res://core/settings.gd")
const SaveGame := preload("res://core/save_game.gd")
const MenuStyle := preload("res://ui/menu_style.gd")
const SettingsPage := preload("res://ui/settings_page.gd")
const ControlsPage := preload("res://ui/controls_page.gd")

const SKY_TOP := Color(0.07, 0.08, 0.12)
const SKY_HORIZON := Color(0.42, 0.24, 0.16)
const SKYLINE := Color(0.04, 0.04, 0.05)

var _buttons: VBoxContainer
var _settings_page: SettingsPage
var _controls_page: ControlsPage
var _page_buttons := {} # page -> the button that opened it
var _skyline: Control


func _ready() -> void:
	Controls.setup()
	Settings.load_settings()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	for page: Control in [_settings_page, _controls_page]:
		if page.visible and event.is_action_pressed("ui_cancel"):
			page.call("leave")
			get_viewport().set_input_as_handled()
			return


## main.gd shows whichever device you last touched; do the same here so the
## Controls page and the game start out right.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		Controls.using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		Controls.using_gamepad = false


func _continue() -> void:
	SaveGame.request_load(get_tree())


func _new_game() -> void:
	SaveGame.pending_load = {}
	get_tree().change_scene_to_file(SaveGame.GAME_SCENE)


func _quit() -> void:
	get_tree().quit()


func _show_page(page: Control) -> void:
	_buttons.visible = false
	page.visible = true
	page.call("focus_first")


func _show_buttons(from_page: Control) -> void:
	from_page.visible = false
	_buttons.visible = true
	(_page_buttons[from_page] as Button).grab_focus()


func _build_ui() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_HORIZON)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_skyline = Control.new()
	_skyline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skyline)
	_skyline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skyline.draw.connect(_draw_skyline)
	_skyline.resized.connect(_skyline.queue_redraw)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	column.add_child(_buttons)
	var title := MenuStyle.add_title(_buttons, "MIDWEST UNDEAD", 64)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	var tagline := Label.new()
	tagline.text = "A couple of months into the outbreak."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_buttons.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	_buttons.add_child(spacer)

	var first: Button
	var save := SaveGame.read()
	if not save.is_empty():
		first = MenuStyle.add_button(_buttons, "Continue", _continue)
		var info := Label.new()
		info.text = "%s  ·  %s" % [save.get("clock", ""), save.get("objective", "")]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = 240
		info.add_theme_font_size_override("font_size", 14)
		info.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_buttons.add_child(info)
	var new_game := MenuStyle.add_button(_buttons, "New game", _new_game)
	if first == null:
		first = new_game
	var settings_button := MenuStyle.add_button(_buttons, "Settings", func() -> void: _show_page(_settings_page))
	var controls_button := MenuStyle.add_button(_buttons, "Controls", func() -> void: _show_page(_controls_page))
	MenuStyle.add_button(_buttons, "Quit", _quit)
	for button in _buttons.get_children():
		if button is Button: # narrower than the title, centered under it
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.custom_minimum_size.x = 320

	_settings_page = SettingsPage.new()
	_controls_page = ControlsPage.new()
	_page_buttons = {_settings_page: settings_button, _controls_page: controls_button}
	for page: Control in [_settings_page, _controls_page]:
		page.visible = false
		column.add_child(page)
		page.connect("back", _show_buttons.bind(page))
	first.grab_focus.call_deferred() # so a controller or the arrow keys work straight away


## Rooftops, a water tower and a few lit windows along the bottom of the screen.
## Seeded, so it's the same skyline every time.
func _draw_skyline() -> void:
	var size := _skyline.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	var ground := size.y * 0.92
	_skyline.draw_rect(Rect2(0, ground, size.x, size.y - ground), SKYLINE)
	var x := -20.0
	while x < size.x:
		var width := rng.randf_range(60.0, 160.0)
		var height := rng.randf_range(30.0, 95.0)
		_skyline.draw_rect(Rect2(x, ground - height, width + 1.0, height), SKYLINE)
		if rng.randf() < 0.35: # a window someone left a candle in
			var window := Rect2(x + rng.randf_range(10.0, width - 20.0), ground - height + rng.randf_range(10.0, height - 20.0), 8, 10)
			_skyline.draw_rect(window, Color(1.0, 0.7, 0.35, 0.8))
		x += width
	# The water tower, off to the right, clear of the buttons.
	var tower := Vector2(size.x * 0.84, ground - 120.0)
	for leg: float in [-24.0, 24.0]:
		_skyline.draw_line(tower + Vector2(leg * 0.6, 30.0), tower + Vector2(leg, 120.0), SKYLINE, 4.0)
	_skyline.draw_rect(Rect2(tower + Vector2(-36.0, -16.0), Vector2(72.0, 48.0)), SKYLINE)
	_skyline.draw_colored_polygon(PackedVector2Array([tower + Vector2(-40.0, -16.0), tower + Vector2(0.0, -38.0),
			tower + Vector2(40.0, -16.0)]), SKYLINE)
