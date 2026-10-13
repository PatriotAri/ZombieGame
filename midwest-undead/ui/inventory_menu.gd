extends CanvasLayer
## Two-column transfer screen between you and an opened container.
## The game keeps running while it's open; Esc closes it (so does dying).

const GameData := preload("res://core/game_data.gd")
const Inventory := preload("res://items/inventory.gd")
const Player := preload("res://characters/player/player.gd")
const LootSpot := preload("res://items/loot_spot.gd")

var player: Player
var container: LootSpot
var player_list: VBoxContainer
var container_list: VBoxContainer
var container_title: Label


func _ready() -> void:
	layer = 5 # above the HUD, below the pause menu
	visible = false
	_build_ui()


func open(p: Player, spot: LootSpot) -> void:
	player = p
	container = spot
	container_title.text = spot.label
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or event.is_action_pressed("pause"):
		close()
		# Mark handled so the pause menu doesn't open and the player doesn't
		# immediately re-open the container with the same key press.
		get_viewport().set_input_as_handled()


## Click moves one; Shift+click moves the whole stack.
func _move(id: String, from_player: bool) -> void:
	var all := Input.is_action_pressed("menu_stack")
	if from_player:
		var n := player.inventory.count(id) if all else 1
		container.inventory.add(id, player.take_item(id, n))
	else:
		var n := container.inventory.count(id) if all else 1
		player.give_item(id, container.inventory.remove(id, n))
	_refresh()


func _refresh() -> void:
	var focus := _remember_focus()
	_fill(player_list, player.inventory, true)
	_fill(container_list, container.inventory, false)
	_restore_focus(focus)


func _fill(list: VBoxContainer, inv: Inventory, from_player: bool) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var ids := inv.ids()
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		list.add_child(empty)
		return
	for id in ids:
		var text := "%s  x%d" % [GameData.item_name(id), inv.count(id)]
		if player.is_gun(id) and from_player:
			text = player.gun_text(id)
		var button := Button.new()
		button.text = text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(260, 36)
		button.pressed.connect(_move.bind(id, from_player))
		list.add_child(button)


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
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	outer.add_child(columns)

	var you_title := _make_title("You")
	player_list = _add_column(columns, you_title)
	container_title = _make_title("Container")
	container_list = _add_column(columns, container_title)

	var footer := Label.new()
	footer.text = "Click or A: move one   ·   Shift+click or RB+A: move all   ·   E / X / Esc / B: close"
	footer.add_theme_font_size_override("font_size", 14)
	outer.add_child(footer)


func _make_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 22)
	return title


func _add_column(parent: Control, title: Label) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	column.add_child(list)
	parent.add_child(column)
	return list


# --- Controller focus ----------------------------------------------------------
# Rebuilding the lists destroys the focused button, which would strand a
# controller player. Remember which row had focus and put it back afterwards.

func _remember_focus() -> Vector2i:
	var focused := get_viewport().gui_get_focus_owner()
	var lists: Array[VBoxContainer] = [player_list, container_list]
	for col in lists.size():
		var idx := lists[col].get_children().find(focused)
		if idx != -1:
			return Vector2i(col, idx)
	return Vector2i(0, 0)


func _restore_focus(where: Vector2i) -> void:
	var lists: Array[VBoxContainer] = [player_list, container_list]
	# Try the same column first, then the other, so focus lands on a real button.
	for col in [where.x, 1 - where.x]:
		var buttons := lists[col].get_children().filter(func(c: Node) -> bool: return c is Button)
		if not buttons.is_empty():
			(buttons[mini(where.y, buttons.size() - 1)] as Button).grab_focus()
			return
