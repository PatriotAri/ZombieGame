extends HumanNPC
## The woodworker. Bring him materials and he'll make scaffolding, guard posts,
## fences, fence gates, garden plots and camp kits (core/recipes.gd,
## ui/craft_menu.gd). Once he's free (the story has him tied up at the bandit
## camp: HumanNPC.captive) he lives at the police station, so he counts toward
## how many people it holds (world/camps.gd).

const Recipes := preload("res://core/recipes.gd")


## Free: he builds things for you.
func own_business(main: Node) -> Array:
	if captive:
		return []
	return ["Build something", func() -> void: main.craft_menu.open(main.player, display_name, Recipes.WOODWORKER)]
