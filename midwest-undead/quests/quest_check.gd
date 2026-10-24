@tool
extends RefCounted
## Checks the quests against a map, without playing: what a typo or a missing
## marker would otherwise only show partway through a playthrough. Map Tools'
## Check quests button runs it on the map you have open (and prints the list
## in the Output panel); tests/quest_check_test.gd runs it too.
##
## It looks for:
##   quests: a missing or repeated id; stage, objective and conversation node
##     ids missing or repeated; a Next, branch or Leads To that goes nowhere; a
##     stage nothing leads to; a giver with no offer to make
##   quest markers and people a quest names that aren't on the map (no person
##     marker, survivor spawn point or quest's Spawn Person brings them in);
##     the wrong kind of marker (Use needs a usable one, Stay In and In Area an
##     area); items and zombie kinds that don't exist, events nothing reports,
##     quests that don't exist
##   conversations a reply leads out of to a node that isn't there, or that
##     can't get to an end
##   the map's own quest markers (no id, or two with one) and person markers
##     (no person file, or a file with no id)

const QuestManager := preload("res://quests/quest_manager.gd")
const GameData := preload("res://core/game_data.gd")
const SURVIVORS := "res://characters/npcs/survivors/"
const PEOPLE := "res://characters/npcs/people/"

## What core/game_events.gd and the quest manager report.
const EVENTS := ["zombie_killed", "npc_died", "player_died", "item_gained", "item_lost",
		"container_opened", "area_entered", "area_left", "object_used", "place_discovered",
		"hour_passed", "flag_set", "quest_started", "quest_completed", "quest_failed",
		"stage_reached", "person_freed"]

var _problems: Array[String] = []
var _markers := {} # marker id -> its kind
var _people := {} # npc ids someone or something brings into the game
var _quests := {} # quest id -> Quest
var _where := ""


## Every quest file the game loads (quests/main/, quests/side/), checked
## against map (the map scene's root). Extra: more quests to check alongside
## (made in code, or the examples). The problems found, one line each; none: [].
static func check(map: Node, extra: Array[Quest] = []) -> Array[String]:
	var quests: Array[Quest] = []
	for dir_main: Array in QuestManager.folders:
		for path in QuestManager._quest_files(dir_main[0]):
			var q := load(path) as Quest
			if q:
				quests.append(q)
	quests.append_array(extra)
	var checker := new()
	checker._run(map, quests)
	return checker._problems


func _run(map: Node, quests: Array[Quest]) -> void:
	_read_map(map)
	for q in quests:
		if q.id == "":
			_where = q.resource_path.get_file()
			_problem("has no id")
		elif _quests.has(q.id):
			_where = q.id
			_problem("two quests have this id (%s, %s)" % [_quests[q.id].resource_path.get_file(), q.resource_path.get_file()])
		elif q.id.contains(" "):
			_where = q.id
			_problem("its id has a space in it")
		_quests[q.id] = q
		_bring_in(q)
	for q in quests:
		_check_quest(q)
	_check_people_files()


## The map's quest markers and people (and everyone else who can turn up).
func _read_map(map: Node) -> void:
	if map == null:
		return
	var survivor_spots := {} # the names on "survivor" spawn points: only they turn up
	for node in map.find_children("*", "", true, false):
		if node is KitQuestMarker:
			var m := node as KitQuestMarker
			_where = "map: quest marker %s" % map.get_path_to(m)
			if m.marker_id == "":
				_problem("has no Marker Id")
			elif _markers.has(m.marker_id):
				_problem("another quest marker is \"%s\" too (quests use the first)" % m.marker_id)
			else:
				_markers[m.marker_id] = m.kind
		elif node is KitPersonMarker:
			var pm := node as KitPersonMarker
			_where = "map: person marker %s" % map.get_path_to(pm)
			if pm.person == null:
				_problem("has no person file")
			elif _person_id(pm.person) == "":
				_problem("its person file%s has no id" % _file(pm.person))
			elif _people.has(_person_id(pm.person)):
				_problem("someone else on the map is \"%s\" too" % _person_id(pm.person))
			else:
				_people[_person_id(pm.person)] = true
		elif node is KitSpawnPoint and node.role == "survivor":
			survivor_spots[node.person] = true
		elif node.get("npc_id") is String and node.get("npc_id") != "":
			_people[node.get("npc_id")] = true # someone put straight into the map
	for file in DirAccess.get_files_at(SURVIVORS):
		var s := load(SURVIVORS + file.trim_suffix(".remap")) as SurvivorData
		if s and survivor_spots.has(s.display_name):
			_people[s.npc_id()] = true


## People a quest's Spawn Person brings in count as known.
func _bring_in(q: Quest) -> void:
	for action in _all_actions(q):
		if action is ActionSpawnPerson and action.person and _person_id(action.person) != "":
			_people[_person_id(action.person)] = true


