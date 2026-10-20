extends Node
## What just happened in the game, for anything that wants to know: quests
## (quests/) listen here instead of each system calling them. A system reports
## an event with GameEvents.send(&"zombie_killed", {...}); listeners
## connect to `happened`. main.gd makes the one GameEvents node, first thing,
## so it's there before anything can report. Without one (a test scene), send()
## does nothing.
##
## Events, and what their data holds:
##   zombie_killed    kind (its ZombieKind id), position, by_player
##   npc_died         npc_id ("" for nameless ones: guards, bandits), name, position, by_player
##   player_died      cause
##   item_gained      item, amount (into your inventory: picked up, taken, bought, given)
##   item_lost        item, amount (out of it: stored, sold, handed over; not ammo
##                    loaded, batteries or food used up)
##   container_opened town_id (its path in the map scene), label
##   area_entered     marker (a quest marker's id): you came into its area
##   area_left        marker
##   object_used      marker (a usable quest marker's id)
##   place_discovered place (its name)
##   hour_passed      hour (0-23, the hour just begun), day

signal happened(event: StringName, data: Dictionary)

## While loading a save, nothing is reported: putting the saved game back isn't
## anything happening (world/save_io.gd sets it).
var muted := false

static var _bus: Node


func _enter_tree() -> void:
	_bus = self


func _exit_tree() -> void:
	if _bus == self:
		_bus = null


## Reports an event, if there's a GameEvents node and it isn't muted.
static func send(event: StringName, data := {}) -> void:
	if _bus == null or not is_instance_valid(_bus) or _bus.muted:
		return
	_bus.happened.emit(event, data)


## The game's GameEvents node, or null.
static func bus() -> Node:
	return _bus if is_instance_valid(_bus) else null
