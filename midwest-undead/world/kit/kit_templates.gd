@tool
class_name KitTemplates
extends RefCounted
## Ready-made buildings: a Building's Template, Variant and Apply Template
## (or Map Tools' New from template) fill in its settings from one of these:
## its size, floors, roof, materials, doors and windows, inner walls, rooms
## (with their Kind, for Furnish Rooms), stairs, porches, and things outside
## it (a gas station's canopy and pumps, a church's steeple, signs, a school's
## flagpole and playground). After that it's an ordinary building to change.
## Never instanced: building.gd calls settings().

const M := "res://world/kit/materials/"
const FURNITURE := "res://world/kit/furniture/"

const NAMES := ["Farmhouse", "Ranch house", "Cottage", "Trailer", "Corner store", "Gas station", "Diner", "Church",
		"School", "Police station", "Barn", "Machine shed"]
const VARIANTS := {
	"Farmhouse": ["Two storey, porch", "One storey, porch", "Two storey, wraparound porch, cellar"],
	"Ranch house": ["Attached garage", "No garage", "Garage and basement"],
	"Cottage": ["Small", "With porch", "Stone, with chimney"],
	"Trailer": ["Single-wide", "Double-wide", "With awning"],
	"Corner store": ["Small", "Large, with office", "Two storey, apartment upstairs"],
	"Gas station": ["Small", "With garage bay", "Big canopy"],
	"Diner": ["Classic", "Small", "Brick"],
	"Church": ["Small chapel", "Steeple", "Brick, steeple"],
	"School": ["One-room schoolhouse", "Two classrooms", "Four classrooms"],
	"Police station": ["Small", "With cell block", "Two storey"],
	"Barn": ["Gambrel, hayloft", "Gable, workshop", "Small shed"],
	"Machine shed": ["Open front", "Garage doors", "Large, workshop"],
}
## Random Colours picks the outside from these.
const HOMES := ["siding_white", "siding_blue", "siding_cream", "siding_sage", "siding_tan", "siding_weathered"]
const TOWN := ["brick_red", "brick_brown", "brick_tan", "stucco_white", "siding_white"]
const FARM := ["barn_red", "barn_red", "siding_weathered"]


## The settings for a template (property -> value; unset ones go back to the
## defaults) and "extras": [Node3D] to add under the building. rng: picks
## the colours (null: the template's own).
static func settings(template: String, variant: int, rng: RandomNumberGenerator) -> Dictionary:
	var p: Plan
	match template:
		"Farmhouse": p = _farmhouse(variant)
		"Ranch house": p = _ranch(variant)
		"Cottage": p = _cottage(variant)
		"Trailer": p = _trailer(variant)
		"Corner store": p = _store(variant)
		"Gas station": p = _gas_station(variant)
		"Diner": p = _diner(variant)
		"Church": p = _church(variant)
		"School": p = _school(variant)
		"Police station": p = _police(variant)
		"Barn": p = _barn(variant)
		"Machine shed": p = _machine_shed(variant)
		_: return {}
	if rng and not p.palette.is_empty():
		p.set_value("exterior_material", _mat(p.palette[rng.randi_range(0, p.palette.size() - 1)]))
	return p.result()


static func _mat(name: String) -> Material:
	return load(M + name + ".tres")


static func _piece(name: String, at: Vector3, yaw_deg := 0.0) -> Node3D:
	var node: Node3D = load(FURNITURE + name + ".tscn").instantiate()
	node.position = at
	node.rotation.y = deg_to_rad(yaw_deg)
	return node


static func _box(size: Vector3, at: Vector3, material: String, name := "") -> Node3D:
	var box := KitBox.new()
	box.name = name
	box.size = size
	box.position = at
	box.material = _mat(material)
	return box


static func _sign(text: String, at: Vector3, yaw_deg: float, size := Vector2(3.0, 0.9), standing := false) -> Node3D:
	var sign := KitSign.new()
	sign.text = text
	sign.size = size
	sign.standing = standing
	sign.position = at
	sign.rotation.y = deg_to_rad(yaw_deg)
	return sign


## A sign on the front wall (facing out, -X), over the door.
static func _front_sign(p: Plan, text: String, z: float, y: float, size := Vector2(3.0, 0.9)) -> void:
	p.extras.append(_sign(text, Vector3(-0.06, y, z), -90.0, size))


# --- Homes -------------------------------------------------------------------------------

