extends "res://world/props/prop_builder.gd"
## A camp's props: world/camp_site.gd puts them where they go (make_props.gd).


func make() -> void:
	_camp()


func _camp() -> void:
	var s: Node3D
	s = _start_prop("Campfire") # a ring of stones, crossed logs, a flame and its glow, a pot on a tripod
	for i in 9:
		var a := TAU * i / 9.0
		_box(s, Vector3(0.22, 0.14, 0.18), Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), _c(STONE), "", -a)
	for k in 3:
		_box(s, Vector3(0.9, 0.1, 0.1), Vector3(0, 0.1, 0), _c(LOG), "", k * PI / 3.0)
	var flame := _box(s, Vector3(0.3, 0.35, 0.3), Vector3(0, 0.3, 0), null, "Flame")
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = FIRE
	flame_mat.emission_enabled = true
	flame_mat.emission = FIRE
	flame_mat.emission_energy_multiplier = 2.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = Vector3(0, 0.6, 0)
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 60.0
	_add(s, glow)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := _box(s, Vector3(0.04, 1.2, 0.04), Vector3(cos(a) * 0.45, 0.55, sin(a) * 0.45), _c(IRON))
		leg.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35) # leaning in to meet over the fire
	_box(s, Vector3(0.36, 0.28, 0.36), Vector3(0, 0.75, 0), _c(IRON)) # the pot
	_save(PROPS + "campfire.tscn")

	s = _start_prop("Lantern") # a kerosene lantern: a base, a glowing globe in a wire guard, a bail handle
	_box(s, Vector3(0.2, 0.1, 0.2), Vector3(0, 0.05, 0), _c(Color(0.25, 0.3, 0.22)), "Paint")
	var globe := _box(s, Vector3(0.13, 0.16, 0.13), Vector3(0, 0.18, 0), null, "Flame")
	var globe_mat := StandardMaterial3D.new()
	globe_mat.albedo_color = Color(1.0, 0.8, 0.45)
	globe_mat.emission_enabled = true
	globe_mat.emission = Color(1.0, 0.75, 0.4)
	globe_mat.emission_energy_multiplier = 2.0
	globe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	globe.material_override = globe_mat
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: float in [-0.08, 0.08]:
		_box(s, Vector3(0.015, 0.18, 0.015), Vector3(x, 0.19, 0), _c(IRON)) # the guard
	_box(s, Vector3(0.18, 0.04, 0.18), Vector3(0, 0.29, 0), _c(Color(0.25, 0.3, 0.22))) # the cap
	_box(s, Vector3(0.2, 0.015, 0.015), Vector3(0, 0.38, 0), _c(IRON)) # the handle
	var lamp := OmniLight3D.new()
	lamp.name = "Glow"
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 0.2, 0)
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 60.0
	_add(s, lamp)
	_save(PROPS + "lantern.tscn")

	s = _start_prop("Tent") # a pup tent: two sloping sides meeting at a ridge, open at the front
	var depth := 2.1
	var half_width := 0.85
	var height := 1.15
	var slope := atan2(height, half_width)
	var side := sqrt(height * height + half_width * half_width)
	for sgn: float in [-1.0, 1.0]:
		_box(s, Vector3(side, 0.03, depth), Vector3(sgn * half_width / 2.0, height / 2.0, 0), _c(CANVAS if sgn < 0.0 else CANVAS_DARK), "", 0.0, 0.0, -sgn * slope)
	_box(s, Vector3(half_width * 2.0, 0.02, depth), Vector3(0, 0.01, 0), _c(CANVAS_DARK)) # the groundsheet
	_box(s, Vector3(0.04, height + 0.1, 0.04), Vector3(0, (height + 0.1) / 2.0, depth / 2.0), _c(WOOD_DARK)) # poles
	_box(s, Vector3(0.04, height + 0.1, 0.04), Vector3(0, (height + 0.1) / 2.0, -depth / 2.0), _c(WOOD_DARK))
	_save(PROPS + "tent.tscn")

	s = _start_prop("CampTable") # the table and chair, with the radio on it (the logbook goes on it too)
	_box(s, Vector3(1.4, 0.06, 0.8), Vector3(0, 0.74, 0), _c(TABLE_WOOD))
	for x: float in [-0.62, 0.62]:
		for z: float in [-0.32, 0.32]:
			_box(s, Vector3(0.06, 0.72, 0.06), Vector3(x, 0.36, z), _c(TABLE_WOOD))
	var chair := Vector3(0.2, 0, 0.75)
	_box(s, Vector3(0.45, 0.05, 0.45), chair + Vector3(0, 0.45, 0), _c(TABLE_WOOD))
	_box(s, Vector3(0.45, 0.5, 0.05), chair + Vector3(0, 0.72, 0.2), _c(TABLE_WOOD))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			_box(s, Vector3(0.04, 0.45, 0.04), chair + Vector3(x, 0.22, z), _c(TABLE_WOOD))
	_box(s, Vector3(0.34, 0.2, 0.18), Vector3(-0.38, 0.87, -0.1), _c(RADIO))
	_box(s, Vector3(0.06, 0.06, 0.02), Vector3(-0.3, 0.88, -0.005), _c(IRON)) # its dial
	_box(s, Vector3(0.015, 0.5, 0.015), Vector3(-0.5, 1.2, -0.12), _c(IRON)) # its aerial
	_save(PROPS + "camp_table.tscn")

	s = _start_prop("Logbook") # a closed book on a table (world/save_point.gd)
	_box(s, Vector3(0.28, 0.05, 0.38), Vector3(0, 0.025, 0), _c(Color(0.15, 0.3, 0.2)))
	_box(s, Vector3(0.26, 0.012, 0.36), Vector3(0.008, 0.056, 0), _c(Color(0.9, 0.87, 0.78)))
	_box(s, Vector3(0.02, 0.3, 0.005), Vector3(0.08, 0.05, 0.19), _c(Color(0.6, 0.1, 0.1)), "", 0.0, 0.0, 1.4) # bookmark
	_save(PROPS + "logbook.tscn")

	s = _start_prop("BulletinBoard") # a cork board on two posts (world/bulletin_board.gd writes on it)
	var board := Vector2(1.3, 0.95)
	for x: float in [-board.x / 2.0 + 0.05, board.x / 2.0 - 0.05]:
		_box(s, Vector3(0.08, 1.9, 0.08), Vector3(x, 0.95, -0.05), _c(Color(0.42, 0.31, 0.2)))
	_box(s, Vector3(board.x, board.y, 0.05), Vector3(0, 1.3, 0.0), _c(Color(0.62, 0.48, 0.32)))
	_box(s, Vector3(board.x + 0.1, 0.06, 0.08), Vector3(0, 1.3 + board.y / 2.0 + 0.03, 0.0), _c(Color(0.42, 0.31, 0.2))) # frame top
	_box(s, Vector3(board.x + 0.1, 0.06, 0.08), Vector3(0, 1.3 - board.y / 2.0 - 0.03, 0.0), _c(Color(0.42, 0.31, 0.2)))
	_save(PROPS + "bulletin_board.tscn")
