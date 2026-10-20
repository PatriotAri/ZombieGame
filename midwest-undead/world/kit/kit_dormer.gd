@tool
class_name KitDormer
extends Resource
## A dormer in a Building's sloped roof: a little gabled bump with a window,
## on the slope nearest its point. Place them with Map Tools (Buildings >
## Place dormer: click near the edge of the roof) or add them to the
## Building's Dormers list. (The window is to look at: there's no way in.)

## Where it sits (the building's own meters: x back from the front, y along
## the front), near the eave of the slope it's on.
@export var position := Vector2(0.5, 0.0):
	set(value):
		position = value
		emit_changed()
@export_range(0.8, 4.0, 0.1) var width := 1.6:
	set(value):
		width = value
		emit_changed()


static func make(at: Vector2) -> KitDormer:
	var dormer := KitDormer.new()
	dormer.position = at
	return dormer
