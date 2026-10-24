@tool
class_name ObjectiveTalkTo
extends QuestObjective
## Talk to someone: done when you get to the end of the conversation (not if
## you walk off, or a reply turns it down). A "?" floats over them meanwhile.

## Their Npc Id.
@export var npc := ""
## What they say. Empty: done as soon as you talk to them.
@export var dialogue: QuestDialogue
## The label to pick it by when they have more than one thing to talk about.
## Empty: the quest's title.
@export var choice_label := ""


func talks_to(_q: Node, _st: Dictionary, npc_id: String) -> bool:
	return npc_id == npc


func choice_text(_q: Node) -> String:
	return choice_label


func talk(q: Node, _st: Dictionary, _npc_id: String, finished: Callable) -> void:
	if dialogue == null:
		finished.call()
		return
	q.play(dialogue, npc, finished)


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, "", npc)
