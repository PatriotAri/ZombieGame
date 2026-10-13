@tool
class_name KitOpening
extends Resource
## A door, doorway or window in a Building's wall (or in a KitWall). Add them to the
## building's Openings list in the Inspector; the building rebuilds as you change them.

## Which wall, seen from outside: the front is the street side (the building's -X).
## (A KitWall has only one wall and ignores this.)
@export_enum("front", "back", "left", "right") var wall := "front":
	set(value):
		wall = value
		emit_changed()
## A doorway is an open gap where a door would be (no door in it).
@export_enum("window", "door", "doorway") var kind := "window":
	set(value):
		kind = value
		emit_changed()
## Which floor it's on: 0 is the ground floor. (Ignored by a KitWall.)
@export_range(0, 20) var level := 0:
	set(value):
		level = value
		emit_changed()
## Where its middle is along the wall, in meters from the wall's middle
## (seen from outside, + is to the right).
@export var offset := 0.0:
	set(value):
		offset = value
		emit_changed()
@export_range(0.4, 10.0, 0.05, "or_greater") var width := 1.2:
	set(value):
		width = value
		emit_changed()
## Its bottom and top, in meters above the floor (a door's or doorway's bottom is 0).
@export var bottom := 0.9:
	set(value):
		bottom = value
		emit_changed()
@export var top := 2.3:
	set(value):
		top = value
		emit_changed()
## Nailed shut with boards for good: solid wall, no glass.
@export var boarded_up := false:
	set(value):
		boarded_up = value
		emit_changed()
## Planked shut when a new game starts; the player can pull the planks off.
@export var boarded_at_start := false:
	set(value):
		boarded_at_start = value
		emit_changed()
@export_group("Door")
## Standing open when a new game starts.
@export var start_open := false:
	set(value):
		start_open = value
		emit_changed()
@export var door_color := Color(0.36, 0.24, 0.14):
	set(value):
		door_color = value
		emit_changed()


static func make(on_wall: String, what: String, along: float, w: float, from: float, to: float) -> KitOpening:
	var op := KitOpening.new()
	op.wall = on_wall
	op.kind = what
	op.offset = along
	op.width = w
	op.bottom = from
	op.top = to
	return op