## A person file's id, or else its scene's own Npc Id ("" if neither).
static func _person_id(p: PersonData) -> String:
	if p.id != "" or p.scene == null:
		return p.id
	var state := p.scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"npc_id":
			return str(state.get_node_property_value(0, i))
	return ""


func _check_people_files() -> void:
	for file in DirAccess.get_files_at(PEOPLE):
		var p := load(PEOPLE + file.trim_suffix(".remap")) as PersonData
		if p == null:
			continue
		_where = "person file " + file.trim_suffix(".remap")
		if _person_id(p) == "":
			_problem("has no id")
		_check_dialogue(p.talk, "Talk")
		_check_dialogue(p.untie_talk, "Untie Talk")
	for file in DirAccess.get_files_at(SURVIVORS):
		var s := load(SURVIVORS + file.trim_suffix(".remap")) as SurvivorData
		if s:
			_where = "survivor file " + file.trim_suffix(".remap")
			_check_dialogue(s.join_talk, "Join Talk")
			_check_dialogue(s.base_talk, "Base Talk")


# --- A quest --------------------------------------------------------------------------

func _check_quest(q: Quest) -> void:
	var name := q.id if q.id != "" else q.resource_path.get_file()
	_where = name
	if q.giver != "":
		_person(q.giver, "Giver")
		if q.offer == null:
			_problem("has a Giver but no Offer: there's nothing to take it by")
	_person(q.afterword_from, "Afterword From")
	_conditions(q.available_when, "Available When")
	_conditions(q.fail_when, "Fail When")
	_actions(q.on_start, "On Start")
	_actions(q.on_complete, "On Complete")
	_actions(q.on_fail, "On Fail")
	_items(q.reward_items, "Reward Items")
	_check_dialogue(q.offer, "Offer")
	_check_dialogue(q.afterword, "Afterword")
	if q.stages.is_empty():
		_problem("has no stages")
		return
	var ids := {}
	var labels := [] # each stage by its id, or by its place when that's no good
	for i in q.stages.size():
		var stage := q.stages[i]
		_where = "%s > stage %d" % [name, i + 1]
		labels.append(_where)
		if stage == null:
			_problem("is empty")
			continue
		if stage.id == "":
			_problem("has no id")
		elif ids.has(stage.id):
			_problem("another stage is \"%s\" too" % stage.id)
		else:
			labels[i] = "%s > stage %s" % [name, stage.id]
		ids[stage.id] = true
	for i in q.stages.size():
		if q.stages[i]:
			_where = labels[i]
			_check_stage(q, q.stages[i])
	for i in _unreached(q):
		_where = labels[i]
		_problem("nothing leads to it")


func _check_stage(q: Quest, stage: QuestStage) -> void:
	var here := _where
	_goes_to(q, stage.next, "Next")
	for b in stage.branches:
		if b:
			_goes_to(q, b.next, "a branch's Next")
			_conditions(b.when, "a branch's When")
	_person(stage.reminder_from, "Reminder From")
	_check_dialogue(stage.reminder, "Reminder")
	_actions(stage.on_start, "On Start")
	_actions(stage.on_complete, "On Complete")
	_items(stage.reward_items, "Reward Items")
	var ids := {}
	for i in stage.objectives.size():
		var o := stage.objectives[i]
		var oid := o.id if o and o.id != "" else str(i + 1)
		_where = "%s > objective %s" % [here, oid]
		if o == null:
			_problem("is empty")
			continue
		if ids.has(oid):
			_problem("another objective in the stage is \"%s\" too" % oid)
		ids[oid] = true
		if o.leads_to != "":
			if stage.finish_when != "any":
				_problem("has a Leads To, but its stage finishes when all are done (Leads To only works with any)")
			_goes_to(q, o.leads_to, "Leads To")
		_conditions(o.when, "When")
		_check_objective(o)
	_where = here


## A Next (or a branch's, or a Leads To): "", "end" or a stage of this quest.
func _goes_to(q: Quest, next: String, what: String) -> void:
	if next != "" and next != "end" and q.stage_index(next) < 0:
		_problem("%s \"%s\" isn't one of the quest's stages" % [what, next])


## The stages (their places in the list) nothing can lead to from the first.
static func _unreached(q: Quest) -> Array:
	var seen := {0: true}
	var todo := [0]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		var stage := q.stages[i]
		if stage == null:
			continue
		var nexts := [stage.next]
		for b in stage.branches:
			if b:
				nexts.append(b.next)
		for o in stage.objectives:
			if o and o.leads_to != "":
				nexts.append(o.leads_to)
		for next: String in nexts:
			var to := i + 1 if next == "" else q.stage_index(next)
			if to >= 0 and to < q.stages.size() and not seen.has(to):
				seen[to] = true
				todo.append(to)
	var unreached := []
	for i in q.stages.size():
		if not seen.has(i) and q.stages[i]:
			unreached.append(i)
	return unreached


