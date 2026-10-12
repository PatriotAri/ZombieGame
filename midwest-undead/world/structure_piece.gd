extends StaticBody3D
## Something you built (structures.gd builds and manages them): scaffolding, a
## guard post (on scaffolding it's the top of a guard tower, with a ladder down
## the side), a fence section, or a fence gate. Zombies can't break any of it.
## Look at it and press interact to take it down and get it back (what's on top
## of scaffolding has to come down first).

const GameData := preload("res://core/game_data.gd")

var kind := "" # an item id: "scaffold", "guard_post", "fence", "fence_gate"
var below: Node3D = null # the scaffolding it stands on (null: on the ground)
var above: Node3D = null # what stands on it (scaffolding only)
var gate_open := false
var leaf: Node3D = null # fence gates: the part that swings (gate_leaf.gd)
var ladder: Area3D = null # a guard post on scaffolding: the ladder's climbing area


func interact_prompt() -> String:
	return "take down the " + GameData.item_name(kind).to_lower()
