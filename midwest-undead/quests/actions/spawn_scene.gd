@tool
class_name ActionSpawnScene
extends QuestAction
## Something turns up at a quest marker (and stays, saved): the trader's
## wagon, a wrecked car blocking the road. Like people, it waits till you're
## away from the marker, so you don't see it pop in. Only once per marker.

## What: a scene (world/props/wagon.tscn...).
@export var scene: PackedScene
## The quest marker it turns up at (facing its way).
@export var at := ""


func run(q: Node, _quest: Quest) -> void:
	q.spawn_scene(scene, at)
