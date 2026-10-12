extends RefCounted
## The small grocery market on the north-east corner of Main and 7th Street. It's
## the corner shop the town already builds there, made over: a sign out front,
## its counter and shelves relabeled, and two aisles of food added in the middle.
## Done this way (rather than building it separately) so the rest of the town and
## older saves are untouched; the new aisles come after every other container.
## Never instanced: main.gd calls build().

const WorldBuilder := preload("res://world/world_builder.gd")
const Building := preload("res://world/building.gd")

const CORNER := Vector2i(1, -1) # east of Main (side +1), north of 7th (dir -1)
const SHELF_COLOR := Color(0.62, 0.64, 0.6)


## rng: the grocery's own dice, for what's on the new aisles.
static func build(b: WorldBuilder, rng: RandomNumberGenerator) -> void:
	var shop: Building = b.corner_shops.get(CORNER)
	if shop == null:
		push_warning("No corner shop at Main & 7th for the grocery.")
		return

	var sign := Label3D.new()
	sign.text = "GROCERY"
	sign.font_size = 64
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(0.95, 0.9, 0.75)
	sign.position = Vector3(-0.06, 3.1, 0.0) # on the facade, above the windows
	sign.rotation.y = -PI / 2.0 # Label3D reads from its +Z side; turn that to face the street
	shop.add_child(sign)

	for spot in shop.loot_spots:
		if spot.label == "Counter":
			spot.label = "Checkout counter"
		else:
			spot.label = "Grocery shelf"
			spot.inventory.add("canned_food", rng.randi_range(1, 2)) # on top of its usual roll

	# Two short aisles between the checkout and the back shelves, clear of the
	# spots where a zombie might be standing (see Building._furnish).
	var half := shop.size_width / 2.0
	for s: int in [-1, 1]:
		var local := Vector3(shop.size_depth * 0.55, shop.FLOOR_Y + 0.7, s * half * 0.45)
		var aisle := b.add_loot(Vector3(1.6, 1.4, 0.5), shop.transform * local, SHELF_COLOR,
				"Grocery shelf", shop.rotation.y)
		aisle.inventory.add("canned_food", rng.randi_range(1, 3))
		if rng.randf() < 0.3:
			aisle.inventory.add("batteries", 1)


## Where it is, for the map screen's label.
static func map_position(b: WorldBuilder) -> Vector2:
	var shop: Building = b.corner_shops.get(CORNER)
	if shop == null:
		return Vector2.INF
	return Vector2(shop.global_position.x + shop.size_depth / 2.0, shop.global_position.z)
