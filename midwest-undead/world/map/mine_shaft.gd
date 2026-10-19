@tool
class_name MineShaft
extends Resource
## A shaft of a KitMine: straight up and down through its levels, one cell
## across. Tunnels on the levels it passes that reach its side open into it.
## Put them in with Map Tools (Mines > Place shaft) or here.
##   Ladder: a ladder up one wall, and timber landings (half the shaft) on the
##     levels a tunnel comes in on, to step off onto.
##   Open: nothing to hold on to. A drop to the bottom (it hurts from 4 m up).
##   Cage: an elevator (later).

enum Kind { LADDER, OPEN, CAGE }

## Where it is, in the mine's cells (across, along).
@export var column := Vector2i.ZERO:
	set(value):
		column = value
		emit_changed()
## Its top and bottom levels (the bottom one has a floor).
@export var top := 0:
	set(value):
		top = value
		emit_changed()
@export var bottom := -1:
	set(value):
		bottom = value
		emit_changed()
@export var kind := Kind.LADDER:
	set(value):
		kind = value
		emit_changed()
## It comes out on the surface: no roof, a stone collar and a timber
## headframe at Surface Height (meters over the top level's floor: set it to
## where the ground is, then Apply).
@export var to_surface := false:
	set(value):
		to_surface = value
		emit_changed()
@export_range(3.0, 60.0, 0.1) var surface_height := 6.0:
	set(value):
		surface_height = value
		emit_changed()


static func make(at: Vector2i, from: int, to: int, shaft_kind := Kind.LADDER) -> MineShaft:
	var shaft := MineShaft.new()
	shaft.column = at
	shaft.top = maxi(from, to)
	shaft.bottom = mini(from, to)
	shaft.kind = shaft_kind
	return shaft


## How high its open space goes over the top level's floor.
func rise() -> float:
	return surface_height if to_surface else KitMine.TUNNEL_HEIGHT
