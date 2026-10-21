extends Node
## Runs every quest: the main story (quests/main_story.tres) and the side quests
## (every QuestData file in quests/side/). The quests themselves are data (see
## quest_data.gd, quest_step.gd and QUESTS.md); this is the machinery:
##   - which quests are locked, available, going, done, failed or abandoned,
##     and which step each one is on;
##   - story events the game reports (event()), remembered for good, which
##     complete steps and show the quests' event stories;
##   - conversations: what each NPC has to say about quests (talk_options()),
##     played through the dialogue box, with replies in the choice menu;
##   - timers, people dying, and the "!" / "?" over quest givers' heads
##     (quest_markers.gd);
##   - the tracked quest: its objective on the HUD and its waypoint.
## main.gd creates it; world/people.gd routes NPC conversations here; it saves
## itself.

signal objective_changed(text: String)
## A big story moment shown in the middle of the screen.
signal story_beat(text: String)
## The journal should redraw (a quest changed).
signal changed

const Conversation := preload("res://quests/conversation.gd")
const QuestMarkers := preload("res://quests/quest_markers.gd")
const GameMap := preload("res://world/game_map.gd")

const MAIN_STORY := "res://quests/main_story.tres"
const SIDE_DIR := "res://quests/side/"
const CHECK_INTERVAL := 0.25

## Where a quest stands.
const LOCKED := "locked" # not offered yet (see QuestData.available)
const AVAILABLE := "available"
const ACTIVE := "active"
const DONE := "done"
const FAILED := "failed"
const ABANDONED := "abandoned"

var quests: Array[QuestData] = []
## The quest whose objective and waypoint show (its id), or "".
var tracked := ""
var _state := {} # quest id -> {"status", "step", "step_seq", "hours_left", "step_hours_left", "done_steps", "fails"}
var _events := {} # event name -> its order (1, 2, 3...)
var _seq := 0
var _autosaved: Array[String] = [] # "quest:step" keys already autosaved near
var _map: GameMap # world/game_map.gd: places, spawn points
var _player: Node3D
var _dialogue: Node # ui/dialogue_box.gd
var _choices: Node # ui/choice_menu.gd
var _conversation: Conversation
var _camps: Node # world/camps.gd (kills near a camp)
var _day_night: Node
var _markers: QuestMarkers # the waypoint, and "!" / "?" over people's heads
var _watched := {} # NPC name -> that NPC, for quests that fail if they die (the dead leave the "npcs" group)
var _timer := 0.0
var _last_hours := -1.0 # the in-game clock, in hours, at the last check
var _beats := PackedStringArray() # story moments this frame, shown together
var _quiet := false # loading a save: no story moments


func _ready() -> void:
	add_to_group("quests")
	process_mode = Node.PROCESS_MODE_ALWAYS # moves the markers; hides them while paused
	# No story moments while a save goes back on: quiet from the quests' turn
	# until everything but you is back (components/saveable.gd).
	Saveable.section(self, "quest", save_state, _load_saved, Saveable.STORY, end_load, Saveable.STORY_END)


func setup(map: GameMap, player: Node3D, dialogue: Node, choices: Node, camps: Node, day_night: Node) -> void:
	_map = map
	_player = player
	_markers = QuestMarkers.new(self)
	_dialogue = dialogue
	_choices = choices
	_conversation = Conversation.new(player, dialogue, choices)
	_camps = camps
	_day_night = day_night
	camps.connect("kills_changed", func() -> void:
		_check()
		_announce())
	_load_quests()
	for q in quests:
		_state[q.id] = _fresh_state()
	_unlock()
	var story := main_story()
	if story:
		_start_quest(story, false)
		tracked = story.id
	_last_hours = _game_hours()
	_announce()


func _load_quests() -> void:
	if ResourceLoader.exists(MAIN_STORY):
		quests.append(load(MAIN_STORY))
	var files := DirAccess.get_files_at(SIDE_DIR)
	files.sort()
	for file in files:
		file = file.trim_suffix(".remap") # exported games rename resources
		if file.ends_with(".tres") or file.ends_with(".res"):
			var q := load(SIDE_DIR + file) as QuestData
			if q:
				quests.append(q)
	var seen := {}
	for q in quests:
		if q.id == "" or seen.has(q.id):
			push_warning("Quest \"%s\" needs a unique id (quests/)." % q.title)
		seen[q.id] = true


