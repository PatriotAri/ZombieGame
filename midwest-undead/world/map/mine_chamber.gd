@tool
class_name MineChamber
extends Resource
## A big room of a KitMine (a worked-out stope, a cavern): a rectangle of the
## mine's cells, taller than a tunnel. Tunnels that reach its sides open into
## it. Draw them with Map Tools (Mines > Draw chamber).

## Two opposite corners, in the mine's cells: (across, level, along). Its
## floor is on corner_a's level.
@export var corner_a := Vector3i.ZERO:
	set(value):
		corner_a = value
		emit_changed()
@export var corner_b := Vector3i(2, 0, 2):
	set(value):
		corner_b = value
		emit_changed()
## Floor to ceiling (meters). Taller than a level (4 m) and a tunnel one level
## up that reaches its side opens onto a ledge over it.
@export_range(3.0, 16.0, 0.5) var height := 6.0:
	set(value):
		height = value
		emit_changed()


static func make(a: Vector3i, b: Vector3i, tall := 6.0) -> MineChamber:
	var chamber := MineChamber.new()
	chamber.corner_a = a
	chamber.corner_b = b
	chamber.height = tall
	return chamber


func cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(mini(corner_a.x, corner_b.x), maxi(corner_a.x, corner_b.x) + 1):
		for z in range(mini(corner_a.z, corner_b.z), maxi(corner_a.z, corner_b.z) + 1):
			result.append(Vector3i(x, corner_a.y, z))
	return result
