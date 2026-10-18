@tool
class_name KitSign
extends StaticBody3D
## A signboard with words on it: on two posts (Standing) or flat against a
## wall (its back to the wall, the node at the middle of its bottom edge).
## Templates put them up (STORE, DINER, POLICE...); change Text in the Inspector.
## Faces -Z like the rest of the kit; a standing one reads from both sides.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const TIMBER := preload("res://world/kit/materials/timber.tres")

@export var text := "STORE":
	set(value):
		text = value
		_changed()
## The board's width and height (meters).
@export var size := Vector2(3.0, 0.9):
	set(value):
		size = value
		_changed()
## On two posts, the board this high off the ground; off: on a wall.
@export var standing := false:
	set(value):
		standing = value
		_changed()
@export_range(0.5, 10.0, 0.1) var height := 2.2:
	set(value):
		height = value
		_changed()
@export var board_color := Color(0.92, 0.9, 0.84):
	set(value):
		board_color = value
		_changed()
@export var text_color := Color(0.6, 0.08, 0.06):
	set(value):
		text_color = value
		_changed()

var _generated: Array[Node] = []
var _dirty := true
var _queued := false


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _dirty:
		_rebuild()


func _changed() -> void:
	_dirty = true
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_generated.clear()
	var board := StandardMaterial3D.new()
	board.albedo_color = board_color
	var km := KitMesh.new()
	var bottom := height if standing else 0.0
	var thick := 0.08
	km.box(Vector3(size.x, size.y, thick), Transform3D(Basis.IDENTITY, Vector3(0, bottom + size.y / 2.0, 0)), KitMesh.all(board))
	if standing:
		for x: float in [-size.x / 2.0 - 0.06, size.x / 2.0 + 0.06]: # at its ends, clear of the words
			km.box(Vector3(0.12, bottom + size.y, 0.12), Transform3D(Basis.IDENTITY, Vector3(x, (bottom + size.y) / 2.0, 0)),
					KitMesh.all(TIMBER))
	_generated = km.add_to(self)
	for side: float in ([-1.0, 1.0] if standing else [-1.0]):
		var label := Label3D.new()
		label.text = text
		label.font_size = 128
		# As tall as fits, unless the words are too long for the board (a letter is about 0.6 as wide as tall).
		label.pixel_size = minf(size.y * 0.55, size.x * 0.9 / (maxi(text.length(), 1) * 0.6)) / 128.0
		label.outline_size = 0
		label.modulate = text_color
		label.double_sided = false
		label.position = Vector3(0, bottom + size.y / 2.0, side * (thick / 2.0 + 0.005))
		label.rotation.y = PI if side < 0.0 else 0.0 # (a Label3D reads from its +Z side)
		add_child(label, false, Node.INTERNAL_MODE_BACK)
		_generated.append(label)
