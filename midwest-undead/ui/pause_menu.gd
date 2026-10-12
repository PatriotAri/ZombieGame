extends CanvasLayer
## Esc (or Start on a controller) toggles the pause menu.
## Pausing works by setting get_tree().paused = true, which freezes every node whose
## process_mode is the default (Inherit -> Pausable): the player, zombies, physics, tweens.
## This menu sets its own process_mode to ALWAYS so it keeps running while paused.
## "Settings" and "Controls" swap the button list for that page (ui/settings_page.gd,
## ui/controls_page.gd, shared with the main menu); Back, Esc or B comes back.

const SaveGame := preload("res://core/save_game.gd")
const MenuStyle := preload("res://ui/menu_style.gd")
const SettingsPage := preload("res://ui/settings_page.gd")
const ControlsPage := preload("res://ui/controls_page.gd")
const MAIN_MENU := "res://ui/main_menu.tscn"

var resume_button: Button
var _load_button: Button
var _main_page: VBoxContainer
var _settings_page: SettingsPage
var _controls_page: ControlsPage
var _page_buttons := {} # page -> the button that opened it, to put focus back on


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10 # draw above the HUD (which is on the default layer 1)
	visible = false
	_build_ui()


## Esc / Start opens and closes it. While paused, B (ui_cancel) also resumes.
## Opening uses its own "pause" action rather than ui_cancel, because B is crouch.
func _unhandled_input(event: InputEvent) -> void:
	var paused := get_tree().paused
	var page := _open_page()
	if paused and page and event.is_action_pressed("ui_cancel"):
		page.leave() # B / Esc on a page goes back to the buttons, not all the way out
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
	var page := _open_page()
	if page:
		page.leave()
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
	get_tree().paused = false # pause state survives a scene change, so clear it first
	get_tree().reload_current_scene()


## Back to the title screen. Anything since your last save is lost (as with New game).
func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _quit() -> void:
	get_tree().quit()


## The settings or controls page if one is showing, else null.
func _open_page() -> Control:
	for page: Control in [_settings_page, _controls_page]:
		if page.visible:
			return page
	return null


func _show_page(page: Control) -> void:
	_main_page.visible = false
	page.visible = true
	page.call("focus_first")


func _show_buttons(from_page: Control) -> void:
	from_page.visible = false
	_main_page.visible = true
	(_page_buttons[from_page] as Button).grab_focus()


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
	MenuStyle.add_title(_main_page, "PAUSED")
	resume_button = MenuStyle.add_button(_main_page, "Resume", resume)
	_load_button = MenuStyle.add_button(_main_page, "Load last save", _load)
	var settings_button := MenuStyle.add_button(_main_page, "Settings", func() -> void: _show_page(_settings_page))
	var controls_button := MenuStyle.add_button(_main_page, "Controls", func() -> void: _show_page(_controls_page))
	MenuStyle.add_button(_main_page, "New game", _restart)
	MenuStyle.add_button(_main_page, "Main menu", _to_main_menu)
	MenuStyle.add_button(_main_page, "Quit to desktop", _quit)

	_settings_page = SettingsPage.new()
	_controls_page = ControlsPage.new()
	_page_buttons = {_settings_page: settings_button, _controls_page: controls_button}
	for page: Control in [_settings_page, _controls_page]:
		page.visible = false
		center.add_child(page)
		page.connect("back", _show_buttons.bind(page))
