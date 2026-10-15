extends Node
## The map's grid and its zones.
##
## The grid: square map references named like a paper map, columns A, B, C... from
## west to east, rows 1, 2, 3... from north to south ("O14"). A square is only a
## place name.
##
## A zone is a named group of squares (ZONES below), and has a status:
##   DANGER   (red on the map)    - zombies walking around in any of its squares
##   HOSTILE  (yellow on the map) - the zombies are dead, but bandits are there
##   SAFE     (clear on the map)  - nothing left
## Status is worked out from whoever is standing in the zone right now, so zombies
## wandering back in make it unsafe again (barricades and planks keep them out:
## see world/fortifications.gd). Nothing here needs saving: zombies and bandits are
## saved, and the status follows from them.
## The map screen (ui/map_menu.gd) draws the grid and the zones; the HUD shows
## the square you're in and, inside a zone, how it stands.
##
## The grid also sets the area the map screen shows. It covers the 1 km map
## (world/map/map.tscn); if the map grows, widen ORIGIN / CELL_SIZE / COLUMNS /
## ROWS to cover it.

signal status_changed(zone_name: String, status: Status)

enum Status { SAFE, HOSTILE, DANGER }

## +x is east and -z is north (Godot's convention; the map is drawn that way up).
## 26 x 26 squares (A-Z, 1-26) of 40 m, 1040 m across: the 1024 m map with a
## little to spare, centered on the middle of the map.
const ORIGIN := Vector2(-520.0, -520.0) # the grid's north-west corner (x, z), in meters
const CELL_SIZE := 40.0 # meters per side
const COLUMNS := 26 # A to Z
const ROWS := 26 # 1 to 26
const CHECK_INTERVAL := 0.5 # seconds; counting everyone every frame is wasted work

## The zones. To add one, add an entry: its name, a title for the map and HUD,
## and its squares. A square belongs to at most one zone (a warning in the Output
## panel names any that are claimed twice).
## (Zone 1 is the 3 x 3 squares in the middle of the map, where you start, until
## the police station is built somewhere: then move it there. The story, the
## wagon trader and building fences all go by Zone 1.)
const ZONES := [
	{"name": "Zone 1", "title": "Police Station",
			"squares": ["M13", "N13", "O13", "M14", "N14", "O14", "M15", "N15", "O15"]},
]

var bandits: Array = [] # set by main.gd; zombies are found through the "zombies" group
var discoveries: Node # set by main.gd; hides zone titles naming places not found yet
var _status := {} # zone name -> Status
var _counts := {} # zone name -> [zombies, bandits]
var _zone_of_square := {} # square name -> zone name
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


## Each zone's squares as (x, z) rectangles, for drawing.
static func zone_rects(zone: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell: Array in cells():
		if cell[0] in zone["squares"]:
			rects.append(cell[1])
	return rects


func _ready() -> void:
	for zone: Dictionary in ZONES:
		_status[zone["name"]] = Status.SAFE
		_counts[zone["name"]] = [0, 0]
		for square: String in zone["squares"]:
			if _zone_of_square.has(square):
				push_warning("Square %s is in both %s and %s." % [square, _zone_of_square[square], zone["name"]])
			_zone_of_square[square] = zone["name"]


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_recount()


## The grid square a point is in ("O14"), or "" off the edge of the grid.
func square_at(pos: Vector3) -> String:
	var col := floori((pos.x - ORIGIN.x) / CELL_SIZE)
	var row := floori((pos.z - ORIGIN.y) / CELL_SIZE)
	if col < 0 or col >= COLUMNS or row < 0 or row >= ROWS:
		return ""
	return cell_name(col, row)


## The zone a point is in ("Zone 1"), or "" outside every zone.
func zone_at(pos: Vector3) -> String:
	return _zone_of_square.get(square_at(pos), "")


## False until the first count: before it, every zone reads as safe.
func is_counted() -> bool:
	return _started


func status_of(zone_name: String) -> Status:
	return _status.get(zone_name, Status.SAFE)


## "Zone 1 (Police Station)"; just "Zone 1" while its title is a place you
## haven't found yet (world/discoveries.gd).
func full_name(zone_name: String) -> String:
	for zone: Dictionary in ZONES:
		if zone["name"] == zone_name:
			if discoveries and not discoveries.is_known(zone["title"]):
				return zone_name
			return "%s (%s)" % [zone_name, zone["title"]]
	return zone_name


## For the HUD, e.g. "O14  ·  Zone 1 (Police Station)  ·  4 zombies", or just
## "C7" outside every zone.
func describe(pos: Vector3) -> String:
	var square := square_at(pos)
	var zone_name := zone_at(pos)
	if zone_name == "":
		return square
	var counts: Array = _counts[zone_name]
	var state := "safe"
	match status_of(zone_name):
		Status.DANGER:
			state = "%d zombie%s" % [counts[0], "" if counts[0] == 1 else "s"]
		Status.HOSTILE:
			state = "%d bandit%s" % [counts[1], "" if counts[1] == 1 else "s"]
	return "%s  ·  %s  ·  %s" % [square, full_name(zone_name), state]


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
