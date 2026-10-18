extends RefCounted
## What a base camp you build looks like (world/structures.gd builds the camp
## kit with it): a campfire with a cooking pot hung over it, two small tents
## behind it, a table and chair with a radio and the camp's logbook (save /
## load) on it, the bulletin board (who lives here) and the supply crate (each
## morning's food and ammo). The camp's +z side faces whoever built it.
## Never instanced: build() adds it all to the camp's StructurePiece.

const SavePoint := preload("res://world/save_point.gd")
const BulletinBoard := preload("res://world/bulletin_board.gd")
const KitContainer := preload("res://items/loot_spot.gd")

## The ground it takes up (meters; x across, z front to back): build() fits in it.
const SIZE := Vector3(7.4, 2.4, 6.4)
const STONE := Color(0.42, 0.41, 0.39)
const LOG := Color(0.3, 0.2, 0.12)
const IRON := Color(0.14, 0.14, 0.15)
const CANVAS := Color(0.45, 0.47, 0.33)
const CANVAS_DARK := Color(0.36, 0.38, 0.26)
const WOOD := Color(0.5, 0.37, 0.24)
const RADIO := Color(0.22, 0.27, 0.2)
const FIRE := Color(1.0, 0.55, 0.15)

static var _materials := {} # Color -> StandardMaterial3D


## Adds the camp to piece. Its parts are named Logbook, Board and Crate (world/camps.gd finds them).
static func build(piece: Node3D) -> void:
	# The campfire: a ring of stones, crossed logs, a glow, and a pot on a tripod.
	for i in 9:
		var a := TAU * i / 9.0
		_box(piece, Vector3(0.22, 0.14, 0.18), Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), STONE, -a)
	for k in 3:
		_box(piece, Vector3(0.9, 0.1, 0.1), Vector3(0, 0.1, 0), LOG, k * PI / 3.0)
	var flame := _box(piece, Vector3(0.3, 0.35, 0.3), Vector3(0, 0.3, 0), FIRE, 0.0)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = FIRE
	flame_mat.emission_enabled = true
	flame_mat.emission = FIRE
	flame_mat.emission_energy_multiplier = 2.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = Vector3(0, 0.6, 0)
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 60.0
	piece.add_child(glow)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := _box(piece, Vector3(0.04, 1.2, 0.04), Vector3(cos(a) * 0.45, 0.55, sin(a) * 0.45), IRON, 0.0)
		leg.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35) # leaning in to meet over the fire
	_box(piece, Vector3(0.36, 0.28, 0.36), Vector3(0, 0.75, 0), IRON, 0.0) # the pot
	# Two small tents behind the fire.
	for side: float in [-1.0, 1.0]:
		_tent(piece, Vector3(2.4 * side, 0, -1.6))
	# The table and chair, with the radio and the logbook on it.
	var table_at := Vector3(0.4, 0, 2.2)
	_box(piece, Vector3(1.4, 0.06, 0.8), table_at + Vector3(0, 0.74, 0), WOOD, 0.0)
	for x: float in [-0.62, 0.62]:
		for z: float in [-0.32, 0.32]:
			_box(piece, Vector3(0.06, 0.72, 0.06), table_at + Vector3(x, 0.36, z), WOOD, 0.0)
	_shape(piece, Vector3(1.4, 0.78, 0.8), table_at + Vector3(0, 0.39, 0))
	var chair_at := table_at + Vector3(0.2, 0, 0.75)
	_box(piece, Vector3(0.45, 0.05, 0.45), chair_at + Vector3(0, 0.45, 0), WOOD, 0.0)
	_box(piece, Vector3(0.45, 0.5, 0.05), chair_at + Vector3(0, 0.72, 0.2), WOOD, 0.0)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			_box(piece, Vector3(0.04, 0.45, 0.04), chair_at + Vector3(x, 0.22, z), WOOD, 0.0)
	_box(piece, Vector3(0.34, 0.2, 0.18), table_at + Vector3(-0.38, 0.87, -0.1), RADIO, 0.0)
	_box(piece, Vector3(0.015, 0.5, 0.015), table_at + Vector3(-0.5, 1.2, -0.12), IRON, 0.0) # its aerial
	var logbook := SavePoint.new()
	logbook.name = "Logbook"
	logbook.position = table_at + Vector3(0.25, 0.77, 0)
	piece.add_child(logbook)
	# The bulletin board and the supply crate, either side of the table.
	var board := BulletinBoard.new()
	board.name = "Board"
	board.position = Vector3(2.6, 0, 2.3)
	piece.add_child(board)
	var crate := KitContainer.new()
	crate.name = "Crate"
	crate.label = "Supply crate"
	crate.loot_table = "none"
	crate.size = Vector3(1.0, 0.7, 0.7)
	crate.sits_on_floor = true
	crate.position = Vector3(-2.4, 0, 2.3)
	piece.add_child(crate)


## A pup tent: two sloping sides meeting at a ridge, open at the front.
static func _tent(piece: Node3D, at: Vector3) -> void:
	var depth := 2.1
	var half_width := 0.85
	var height := 1.15
	var slope := atan2(height, half_width)
	var side := sqrt(height * height + half_width * half_width)
	for s: float in [-1.0, 1.0]:
		var panel := _box(piece, Vector3(side, 0.03, depth), at + Vector3(s * half_width / 2.0, height / 2.0, 0), CANVAS if s < 0.0 else CANVAS_DARK, 0.0)
		panel.rotation.z = -s * slope # each side leans in to meet at the ridge
	_box(piece, Vector3(half_width * 2.0, 0.02, depth), at + Vector3(0, 0.01, 0), CANVAS_DARK, 0.0) # the groundsheet
	_shape(piece, Vector3(half_width * 2.0, height, depth), at + Vector3(0, height / 2.0, 0))


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, yaw: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_materials[color] = mat
	mesh.material = _materials[color]
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation.y = yaw
	parent.add_child(inst)
	return inst


static func _shape(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)
