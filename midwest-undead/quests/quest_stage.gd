@tool
class_name QuestStage
extends Resource
## One part of a quest: what to do now (its objectives), and where it goes when
## that's done (QUESTS.md).

## Other stages, branches and objectives go to this one by its id. Saves go by
## it too: don't change it once there are saves.
@export var id := ""
## Added to the quest's page in the journal while it's on this stage.
@export_multiline var journal_note := ""
## What to do: each kind is a script in quests/objectives/.
@export var objectives: Array[QuestObjective] = []
## all: done once every objective that isn't optional is. any: done as soon as
## one is (that objective's Leads To can pick where it goes).
@export_enum("all", "any") var finish_when := "all"
## Where it goes when it's done: a stage's id. Empty: the next one in the list
## (or the quest's done, after the last). "end": the quest's done.
@export var next := ""
## Checked in order when it's done: the first whose conditions all hold picks
## the next stage instead.
@export var branches: Array[QuestBranch] = []
## In-game hours for this stage alone; the quest fails if they run out. 0: no limit.
@export var time_limit_hours := 0.0

@export_group("Story")
## Shown big in the middle of the screen as it begins (not if it's already
## done the moment it begins).
@export_multiline var start_story := ""
@export_multiline var complete_story := ""
@export var on_start: Array[QuestAction] = []
@export var reward_money := 0
@export var reward_items: Dictionary[String, int] = {}
@export var on_complete: Array[QuestAction] = []