static func _farmhouse(v: int) -> Plan:
	var p := Plan.new(10.0, 12.0)
	p.palette = HOMES
	p.set_values({"floors": 1 if v == 1 else 2, "floor_y": 0.45, "roof_shape": "Gable", "roof_pitch": 40.0,
			"exterior_material": _mat("siding_white"), "foundation": "Stone"})
	if v == 1:
		p.size(10.0, 14.0)
		p.door("front", -2.0)
		p.door("right", 2.75)
		p.wins("front", [-5.0, 2.5, 5.0])
		p.wins("back", [-4.5, 0.75, 5.0])
		p.wins("left", [2.5, 7.5])
		p.wins("right", [7.75])
		# Front: living room and kitchen; back: two bedrooms and a bathroom between.
		p.inner(0, Vector2(5.5, -7), Vector2(5.5, 7), [2.5, 8.5, 12.5])
		p.inner(0, Vector2(0, 0), Vector2(5.5, 0), [2.75])
		p.inner(0, Vector2(5.5, -1.5), Vector2(10, -1.5), [])
		p.inner(0, Vector2(5.5, 3.0), Vector2(10, 3.0), [])
		p.room(0, Vector2(2.75, -3.5), "Living room")
		p.room(0, Vector2(2.75, 3.5), "Kitchen", "concrete_slab")
		p.room(0, Vector2(7.75, -4.5), "Bedroom")
		p.room(0, Vector2(7.75, 0.75), "Bathroom", "concrete_slab")
		p.room(0, Vector2(7.75, 5.0), "Bedroom")
		p.porch([0], "Roofed", 2.4, -2.0)
		p.chimney(Vector2(5.5, -6.3))
		return p
	p.door("front", -1.5)
	p.door("back", 4.0)
	for k in 2:
		p.wins("front", [-4.0, 3.0] if k == 0 else [-3.0, 3.0], k)
		p.wins("left", [3.0, 8.0], k)
		p.wins("right", [3.0, 8.0], k)
		p.wins("back", [-4.5] if k == 0 else [-4.75], k)
	# Ground floor: living room and dining room in front; at the back the hall
	# (with the stairs up along the back wall) and the kitchen.
	p.inner(0, Vector2(6, -6), Vector2(6, 6), [2.5, 9.0])
	p.inner(0, Vector2(0, 0.5), Vector2(6, 0.5), [3.0])
	p.inner(0, Vector2(6, 1.5), Vector2(10, 1.5), [1.0])
	p.room(0, Vector2(3, -3), "Living room")
	p.room(0, Vector2(3, 3.5), "Dining room")
	p.room(0, Vector2(8, 4), "Kitchen", "concrete_slab")
	p.stair(0, Vector2(8.9, -5.0), 90.0)
	# Upstairs: two bedrooms in front, the landing and a bathroom at the back.
	p.inner(1, Vector2(6, -6), Vector2(6, 6), [3.0, 8.0])
	p.inner(1, Vector2(0, 0.5), Vector2(6, 0.5), [])
	p.inner(1, Vector2(6, 3.5), Vector2(10, 3.5), [2.0])
	p.room(1, Vector2(3, -3), "Bedroom")
	p.room(1, Vector2(3, 3.5), "Bedroom")
	p.room(1, Vector2(8, 4.75), "Bathroom", "concrete_slab")
	p.chimney(Vector2(5.5, -5.6))
	if v == 2:
		p.porch([0, 1], "Roofed", 2.4, -1.5)
		p.set_value("basement", true)
		p.cellar("back", 3.0)
		p.room(-1, Vector2(5, 0), "Basement storage")
	else:
		p.porch([0], "Roofed", 2.4, -1.5)
	return p


