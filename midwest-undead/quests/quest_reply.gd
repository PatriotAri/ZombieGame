@tool
class_name QuestReply
extends Resource
## One reply you can pick at the end of a bit of conversation (QuestDialogueNode).

## What you say.
@export var text := "..."
## The id of the node it leads to; empty ends the conversation.
@export var next := ""
## What it does besides. Quests: accept or decline the quest being offered, or
## fail the quest. Survivors: join (come to the base) or decline (not now).
## "decline" and "fail" end the conversation there.
@export_enum("none", "accept", "decline", "fail", "join") var action := "none"
