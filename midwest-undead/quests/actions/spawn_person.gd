@tool
class_name ActionSpawnPerson
extends QuestAction
## Someone turns up at a quest marker (and stays, saved): the wagon trader
## rolling in, a stranger at the gate. Nothing happens if they're already there.

## Who: their person file (characters/npcs/people/).
@export var person: PersonData
## The quest marker they turn up at (facing its way).
@export var at := ""


func run(q: Node, _quest: Quest) -> void:
	q.spawn_person(person, at)