static func _ranch(v: int) -> Plan:
	var garage := v != 1
	var p := Plan.new(9.0, 20.0 if garage else 16.0)
	p.palette = HOMES
	p.set_values({"floor_y": 0.1, "roof_shape": "Hip", "roof_pitch": 25.0, "roof_overhang": 0.6,
			"exterior_material": _mat("siding_tan")})
	var end := 4.0 if garage else 8.0 # where the house part ends (z); the garage past it
	var start := -p.width / 2.0
	# A hall down the middle (x 4.5 to 6.1); living room and kitchen in front of
	# it, bedrooms and a bathroom behind.
	p.inner(0, Vector2(4.5, start), Vector2(4.5, end), [3.0, end - start - 3.5])
	p.inner(0, Vector2(6.1, start), Vector2(6.1, end), [2.5, (end - start) / 2.0, end - start - 2.0])
	p.inner(0, Vector2(0, (start + end) / 2.0 + 1.0), Vector2(4.5, (start + end) / 2.0 + 1.0), [2.25])
	var b1 := start + (end - start) * 0.38
	var b2 := start + (end - start) * 0.62
	p.inner(0, Vector2(6.1, b1), Vector2(9, b1), [])
	p.inner(0, Vector2(6.1, b2), Vector2(9, b2), [])
	p.room(0, Vector2(2.25, start + 2.5), "Living room")
	p.room(0, Vector2(2.25, end - 2.0), "Kitchen", "concrete_slab")
	p.room(0, Vector2(7.55, start + 1.5), "Bedroom")
	p.room(0, Vector2(7.55, (b1 + b2) / 2.0), "Bathroom", "concrete_slab")
	p.room(0, Vector2(7.55, end - 1.5), "Bedroom")
	p.door("front", start + 4.0)
	p.wins("front", [start + 1.5, start + 7.0, end - 2.0])
	p.wins("back", [start + 1.5, (b1 + b2) / 2.0, end - 1.5], 0, 1.2, 1.2)
	p.wins("left", [2.25])
	if garage:
		p.inner(0, Vector2(0, end), Vector2(9, end), [5.3])
		p.room(0, Vector2(4.5, end + 3.0), "Garage", "concrete_slab")
		p.opening("front", end + 3.0, "garage door", 2.8, 0.0, 2.3)
		p.wins("right", [1.5])
	else:
		p.wins("right", [2.25])
		p.door("back", end - 2.5)
	if v == 2:
		p.set_value("basement", true)
		p.stair(-1, Vector2(2.0, end + 5.0), 0.0)
		p.room(-1, Vector2(4.5, 0.0), "Basement storage")
	return p


static func _cottage(v: int) -> Plan:
	var p := Plan.new(7.0, 8.0)
	p.palette = HOMES
	p.set_values({"floor_y": 0.3, "roof_shape": "Gable", "roof_pitch": 45.0, "foundation": "Stone",
			"exterior_material": _mat("stone_gray" if v == 2 else "siding_cream")})
	p.door("front", -1.0)
	p.wins("front", [2.0])
	p.wins("left", [1.75])
	p.wins("right", [5.25])
	p.wins("back", [-1.5])
	p.inner(0, Vector2(3.5, -4), Vector2(3.5, 4), [2.5, 6.5])
	p.inner(0, Vector2(3.5, 1), Vector2(7, 1), [])
	p.room(0, Vector2(1.75, 0), "Living room")
	p.room(0, Vector2(5.25, -1.5), "Bedroom")
	p.room(0, Vector2(5.25, 2.5), "Bathroom", "concrete_slab")
	if v == 1:
		p.porch([0], "Roofed", 2.0, 0.0)
	if v == 2:
		p.chimney(Vector2(3.5, 3.6))
		p.dormer(Vector2(0.5, 1.5))
	return p


static func _trailer(v: int) -> Plan:
	var double := v == 1
	var p := Plan.new(8.4 if double else 4.6, 18.0 if double else 16.0)
	p.palette = ["siding_white", "metal_siding", "siding_cream", "siding_weathered"]
	p.set_values({"floor_y": 0.7, "foundation": "Wooden posts", "roof_shape": "Gable", "roof_pitch": 12.0,
			"roof_overhang": 0.15, "exterior_material": _mat("metal_siding")})
	if double:
		p.inner(0, Vector2(4.2, -9), Vector2(4.2, 9), [3.0, 7.5, 13.5])
		p.inner(0, Vector2(0, 1), Vector2(4.2, 1), [2.1])
		p.inner(0, Vector2(4.2, -3), Vector2(8.4, -3), [])
		p.inner(0, Vector2(4.2, 0), Vector2(8.4, 0), [])
		p.room(0, Vector2(2.1, -4), "Living room")
		p.room(0, Vector2(2.1, 5), "Kitchen", "concrete_slab")
		p.room(0, Vector2(6.3, -6), "Bedroom")
		p.room(0, Vector2(6.3, -1.5), "Bathroom", "concrete_slab")
		p.room(0, Vector2(6.3, 4.5), "Bedroom")
		p.door("front", -1.0)
		p.wins("front", [-6.0, 4.0])
		p.wins("back", [6.0, -4.5], 0, 1.2, 1.2)
		p.porch([0], "Open", 1.6, -1.0, 3.0)
		return p
	for z: float in [-3.0, 2.0, 5.0]:
		p.inner(0, Vector2(0, z), Vector2(4.6, z), [2.3])
	p.room(0, Vector2(2.3, -5.5), "Bedroom")
	p.room(0, Vector2(2.3, -0.5), "Living room")
	p.room(0, Vector2(2.3, 3.5), "Kitchen", "concrete_slab")
	p.room(0, Vector2(2.3, 6.5), "Bathroom", "concrete_slab")
	p.door("front", 0.0)
	p.wins("front", [-5.5, 3.5])
	p.wins("back", [5.5, 0.5, -3.5], 0, 1.2, 1.2)
	if v == 2:
		p.porch([0], "Roofed", 2.4, 0.0, 7.0)
	else:
		p.porch([0], "Open", 1.6, 0.0, 3.0)
	return p