func _fresh_state() -> Dictionary:
	return {"status": LOCKED, "step": 0, "step_seq": 0, "hours_left": 0.0, "step_hours_left": 0.0,
			"done_steps": [], "fails": 0}


# --- Queries -------------------------------------------------------------------

func main_story() -> QuestData:
	for q in quests:
		if q.main:
			return q
	return null


func find(quest_id: String) -> QuestData:
	for q in quests:
		if q.id == quest_id:
			return q
	return null


func status(q: QuestData) -> String:
	return _state[q.id]["status"]


func current_step(q: QuestData) -> QuestStep:
	var i: int = _state[q.id]["step"]
	return q.steps[i] if i >= 0 and i < q.steps.size() else null


func happened(event_name: String) -> bool:
	return _events.has(event_name)


## The quest whose objective shows: the tracked one, or the main story.
func shown_quest() -> QuestData:
	var q := find(tracked)
	if q and status(q) == ACTIVE:
		return q
	var story := main_story()
	return story if story and status(story) == ACTIVE else null


func objective_text() -> String:
	var q := shown_quest()
	var step := current_step(q) if q else null
	if step and step.kind == "kill_near":
		return step.objective.replace("{count}", str(mini(_camps.call("kills_near", step.target), step.count)))
	return step.objective if step else ""


## Where the shown quest's waypoint is, or Vector3.INF.
func objective_position() -> Vector3:
	return _markers.objective_position()


## The waypoint to autosave near (the current step asks for it and hasn't had
## one yet), or Vector3.INF. Call mark_autosaved() once saved.
func autosave_target() -> Vector3:
	return _markers.objective_position() if _markers.autosave_due() else Vector3.INF


func mark_autosaved() -> void:
	var q := shown_quest()
	var step := current_step(q) if q else null
	if step:
		_autosaved.append(_autosave_key(q, step))
		_markers.stale = true


func _autosave_key(q: QuestData, step: QuestStep) -> String:
	return "%s:%s" % [q.id, step.id]


## For the journal: every quest you know about, main story first.
func journal() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for q in quests:
		var st: Dictionary = _state[q.id]
		if st["status"] in [LOCKED, AVAILABLE] or (st["status"] == ABANDONED):
			continue
		var steps := []
		for i in q.steps.size():
			var step := q.steps[i]
			if step == null:
				continue
			if step.id in st["done_steps"]:
				steps.append({"objective": step.objective, "done": true})
			elif st["status"] == ACTIVE and i == st["step"]:
				steps.append({"objective": step.objective, "done": false})
		entries.append({"id": q.id, "title": q.title, "description": q.description, "main": q.main,
				"status": st["status"], "tracked": q.id == tracked, "steps": steps,
				"hours_left": _hours_left(q)})
	return entries


## In-game hours left on the quest or its step, whichever is sooner (INF: no limit).
func _hours_left(q: QuestData) -> float:
	var st: Dictionary = _state[q.id]
	var left := INF
	if q.time_limit_hours > 0.0:
		left = st["hours_left"]
	var step := current_step(q)
	if step and step.time_limit_hours > 0.0:
		left = minf(left, st["step_hours_left"])
	return left


# --- Changes ---------------------------------------------------------------------

## The game reports something that happened (see quest_step.gd for the names).
## Only the first time counts.
func event(event_name: String) -> void:
	if _events.has(event_name):
		return
	_seq += 1
	_events[event_name] = _seq
	for q in quests:
		if status(q) == ACTIVE and q.event_stories.has(event_name):
			_beat(q.event_stories[event_name])
	_check()


func track(quest_id: String) -> void:
	var q := find(quest_id)
	if q and status(q) == ACTIVE:
		tracked = quest_id
		_announce()


