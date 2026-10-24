@tool
class_name ObjectiveCollect
extends QuestObjective
## Have so many of an item on you (at once). Done the moment you do, even if
## you had them already. Nothing's taken: a Deliver objective, or a Take
## action, does that.

## The item's id (its file in items/data/, e.g. "health_pack").
@export var item := ""
@export_range(1, 999) var count := 1
## Where to find them, for the map (a quest marker's id). Optional.
@export var marker := ""


func is_done(q: Node, _st: Dictionary) -> bool:
	return q.item_count(item) >= count


func progress(q: Node, _st: Dictionary) -> Array:
	return [q.item_count(item), count]


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, marker)
