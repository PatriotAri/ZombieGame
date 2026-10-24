extends CanvasLayer
## The quest debug panel: F4 opens or closes it, in a debug build only (playing
## from the editor, or a debug export; never a release export). For trying
## quests out without playing up to them: pick a quest to see where it stands
## (its stage, objectives ticked when done, time left), then start it, put it
## at any stage, count an objective as done, finish, fail or reset it. Below:
## set a flag, give yourself items, and go straight to a quest marker.
## The game is paused while it's open. main.gd makes it.

const QuestManager := preload("res://quests/quest_manager.gd")
const GameData := preload("res://core/game_data.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

var _player: Node3D
var _quests: QuestManager
var _quest_list: OptionButton
var _summary: Label
var _stages: OptionButton
var _objectives: OptionButton
var _flags: Label
var _flag_name: LineEdit
var _flag_value: SpinBox
var _items: OptionButton
var _item_count: SpinBox
var _markers: OptionButton
var _paused_it := false


func _ready() -> void:
	layer = 60 # over everything but the fade
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func setup(player: Node3D, quests: QuestManager) -> void:
	_player = player
	_quests = quests


func open() -> void:
	if visible or _player.get("is_dead") or _player.get("menu_open"):
		return
	_player.set("menu_open", true)
	visible = true
	_paused_it = not get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill_lists()
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if _paused_it:
		get_tree().paused = false
	_player.set("menu_open", false)
	if not _player.get("is_dead"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if _player == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F4:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- What's shown ----------------------------------------------------------------------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	box.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = 520.0
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	MenuStyle.add_heading(col, "Quest debug  (F4 / Esc closes)")
	_quest_list = OptionButton.new()
	_quest_list.item_selected.connect(func(_i: int) -> void: _refresh())
	col.add_child(_quest_list)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	var row := _row(col)
	_small_button(row, "Start", func() -> void: _quests.debug_start(_quest()))
	_small_button(row, "Finish", func() -> void: _quests.debug_complete(_quest()))
	_small_button(row, "Fail", func() -> void: _quests.fail_quest(_quest(), "debug panel"))
	_small_button(row, "Reset", func() -> void: _quests.debug_reset(_quest()))
	_small_button(row, "Track", func() -> void: _quests.track(_quest()))
	row = _row(col)
	_stages = _option(row)
	_small_button(row, "Go to stage", func() -> void:
		if _stages.selected >= 0:
			_quests.debug_go_to_stage(_quest(), _stages.get_item_text(_stages.selected)))
	row = _row(col)
	_objectives = _option(row)
	_small_button(row, "Count as done", func() -> void:
		if _objectives.selected >= 0:
			_quests.debug_finish_objective(_quest(), _objectives.get_item_text(_objectives.selected)))

	MenuStyle.add_heading(col, "Flags")
	_flags = Label.new()
	_flags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_flags)
	row = _row(col)
	_flag_name = LineEdit.new()
	_flag_name.placeholder_text = "flag"
	_flag_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_flag_name)
	_flag_value = _spin(row, -999, 999, 1)
	_small_button(row, "Set", func() -> void:
		if _flag_name.text.strip_edges() != "":
			_quests.set_flag(_flag_name.text.strip_edges(), int(_flag_value.value)))

	MenuStyle.add_heading(col, "Give yourself")
	row = _row(col)
	_items = _option(row)
	_item_count = _spin(row, 1, 999, 1)
	_small_button(row, "Give", func() -> void:
		if _items.selected >= 0:
			_quests.give({_items.get_item_metadata(_items.selected): int(_item_count.value)}, 0))
	row = _row(col)
	_small_button(row, "$100", func() -> void: _quests.give({}, 100))

	MenuStyle.add_heading(col, "Go to a quest marker")
	row = _row(col)
	_markers = _option(row)
	_small_button(row, "Go there", _go_to_marker)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _option(parent: Control) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	parent.add_child(option)
	return option


func _spin(parent: Control, low: int, high: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	parent.add_child(spin)
	return spin


## Does what it says, then shows how things stand now.
func _small_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		action.call()
		_refresh())
	parent.add_child(button)
	return button


## The quests, items and markers to pick from (what's in the game doesn't
## change while it's open).
func _fill_lists() -> void:
	var picked := _quest()
	_quest_list.clear()
	for q in _quests.quests:
		_quest_list.add_item(q.title if q.title != "" else q.id)
		_quest_list.set_item_metadata(_quest_list.item_count - 1, q.id)
		if q.id == (picked if picked != "" else _quests.tracked):
			_quest_list.select(_quest_list.item_count - 1)
	if _items.item_count == 0:
		for id in GameData.item_ids():
			_items.add_item("%s  (%s)" % [GameData.item_name(id), id])
			_items.set_item_metadata(_items.item_count - 1, id)
	_markers.clear()
	var ids: Array = _quests.world.marker_ids()
	ids.sort()
	for id: String in ids:
		_markers.add_item(id)


func _quest() -> String:
	return str(_quest_list.get_item_metadata(_quest_list.selected)) if _quest_list.selected >= 0 else ""


func _refresh() -> void:
	var id := _quest()
	for i in _quest_list.item_count:
		var q: Quest = _quests.find(str(_quest_list.get_item_metadata(i)))
		_quest_list.set_item_text(i, "%s  [%s]" % [q.title if q.title != "" else q.id, _quests.status(q)])
	_summary.text = _quests.debug_summary(id)
	var q := _quests.find(id)
	_stages.clear()
	if q:
		for stage in q.stages:
			if stage:
				_stages.add_item(stage.id)
		var current := _quests.current_stage(q)
		if current:
			_stages.select(q.stage_index(current.id))
	_objectives.clear()
	for oid in _quests.debug_objective_ids(id):
		_objectives.add_item(oid)
	var flags := _quests.debug_flags()
	var shown := PackedStringArray()
	for f: String in flags:
		shown.append("%s = %d" % [f, flags[f]])
	_flags.text = ", ".join(shown) if not shown.is_empty() else "(none set)"


func _go_to_marker() -> void:
	if _markers.selected < 0:
		return
	var m: KitQuestMarker = _quests.world.marker(_markers.get_item_text(_markers.selected))
	if m == null:
		return
	_player.global_position = m.global_position + Vector3(0, 1.0, 0)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	close() # see where you are
