@tool
class_name KitPorch
extends Resource
## A porch along a Building's outside walls: a deck at the ground floor's
## height, steps down to the ground, a railing, and a roof on posts (Roofed),
## or screens all round as well (Screened), or no roof (Open: a deck or a
## stoop). On two or more walls one after another it wraps round the corners.
## Add them with Map Tools (Buildings > Add porch: click on a wall) or to the
## Building's Porches list.

## Which walls it runs along, by number (shown over the walls while the
## building is selected), one after another round the building: [0] is along
## the front; [0, 1] wraps round onto wall 1.
@export var walls := PackedInt32Array([0]):
	set(value):
		walls = value
		emit_changed()
## On one wall: how long it is along the wall (meters; 0 = the whole wall),
## and where its middle is, from the wall's middle (+ toward the wall's next
## corner, as for an opening). On several walls it runs their whole length.
@export_range(0.0, 100.0, 0.1, "or_greater") var length := 0.0:
	set(value):
		length = value
		emit_changed()
@export var offset := 0.0:
	set(value):
		offset = value
		emit_changed()
## How far out from the wall it comes (meters).
@export_range(1.0, 6.0, 0.1) var depth := 2.4:
	set(value):
		depth = value
		emit_changed()
@export_enum("Roofed", "Open", "Screened") var kind := "Roofed":
	set(value):
		kind = value
		emit_changed()
## A railing round the deck's edge (not across the steps). A screened porch
## always has its screens.
@export var railing := true:
	set(value):
		railing = value
		emit_changed()
## The steps down: which of its walls they come off (-1: none), and where along
## that wall, from its middle. A screened porch has its screen door there.
@export_range(-1, 100) var steps_wall := 0:
	set(value):
		steps_wall = value
		emit_changed()
@export var steps_offset := 0.0:
	set(value):
		steps_offset = value
		emit_changed()


static func make(on_walls: PackedInt32Array, what := "Roofed") -> KitPorch:
	var porch := KitPorch.new()
	porch.walls = on_walls
	porch.kind = what
	porch.steps_wall = on_walls[0] if on_walls.size() else -1
	return porch
