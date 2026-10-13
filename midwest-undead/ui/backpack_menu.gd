extends CanvasLayer
## Your inventory (Tab, or Y on a controller): everything you're carrying, your
## money and the flashlight's charge. The things you can hold are buttons,
## numbered like the 1-9 keys; pick one to hold it (that closes the screen).
## Ammo, batteries and trade goods are just listed.
## Like the map, it doesn't pause the game. Tab or Esc closes it (so does dying).
## (Containers have their own two-column screen: ui/inventory_menu.gd.)

const GameData := preload("res://core/game_data.gd")
const Player := preload("res://characters/player/player.gd")
const Controls := preload("res://core/controls.gd")

var player: Player
var _info: Label
var _list: VBoxContainer
var _footer: Label


func _ready() -> void:
	layer = 5 # above the HUD, below the pause menu
	visible = false
	_build_ui()


func setup(p: Player) -> void:
	player = p


func open() -> void:
	if visible or player.is_dead or player.menu_open:
		return
	player.menu_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	player.menu_open = false
	if not player.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## _input, not _unhandled_input: while it's open a button has focus, and the GUI
## would otherwise take Tab to move focus instead of closing the screen.
func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("inventory"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled() # so the pause menu doesn't open too


func _hold(id: String) -> void:
	player.select(id)
	close()


func _refresh() -> void:
	_info.text = "$%d    ·    %s" % [player.money, player.flashlight_text()]
	var base := get_tree().get_first_node_in_group("base_camp")
	if base:
		_info.text += "    ·    Base: %d / %d people" % [base.call("population"), base.call("capacity")]
	_footer.text = ("A: hold it   ·   Y / B: close" if Controls.using_gamepad
			else "Click: hold it   ·   Tab / Esc: close")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var holdable := player.holdable()
	for i in holdable.size():
		var id := holdable[i]
		var button := Button.new()
		button.text = "%s  %s" % [str(i + 1) if i < 9 else " ", _item_text(id)]
		if id == player.held:
			button.text += "   (holding)"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(340, 36)
		button.pressed.connect(_hold.bind(id))
		_list.add_child(button)
		if id == player.held:
			button.grab_focus.call_deferred() # a controller starts on what you hold

	for id in player.inventory.ids():
		if id in holdable:
			continue
		var label := Label.new()
		label.text = "     " + _item_text(id)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_list.add_child(label)


func _item_text(id: String) -> String:
	match id:
		"hands":
			return "Fists"
		"pistol":
			return "Pistol  (%d/%d loaded)" % [player.pistol_mag, Player.PISTOL_MAG]
	var count := player.inventory.count(id)
	return GameData.item_name(id) + ("  x%d" % count if count > 1 else "")


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
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)
	_info = Label.new()
	outer.add_child(_info)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	outer.add_child(_list)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 14)
	outer.add_child(_footer)
