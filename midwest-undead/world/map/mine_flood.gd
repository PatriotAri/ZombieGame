@tool
class_name MineFlood
extends Resource
## A flooded part of a KitMine: a rectangle of its cells on one level, under
## water to Depth meters over that level's floor. Over 3 m a tunnel's flooded
## to its roof: you swim through it holding your breath (player.gd). Zombies
## that wade in deep drown. Draw them with Map Tools (Mines > Flood).

## Two opposite corners, in the mine's cells (across, level, along). The
## water's on corner_a's level.
@export var corner_a := Vector3i.ZERO:
	set(value):
		corner_a = value
		emit_changed()
@export var corner_b := Vector3i(2, 0, 2):
	set(value):
		corner_b = value
		emit_changed()
## Meters of water over the floor (1.3 and over: swimming; 3 and over: to a tunnel's roof).
@export_range(0.3, 16.0, 0.1) var depth := 1.0:
	set(value):
		depth = value
		emit_changed()


static func make(a: Vector3i, b: Vector3i, deep := 1.0) -> MineFlood:
	var flood := MineFlood.new()
	flood.corner_a = a
	flood.corner_b = b
	flood.depth = deep
	return flood


## Its cells' (x, z) range: Rect2i(x, z, across, along).
func rect() -> Rect2i:
	return Rect2i(mini(corner_a.x, corner_b.x), mini(corner_a.z, corner_b.z),
			absi(corner_b.x - corner_a.x) + 1, absi(corner_b.z - corner_a.z) + 1)
