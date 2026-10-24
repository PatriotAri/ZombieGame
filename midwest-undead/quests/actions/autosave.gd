@tool
class_name ActionAutosave
extends QuestAction
## Autosaves, as soon as nothing's after you (a save in the middle of a fight
## could leave you stuck in it).


func run(q: Node, _quest: Quest) -> void:
	q.request_autosave()
