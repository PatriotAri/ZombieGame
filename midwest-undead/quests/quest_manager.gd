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
##   - timers, people dying, and the "!" / "?" over quest givers' heads;
##   - the tracked quest: its objective on the HUD and its waypoint.
## main.gd creates it, routes NPC conversations here, and saves it.

signal objective_changed(text: String)
## A big story moment shown in the middle of the screen.
signal story_beat(text: String)
## The journal should redraw (a quest changed).
signal changed

const Conversation := preload("res://quests/conversation.gd")

const MAIN_STORY := "res://quests/main_story.tres"
const SIDE_DIR := "res://quests/side/"
const CHECK_INTERVAL := 0.25
const MARKER_HIDE_DISTANCE := 6.0 # the waypoint hides once you're basically there
const NPC_MARKER_RANGE := 45.0 # "!" and "?" show this close

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
var _main: Node # main.gd: places, spawn points
var _player: Node3D
var _dialogue: Node # ui/dialogue_box.gd
var _choices: Node # ui/choice_menu.gd
var _conversation: Conversation
var _zones: Node # world/zones.gd
var _day_night: Node
var _waypoint: Label3D
var _npc_markers := {} # npc -> its "!" / "?" label
var _watched := {} # NPC name -> that NPC, for quests that fail if they die (the dead leave the "npcs" group)
var _timer := 0.0
var _last_hours := -1.0 # the in-game clock, in hours, at the last check
var _beats := PackedStringArray() # story moments this frame, shown together
var _quiet := false # loading a save: no story moments


func _ready() -> void:
	add_to_group("quests")
	process_mode = Node.PROCESS_MODE_ALWAYS # moves the markers; hides them while paused


func setup(main: Node, player: Node3D, dialogue: Node, choices: Node, zones: Node, day_night: Node) -> void:
	_main = main
	_player = player
	_dialogue = dialogue
	_choices = choices
	_conversation = Conversation.new(player, dialogue, choices)
	_zones = zones
	_day_night = day_night
	zones.connect("status_changed", func(zone_name: String, status: int) -> void:
		if status == 0: # Zones.Status.SAFE
			event("zone_cleared:" + zone_name))
	_load_quests()
	for q in quests:
		_state[q.id] = _fresh_state()
	_unlock()
	var story := main_story()
	if story:
		_start_quest(story, false)
		tracked = story.id
	_waypoint = Label3D.new()
	_waypoint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_waypoint.no_depth_test = true
	_waypoint.fixed_size = true
	_waypoint.pixel_size = 0.0012
	_waypoint.font_size = 32
	_waypoint.outline_size = 10
	_waypoint.modulate = Color(1.0, 0.85, 0.35)
	add_child(_waypoint)
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
	return step.objective if step else ""


## Where the shown quest's waypoint is, or Vector3.INF.
func objective_position() -> Vector3:
	var q := shown_quest()
	return _waypoint_position(current_step(q)) if q else Vector3.INF


## The waypoint to autosave near (the current step asks for it and hasn't had
## one yet), or Vector3.INF. Call mark_autosaved() once saved.
func autosave_target() -> Vector3:
	var q := shown_quest()
	var step := current_step(q) if q else null
	if step == null or not step.autosave_near or _autosave_key(q, step) in _autosaved:
		return Vector3.INF
	return _waypoint_position(step)


func mark_autosaved() -> void:
	var q := shown_quest()
	var step := current_step(q) if q else null
	if step:
		_autosaved.append(_autosave_key(q, step))


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
		"clear_zone":
			if _zones.call("is_counted") and int(_zones.call("status_of", step.target)) == 0:
				return true
			return _happened_for(q, step, "zone_cleared:" + step.target)
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
	_update_markers()
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
	for place: Node3D in _main.get("places"):
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
## story first). main.gd shows them in a choice menu next to the NPC's own
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


# --- Markers -----------------------------------------------------------------------

func _update_markers() -> void:
	if _player == null or _waypoint == null:
		return
	var in_screen: bool = _player.get("menu_open") or get_tree().paused
	var target := objective_position()
	var dist := INF if target == Vector3.INF else _player.global_position.distance_to(target)
	_waypoint.visible = dist > MARKER_HIDE_DISTANCE and dist != INF and not in_screen
	if _waypoint.visible:
		_waypoint.global_position = target + Vector3(0, 3.2, 0)
		_waypoint.text = "%s\n%d m\n▼" % [_waypoint_label(current_step(shown_quest())), roundi(dist)]
	# "!" over someone with a quest to offer, "?" over someone a quest needs you to talk to.
	var wanted := {}
	for q in quests:
		if _offerable(q) and q.offer:
			wanted[q.giver] = wanted.get(q.giver, "!")
		elif status(q) == ACTIVE:
			var step := current_step(q)
			if step and step.kind == "talk_to":
				wanted[step.target] = "?"
	for npc in get_tree().get_nodes_in_group("npcs"):
		var who: String = npc.get("display_name")
		var mark: String = wanted.get(who, "")
		var label: Label3D = _npc_markers.get(npc)
		var show: bool = mark != "" and not npc.get("is_dead") and not in_screen \
				and (npc as Node3D).global_position.distance_to(_player.global_position) < NPC_MARKER_RANGE
		if not show:
			if label:
				label.visible = false
			continue
		if label == null:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.fixed_size = true
			label.pixel_size = 0.0016
			label.font_size = 48
			label.outline_size = 12
			label.modulate = Color(1.0, 0.85, 0.35)
			add_child(label)
			_npc_markers[npc] = label
			npc.tree_exiting.connect(func() -> void:
				_npc_markers.erase(npc)
				label.queue_free())
		label.text = mark
		label.visible = true
		label.global_position = (npc as Node3D).global_position + Vector3(0, 2.35, 0)


func _waypoint_position(step: QuestStep) -> Vector3:
	if step == null:
		return Vector3.INF
	var mode := step.waypoint
	var target := step.waypoint_target
	if mode == "auto":
		match step.kind:
			"talk_to":
				mode = "npc"
				target = step.target
			"go_to_place":
				mode = "place"
				target = step.target
			_:
				return Vector3.INF
	match mode:
		"npc":
			var npc := _find_npc(target)
			return npc.global_position if npc else Vector3.INF
		"place":
			for place: Node3D in _main.get("places"):
				if place.get("place_name") == target:
					return place.global_position
		"spawn_point":
			for spot: Node3D in _main.get("spawn_points"):
				if spot.get("role") == target:
					return spot.global_position
	return Vector3.INF


func _waypoint_label(step: QuestStep) -> String:
	if step == null:
		return ""
	if step.marker_label != "":
		return step.marker_label
	return step.waypoint_target if step.waypoint not in ["auto", "none"] else step.target


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
