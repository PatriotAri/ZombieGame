@tool
class_name ActionSetFlag
extends QuestAction
## Sets a flag (a named number: Flag conditions check it), or adds to it.
## Flags are saved and start at 0.

@export var flag := ""
@export var value := 1
## Add Value to the flag instead of setting it.
@export var add := false


func run(q: Node, _quest: Quest) -> void:
	q.set_flag(flag, q.flag(flag) + value if add else value)