# --- Town --------------------------------------------------------------------------------

static func _store(v: int) -> Plan:
	var large := v == 1
	var p := Plan.new(18.0 if large else 14.0, 16.0 if large else 12.0)
	p.palette = TOWN
	var back := p.depth - 4.0
	p.set_values({"floor_y": 0.1, "floors": 2 if v == 2 else 1, "exterior_material": _mat("brick_red"),
			"floor_material": _mat("concrete_slab"), "upper_height": 1.2 if v != 2 else 0.0, "painted_windows": false})
	p.door("front", 0.0)
	p.opening("front", -p.width / 4.0 - 0.3, "window", p.width / 2.0 - 2.2, 0.5, 2.6)
	p.opening("front", p.width / 4.0 + 0.3, "window", p.width / 2.0 - 2.2, 0.5, 2.6)
	p.door("back", p.width / 2.0 - 2.0)
	p.inner(0, Vector2(back, -p.width / 2.0), Vector2(back, p.width / 2.0), [p.width - 2.5])
	p.room(0, Vector2(back / 2.0, 0), "Store floor")
	if large:
		p.inner(0, Vector2(back, 2), Vector2(p.depth, 2), [2.0])
		p.room(0, Vector2(back + 2.0, -4), "Stockroom")
		p.room(0, Vector2(back + 2.0, 5), "Office", "wood_floor")
	else:
		p.room(0, Vector2(back + 2.0, 0), "Stockroom")
	_front_sign(p, "GROCERY" if large else "STORE", 0.0, 3.0, Vector2(4.0, 0.7))
	if v == 2:
		# An apartment upstairs, the stairs up from the stockroom.
		p.stair(0, Vector2(back + 1.0, -5.2), 90.0)
		p.inner(1, Vector2(7, -6), Vector2(7, 6), [2.0, 9.0])
		p.inner(1, Vector2(7, 2), Vector2(14, 2), [5.0])
		p.room(1, Vector2(3.5, 0), "Living room", "wood_floor")
		p.room(1, Vector2(10.5, -3), "Kitchen")
		p.room(1, Vector2(10.5, 4), "Bedroom", "wood_floor")
		p.wins("front", [-3.0, 3.0], 1)
		p.wins("left", [3.5], 1)
		p.wins("right", [10.5], 1)
		p.set_value("roof_shape", "Flat")
	return p


static func _gas_station(v: int) -> Plan:
	var bay := v == 1
	var p := Plan.new(8.0, 16.0 if bay else 10.0)
	p.palette = ["siding_white", "stucco_white", "brick_tan"]
	p.set_values({"floor_y": 0.1, "exterior_material": _mat("stucco_white"), "floor_material": _mat("concrete_slab"),
			"upper_height": 0.8, "painted_windows": false})
	var shop_end := 1.0 if bay else 5.0 # z where the shop ends (the bay past it)
	p.door("front", -2.5)
	p.opening("front", 0.5, "window", 2.5, 0.6, 2.4)
	p.inner(0, Vector2(5.5, -5), Vector2(5.5, shop_end), [2.0])
	p.inner(0, Vector2(5.5, -1.5), Vector2(8, -1.5), [1.25])
	p.room(0, Vector2(2.75, -1.5), "Store floor")
	p.room(0, Vector2(6.75, -3.5), "Stockroom")
	p.room(0, Vector2(6.75, 0.0 if bay else 2.5), "Restroom")
	if bay:
		p.inner(0, Vector2(0, shop_end), Vector2(8, shop_end), [5.5])
		p.room(0, Vector2(4, 4.5), "Workshop")
		p.opening("front", 4.5, "garage door", 3.0, 0.0, 2.6)
	p.wins("left", [2.75])
	_front_sign(p, "GAS", -1.5 if bay else 0.0, 3.2, Vector2(2.5, 0.7))
	# The canopy over the pumps, out front.
	var deep := 7.0 if v == 2 else 5.0
	var wide := 12.0 if v == 2 else 7.0
	var cx := -3.5 - deep / 2.0
	var cz := -2.0
	for x: float in [cx - deep / 2.0 + 0.3, cx + deep / 2.0 - 0.3]:
		for z: float in [cz - wide / 2.0 + 0.3, cz + wide / 2.0 - 0.3]:
			p.extras.append(_box(Vector3(0.35, 4.6, 0.35), Vector3(x, 2.3, z), "steel", "CanopyPost"))
	p.extras.append(_box(Vector3(deep + 0.6, 0.5, wide + 0.6), Vector3(cx, 4.85, cz), "siding_white", "Canopy"))
	var islands := [cz] if v != 2 else [cz - 3.0, cz + 3.0]
	for z: float in islands:
		p.extras.append(_box(Vector3(1.0, 0.15, 3.6), Vector3(cx, 0.075, z), "concrete_slab", "PumpIsland"))
		for d: float in [-1.0, 1.0]:
			p.extras.append(_piece("gas_pump", Vector3(cx, 0.15, z + d), 90.0))
	p.extras.append(_sign("GAS", Vector3(cx - deep / 2.0 - 1.5, 0, cz + wide / 2.0 + 1.5), -90.0, Vector2(2.0, 1.2), true))
	return p