## Gives up a side quest; it can be taken again from its giver.
func abandon(quest_id: String) -> void:
	var q := find(quest_id)
	if q == null or q.main or status(q) != ACTIVE:
		return
	_state[q.id]["status"] = ABANDONED
	_player.emit_signal("notify", "Abandoned: " + q.title)
	_untrack(q)
	_announce()


func _start_quest(q: QuestData, announce := true) -> void:
	var st: Dictionary = _state[q.id]
	st["status"] = ACTIVE
	st["done_steps"] = []
	st["hours_left"] = q.time_limit_hours
	_watch(q)
	if announce and not q.main:
		_player.emit_signal("notify", "New quest: " + q.title)
		tracked = q.id # what you just took on is what you're doing
	_start_step(q, 0, announce)


func _start_step(q: QuestData, index: int, announce := true) -> void:
	var st: Dictionary = _state[q.id]
	if index >= q.steps.size():
		_complete_quest(q)
		return
	st["step"] = index
	st["step_seq"] = _seq
	var step := q.steps[index]
	st["step_hours_left"] = step.time_limit_hours if step else 0.0
	if step == null or _step_done(q, step):
		_complete_step(q) # already done: no fanfare
		return
	if announce and step.start_story != "":
		_beat(step.start_story)
	_announce()


## next_override: a step id to go to instead of the usual next one.
func _complete_step(q: QuestData, next_override := "", money := 0, items := {}) -> void:
	var st: Dictionary = _state[q.id]
	var step := current_step(q)
	var next: int = st["step"] + 1
	if step:
		st["done_steps"].append(step.id)
		_reward(step.reward_money + money, _merged(step.reward_items, items))
		if step.complete_story != "":
			_beat(step.complete_story)
		if step.next_step != "":
			next = q.step_index(step.next_step)
	if next_override != "":
		next = q.step_index(next_override)
	if next < 0:
		push_warning("Quest %s: no step called \"%s\"." % [q.id, next_override if next_override != "" else step.next_step])
		next = q.steps.size()
	_start_step(q, next)


func _complete_quest(q: QuestData) -> void:
	_state[q.id]["status"] = DONE
	_reward(q.reward_money, q.reward_items)
	if q.complete_story != "":
		_beat(q.complete_story)
	elif not q.main:
		_player.emit_signal("notify", "Quest complete: " + q.title)
	_untrack(q)
	_unlock()
	_announce()


func _fail(q: QuestData, why := "") -> void:
	if q.main or status(q) != ACTIVE:
		return # the main story never fails
	var st: Dictionary = _state[q.id]
	st["status"] = FAILED
	st["fails"] += 1
	_beat("Quest failed: %s%s" % [q.title, "\n" + why if why != "" else ""])
	_untrack(q)
	_announce()


func _untrack(q: QuestData) -> void:
	if tracked == q.id:
		var story := main_story()
		tracked = story.id if story and status(story) == ACTIVE else ""


func _reward(money: int, items: Dictionary) -> void:
	if money == 0 and items.is_empty():
		return
	var parts := PackedStringArray()
	if money != 0:
		_player.set("money", int(_player.get("money")) + money)
		parts.append("+$%d" % money)
	for id: String in items:
		_player.call("give_item", id, int(items[id]))
		parts.append("+%d %s" % [int(items[id]), id.replace("_", " ")])
	_player.emit_signal("notify", "  ·  ".join(parts))


