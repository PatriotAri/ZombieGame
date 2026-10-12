extends Node
## Named areas of the map and how safe each one is:
##   DANGER   (red on the map)    - zombies still walking around in it
##   HOSTILE  (yellow on the map) - the zombies are dead, but bandits are still there
##   SAFE     (clear on the map)  - nothing left
## Status is worked out from whoever is standing in the zone right now, so a
## zombie wandering into a cleared zone turns it red again. Nothing here needs
## saving: zombies and bandits are saved, and the status follows from them.
## The map screen (ui/map_menu.gd) draws the zones; the HUD shows the one you're in.
##
## To add a zone, add a line to ZONES. A zone is one or more boxes, so it can
## wrap around another one. Boxes must not overlap (a zombie would count in
## whichever is listed first); a warning in the Output panel names any that do.

signal status_changed(zone_name: String, status: Status)

enum Status { SAFE, HOSTILE, DANGER }

const CHECK_INTERVAL := 0.5 # seconds; counting everyone every frame is wasted work

## Each zone: a name, then its boxes as [corner (x0, z0), corner (x1, z1)] in
## meters. +x is east and -z is north (Godot's convention; the map is drawn
## that way up), so the police station is on the south side of the cross street.
const ZONES := [
	["Police Station", [[Vector2(30, -6), Vector2(72, 32)]]],
	["Bandit Camp", [[Vector2(-50, -55), Vector2(-22, -15)]]], # stops where the Main Street shops begin
	["Westside Safe House", [[Vector2(-74, 4), Vector2(-50, 26)]]], # the yard (from the barricade) and the house
	["Crossroads", [[Vector2(-22, -6), Vector2(22, 6)]]],
	["Main Street North", [[Vector2(-22, -86), Vector2(22, -6)]]],
	["Main Street South", [[Vector2(-22, 6), Vector2(22, 86)]]],
	["East Road", [[Vector2(22, -6), Vector2(30, 6)]]],
	# The cross street west of Main, stepping around the safe house yard.
	["West Road", [[Vector2(-86, -6), Vector2(-74, 6)], [Vector2(-74, -6), Vector2(-50, 4)],
			[Vector2(-50, -6), Vector2(-22, 6)]]],
]

var bandits: Array = [] # set by main.gd; zombies are found through the "zombies" group
var _status := {} # zone name -> Status
var _counts := {} # zone name -> [zombies, bandits]
var _check_timer := 0.0
var _started := false


func _ready() -> void:
	for zone: Array in ZONES:
		_status[zone[0]] = Status.SAFE
		_counts[zone[0]] = [0, 0]
	_warn_overlaps()


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_recount()


## The zone a point is in, or "" outside all of them.
func zone_at(pos: Vector3) -> String:
	for zone: Array in ZONES:
		for box: Array in zone[1]:
			var corner0: Vector2 = box[0]
			var corner1: Vector2 = box[1]
			if pos.x >= corner0.x and pos.x < corner1.x and pos.z >= corner0.y and pos.z < corner1.y:
				return zone[0]
	return ""


func status_of(zone_name: String) -> Status:
	return _status.get(zone_name, Status.SAFE)


## For the HUD, e.g. "Main Street North  ·  4 zombies".
func describe(zone_name: String) -> String:
	if zone_name == "":
		return ""
	var counts: Array = _counts[zone_name]
	match status_of(zone_name):
		Status.DANGER:
			return "%s  ·  %d zombie%s" % [zone_name, counts[0], "" if counts[0] == 1 else "s"]
		Status.HOSTILE:
			return "%s  ·  %d bandit%s" % [zone_name, counts[1], "" if counts[1] == 1 else "s"]
	return "%s  ·  safe" % zone_name


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


## Overlapping boxes would count zombies in whichever zone is listed first and
## draw on top of each other on the map. Catch it when someone edits ZONES.
func _warn_overlaps() -> void:
	var boxes := []
	for zone: Array in ZONES:
		for box: Array in zone[1]:
			boxes.append([zone[0], Rect2(box[0], box[1] - box[0])])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Rect2 = boxes[i][1]
			var b: Rect2 = boxes[j][1]
			if a.intersection(b).has_area():
				push_warning("Zones '%s' and '%s' overlap at %s." % [boxes[i][0], boxes[j][0], a.intersection(b)])
