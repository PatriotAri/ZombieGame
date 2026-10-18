extends Node
## The base camps: where your people live, and what they work.
##   - The police station is a camp from the start, and can't be taken down
##     (a KitBaseCamp marker in the map scene: where its logbook, bulletin board
##     and supply crate are). The woodworker lives there.
##   - Build more with the woodworker's camp kit (world/structures.gd builds it,
##     world/camp_site.gd is how it looks), at least RANGE from every other camp.
##     A built camp can be taken down: its people move to camps you pick
##     (main.gd asks).
##   - Each camp holds BASE_CAPACITY people, plus PER_STATION for every garden
##     plot or ammo bench someone works there. A station (or a guard post)
##     belongs to the nearest camp within RANGE; further out it's idle.
##   - Every morning each camp's worked plots put food, and its worked benches
##     their ammo, in that camp's supply crate.
##   - Survivors can be posted on a guard post or tower within RANGE of their
##     camp: they shoot zombies within GUARD_RADIUS of it (free ammo), and come
##     back to camp when you stand them down.
##   - Each camp's bulletin board shows who lives there.
##   - Zombies you kill within RANGE of a camp are counted for it (the wagon
##     trader comes once enough are killed round the station; quests can ask
##     for kills near a camp).
## main.gd creates it. Saved: the camps (built ones by their piece), each
## crate's contents, who works what, who guards where, and the kills. (Who lives where is
## saved with the survivors.)

const Survivor := preload("res://characters/npcs/survivor.gd")
const Woodworker := preload("res://characters/npcs/woodworker.gd")
const Guard := preload("res://characters/npcs/guard.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn")
const StructurePiece := preload("res://world/structure_piece.gd")
const SavePoint := preload("res://world/save_point.gd")
const BulletinBoard := preload("res://world/bulletin_board.gd")
const KitContainer := preload("res://items/loot_spot.gd")
const Ground := preload("res://world/ground.gd")

signal kills_changed

## Meters: how far apart camps must be, and how far a camp's stations and guard
## posts can be from it.
const RANGE := 75.0
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
const STATIONS := ["garden_plot", "ammo_bench", "shell_bench", "rifle_bench"]
const STATION_NAMES := {"garden_plot": "garden", "ammo_bench": "ammo bench", "shell_bench": "shell bench",
		"rifle_bench": "rifle bench"}
const GUARD_RADIUS := 35.0
const HOME_RING := 4.0 # meters from a camp's middle where its people stand (no SpawnPoint for them)
const CHECK_INTERVAL := 1.0


class Camp:
	extends RefCounted
	var name := ""
	var center := Vector3.ZERO
	var piece: Node3D = null # a built camp's StructurePiece (null: the police station)
	var built := false # (a freed piece reads as null, so this says which kind it is)
	var crate: Node3D = null
	var logbook: Node3D = null
	var board: Node3D = null
	var supplied_day := 1

	func permanent() -> bool:
		return not built


var camps: Array[Camp] = []
var station: Camp
var _survivors: Node # world/survivors.gd
var _woodworker: Node # world/woodworker_rescue.gd
var _structures: Node
var _zones: Node
var _day_night: Node
var _player: Node3D
var _station_homes := {} # survivor name -> their spot at the station (SpawnPoints)
var _guards := {} # survivor -> their Guard on a post
var _names := {} # piece -> the name its camp was given (so it keeps it)
var kills := {} # camp name -> zombies you've killed within RANGE of it
var _timer := 0.0


