@tool
class_name ActionRemovePerson
extends QuestAction
## Someone leaves for good (saved), once you're not near them.

## Their Npc Id.
@export var npc := ""


func run(q: Node, _quest: Quest) -> void:
	q.remove_person(npc)
