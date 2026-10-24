extends Node
## Runs the quests (QUESTS.md): the main story (every Quest file in
## quests/main/) and the side quests (quests/side/). The quests are data
## (quest.gd, quest_stage.gd, and the kinds in objectives/, conditions/ and
## actions/); this is the machinery:
##   - which quests are locked, on offer, going, done, failed or abandoned,
##     which stage each is on, and each objective's progress;
##   - what happens in the game (core/game_events.gd), passed to the
##     objectives, and remembered (but for kills, items and hours) for
##     Happened conditions;
##   - flags, timers, failing, and the people quests bring in, move or send off;
##   - conversations: what each person has to say about quests (talk_options()),
##     played through the dialogue box, with replies in the choice menu;
##   - the "!" and "?" over people's heads (quest_markers.gd), the tracked
##     quest's objectives on the HUD, and where they are for the map.
## The objectives, conditions and actions call back into it (they get it as q):
## the functions under "For the quests' parts" are theirs.
## main.gd makes it, routes conversations here, and saves it.

signal objective_changed(text: String)
## A big story moment shown in the middle of the screen.
signal story_beat(text: String)
## The journal should redraw (a quest changed).
signal changed

const GameEvents := preload("res://core/game_events.gd")
const GameData := preload("res://core/game_data.gd")
const Conversation := preload("res://quests/conversation.gd")
const QuestMarkers := preload("res://quests/quest_markers.gd")

const MAIN_DIR := "res://quests/main/"
const SIDE_DIR := "res://quests/side/"
## Saves from another version of this layout start the quests afresh.
const SAVE_VERSION := 2
const CHECK_INTERVAL := 0.25
const UNLOCK_INTERVAL := 1.0
## Too common to remember for Happened (objectives count them as they come).
const NOT_REMEMBERED: Array[StringName] = [&"zombie_killed", &"item_gained", &"item_lost", &"hour_passed", &"area_left"]
const HISTORY_MAX := 400
## People move or leave only while you're at least this far from where they
## are and where they're going (meters), so you don't see them vanish.
const PERSON_CLEAR := 40.0

## Where a quest stands.
const LOCKED := "locked" # not on offer yet (its Available When doesn't hold)
const AVAILABLE := "available" # its giver is offering it
const ACTIVE := "active"
const DONE := "done"
const FAILED := "failed"
const ABANDONED := "abandoned"

var quests: Array[Quest] = []
## The quest whose objectives show on the HUD and the map (its id), or "".
var tracked := ""
var player: Node3D
var world: Node # world/quest_world.gd: quest markers and people by id
var day_night: Node
var _main: Node
## Quest id -> {"status", "stage" (its id), "objectives": {objective id -> its
## state}, "done": [objective ids], "reached": [stage ids], "hours_left",
## "stage_hours_left"}.
var _state := {}
var _flags := {} # flag -> number
var _history: Array = [] # [event, data]: what's happened, for Happened conditions
## People quests brought in, moved or sent off: npc id -> {"person": their
## person file's path (brought in), "at": [x, y, z], "yaw", "gone": bool}.
var _people := {}
var _pending_people: Array = [] # ["move" or "remove", npc id, marker id]: waiting till you're away
var _autosave_wanted := false
var _conversation: Conversation
var _markers: QuestMarkers
var _timer := 0.0
var _unlock_timer := 0.0
var _last_hours := -1.0
var _beats := PackedStringArray()
var _quiet := false # loading a save: no story moments or announcements
var _checking := false # in _check: a check asked for meanwhile (an action's event) waits for it
var _announced := "" # what _announce last told the HUD and journal (it says again only when it changes)
var _recheck := false


func _ready() -> void:
	add_to_group("quests")
	process_mode = Node.PROCESS_MODE_ALWAYS # moves the markers; hides them while paused


func setup(main: Node, the_player: Node3D, dialogue: Node, choices: Node, quest_world: Node, clock: Node) -> void:
	_main = main
	player = the_player
	world = quest_world
	day_night = clock
	_markers = QuestMarkers.new(self)
	_conversation = Conversation.new(the_player, dialogue, choices)
	_load_quests()
	for q in quests:
		_state[q.id] = _fresh_state()
	var bus := GameEvents.bus()
	if bus:
		bus.happened.connect(_on_event)
	_last_hours = game_hours()
	_unlock()
	_announce()


