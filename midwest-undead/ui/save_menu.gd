extends CanvasLayer
## The logbook screen: save as a new save or over an old one, load one, or
## delete one (ui/save_list.gd). main.gd supplies the save callback (it knows how
## to collect the game state).

const SaveList := preload("res://ui/save_list.gd")

var _player: Node
var _list: SaveList


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


## save_callback(path) saves the game there and returns true if it did.
func open(player: Node, save_callback: Callable) -> void:
	_player = player
	_list.save_callback = save_callback
	_player.set("menu_open", true)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_list.refresh()
	_list.focus_first()


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

	_list = SaveList.new(SaveList.Mode.SAVE, "LOGBOOK")
	_list.back.connect(close)
	margin.add_child(_list)
