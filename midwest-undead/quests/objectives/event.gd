@tool
class_name ObjectiveEvent
extends QuestObjective
## Something happens (core/game_events.gd lists them): e.g. container_opened,
## place_discovered, npc_died, or a quest's own (quest_completed, flag_set).
## Match narrows it: every key there must equal the event's (npc_died with
## {"npc_id": "chief"}).

@export var event := ""
@export var match: Dictionary = {}
@export_range(1, 999) var count := 1
## Already happened before the stage began: counts (once).
@export var counts_if_earlier := false
## For the map: a quest marker's id. Optional.
@export var marker := ""


func begin(q: Node, st: Dictionary) -> void:
	if not st.has("seen"):
		st["seen"] = 1 if counts_if_earlier and q.happened(event, match) else 0


func on_event(q: Node, st: Dictionary, happened: StringName, data: Dictionary) -> void:
	if String(happened) == event and q.matches(data, match):
		st["seen"] = int(st.get("seen", 0)) + 1


func is_done(_q: Node, st: Dictionary) -> bool:
	return int(st.get("seen", 0)) >= count


func progress(_q: Node, st: Dictionary) -> Array:
	return [int(st.get("seen", 0)), count] if count > 1 else []


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, marker)