func setup(marker: KitBaseCamp, station_homes: Dictionary, survivors: Node, woodworker: Node,
		structures: Node, zones: Node, day_night: Node, player: Node3D) -> void:
	_survivors = survivors
	_woodworker = woodworker
	_structures = structures
	_zones = zones
	_day_night = day_night
	_player = player
	_station_homes = station_homes
	station = Camp.new()
	station.supplied_day = int(day_night.get("day"))
	if marker:
		station.name = marker.camp_name
		station.center = marker.global_position
		station.logbook = _part(SavePoint.new(), marker.part_transform("Logbook"))
		station.board = _part(BulletinBoard.new(), marker.part_transform("Board"))
		var crate := KitContainer.new()
		crate.label = "Supply crate"
		crate.loot_table = "none"
		crate.size = Vector3(1.0, 0.7, 0.7)
		crate.sits_on_floor = true
		station.crate = _part(crate, marker.part_transform("Crate"))
	else:
		push_warning("The map scene has no KitBaseCamp marker (the police station's camp): it's where you start, with no logbook, board or crate.")
		station.name = "Police Station"
		station.center = player.global_position
	camps.append(station)


func _ready() -> void:
	add_to_group("kill_listeners")


## A zombie died (zombie.gd tells everyone in "kill_listeners"); yours count
## for every camp it was near.
func zombie_killed(at: Vector3, killer: Node) -> void:
	if killer == null or not killer.is_in_group("player"):
		return
	var counted := false
	for camp in camps:
		if Vector2(camp.center.x - at.x, camp.center.z - at.z).length() <= RANGE:
			kills[camp.name] = int(kills.get(camp.name, 0)) + 1
			counted = true
	if counted:
		kills_changed.emit()


func kills_near(camp_name: String) -> int:
	return int(kills.get(camp_name, 0))


func _part(node: Node3D, xform: Transform3D) -> Node3D:
	node.transform = Transform3D(Basis(Vector3.UP, xform.basis.get_euler().y), xform.origin)
	get_parent().add_child(node)
	return node


# --- Camps -----------------------------------------------------------------------

func camp_named(camp_name: String) -> Camp:
	for camp in camps:
		if camp.name == camp_name:
			return camp
	return null


## The camp a station or post at pos belongs to: the nearest within RANGE, or null.
func camp_at(pos: Vector3) -> Camp:
	var best: Camp = null
	var best_dist := RANGE
	for camp in camps:
		var dist := Vector2(camp.center.x - pos.x, camp.center.z - pos.z).length()
		if dist <= best_dist:
			best = camp
			best_dist = dist
	return best


## Why a new camp can't go at pos ("" if it can): too close to another one.
func placement_problem(pos: Vector3) -> String:
	for camp in camps:
		var dist := Vector2(camp.center.x - pos.x, camp.center.z - pos.z).length()
		if dist < RANGE:
			return "Too close to %s (%d m; camps must be %d m apart)" % [camp.name, roundi(dist), roundi(RANGE)]
	return ""


## Built camps appear and go with their pieces (world/structures.gd).
func _sync_built() -> void:
	var pieces: Array = _structures.get("pieces")
	for i in range(camps.size() - 1, -1, -1):
		var camp := camps[i]
		if camp.built and (not is_instance_valid(camp.piece) or not camp.piece in pieces):
			camps.remove_at(i)
	for piece: StructurePiece in pieces:
		if piece.kind == "camp_kit" and _camp_of_piece(piece) == null:
			var camp := Camp.new()
			camp.piece = piece
			camp.built = true
			camp.center = piece.global_position
			camp.name = _names.get(piece, _new_name(piece.global_position))
			_names[piece] = camp.name
			camp.logbook = piece.get_node_or_null("Logbook")
			camp.board = piece.get_node_or_null("Board")
			camp.crate = piece.get_node_or_null("Crate")
			camp.supplied_day = int(_day_night.get("day"))
			camps.append(camp)


func _camp_of_piece(piece: Node3D) -> Camp:
	for camp in camps:
		if camp.piece == piece:
			return camp
	return null


## A built camp is named after the zone it's in ("Pine Hollow Camp"), or numbered.
func _new_name(pos: Vector3) -> String:
	var zone: String = _zones.call("zone_at", pos) if _zones else ""
	var base := (zone + " Camp") if zone != "" else "Camp"
	var n := 1
	var candidate := base if zone != "" else "Camp 2"
	while camp_named(candidate) != null or candidate in _names.values():
		n += 1
		candidate = "%s %d" % [base, n]
	return candidate


