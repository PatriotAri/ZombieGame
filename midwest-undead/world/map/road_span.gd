@tool
extends Marker3D
## A bridge span on a road (world/map/road.gd): put it as a child of the road,
## move it to where the road crosses a gap (a creek, a hollow), and raise it to
## the height the deck should be. Over `length` meters the road is a flat deck
## at that height, with collision, and Apply leaves the ground under it alone:
## the creek keeps flowing below. Put your own supports under it. The road
## climbs to the deck over a short ramp at each end.
## The Map Tools panel's "Add span" button adds one in the middle of the
## selected road.

## Meters of deck, centered on this marker (along the road).
@export_range(2.0, 200.0, 0.5) var length := 12.0:
	set(value):
		length = value
		_road_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_road_changed()


func _ready() -> void:
	set_notify_transform(true)


func _road_changed() -> void:
	var road := get_parent()
	if road and road.has_method("rebuild_later"):
		road.call("rebuild_later")