func _check_objective(o: QuestObjective) -> void:
	if o is ObjectiveGoTo:
		_marker(o.marker, "Marker", "", true)
	elif o is ObjectiveTalkTo:
		_person(o.npc, "Npc", true)
		_check_dialogue(o.dialogue, "Dialogue")
	elif o is ObjectiveCollect:
		_item(o.item, "Item", true)
		_marker(o.marker, "Marker")
	elif o is ObjectiveDeliver:
		_person(o.npc, "Npc", true)
		_item(o.item, "Item", true)
		_check_dialogue(o.dialogue, "Dialogue")
	elif o is ObjectiveKill:
		var kind := ZombieKind.find(o.zombie_kind) if o.zombie_kind != "" else null
		if o.zombie_kind != "" and (kind == null or kind.id != o.zombie_kind):
			_problem("Zombie Kind \"%s\" isn't a zombie kind (characters/zombie/kinds/)" % o.zombie_kind)
		_marker(o.near, "Near")
	elif o is ObjectiveSurvive:
		_marker(o.stay_in, "Stay In", "area")
		if o.until_hour < 0 and o.hours <= 0.0:
			_problem("has no Until Hour and no Hours: it's done at once")
	elif o is ObjectiveUse:
		_marker(o.marker, "Marker", "usable", true)
	elif o is ObjectiveEvent:
		_event(o.event)
		_marker(o.marker, "Marker")
	elif o is ObjectiveWaitFor:
		if o.conditions.is_empty():
			_problem("has nothing to wait for (no Conditions): it's done at once")
		_conditions(o.conditions, "Conditions")
		_marker(o.marker, "Marker")


func _conditions(conditions: Array[QuestCondition], what: String) -> void:
	for c in conditions:
		if c == null:
			_problem("%s has an empty entry" % what)
		elif c is ConditionHasItem:
			_item(c.item, what + ": Item", true)
		elif c is ConditionQuest:
			_quest(c.quest, what + ": Quest", true)
			var other: Quest = _quests.get(c.quest)
			if other and c.reached_stage != "" and other.stage_index(c.reached_stage) < 0:
				_problem("%s: Reached Stage \"%s\" isn't one of %s's stages" % [what, c.reached_stage, c.quest])
		elif c is ConditionFlag:
			if c.flag == "":
				_problem("%s: a flag condition names no flag" % what)
		elif c is ConditionHappened:
			_event(c.event)
		elif c is ConditionInArea:
			_marker(c.marker, what + ": Marker", "area", true)
		elif c is ConditionPersonAlive:
			_person(c.npc, what + ": Npc", true)


func _actions(actions: Array[QuestAction], what: String) -> void:
	for a in actions:
		if a == null:
			_problem("%s has an empty entry" % what)
		elif a is ActionGive or a is ActionTake:
			_items(a.items, what + ": Items")
		elif a is ActionSetFlag:
			if a.flag == "":
				_problem("%s: Set Flag names no flag" % what)
		elif a is ActionStartQuest:
			_quest(a.quest, what + ": Start Quest", true)
		elif a is ActionFailQuest:
			_quest(a.quest, what + ": Fail Quest")
		elif a is ActionNoise:
			_marker(a.marker, what + ": Noise", "", true)
		elif a is ActionSpawnPerson:
			if a.person == null:
				_problem("%s: Spawn Person has no person file" % what)
			elif _person_id(a.person) == "":
				_problem("%s: Spawn Person's person file%s has no id" % [what, _file(a.person)])
			_marker(a.at, what + ": Spawn Person At", "", true)
		elif a is ActionSpawnScene:
			if a.scene == null:
				_problem("%s: Spawn Scene has no scene" % what)
			_marker(a.at, what + ": Spawn Scene At", "", true)
		elif a is ActionMovePerson:
			_person(a.npc, what + ": Move Person", true)
			_marker(a.to, what + ": Move Person To", "", true)
		elif a is ActionRemovePerson:
			_person(a.npc, what + ": Remove Person", true)


