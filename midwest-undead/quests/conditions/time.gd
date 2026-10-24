@tool
class_name ConditionTime
extends QuestCondition
## The time of day is between two hours (it can run past midnight: 20 to 5 is
## the night), and it's at least a certain day.

@export_range(0, 23) var from_hour := 0
@export_range(0, 24) var to_hour := 24
## Day 1 is the first. 0: any day.
@export var from_day := 0


func _check(q: Node) -> bool:
	var hour: float = fmod(q.game_hours(), 24.0)
	var day: int = q.day()
	if from_day > 0 and day < from_day:
		return false
	if from_hour <= to_hour:
		return hour >= from_hour and hour < to_hour
	return hour >= from_hour or hour < to_hour
