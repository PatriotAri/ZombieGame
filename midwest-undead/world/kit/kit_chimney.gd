@tool
class_name KitChimney
extends Resource
## A brick chimney in a Building: from the ground up through the roof. Place
## them with Map Tools (Buildings > Place chimney) or add them to the
## Building's Chimneys list.

## Where its middle is (the building's own meters: x back from the front, y along the front).
@export var position := Vector2(2.0, 0.0):
	set(value):
		position = value
		emit_changed()
## How big it is across (x, y in the same axes).
@export var size := Vector2(0.8, 0.8):
	set(value):
		size = value
		emit_changed()


static func make(at: Vector2) -> KitChimney:
	var chimney := KitChimney.new()
	chimney.position = at
	return chimney
