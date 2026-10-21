@tool
class_name MineControl
extends StaticBody3D
## Something you press interact on in a mine (a cage's lever, a call button):
## what it says and what it does are the owner's (world/map/mine_cage.gd).

var prompt: Callable # () -> String
var action: Callable # (player) -> void


func _ready() -> void:
	if not Engine.is_editor_hint():
		Interactable.attach(self, interact_prompt).interacted.connect(_on_interacted)


func interact_prompt() -> String:
	return prompt.call() if prompt.is_valid() else ""


func _on_interacted(actor: Node3D) -> void:
	if action.is_valid():
		action.call(actor)
