@tool
class_name QuestDialogue
extends Resource
## A conversation: nodes of lines, joined by replies. It starts at the first node.
## Finishing it (reaching a node with nowhere to go) is what completes a "talk to"
## step; declining or failing on the way doesn't.

@export var nodes: Array[QuestDialogueNode] = []


func first() -> QuestDialogueNode:
	return nodes[0] if not nodes.is_empty() else null


## Where it starts: the first node whose Start When holds (q: the quest
## manager, which checks conditions), or else the first.
func start_node(q: Node) -> QuestDialogueNode:
	if q:
		for node in nodes:
			if node and not node.start_when.is_empty() and q.all_hold(node.start_when):
				return node
	return first()


func find(node_id: String) -> QuestDialogueNode:
	for node in nodes:
		if node and node.id == node_id:
			return node
	return null


## A one-node conversation with these lines (handy in code).
static func of(lines: Array[String], speaker := "") -> QuestDialogue:
	var node := QuestDialogueNode.new()
	node.lines = lines
	node.speaker = speaker
	var dialogue := QuestDialogue.new()
	dialogue.nodes = [node]
	return dialogue
