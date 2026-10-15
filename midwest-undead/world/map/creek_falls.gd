@tool
extends Marker3D
## A waterfall on a creek (world/map/creek.gd): put it as a child of the creek
## where the water should drop over a ledge. Upstream of it the creek runs
## level (a pool above the falls) for `pool` meters, then drops all at once
## here, down to wherever the ground takes it. Apply the creek again after
## moving it. The Map Tools panel's "Add falls" button adds one.

## Meters above the falls where the water runs level before the drop.
@export_range(2.0, 60.0, 0.5) var pool := 10.0:
	set(value):
		pool = value
		_creek_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_creek_changed()


func _ready() -> void:
	set_notify_transform(true)


func _creek_changed() -> void:
	var creek := get_parent()
	if creek and creek.has_method("rebuild_later"):
		creek.call("rebuild_later")
