@tool
class_name ConditionHappened
extends QuestCondition
## Something has happened at some point (core/game_events.gd lists the events;
## Match narrows it: every key there must equal the event's). Kills, items and
## hours aren't remembered: use a Kill or Collect objective for those.

@export var event := ""
@export var match: Dictionary = {}


func _check(q: Node) -> bool:
	return q.happened(event, match)
