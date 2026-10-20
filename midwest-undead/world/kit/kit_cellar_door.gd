@tool
class_name KitCellarDoor
extends Resource
## Storm-cellar doors outside a Building with a Basement: a slanted door over
## steps down beside a wall, into the basement. It opens and shuts like a
## door; zombies can bash it in, and you can board it up. Add them with Map
## Tools (Buildings > Add cellar door: click on a wall) or to the Building's
## Cellar Doors list. (Press Apply in Map Tools to open the ground there.)

## The wall it's beside, by number (shown over the walls while the building is selected).
@export_range(0, 100) var wall := 0:
	set(value):
		wall = value
		emit_changed()
## Where its middle is along the wall, from the wall's middle (+ toward the
## wall's next corner, as for an opening).
@export var offset := 0.0:
	set(value):
		offset = value
		emit_changed()


static func make(on_wall: int, along: float) -> KitCellarDoor:
	var door := KitCellarDoor.new()
	door.wall = on_wall
	door.offset = along
	return door
