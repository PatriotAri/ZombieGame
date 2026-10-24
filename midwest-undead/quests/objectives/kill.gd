@tool
class_name ObjectiveKill
extends QuestObjective
## Kill so many zombies, counted from when the stage begins: any kind or one
## kind, anywhere or near a place.

@export_range(1, 999) var count := 10
## A zombie kind's id (characters/zombie/kinds/: walker, runner...). Empty: any.
@export var zombie_kind := ""
## Only near this quest marker (its area, or within Radius of a point marker). Empty: anywhere.
@export var near := ""
@export var radius := 75.0
## Only the ones you kill (not your guards').
@export var only_yours := true


func on_event(q: Node, st: Dictionary, event: StringName, data: Dictionary) -> void:
	if event != &"zombie_killed" or (only_yours and not data.get("by_player", false)):
		return
	if zombie_kind != "" and data.get("kind", "") != zombie_kind:
		return
	if near != "":
		var m: KitQuestMarker = q.world.marker(near)
		if m == null:
			return
		var at: Vector3 = data.get("position", Vector3.INF)
		if m.kind == "area":
			if not m.contains(at):
				return
		elif Vector2(at.x - m.global_position.x, at.z - m.global_position.z).length() > radius:
			return
	st["kills"] = int(st.get("kills", 0)) + 1


func is_done(_q: Node, st: Dictionary) -> bool:
	return int(st.get("kills", 0)) >= count


func progress(_q: Node, st: Dictionary) -> Array:
	return [int(st.get("kills", 0)), count]


func places(q: Node, _st: Dictionary) -> Array:
	var found := place_of(q, near)
	if not found.is_empty() and found[0]["radius"] == 0.0:
		found[0]["radius"] = radius
	return found
