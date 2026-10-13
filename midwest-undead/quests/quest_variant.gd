@tool
class_name QuestVariant
extends Resource
## Another way a "talk to" step can go, when something already happened. E.g.
## the Chief, about to send you to the safe house, notices you've already been:
## different lines, and the story skips ahead.

## Used if this event has happened (see quest_step.gd for event names).
@export var if_event := ""
@export var dialogue: QuestDialogue
## The step to go to afterwards (its id). Empty: the step after this one.
@export var next_step := ""
@export var reward_money := 0
@export var reward_items: Dictionary[String, int] = {}
