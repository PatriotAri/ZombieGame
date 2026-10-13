extends HumanNPC
## A survivor holed up in a boarded-up house in town. Talk to them and they join
## you (if the base has room): they make their own way to the police station
## and live in the back yard. There you can give them a job working a garden
## plot or ammo bench (world/base_camp.gd); the machinist makes ammo benches.
## world/survivors.gd places them, plays what they say (their file in
## characters/npcs/survivors/), and moves them home.

enum State { WAITING, TRAVELLING, HOME }

var state := State.WAITING
var job := "" # "machinist": makes things instead of working a station
var work_piece: Node3D = null # the garden plot or ammo bench they're working
var working := false # has a station (work_piece can read null once it's been taken down)


func interact_prompt() -> String:
	return "" if state == State.TRAVELLING else "talk to " + display_name
