extends CanvasLayer
## Your inventory (Tab, or Y on a controller): everything you're carrying, your
## money and the flashlight's charge. First your weapons: the equipped ones
## (the three you switch between: player.gd's slots) have a small square by
## them; picking another one equips it in place of its kind and holds it. Then
## the other things you can hold (health packs, food, planks...): this is where
## you put those in your hands. Picking anything closes the screen.
## The helmet lamp is a button too: put it on (the flashlight key then switches
## it) or take it off. Ammo, batteries and trade goods are just listed.
## Like the map, it doesn't pause the game. Tab or Esc closes it (so does dying).
## (Containers have their own two-column screen: ui/inventory_menu.gd.)

const GameData := preload("res://core/game_data.gd")
const Player := preload("res://characters/player/player.gd")
const Controls := preload("res://core/controls.gd")

var player: Player
var _info: Label
var _list: VBoxContainer
var _footer: Label
var _mark: Texture2D # the square by an equipped weapon
var _no_mark: Texture2D # the same size, empty, so names line up


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
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return # typing (a save's name): the keys are letters, not this screen's
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
	_footer.text = ("A: hold it   ·   %s / B: close" if Controls.using_gamepad
			else "Click: hold it   ·   %s / Esc: close") % Controls.hint("inventory")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	# The equipped weapons (slot order), then the others (picking one equips it).
	var shown: Array[String] = ["hands"]
	for id in player.weapons():
		shown.append(id)
		_add_button(_item_text(id), id, _hold.bind(id), true)
	for id in player.inventory.ids():
		if Player.slot_of(id) != "" and not id in shown:
			shown.append(id)
			_add_button(_item_text(id), id, func() -> void:
				player.equip_weapon(id)
				_hold(id))
	# Everything else you can hold.
	for id in player.holdable():
		if not id in shown:
			shown.append(id)
			_add_button(_item_text(id), id, _hold.bind(id))

	for id in player.inventory.ids():
		if id in shown:
			continue
		if id == "helmet_lamp": # worn, not held: a button to put it on or take it off
			var wear := Button.new()
			wear.text = "Helmet lamp   " + ("(wearing: take it off)" if player.lamp_worn else "(put it on)")
			wear.icon = _no_mark
			wear.add_theme_constant_override("h_separation", 10)
			wear.alignment = HORIZONTAL_ALIGNMENT_LEFT
			wear.custom_minimum_size = Vector2(340, 36)
			wear.pressed.connect(func() -> void:
				player.wear_lamp(not player.lamp_worn)
				_refresh())
			_list.add_child(wear)
			continue
		var label := Label.new()
		label.text = "     " + _item_text(id)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_list.add_child(label)


## A button for something you can hold (id: what's in your hands, for
## "(holding)"); equipped: a square by it.
func _add_button(text: String, id: String, pressed: Callable, equipped := false) -> void:
	var button := Button.new()
	button.text = text + ("   (holding)" if id == player.held else "")
	button.icon = _mark if equipped else _no_mark
	button.add_theme_constant_override("h_separation", 10)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(340, 36)
	button.pressed.connect(pressed)
	_list.add_child(button)
	if id == player.held:
		button.grab_focus.call_deferred() # a controller starts on what you hold


func _item_text(id: String) -> String:
	if id == "hands":
		return "Fists"
	if player.is_gun(id):
		return player.gun_text(id)
	var count := player.inventory.count(id)
	return GameData.item_name(id) + ("  x%d" % count if count > 1 else "")


func _build_ui() -> void:
	var square := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	square.fill(Color(0.95, 0.82, 0.45)) # (the HUD's objective yellow)
	_mark = ImageTexture.create_from_image(square)
	square.fill(Color(0, 0, 0, 0))
	_no_mark = ImageTexture.create_from_image(square)
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
