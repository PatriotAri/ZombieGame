@tool
class_name ActionTake
extends QuestAction
## Takes items and money from you (as much as you have).

## Item id -> how many.
@export var items: Dictionary[String, int] = {}
@export var money := 0


func run(q: Node, _quest: Quest) -> void:
	q.take(items, money)
