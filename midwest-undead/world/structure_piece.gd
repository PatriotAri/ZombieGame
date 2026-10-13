extends StaticBody3D
## Something you built (structures.gd builds and manages them): scaffolding, a
## guard post (on scaffolding it's the top of a guard tower, with a ladder down
## the side), a fence section, a fence gate, a garden plot or an ammo bench.
## Zombies can't break any of it.
## Look at it and press interact to take it down and get it back (what's on top
## of scaffolding has to come down first).

const GameData := preload("res://core/game_data.gd")

var kind := "" # an item id: "scaffold", "guard_post", "fence", "fence_gate"
var below: Node3D = null # the scaffolding it stands on (null: on the ground)
var above: Node3D = null # what stands on it (scaffolding only)
var gate_open := false
var leaf: Node3D = null # fence gates: the part that swings (gate_leaf.gd)
var ladder: Area3D = null # a guard post on scaffolding: the ladder's climbing area
var worker: Node3D = null # garden plots and ammo benches: the survivor working it (base_camp.gd)


## Where its worker stands: just in front of it (its +z side), clear of its edge.
func work_spot() -> Vector3:
	var out := 1.5 if kind == "garden_plot" else 0.95 # half its depth, plus room for them
	return global_transform * Vector3(0, 0.1, out)


func interact_prompt() -> String:
	return "take down the " + GameData.item_name(kind).to_lower()
