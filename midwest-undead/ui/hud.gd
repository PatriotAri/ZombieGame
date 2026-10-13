extends CanvasLayer
## Everything on screen during play: health, stamina and hunger (top left), the
## clock (top right), the objective (middle left), the crosshair and the
## interact prompt, what you're holding (bottom right), toasts, story moments,
## the red flash when you're hurt, and the death message. The button list is on
## the pause menu's Controls page.
## Everything you carry is on the inventory screen (Tab, ui/backpack_menu.gd).
## While a screen is up (the map, a container, the shop, a conversation, the
## logbook, the pause menu) only the toasts, story moments, hurt flash and death
## message stay; the rest is play information and gets out of the way.
## main.gd creates it, calls setup(), and calls the show_* functions.

const Player := preload("res://characters/player/player.gd")
const Controls := preload("res://core/controls.gd")

var _player: Player
var _day_night: Node
var _has_save_on_death := false

var status_label: Label
var clock_label: Label
var held_label: Label # what you're holding, and its ammo
var _crosshair: Label
var _scope: Control # drawn while looking through the rifle's scope
var prompt_label: Label
var toast_label: Label
var message_label: Label
var objective_label: Label
var story_label: Label
var hurt_overlay: ColorRect
var story_tween: Tween
var toast_tween: Tween
var hurt_tween: Tween
var _play_items: Array[Control] = [] # hidden while a screen is up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # so it notices the pause menu
	_build()


func setup(player: Player, day_night: Node) -> void:
	_player = player
	_day_night = day_night


func _process(_delta: float) -> void:
	if _player == null:
		return
	var in_screen := _player.menu_open or get_tree().paused
	for item in _play_items:
		item.visible = not in_screen
	var crouch := "   (crouching)" if _player.is_crouching else ""
	status_label.text = "Health %d\nStamina %d%s\n%s\nHealth packs %d    $%d" % [
		ceili(_player.health), floori(_player.stamina), crouch, _player.hunger_text(),
		_player.inventory.count("health_pack"), _player.money,
	]
	held_label.text = _player.held_label()
	var scoped := _player.is_scoped() and not in_screen
	if _scope.visible != scoped:
		_scope.visible = scoped
		_scope.queue_redraw()
	_crosshair.visible = not in_screen and not scoped
	prompt_label.text = _player.prompt_text
	clock_label.text = _day_night.clock_text()
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
	# The rifle's scope: black all round a circle, with a reticle. First, so all
	# the text (health, ammo...) draws on top of it.
	_scope = Control.new()
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	add_child(_scope)
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.draw.connect(_draw_scope)

	# Red flash when hurt. Behind the text.
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

	var crosshair := Label.new()
	crosshair.text = "+"
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair = crosshair


	# Full-screen labels with centered text; offset_top pushes the center down.
	prompt_label = _make_centered_label(18)
	add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.offset_top = 90.0

	toast_label = _make_centered_label(22)
	add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label.offset_bottom = -300.0

	# What you're holding: bottom right.
	held_label = Label.new()
	held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	held_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	held_label.add_theme_font_size_override("font_size", 22)
	held_label.add_theme_constant_override("outline_size", 6)
	held_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(held_label)
	held_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	held_label.offset_left = -500.0
	held_label.offset_right = -20.0
	held_label.offset_top = -60.0
	held_label.offset_bottom = -20.0

	# The objective: middle of the left edge, wrapping if it's long.
	objective_label = Label.new()
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	objective_label.add_theme_constant_override("outline_size", 6)
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(objective_label)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	objective_label.offset_left = 20.0
	objective_label.offset_right = 340.0
	objective_label.offset_top = -60.0
	objective_label.offset_bottom = 60.0

	story_label = _make_centered_label(28)
	story_label.add_theme_constant_override("outline_size", 8)
	story_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(story_label)
	story_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_label.offset_bottom = -220.0 # sits in the upper part of the screen

	_play_items = [status_label, clock_label, held_label, prompt_label, objective_label] # (the crosshair: _process)

	message_label = _make_centered_label(36)
	message_label.visible = false
	add_child(message_label)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw_scope() -> void:
	var size := _scope.size
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.45
	# Black outside the lens: a ring wide enough to reach the corners.
	var reach := center.length() + 4.0
	_scope.draw_arc(center, (radius + reach) / 2.0, 0.0, TAU, 96, Color.BLACK, reach - radius, true)
	var line := Color(0, 0, 0, 0.85)
	_scope.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), line, 2.0)
	_scope.draw_line(center - Vector2(0, radius), center + Vector2(0, radius), line, 2.0)
	_scope.draw_line(center - Vector2(0, radius * 0.08), center + Vector2(0, radius), line, 5.0) # thick post below
	_scope.draw_arc(center, radius, 0.0, TAU, 96, Color(0, 0, 0, 0.9), 3.0, true)


func _make_centered_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
