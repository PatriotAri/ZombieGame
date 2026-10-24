@tool
class_name ConditionQuest
extends QuestCondition
## Where another quest (or this one) stands.

## The quest's id.
@export var quest := ""
@export_enum("done", "failed", "active", "not started", "any") var status := "done"
## And it's got to this stage (its id) at some point. Empty: any.
@export var reached_stage := ""


func _check(q: Node) -> bool:
	var now: String = q.status_of(quest)
	var fits := status == "any" or now == status or (status == "not started" and now in ["locked", "available"])
	if fits and reached_stage != "":
		fits = q.reached(quest, reached_stage)
	return fits
