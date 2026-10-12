extends CanvasLayer
## Everything on screen during play: health and supplies (top left), the clock
## and the zone you're in (top right), the objective, the crosshair and the
## interact prompt, the hotbar, button help, toasts, story moments, the red
## flash when you're hurt, and the death message.
## main.gd creates it, calls setup(), and calls the show_* functions.

const Player := preload("res://characters/player/player.gd")
const Controls := preload("res://core/controls.gd")
const GameData := preload("res://core/game_data.gd")
const Zones := preload("res://world/zones.gd")

const HELP_KEYBOARD := "WASD move  ·  Shift sprint  ·  Ctrl crouch  ·  Space jump  ·  Click use held item  ·  Wheel / 1-9 pick item  ·  R reload  ·  E search/pick up/trade/open  ·  Q quick heal  ·  F flashlight  ·  M map  ·  Esc pause"
const HELP_GAMEPAD := "L stick move  ·  R stick look  ·  L3 sprint  ·  B crouch  ·  A jump  ·  RT use held item  ·  Y / D-pad pick item  ·  RB reload  ·  X search/pick up/trade/open  ·  LB quick heal  ·  D-pad up flashlight  ·  Back map  ·  Start pause"
const ZONE_TEXT_COLORS := {
	Zones.Status.DANGER: Color(1.0, 0.45, 0.4),
	Zones.Status.HOSTILE: Color(1.0, 0.85, 0.35),
	Zones.Status.SAFE: Color(0.75, 0.95, 0.75),
}

var _player: Player
var _day_night: Node
var _zones: Zones
var _has_save_on_death := false

var status_label: Label
var clock_label: Label
var zone_label: Label # the zone you're standing in and what's left in it
var help_label: Label
var hotbar_box: HBoxContainer
var _hotbar_shown := "" # what the hotbar currently displays, so it's only rebuilt on change
var prompt_label: Label
var toast_label: Label
var message_label: Label
var objective_label: Label
var story_label: Label
var hurt_overlay: ColorRect
var story_tween: Tween
var toast_tween: Tween
var hurt_tween: Tween


func _ready() -> void:
	_build()


func setup(player: Player, day_night: Node, zones: Zones) -> void:
	_player = player
	_day_night = day_night
	_zones = zones


func _process(_delta: float) -> void:
	if _player == null:
		return
	var crouch := "   (crouching)" if _player.is_crouching else ""
	status_label.text = "Health %d    Stamina %d%s\n%s\n%s    Health packs: %d    $%d" % [
		ceili(_player.health), floori(_player.stamina), crouch, _player.condition_text(),
		_player.held_label(), _player.inventory.count("health_pack"), _player.money,
	]
	prompt_label.text = _player.prompt_text
	clock_label.text = _day_night.clock_text()
	var zone := _zones.zone_at(_player.global_position)
	zone_label.text = _zones.describe(zone)
	zone_label.add_theme_color_override("font_color", ZONE_TEXT_COLORS[_zones.status_of(zone)])
	help_label.text = HELP_GAMEPAD if Controls.using_gamepad else HELP_KEYBOARD
	_update_hotbar()
	if _player.is_dead:
		var cause: String = {"starved": "You starved.", "shot": "You were shot."}.get(_player.death_cause, "You were bitten.")
		if _has_save_on_death:
			message_label.text = "%s\nLoading your last save...   (%s to load now)" % [cause, Controls.hint("restart")]
		else:
			message_label.text = "%s You never saved.\nPress %s to start over." % [cause, Controls.hint("restart")]


func set_objective(text: String) -> void:
	objective_label.text = "Objective:  " + text if text != "" else ""


## The death message. Its text is set every frame, so the button hint stays current.
func show_death(has_save: bool) -> void:
	_has_save_on_death = has_save
	message_label.visible = true


func flash_hurt() -> void:
	hurt_overlay.color.a = 0.35
	if hurt_tween:
		hurt_tween.kill()
	hurt_tween = create_tween()
	hurt_tween.tween_property(hurt_overlay, "color:a", 0.0, 0.5)


## A big story moment in the middle of the screen, fading after a few seconds.
func show_story(text: String) -> void:
	story_label.text = text
	story_label.modulate.a = 1.0
	if story_tween:
		story_tween.kill()
	story_tween = create_tween()
	story_tween.tween_interval(6.0)
	story_tween.tween_property(story_label, "modulate:a", 0.0, 1.5)


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _build() -> void:
	# Red flash when hurt. Added first so it sits behind the text.
	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	status_label = Label.new()
	status_label.position = Vector2(20, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	add_child(status_label)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(clock_label)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -300.0
	clock_label.offset_right = -20.0
	clock_label.offset_top = 16.0

	zone_label = Label.new()
	zone_label.add_theme_font_size_override("font_size", 18)
	zone_label.add_theme_constant_override("outline_size", 6)
	zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(zone_label)
	zone_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	zone_label.offset_left = -420.0
	zone_label.offset_right = -20.0
	zone_label.offset_top = 46.0

	var crosshair := Label.new()
	crosshair.text = "+"
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Full-screen labels with centered text; offset_top pushes the center down.
	prompt_label = _make_centered_label(18)
	add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.offset_top = 90.0

	toast_label = _make_centered_label(22)
	add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label.offset_bottom = -300.0

	# Hotbar: one box per item you can hold, the held one highlighted.
	hotbar_box = HBoxContainer.new()
	hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_box.add_theme_constant_override("separation", 6)
	hotbar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar_box)
	hotbar_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar_box.offset_top = -86.0
	hotbar_box.offset_bottom = -46.0

	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 14)
	add_child(help_label)
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help_label.offset_left = 16.0
	help_label.offset_top = -36.0
	help_label.offset_bottom = -12.0

	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	objective_label.add_theme_constant_override("outline_size", 6)
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(objective_label)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_label.offset_top = 16.0
	objective_label.offset_bottom = 44.0

	story_label = _make_centered_label(28)
	story_label.add_theme_constant_override("outline_size", 8)
	story_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(story_label)
	story_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_label.offset_bottom = -220.0 # sits in the upper part of the screen

	message_label = _make_centered_label(36)
	message_label.visible = false
	add_child(message_label)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Rebuilds the hotbar boxes only when something about them changed.
func _update_hotbar() -> void:
	var bar := _player.hotbar()
	var texts: Array[String] = []
	for i in bar.size():
		var id := bar[i]
		var label := "Fists" if id == "hands" else GameData.item_name(id)
		if id == "pistol":
			label += " %d/%d" % [_player.pistol_mag, Player.PISTOL_MAG]
		elif id != "hands" and _player.inventory.count(id) > 1:
			label += " x%d" % _player.inventory.count(id)
		if not Controls.using_gamepad and i < 9:
			label = "%d  %s" % [i + 1, label] # number key that selects it
		texts.append(label)
	var signature := "%s|%s" % [str(texts), _player.held]
	if signature == _hotbar_shown:
		return
	_hotbar_shown = signature

	for child in hotbar_box.get_children():
		hotbar_box.remove_child(child)
		child.queue_free()
	for i in bar.size():
		var selected := bar[i] == _player.held
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.75, 0.35, 0.85) if selected else Color(0.0, 0.0, 0.0, 0.5)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = texts[i]
		label.add_theme_font_size_override("font_size", 15)
		if selected:
			label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		panel.add_child(label)
		hotbar_box.add_child(panel)


func _make_centered_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
