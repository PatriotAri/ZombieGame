extends RefCounted
## The marks over people's heads (quests/quest_manager.gd keeps one): "!" over
## someone with a quest on offer, "?" over someone a quest needs you to talk
## to, when you're near. Who's marked is worked out again when quest state
## changes (the manager sets `stale`); where the marks are, every frame
## (people move). Where the tracked quest's objectives are goes on the map
## screen instead (quest_manager.gd objective_places()).

const NPC_MARKER_RANGE := 45.0 # meters: marks show this close

var stale := true
var _q: Node # the quest manager
var _npc_markers := {} # person -> their label
var _wanted := {} # npc id -> "!" or "?"


## Marks for `manager`'s quests (they go under it).
func _init(manager: Node) -> void:
	_q = manager


## Every frame: puts the marks where they go, or hides them.
func update(player: Node3D) -> void:
	if stale:
		stale = false
		_wanted = _q.marked_people()
	var in_screen: bool = player.get("menu_open") or _q.get_tree().paused
	if _wanted.is_empty() or in_screen: # nobody to mark, or a menu's up: just hide them
		for label: Label3D in _npc_markers.values():
			label.visible = false
		return
	for person in _q.get_tree().get_nodes_in_group("named_npcs"):
		var mark: String = _wanted.get(person.get("npc_id"), "")
		var label: Label3D = _npc_markers.get(person)
		var show: bool = mark != "" and not person.get("is_dead") \
				and (person as Node3D).global_position.distance_squared_to(player.global_position) < NPC_MARKER_RANGE * NPC_MARKER_RANGE
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
			_npc_markers[person] = label
			person.tree_exiting.connect(func() -> void:
				_npc_markers.erase(person)
				label.queue_free())
		label.text = mark
		label.visible = true
		label.global_position = (person as Node3D).global_position + Vector3(0, 2.35, 0)