## A conversation: node ids, where its replies and Nexts lead, and that it
## can get to an end (not just a decline or fail).
func _check_dialogue(d: QuestDialogue, what: String) -> void:
	if d == null:
		return
	var here := _where
	_where = "%s > %s" % [here, what]
	if d.nodes.is_empty() or d.nodes.has(null):
		_problem("has no nodes" if d.nodes.is_empty() else "has an empty node")
		_where = here
		return
	var ids := {}
	for node in d.nodes:
		if ids.has(node.id):
			_problem("two nodes are \"%s\" (replies lead to the first)" % node.id)
		ids[node.id] = true
	for node in d.nodes:
		if node.next != "" and d.find(node.next) == null:
			_problem("node \"%s\": Next \"%s\" isn't one of its nodes" % [node.id, node.next])
		_conditions(node.start_when, "node \"%s\": Start When" % node.id)
		for r in node.replies:
			if r == null:
				_problem("node \"%s\" has an empty reply" % node.id)
				continue
			if r.next != "" and d.find(r.next) == null:
				_problem("reply \"%s\": Next \"%s\" isn't one of its nodes" % [r.text, r.next])
			_conditions(r.when, "reply \"%s\": When" % r.text)
			_actions(r.actions, "reply \"%s\": Actions" % r.text)
	var ends := _ending_nodes(d)
	var starts := d.nodes.filter(func(n: QuestDialogueNode) -> bool: return not n.start_when.is_empty())
	starts.push_front(d.first())
	for node: QuestDialogueNode in starts:
		if not ends.has(node):
			_problem("starting at node \"%s\", it never gets to an end (every way loops, or declines or fails)" % node.id)
	_where = here


## The nodes from which the conversation can finish.
static func _ending_nodes(d: QuestDialogue) -> Dictionary:
	var ends := {}
	var grew := true
	while grew:
		grew = false
		for node in d.nodes:
			if ends.has(node):
				continue
			var exits := []
			for r in node.replies:
				if r and not r.action in ["decline", "fail"]:
					exits.append(r.next)
			# With no replies, or none whose When holds, it goes on to Next.
			if node.replies.is_empty() or node.replies.all(func(r: QuestReply) -> bool: return r == null or not r.when.is_empty()):
				exits.append(node.next)
			for next: String in exits:
				var to := d.find(next) if next != "" else null
				if to == null or ends.has(to): # (a Next that isn't there ends it too)
					ends[node] = true
					grew = true
					break
	return ends


# --- Names ----------------------------------------------------------------------------

## A quest marker id. kind: the kind it has to be ("" any). needed: empty is a problem.
func _marker(id: String, what: String, kind := "", needed := false) -> void:
	if id == "":
		if needed:
			_problem("%s names no quest marker" % what)
	elif not _markers.has(id):
		_problem("%s: there's no quest marker \"%s\" on the map" % [what, id])
	elif kind != "" and _markers[id] != kind:
		_problem("%s: quest marker \"%s\" is %s; it has to be %s" % [what, id, _a(_markers[id]), _a(kind)])


func _person(id: String, what: String, needed := false) -> void:
	if id == "":
		if needed:
			_problem("%s names nobody" % what)
	elif not _people.has(id):
		_problem("%s: nobody is \"%s\" (no person marker, survivor spawn point or Spawn Person brings them)" % [what, id])


func _item(id: String, what: String, needed := false) -> void:
	if id == "":
		if needed:
			_problem("%s names no item" % what)
	elif not GameData.has_item(id):
		_problem("%s: \"%s\" isn't an item (items/data/)" % [what, id])


func _items(items: Dictionary, what: String) -> void:
	for id in items:
		_item(str(id), what, true)


## needed: empty is a problem (Fail Quest's empty means this one).
func _quest(id: String, what: String, needed := false) -> void:
	if id == "":
		if needed:
			_problem("%s names no quest" % what)
	elif not _quests.has(id):
		_problem("%s: there's no quest \"%s\"" % [what, id])


func _event(event: String) -> void:
	if event == "":
		_problem("names no event")
	elif not event in EVENTS:
		_problem("event \"%s\": nothing reports that (core/game_events.gd lists them)" % event)


## " (its file name)", or "" if it isn't saved in one.
static func _file(r: Resource) -> String:
	return " (%s)" % r.resource_path.get_file() if r.resource_path != "" else ""


static func _a(kind: String) -> String:
	return ("an " if kind == "area" else "a ") + kind + " one"


func _problem(text: String) -> void:
	_problems.append("%s: %s" % [_where, text])


## Every action in a quest, its stages' and its conversations' replies too.
static func _all_actions(q: Quest) -> Array[QuestAction]:
	var found: Array[QuestAction] = []
	found.append_array(q.on_start)
	found.append_array(q.on_complete)
	found.append_array(q.on_fail)
	var dialogues: Array = [q.offer, q.afterword]
	for stage in q.stages:
		if stage == null:
			continue
		found.append_array(stage.on_start)
		found.append_array(stage.on_complete)
		dialogues.append(stage.reminder)
		for o in stage.objectives:
			if o and o.get("dialogue") is QuestDialogue:
				dialogues.append(o.get("dialogue"))
	for d: QuestDialogue in dialogues:
		if d == null:
			continue
		for node in d.nodes:
			if node:
				for r in node.replies:
					if r:
						found.append_array(r.actions)
	return found