static func _merged(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = int(out.get(k, 0)) + int(b[k])
	return out


## Side quests whose time has come become available.
func _unlock() -> void:
	var story := main_story()
	for q in quests:
		if q.main or status(q) != LOCKED:
			continue
		var ready := false
		match q.available:
			"from_start":
				ready = true
			"after_main_step":
				ready = story != null and q.available_after in _state[story.id]["done_steps"]
			"after_quest":
				var other := find(q.available_after)
				ready = other != null and status(other) == DONE
		if ready:
			_state[q.id]["status"] = AVAILABLE
			_markers.stale = true


## Can it be offered by its giver now?
func _offerable(q: QuestData) -> bool:
	var s := status(q)
	return not q.main and (s == AVAILABLE or s == ABANDONED or (s == FAILED and q.can_retry))


# --- Step conditions -------------------------------------------------------------

func _step_done(q: QuestData, step: QuestStep) -> bool:
	match step.kind:
		"event":
			return _happened_for(q, step, step.target)
		"go_to_place":
			return _happened_for(q, step, "reached:" + step.target)
		"kill_near":
			return int(_camps.call("kills_near", step.target)) >= step.count
	return false # talk_to: done by talking


func _happened_for(q: QuestData, step: QuestStep, event_name: String) -> bool:
	if not _events.has(event_name):
		return false
	return step.counts_if_done_earlier or int(_events[event_name]) > int(_state[q.id]["step_seq"])


## Completes whatever's been done; keeps going while steps keep completing.
func _check() -> void:
	for q in quests:
		var guard := 0
		while status(q) == ACTIVE and guard < 64:
			var step := current_step(q)
			if step == null or not _step_done(q, step):
				break
			_complete_step(q)
			guard += 1
	_unlock()


func _process(delta: float) -> void:
	if _player and _markers:
		_markers.update(_player)
	_timer -= delta
	if _timer > 0.0 or _player == null:
		return
	_timer = CHECK_INTERVAL
	_note_places()
	_tick_clock()
	_check_deaths()
	_check()


## "reached:<place>" for every Place you're within the radius of.
func _note_places() -> void:
	for place: Node3D in _map.places:
		var at: Vector3 = place.global_position
		var flat := Vector2(_player.global_position.x - at.x, _player.global_position.z - at.z)
		if flat.length() <= float(place.get("radius")):
			event("reached:" + str(place.get("place_name")))


func _tick_clock() -> void:
	var now := _game_hours()
	var passed := maxf(now - _last_hours, 0.0)
	_last_hours = now
	if passed <= 0.0:
		return
	for q in quests:
		if status(q) != ACTIVE or q.main:
			continue
		var st: Dictionary = _state[q.id]
		var step := current_step(q)
		if q.time_limit_hours > 0.0:
			st["hours_left"] -= passed
			if st["hours_left"] <= 0.0:
				_fail(q, "You ran out of time.")
				continue
		if step and step.time_limit_hours > 0.0:
			st["step_hours_left"] -= passed
			if st["step_hours_left"] <= 0.0:
				_fail(q, "You ran out of time.")


func _check_deaths() -> void:
	for q in quests:
		if status(q) != ACTIVE or q.main or q.fail_if_dies.is_empty():
			continue
		_watch(q)
		for who in q.fail_if_dies:
			var npc: Node = _watched.get(who)
			if npc != null and (not is_instance_valid(npc) or npc.get("is_dead")):
				_fail(q, "%s is dead." % who)
				break


## Remembers the living NPCs a quest needs alive, so it notices when one dies.
func _watch(q: QuestData) -> void:
	for who in q.fail_if_dies:
		var known: Node = _watched.get(who)
		if known == null or not is_instance_valid(known) or known.get("is_dead"):
			var npc := _find_npc(who)
			if npc:
				_watched[who] = npc


func _game_hours() -> float:
	return float(_day_night.get("day")) * 24.0 + float(_day_night.get("hour"))


# --- Talking -----------------------------------------------------------------------

## What this NPC has to say about quests: [label, callable] for each (the main
## story first). world/people.gd shows them in a choice menu next to the NPC's own
## business (trading, building...), or plays a lone one straight away.
func talk_options(npc: Node) -> Array:
	var who: String = npc.get("display_name")
	var options := []
	for q in quests:
		var s := status(q)
		if s == ACTIVE:
			var step := current_step(q)
			if step == null:
				continue
			if step.kind == "talk_to" and step.target == who:
				options.append([q.title, _talk_step.bind(q, who)])
			elif q.giver == who and step.reminder:
				options.append([q.title, _play.bind(step.reminder, who, Callable(), Callable())])
		elif _offerable(q) and q.giver == who and q.offer:
			options.append([q.title + "  (new)", _offer.bind(q, who)])
	return options


## What this NPC says when there's nothing about quests: the afterword of the
## last quest they gave that's done. Returns false if there's none.
func afterword(npc: Node) -> bool:
	var who: String = npc.get("display_name")
	for i in range(quests.size() - 1, -1, -1):
		var q := quests[i]
		if q.giver == who and status(q) == DONE and q.afterword:
			_play(q.afterword, who, Callable(), Callable())
			return true
	return false


func _talk_step(q: QuestData, who: String) -> void:
	var step := current_step(q)
	for variant in step.variants:
		if variant and variant.dialogue and happened(variant.if_event):
			_play(variant.dialogue, who, func() -> void:
				if current_step(q) == step:
					_complete_step(q, variant.next_step, variant.reward_money, variant.reward_items),
					_on_reply.bind(q))
			return
	if step.dialogue == null:
		_complete_step(q)
		return
	_play(step.dialogue, who, func() -> void:
		if current_step(q) == step: # (nothing else moved it on meanwhile)
			_complete_step(q),
			_on_reply.bind(q))


func _offer(q: QuestData, who: String) -> void:
	var has_accept := Conversation.has_action(q.offer, "accept")
	_play(q.offer, who, func() -> void:
		if not has_accept and _offerable(q):
			_start_quest(q),
			_on_reply.bind(q))


## A reply's action, during a conversation about q.
func _on_reply(action: String, q: QuestData) -> void:
	match action:
		"accept":
			if _offerable(q):
				_start_quest(q)
		"fail":
			_fail(q)


## Plays a conversation from its first node (quests/conversation.gd).
func _play(dialogue: QuestDialogue, who: String, on_finished: Callable, on_action: Callable) -> void:
	_conversation.play(dialogue, who, on_finished, on_action)


## The NPC with this name (the living one, if there's one alive; with any_state,
## a dead one too).
func _find_npc(who: String, any_state := false) -> Node3D:
	var dead: Node3D = null
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.get("display_name") != who:
			continue
		if not npc.get("is_dead"):
			return npc
		dead = npc
	return dead if any_state else null


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


func _announce() -> void:
	_markers.stale = true
	objective_changed.emit(objective_text())
	changed.emit()


# --- Saving ----------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"quests": _state.duplicate(true), "events": _events.duplicate(), "seq": _seq, "tracked": tracked,
			"autosaved": _autosaved.duplicate()}