static func _diner(v: int) -> Plan:
	var small := v == 1
	var p := Plan.new(8.0 if small else 10.0, 10.0 if small else 14.0)
	p.palette = ["stucco_white", "siding_cream", "brick_red"]
	p.set_values({"floor_y": 0.3, "exterior_material": _mat("brick_red" if v == 2 else "siding_cream"),
			"floor_material": _mat("concrete_slab"), "upper_height": 0.6, "painted_windows": false})
	var back := p.depth - 3.5
	p.door("front", 0.0)
	p.opening("front", -p.width / 4.0 - 0.4, "window", p.width / 2.0 - 2.4, 0.9, 2.3)
	p.opening("front", p.width / 4.0 + 0.4, "window", p.width / 2.0 - 2.4, 0.9, 2.3)
	p.door("back", -p.width / 2.0 + 2.0)
	p.inner(0, Vector2(back, -p.width / 2.0), Vector2(back, p.width / 2.0), [p.width / 2.0 - 2.5, p.width - 1.5])
	p.inner(0, Vector2(back, p.width / 2.0 - 3.0), Vector2(p.depth, p.width / 2.0 - 3.0), [])
	p.room(0, Vector2(back / 2.0, 0), "Diner seating")
	p.room(0, Vector2(back + 1.75, -2.0), "Diner kitchen")
	p.room(0, Vector2(back + 1.75, p.width / 2.0 - 1.5), "Restroom")
	p.wins("left", [3.0])
	p.wins("right", [3.0])
	p.porch([0], "Open", 1.6, 0.0, 3.0)
	_front_sign(p, "DINER", 0.0, 3.0, Vector2(3.0, 0.7))
	return p


static func _church(v: int) -> Plan:
	var chapel := v == 0
	var p := Plan.new(12.0 if chapel else 16.0, 8.0 if chapel else 10.0)
	p.palette = ["siding_white", "stone_gray", "brick_red"]
	p.set_values({"floor_y": 0.5, "roof_shape": "Gable", "roof_pitch": 45.0,
			"exterior_material": _mat("brick_red" if v == 2 else "siding_white"), "foundation": "Stone"})
	p.opening("front", 0.0, "door", 2.0, 0.0, 2.8)
	var back := p.depth - (0.0 if chapel else 3.0)
	for x in range(2, int(back) - 1, 3):
		p.opening("left", float(x), "window", 1.0, 1.0, 3.0)
		p.opening("right", float(x), "window", 1.0, 1.0, 3.0)
	p.room(0, Vector2(back / 2.0, 0), "Sanctuary", "wood_floor")
	if not chapel:
		p.inner(0, Vector2(back, -5), Vector2(back, 5), [7.5])
		p.room(0, Vector2(back + 1.5, -1), "Office")
		p.door("back", 3.0)
	p.porch([0], "Open", 2.0, 0.0, 4.0)
	p.extras.append(_sign("CHURCH", Vector3(-4.5, 0, p.width / 2.0 + 1.5), -90.0, Vector2(2.4, 0.8), true))
	if not chapel:
		var steeple := KitSteeple.new()
		steeple.width = 2.6
		steeple.tower = 5.5
		steeple.spire = 6.0
		steeple.wall_material = _mat("brick_red" if v == 2 else "siding_white")
		steeple.position = Vector3(1.6, 3.6, 0)
		p.extras.append(steeple)
	return p


