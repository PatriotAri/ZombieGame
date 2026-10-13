extends Node
## The base at the police station: how many people live there, how many it can
## hold, who works the garden plots and ammo benches, and the supply crate.
##   - Everyone you've brought in counts: recruited survivors (the machinist
##     too) and the woodworker.
##   - It holds BASE_CAPACITY people, plus PER_STATION for every garden plot
##     or ammo bench (pistol, shell or rifle) someone is working. Nobody needs
##     feeding; this is just how many the place can support.
##   - Talk to a survivor at the base to put them on a free plot or bench
##     (survivors.gd); they stand at it. Take it down and they go back to the yard.
##   - Every morning each worked plot puts food, and each worked bench its ammo,
##     in the supply crate in the station yard: fewer of the bigger rounds.
## The crate is the container in the town scene in the "base_supply_crate" group.
## main.gd creates it. Saved: who works what, and when the crate was last filled.

const Survivor := preload("res://characters/npcs/survivor.gd")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const StructurePiece := preload("res://world/structure_piece.gd")

const BASE_CAPACITY := 10
const PER_STATION := 2
const SUPPLY_HOUR := 7
const FOOD_PER_PLOT := 2 # cans each morning
## Each morning, from each worked bench of that kind: [ammo, how many].
const BENCH_OUTPUT := {
	"ammo_bench": ["pistol_ammo", 10],
	"shell_bench": ["shotgun_shells", 4],
	"rifle_bench": ["rifle_rounds", 2],
}
const CHECK_INTERVAL := 1.0

var crate: Node3D # a LootSpot: main.gd saves it with the other containers
var supplied_day := 1 # the last morning the crate was filled
var _survivors: Node # survivors.gd
var _woodworker: Node # woodworker_rescue.gd
var _structures: Node # structures.gd
var _day_night: Node
var _player: Node3D
var _timer := 0.0


func _ready() -> void:
	add_to_group("base_camp")


func setup(supply_crate: Node3D, survivors: Node, woodworker: Node, structures: Node, day_night: Node, player: Node3D) -> void:
	_survivors = survivors
	_woodworker = woodworker
	_structures = structures
	_day_night = day_night
	_player = player
	crate = supply_crate
	supplied_day = int(day_night.get("day"))


# --- Who's here, and how many fit ----------------------------------------------

func population() -> int:
	var count: int = _survivors.call("recruited_count")
	if _woodworker.call("state") != Woodworker.State.CAPTIVE:
		count += 1
	return count


func capacity() -> int:
	var stations := worked("garden_plot")
	for kind: String in BENCH_OUTPUT:
		stations += worked(kind)
	return BASE_CAPACITY + PER_STATION * stations


func is_full() -> bool:
	return population() >= capacity()


## How many of this kind of station someone is working.
func worked(kind: String) -> int:
	return _stations(kind).filter(func(p: StructurePiece) -> bool: return p.worker != null).size()


func free_station(kind: String) -> StructurePiece:
	for piece in _stations(kind):
		if piece.worker == null:
			return piece
	return null


func _stations(kind: String) -> Array:
	return (_structures.get("pieces") as Array).filter(func(p: StructurePiece) -> bool: return p.kind == kind)


# --- Jobs ----------------------------------------------------------------------

## Puts a survivor at a free station of this kind. Returns false if there isn't one.
func assign(survivor: Survivor, kind: String) -> bool:
	var piece := free_station(kind)
	if piece == null:
		return false
	unassign(survivor)
	piece.worker = survivor
	survivor.work_piece = piece
	survivor.working = true
	survivor.global_position = piece.work_spot()
	var to := piece.global_position - survivor.global_position
	survivor.rotation.y = atan2(-to.x, -to.z) # facing their work
	return true


## Off the job and back to their spot in the yard.
func unassign(survivor: Survivor) -> void:
	var piece: Variant = survivor.work_piece
	if is_instance_valid(piece) and (piece as StructurePiece).worker == survivor:
		(piece as StructurePiece).worker = null
	survivor.work_piece = null
	survivor.working = false
	_survivors.call("go_home_spot", survivor)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	# A station that's been taken down: its worker goes back to the yard.
	for survivor: Survivor in _survivors.get("survivors"):
		if survivor.working and (not is_instance_valid(survivor.work_piece) \
				or not survivor.work_piece in (_structures.get("pieces") as Array)):
			unassign(survivor)
	_resupply()


## Each morning: food from every worked plot, ammo from every worked bench.
func _resupply() -> void:
	var day := int(_day_night.get("day"))
	if day <= supplied_day or float(_day_night.get("hour")) < SUPPLY_HOUR:
		return
	supplied_day = day
	var food := FOOD_PER_PLOT * worked("garden_plot")
	var total := food
	var inventory: RefCounted = crate.get("inventory")
	inventory.call("add", "canned_food", food)
	for kind: String in BENCH_OUTPUT:
		var amount: int = BENCH_OUTPUT[kind][1] * worked(kind)
		inventory.call("add", BENCH_OUTPUT[kind][0], amount)
		total += amount
	if total > 0:
		_player.emit_signal("notify", "Fresh supplies in the station's supply crate.")


# --- Saving ---------------------------------------------------------------------

func save_state() -> Dictionary:
	var workers := {}
	var survivors: Array = _survivors.get("survivors")
	var pieces: Array = _structures.get("pieces")
	for i in survivors.size():
		var piece = survivors[i].work_piece
		if piece != null and is_instance_valid(piece) and piece in pieces:
			workers[str(i)] = pieces.find(piece)
	return {"workers": workers, "supplied_day": supplied_day}


## After structures.gd and survivors.gd have loaded.
func load_state(data: Dictionary) -> void:
	supplied_day = int(data.get("supplied_day", supplied_day))
	var survivors: Array = _survivors.get("survivors")
	var pieces: Array = _structures.get("pieces")
	var workers: Dictionary = data.get("workers", {})
	for key in workers:
		var i := int(key)
		var p := int(workers[key])
		if i < survivors.size() and p >= 0 and p < pieces.size() and pieces[p].worker == null:
			var piece: StructurePiece = pieces[p]
			piece.worker = survivors[i]
			survivors[i].work_piece = piece
			survivors[i].working = true
			survivors[i].global_position = piece.work_spot()
			var to: Vector3 = piece.global_position - survivors[i].global_position
			survivors[i].rotation.y = atan2(-to.x, -to.z)
