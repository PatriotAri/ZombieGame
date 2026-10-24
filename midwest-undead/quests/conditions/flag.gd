@tool
class_name ConditionFlag
extends QuestCondition
## A flag (a named number quests set with the Set Flag action) is at least so
## much. Flags start at 0. Negate: it isn't (so "not set" is Negate on 1).

@export var flag := ""
@export var at_least := 1


func _check(q: Node) -> bool:
	return q.flag(flag) >= at_least
