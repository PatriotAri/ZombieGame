@tool
class_name QuestAction
extends Resource
## Something a quest does: when it starts or ends, when a stage begins or ends,
## or when you pick a reply. Each kind is a script in quests/actions/ (in the
## Inspector: New, then pick its kind). QUESTS.md lists them.


## Each kind's own doing. q: the quest manager (quests/quest_manager.gd);
## quest: the quest it's part of (null for a reply outside a quest).
func run(_q: Node, _quest: Quest) -> void:
	pass
