@tool
class_name ConditionHasItem
extends QuestCondition
## You have at least so many of an item on you.

## The item's id (its file in items/data/).
@export var item := ""
@export_range(1, 999) var count := 1


func _check(q: Node) -> bool:
	return q.item_count(item) >= count
