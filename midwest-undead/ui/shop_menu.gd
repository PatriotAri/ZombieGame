extends CanvasLayer
## Buy/sell screen with a shopkeeper. Left column: your items (click to sell).
## Right column: their stock (click to buy). Shift+click does the whole stack,
## or as many as you can afford when buying.

const GameData := preload("res://core/game_data.gd")
const Player := preload("res://characters/player/player.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")

var player: Player
var shop: Shopkeeper
var player_list: VBoxContainer
var shop_list: VBoxContainer
var money_label: Label
var shop_title: Label


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


func open(p: Player, s: Shopkeeper) -> void:
	player = p
	shop = s
	shop_title.text = s.display_name
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
		get_viewport().set_input_as_handled()


func _sell(id: String) -> void:
	var price := shop.sell_price(id)
	var amount := player.inventory.count(id) if Input.is_action_pressed("menu_stack") else 1
	var sold := player.take_item(id, amount)
	player.money += sold * price
	shop.stock.add(id, sold)
	_refresh()


func _buy(id: String) -> void:
	var price := shop.buy_price(id)
	var wanted := shop.stock.count(id) if Input.is_action_pressed("menu_stack") else 1
	var affordable := player.money / price if price > 0 else wanted
	var amount := mini(wanted, affordable)
	if amount <= 0:
		player.notify.emit("Not enough money.")
		return
	var bought := shop.stock.remove(id, amount)
	player.money -= bought * price
	player.give_item(id, bought)
	_refresh()


func _refresh() -> void:
	var focus := _remember_focus()
	money_label.text = "You  ·  $%d" % player.money
	_clear(player_list)
	_clear(shop_list)

	var mine := player.inventory.ids()
	if mine.is_empty():
		_add_note(player_list, "(nothing to sell)")
	for id in mine:
		var price := shop.sell_price(id)
		var text := "%s  x%d" % [GameData.item_name(id), player.inventory.count(id)]
		if player.is_gun(id):
			text = player.gun_text(id)
		var button := _add_button(player_list, text, "sell $%d" % price if price > 0 else "won't buy")
		button.disabled = price <= 0
		button.pressed.connect(_sell.bind(id))

	var theirs := shop.stock.ids()
	if theirs.is_empty():
		_add_note(shop_list, "(sold out)")
	for id in theirs:
		var price := shop.buy_price(id)
		var button := _add_button(shop_list, "%s  x%d" % [GameData.item_name(id), shop.stock.count(id)],
				"$%d" % price if price > 0 else "not for sale")
		button.disabled = price <= 0 or player.money < price
		button.pressed.connect(_buy.bind(id))
	_restore_focus(focus)


func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _add_note(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	list.add_child(label)


## A full-width button with the item on the left and the price on the right.
func _add_button(list: VBoxContainer, left: String, right: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(320, 36)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE # let clicks reach the button
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -10.0
	var name_label := Label.new()
	name_label.text = left
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var price_label := Label.new()
	price_label.text = right
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_label)
	list.add_child(button)
	return button


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

	money_label = _make_title("You")
	player_list = _add_column(columns, money_label)
	shop_title = _make_title("Shop")
	shop_list = _add_column(columns, shop_title)

	var footer := Label.new()
	footer.text = "Left: sell   ·   Right: buy   ·   Shift+click or RB+A: whole stack   ·   E / X / Esc / B: close"
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
	var lists: Array[VBoxContainer] = [player_list, shop_list]
	for col in lists.size():
		var idx := lists[col].get_children().find(focused)
		if idx != -1:
			return Vector2i(col, idx)
	return Vector2i(0, 0)


func _restore_focus(where: Vector2i) -> void:
	var lists: Array[VBoxContainer] = [player_list, shop_list]
	# Try the same column first, then the other, so focus lands on a real button.
	for col in [where.x, 1 - where.x]:
		var buttons := lists[col].get_children().filter(func(c: Node) -> bool: return c is Button)
		if not buttons.is_empty():
			(buttons[mini(where.y, buttons.size() - 1)] as Button).grab_focus()
			return
