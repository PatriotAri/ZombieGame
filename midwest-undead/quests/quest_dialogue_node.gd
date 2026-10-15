@tool
class_name QuestDialogueNode
extends Resource
## One bit of a conversation: a few lines, then (optionally) replies to pick from.

## Other nodes' replies lead here by this id.
@export var id := "start"
## Who's talking. Empty: whoever you're talking to.
@export var speaker := ""
## Shown one at a time.
@export var lines: Array[String] = []
## Your replies. None: the conversation goes on to `next` (or ends).
@export var replies: Array[QuestReply] = []
## With no replies: the node that comes next. Empty ends the conversation.
@export var next := ""
