extends Node
## The wagon trader. The first time Zone 1 (the streets around the police
## station, see world/zones.gd) is clear of zombies, word gets around, and a
## trader's wagon comes to the station yard. It turns up while you're away
## (ARRIVE_DISTANCE from the station), so you never see it pop in, and it stays
## for good. Zombies wandering back into the zone later don't drive them off,
## but they won't restock while there are zombies in it: the morning's restock
## waits until the zone is clear again.
## Coming back near it the first time is the "a trader is here" moment.
## main.gd creates it and listens to the signals; the quest follows along.
##
## Saved: whether the zone has been cleared, whether the trader has come and
## been seen, and the trader's stock.

signal zone_cleared
signal arrived
signal seen # the first time you come near after they arrived

const Zones := preload("res://world/zones.gd")
const Shopkeeper := preload("res://characters/npcs/shopkeeper.gd")
const TraderScene := preload("res://characters/npcs/wagon_trader.tscn")

const ZONE := "Zone 1"
const ARRIVE_DISTANCE := 100.0 # how far from the station you have to be for them to arrive
const SEEN_DISTANCE := 35.0
const CHECK_INTERVAL := 0.5
# In the yard's east strip, between the station and the fence, behind the guard tower.
const WAGON_SPOT := Vector3(65.2, 0.0, 17.0)
const TRADER_SPOT := Vector3(65.2, 0.1, 13.6) # in front of the wagon, facing the front yard
const WOOD := Color(0.45, 0.32, 0.2)
const WOOD_DARK := Color(0.3, 0.21, 0.13)
const CANVAS := Color(0.78, 0.74, 0.62)

var cleared := false
var has_arrived := false
var was_seen := false
var trader: Shopkeeper # null until they arrive
var _player: Node3D
var _zones: Zones
var _day_night: Node
var _station_center := Vector3.ZERO
var _timer := 0.0


func setup(player: Node3D, zones: Zones, day_night: Node, station_center: Vector3) -> void:
	_player = player
	_zones = zones
	_day_night = day_night
	_station_center = station_center


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var dist := _player.global_position.distance_to(_station_center)
	# is_counted: before the first count every zone reads as safe.
	if not cleared and _zones.is_counted() and _zones.status_of(ZONE) == Zones.Status.SAFE:
		cleared = true
		zone_cleared.emit()
	if cleared and not has_arrived and dist >= ARRIVE_DISTANCE:
		_arrive()
		arrived.emit()
	if has_arrived and not was_seen and _player.global_position.distance_to(WAGON_SPOT) <= SEEN_DISTANCE:
		was_seen = true
		seen.emit()


func save_state() -> Dictionary:
	var data := {"cleared": cleared, "arrived": has_arrived, "seen": was_seen}
	if trader:
		data["stock"] = trader.stock.to_dict()
		data["restocked_day"] = trader.restocked_day
	return data


func load_state(data: Dictionary) -> void:
	cleared = bool(data.get("cleared", false))
	was_seen = bool(data.get("seen", false))
	if bool(data.get("arrived", false)) and not has_arrived:
		_arrive()
		if data.has("stock"):
			trader.stock.from_dict(data["stock"])
		trader.restocked_day = int(data.get("restocked_day", trader.restocked_day))


func _arrive() -> void:
	has_arrived = true
	_build_wagon()
	trader = TraderScene.instantiate() as Shopkeeper
	trader.position = TRADER_SPOT
	trader.day_night = _day_night # restocks each morning, like the Quartermaster...
	trader.can_restock = func() -> bool: return _zones.status_of(ZONE) != Zones.Status.DANGER # ...when Zone 1 is clear
	get_parent().add_child(trader)
	# Their first restock is the morning after they arrive.
	trader.restocked_day = _day_night.day


## A covered wagon: a box bed on four wheels, hoops of canvas over it, a hitch
## pole out the front, and a lantern for the night.
func _build_wagon() -> void:
	var wagon := StaticBody3D.new()
	wagon.position = WAGON_SPOT
	get_parent().add_child(wagon)
	_box(wagon, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.95, 0), WOOD) # bed
	_box(wagon, Vector3(1.9, 0.45, 0.08), Vector3(0, 1.42, -2.0), WOOD_DARK) # front board
	_box(wagon, Vector3(1.9, 0.45, 0.08), Vector3(0, 1.42, 2.0), WOOD_DARK) # tailboard
	_box(wagon, Vector3(0.08, 0.1, 2.6), Vector3(0, 0.75, -3.2), WOOD_DARK) # hitch pole
	_box(wagon, Vector3(2.0, 1.3, 3.6), Vector3(0, 2.0, 0.1), CANVAS) # canvas cover
	_box(wagon, Vector3(1.4, 0.3, 3.6), Vector3(0, 2.75, 0.1), CANVAS)
	for x: float in [-1.05, 1.05]:
		for z: float in [-1.4, 1.4]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.55
			mesh.bottom_radius = 0.55
			mesh.height = 0.12
			mesh.material = _material(WOOD_DARK)
			wheel.mesh = mesh
			wheel.position = Vector3(x, 0.55, z)
			wheel.rotation.z = PI / 2.0
			wagon.add_child(wheel)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.9, 4.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 1.45, 0)
	wagon.add_child(col)
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0.0, 2.2, -2.2)
	lantern.light_color = Color(1.0, 0.75, 0.45)
	lantern.light_energy = 0.7
	lantern.omni_range = 8.0
	wagon.add_child(lantern)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