func _load_quests() -> void:
	for dir_main: Array in [[MAIN_DIR, true], [SIDE_DIR, false]]:
		for path in _quest_files(dir_main[0]):
			var q := load(path) as Quest
			if q == null:
				continue
			q.main = dir_main[1]
			quests.append(q)
	var seen := {}
	for q in quests:
		if q.id == "" or seen.has(q.id):
			push_warning("Quest \"%s\" (%s) needs a unique id." % [q.title, q.resource_path])
		seen[q.id] = true


## Every .tres under dir, its subfolders too, in name order.
static func _quest_files(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		file = file.trim_suffix(".remap") # exported games rename resources
		if file.ends_with(".tres") or file.ends_with(".res"):
			found.append(dir + file)
	var subdirs := Array(DirAccess.get_directories_at(dir))
	subdirs.sort()
	for sub: String in subdirs:
		found.append_array(_quest_files(dir + sub + "/"))
	return found


## Adds a quest that isn't in a file (tests, the debug panel). It's on offer
## or starts as its Available When says, like the others.
func add_quest(q: Quest, is_main := false) -> void:
	q.main = is_main
	quests.append(q)
	_state[q.id] = _fresh_state()
	_unlock()
	_check()


func _fresh_state() -> Dictionary:
	return {"status": LOCKED, "stage": "", "objectives": {}, "done": [], "reached": [],
			"hours_left": 0.0, "stage_hours_left": 0.0}


# --- Queries -------------------------------------------------------------------

func find(quest_id: String) -> Quest:
	for q in quests:
		if q.id == quest_id:
			return q
	return null


func status(q: Quest) -> String:
	return _state[q.id]["status"]


func current_stage(q: Quest) -> QuestStage:
	return q.stage(_state[q.id]["stage"]) if status(q) == ACTIVE else null


## The quest whose objectives show: the tracked one, or the first main story
## quest that's going.
func shown_quest() -> Quest:
	var q := find(tracked)
	if q and status(q) == ACTIVE:
		return q
	for each in quests:
		if each.main and status(each) == ACTIVE:
			return each
	return null


## The shown quest's objectives still to do, one a line (for the HUD).
func objective_text() -> String:
	var q := shown_quest()
	if q == null:
		return ""
	var lines := PackedStringArray()
	for entry in _objectives_of(q):
		if not entry["done"]:
			lines.append(entry["text"] + ("  (optional)" if entry["optional"] else ""))
	return "\n".join(lines)


## The shown quest's objectives' places, for the map: [{"position", "radius",
## "label"}].
func objective_places() -> Array:
	var q := shown_quest()
	var found := []
	if q == null:
		return found
	var stage := current_stage(q)
	for i in stage.objectives.size():
		var obj := stage.objectives[i]
		var oid := _objective_id(stage, i)
		if obj == null or not obj.show_on_map or _is_done(q, stage, oid):
			continue
		var st: Dictionary = _state[q.id]["objectives"].get(oid, {})
		for place: Dictionary in obj.places(self, st):
			place["label"] = obj.map_label if obj.map_label != "" else obj.shown_text(self, st)
			found.append(place)
	return found


## Who to mark: npc id -> "!" (has a quest on offer) or "?" (a quest needs you
## to talk to them).
func marked_people() -> Dictionary:
	var marks := {}
	for q in quests:
		if _offerable(q) and q.offer:
			marks[q.giver] = "!"
	for q in quests:
		var stage := current_stage(q)
		if stage == null:
			continue
		for i in stage.objectives.size():
			var obj := stage.objectives[i]
			var oid := _objective_id(stage, i)
			if obj == null or _is_done(q, stage, oid):
				continue
			var st: Dictionary = _state[q.id]["objectives"].get(oid, {})
			for person in get_tree().get_nodes_in_group("named_npcs"):
				var id: String = person.get("npc_id")
				if not marks.has(id) and obj.talks_to(self, st, id):
					marks[id] = "?"
	return marks


## For the journal: every quest you know about, main story first.
func journal() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for main_first in [true, false]:
		for q in quests:
			if q.main != main_first:
				continue
			var st: Dictionary = _state[q.id]
			if st["status"] in [LOCKED, AVAILABLE, ABANDONED]:
				continue
			var steps := []
			for entry in _objectives_of(q):
				steps.append({"objective": entry["text"] + ("  (optional)" if entry["optional"] and not entry["done"] else ""),
						"done": entry["done"]})
			entries.append({"id": q.id, "title": q.title, "description": q.description, "main": q.main,
					"status": st["status"], "tracked": q.id == tracked, "steps": steps, "hours_left": _hours_left(q)})
	return entries


## Every objective of the stages it's been through (done ones only, for the
## stages it's left) and the one it's on: [{"text", "done", "optional"}].
func _objectives_of(q: Quest) -> Array:
	var st: Dictionary = _state[q.id]
	var list := []
	for stage_id: String in st["reached"]:
		var stage := q.stage(stage_id)
		if stage == null:
			continue
		var current: bool = stage_id == st["stage"] and st["status"] == ACTIVE
		for i in stage.objectives.size():
			var obj := stage.objectives[i]
			if obj == null:
				continue
			var oid := _objective_id(stage, i)
			var done := _is_done(q, stage, oid)
			if not current and not done:
				continue
			var ost: Dictionary = st["objectives"].get(oid, {}) if current else {}
			list.append({"text": obj.shown_text(self, ost), "done": done, "optional": obj.optional})
	return list


## In-game hours left on the quest or its stage, whichever is sooner (INF: no limit).
func _hours_left(q: Quest) -> float:
	var st: Dictionary = _state[q.id]
	if st["status"] != ACTIVE or q.main:
		return INF
	var left := INF
	if q.time_limit_hours > 0.0:
		left = float(st["hours_left"])
	var stage := current_stage(q)
	if stage and stage.time_limit_hours > 0.0:
		left = minf(left, float(st["stage_hours_left"]))
	return left


# --- For the quests' parts (objectives, conditions, actions) --------------------

func status_of(quest_id: String) -> String:
	return _state[quest_id]["status"] if _state.has(quest_id) else ""


## Whether a quest has got to a stage at some point.
func reached(quest_id: String, stage_id: String) -> bool:
	return _state.has(quest_id) and stage_id in _state[quest_id]["reached"]


func item_count(id: String) -> int:
	return int(player.get("inventory").call("count", id)) if player else 0


func item_name(id: String) -> String:
	return GameData.item_name(id)


func flag(flag_name: String) -> int:
	return int(_flags.get(flag_name, 0))


func set_flag(flag_name: String, value: int) -> void:
	_flags[flag_name] = value
	_on_event(&"flag_set", {"flag": flag_name, "value": value})


## Whether this has happened since the game began (every key in match equal to the event's).
func happened(event_name: String, match := {}) -> bool:
	for entry: Array in _history:
		if String(entry[0]) == event_name and matches(entry[1], match):
			return true
	return false


static func matches(data: Dictionary, match: Dictionary) -> bool:
	for key in match:
		if not data.has(key) or str(data[key]) != str(match[key]):
			return false
	return true


func all_hold(conditions: Array[QuestCondition]) -> bool:
	for c in conditions:
		if c and not c.holds(self):
			return false
	return true


func any_holds(conditions: Array[QuestCondition]) -> bool:
	for c in conditions:
		if c and c.holds(self):
			return true
	return false


func npc(id: String) -> HumanNPC:
	return world.npc(id) if world else null


## In-game hours since the game began (day 1, 0:00 is 24).
func game_hours() -> float:
	return float(day_night.get("day")) * 24.0 + float(day_night.get("hour")) if day_night else 0.0


func day() -> int:
	return int(day_night.get("day")) if day_night else 1


func give(items: Dictionary, money: int) -> void:
	for id: String in items:
		if int(items[id]) > 0:
			player.call("give_item", id, int(items[id]))
			player.emit_signal("notify", "Got %s x%d" % [item_name(id), int(items[id])])
	if money > 0:
		player.set("money", int(player.get("money")) + money)
		player.emit_signal("notify", "Got $%d" % money)


func take(items: Dictionary, money: int) -> void:
	for id: String in items:
		player.call("take_item", id, int(items[id]))
	if money > 0:
		player.set("money", maxi(int(player.get("money")) - money, 0))


func story(text: String) -> void:
	_beat(text)


## Plays a conversation, said by this person (their id). finished: called at
## its end; replies' actions act on quest (accept, fail).
func play(dialogue: QuestDialogue, npc_id: String, finished := Callable(), quest: Quest = null) -> void:
	var person := npc(npc_id)
	var who: String = person.display_name if person else npc_id
	_conversation.play(dialogue, who, finished, func(action: String) -> void: _on_reply(action, quest))


func start_quest(quest_id: String) -> void:
	var q := find(quest_id)
	if q and status(q) != ACTIVE and status(q) != DONE:
		_start(q)


func fail_quest(quest_id: String, why := "") -> void:
	var q := find(quest_id)
	if q and status(q) == ACTIVE:
		_fail(q, why)


## Fails the quest an objective of the current stage belongs to.
func fail_current(objective: QuestObjective, why := "") -> void:
	for q in quests:
		var stage := current_stage(q)
		if stage and objective in stage.objectives:
			_fail(q, why)
			return


## Someone (a person file) turns up at a quest marker, unless they're already there.
func spawn_person(someone: PersonData, marker_id: String) -> void:
	var m: KitQuestMarker = world.marker(marker_id)
	if someone == null or someone.id == "" or m == null:
		push_warning("Spawn person: no person file (with an id), or no quest marker \"%s\"." % marker_id)
		return
	var existing := npc(someone.id)
	if existing and not existing.is_dead:
		return
	_people[someone.id] = {"person": someone.resource_path, "at": _vec(m.global_position),
			"yaw": m.global_rotation.y, "gone": false}
	_bring_in(someone.id)


## Someone goes to a quest marker, once you're away from both places.
func move_person(npc_id: String, marker_id: String) -> void:
	_pending_people.append(["move", npc_id, marker_id])


## Someone leaves for good, once you're away from them.
func remove_person(npc_id: String) -> void:
	_pending_people.append(["remove", npc_id, ""])


func request_autosave() -> void:
	_autosave_wanted = true


## Whether a quest wants an autosave (main.gd saves once nothing's after you,
## then calls autosaved()).
func wants_autosave() -> bool:
	return _autosave_wanted


func autosaved() -> void:
	_autosave_wanted = false


# --- Changes -------------------------------------------------------------------------

## Something happened in the game (core/game_events.gd, or set_flag and the
## quests' own events).
func _on_event(event: StringName, data: Dictionary) -> void:
	if _markers:
		_markers.stale = true # (who's marked can hang on what you carry: a delivery)
	if not event in NOT_REMEMBERED:
		var kept := data.duplicate()
		kept.erase("position")
		_history.append([event, kept])
		if _history.size() > HISTORY_MAX:
			_history.pop_front()
	for q in quests:
		var stage := current_stage(q)
		if stage == null:
			continue
		for i in stage.objectives.size():
			var obj := stage.objectives[i]
			var oid := _objective_id(stage, i)
			if obj and not _is_done(q, stage, oid):
				obj.on_event(self, _objective_state(q, oid), event, data)
	_check()


## A story event from the old scripts (world/trader_arrival.gd and the like):
## "story" with its name.
func event(event_name: String) -> void:
	if not happened("story", {"name": event_name}):
		_on_event(&"story", {"name": event_name})


func track(quest_id: String) -> void:
	var q := find(quest_id)
	if q and status(q) == ACTIVE:
		tracked = quest_id
		_announce()


## Gives up a side quest; its giver offers it again.
func abandon(quest_id: String) -> void:
	var q := find(quest_id)
	if q == null or q.main or status(q) != ACTIVE:
		return
	_end_objectives(q)
	_state[q.id]["status"] = ABANDONED
	_notify("Abandoned: " + q.title)
	_untrack(q)
	_announce()


func _start(q: Quest, announce := true) -> void:
	var st: Dictionary = _state[q.id]
	st["status"] = ACTIVE
	st["done"] = []
	st["reached"] = []
	st["hours_left"] = q.time_limit_hours
	_run(q.on_start, q)
	if announce and not _quiet:
		_notify(("New: " if q.main else "New quest: ") + q.title)
	if not q.main or tracked == "" or status_of(tracked) != ACTIVE:
		tracked = q.id # what you just took on is what you're doing
	GameEvents.send(&"quest_started", {"quest": q.id})
	if q.stages.is_empty():
		_complete(q)
		return
	_enter_stage(q, 0)


func _enter_stage(q: Quest, index: int) -> void:
	var st: Dictionary = _state[q.id]
	var stage := q.stages[index]
	st["stage"] = stage.id
	st["objectives"] = {}
	# (Back on a stage it's been on: its objectives start over.)
	st["done"] = Array(st["done"]).filter(func(key: String) -> bool: return not key.begins_with(stage.id + "/"))
	if not stage.id in st["reached"]:
		st["reached"].append(stage.id)
	st["stage_hours_left"] = stage.time_limit_hours
	_begin_objectives(q, stage)
	_run(stage.on_start, q)
	GameEvents.send(&"stage_reached", {"quest": q.id, "stage": stage.id})
	_mark_done(q, stage)
	if _stage_finished(q, stage) == null:
		_beat(stage.start_story)
	_check()


func _begin_objectives(q: Quest, stage: QuestStage) -> void:
	for i in stage.objectives.size():
		if stage.objectives[i]:
			stage.objectives[i].begin(self, _objective_state(q, _objective_id(stage, i)))


func _end_objectives(q: Quest) -> void:
	var stage := current_stage(q)
	if stage == null:
		return
	for i in stage.objectives.size():
		if stage.objectives[i]:
			stage.objectives[i].end(self, _objective_state(q, _objective_id(stage, i)))


## Done objectives marked, finished stages moved on, failed quests failed.
## (Repeats while a stage's ending starts another that's done already.)
func _check() -> void:
	if _checking:
		_recheck = true
		return
	_checking = true
	var moved := true
	var guard := 0
	while (moved or _recheck) and guard < 50:
		moved = false
		_recheck = false
		guard += 1
		for q in quests:
			var stage := current_stage(q)
			if stage == null:
				continue
			_mark_done(q, stage)
			var finished: Variant = _stage_finished(q, stage)
			if finished != null:
				_complete_stage(q, stage, finished)
				moved = true
	_checking = false
	_announce()


func _mark_done(q: Quest, stage: QuestStage) -> void:
	var st: Dictionary = _state[q.id]
	for i in stage.objectives.size():
		var obj := stage.objectives[i]
		var oid := _objective_id(stage, i)
		if obj and not _is_done(q, stage, oid) and obj.is_done(self, _objective_state(q, oid)):
			_set_done(q, stage, oid)


## null while the stage is going; once it's done, the objective that did it
## (finish_when "any"), or true.
func _stage_finished(q: Quest, stage: QuestStage) -> Variant:
	if stage.finish_when == "any":
		for i in stage.objectives.size():
			if stage.objectives[i] and _is_done(q, stage, _objective_id(stage, i)):
				return stage.objectives[i]
		return null if not stage.objectives.is_empty() else true
	for i in stage.objectives.size():
		var obj := stage.objectives[i]
		if obj and not obj.optional and not _is_done(q, stage, _objective_id(stage, i)):
			return null
	return true


func _complete_stage(q: Quest, stage: QuestStage, finished: Variant) -> void:
	_end_objectives(q)
	_reward(stage.reward_money, stage.reward_items)
	_run(stage.on_complete, q)
	_beat(stage.complete_story)
	if status(q) != ACTIVE:
		return # an action ended the quest
	var next := stage.next
	if finished is QuestObjective and (finished as QuestObjective).leads_to != "":
		next = (finished as QuestObjective).leads_to
	for branch in stage.branches:
		if branch and all_hold(branch.when):
			next = branch.next
			break
	var index := q.stage_index(stage.id) + 1 if next == "" else q.stage_index(next)
	if next == "end" or index >= q.stages.size():
		_complete(q)
	elif index < 0:
		push_warning("Quest \"%s\": stage \"%s\" goes to \"%s\", which isn't one of its stages." % [q.id, stage.id, next])
		_complete(q)
	else:
		_enter_stage(q, index)


func _complete(q: Quest) -> void:
	_state[q.id]["status"] = DONE
	_reward(q.reward_money, q.reward_items)
	_run(q.on_complete, q)
	if q.complete_story != "":
		_beat(q.complete_story)
	elif not _quiet:
		_notify("Done: " + q.title)
	GameEvents.send(&"quest_completed", {"quest": q.id})
	_untrack(q)
	_unlock()


func _fail(q: Quest, why := "") -> void:
	if q.main or status(q) != ACTIVE:
		return # the main story never fails
	_end_objectives(q)
	_state[q.id]["status"] = FAILED
	_run(q.on_fail, q)
	var reason := why if why != "" else q.fail_text
	_notify("Failed: %s%s" % [q.title, (" (%s)" % reason) if reason != "" else ""])
	GameEvents.send(&"quest_failed", {"quest": q.id})
	_untrack(q)
	_unlock()


func _untrack(q: Quest) -> void:
	if tracked == q.id:
		tracked = ""
		var next := shown_quest()
		tracked = next.id if next else ""


func _reward(money: int, items: Dictionary) -> void:
	if money > 0 or not items.is_empty():
		give(items, money)


func _run(actions: Array[QuestAction], q: Quest) -> void:
	for action in actions:
		if action:
			action.run(self, q)


## Quests whose time has come: on offer (a giver) or started (none).
func _unlock() -> void:
	for q in quests:
		var s := status(q)
		if s == LOCKED and all_hold(q.available_when):
			if q.giver == "":
				_start(q)
			else:
				_state[q.id]["status"] = AVAILABLE


func _offerable(q: Quest) -> bool:
	if q.giver == "":
		return false
	var s := status(q)
	if s == AVAILABLE or s == ABANDONED or (s == FAILED and q.can_retry):
		return all_hold(q.available_when)
	return false


## Done objectives are kept as "stage/objective" (so the same ids in two stages
## don't mix).
func _is_done(q: Quest, stage: QuestStage, oid: String) -> bool:
	return "%s/%s" % [stage.id, oid] in _state[q.id]["done"]


func _set_done(q: Quest, stage: QuestStage, oid: String) -> void:
	if not _is_done(q, stage, oid):
		_state[q.id]["done"].append("%s/%s" % [stage.id, oid])


func _objective_id(stage: QuestStage, index: int) -> String:
	var obj := stage.objectives[index]
	return obj.id if obj and obj.id != "" else str(index + 1)


func _objective_state(q: Quest, oid: String) -> Dictionary:
	var all: Dictionary = _state[q.id]["objectives"]
	if not all.has(oid):
		all[oid] = {}
	return all[oid]


# --- Every so often ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if player and _markers:
		_markers.update(player)
	_timer -= delta
	if _timer > 0.0 or player == null:
		return
	_timer = CHECK_INTERVAL
	_tick_objectives()
	_tick_clock()
	_check_failing()
	_move_people()
	_check()
	_unlock_timer -= CHECK_INTERVAL
	if _unlock_timer <= 0.0:
		_unlock_timer = UNLOCK_INTERVAL
		_unlock()


func _tick_objectives() -> void:
	for q in quests:
		var stage := current_stage(q)
		if stage == null:
			continue
		for i in stage.objectives.size():
			var obj := stage.objectives[i]
			if obj and obj.has_method("tick") and not _is_done(q, stage, _objective_id(stage, i)):
				obj.call("tick", self, _objective_state(q, _objective_id(stage, i)))


func _tick_clock() -> void:
	var now := game_hours()
	var passed := maxf(now - _last_hours, 0.0)
	_last_hours = now
	if passed <= 0.0:
		return
	for q in quests:
		if status(q) != ACTIVE or q.main:
			continue
		var st: Dictionary = _state[q.id]
		if q.time_limit_hours > 0.0:
			st["hours_left"] = float(st["hours_left"]) - passed
			if st["hours_left"] <= 0.0:
				_fail(q, "out of time")
				continue
		var stage := current_stage(q)
		if stage and stage.time_limit_hours > 0.0:
			st["stage_hours_left"] = float(st["stage_hours_left"]) - passed
			if st["stage_hours_left"] <= 0.0:
				_fail(q, "out of time")


func _check_failing() -> void:
	for q in quests:
		if status(q) == ACTIVE and not q.main and not q.fail_when.is_empty() and any_holds(q.fail_when):
			_fail(q)


# --- People ------------------------------------------------------------------------------

## Brings in someone _people says a quest brought (spawn_person, or loading).
func _bring_in(id: String) -> void:
	var entry: Dictionary = _people[id]
	if entry.get("gone", false) or not ResourceLoader.exists(str(entry.get("person", ""))):
		return
	var existing := npc(id)
	if existing and not existing.is_dead:
		return
	var person := (load(entry["person"]) as PersonData).make()
	person.position = _from_vec(entry["at"])
	person.rotation.y = float(entry.get("yaw", 0.0))
	if "day_night" in person:
		person.set("day_night", day_night) # a trader restocks each morning
	_main.add_child(person)


## Moves and removals waiting till you're away.
func _move_people() -> void:
	var still: Array = []
	for job: Array in _pending_people:
		var person := npc(job[1])
		if person == null or person.is_dead:
			if job[0] == "move" and person == null:
				still.append(job) # not there yet (a quest brings them in later): it waits
			continue
		var to: Vector3 = person.global_position
		var yaw := person.rotation.y
		if job[0] == "move":
			var m: KitQuestMarker = world.marker(job[2])
			if m == null:
				continue
			to = m.global_position
			yaw = m.global_rotation.y
		if _near_player(person.global_position) or _near_player(to):
			still.append(job)
			continue
		var entry: Dictionary = _people.get(job[1], {})
		if job[0] == "remove":
			entry["gone"] = true
			person.queue_free()
		else:
			person.global_position = to
			person.rotation.y = yaw
			entry["at"] = _vec(to)
			entry["yaw"] = yaw
		_people[job[1]] = entry
	_pending_people = still


func _near_player(at: Vector3) -> bool:
	return player.global_position.distance_squared_to(at) < PERSON_CLEAR * PERSON_CLEAR


# --- Talking -------------------------------------------------------------------------

## What this person has to say about quests: [label, callable] for each.
## main.gd shows them in a choice menu next to their own business (trading,
## building...), or plays a lone one straight away.
func talk_options(person: Node) -> Array:
	var id: String = person.get("npc_id")
	var options := []
	if id == "":
		return options
	for q in quests:
		var stage := current_stage(q)
		if stage != null:
			for i in stage.objectives.size():
				var obj := stage.objectives[i]
				var oid := _objective_id(stage, i)
				var st := _objective_state(q, oid)
				if obj and not _is_done(q, stage, oid) and obj.talks_to(self, st, id):
					var label := obj.choice_text(self)
					options.append([label if label != "" else q.title, _talk.bind(q, stage, oid, id)])
		elif _offerable(q) and q.giver == id and q.offer:
			options.append([q.title + "  (new)", _offer.bind(q)])
	return options


## What someone says when there's nothing about quests: the afterword of the
## last quest they gave that's done. Returns false if there's none.
func afterword(person: Node) -> bool:
	var id: String = person.get("npc_id")
	for i in range(quests.size() - 1, -1, -1):
		var q := quests[i]
		if q.giver == id and id != "" and status(q) == DONE and q.afterword:
			play(q.afterword, id, Callable(), q)
			return true
	return false


func _talk(q: Quest, stage: QuestStage, oid: String, npc_id: String) -> void:
	_objective_of(stage, oid).talk(self, _objective_state(q, oid), npc_id, func() -> void:
		if current_stage(q) == stage and not _is_done(q, stage, oid): # (nothing else moved it on meanwhile)
			_set_done(q, stage, oid)
			_check())


func _objective_of(stage: QuestStage, oid: String) -> QuestObjective:
	for i in stage.objectives.size():
		if _objective_id(stage, i) == oid:
			return stage.objectives[i]
	return null


func _offer(q: Quest) -> void:
	var has_accept := Conversation.has_action(q.offer, "accept")
	play(q.offer, q.giver, func() -> void:
		if not has_accept and _offerable(q):
			_start(q), q)


## A reply's action, in a conversation about q.
func _on_reply(action: String, q: Quest) -> void:
	if q == null:
		return
	match action:
		"accept":
			if _offerable(q):
				_start(q)
		"fail":
			_fail(q)


# --- Story moments, HUD --------------------------------------------------------------

func _beat(text: String) -> void:
	if _quiet or text == "":
		return
	if _beats.is_empty():
		_flush_beats.call_deferred()
	_beats.append(text)


## Everything that happened at once shows as one story moment.
func _flush_beats() -> void:
	if not _beats.is_empty():
		story_beat.emit("\n".join(_beats))
	_beats.clear()


func _notify(text: String) -> void:
	if not _quiet and player:
		player.emit_signal("notify", text)


## Tells the HUD, the journal and the marks, if anything they show has
## changed since last time (it's asked after every check).
func _announce() -> void:
	var text := objective_text()
	var now := PackedStringArray([tracked, text])
	for q in quests:
		var st: Dictionary = _state[q.id]
		now.append("%s:%s:%s:%d" % [q.id, st["status"], st["stage"], st["done"].size()])
	var summary := "|".join(now)
	if summary == _announced:
		return
	_announced = summary
	if _markers:
		_markers.stale = true
	objective_changed.emit(text)
	changed.emit()


# --- Saving ----------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"version": SAVE_VERSION, "quests": _state.duplicate(true), "flags": _flags.duplicate(),
			"history": _history.duplicate(true), "people": _people.duplicate(true),
			"pending_people": _pending_people.duplicate(true), "tracked": tracked, "autosave": _autosave_wanted}


