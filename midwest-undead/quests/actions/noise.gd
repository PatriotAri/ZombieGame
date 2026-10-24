@tool
class_name ActionNoise
extends QuestAction
## A noise at a quest marker: every zombie and bandit within Radius comes to see.

## The quest marker's Marker Id.
@export var marker := ""
@export var radius := 30.0


func run(q: Node, _quest: Quest) -> void:
	var m: KitQuestMarker = q.world.marker(marker)
	if m:
		q.get_tree().call_group("noise_listeners", "hear_noise", m.global_position, radius)
