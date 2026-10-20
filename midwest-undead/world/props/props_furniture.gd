extends "res://world/props/prop_builder.gd"
## Furniture stand-ins (each at its furniture scene's default Size), and the
## newer furniture pieces' own scenes if they're missing (make_props.gd).


func make() -> void:
	_furniture()
	_more_furniture()


func _furniture() -> void:
	var s: Node3D
	s = _start("Table")
	_box(s, Vector3(1.2, 0.06, 1.8), Vector3(0, 0.77, 0), _mat("wood_planks"), "Paint")
	for x: float in [-0.52, 0.52]:
		for z: float in [-0.82, 0.82]:
			_box(s, Vector3(0.07, 0.74, 0.07), Vector3(x, 0.37, z), _mat("wood_planks"))
	_save(FURNITURE + "table.tscn")

	s = _start("Desk")
	_box(s, Vector3(1.0, 0.05, 2.2), Vector3(0, 0.825, 0), _mat("wood_planks"), "Paint")
	_box(s, Vector3(0.95, 0.78, 0.5), Vector3(0, 0.39, 0.8), _mat("wood_planks")) # drawers
	for i in 3:
		_box(s, Vector3(0.02, 0.2, 0.42), Vector3(-0.48, 0.14 + i * 0.25, 0.8), _c(TABLE_WOOD.darkened(0.3)))
		_box(s, Vector3(0.03, 0.03, 0.12), Vector3(-0.5, 0.2 + i * 0.25, 0.8), _c(HANDLE))
	for z: float in [-1.02, 0.5]:
		_box(s, Vector3(0.9, 0.78, 0.04), Vector3(0, 0.39, z), _mat("wood_planks"))
	_save(FURNITURE + "desk.tscn")

	s = _start("Bed")
	_box(s, Vector3(2.0, 0.25, 1.4), Vector3(0, 0.15, 0), _mat("wood_planks")) # frame
	_box(s, Vector3(1.95, 0.2, 1.35), Vector3(0, 0.37, 0), _mat("fabric_bed"), "Paint") # mattress
	_box(s, Vector3(0.1, 0.75, 1.4), Vector3(-0.95, 0.375, 0), _mat("wood_planks")) # headboard
	_box(s, Vector3(0.4, 0.12, 1.0), Vector3(-0.7, 0.53, 0), _c(PILLOW))
	_box(s, Vector3(1.2, 0.04, 1.38), Vector3(0.35, 0.48, 0), _c(SHEET)) # blanket
	_save(FURNITURE + "bed.tscn")

	s = _start("Dresser")
	_box(s, Vector3(1.2, 1.1, 0.5), Vector3(0, 0.55, 0), _mat("wood_planks"), "Paint")
	for i in 4:
		_box(s, Vector3(1.1, 0.22, 0.02), Vector3(0, 0.15 + i * 0.26, 0.255), _c(TABLE_WOOD.darkened(0.25)))
		for x: float in [-0.3, 0.3]:
			_box(s, Vector3(0.12, 0.03, 0.03), Vector3(x, 0.17 + i * 0.26, 0.275), _c(HANDLE))
	_save(FURNITURE + "dresser.tscn")

	s = _start("Counter")
	_box(s, Vector3(0.8, 0.94, 3.0), Vector3(0, 0.47, 0), _mat("cabinet"), "Paint")
	_box(s, Vector3(0.86, 0.06, 3.04), Vector3(0, 0.97, 0), _mat("concrete_slab")) # top
	_box(s, Vector3(0.02, 0.1, 3.0), Vector3(0.4, 0.05, 0), _c(RUBBER)) # kick plate
	_save(FURNITURE + "counter.tscn")

	s = _start("KitchenCabinet")
	_box(s, Vector3(0.6, 0.86, 2.4), Vector3(0, 0.43, 0), _mat("cabinet"), "Paint")
	_box(s, Vector3(0.64, 0.04, 2.44), Vector3(0, 0.88, 0), _mat("concrete_slab"))
	for i in 4:
		var z := -0.9 + i * 0.6
		_box(s, Vector3(0.02, 0.7, 0.56), Vector3(0.31, 0.43, z), _c(Color(0.75, 0.72, 0.65)))
		_box(s, Vector3(0.03, 0.12, 0.03), Vector3(0.33, 0.62, z + 0.2), _c(CHROME))
	_save(FURNITURE + "kitchen_cabinet.tscn")

	s = _start("Shelf")
	_shelves(s, Vector3(4.0, 1.8, 0.5), 4, _mat("shelf_metal"))
	_save(FURNITURE + "shelf.tscn")

	s = _start("GroceryShelf")
	_shelves(s, Vector3(1.6, 1.4, 0.5), 3, _mat("shelf_metal"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for level in 3: # cans and boxes on each shelf
		for i in 6:
			var c := Color.from_hsv(rng.randf(), 0.5, 0.6)
			_box(s, Vector3(0.18, 0.2, 0.25), Vector3(-0.65 + i * 0.26, 0.2 + level * 0.45, 0.05), _c(c))
	_save(FURNITURE + "grocery_shelf.tscn")

	s = _start("CardboardBoxes")
	_box(s, Vector3(0.5, 0.35, 0.5), Vector3(-0.12, 0.175, -0.1), _mat("cardboard"), "Paint")
	_box(s, Vector3(0.4, 0.3, 0.4), Vector3(0.18, 0.15, 0.18), _mat("cardboard"), "Paint2", 0.3)
	_box(s, Vector3(0.38, 0.3, 0.38), Vector3(-0.08, 0.5, -0.05), _mat("cardboard"), "Paint3", -0.2)
	_save(FURNITURE + "cardboard_boxes.tscn")

	s = _start("SupplyCrate")
	_box(s, Vector3(1.0, 0.9, 1.4), Vector3(0, 0.45, 0), _mat("crate_wood"), "Paint")
	for z: float in [-0.66, 0.66]:
		_box(s, Vector3(1.04, 0.1, 0.1), Vector3(0, 0.1, z), _c(WOOD_DARK))
		_box(s, Vector3(1.04, 0.1, 0.1), Vector3(0, 0.8, z), _c(WOOD_DARK))
	_box(s, Vector3(1.04, 0.08, 1.44), Vector3(0, 0.88, 0), _c(WOOD_DARK)) # lid
	_save(FURNITURE + "supply_crate.tscn")

	s = _start("Dumpster")
	_box(s, Vector3(2.0, 1.1, 1.2), Vector3(0, 0.65, 0), _mat("dumpster_green"), "Paint")
	_box(s, Vector3(2.04, 0.06, 1.3), Vector3(0, 1.23, -0.03), _mat("dumpster_green"), "Paint2", 0.0, 0.08) # lid, a little open
	for x: float in [-0.8, 0.8]:
		for z: float in [-0.45, 0.45]:
			_cyl(s, 0.08, 0.06, Vector3(x, 0.08, z), _c(RUBBER), Vector3(0, 0, PI / 2.0))
	_save(FURNITURE + "dumpster.tscn")

	s = _start("Car") # body, cabin and wheels
	_box(s, Vector3(1.9, 0.55, 4.4), Vector3(0, 0.6, 0), _mat("car_red"), "Paint")
	_box(s, Vector3(1.7, 0.55, 2.2), Vector3(0, 1.15, 0.15), _mat("car_red"), "Paint2")
	_box(s, Vector3(1.72, 0.42, 2.0), Vector3(0, 1.16, 0.15), _mat("car_cabin")) # windows
	_box(s, Vector3(1.6, 0.4, 0.05), Vector3(0, 1.1, -0.95), _mat("car_cabin"), "", 0.0, 0.5) # windshield
	for x: float in [-0.85, 0.85]:
		for z: float in [-1.4, 1.4]:
			_cyl(s, 0.34, 0.24, Vector3(x, 0.34, z), _c(RUBBER), Vector3(0, 0, PI / 2.0))
			_cyl(s, 0.18, 0.25, Vector3(x, 0.34, z), _c(CHROME), Vector3(0, 0, PI / 2.0))
	for x: float in [-0.6, 0.6]:
		_box(s, Vector3(0.3, 0.15, 0.04), Vector3(x, 0.7, -2.2), _c(Color(0.95, 0.95, 0.85))) # headlights
		_box(s, Vector3(0.3, 0.12, 0.04), Vector3(x, 0.72, 2.2), _c(Color(0.7, 0.1, 0.1))) # tail lights
	_save(FURNITURE + "car.tscn")


## The furniture that rooms are furnished with (world/kit/kit_furnish.gd):
## each one's width along X, height, depth along Z, its back at -Z.
## [name, size, solid, container loot table ("" = not a container), label, salvage label]
const MORE_FURNITURE := [
	["couch", Vector3(2.0, 0.85, 0.9), true, "", "", ""],
	["armchair", Vector3(0.9, 0.9, 0.85), true, "", "", ""],
	["chair", Vector3(0.45, 0.9, 0.45), false, "", "", ""],
	["coffee_table", Vector3(1.1, 0.45, 0.6), true, "", "", ""],
	["tv", Vector3(1.2, 1.15, 0.45), true, "", "", ""],
	["bookcase", Vector3(1.0, 2.0, 0.35), true, "", "", "Bookcase"],
	["nightstand", Vector3(0.5, 0.6, 0.42), true, "bedroom", "Nightstand", ""],
	["fridge", Vector3(0.8, 1.8, 0.75), true, "kitchen", "Fridge", ""],
	["stove", Vector3(0.76, 0.95, 0.65), true, "", "", "Stove"],
	["sink_cabinet", Vector3(1.2, 0.92, 0.6), true, "kitchen", "Sink cabinet", ""],
	["toilet", Vector3(0.45, 0.8, 0.7), true, "", "", ""],
	["bathtub", Vector3(1.7, 0.55, 0.75), true, "", "", ""],
	["bathroom_sink", Vector3(0.6, 1.8, 0.45), true, "bathroom", "Medicine cabinet", ""],
	["washer", Vector3(0.65, 0.9, 0.65), true, "", "", "Washer"],
	["workbench", Vector3(2.0, 0.92, 0.7), true, "workshop", "Workbench", ""],
	["filing_cabinet", Vector3(0.5, 1.3, 0.6), true, "office", "Filing cabinet", ""],
	["gun_locker", Vector3(1.0, 1.9, 0.5), true, "police", "Gun locker", ""],
	["school_desk", Vector3(0.65, 0.76, 0.5), false, "", "", ""],
	["chalkboard", Vector3(2.4, 2.1, 0.08), true, "", "", ""],
	["pew", Vector3(2.4, 0.95, 0.6), true, "", "", "Pew"],
	["altar", Vector3(1.6, 1.0, 0.7), true, "", "", ""],
	["booth", Vector3(1.2, 1.1, 1.9), true, "", "", ""],
	["stool", Vector3(0.4, 0.75, 0.4), false, "", "", ""],
	["cell_bars", Vector3(1.0, 2.6, 0.1), true, "", "", ""],
	["hay_bale", Vector3(1.2, 0.45, 0.5), true, "", "", ""],
	["feed_trough", Vector3(2.0, 0.6, 0.6), true, "farm", "Feed bin", ""],
	["tractor", Vector3(2.0, 2.3, 3.6), true, "", "", "Tractor"],
	["gas_pump", Vector3(0.8, 1.8, 0.5), true, "", "", "Gas pump"],
	["flagpole", Vector3(1.7, 7.5, 0.3), false, "", "", ""], # (its box takes in the flag)
	["swing_set", Vector3(3.2, 2.3, 1.6), false, "", "", ""],
	["slide", Vector3(0.7, 1.8, 3.0), false, "", "", ""],
	["mine_cart", Vector3(0.9, 1.0, 1.3), true, "", "", ""], # (on a mine's rails: kit_mine.gd)
	["miner_locker", Vector3(0.6, 1.9, 0.5), true, "miner", "Miner's locker", ""],
	["supply_cache", Vector3(1.1, 0.7, 0.6), true, "mine_cache", "Supply cache", ""],
]


func _more_furniture() -> void:
	var wood := _mat("wood_planks")
	var fabric := _c(Color(0.42, 0.36, 0.3))
	var white := _c(Color(0.9, 0.9, 0.87))
	var steel := _mat("steel")
	var s: Node3D

	s = _start("Couch")
	_box(s, Vector3(2.0, 0.42, 0.9), Vector3(0, 0.21, 0), fabric, "Paint")
	_box(s, Vector3(2.0, 0.45, 0.22), Vector3(0, 0.62, -0.34), fabric, "Paint2") # back
	for x: float in [-0.9, 0.9]:
		_box(s, Vector3(0.2, 0.3, 0.9), Vector3(x, 0.55, 0), fabric, "Paint3" if x < 0 else "Paint4") # arms
	for x: float in [-0.45, 0.45]:
		_box(s, Vector3(0.78, 0.12, 0.62), Vector3(x, 0.48, 0.1), fabric) # cushions
	_more("couch")

	s = _start("Armchair")
	_box(s, Vector3(0.9, 0.42, 0.85), Vector3(0, 0.21, 0), fabric, "Paint")
	_box(s, Vector3(0.9, 0.48, 0.2), Vector3(0, 0.64, -0.32), fabric, "Paint2")
	for x: float in [-0.37, 0.37]:
		_box(s, Vector3(0.16, 0.28, 0.85), Vector3(x, 0.55, 0), fabric, "Paint3" if x < 0 else "Paint4")
	_more("armchair")

	s = _start("Chair")
	_box(s, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.46, 0), wood, "Paint")
	_box(s, Vector3(0.45, 0.45, 0.04), Vector3(0, 0.68, -0.2), wood)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			_box(s, Vector3(0.04, 0.45, 0.04), Vector3(x, 0.22, z), wood)
	_more("chair")

	s = _start("CoffeeTable")
	_box(s, Vector3(1.1, 0.05, 0.6), Vector3(0, 0.42, 0), wood, "Paint")
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.25, 0.25]:
			_box(s, Vector3(0.05, 0.4, 0.05), Vector3(x, 0.2, z), wood)
	_more("coffee_table")

	s = _start("TV") # a set on a low stand
	_box(s, Vector3(1.2, 0.5, 0.45), Vector3(0, 0.25, 0), wood, "Paint")
	_box(s, Vector3(0.9, 0.6, 0.35), Vector3(0, 0.82, -0.02), _c(Color(0.12, 0.12, 0.12)))
	_box(s, Vector3(0.75, 0.48, 0.02), Vector3(0, 0.83, 0.16), _c(Color(0.2, 0.24, 0.26)))
	_more("tv")

	s = _start("Bookcase")
	_shelves(s, Vector3(1.0, 2.0, 0.35), 5, wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for level in 4: # rows of books
		var x := -0.44
		while x < 0.4:
			var w := rng.randf_range(0.04, 0.08)
			var h := rng.randf_range(0.22, 0.32)
			_box(s, Vector3(w, h, 0.22), Vector3(x + w / 2.0, 0.12 + level * 0.48 + h / 2.0, 0.02), _c(Color.from_hsv(rng.randf(), 0.45, 0.45)))
			x += w + 0.01
	_more("bookcase")

	s = _start("Nightstand")
	_box(s, Vector3(0.5, 0.6, 0.42), Vector3(0, 0.3, 0), wood, "Paint")
	_box(s, Vector3(0.44, 0.18, 0.02), Vector3(0, 0.45, 0.215), _c(TABLE_WOOD.darkened(0.25)))
	_box(s, Vector3(0.1, 0.03, 0.03), Vector3(0, 0.45, 0.235), _c(HANDLE))
	_more("nightstand")

	s = _start("Fridge")
	_box(s, Vector3(0.8, 1.8, 0.75), Vector3(0, 0.9, 0), white, "Paint")
	_box(s, Vector3(0.78, 0.02, 0.02), Vector3(0, 1.25, 0.38), _c(Color(0.6, 0.6, 0.6))) # door split
	for y: float in [1.0, 1.5]:
		_box(s, Vector3(0.03, 0.3, 0.04), Vector3(-0.33, y, 0.4), _c(CHROME))
	_more("fridge")

	s = _start("Stove")
	_box(s, Vector3(0.76, 0.9, 0.65), Vector3(0, 0.45, 0), white, "Paint")
	_box(s, Vector3(0.6, 0.4, 0.02), Vector3(0, 0.4, 0.33), _c(Color(0.1, 0.1, 0.1))) # oven window
	for x: float in [-0.18, 0.18]:
		for z: float in [-0.15, 0.15]:
			_cyl(s, 0.09, 0.02, Vector3(x, 0.91, z), _c(Color(0.15, 0.15, 0.15)), Vector3.ZERO)
	_box(s, Vector3(0.76, 0.2, 0.06), Vector3(0, 1.0, -0.3), white) # back panel
	_more("stove")

	s = _start("SinkCabinet")
	_box(s, Vector3(1.2, 0.86, 0.6), Vector3(0, 0.43, 0), _mat("cabinet"), "Paint")
	_box(s, Vector3(1.24, 0.04, 0.64), Vector3(0, 0.88, 0), _mat("concrete_slab"))
	_box(s, Vector3(0.6, 0.02, 0.38), Vector3(0, 0.905, 0.02), steel) # basin
	_cyl(s, 0.02, 0.25, Vector3(0, 1.0, -0.22), _c(CHROME), Vector3.ZERO) # tap
	_more("sink_cabinet")

	s = _start("Toilet")
	_box(s, Vector3(0.4, 0.4, 0.5), Vector3(0, 0.2, 0.08), white, "Paint")
	_box(s, Vector3(0.45, 0.4, 0.2), Vector3(0, 0.6, -0.25), white) # tank
	_box(s, Vector3(0.42, 0.03, 0.48), Vector3(0, 0.42, 0.08), white) # seat
	_more("toilet")

	s = _start("Bathtub")
	_box(s, Vector3(1.7, 0.5, 0.75), Vector3(0, 0.25, 0), white, "Paint")
	_box(s, Vector3(1.5, 0.05, 0.55), Vector3(0, 0.51, 0), _c(Color(0.7, 0.72, 0.74))) # inside
	_cyl(s, 0.025, 0.2, Vector3(-0.75, 0.62, -0.3), _c(CHROME), Vector3(PI / 2.0, 0, 0))
	_more("bathtub")

	s = _start("BathroomSink") # a basin on a pedestal, and a mirror cabinet over it
	_box(s, Vector3(0.6, 0.15, 0.45), Vector3(0, 0.8, 0), white, "Paint")
	_box(s, Vector3(0.2, 0.75, 0.2), Vector3(0, 0.37, -0.1), white)
	_box(s, Vector3(0.55, 0.65, 0.14), Vector3(0, 1.45, -0.15), white, "Paint2")
	_box(s, Vector3(0.5, 0.58, 0.02), Vector3(0, 1.45, -0.07), _c(Color(0.6, 0.68, 0.72))) # mirror
	_more("bathroom_sink")

	s = _start("Washer")
	_box(s, Vector3(0.65, 0.9, 0.65), Vector3(0, 0.45, 0), white, "Paint")
	_cyl(s, 0.2, 0.03, Vector3(0, 0.5, 0.33), _c(Color(0.3, 0.33, 0.36)), Vector3(PI / 2.0, 0, 0))
	_more("washer")

	s = _start("Workbench")
	_box(s, Vector3(2.0, 0.08, 0.7), Vector3(0, 0.88, 0), wood, "Paint")
	for x: float in [-0.92, 0.92]:
		for z: float in [-0.3, 0.3]:
			_box(s, Vector3(0.08, 0.84, 0.08), Vector3(x, 0.42, z), _c(WOOD_DARK))
	_box(s, Vector3(1.9, 0.05, 0.6), Vector3(0, 0.25, 0), wood) # shelf under
	_box(s, Vector3(2.0, 0.8, 0.04), Vector3(0, 1.32, -0.33), _mat("plywood")) # pegboard
	_box(s, Vector3(0.45, 0.2, 0.22), Vector3(0.5, 1.02, 0.05), _c(Color(0.7, 0.12, 0.1))) # toolbox
	_more("workbench")

	s = _start("FilingCabinet")
	_box(s, Vector3(0.5, 1.3, 0.6), Vector3(0, 0.65, 0), _mat("metal_gray"), "Paint")
	for i in 4:
		_box(s, Vector3(0.44, 0.28, 0.02), Vector3(0, 0.18 + i * 0.31, 0.305), _c(Color(0.5, 0.52, 0.52)))
		_box(s, Vector3(0.12, 0.03, 0.03), Vector3(0, 0.26 + i * 0.31, 0.325), _c(CHROME))
	_more("filing_cabinet")

	s = _start("GunLocker")
	_box(s, Vector3(1.0, 1.9, 0.5), Vector3(0, 0.95, 0), _mat("metal_dark"), "Paint")
	_box(s, Vector3(0.02, 1.8, 0.02), Vector3(0, 0.95, 0.255), _c(Color(0.1, 0.1, 0.1)))
	for x: float in [-0.08, 0.08]:
		_box(s, Vector3(0.03, 0.25, 0.04), Vector3(x, 1.0, 0.27), _c(CHROME))
	_more("gun_locker")

	s = _start("SchoolDesk")
	_box(s, Vector3(0.65, 0.04, 0.5), Vector3(0, 0.74, 0.0), wood, "Paint")
	_box(s, Vector3(0.6, 0.2, 0.45), Vector3(0, 0.6, 0.0), steel) # book box
	for x: float in [-0.28, 0.28]:
		_box(s, Vector3(0.03, 0.5, 0.03), Vector3(x, 0.25, -0.15), steel)
	_box(s, Vector3(0.4, 0.04, 0.35), Vector3(0, 0.44, 0.4), wood) # its seat, in front
	_more("school_desk")

	s = _start("Chalkboard")
	_box(s, Vector3(2.4, 1.2, 0.05), Vector3(0, 1.5, 0), _c(Color(0.16, 0.24, 0.18)), "Paint")
	_box(s, Vector3(2.5, 0.06, 0.08), Vector3(0, 0.88, 0.02), wood) # chalk ledge
	_box(s, Vector3(2.5, 0.06, 0.06), Vector3(0, 2.13, 0), wood)
	_more("chalkboard")

	s = _start("Pew")
	_box(s, Vector3(2.4, 0.06, 0.45), Vector3(0, 0.45, 0.05), wood, "Paint")
	_box(s, Vector3(2.4, 0.55, 0.05), Vector3(0, 0.7, -0.22), wood)
	for x: float in [-1.17, 1.17]:
		_box(s, Vector3(0.06, 0.95, 0.6), Vector3(x, 0.475, 0), _c(WOOD_DARK))
	_more("pew")

	s = _start("Altar")
	_box(s, Vector3(1.6, 0.95, 0.7), Vector3(0, 0.475, 0), wood, "Paint")
	_box(s, Vector3(1.7, 0.05, 0.8), Vector3(0, 0.975, 0), _c(SHEET)) # cloth
	_more("altar")

	s = _start("Booth") # two benches facing each other across a table, out from the wall
	_box(s, Vector3(1.0, 0.05, 0.8), Vector3(0, 0.74, 0), wood, "Paint")
	_box(s, Vector3(0.1, 0.72, 0.1), Vector3(0, 0.36, 0), steel)
	for z: float in [-0.75, 0.75]:
		_box(s, Vector3(1.2, 0.45, 0.4), Vector3(0, 0.225, z), _c(Color(0.55, 0.12, 0.1)), "Paint2")
		_box(s, Vector3(1.2, 0.65, 0.12), Vector3(0, 0.77, z + signf(z) * 0.14), _c(Color(0.55, 0.12, 0.1)))
	_more("booth")

	s = _start("Stool")
	_cyl(s, 0.18, 0.06, Vector3(0, 0.72, 0), _c(Color(0.55, 0.12, 0.1)), Vector3.ZERO)
	_cyl(s, 0.03, 0.7, Vector3(0, 0.35, 0), _c(CHROME), Vector3.ZERO)
	_cyl(s, 0.17, 0.03, Vector3(0, 0.015, 0), _c(CHROME), Vector3.ZERO)
	_more("stool")

	s = _start("CellBars")
	_box(s, Vector3(1.0, 0.06, 0.08), Vector3(0, 2.57, 0), steel, "Paint")
	_box(s, Vector3(1.0, 0.06, 0.08), Vector3(0, 0.03, 0), steel)
	_box(s, Vector3(1.0, 0.04, 0.06), Vector3(0, 1.3, 0), steel)
	for i in 8:
		_cyl(s, 0.015, 2.6, Vector3(-0.44 + i * 0.125, 1.3, 0), steel, Vector3.ZERO)
	_more("cell_bars")

	s = _start("HayBale")
	_box(s, Vector3(1.2, 0.45, 0.5), Vector3(0, 0.225, 0), _c(Color(0.78, 0.68, 0.38)), "Paint")
	for x: float in [-0.35, 0.35]:
		_box(s, Vector3(0.02, 0.46, 0.51), Vector3(x, 0.225, 0), _c(Color(0.55, 0.45, 0.25)))
	_more("hay_bale")

	s = _start("FeedTrough")
	_box(s, Vector3(2.0, 0.5, 0.6), Vector3(0, 0.35, 0), wood, "Paint")
	_box(s, Vector3(1.9, 0.02, 0.5), Vector3(0, 0.6, 0), _c(Color(0.7, 0.6, 0.35))) # feed
	for x: float in [-0.9, 0.9]:
		_box(s, Vector3(0.1, 0.1, 0.6), Vector3(x, 0.05, 0), _c(WOOD_DARK))
	_more("feed_trough")

	s = _start("Tractor") # facing +Z: hood forward, cab at the back
	var green := _c(Color(0.2, 0.42, 0.18))
	_box(s, Vector3(0.9, 0.9, 1.9), Vector3(0, 1.0, 0.75), green, "Paint") # hood
	_box(s, Vector3(1.2, 1.3, 1.1), Vector3(0, 1.55, -0.95), _mat("car_cabin")) # cab
	_box(s, Vector3(1.25, 0.08, 1.2), Vector3(0, 2.24, -0.95), green, "Paint2") # cab roof
	for x: float in [-0.85, 0.85]:
		_cyl(s, 0.75, 0.45, Vector3(x, 0.75, -1.0), _c(RUBBER), Vector3(0, 0, PI / 2.0))
		_cyl(s, 0.4, 0.25, Vector3(x * 0.8, 0.4, 1.3), _c(RUBBER), Vector3(0, 0, PI / 2.0))
	_cyl(s, 0.06, 0.8, Vector3(0.3, 1.8, 1.2), _c(IRON), Vector3.ZERO) # stack
	_more("tractor")

	s = _start("GasPump")
	_box(s, Vector3(0.8, 0.3, 0.5), Vector3(0, 0.15, 0), _mat("concrete_slab")) # base
	_box(s, Vector3(0.7, 1.5, 0.45), Vector3(0, 1.05, 0), _mat("pump_red"), "Paint")
	_box(s, Vector3(0.5, 0.3, 0.02), Vector3(0, 1.45, 0.23), _c(Color(0.85, 0.85, 0.78))) # dials
	_box(s, Vector3(0.12, 0.25, 0.1), Vector3(0.3, 0.95, 0.28), _c(IRON)) # nozzle
	_more("gas_pump")

	s = _start("Flagpole") # the pole at the left end, the flag out to the right
	_cyl(s, 0.05, 7.5, Vector3(-0.7, 3.75, 0), _c(CHROME), Vector3.ZERO)
	_box(s, Vector3(0.3, 0.3, 0.3), Vector3(-0.7, 0.15, 0), _mat("concrete_slab"), "Paint")
	_box(s, Vector3(1.5, 0.9, 0.02), Vector3(0.1, 6.9, 0), _c(Color(0.7, 0.12, 0.14))) # the flag
	_box(s, Vector3(0.6, 0.45, 0.025), Vector3(-0.35, 7.12, 0), _c(Color(0.12, 0.18, 0.45)))
	_more("flagpole")

	s = _start("SwingSet")
	for x: float in [-1.5, 1.5]:
		for z: float in [-0.7, 0.7]:
			_box(s, Vector3(0.08, 2.4, 0.08), Vector3(x, 1.15, z * 0.5), _c(STEEL), "", 0.0, signf(z) * 0.3)
	_box(s, Vector3(3.2, 0.08, 0.08), Vector3(0, 2.25, 0), _c(STEEL), "Paint")
	for x: float in [-0.7, 0.7]:
		for d: float in [-0.2, 0.2]:
			_box(s, Vector3(0.015, 1.7, 0.015), Vector3(x + d, 1.4, 0), _c(IRON))
		_box(s, Vector3(0.5, 0.04, 0.2), Vector3(x, 0.55, 0), _c(RUBBER))
	_more("swing_set")

	s = _start("Slide")
	_box(s, Vector3(0.5, 0.06, 2.6), Vector3(0, 0.95, 0.55), _c(Color(0.85, 0.65, 0.1)), "Paint", 0.0, -0.62)
	_box(s, Vector3(0.6, 0.06, 0.6), Vector3(0, 1.75, -1.1), _c(STEEL))
	for x: float in [-0.25, 0.25]:
		_box(s, Vector3(0.05, 1.75, 0.05), Vector3(x, 0.875, -1.35), _c(STEEL))
		_box(s, Vector3(0.05, 1.75, 0.05), Vector3(x, 0.875, -0.85), _c(STEEL))
	for i in 5: # the ladder's rungs
		_box(s, Vector3(0.5, 0.04, 0.04), Vector3(0, 0.3 + i * 0.32, -1.38), _c(STEEL))
	_more("slide")

	s = _start("MineCart") # a rusty ore car: a tub on a frame, four wheels on the rails' gauge
	var rust := _mat("rust")
	_box(s, Vector3(0.84, 0.06, 1.24), Vector3(0, 0.3, 0), rust) # floor
	for x: float in [-0.42, 0.42]:
		_box(s, Vector3(0.05, 0.6, 1.3), Vector3(x * 1.04, 0.62, 0), rust, "Paint" if x < 0 else "", 0.0, 0.0, 0.12 * signf(x))
	for z: float in [-0.62, 0.62]:
		_box(s, Vector3(0.9, 0.6, 0.05), Vector3(0, 0.62, z), rust)
	_box(s, Vector3(0.95, 0.06, 0.08), Vector3(0, 0.94, -0.62), _c(IRON)) # rims
	_box(s, Vector3(0.95, 0.06, 0.08), Vector3(0, 0.94, 0.62), _c(IRON))
	for z: float in [-0.4, 0.4]:
		_box(s, Vector3(0.7, 0.08, 0.08), Vector3(0, 0.2, z), _c(IRON)) # axles
		for x: float in [-0.3, 0.3]:
			_cyl(s, 0.15, 0.06, Vector3(x, 0.15, z), _c(IRON), Vector3(0, 0, PI / 2.0))
	_box(s, Vector3(0.3, 0.06, 0.12), Vector3(0, 0.25, 0.7), _c(IRON)) # couplings
	_box(s, Vector3(0.3, 0.06, 0.12), Vector3(0, 0.25, -0.7), _c(IRON))
	_more("mine_cart")

	s = _start("MinerLocker") # a tall dented steel locker: vents, a handle, a padlock hasp
	var locker := _c(Color(0.32, 0.38, 0.33))
	_box(s, Vector3(0.6, 1.9, 0.5), Vector3(0, 0.95, 0), locker, "Paint")
	for i in 4: # vents
		_box(s, Vector3(0.3, 0.02, 0.01), Vector3(0, 1.6 + i * 0.05, 0.255), _c(IRON))
	_box(s, Vector3(0.03, 0.18, 0.03), Vector3(0.22, 1.0, 0.26), _c(CHROME))
	_box(s, Vector3(0.6, 0.04, 0.5), Vector3(0, 1.92, 0), _c(IRON))
	_more("miner_locker")

	s = _start("SupplyCache") # a stout wooden powder box, iron-banded, a stencil on the lid
	var crate := _mat("crate_wood")
	_box(s, Vector3(1.1, 0.6, 0.6), Vector3(0, 0.3, 0), crate, "Paint")
	_box(s, Vector3(1.12, 0.08, 0.62), Vector3(0, 0.64, 0), crate) # lid
	for x: float in [-0.4, 0.4]:
		_box(s, Vector3(0.05, 0.7, 0.62), Vector3(x, 0.35, 0), _c(IRON)) # bands
	_box(s, Vector3(0.5, 0.01, 0.2), Vector3(0, 0.685, 0), _c(Color(0.65, 0.1, 0.08))) # stencil
	_more("supply_cache")


## Saves the stand-in just made, and its furniture scene if there isn't one yet:
## a KitBox (or a container, KitContainer, if it has a loot table) of its size
## with the stand-in as its model.
func _more(name: String) -> void:
	_save(FURNITURE + name + ".tscn")
	var path := "res://world/kit/furniture/%s.tscn" % name
	if ResourceLoader.exists(path):
		return
	var info: Array = MORE_FURNITURE.filter(func(e: Array) -> bool: return e[0] == name)[0]
	var container: bool = info[3] != ""
	var root: StaticBody3D = (load("res://items/loot_spot.gd") if container else load("res://world/kit/kit_box.gd")).new()
	root.name = name.to_pascal_case()
	root.set("size", info[1])
	root.set("sits_on_floor", true)
	var look: Array[PackedScene] = [load(FURNITURE + name + ".tscn")]
	root.set("models", look)
	if not info[2]:
		root.set("solid", false)
	if container:
		root.set("label", info[4])
		root.set("loot_table", info[3])
	if info[5] != "":
		root.set_meta("salvage_label", info[5])
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
	else:
		_made += 1
	root.free()


## Shelving: uprights at the ends and the back, size.y high, `levels` shelves.
func _shelves(s: Node3D, size: Vector3, levels: int, mat: Material) -> void:
	for x: float in [-size.x / 2.0 + 0.03, size.x / 2.0 - 0.03]:
		_box(s, Vector3(0.05, size.y, size.z), Vector3(x, size.y / 2.0, 0), mat, "Paint")
	_box(s, Vector3(size.x, size.y, 0.03), Vector3(0, size.y / 2.0, -size.z / 2.0 + 0.015), mat)
	for i in levels:
		var y := 0.08 + i * (size.y - 0.1) / float(levels - 1) if levels > 1 else 0.08
		_box(s, Vector3(size.x - 0.06, 0.04, size.z), Vector3(0, y, 0), mat)
