extends RefCounted
## Plays a conversation (QuestDialogue): each node's lines in the dialogue box,
## then its replies in the choice menu. Quests (quest_manager.gd) and survivors
## (world/survivors.gd) both talk through this.
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
func play(dialogue: QuestDialogue, who: String, on_finished := Callable(), on_action := Callable()) -> void:
	_show_node(dialogue, dialogue.first() if dialogue else null, who, on_finished, on_action)


## Has a reply with this action somewhere in it.
static func has_action(dialogue: QuestDialogue, action: String) -> bool:
	return dialogue != null and dialogue.nodes.any(func(n: QuestDialogueNode) -> bool:
		return n and n.replies.any(func(r: QuestReply) -> bool: return r and r.action == action))


func _show_node(dialogue: QuestDialogue, node: QuestDialogueNode, who: String, on_finished: Callable,
		on_action: Callable) -> void:
	if node == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	var speaker := node.speaker if node.speaker != "" else who
	var after := func() -> void:
		if node.replies.is_empty():
			_show_node(dialogue, dialogue.find(node.next) if node.next != "" else null, who, on_finished, on_action)
			return
		var options := []
		for reply in node.replies:
			if reply:
				options.append([reply.text, _pick.bind(dialogue, reply, who, on_finished, on_action)])
		var prompt: String = node.lines[node.lines.size() - 1] if not node.lines.is_empty() else ""
		_choices.call("open", _player, speaker, prompt, options)
	if node.lines.is_empty():
		after.call()
	else:
		var lines: Array[String] = []
		lines.assign(node.lines)
		_dialogue.call("start", speaker, lines, _player, after)


func _pick(dialogue: QuestDialogue, reply: QuestReply, who: String, on_finished: Callable, on_action: Callable) -> void:
	if reply.action != "none" and on_action.is_valid():
		on_action.call(reply.action)
	if reply.action in ["decline", "fail"]:
		return # the conversation ends there, without finishing
	if reply.next == "":
		if on_finished.is_valid():
			on_finished.call()
		return
	_show_node(dialogue, dialogue.find(reply.next), who, on_finished, on_action)
