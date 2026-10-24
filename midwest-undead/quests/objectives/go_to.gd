@tool
class_name ObjectiveGoTo
extends QuestObjective
## Get to a place: a quest marker's area (or, for a point marker, within Radius
## of it). Done the moment you're there, even if you were already.

## The quest marker's Marker Id.
@export var marker := ""
## For a point marker: how close counts (meters). An area marker uses its own.
@export var radius := 8.0


func is_done(q: Node, _st: Dictionary) -> bool:
	var m: KitQuestMarker = q.world.marker(marker)
	if m == null or q.player == null:
		return false
	var at: Vector3 = q.player.global_position
	if m.kind == "area":
		return m.contains(at)
	var d := at - m.global_position
	return Vector2(d.x, d.z).length() <= radius and absf(d.y) <= 4.0


func places(q: Node, _st: Dictionary) -> Array:
	var found := place_of(q, marker)
	if not found.is_empty() and found[0]["radius"] == 0.0:
		found[0]["radius"] = radius
	return found