## A camp you're about to take down: its people (they need somewhere to go).
func camp_for_piece(piece: Node3D) -> Camp:
	_sync_built()
	return _camp_of_piece(piece)


# --- Who lives where ---------------------------------------------------------------

## The survivors living at a camp (travelling there counts), plus the woodworker at the station.
func members(camp: Camp) -> Array:
	var result := []
	for survivor: Survivor in _survivors.get("survivors"):
		if survivor.state != Survivor.State.WAITING and survivor.camp_name == camp.name:
			result.append(survivor)
	return result


func population(camp: Camp) -> int:
	var count := members(camp).size()
	if camp == station and _woodworker_home():
		count += 1
	return count


func _woodworker_home() -> bool:
	return _woodworker != null and _woodworker.call("state") != Woodworker.State.CAPTIVE


## The woodworker's rescue (world/woodworker_rescue.gd), made after the camps.
func attach_woodworker(woodworker: Node) -> void:
	_woodworker = woodworker


func capacity(camp: Camp) -> int:
	var worked_stations := 0
	for kind: String in STATIONS:
		worked_stations += worked(camp, kind)
	return BASE_CAPACITY + PER_STATION * worked_stations


func is_full(camp: Camp) -> bool:
	return population(camp) >= capacity(camp)


## Camps with room for one more.
func with_room() -> Array[Camp]:
	var result: Array[Camp] = []
	for camp in camps:
		if not is_full(camp):
			result.append(camp)
	return result


## Where a member stands at their camp: their SpawnPoint at the station, or a
## spot round the camp's middle.
func home_spot(survivor: Survivor) -> Vector3:
	var camp := camp_named(survivor.camp_name)
	if camp == null:
		camp = station
	if camp == station and _station_homes.has(survivor.display_name):
		return _station_homes[survivor.display_name]
	var index := members(camp).find(survivor)
	var angle := PI + index * 0.9 # a ring, starting behind the camp
	var basis := Basis(Vector3.UP, camp.piece.global_rotation.y) if camp.built and is_instance_valid(camp.piece) else Basis.IDENTITY
	var at := camp.center + basis * (Vector3(sin(angle), 0, cos(angle)) * HOME_RING)
	return Ground.snap(at, 0.1) if Ground.terrain else at


## Sends someone to live at another camp (taking down theirs): off any job or post.
func move_to(survivor: Survivor, camp: Camp) -> void:
	unassign(survivor)
	stand_down(survivor)
	survivor.camp_name = camp.name
	_survivors.call("go_home_spot", survivor)


# --- Stations ---------------------------------------------------------------------

func _stations(camp: Camp, kind: String) -> Array:
	return (_structures.get("pieces") as Array).filter(func(p: StructurePiece) -> bool:
		return p.kind == kind and camp_at(p.global_position) == camp)


## How many of this kind of station someone is working at a camp.
func worked(camp: Camp, kind: String) -> int:
	return _stations(camp, kind).filter(func(p: StructurePiece) -> bool: return p.worker != null).size()


func free_station(camp: Camp, kind: String) -> StructurePiece:
	for piece: StructurePiece in _stations(camp, kind):
		if piece.worker == null:
			return piece
	return null


## Puts a survivor at a free station of this kind at their camp. False if there isn't one.
func assign(survivor: Survivor, kind: String) -> bool:
	var piece := free_station(camp_named(survivor.camp_name), kind)
	if piece == null:
		return false
	unassign(survivor)
	stand_down(survivor)
	_put_to_work(survivor, piece)
	return true


func _put_to_work(survivor: Survivor, piece: StructurePiece) -> void:
	piece.worker = survivor
	survivor.work_piece = piece
	survivor.working = true
	survivor.global_position = piece.work_spot()
	var to := piece.global_position - survivor.global_position
	survivor.rotation.y = atan2(-to.x, -to.z) # facing their work


