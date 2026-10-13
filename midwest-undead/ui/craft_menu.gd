extends CanvasLayer
## Crafting with the woodworker or the machinist: what they can make, what each
## needs, and how much of it you have. Pick one you have the materials for and
## it's made on the spot (materials out of your inventory, the piece in).
## Recipes are in core/recipes.gd. Like the shop, the game keeps running; Esc,
## E or B closes it (so does dying).

const GameData := preload("res://core/game_data.gd")
const Recipes := preload("res://core/recipes.gd")
const Player := preload("res://characters/player/player.gd")

var player: Player
var _recipes: Array = []
var _title: Label
var _note: Label
var _list: VBoxContainer
var _have: Label


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


## note: shown above the list (e.g. why some things can't be made yet); with
## recipes empty it's all there is.
func open(p: Player, crafter: String, recipes: Array, note := "") -> void:
	if p.menu_open or p.is_dead:
		return
	player = p
	_recipes = recipes
	_title.text = crafter
	_note.text = note
	_note.visible = note != ""
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


func _craft(recipe: Dictionary) -> void:
	if not Recipes.can_make(player.inventory, recipe):
		return
	Recipes.take(player.inventory, recipe)
	player.give_item(recipe["id"])
	player.notify.emit("Made: " + GameData.item_name(recipe["id"]))
	_refresh()


func _refresh() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_index := _list.get_children().find(focused)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for recipe: Dictionary in _recipes:
		var needs: Dictionary = recipe["needs"]
		var parts: Array[String] = []
		for item: String in needs:
			parts.append("%d %s" % [needs[item], GameData.item_name(item).to_lower()])
		var button := Button.new()
		button.text = "%s   ·   %s" % [GameData.item_name(recipe["id"]), ", ".join(parts)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(460, 38)
		button.disabled = not Recipes.can_make(player.inventory, recipe)
		button.pressed.connect(_craft.bind(recipe))
		_list.add_child(button)
	var have: Array[String] = []
	for item in ["planks", "plywood", "scrap_metal"]:
		have.append("%s %d" % [GameData.item_name(item), Recipes.have(player.inventory, item)])
	_have.text = "You have:  " + "   ·   ".join(have) + "   (used planks count as planks)"
	# Keep a controller on the same row after rebuilding the list.
	var buttons := _list.get_children().filter(func(c: Node) -> bool: return c is Button and not (c as Button).disabled)
	if not buttons.is_empty():
		var target: Button = _list.get_children()[focus_index] if focus_index >= 0 and focus_index < _list.get_child_count() else buttons[0]
		if target.disabled:
			target = buttons[0]
		_focus_later(target)


## Next frame (after the rebuild settles), if the button's still there.
func _focus_later(button: Button) -> void:
	(func() -> void:
		if is_instance_valid(button) and button.is_inside_tree():
			button.grab_focus()).call_deferred()


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
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	outer.add_child(_title)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 460
	_note.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	outer.add_child(_note)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	outer.add_child(_list)
	_have = Label.new()
	outer.add_child(_have)
	var footer := Label.new()
	footer.text = "Click or A: make it   ·   E / X / Esc / B: close"
	footer.add_theme_font_size_override("font_size", 14)
	outer.add_child(footer)
