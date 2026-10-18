extends StaticBody3D
## A camp's bulletin board: a notice board on two posts, with the camp's name,
## how many live there out of how many it can hold, and who they are (written
## on the board itself, and read out in full when you look at it and press
## interact). world/camps.gd makes one for each camp and keeps it up to date;
## main.gd opens it.

const WOOD := Color(0.42, 0.31, 0.2)
const CORK := Color(0.62, 0.48, 0.32)
const BOARD := Vector2(1.3, 0.95)

var title := "" # the camp's name
var summary := "" # "Members 3 / 12"
var details := "" # one line per member: name and what they're doing

var _text: Label3D


func _ready() -> void:
	collision_layer = 1 # the world: you can look at it, zombies path around it
	for x: float in [-BOARD.x / 2.0 + 0.05, BOARD.x / 2.0 - 0.05]:
		_box(Vector3(0.08, 1.9, 0.08), Vector3(x, 0.95, 0.0), WOOD)
	_box(Vector3(BOARD.x, BOARD.y, 0.05), Vector3(0, 1.3, 0.0), CORK)
	var shape := BoxShape3D.new()
	shape.size = Vector3(BOARD.x, 1.9, 0.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.95
	add_child(col)
	_text = Label3D.new()
	_text.pixel_size = 0.0022
	_text.font_size = 36
	_text.modulate = Color(0.08, 0.06, 0.05)
	_text.outline_size = 0
	_text.width = 520.0
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.position = Vector3(0, 1.3 + BOARD.y / 2.0 - 0.06, 0.03)
	add_child(_text)
	_refresh()


## What it says: the camp's name, the head count, and a line per member.
func show_camp(camp_title: String, members: int, capacity: int, lines: PackedStringArray) -> void:
	title = camp_title
	summary = "Members %d / %d" % [members, capacity]
	details = "\n".join(lines) if not lines.is_empty() else "Nobody lives here yet."
	_refresh()


func _refresh() -> void:
	if _text:
		_text.text = "%s\n%s\n\n%s" % [title.to_upper(), summary, details]


func interact_prompt() -> String:
	return "read the bulletin board"


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
