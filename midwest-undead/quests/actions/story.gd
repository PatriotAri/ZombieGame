@tool
class_name ActionStory
extends QuestAction
## Shows text big in the middle of the screen, as a story moment.

@export_multiline var text := ""


func run(q: Node, _quest: Quest) -> void:
	q.story(text)
