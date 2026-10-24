@tool
class_name QuestObjective
extends Resource
## One thing to do in a quest stage. Each kind is a script in
## quests/objectives/ (in the Inspector: New, then pick its kind); this is what
## they share. QUESTS.md lists them.
##
## A kind keeps what it needs to remember (a count, a start time) in st, a
## dictionary the quest manager saves for it: numbers and text only. q is the
## quest manager (quests/quest_manager.gd): the player, the world, the clock.
## Once an objective is done it stays done.

## What other objectives, stages and saves call it. Empty: its place in the
## stage's list ("1", "2"...).
@export var id := ""
## Shown on the HUD, the journal and the map. {count} and {total} show the
## progress of the kinds that count ("Kill zombies at the farm ({count}/{total})").
@export_multiline var text := ""
## Not needed for the stage to be done: an extra (the journal says so).
@export var optional := false
## In a stage that's done when any objective is: the stage it goes to when it's
## this one. Empty: the stage's own Next.
@export var leads_to := ""
## It can't be done until these all hold too (going to where the trader stands
## only counts once the trader's there).
@export var when: Array[QuestCondition] = []

@export_group("Map")
## Marked on the map screen while it's the tracked quest's (where the kind has
## a place: an area, a person, a spot).
@export var show_on_map := true
## The marker's label on the map. Empty: the text.
@export var map_label := ""


## The stage it's in began (st is empty, or what a save had).
func begin(_q: Node, _st: Dictionary) -> void:
	pass


## The stage is over (done, failed or abandoned), or the game is ending.
func end(_q: Node, _st: Dictionary) -> void:
	pass


## Something happened (core/game_events.gd).
func on_event(_q: Node, _st: Dictionary, _event: StringName, _data: Dictionary) -> void:
	pass


func is_done(_q: Node, _st: Dictionary) -> bool:
	return false


## [have, need] for {count} and {total}; [] if it isn't counted.
func progress(_q: Node, _st: Dictionary) -> Array:
	return []


## Where it is, for the map: [{"position": Vector3, "radius": meters (0: a point)}].
func places(_q: Node, _st: Dictionary) -> Array:
	return []


## Whether talking to this person (an npc_id) right now is about this objective.
func talks_to(_q: Node, _st: Dictionary, _npc_id: String) -> bool:
	return false


## What to pick it by when they have other things to talk about too. Empty:
## the quest's title.
func choice_text(_q: Node) -> String:
	return ""


## You're talking to them about it: plays what's said, then calls finished()
## if it got done (not if you walked off or turned it down).
func talk(_q: Node, _st: Dictionary, _npc_id: String, _finished: Callable) -> void:
	pass


## The text, {count} and {total} filled in.
func shown_text(q: Node, st: Dictionary) -> String:
	var shown := text
	var counted := progress(q, st)
	if counted.size() == 2:
		shown = shown.replace("{count}", str(mini(counted[0], counted[1]))).replace("{total}", str(counted[1]))
	return shown


## The place of a quest marker or person (by id), for places(): [] if neither exists.
static func place_of(q: Node, marker_id: String, npc_id := "") -> Array:
	if marker_id != "":
		var m: KitQuestMarker = q.world.marker(marker_id)
		if m:
			return [{"position": m.global_position, "radius": m.radius if m.kind == "area" else 0.0}]
	if npc_id != "":
		var npc: HumanNPC = q.npc(npc_id)
		if npc and not npc.is_dead:
			return [{"position": npc.global_position, "radius": 0.0}]
	return []
