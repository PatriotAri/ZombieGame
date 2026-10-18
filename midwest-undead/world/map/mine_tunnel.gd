@tool
class_name MineTunnel
extends Resource
## One tunnel of a KitMine: a path through the mine's grid, one cell (2.5 m)
## wide and 3 m high, with timber frames along it. Draw them with Map Tools
## (Mines > Draw tunnel) or edit the points here.

## The corners it runs through, in the mine's cells: (across, level, along).
## From one point to the next it runs straight (across first, then along, if
## both change).
@export var points: Array[Vector3i] = []:
	set(value):
		points = value
		emit_changed()
## Rails along it, with sleepers.
@export var rails := false:
	set(value):
		rails = value
		emit_changed()
## Mine carts standing on its rails, at the end where it stops dead (not at an
## entrance or where it meets another tunnel or a chamber: they'd block the way).
@export_range(0, 10) var carts := 0:
	set(value):
		carts = value
		emit_changed()
## Its first or last point opens out of the hill (a timber portal, no end
## wall). Mark one with Map Tools (Mark entrance).
@export var entrance_at_start := false:
	set(value):
		entrance_at_start = value
		emit_changed()
@export var entrance_at_end := false:
	set(value):
		entrance_at_end = value
		emit_changed()


static func make(from: Array[Vector3i], with_rails := false) -> MineTunnel:
	var tunnel := MineTunnel.new()
	tunnel.points = from
	tunnel.rails = with_rails
	return tunnel


## The cells it runs through, in order (each cell once).
func cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if points.is_empty():
		return result
	result.append(points[0])
	for i in range(1, points.size()):
		var at := result[-1]
		var to := points[i]
		at.y = to.y # (phase 2: ramps between levels)
		while at.x != to.x:
			at.x += signi(to.x - at.x)
			result.append(at)
		while at.z != to.z:
			at.z += signi(to.z - at.z)
			result.append(at)
	return result
