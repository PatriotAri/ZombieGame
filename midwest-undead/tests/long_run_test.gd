extends SceneTree
## A smoke test: the real game (main.tscn on the real map) runs for 25 s of game
## time with nothing scripted, and nothing breaks. The runner fails it on any
## script error too.
var main: Node
var f := 0
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 1500:
		var up: int = main.zombies.filter(func(z: Node) -> bool: return not z.is_dead).size()
		check(main.player != null and is_instance_valid(main.player), "the player's there")
		check(up > 0, "zombies are about (%d up, %d in all)" % [up, main.zombies.size()])
		check(main.day_night.hour > main.start_hour, "the clock ran (%.2f)" % main.day_night.hour)
		print("FAILS: %d" % fails)
		return true
	return false
