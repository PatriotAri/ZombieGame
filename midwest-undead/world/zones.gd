extends Node
## The map's zones: named areas drawn in the map scene (KitZone outlines,
## world/markers/zone.gd). Zones are just names: walking into one says so
## (zone_entered), and the map screen can outline them (ui/map_menu.gd). Nothing
## here needs saving.
## main.gd creates it and calls setup() with the map.

signal zone_entered(zone_name: String)

const Ground := preload("res://world/ground.gd")
const CHECK_INTERVAL := 0.5

var _zones: Array[Dictionary] = [] # {"name", "outline": PackedVector2Array, "box": Rect2}
var _player: Node3D
var _current := "" # the zone you're in
var _timer := 0.0


## map: the map scene (its KitZone nodes); player: who to tell about entering.
func setup(map: Node, player: Node3D) -> void:
	_player = player
	for node in map.find_children("*", "Path3D", true, false):
		if node is KitZone:
			var outline := (node as KitZone).outline()
			if outline.size() < 3:
				push_warning("Zone \"%s\" needs at least 3 corners: skipped." % (node as KitZone).zone_name)
				continue
			var box := Rect2(outline[0], Vector2.ZERO)
			for p in outline:
				box = box.expand(p)
			_zones.append({"name": (node as KitZone).zone_name, "outline": outline, "box": box})
	_current = zone_at(player.global_position) # where you start doesn't count as entering


## The whole map, as an (x, z) rectangle in meters (what the map screen shows).
static func bounds() -> Rect2:
	var rect := Ground.map_rect()
	return rect if rect.size != Vector2.ZERO else Rect2(-512, -512, 1024, 1024)


## Every zone: [{"name", "outline"}], for drawing.
func all() -> Array[Dictionary]:
	return _zones


## The zone a point is in, or "" outside every zone.
func zone_at(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	for zone in _zones:
		if (zone["box"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, zone["outline"]):
			return zone["name"]
	return ""


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var now := zone_at(_player.global_position)
	if now != _current:
		_current = now
		if now != "":
			zone_entered.emit(now)
