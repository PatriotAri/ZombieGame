extends RefCounted
## Player preferences from the pause menu's Settings page: look sensitivity and
## volume. Kept in their own file (user://settings.cfg), separate from the save
## game, so they carry over to every playthrough. Never instanced.
## main.gd calls load_settings() once at startup.

const PATH := "user://settings.cfg"
## Every sound effect plays on this bus (see core/sound.gd); it feeds Master.
const SFX_BUS := &"Effects"

const DEFAULTS := {
	"mouse_sensitivity": 1.0,
	"stick_sensitivity": 1.0,
	"invert_y": false,
	"master_volume": 1.0,
	"sfx_volume": 1.0,
}

## Multipliers on the player's tuned look speeds (player.tscn), so 1.0 is the
## designer's default and the Inspector stays the place to set the baseline.
static var mouse_sensitivity := 1.0
static var stick_sensitivity := 1.0
## Flips up/down look relative to the player's invert_look_y default.
static var invert_y := false
## Linear volume, 0 (silent) to 1 (full).
static var master_volume := 1.0
static var sfx_volume := 1.0


static func load_settings() -> void:
	_ensure_buses()
	var file := ConfigFile.new()
	var loaded := file.load(PATH) == OK # a missing file just means defaults
	for key: String in DEFAULTS:
		var value: Variant = file.get_value("settings", key, DEFAULTS[key]) if loaded else DEFAULTS[key]
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
		"stick_sensitivity": return stick_sensitivity
		"invert_y": return invert_y
		"master_volume": return master_volume
		"sfx_volume": return sfx_volume
	return null


## Sets one setting and applies it right away (volumes take effect immediately).
static func set_value(key: String, value: Variant) -> void:
	match key:
		"mouse_sensitivity": mouse_sensitivity = clampf(float(value), 0.1, 3.0)
		"stick_sensitivity": stick_sensitivity = clampf(float(value), 0.1, 3.0)
		"invert_y": invert_y = bool(value)
		"master_volume": master_volume = clampf(float(value), 0.0, 1.0)
		"sfx_volume": sfx_volume = clampf(float(value), 0.0, 1.0)
	_apply_volume()


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