static func _school(v: int) -> Plan:
	var p: Plan
	if v == 0:
		p = Plan.new(10.0, 8.0)
		p.set_values({"floor_y": 0.4, "roof_shape": "Gable", "roof_pitch": 40.0, "exterior_material": _mat("barn_red")})
		p.door("front", 0.0)
		p.wins("left", [2.0, 5.0, 8.0])
		p.wins("right", [2.0, 5.0, 8.0])
		p.room(0, Vector2(5, 0), "Classroom", "wood_floor")
		p.porch([0], "Roofed", 1.8, 0.0, 3.6)
		var bell := KitSteeple.new()
		bell.width = 1.6
		bell.tower = 2.0
		bell.spire = 2.0
		bell.wall_material = _mat("siding_white")
		bell.position = Vector3(1.2, 3.6, 0)
		p.extras.append(bell)
	elif v == 1:
		p = Plan.new(10.0, 20.0)
		p.set_values({"floor_y": 0.2, "roof_shape": "Hip", "roof_pitch": 25.0, "exterior_material": _mat("brick_red")})
		p.door("front", 0.0)
		p.inner(0, Vector2(0, -2), Vector2(10, -2), [5.0])
		p.inner(0, Vector2(0, 2), Vector2(10, 2), [5.0])
		p.inner(0, Vector2(6.5, -2), Vector2(6.5, 2), [2.0])
		p.room(0, Vector2(5, -6), "Classroom")
		p.room(0, Vector2(5, 6), "Classroom")
		p.room(0, Vector2(8.25, 0), "Office", "wood_floor")
		p.wins("front", [-6.0, 6.0], 0, 3.0, 0.9, 2.4)
		p.wins("back", [-6.0, 6.0], 0, 3.0, 0.9, 2.4)
	else:
		p = Plan.new(20.0, 24.0)
		p.set_values({"floor_y": 0.2, "roof_shape": "Flat", "exterior_material": _mat("brick_tan"), "upper_height": 0.6,
				"painted_windows": false})
		p.door("front", 0.0)
		# A corridor across the middle (x 9 to 10.6), classrooms either side.
		p.inner(0, Vector2(9, -12), Vector2(9, 12), [5.0, 12.0, 19.0])
		p.inner(0, Vector2(10.6, -12), Vector2(10.6, 12), [5.0, 12.5, 19.0])
		for z: float in [-4.0, 4.0]:
			p.inner(0, Vector2(0, z), Vector2(9, z), [])
		p.inner(0, Vector2(10.6, 0), Vector2(20, 0), [])
		p.inner(0, Vector2(0, -1.0), Vector2(9, -1.0), [4.5])
		p.room(0, Vector2(4.5, -8), "Classroom")
		p.room(0, Vector2(4.5, 8), "Classroom")
		p.room(0, Vector2(4.5, -2.5), "Office", "wood_floor")
		p.room(0, Vector2(15, -6), "Classroom")
		p.room(0, Vector2(15, 6), "Classroom")
		p.wins("front", [-8.0, 8.0], 0, 3.0, 0.9, 2.4)
		p.wins("back", [-6.0, 6.0], 0, 3.0, 0.9, 2.4)
	p.palette = ["brick_red", "brick_tan", "barn_red"]
	_front_sign(p, "SCHOOL", -3.0 if v == 0 else 0.0, 3.0, Vector2(2.6, 0.6))
	var side := p.width / 2.0
	p.extras.append(_piece("flagpole", Vector3(-4.0, 0, -side + 1.0)))
	p.extras.append(_piece("swing_set", Vector3(p.depth / 2.0, 0, side + 4.0), 90.0))
	p.extras.append(_piece("slide", Vector3(p.depth / 2.0 + 4.0, 0, side + 4.0), 90.0))
	return p


