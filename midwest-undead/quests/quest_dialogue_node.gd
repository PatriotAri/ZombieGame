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
## The conversation starts here instead of at the first node while these all
## hold (the first node in the list whose do): the Chief saying something else
## once you've been to the safe house. Replies and Next lead here whatever these say.
@export var start_when: Array[QuestCondition] = []
