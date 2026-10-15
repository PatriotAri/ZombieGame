@tool
class_name QuestData
extends Resource
## A quest: who gives it, when it's available, its steps, and what it pays.
## Make one in the FileSystem dock (New Resource > QuestData) and put it in
## res://quests/side/ for it to be in the game. See QUESTS.md.

## Saves go by this: keep it unique, and don't change it once people have saves.
@export var id := ""
@export var title := ""
@export_multiline var description := ""
## The main story: always going, can't be abandoned, never fails. Only one.
@export var main := false
## Who offers it, and who the "reminder" lines on its steps come from (an NPC's name).
@export var giver := ""
## What the giver says when offering it. Give a reply the "accept" action (and
## one "decline"); with no replies, hearing it out accepts it. The main story
## doesn't need one.
@export var offer: QuestDialogue

@export_group("Available")
@export_enum("from_start", "after_main_step", "after_quest") var available := "from_start"
## after_main_step: a main story step's id (available once that step is done).
## after_quest: another quest's id (available once it's completed).
@export var available_after := ""
## Once failed, it can be taken again from its giver. (Abandoned quests always can.)
@export var can_retry := true

@export_group("Failing")
## In-game hours from accepting it to finish it. 0: no limit.
@export var time_limit_hours := 0.0
## It fails if any of these (NPC names) die.
@export var fail_if_dies: Array[String] = []

@export_group("Steps")
@export var steps: Array[QuestStep] = []

@export_group("Finish")
@export var reward_money := 0
@export var reward_items: Dictionary[String, int] = {}
@export_multiline var complete_story := ""
## What the giver says once it's done, when there's nothing else to talk about.
@export var afterword: QuestDialogue
## Shown in the middle of the screen when these events first happen while the
## quest is going: event name -> text.
@export var event_stories: Dictionary[String, String] = {}


func step_index(step_id: String) -> int:
	for i in steps.size():
		if steps[i] and steps[i].id == step_id:
			return i
	return -1
