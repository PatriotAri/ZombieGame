@tool
class_name QuestBranch
extends Resource
## Where a stage goes next if these all hold when it's done (QuestStage.branches).

@export var when: Array[QuestCondition] = []
## A stage's id, or "end" (the quest's done).
@export var next := ""
