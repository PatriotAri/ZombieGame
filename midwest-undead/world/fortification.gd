extends StaticBody3D
## Something the player put up: planks over a door or window, or a freestanding
## barricade. Zombies can't break it (it has no health). Look at it and press
## interact to take it down and get the item back (main.gd hands that to
## fortifications.gd). Built by fortifications.gd.

var kind := "barricade" # or "planks"
var opening := -1 # for planks: the index of the opening it covers (fortifications.gd)
var used := false # planks nailed up from used planks: they won't come down in one piece


func interact_prompt() -> String:
	return "take down the barricade" if kind == "barricade" else "take down the planks"


## The item you get back for it: fresh planks come down as used planks, and
## used planks don't come down in one piece at all ("").
func item_id() -> String:
	if kind == "barricade":
		return "barricade"
	return "" if used else "used_planks"
