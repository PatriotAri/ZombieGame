extends RefCounted
## Player preferences from the pause menu's Settings page: look sensitivity
## (mouse, stick left/right and up/down, while aiming), invert look,
## volume and graphics. Kept in their own file (user://settings.cfg), separate from the save
## game, so they carry over to every playthrough. Never instanced.
## main.gd calls load_settings() once at startup.

const PATH := "user://settings.cfg"
## Every sound effect plays on this bus (see core/sound.gd); it feeds Master.
const SFX_BUS := &"Effects"
const ViewDistance := preload("res://core/view_distance.gd")
## Shadows setting: 0 off, 1 medium, 2 high. [layers, meters] for the sun's shadows.
const SHADOW_QUALITY := {1: [2, 60.0], 2: [4, 100.0]}

const DEFAULTS := {
	"mouse_sensitivity": 1.0,
	"stick_sensitivity_x": 1.0,
	"stick_sensitivity_y": 1.0,
	"aim_sensitivity": 1.0,
	"invert_mouse_y": false,
	"invert_stick_y": false,
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"shadows": 1,
	"view_distance": 1.0,
	"render_scale": 1.0,
	"occlusion_culling": true,
}

## Multipliers on the player's tuned look speeds (player.tscn), so 1.0 is the
## designer's default and the Inspector stays the place to set the baseline.
static var mouse_sensitivity := 1.0
static var stick_sensitivity_x := 1.0 # left / right on the stick
static var stick_sensitivity_y := 1.0 # up / down on the stick
## On top of those while you aim (or look down the rifle's scope), mouse and stick alike.
static var aim_sensitivity := 1.0
## Flip up/down look relative to the player's invert_look_y default, each on its own.
static var invert_mouse_y := false
static var invert_stick_y := false
## Linear volume, 0 (silent) to 1 (full).
static var master_volume := 1.0
static var sfx_volume := 1.0
## Graphics. Shadows: 0 off, 1 medium, 2 high (SHADOW_QUALITY). View distance:
## how far small things are drawn (core/view_distance.gd), as a multiplier.
## Render scale: the 3D world's resolution, as a fraction of the window's (the
## menus and HUD stay sharp). Occlusion culling: what's hidden behind buildings
## isn't drawn (a little work for the processor; much less for the graphics
## card in a town).
static var shadows := 1
static var view_distance := 1.0
static var render_scale := 1.0
static var occlusion_culling := true


static func load_settings() -> void:
	_ensure_buses()
	var file := ConfigFile.new()
	var loaded := file.load(PATH) == OK # a missing file just means defaults
	# Files from before the stick and invert settings were split: one value for both.
	var old := {"stick_sensitivity": ["stick_sensitivity_x", "stick_sensitivity_y"],
			"invert_y": ["invert_mouse_y", "invert_stick_y"]}
	for key: String in DEFAULTS:
		var fallback: Variant = DEFAULTS[key]
		for was: String in old:
			if key in old[was] and loaded:
				fallback = file.get_value("settings", was, fallback)
		var value: Variant = file.get_value("settings", key, fallback) if loaded else DEFAULTS[key]
		set_value(key, value)


static func save_settings() -> void:
	var file := ConfigFile.new()
	for key: String in DEFAULTS:
		file.set_value("settings", key, get_value(key))
	var err := file.save(PATH)
	if err != OK:
		push_error("Couldn't save settings: %s" % error_string(err))


static func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		set_value(key, DEFAULTS[key])


static func get_value(key: String) -> Variant:
	match key:
		"mouse_sensitivity": return mouse_sensitivity
		"stick_sensitivity_x": return stick_sensitivity_x
		"stick_sensitivity_y": return stick_sensitivity_y
		"aim_sensitivity": return aim_sensitivity
		"invert_mouse_y": return invert_mouse_y
		"invert_stick_y": return invert_stick_y
		"master_volume": return master_volume
		"sfx_volume": return sfx_volume
		"shadows": return shadows
		"view_distance": return view_distance
		"render_scale": return render_scale
		"occlusion_culling": return occlusion_culling
	return null


## Sets one setting and applies it right away (volumes take effect immediately).
static func set_value(key: String, value: Variant) -> void:
	match key:
		"mouse_sensitivity": mouse_sensitivity = clampf(float(value), 0.1, 3.0)
		"stick_sensitivity_x": stick_sensitivity_x = clampf(float(value), 0.1, 3.0)
		"stick_sensitivity_y": stick_sensitivity_y = clampf(float(value), 0.1, 3.0)
		"aim_sensitivity": aim_sensitivity = clampf(float(value), 0.1, 3.0)
		"invert_mouse_y": invert_mouse_y = bool(value)
		"invert_stick_y": invert_stick_y = bool(value)
		"master_volume": master_volume = clampf(float(value), 0.0, 1.0)
		"sfx_volume": sfx_volume = clampf(float(value), 0.0, 1.0)
		"shadows": shadows = clampi(int(value), 0, 2)
		"view_distance": view_distance = clampf(float(value), 0.5, 1.5)
		"render_scale": render_scale = clampf(float(value), 0.5, 1.0)
		"occlusion_culling": occlusion_culling = bool(value)
	_apply_volume()
	apply_graphics()


## Puts the graphics settings into effect on whatever's running (the game's sun
## is in the "sun" group). main.gd calls it once the world is set up.
static func apply_graphics() -> void:
	ViewDistance.scale = view_distance # things made from now on use it
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	ViewDistance.set_scale(tree, view_distance)
	tree.root.scaling_3d_scale = render_scale
	tree.root.use_occlusion_culling = occlusion_culling
	for node in tree.get_nodes_in_group("sun"):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = shadows > 0
		if shadows > 0:
			var quality: Array = SHADOW_QUALITY[shadows]
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality[0] == 2 \
					else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = quality[1]


static func _apply_volume() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


## Sliders are linear (what feels even to the ear is closer to that than to
## decibels); 0 mutes outright, since linear_to_db(0) is -infinity.
static func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## The project has no bus layout file; the Effects bus is made here instead,
## so it can't go missing. (A later Music or Ambience slider would add its bus
## the same way.)
static func _ensure_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, SFX_BUS)
	AudioServer.set_bus_send(index, &"Master")
