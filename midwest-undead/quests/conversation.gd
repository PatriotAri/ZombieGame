extends RefCounted
## Plays a conversation (QuestDialogue): each node's lines in the dialogue box,
## then its replies in the choice menu. Quests (quest_manager.gd) and survivors
## (world/survivors.gd) both talk through this.
##
## It starts at the first node whose Start When holds (or the first), offers
## only the replies whose When holds, and does a picked reply's actions. The
## quest manager (found by its group) checks the conditions and does the
## actions; quest is the quest it's about, if any (for "fail this quest").
##
## on_finished: called when it reaches its end (not when a "decline" or "fail"
## reply, or walking away, cuts it short). on_action(action): called with a
## reply's action ("accept", "decline", "fail", "join") when it's picked.

var _player: Node3D
var _dialogue: Node # ui/dialogue_box.gd
var _choices: Node # ui/choice_menu.gd


func _init(player: Node3D, dialogue: Node, choices: Node) -> void:
	_player = player
	_dialogue = dialogue
	_choices = choices


## who: the speaker for nodes that don't name one.
func play(dialogue: QuestDialogue, who: String, on_finished := Callable(), on_action := Callable(),
		quest: Resource = null) -> void:
	var talk := {"dialogue": dialogue, "who": who, "finished": on_finished, "action": on_action, "quest": quest}
	_show_node(talk, dialogue.start_node(_quests()) if dialogue else null)


## Has a reply with this action somewhere in it.
static func has_action(dialogue: QuestDialogue, action: String) -> bool:
	return dialogue != null and dialogue.nodes.any(func(n: QuestDialogueNode) -> bool:
		return n and n.replies.any(func(r: QuestReply) -> bool: return r and r.action == action))


func _quests() -> Node:
	return _player.get_tree().get_first_node_in_group("quests") if _player and _player.is_inside_tree() else null


## The replies to offer: those whose When holds.
func _offered(node: QuestDialogueNode) -> Array[QuestReply]:
	var q := _quests()
	var shown: Array[QuestReply] = []
	for reply in node.replies:
		if reply and (reply.when.is_empty() or (q != null and q.all_hold(reply.when))):
			shown.append(reply)
	return shown


func _show_node(talk: Dictionary, node: QuestDialogueNode) -> void:
	if node == null:
		if (talk["finished"] as Callable).is_valid():
			(talk["finished"] as Callable).call()
		return
	var speaker: String = node.speaker if node.speaker != "" else talk["who"]
	var after := func() -> void:
		var replies := _offered(node)
		if replies.is_empty(): # none (or none that hold): on to Next
			var dialogue: QuestDialogue = talk["dialogue"]
			_show_node(talk, dialogue.find(node.next) if node.next != "" else null)
			return
		var options := []
		for reply in replies:
			options.append([reply.text, _pick.bind(talk, reply)])
		var prompt: String = node.lines[node.lines.size() - 1] if not node.lines.is_empty() else ""
		_choices.call("open", _player, speaker, prompt, options)
	if node.lines.is_empty():
		after.call()
	else:
		var lines: Array[String] = []
		lines.assign(node.lines)
		_dialogue.call("start", speaker, lines, _player, after)


func _pick(talk: Dictionary, reply: QuestReply) -> void:
	if not reply.actions.is_empty():
		var q := _quests()
		if q:
			q.run_actions(reply.actions, talk["quest"])
	var on_action: Callable = talk["action"]
	if reply.action != "none" and on_action.is_valid():
		on_action.call(reply.action)
	if reply.action in ["decline", "fail"]:
		return # the conversation ends there, without finishing
	if reply.next == "":
		if (talk["finished"] as Callable).is_valid():
			(talk["finished"] as Callable).call()
		return
	var dialogue: QuestDialogue = talk["dialogue"]
	_show_node(talk, dialogue.find(reply.next))
