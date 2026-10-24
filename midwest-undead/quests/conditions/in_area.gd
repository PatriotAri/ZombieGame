@tool
class_name ConditionInArea
extends QuestCondition
## You're in a quest marker's area right now.

## The area quest marker's Marker Id.
@export var marker := ""


func _check(q: Node) -> bool:
	return q.world.is_inside(marker)
