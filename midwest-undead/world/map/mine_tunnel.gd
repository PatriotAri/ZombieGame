@tool
class_name MineTunnel
extends Resource
## One tunnel of a KitMine: a path through the mine's grid, one cell (2.5 m)
## wide and 3 m high, with timber frames along it. Draw them with Map Tools
## (Mines > Draw tunnel) or edit the points here.

## The corners it runs through, in the mine's cells: (across, level, along).
## From one point to the next it runs straight (across first, then along, if
## both change). From one level to another it's a ramp, at least 3 cells
## long for each level it climbs (Map Tools makes it so).
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
	for step in steps():
		result.append(step["cell"])
	return result


## Its cells in order, each {"cell": Vector3i, "floor": its floor at its low
## edge, "rise": how much higher its high edge is (meters; 0 on the flat),
## "up": which way it climbs (x, z)}. From a corner on one level to a corner
## on another it ramps: the cells between climb evenly (the corners stay
## flat); a ramp's cell is keyed on the lower level.
func steps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if points.is_empty():
		return result
	result.append(_flat(points[0]))
	for i in range(1, points.size()):
		var from := points[i - 1]
		var to := points[i]
		var path: Array[Vector2i] = []
		var at := Vector2i(from.x, from.z)
		while at.x != to.x:
			at.x += signi(to.x - at.x)
			path.append(at)
		while at.y != to.z:
			at.y += signi(to.z - at.y)
			path.append(at)
		var between := path.size() - 1 # the ramp's cells (the last is the corner)
		for k in path.size():
			var c := path[k]
			if k == between or from.y == to.y:
				result.append(_flat(Vector3i(c.x, to.y if k == between else from.y, c.y)))
				continue
			var prev := path[k - 1] if k > 0 else Vector2i(from.x, from.z)
			var way := c - prev
			var y0 := lerpf(from.y, to.y, float(k) / between) * KitMine.LEVEL
			var y1 := lerpf(from.y, to.y, float(k + 1) / between) * KitMine.LEVEL
			result.append({"cell": Vector3i(c.x, mini(from.y, to.y), c.y), "floor": minf(y0, y1),
					"rise": absf(y1 - y0), "up": way if y1 > y0 else -way})
	return result


static func _flat(cell: Vector3i) -> Dictionary:
	return {"cell": cell, "floor": cell.y * KitMine.LEVEL, "rise": 0.0, "up": Vector2i.ZERO}
