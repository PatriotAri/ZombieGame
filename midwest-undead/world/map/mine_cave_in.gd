@tool
class_name MineCaveIn
extends StaticBody3D
## A cave-in blocking a mine's tunnel: a heap of rock and broken timber from
## floor to roof. Dig through it with a pickaxe (hold interact: player.gd);
## the digging's kept if you stop and come back. Once dug through it's gone
## for good (the mine remembers: KitMine.save_state). Digging is loud.
## KitMine builds one for each of its Cave Ins.

signal dug_out(cell: Vector3i)

const DIG_TIME := 12.0 # seconds of digging

var cell := Vector3i.ZERO
var progress := 0.0 # seconds dug so far


func interact_prompt() -> String:
	return "a cave-in: it would take a pickaxe to dig through"


func interact(player: Node) -> void:
	player.emit_signal("notify", "Rock and broken timber, floor to roof. It would take a pickaxe.")


## How far through it's been dug, 0-1.
func dug() -> float:
	return clampf(progress / DIG_TIME, 0.0, 1.0)


## A moment's digging (player.gd, holding interact with the pickaxe). True when it's through.
func dig(delta: float) -> bool:
	progress += delta
	if progress < DIG_TIME:
		return false
	dig_out()
	return true


## Gone: out of the way, and zombies' paths go through again.
func dig_out() -> void:
	if not is_inside_tree():
		return
	var at := global_position
	var fortifications := get_tree().get_first_node_in_group("fortifications")
	dug_out.emit(cell)
	get_parent().remove_child(self) # (out before the navigation re-bake reads the scene)
	if fortifications:
		fortifications.call("rebake", at)
	queue_free()
