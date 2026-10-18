@tool
class_name KitInnerWall
extends Resource
## A wall inside a Building, on one floor, from start to end (the building's
## own meters: x back from the front, y along the front). Draw them with Map
## Tools (Buildings > Draw inner wall) or add them to the Building's Inner
## Walls list. The spaces they close off are rooms (each can have its own
## materials: the Building's Rooms). Doors, doorways and windows go in its own
## Openings (Offset from the wall's middle, + toward End; Wall and Edge don't
## matter here).

## The floor it's on (0: the ground floor, -1: the basement). It reaches from that floor to the ceiling.
@export_range(-1, 19) var level := 0:
	set(value):
		level = value
		emit_changed()
@export var start := Vector2.ZERO:
	set(value):
		start = value
		emit_changed()
@export var end := Vector2(3.0, 0.0):
	set(value):
		end = value
		emit_changed()
@export var openings: Array[KitOpening] = []:
	set(value):
		for op in openings:
			if op and op.changed.is_connected(emit_changed):
				op.changed.disconnect(emit_changed)
		openings = value
		for op in openings:
			if op and not op.changed.is_connected(emit_changed):
				op.changed.connect(emit_changed)
		emit_changed()


static func make(on_level: int, from: Vector2, to: Vector2) -> KitInnerWall:
	var wall := KitInnerWall.new()
	wall.level = on_level
	wall.start = from
	wall.end = to
	return wall
