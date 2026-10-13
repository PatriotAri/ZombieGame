@tool
class_name QuestReply
extends Resource
## One reply you can pick at the end of a bit of conversation (QuestDialogueNode).

## What you say.
@export var text := "..."
## The id of the node it leads to; empty ends the conversation.
@export var next := ""
## What it does besides: accept or decline the quest being offered, or fail the quest.
@export_enum("none", "accept", "decline", "fail") var action := "none"
