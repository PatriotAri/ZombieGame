@tool
class_name ConditionPersonAlive
extends QuestCondition
## Someone is in the world and alive. (Negate: dead, or not there.)

## Their Npc Id.
@export var npc := ""


func _check(q: Node) -> bool:
	var person: HumanNPC = q.npc(npc)
	return person != null and not person.is_dead
