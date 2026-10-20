extends HumanNPC
## A survivor holed up in a boarded-up house in town. Talk to them and they join
## you (at a camp with room: you pick which), make their own way there and live
## there. At their camp you can give them a job working a garden plot or ammo
## bench, or post them on a guard post (world/camps.gd); the machinist makes
## ammo benches.
## world/survivors.gd places them, plays what they say (their file in
## characters/npcs/survivors/), and moves them home.

enum State { WAITING, TRAVELLING, HOME }

var state := State.WAITING
var job := "" # "machinist": makes things instead of working a station
var work_piece: Node3D = null # the garden plot or ammo bench they're working
var working := false # has a station (work_piece can read null once it's been taken down)
var camp_name := "" # the base camp they live at (world/camps.gd)
var guard_post: Node3D = null # the guard post they're on, or null


func interact_prompt() -> String:
	return "" if state == State.TRAVELLING else "talk to " + display_name


## At work: bent over the garden, or at a bench.
func _animation() -> Array:
	if working and not talking and is_instance_valid(work_piece):
		return ["work_dig" if work_piece.get("kind") == "garden_plot" else "work_bench", 1.0]
	return super()
