@tool
class_name QuestStep
extends Resource
## One step of a quest: what to do, what completes it, and what's said.
##
## Kinds, and what `target` is for each:
##   go_to_place - the name of a Place marker in the town; done when you're within its radius.
##   talk_to     - an NPC's name (Police Chief, Wagon Trader, Woodworker, a survivor's
##                 name...); done when you finish `dialogue` with them.
##   clear_zone  - a zone's name ("Zone 1"); done when no zombies are left in it.
##   event       - a story event's name; done when the game reports it. The game's
##                 events: safe_house_reached, trader_found, woodworker_untied,
##                 woodworker_found, zone_cleared:<zone>, reached:<place>.

## Other steps (and variants) go to this one by its id.
@export var id := ""
## Shown on the HUD and in the journal while it's the current step.
@export_multiline var objective := ""
@export_enum("go_to_place", "talk_to", "clear_zone", "event") var kind := "event"
@export var target := ""
## Done already counts (you went there, or it happened, before this step began).
@export var counts_if_done_earlier := true

@export_group("Talk")
## talk_to: what the target says. Finishing it completes the step.
@export var dialogue: QuestDialogue
## talk_to: other ways it goes if something already happened (the first that fits).
@export var variants: Array[QuestVariant] = []
## What the quest's giver says if you talk to them during this step (when the
## step isn't talking to them).
@export var reminder: QuestDialogue

@export_group("Waypoint")
## Where the waypoint points. auto: the NPC for talk_to, the place for go_to_place.
@export_enum("auto", "none", "place", "npc", "spawn_point") var waypoint := "auto"
## place: a Place's name; npc: an NPC's name; spawn_point: a SpawnPoint role.
@export var waypoint_target := ""
## What the waypoint says. Empty: the target's name.
@export var marker_label := ""
## Autosave when you get near the waypoint during this step (once).
@export var autosave_near := false

@export_group("Story")
## Shown big in the middle of the screen when the step begins (not if it's
## already done the moment it begins).
@export_multiline var start_story := ""
@export_multiline var complete_story := ""
@export var reward_money := 0
@export var reward_items: Dictionary[String, int] = {}
## The step after this one (its id). Empty: the next in the list.
@export var next_step := ""
## In-game hours to do it in; the quest fails if time runs out. 0: no limit.
## (The main story never fails.)
@export var time_limit_hours := 0.0
