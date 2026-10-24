@tool
class_name MineControl
extends StaticBody3D
## Something you press interact on in a mine (a cage's lever, a call button):
## what it says and what it does are the owner's (world/map/mine_cage.gd).

var prompt: Callable # () -> String
var action: Callable # (player) -> void


func interact_prompt() -> String:
	return prompt.call() if prompt.is_valid() else ""


func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)
