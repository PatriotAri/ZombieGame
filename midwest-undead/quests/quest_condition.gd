@tool
class_name QuestCondition
extends Resource
## Something a quest checks: is it on offer yet, has it failed, which branch to
## take, is a reply there. Each kind is a script in quests/conditions/ (in the
## Inspector: New, then pick its kind). QUESTS.md lists them.

## Holds when the check doesn't ("hasn't got the key", "isn't dead").
@export var negate := false


func holds(q: Node) -> bool:
	return _check(q) != negate


## Each kind's own check. q: the quest manager (quests/quest_manager.gd).
func _check(_q: Node) -> bool:
	return true
