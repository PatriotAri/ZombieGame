class_name Saveable
extends Node
## Puts its parent's state in the save file and back (world/save_io.gd gathers
## every one in the game). Two kinds:
##   - a section: one of the game's systems ("structures", "camps", the
##     player). Each adds its own in _ready():
##         Saveable.section(self, "horde", save_state, load_state, Saveable.HORDE)
##   - a thing on the map, by its key (core/save_ids.gd). main.gd adds these
##     when the map loads.
## saves returns the state (anything JSON can hold); loads gets it back on a
## freshly loaded game, only if the save has it: otherwise the thing keeps the
## state a new game gives it.
##
## Loading goes in order (the constants below): the world first, then the
## people in it, then you. finish, when given, runs once everything up to
## finish_order has loaded (the story stays quiet until then).

const GROUP := &"saveables"

# Load order.
const TIME := 0
const STORY := 10
const MAP_THINGS := 20 # containers, doors, mines (by key)
const FORTIFICATIONS := 30
const STRUCTURES := 31
const DISCOVERIES := 32
const GROUND_ITEMS := 40
const ZOMBIES := 41
const HORDE := 42
const BANDITS := 50
const SHOP := 51
const WAGON_TRADER := 52
const WOODWORKER := 53
const SURVIVORS := 54
const CAMPS := 55
const SALVAGE := 56
const STORY_END := 90
const PLAYER := 100

## The section's name, or the thing's key.
var key := ""
var is_thing := false
var order := 0
var save_state := Callable() # () -> Variant
var load_state := Callable() # (Variant) -> void
var finish := Callable() # () -> void
var finish_order := 0


static func section(host: Node, section_name: String, saves: Callable, loads: Callable, load_order: int,
		then: Callable = Callable(), then_order := 0) -> Saveable:
	var it := _make(host, section_name, saves, loads, load_order)
	it.finish = then
	it.finish_order = then_order
	return it


## host: the thing (a Node3D: a door or window made in the game is also saved
## with where it is; core/save_ids.gd).
static func thing(host: Node3D, thing_key: String, saves: Callable, loads: Callable) -> Saveable:
	var it := _make(host, thing_key, saves, loads, MAP_THINGS)
	it.is_thing = true
	return it


static func _make(host: Node, k: String, saves: Callable, loads: Callable, load_order: int) -> Saveable:
	var it := Saveable.new()
	it.name = "Saveable"
	it.key = k
	it.save_state = saves
	it.load_state = loads
	it.order = load_order
	it.add_to_group(GROUP)
	host.add_child(it, false, Node.INTERNAL_MODE_BACK)
	return it
