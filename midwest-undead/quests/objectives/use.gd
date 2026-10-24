@tool
class_name ObjectiveUse
extends QuestObjective
## Use something: a usable quest marker (it offers itself while this is going).

## The usable quest marker's Marker Id.
@export var marker := ""


func begin(q: Node, _st: Dictionary) -> void:
	q.world.set_usable(marker, true)


func end(q: Node, _st: Dictionary) -> void:
	q.world.set_usable(marker, false)


func on_event(_q: Node, st: Dictionary, event: StringName, data: Dictionary) -> void:
	if event == &"object_used" and data.get("marker", "") == marker:
		st["used"] = true


func is_done(_q: Node, st: Dictionary) -> bool:
	return st.get("used", false)


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, marker)
