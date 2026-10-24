@tool
class_name ObjectiveDeliver
extends QuestObjective
## Bring someone so many of an item: once you have them, talking to them hands
## them over (they're taken from you) and it's done.

## Their Npc Id.
@export var npc := ""
## The item's id (its file in items/data/).
@export var item := ""
@export_range(1, 999) var count := 1
## What they say as you hand it over. Optional.
@export var dialogue: QuestDialogue
## The label to pick it by when they have more than one thing to talk about.
## Empty: "Give <item>".
@export var choice_label := ""


func talks_to(q: Node, _st: Dictionary, npc_id: String) -> bool:
	return npc_id == npc and q.item_count(item) >= count


func choice_text(q: Node) -> String:
	return choice_label if choice_label != "" else "Give %s" % q.item_name(item)


func talk(q: Node, _st: Dictionary, _npc_id: String, finished: Callable) -> void:
	if q.item_count(item) < count:
		return
	q.take({item: count}, 0)
	if dialogue == null:
		finished.call()
	else:
		q.play(dialogue, npc, finished)


func progress(q: Node, _st: Dictionary) -> Array:
	return [q.item_count(item), count]


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, "", npc)