## While a save is being put back: no story moments.
func begin_load() -> void:
	_quiet = true


func end_load() -> void:
	_check()
	_quiet = false
	_last_hours = game_hours()
	_announce()


func load_state(data: Dictionary) -> void:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return # an older layout: the quests start afresh
	var saved: Dictionary = data.get("quests", {})
	for q in quests:
		var st := _fresh_state()
		var entry: Dictionary = saved.get(q.id, {})
		for key in st:
			if entry.has(key):
				st[key] = entry[key]
		st["done"] = Array(st["done"]).map(func(s: Variant) -> String: return str(s))
		st["reached"] = Array(st["reached"]).map(func(s: Variant) -> String: return str(s))
		if st["status"] == ACTIVE and q.stage(st["stage"]) == null:
			# The quest file's changed since: back to its first stage.
			push_warning("Quest \"%s\": the saved stage \"%s\" isn't there any more; it starts again." % [q.id, st["stage"]])
			_state[q.id] = st
			_enter_stage(q, 0)
			continue
		_state[q.id] = st
		var stage := current_stage(q)
		if stage:
			_begin_objectives(q, stage) # with what each had (a Use marker offers itself again)
	_flags = data.get("flags", {}).duplicate()
	_history = Array(data.get("history", [])).map(func(e: Variant) -> Array: return [StringName(str(e[0])), e[1]])
	_people = data.get("people", {}).duplicate(true)
	for id: String in _people:
		var entry: Dictionary = _people[id]
		var person := npc(id)
		if entry.get("gone", false):
			if person:
				person.queue_free()
		elif person == null:
			_bring_in(id)
		elif entry.has("at"):
			person.global_position = _from_vec(entry["at"])
			person.rotation.y = float(entry.get("yaw", 0.0))
	_pending_people = Array(data.get("pending_people", []))
	tracked = str(data.get("tracked", ""))
	_autosave_wanted = bool(data.get("autosave", false))


static func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _from_vec(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.ZERO
