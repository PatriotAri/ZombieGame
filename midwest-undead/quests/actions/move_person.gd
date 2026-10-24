@tool
class_name ActionMovePerson
extends QuestAction
## Someone goes to a quest marker (and stays there, saved). They move while
## you're not near either place, so you don't see them pop from one to the other.

## Their Npc Id.
@export var npc := ""
## The quest marker they go to (facing its way).
@export var to := ""


func run(q: Node, _quest: Quest) -> void:
	q.move_person(npc, to)
