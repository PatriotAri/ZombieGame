@tool
class_name Quest
extends Resource
## A quest (QUESTS.md): who offers it, when, its stages, how it can fail and
## what it pays. A file in quests/main/ is part of the main story (it can't be
## abandoned and never fails); one in quests/side/ is a side quest.

## Saves go by this: unique, no spaces, and don't change it once there are saves.
@export var id := ""
@export var title := ""
@export_multiline var description := ""
## Who offers it: a person's id (Npc Id). A "!" floats over them while it's on
## offer. Empty: it starts by itself as soon as it's available.
@export var giver := ""
## What the giver says when offering it. A reply with the "accept" action takes
## it (and one with "decline" turns it down for now); with no replies, hearing
## it out takes it.
@export var offer: QuestDialogue

@export_group("Available")
## It's on offer (or starts) once all of these hold. None: from the start.
@export var available_when: Array[QuestCondition] = []
## Once failed it's on offer again. (An abandoned one always is.)
@export var can_retry := true

@export_group("Stages")
## In order: it starts at the first. A stage's Next (or a branch) can jump to
## another by its id.
@export var stages: Array[QuestStage] = []

@export_group("Failing")
## In-game hours from taking it to finish it. 0: no limit.
@export var time_limit_hours := 0.0
## It fails as soon as any of these holds (someone dead, an hour gone by...).
@export var fail_when: Array[QuestCondition] = []
## Shown when it fails. Empty: just "Failed".
@export var fail_text := ""

@export_group("Start and finish")
@export var on_start: Array[QuestAction] = []
@export var reward_money := 0
@export var reward_items: Dictionary[String, int] = {}
@export var on_complete: Array[QuestAction] = []
@export var on_fail: Array[QuestAction] = []
## Shown big in the middle of the screen when it's done.
@export_multiline var complete_story := ""
## What the giver says afterwards, when there's nothing else to talk about.
@export var afterword: QuestDialogue

## Set by quests/quest_manager.gd: it's in quests/main/.
var main := false


func stage_index(stage_id: String) -> int:
	for i in stages.size():
		if stages[i] and stages[i].id == stage_id:
			return i
	return -1


func stage(stage_id: String) -> QuestStage:
	var i := stage_index(stage_id)
	return stages[i] if i >= 0 else null
