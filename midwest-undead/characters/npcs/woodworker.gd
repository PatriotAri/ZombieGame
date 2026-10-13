extends HumanNPC
## The woodworker. The bandits are holding him at their camp; free him and he
## makes his way to the station and sets up in the yard. Bring him materials and
## he'll make scaffolding, guard posts, fences, fence gates and garden plots
## (core/recipes.gd, ui/craft_menu.gd). He lives at the base, so he counts
## toward how many people it holds (world/base_camp.gd).
## world/woodworker_rescue.gd moves him around and keeps track of all that.

enum State { CAPTIVE, TRAVELLING, HOME }

var state := State.HOME


func interact_prompt() -> String:
	match state:
		State.CAPTIVE:
			return "untie " + display_name
		State.TRAVELLING:
			return "" # on his way
	return "talk to " + display_name
