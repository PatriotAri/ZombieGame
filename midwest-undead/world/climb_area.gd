extends RefCounted
## A ladder's climbing area: while you're in it you hold on and climb
## (player.gd's enter_ladder / exit_ladder). Guard towers (structures.gd),
## the silo (world/kit/kit_silo.gd) and mine shafts (world/map/kit_mine.gd)
## make theirs here. Each sets its own "top_y" meta (where you can step off at
## the top) and, for a mine's ladder, "landings". Never instanced.

const GameData := preload("res://core/game_data.gd")


## An area with a box of `size` at `center` (in the area's own space). Add it
## to the tree yourself.
static func make(size: Vector3, center: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameData.LAYER_PLAYER
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = center
	area.add_child(col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("enter_ladder"):
			body.call("enter_ladder", area))
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.has_method("exit_ladder"):
			body.call("exit_ladder", area))
	return area
