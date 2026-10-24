@tool
class_name ActionGive
extends QuestAction
## Gives you items and money.

## Item id -> how many.
@export var items: Dictionary[String, int] = {}
@export var money := 0


func run(q: Node, _quest: Quest) -> void:
	q.give(items, money)
