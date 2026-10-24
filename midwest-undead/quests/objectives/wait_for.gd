@tool
class_name ObjectiveWaitFor
extends QuestObjective
## Done once these all hold (quests/conditions/): a flag set, an hour come, a
## quest done, someone dead...

@export var conditions: Array[QuestCondition] = []
## For the map: a quest marker's id. Optional.
@export var marker := ""


func is_done(q: Node, _st: Dictionary) -> bool:
	return q.all_hold(conditions)


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, marker)
