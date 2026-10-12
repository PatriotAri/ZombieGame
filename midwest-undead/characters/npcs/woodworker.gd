extends "res://characters/npcs/shopkeeper.gd"
## The woodworker. The bandits are holding him at their camp; free him and he
## makes his way to the station, sets up in the yard, and sells what you need to
## build: scaffolding, guard posts, fences and fence gates (world/structures.gd).
## world/woodworker_rescue.gd moves him around and keeps track of all that.

enum State { CAPTIVE, TRAVELLING, HOME }

var state := State.HOME


func interact_prompt() -> String:
	match state:
		State.CAPTIVE:
			return "untie " + display_name
		State.TRAVELLING:
			return "" # on his way
	return super()


func can_trade() -> bool:
	return state == State.HOME and super()
