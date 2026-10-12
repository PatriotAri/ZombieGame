extends CanvasLayer
## Esc (or Start on a controller) toggles the pause menu.
## Pausing works by setting get_tree().paused = true, which freezes every node whose
## process_mode is the default (Inherit -> Pausable): the player, zombies, physics, tweens.
## This menu sets its own process_mode to ALWAYS so it keeps running while paused.

const SaveGame := preload("res://core/save_game.gd")

var resume_button: Button
var _load_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10 # draw above the HUD (which is on the default layer 1)
	visible = false
	_build_ui()


## Esc / Start opens and closes it. While paused, B (ui_cancel) also resumes.
## Opening uses its own "pause" action rather than ui_cancel, because B is crouch.
func _unhandled_input(event: InputEvent) -> void:
	var paused := get_tree().paused
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

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	resume_button = _add_button(box, "Resume", resume)
	_load_button = _add_button(box, "Load last save", _load)
	_add_button(box, "New game", _restart)
	_add_button(box, "Quit to desktop", _quit)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
