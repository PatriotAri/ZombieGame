extends RefCounted
## The quest markers (quests/quest_manager.gd keeps one): the waypoint over
## where the shown quest's step takes you (with how far it is), and "!" over
## someone with a quest to offer, "?" over someone a quest needs you to talk to.
## What they show is worked out once per change of quest state (the manager
## sets `stale`); where they are, every frame (people move).

const MARKER_HIDE_DISTANCE := 6.0 # the waypoint hides once you're basically there
const NPC_MARKER_RANGE := 45.0 # "!" and "?" show this close

var stale := true
var _q: Node # the quest manager
var _waypoint: Label3D
var _npc_markers := {} # npc -> its "!" / "?" label
var _wanted := {} # NPC name -> "!" or "?"
var _shown_label := "" # the waypoint's name for the shown quest's current step
var _goal_npc_name := "" # the waypoint follows this NPC, or else sits at _goal_pos
var _goal_npc: Node3D
var _goal_pos := Vector3.INF
var _autosave_due := false # the shown step autosaves near its waypoint, and hasn't yet


## Markers for `manager`'s quests (they go under it).
func _init(manager: Node) -> void:
	_q = manager
	_waypoint = Label3D.new()
	_waypoint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_waypoint.no_depth_test = true
	_waypoint.fixed_size = true
	_waypoint.pixel_size = 0.0012
	_waypoint.font_size = 32
	_waypoint.outline_size = 10
	_waypoint.modulate = Color(1.0, 0.85, 0.35)
	manager.add_child(_waypoint)


## Where the shown quest's step takes you, or Vector3.INF.
func objective_position() -> Vector3:
	_refresh()
	if _goal_npc_name == "":
		return _goal_pos
	if not (is_instance_valid(_goal_npc) and _goal_npc.is_inside_tree() and not _goal_npc.get("is_dead")):
		_goal_npc = _q._find_npc(_goal_npc_name) # (not there yet, or died: look again)
	return _goal_npc.global_position if _goal_npc else Vector3.INF


## Whether the shown step wants an autosave near its waypoint (and hasn't had one).
func autosave_due() -> bool:
	_refresh()
	return _autosave_due


## Every frame: puts the markers where they go, or hides them.
func update(player: Node3D) -> void:
	var in_screen: bool = player.get("menu_open") or _q.get_tree().paused
	var target := objective_position()
	var dist := INF if target == Vector3.INF else player.global_position.distance_to(target)
	_waypoint.visible = dist > MARKER_HIDE_DISTANCE and dist != INF and not in_screen
	if _waypoint.visible:
		_waypoint.global_position = target + Vector3(0, 3.2, 0)
		_waypoint.text = "%s\n%d m\n▼" % [_shown_label, roundi(dist)]
	if _wanted.is_empty() or in_screen: # nobody to mark, or a menu's up: just hide them
		for label: Label3D in _npc_markers.values():
			label.visible = false
		return
	for npc in _q.get_tree().get_nodes_in_group("npcs"):
		var who: String = npc.get("display_name")
		var mark: String = _wanted.get(who, "")
		var label: Label3D = _npc_markers.get(npc)
		var show: bool = mark != "" and not npc.get("is_dead") \
				and (npc as Node3D).global_position.distance_squared_to(player.global_position) < NPC_MARKER_RANGE * NPC_MARKER_RANGE
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
			_q.add_child(label)
			_npc_markers[npc] = label
			npc.tree_exiting.connect(func() -> void:
				_npc_markers.erase(npc)
				label.queue_free())
		label.text = mark
		label.visible = true
		label.global_position = (npc as Node3D).global_position + Vector3(0, 2.35, 0)


## Works out again what the markers show, if quest state has changed since.
func _refresh() -> void:
	if not stale:
		return
	stale = false
	_wanted = {}
	for q: QuestData in _q.quests:
		if _q._offerable(q) and q.offer:
			_wanted[q.giver] = _wanted.get(q.giver, "!")
		elif _q.status(q) == _q.ACTIVE:
			var step: QuestStep = _q.current_step(q)
			if step and step.kind == "talk_to":
				_wanted[step.target] = "?"
	var shown: QuestData = _q.shown_quest()
	var step: QuestStep = _q.current_step(shown) if shown else null
	_shown_label = waypoint_label(step)
	_autosave_due = step != null and step.autosave_near and _q._autosave_key(shown, step) not in _q._autosaved
	_goal_npc = null
	_goal_npc_name = ""
	_goal_pos = Vector3.INF
	var goal := _waypoint_goal(step)
	if goal[0] == "npc":
		_goal_npc_name = goal[1]
	else:
		_goal_pos = goal[1]


## Where a step's waypoint is: ["npc", their name] (they move), or ["at", a
## position] (Vector3.INF if none).
func _waypoint_goal(step: QuestStep) -> Array:
	if step == null:
		return ["at", Vector3.INF]
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
				return ["at", Vector3.INF]
	match mode:
		"npc":
			return ["npc", target]
		"place":
			for place: Node3D in _q._map.places:
				if place.get("place_name") == target:
					return ["at", place.global_position]
		"spawn_point":
			for spot: Node3D in _q._map.spawn_points:
				if spot.get("role") == target:
					return ["at", spot.global_position]
	return ["at", Vector3.INF]


## What the waypoint calls a step's destination.
static func waypoint_label(step: QuestStep) -> String:
	if step == null:
		return ""
	if step.marker_label != "":
		return step.marker_label
	return step.waypoint_target if step.waypoint not in ["auto", "none"] else step.target
