extends CanvasLayer
## The performance readout: F3 shows or hides it (bottom right, above what
## you're holding). Frames per second, and where each frame's time goes: the
## game's code on the processor (scripts, physics, pathfinding), preparing the
## picture on the processor, and drawing it on the graphics card. Whichever is
## biggest is what's holding the frame rate back, and the last line says which.
## Also how much is being drawn (draw calls, objects, triangles) and how many
## zombies there are.
## main.gd creates it. Hidden at start; works while paused too.

const UPDATE := 0.5 # seconds between refreshes (steadier to read than every frame)

var _label: Label
var _panel: PanelContainer
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50 # over the HUD
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.set_content_margin_all(8.0)
	box.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# A point 20 px in from the right and clear of the held-item line (ui/hud.gd);
	# the panel grows left and up from it to fit the text.
	_panel.offset_left = -20.0
	_panel.offset_right = -20.0
	_panel.offset_top = -72.0
	_panel.offset_bottom = -72.0
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_label)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("performance"):
		_panel.visible = not _panel.visible
		# The graphics card's time is only measured while it's being shown.
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), _panel.visible)
		_timer = 0.0


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE
	var vp := get_viewport().get_viewport_rid()
	var fps := Engine.get_frames_per_second()
	var game_ms := 1000.0 * (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			+ Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS))
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp) \
			+ RenderingServer.get_frame_setup_time_cpu()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var lines := [
		"%d fps  (%.1f ms a frame)" % [fps, 1000.0 / maxf(fps, 1.0)],
		"Game code: %.1f ms" % game_ms,
		"Preparing view: %.1f ms" % render_cpu,
		"Graphics card: %s" % ("%.1f ms" % gpu if gpu > 0.0 else "n/a (not measurable on this renderer)"),
		"Draw calls %d   objects %d   triangles %dk" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000],
		"Zombies %d" % get_tree().get_nodes_in_group("zombies").size(),
	]
	var worst := maxf(game_ms, maxf(render_cpu, gpu))
	if worst > 0.0:
		var who := "graphics card" if worst == gpu else ("game code" if worst == game_ms else "preparing the view")
		lines.append("Slowest: " + who)
	_label.text = "\n".join(lines)
