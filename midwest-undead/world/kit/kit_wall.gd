@tool
class_name KitWall
extends Node3D
## One straight wall, any length and height, with doorways and windows cut into
## it: for shapes a Building can't make (an L-shaped store, a back room, a
## garage). Build with several, plus KitFloor for floors and roofs and KitStairs.
##
## It starts at the node and runs along +Z for `length`; it's 0.2 m thick,
## centered on the node's X, and its outside faces -X (turn the node to point
## it the other way). Openings measure along it from its middle, and their
## bottom and top from `floor_height`.
## Turn on snapping (the magnet in the 3D view's toolbar) to line pieces up.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const DEFAULT_OUTSIDE := preload("res://world/kit/materials/siding_white.tres")
const DEFAULT_INSIDE := preload("res://world/kit/materials/plaster.tres")

@export_range(0.2, 100.0, 0.1, "or_greater") var length := 4.0:
	set(value):
		length = value
		_changed()
@export_range(0.2, 30.0, 0.1, "or_greater") var height := 3.6:
	set(value):
		height = value
		_changed()
## Where the floor is on this wall (openings measure up from it).
@export var floor_height := 0.0:
	set(value):
		floor_height = value
		_changed()
## Doorways and windows (their "wall" and "level" settings don't matter here).
@export var openings: Array[KitOpening] = []:
	set(value):
		for op in openings:
			if op and op.changed.is_connected(_changed):
				op.changed.disconnect(_changed)
		openings = value
		for op in openings:
			if op and not op.changed.is_connected(_changed):
				op.changed.connect(_changed)
		_changed()
## Its windows and doors can be planked up by the player.
@export var boardable := true:
	set(value):
		boardable = value
		_changed()
@export var outside_material: Material:
	set(value):
		outside_material = value
		_changed()
@export var inside_material: Material:
	set(value):
		inside_material = value
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
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	var km := KitMesh.new()
	var list := []
	for op in openings:
		if op:
			list.append({"kind": op.kind, "along": op.offset, "width": op.width, "bottom": floor_height + op.bottom,
					"top": floor_height + op.top, "boarded_up": op.boarded_up, "source": op})
	km.wall(Transform3D(Basis.IDENTITY, Vector3(0, 0, length / 2.0)), length, 0.0, height, floor_height, list,
			outside_material if outside_material else DEFAULT_OUTSIDE,
			inside_material if inside_material else DEFAULT_INSIDE, true)
	var body := StaticBody3D.new()
	body.name = "Shell"
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	_generated.append(body)
	km.add_to(body)
	var counts := {"door": 0, "window": 0}
	for entry: Dictionary in list:
		var op: KitOpening = entry["source"]
		if op.kind == "doorway":
			continue # just a gap
		counts[op.kind] += 1
		var node_name: String = op.kind.capitalize() + (str(counts[op.kind]) if counts[op.kind] > 1 else "")
		var node: Node3D
		if op.kind == "door":
			var door := KitMesh.make_door(entry, op.door_color)
			door.start_open = op.start_open
			door.boardable = boardable
			door.boarded_at_start = op.boarded_at_start and boardable
			node = door
		elif not op.boarded_up:
			var frame: Transform3D = entry["frame"]
			node = KitMesh.make_window(entry, boardable, op.boarded_at_start and boardable, frame.origin.y - floor_height)
		if node:
			node.name = node_name
			add_child(node, false, Node.INTERNAL_MODE_BACK)
			_generated.append(node)
