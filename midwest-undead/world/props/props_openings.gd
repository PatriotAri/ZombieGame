extends "res://world/props/prop_builder.gd"
## Doors and windows, stretched to fit each opening (make_props.gd).


func make() -> void:
	_openings()


func _openings() -> void:
	var s := _start_prop("Door") # 0.9 m wide along +Z, 2.1 m tall, centered: a panel door with a knob
	_box(s, Vector3(0.06, 2.1, 0.9), Vector3.ZERO, _c(Color(0.36, 0.24, 0.14)), "Paint")
	for side: float in [-1.0, 1.0]: # raised panels and a knob on both faces
		for yy: float in [0.45, -0.5]:
			_box(s, Vector3(0.02, 0.75, 0.6), Vector3(side * 0.035, yy, 0), _c(Color(0.32, 0.21, 0.12)), "Paint%d" % (2 if side < 0 else 3) + ("a" if yy > 0 else "b"))
		_cyl(s, 0.035, 0.05, Vector3(side * 0.06, -0.05, 0.36), _c(Color(0.75, 0.65, 0.3)), Vector3(0, 0, PI / 2.0))
	_save(PROPS + "door.tscn")

	s = _start_prop("Window") # 1 m wide along +Z, 1.2 m tall, centered: a frame, a cross bar and the glass
	var glass := StandardMaterial3D.new()
	glass.albedo_color = KitMesh.GLASS
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.metallic_specular = 0.8
	var g := _box(s, Vector3(0.02, 1.16, 0.96), Vector3.ZERO, glass, "Glass")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # let sunlight in
	var frame := _c(Color(0.85, 0.83, 0.78))
	for yy: float in [-0.58, 0.58]:
		_box(s, Vector3(0.06, 0.05, 1.0), Vector3(0, yy, 0), frame)
	for zz: float in [-0.48, 0.48]:
		_box(s, Vector3(0.06, 1.2, 0.05), Vector3(0, 0, zz), frame)
	_box(s, Vector3(0.05, 1.16, 0.03), Vector3.ZERO, frame) # the cross bar
	_box(s, Vector3(0.05, 0.03, 0.96), Vector3.ZERO, frame)
	_save(PROPS + "window.tscn")

	s = _start_prop("GarageDoor") # 2.4 m wide along +Z, 2.1 m tall, centered: ribbed steel sections and a handle
	var steel := _c(Color(0.82, 0.81, 0.78))
	_box(s, Vector3(0.05, 2.1, 2.4), Vector3.ZERO, steel, "Paint")
	for i in 4: # the sections' seams, both faces
		for side: float in [-1.0, 1.0]:
			_box(s, Vector3(0.01, 0.04, 2.4), Vector3(side * 0.03, -1.05 + 0.525 * (i + 1) - 0.02, 0), _c(Color(0.6, 0.6, 0.58)))
	_box(s, Vector3(0.04, 0.05, 0.3), Vector3(-0.045, -0.75, 0), _c(IRON))
	_save(PROPS + "garage_door.tscn")

	s = _start_prop("CellarDoor") # a storm-cellar leaf: 1 m across along +Z, 2 m up its slope (Y), its top face -X
	_box(s, Vector3(0.05, 2.0, 1.0), Vector3.ZERO, _c(Color(0.3, 0.33, 0.3)), "Paint")
	for yy: float in [-0.7, 0.0, 0.7]: # stiffening ribs on top
		_box(s, Vector3(0.03, 0.06, 0.96), Vector3(-0.04, yy, 0), _c(Color(0.25, 0.27, 0.25)))
	_cyl(s, 0.02, 0.18, Vector3(-0.08, -0.85, 0.3), _c(IRON), Vector3(0, 0, PI / 2.0)) # the handle
	_save(PROPS + "cellar_door.tscn")

	s = _start_prop("ScreenDoor") # 0.9 m wide along +Z, 2.1 m tall, centered: a wood frame round a screen
	var wood := _c(Color(0.55, 0.42, 0.28))
	var screen := _mat("screen")
	_box(s, Vector3(0.01, 2.0, 0.8), Vector3.ZERO, screen, "Screen")
	for yy: float in [-1.02, 0.0, 1.02]:
		_box(s, Vector3(0.05, 0.08, 0.9), Vector3(0, yy, 0), wood, "Paint" if yy == 0.0 else "")
	for zz: float in [-0.42, 0.42]:
		_box(s, Vector3(0.05, 2.1, 0.07), Vector3(0, 0, zz), wood)
	_save(PROPS + "screen_door.tscn")
