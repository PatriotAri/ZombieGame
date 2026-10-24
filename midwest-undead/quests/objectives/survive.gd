@tool
class_name ObjectiveSurvive
extends QuestObjective
## Hold out: until an hour of the day comes round, or for so many hours. With
## Stay In, only time spent in that area counts, and leaving it can fail the quest.

## The hour (0-23) it ends at, the next time it comes round. -1: use Hours.
@export_range(-1, 23) var until_hour := -1
## How long, in in-game hours (when Until Hour is -1).
@export var hours := 1.0
## A quest marker's id (an area): you have to be in it. Empty: anywhere.
@export var stay_in := ""
## With Stay In: leaving the area fails the quest (otherwise the time just
## stops counting while you're away).
@export var leaving_fails := false


func begin(q: Node, st: Dictionary) -> void:
	if st.has("left"):
		return # (from a save)
	var need := hours
	if until_hour >= 0:
		var now := fmod(q.game_hours(), 24.0)
		need = fmod(until_hour - now + 24.0, 24.0)
		if need < 0.01:
			need = 24.0
	st["left"] = need
	st["last"] = q.game_hours()


func on_event(q: Node, st: Dictionary, event: StringName, data: Dictionary) -> void:
	if event == &"area_left" and stay_in != "" and data.get("marker", "") == stay_in and leaving_fails:
		q.fail_current(self, "You left.")


## The quest manager calls this every check.
func tick(q: Node, st: Dictionary) -> void:
	var now: float = q.game_hours()
	var passed := maxf(now - float(st.get("last", now)), 0.0)
	st["last"] = now
	if stay_in == "" or q.world.is_inside(stay_in):
		st["left"] = maxf(float(st.get("left", 0.0)) - passed, 0.0)


func is_done(_q: Node, st: Dictionary) -> bool:
	return st.has("left") and float(st["left"]) <= 0.0


func progress(_q: Node, st: Dictionary) -> Array:
	return [] if not st.has("left") else [0, ceili(float(st["left"]))]


func shown_text(q: Node, st: Dictionary) -> String:
	return text.replace("{hours}", str(ceili(float(st.get("left", hours)))))


func places(q: Node, _st: Dictionary) -> Array:
	return place_of(q, stay_in)