static func _police(v: int) -> Plan:
	var cells := v == 1
	var p := Plan.new(14.0 if cells else 12.0, 14.0)
	p.palette = ["brick_tan", "brick_brown", "brick_red"]
	p.set_values({"floor_y": 0.1, "floors": 2 if v == 2 else 1, "exterior_material": _mat("brick_tan"),
			"floor_material": _mat("concrete_slab"), "upper_height": 0.6, "painted_windows": false})
	p.door("front", 0.0)
	p.wins("front", [-4.5, 4.5], 0, 2.0)
	p.inner(0, Vector2(7, -7), Vector2(7, 7), [2.0, 12.0])
	p.room(0, Vector2(3.5, 0), "Police office")
	if cells:
		# A corridor behind the office, three cells behind bars off it.
		for z: float in [-2.5, 2.5]:
			p.inner(0, Vector2(10, z), Vector2(14, z), [])
		p.room(0, Vector2(12, 0), "Cells")
		for z: float in [-4.8, 0.0, 4.8]:
			for d: float in [-1.6, 1.6]:
				p.extras.append(_piece("cell_bars", Vector3(10.0, 0.1, z + d), 90.0))
			if z != 0.0:
				p.extras.append(_piece("bed", Vector3(12.5, 0.1, z + signf(z) * 0.5), 90.0))
	else:
		p.inner(0, Vector2(7, 1), Vector2(12, 1), [])
		p.room(0, Vector2(9.5, -3), "Cells")
		p.room(0, Vector2(9.5, 4), "Restroom")
	if v == 2:
		# Upstairs from the front office, along its side wall.
		p.stair(0, Vector2(1.2, 6.2), -90.0)
		p.inner(1, Vector2(7, -7), Vector2(7, 7), [4.0])
		p.room(1, Vector2(3.5, -3), "Office", "wood_floor")
		p.room(1, Vector2(9.5, 0), "Police office")
		p.wins("front", [-4.5, 0.0, 4.5], 1)
	_front_sign(p, "POLICE", 0.0, 3.0, Vector2(3.0, 0.7))
	p.extras.append(_piece("flagpole", Vector3(-4.0, 0, -6.0)))
	return p


# --- Farm -------------------------------------------------------------------------------

static func _barn(v: int) -> Plan:
	var small := v == 2
	var p := Plan.new(8.0 if small else 16.0, 8.0 if small else 12.0)
	p.palette = FARM
	p.set_values({"floor_y": 0.05, "exterior_material": _mat("barn_red"), "floor_material": _mat("concrete_slab"),
			"roof_material": _mat("metal_gray")})
	p.opening("front", 0.0, "garage door", 3.6, 0.0, 3.2)
	if small:
		p.set_values({"roof_shape": "Shed", "roof_pitch": 15.0})
		p.room(0, Vector2(4, 0), "Barn stalls")
		p.wins("left", [4.0], 0, 1.0, 1.4, 2.2)
		return p
	if v == 0:
		p.set_values({"floors": 2, "roof_shape": "Gambrel", "roof_pitch": 35.0})
		p.room(0, Vector2(8, 0), "Barn stalls")
		p.room(1, Vector2(8, 0), "Hayloft", "wood_planks")
		p.stair(0, Vector2(2.5, 5.0), 0.0)
		p.opening("front", 0.0, "doorway", 1.6, 0.6, 2.6, 1) # the hay door
		p.opening("back", 0.0, "garage door", 3.6, 0.0, 3.2)
	else:
		p.set_values({"roof_shape": "Gable", "roof_pitch": 35.0})
		p.inner(0, Vector2(11, -6), Vector2(11, 6), [3.0])
		p.room(0, Vector2(5.5, 0), "Barn stalls")
		p.room(0, Vector2(13.5, 0), "Workshop")
		p.door("back", 3.0)
	p.wins("left", [4.0, 8.0, 12.0], 0, 1.0, 1.4, 2.2)
	p.wins("right", [4.0, 8.0, 12.0], 0, 1.0, 1.4, 2.2)
	return p


static func _machine_shed(v: int) -> Plan:
	var large := v == 2
	var p := Plan.new(16.0 if large else 12.0, 24.0 if large else 18.0)
	p.palette = ["metal_siding", "metal_siding", "barn_red"]
	p.set_values({"floor_y": 0.05, "roof_shape": "Gable", "roof_pitch": 18.0, "roof_overhang": 0.3,
			"exterior_material": _mat("metal_siding"), "roof_material": _mat("metal_gray"),
			"floor_material": _mat("concrete_slab"), "foundation": "Concrete block"})
	var bays := 3
	var bay_w := p.width / bays
	for i in bays:
		var z := -p.width / 2.0 + bay_w * (i + 0.5)
		if v == 0:
			p.opening("front", z, "doorway", bay_w - 1.0, 0.0, 3.2)
		elif not (large and i == bays - 1):
			p.opening("front", z, "garage door", 4.0, 0.0, 3.0)
	p.room(0, Vector2(p.depth / 2.0, -p.width / 6.0), "Machine bay")
	if large:
		p.inner(0, Vector2(0, p.width / 2.0 - bay_w), Vector2(p.depth, p.width / 2.0 - bay_w), [p.depth / 2.0])
		p.room(0, Vector2(p.depth / 2.0, p.width / 2.0 - bay_w / 2.0), "Workshop")
		p.door("front", p.width / 2.0 - bay_w / 2.0)
	p.door("back", 0.0)
	p.wins("left", [p.depth / 2.0], 0, 1.4, 1.4, 2.4)
	return p


