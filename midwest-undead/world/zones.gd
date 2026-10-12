extends Node
## The map is split into a grid of square zones, named like a paper map: columns
## A, B, C... from west to east, rows 1, 2, 3... from north to south ("C4").
## Each zone is:
##   DANGER   (red on the map)    - zombies still walking around in it
##   HOSTILE  (yellow on the map) - the zombies are dead, but bandits are still there
##   SAFE     (clear on the map)  - nothing left
## Status is worked out from whoever is standing in the zone right now, so a
## zombie wandering into a cleared zone turns it red again. Nothing here needs
## saving: zombies and bandits are saved, and the status follows from them.
## The map screen (ui/map_menu.gd) draws the grid; the HUD shows the zone you're in.
##
## The grid also sets the area the map screen shows. When the world grows, widen
## ORIGIN / COLUMNS / ROWS to cover it.

signal status_changed(zone_name: String, status: Status)

enum Status { SAFE, HOSTILE, DANGER }

## +x is east and -z is north (Godot's convention; the map is drawn that way up).
## 26 x 26 squares (A-Z, 1-26), about 780 m across, with the town in the middle.
## Offset by half a square so Main Street (x = 0) runs down the middle of column M
## and the cross street (z = 0) along the middle of row 13, instead of along grid
## lines that would split them between two zones.
const ORIGIN := Vector2(-375.0, -375.0) # the grid's north-west corner (x, z), in meters
const CELL_SIZE := 30.0 # meters per side
const COLUMNS := 26 # A to Z
const ROWS := 26 # 1 to 26
const CHECK_INTERVAL := 0.5 # seconds; counting everyone every frame is wasted work

var bandits: Array = [] # set by main.gd; zombies are found through the "zombies" group
var _status := {} # zone name -> Status
var _counts := {} # zone name -> [zombies, bandits]
var _check_timer := 0.0
var _started := false


## The whole grid, as an (x, z) rectangle in meters.
static func bounds() -> Rect2:
	return Rect2(ORIGIN, Vector2(COLUMNS, ROWS) * CELL_SIZE)


## Every zone as [name, (x, z) rectangle], row by row from the north-west corner.
static func cells() -> Array:
	var result := []
	for row in ROWS:
		for col in COLUMNS:
			result.append([cell_name(col, row), Rect2(ORIGIN + Vector2(col, row) * CELL_SIZE,
					Vector2(CELL_SIZE, CELL_SIZE))])
	return result


## "A1" for the north-west corner. Column Z is the last single letter: a wider
## grid would need names like "AA".
static func cell_name(col: int, row: int) -> String:
	return String.chr(65 + col) + str(row + 1)


func _ready() -> void:
	for cell: Array in cells():
		_status[cell[0]] = Status.SAFE
		_counts[cell[0]] = [0, 0]


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_recount()


## The zone a point is in, or "" off the edge of the grid.
func zone_at(pos: Vector3) -> String:
	var col := floori((pos.x - ORIGIN.x) / CELL_SIZE)
	var row := floori((pos.z - ORIGIN.y) / CELL_SIZE)
	if col < 0 or col >= COLUMNS or row < 0 or row >= ROWS:
		return ""
	return cell_name(col, row)


func status_of(zone_name: String) -> Status:
	return _status.get(zone_name, Status.SAFE)


## For the HUD, e.g. "Zone C4  ·  4 zombies".
func describe(zone_name: String) -> String:
	if zone_name == "":
		return ""
	var counts: Array = _counts[zone_name]
	match status_of(zone_name):
		Status.DANGER:
			return "Zone %s  ·  %d zombie%s" % [zone_name, counts[0], "" if counts[0] == 1 else "s"]
		Status.HOSTILE:
			return "Zone %s  ·  %d bandit%s" % [zone_name, counts[1], "" if counts[1] == 1 else "s"]
	return "Zone %s  ·  safe" % zone_name


func _recount() -> void:
	for zone_name: String in _counts:
		_counts[zone_name] = [0, 0]
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var zone := zone_at(zombie.global_position)
		if zone != "":
			_counts[zone][0] += 1
	for bandit in bandits:
		if not bandit.is_dead:
			var zone := zone_at(bandit.global_position)
			if zone != "":
				_counts[zone][1] += 1

	for zone_name: String in _counts:
		var counts: Array = _counts[zone_name]
		var status := Status.DANGER if counts[0] > 0 else (Status.HOSTILE if counts[1] > 0 else Status.SAFE)
		if status == _status[zone_name]:
			continue
		_status[zone_name] = status
		# The first count after loading just sets the statuses; nothing "happened".
		if _started:
			status_changed.emit(zone_name, status)
	_started = true
