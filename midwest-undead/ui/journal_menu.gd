extends CanvasLayer
## The journal (J, or D-pad down on a controller): your quests (the main story,
## side quests you've taken, ones you've finished or failed) on the left; the
## one you pick on the right, with its steps so far. Track a quest to show its
## objective and waypoint; abandon a side quest to give it up (you can take it
## again from whoever gave it). Like the map, it doesn't pause the game. J or
## Esc closes it.

const QuestManager := preload("res://quests/quest_manager.gd")
const Controls := preload("res://core/controls.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

const SECTIONS := [["active", "Quests"], ["done", "Finished"], ["failed", "Failed"]]

var _player: Node
var _quests: QuestManager
var _list: VBoxContainer
var _title: Label
var _description: Label
var _steps: Label
var _track_button: Button
var _abandon_button: Button
var _footer: Label
var _selected := ""


func _ready() -> void:
	layer = 5
	visible = false
	_build_ui()


func setup(player: Node, quests: QuestManager) -> void:
	_player = player
	_quests = quests
	quests.changed.connect(func() -> void:
		if visible:
			_refresh())


func open() -> void:
	if visible or _player.get("is_dead") or _player.get("menu_open"):
		return
	_player.set("menu_open", true)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected = _quests.tracked
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_player.set("menu_open", false)
	if not _player.get("is_dead"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## _input, not _unhandled_input: a button has focus while it's open, and the GUI
## would otherwise keep the press.
func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("journal"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries := _quests.journal()
	if entries.filter(func(e: Dictionary) -> bool: return e["id"] == _selected).is_empty():
		_selected = entries[0]["id"] if not entries.is_empty() else ""
	var focus: Button = null
	for section: Array in SECTIONS:
		var in_section := entries.filter(func(e: Dictionary) -> bool: return e["status"] == section[0])
		if in_section.is_empty():
			continue
		MenuStyle.add_heading(_list, section[1])
		for entry: Dictionary in in_section:
			var button := Button.new()
			button.text = ("◆ " if entry["tracked"] else "   ") + entry["title"] + ("  (main story)" if entry["main"] else "")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(330, 36)
			button.pressed.connect(func() -> void:
				_selected = entry["id"]
				_refresh())
			_list.add_child(button)
			if entry["id"] == _selected:
				focus = button
	if focus:
		focus.grab_focus.call_deferred()
	_show_selected(entries)
	_footer.text = ("A: pick   ·   Y / B: close" if Controls.using_gamepad else "Click: pick   ·   J / Esc: close") \
			+ "   ·   ◆ tracked"


func _show_selected(entries: Array[Dictionary]) -> void:
	var picked := entries.filter(func(e: Dictionary) -> bool: return e["id"] == _selected)
	_track_button.visible = false
	_abandon_button.visible = false
	if picked.is_empty():
		_title.text = "No quests yet."
		_description.text = "Talk to people. Someone with something for you has a ! over their head."
		_steps.text = ""
		return
	var entry: Dictionary = picked[0]
	_title.text = entry["title"]
	_description.text = entry["description"]
	var lines := PackedStringArray()
	for step: Dictionary in entry["steps"]:
		lines.append(("✓  " if step["done"] else "▸  ") + str(step["objective"]))
	if entry["status"] == "active" and entry["hours_left"] != INF:
		lines.append("\nTime left: %d hours" % ceili(entry["hours_left"]))
	match entry["status"]:
		"done":
			lines.append("\nFinished.")
		"failed":
			lines.append("\nFailed.")
	_steps.text = "\n".join(lines)
	var active: bool = entry["status"] == "active"
	_track_button.visible = active and not entry["tracked"]
	_abandon_button.visible = active and not entry["main"]


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
	MenuStyle.add_title(outer, "JOURNAL", 30)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	outer.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(420, 420)
	detail.add_theme_constant_override("separation", 10)
	columns.add_child(detail)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", MenuStyle.HEADING_COLOR)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_title)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	detail.add_child(_description)
	_steps = Label.new()
	_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_steps)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	detail.add_child(buttons)
	_track_button = MenuStyle.add_button(buttons, "Track", func() -> void:
		_quests.track(_selected)
		_refresh())
	_abandon_button = MenuStyle.add_button(buttons, "Abandon", func() -> void:
		_quests.abandon(_selected)
		_refresh())

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 14)
	outer.add_child(_footer)
