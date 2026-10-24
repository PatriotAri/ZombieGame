@tool
class_name ActionFailQuest
extends QuestAction
## Fails a quest (the main story can't fail).

## The quest's id. Empty: the one this is part of.
@export var quest := ""
## Shown as why. Empty: the quest's own Fail Text.
@export var why := ""


func run(q: Node, this_quest: Quest) -> void:
	q.fail_quest(quest if quest != "" else (this_quest.id if this_quest else ""), why)