## While a save is being put back: no story moments.
func begin_load() -> void:
	_quiet = true


func end_load() -> void:
	_check()
	_quiet = false
	_last_hours = _game_hours()
	_announce()


func _load_saved(data: Dictionary) -> void:
	begin_load()
	load_state(data)


func load_state(data: Dictionary) -> void:
	if data.has("stage"):
		_load_old_story(data)
		return
	var saved: Dictionary = data.get("quests", {})
	for q in quests:
		var st := _fresh_state()
		var entry: Dictionary = saved.get(q.id, {})
		for key in st:
			if entry.has(key):
				st[key] = entry[key]
		st["step"] = int(st["step"])
		st["step_seq"] = int(st["step_seq"])
		st["fails"] = int(st["fails"])
		st["done_steps"] = Array(st["done_steps"]).map(func(s: Variant) -> String: return str(s))
		_state[q.id] = st
	_events = {}
	var events: Dictionary = data.get("events", {})
	for e in events:
		_events[str(e)] = int(events[e])
	_seq = int(data.get("seq", _events.size()))
	tracked = str(data.get("tracked", ""))
	_autosaved.assign(Array(data.get("autosaved", [])).map(func(s: Variant) -> String: return str(s)))
	_unlock()


## A save from before quests were data: its stage number is the main story's step.
func _load_old_story(data: Dictionary) -> void:
	var story := main_story()
	if story == null:
		return
	var stage := int(data.get("stage", 0))
	var st: Dictionary = _state[story.id]
	st["done_steps"] = []
	for i in mini(stage, story.steps.size()):
		st["done_steps"].append(story.steps[i].id)
	if stage >= story.steps.size():
		st["status"] = DONE
	else:
		st["status"] = ACTIVE
		st["step"] = stage
	if data.get("safe_house_investigated", false):
		_seq += 1
		_events["safe_house_reached"] = _seq
	tracked = story.id
	_unlock()
