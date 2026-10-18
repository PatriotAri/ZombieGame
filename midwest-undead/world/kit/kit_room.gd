@tool
class_name KitRoom
extends Resource
## A room in a Building: the space its walls (outside and inner) close off
## round Point, on one floor. Its walls' inside faces and its floor take these
## materials instead of the building's, and its Kind says what it's for. Mark
## one with Map Tools (Buildings > Paint room: click inside it) or add it to the
## Building's Rooms list.

@export_range(-1, 19) var level := 0:
	set(value):
		level = value
		emit_changed()
## Any spot inside the room (the building's own meters: x back from the front,
## y along the front).
@export var point := Vector2(2.0, 0.0):
	set(value):
		point = value
		emit_changed()
## What it is: what Furnish Rooms (on the Building, or Map Tools) puts in it,
## and what its cabinets and drawers tend to hold (world/kit/kit_furnish.gd).
## None: Furnish leaves it alone.
@export_enum("None", "Bedroom", "Kitchen", "Living room", "Dining room", "Bathroom", "Laundry", "Garage",
		"Basement storage", "Store floor", "Stockroom", "Office", "Diner seating", "Diner kitchen", "Sanctuary",
		"Classroom", "Police office", "Cells", "Restroom", "Barn stalls", "Hayloft", "Workshop", "Machine bay")
var kind := "None":
	set(value):
		kind = value
		emit_changed()
## Empty: the building's Interior Material.
@export var wall_material: Material:
	set(value):
		wall_material = value
		emit_changed()
## Empty: the building's Floor Material.
@export var floor_material: Material:
	set(value):
		floor_material = value
		emit_changed()


static func make(on_level: int, at: Vector2, what := "None") -> KitRoom:
	var room := KitRoom.new()
	room.level = on_level
	room.point = at
	room.kind = what
	return room