## Off the job and back to their spot.
func unassign(survivor: Survivor) -> void:
	var piece: Variant = survivor.work_piece
	if is_instance_valid(piece) and (piece as StructurePiece).worker == survivor:
		(piece as StructurePiece).worker = null
	var was_working := survivor.working
	survivor.work_piece = null
	survivor.working = false
	if was_working:
		_survivors.call("go_home_spot", survivor)


# --- Guards ------------------------------------------------------------------------

## Guard posts (on the ground or atop scaffolding) belonging to a camp that nobody's on.
func free_posts(camp: Camp) -> Array:
	return _stations(camp, "guard_post").filter(func(p: StructurePiece) -> bool: return p.worker == null)


## Posts a survivor on a guard post: they stand on it with a rifle and shoot
## zombies within GUARD_RADIUS of it. (Their own self waits, hidden, at camp.)
func post_guard(survivor: Survivor, piece: StructurePiece) -> void:
	unassign(survivor)
	stand_down(survivor)
	piece.worker = survivor
	var guard := GuardScene.instantiate() as Guard
	guard.display_name = survivor.display_name
	if survivor.model:
		guard.model = survivor.model
	guard.outfit_color = survivor.outfit_color
	guard.skin_color = survivor.skin_color
	guard.zombies_target = false # out of reach up there: they don't get eaten
	guard.guard_from = piece.global_position
	guard.guard_to = piece.global_position
	guard.guard_radius = GUARD_RADIUS
	guard.fire_range = GUARD_RADIUS + 10.0
	guard.set_meta("survivor", survivor)
	var at := piece.global_position + Vector3(0, 0.05, 0)
	guard.transform = Transform3D(Basis(Vector3.UP, piece.global_rotation.y), at)
	# Its own post (and the scaffolding under it) don't block its aim.
	var part: Node = piece
	while part != null:
		guard.exclude.append((part as CollisionObject3D).get_rid())
		part = (part as StructurePiece).below
	get_parent().add_child(guard)
	_guards[survivor] = guard
	survivor.guard_post = piece
	survivor.visible = false
	survivor.process_mode = Node.PROCESS_MODE_DISABLED
	(survivor.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", true)


## Off guard duty and back to camp.
func stand_down(survivor: Survivor) -> void:
	if not _guards.has(survivor):
		return
	var guard: Node3D = _guards[survivor]
	_guards.erase(survivor)
	if is_instance_valid(guard):
		guard.queue_free()
	var piece: Variant = survivor.guard_post
	if is_instance_valid(piece) and (piece as StructurePiece).worker == survivor:
		(piece as StructurePiece).worker = null
	survivor.guard_post = null
	survivor.visible = true
	survivor.process_mode = Node.PROCESS_MODE_INHERIT
	(survivor.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	_survivors.call("go_home_spot", survivor)


func is_guarding(survivor: Survivor) -> bool:
	return _guards.has(survivor)


# --- Every so often ----------------------------------------------------------------

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	_sync_built()
	var pieces: Array = _structures.get("pieces")
	for survivor: Survivor in _survivors.get("survivors"):
		# A station or post that's been taken down (or is out of their camp's
		# reach now): back to camp.
		if survivor.working and (not is_instance_valid(survivor.work_piece) or not survivor.work_piece in pieces):
			unassign(survivor)
		if is_guarding(survivor) and (not is_instance_valid(survivor.guard_post) or not survivor.guard_post in pieces):
			stand_down(survivor)
	_resupply()
	_update_boards()


## Each morning: food from every worked plot, ammo from every worked bench, into its camp's crate.
func _resupply() -> void:
	var day := int(_day_night.get("day"))
	if float(_day_night.get("hour")) < SUPPLY_HOUR:
		return
	var delivered := false
	for camp in camps:
		if day <= camp.supplied_day:
			continue
		camp.supplied_day = day
		if camp.crate == null or not is_instance_valid(camp.crate):
			continue
		var inventory: RefCounted = camp.crate.get("inventory")
		var food := FOOD_PER_PLOT * worked(camp, "garden_plot")
		inventory.call("add", "canned_food", food)
		var total := food
		for kind: String in BENCH_OUTPUT:
			var amount: int = BENCH_OUTPUT[kind][1] * worked(camp, kind)
			inventory.call("add", BENCH_OUTPUT[kind][0], amount)
			total += amount
		delivered = delivered or total > 0
	if delivered:
		_player.emit_signal("notify", "Fresh supplies in the camps' supply crates.")


## Each board: the camp's name, head count and who's doing what.
func _update_boards() -> void:
	for camp in camps:
		if camp.board == null or not is_instance_valid(camp.board):
			continue
		var lines := PackedStringArray()
		if camp == station and _woodworker_home():
			lines.append("Woodworker (building)")
		for survivor: Survivor in members(camp):
			lines.append("%s (%s)" % [survivor.display_name, _doing(survivor)])
		camp.board.call("show_camp", camp.name, population(camp), capacity(camp), lines)


## What a member's up to, for the board.
func _doing(survivor: Survivor) -> String:
	if survivor.state == Survivor.State.TRAVELLING:
		return "on the way"
	if is_guarding(survivor):
		return "on guard"
	if survivor.working and is_instance_valid(survivor.work_piece):
		return "on the " + STATION_NAMES.get(survivor.work_piece.get("kind"), "job")
	if survivor.job == "machinist":
		return "machinist"
	return "resting"


# --- Saving -------------------------------------------------------------------------

func save_state() -> Dictionary:
	var pieces: Array = _structures.get("pieces")
	var survivors: Array = _survivors.get("survivors")
	var camp_data := []
	for camp in camps:
		var entry := {"name": camp.name, "piece": pieces.find(camp.piece) if camp.built else -1,
				"supplied_day": camp.supplied_day}
		if camp.crate and is_instance_valid(camp.crate):
			entry["crate"] = (camp.crate.get("inventory") as RefCounted).call("to_dict")
		camp_data.append(entry)
	var workers := {}
	var guards := {}
	for i in survivors.size():
		var survivor: Survivor = survivors[i]
		if survivor.working and is_instance_valid(survivor.work_piece) and survivor.work_piece in pieces:
			workers[str(i)] = pieces.find(survivor.work_piece)
		if is_guarding(survivor) and survivor.guard_post in pieces:
			guards[str(i)] = pieces.find(survivor.guard_post)
	return {"camps": camp_data, "workers": workers, "guards": guards, "kills": kills.duplicate()}


## After structures.gd and survivors.gd have loaded.
func load_state(data: Dictionary) -> void:
	var pieces: Array = _structures.get("pieces")
	var survivors: Array = _survivors.get("survivors")
	kills = (data.get("kills", {}) as Dictionary).duplicate()
	for entry: Dictionary in data.get("camps", []):
		var index := int(entry.get("piece", -1))
		if index >= 0 and index < pieces.size():
			_names[pieces[index]] = str(entry.get("name", ""))
	_sync_built()
	for entry: Dictionary in data.get("camps", []):
		var index := int(entry.get("piece", -1))
		var camp := station if index < 0 else (_camp_of_piece(pieces[index]) if index < pieces.size() else null)
		if camp == null:
			continue
		camp.supplied_day = int(entry.get("supplied_day", camp.supplied_day))
		if entry.has("crate") and camp.crate and is_instance_valid(camp.crate):
			(camp.crate.get("inventory") as RefCounted).call("from_dict", entry["crate"])
	for key in data.get("workers", {}):
		var i := int(key)
		var p := int(data["workers"][key])
		if i < survivors.size() and p >= 0 and p < pieces.size() and pieces[p].worker == null:
			_put_to_work(survivors[i], pieces[p])
	for key in data.get("guards", {}):
		var i := int(key)
		var p := int(data["guards"][key])
		if i < survivors.size() and p >= 0 and p < pieces.size() and pieces[p].worker == null:
			post_guard(survivors[i], pieces[p])
	_update_boards()