## A building's settings, made up wall by wall. Positions along a wall are
## the building's own coordinate along it (z for the front and back, x for
## the sides); they're turned into openings' Offsets here.
class Plan:
	var depth: float
	var width: float
	var palette: Array = []
	var extras: Array[Node3D] = []
	var _values := {}
	var _openings: Array[KitOpening] = []
	var _inner: Array[KitInnerWall] = []
	var _rooms: Array[KitRoom] = []
	var _stairs: Array[KitStair] = []
	var _porches: Array[KitPorch] = []
	var _cellars: Array[KitCellarDoor] = []
	var _chimneys: Array[KitChimney] = []
	var _dormers: Array[KitDormer] = []

	func _init(d: float, w: float) -> void:
		size(d, w)

	func size(d: float, w: float) -> void:
		depth = d
		width = w

	func set_value(property: String, value: Variant) -> void:
		_values[property] = value

	func set_values(values: Dictionary) -> void:
		_values.merge(values, true)

	## A wall's Offset for a point along it (see the top).
	func offset(wall: String, at: float) -> float:
		match wall:
			"front": return at
			"right": return at - depth / 2.0
			"back": return -at
			_: return depth / 2.0 - at # left

	func opening(wall: String, at: float, kind: String, w: float, bottom: float, top: float, level := 0) -> void:
		var op := KitOpening.make(wall, kind, offset(wall, at), w, bottom, top)
		op.level = level
		if kind == "garage door":
			op.door_color = Color(0.85, 0.85, 0.82)
		_openings.append(op)

	func door(wall: String, at: float, level := 0) -> void:
		opening(wall, at, "door", 1.6, 0.0, 2.4, level)

	func wins(wall: String, ats: Array, level := 0, w := 1.2, bottom := 0.9, top := 2.3) -> void:
		for at: float in ats:
			opening(wall, at, "window", w, bottom, top, level)

	## An inner wall from a to b with doorways (1.6 m) this far along from a.
	func inner(level: int, a: Vector2, b: Vector2, doorways: Array) -> void:
		var wall := KitInnerWall.make(level, a, b)
		var ops: Array[KitOpening] = []
		var length := a.distance_to(b)
		for at: float in doorways:
			ops.append(KitOpening.make("front", "doorway", at - length / 2.0, 1.6, 0.0, 2.4))
		wall.openings = ops
		_inner.append(wall)

	func room(level: int, point: Vector2, kind: String, floor := "") -> void:
		var r := KitRoom.make(level, point, kind)
		if floor != "":
			r.floor_material = load(M + floor + ".tres")
		_rooms.append(r)

	func stair(level: int, start: Vector2, degrees: float) -> void:
		_stairs.append(KitStair.make(level, start, degrees))

	## A porch along walls (by number), its steps at `steps_at` along the first
	## (a building coordinate, as for openings); on one wall, `length` long (0:
	## the whole wall), centered on the steps.
	func porch(walls: Array, kind: String, porch_depth: float, steps_at: float, length := 0.0) -> void:
		var porch := KitPorch.make(PackedInt32Array(walls), kind)
		porch.depth = porch_depth
		var names := ["front", "right", "back", "left"]
		porch.steps_offset = offset(names[walls[0]], steps_at)
		if walls.size() == 1 and length > 0.0:
			porch.length = length
			porch.offset = porch.steps_offset
		_porches.append(porch)

	func cellar(wall: String, at: float) -> void:
		_cellars.append(KitCellarDoor.make(["front", "right", "back", "left"].find(wall), offset(wall, at)))

	func chimney(at: Vector2) -> void:
		_chimneys.append(KitChimney.make(at))

	func dormer(at: Vector2) -> void:
		_dormers.append(KitDormer.make(at))

	func result() -> Dictionary:
		var r := _values.duplicate()
		r["size_depth"] = depth
		r["size_width"] = width
		r["openings"] = _openings
		r["inner_walls"] = _inner
		r["rooms"] = _rooms
		r["stairs"] = _stairs
		r["porches"] = _porches
		r["cellar_doors"] = _cellars
		r["chimneys"] = _chimneys
		r["dormers"] = _dormers
		r["extras"] = extras
		return r
