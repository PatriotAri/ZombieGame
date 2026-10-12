extends Node
## Runs the clock: moves the sun and moon, recolors the sky, and dims the world.
## Other scripts find this node through the "day_night" group and call
## light_level() (0 = darkest night, 1 = full daylight).

# Tunable values, set by main.gd from its inspector before setup().
var start_hour := 17.0 # late afternoon; dusk arrives a few minutes in
var seconds_per_game_hour := 40.0 # a full day is 16 real minutes
var night_ambient := Color(0.05, 0.06, 0.1) # dark, but you can make out shapes

const DAY_TOP := Color(0.3, 0.45, 0.72)
const DAY_HORIZON := Color(0.68, 0.74, 0.8)
const DUSK_HORIZON := Color(0.9, 0.45, 0.22)
const NIGHT_TOP := Color(0.01, 0.015, 0.035)
const NIGHT_HORIZON := Color(0.04, 0.05, 0.09)
const DAY_AMBIENT := Color(0.55, 0.56, 0.6)

var hour := 17.0
var day := 1

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D


func setup(environment: Environment, sky_material: ProceduralSkyMaterial,
		sun_light: DirectionalLight3D, moon_light: DirectionalLight3D) -> void:
	add_to_group("day_night")
	hour = start_hour
	env = environment
	sky_mat = sky_material
	sun = sun_light
	moon = moon_light
	_apply()


func _process(delta: float) -> void:
	hour += delta / seconds_per_game_hour
	if hour >= 24.0:
		hour -= 24.0
		day += 1
	_apply()


## -1 at midnight, 0 at sunrise (6:00) and sunset (18:00), 1 at noon.
func sun_height() -> float:
	return sin((hour - 6.0) / 12.0 * PI)


func light_level() -> float:
	return smoothstep(-0.2, 0.25, sun_height())


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "Day %d  ·  %d:%02d %s" % [day, h12, m, "AM" if h < 12 else "PM"]


func _apply() -> void:
	var height := sun_height()
	var light := light_level()
	var twilight := clampf(1.0 - absf(height) / 0.3, 0.0, 1.0) # peaks at sunrise and sunset

	# The sun arcs from the horizon at 6:00, overhead at noon, to the other horizon at 18:00.
	sun.rotation_degrees = Vector3(-(hour - 6.0) / 12.0 * 180.0, -60.0, 0.0)
	sun.visible = height > -0.05
	sun.light_energy = clampf(height * 4.0, 0.0, 1.0) * 1.1
	sun.light_color = Color(1.0, 0.55, 0.35).lerp(Color(1.0, 0.97, 0.92), clampf(height * 2.5, 0.0, 1.0))

	# The moon does the same arc through the night: rises at 18:00, sets at 6:00.
	var moon_hour := fposmod(hour - 18.0, 24.0)
	moon.rotation_degrees = Vector3(-moon_hour / 12.0 * 180.0, 120.0, 0.0)
	moon.visible = height < 0.05
	moon.light_energy = 0.2 * clampf(-height * 4.0, 0.0, 1.0)

	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, light).lerp(DUSK_HORIZON, twilight * 0.75)
	sky_mat.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, light)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.3)
	sky_mat.ground_bottom_color = horizon.darkened(0.8)

	env.ambient_light_color = night_ambient.lerp(DAY_AMBIENT, light)
	env.fog_light_color = horizon.darkened(0.25)
