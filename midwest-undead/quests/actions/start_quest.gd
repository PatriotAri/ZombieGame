@tool
class_name ActionStartQuest
extends QuestAction
## Starts a quest now, as if you'd taken it (it needn't be on offer).

## The quest's id.
@export var quest := ""


func run(q: Node, _quest: Quest) -> void:
	q.start_quest(quest)
