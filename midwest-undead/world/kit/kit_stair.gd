@tool
class_name KitStair
extends Resource
## One flight of stairs in a Building, from a floor up to the one above it.
## Place them with the Map Tools panel's Buildings section (click where it
## starts, then which way it climbs), or add them to the Building's Stairs list
## and set them here. The floor above gets a hole over it and a railing round
## the hole.

## The floor it starts on (0: the ground floor); it climbs to the next one.
@export_range(0, 19) var level := 0:
	set(value):
		level = value
		emit_changed()
## Where its bottom step is (the middle of it), in the building's own meters:
## x back from the front, y along the front (the building's z).
@export var start := Vector2(1.5, 0.0):
	set(value):
		start = value
		emit_changed()
## Which way it climbs, in degrees: 0 is straight back from the front (the
## building's +x), 90 is toward its +z side, -90 the other way.
@export_range(-180.0, 180.0, 1.0) var direction := 0.0:
	set(value):
		direction = value
		emit_changed()


static func make(on_level: int, at: Vector2, degrees: float) -> KitStair:
	var stair := KitStair.new()
	stair.level = on_level
	stair.start = at
	stair.direction = degrees
	return stair
