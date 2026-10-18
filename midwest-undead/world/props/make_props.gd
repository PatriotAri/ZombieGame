extends SceneTree
## Builds the stand-ins: simple shapes that look like what they are, until
## there are models (HOW_TO_MODEL.md, "Props"). Run it from the project folder
## to rebuild them after changing this:
##   godot --headless --path . -s res://world/props/make_props.gd
## It writes:
##   world/kit/furniture/standins/<name>.tscn  furniture: each furniture scene's
##       first model (stretched to the piece's Size)
##   world/kit/furniture/<name>.tscn           the newer furniture pieces' own
##       scenes, only if missing (so their settings, once changed, are kept)
##   world/props/<name>.tscn                   a KitProp with its stand-in under
##       StandIn: things you build, camp props, doors, windows, planks. Set
##       Models on one of those to swap in a model (running this again keeps
##       the Models you set).
## Everything faces -Z like the rest of the kit, sits on its origin unless
## said otherwise, and is the size the game makes the thing.

const Structures := preload("res://world/structures.gd")
const Fortifications := preload("res://world/fortifications.gd")
const KitMesh := preload("res://world/kit/kit_mesh.gd")
const KitPropScript := preload("res://world/props/kit_prop.gd")

const FURNITURE := "res://world/kit/furniture/standins/"
const PROPS := "res://world/props/"
const M := "res://world/kit/materials/"

const WOOD := Structures.WOOD
const WOOD_DARK := Structures.WOOD_DARK
const STEEL := Structures.STEEL
const PLYWOOD := Structures.PLYWOOD
const METAL := Structures.METAL
const STONE := Color(0.42, 0.41, 0.39)
const LOG := Color(0.3, 0.2, 0.12)
const IRON := Color(0.14, 0.14, 0.15)
const CANVAS := Color(0.45, 0.47, 0.33)
const CANVAS_DARK := Color(0.36, 0.38, 0.26)
const TABLE_WOOD := Color(0.5, 0.37, 0.24)
const RADIO := Color(0.22, 0.27, 0.2)
const FIRE := Color(1.0, 0.55, 0.15)
const RUBBER := Color(0.08, 0.08, 0.08)
const CHROME := Color(0.7, 0.7, 0.72)
const PILLOW := Color(0.88, 0.86, 0.8)
const SHEET := Color(0.75, 0.78, 0.82)
const HANDLE := Color(0.6, 0.58, 0.5)

var _colors := {} # Color -> StandardMaterial3D, shared within one scene
var _root: Node3D
var _made := 0


func _initialize() -> void:
	_furniture()
	_more_furniture()
	_built()
	_camp()
	_openings()
	print("props: %d scenes saved" % _made)
	quit()


# --- Furniture (each at its furniture scene's default Size) ----------------------

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


# --- Things you build (structures.gd's sizes) ------------------------------------

func _built() -> void:
	var half := Structures.SCAFFOLD / 2.0
	var s: Node3D
	s = _start_prop("Scaffold")
	for x: float in [-half.x + 0.06, half.x - 0.06]:
		for z: float in [-half.z + 0.06, half.z - 0.06]:
			_box(s, Vector3(0.1, Structures.SCAFFOLD.y, 0.1), Vector3(x, half.y, z), _c(STEEL))
	for side in 4: # a diagonal brace on each face, and a rail around the middle
		var turn := side * PI / 2.0
		var out := Vector3(0, 0, half.z - 0.06).rotated(Vector3.UP, turn)
		_box(s, Vector3(Structures.SCAFFOLD.x * 1.15, 0.07, 0.05), out + Vector3(0, half.y, 0), _c(STEEL), "", turn, 0.0, 0.85)
		_box(s, Vector3(Structures.SCAFFOLD.x, 0.06, 0.05), out + Vector3(0, half.y, 0), _c(STEEL), "", turn)
	for i in 6: # boards across the top
		var z := -half.z + Structures.SCAFFOLD.z * (i + 0.5) / 6.0
		_box(s, Vector3(Structures.SCAFFOLD.x, 0.06, Structures.SCAFFOLD.z / 6.0 - 0.03), Vector3(0, Structures.SCAFFOLD.y - 0.03, z), _c(WOOD))
	_save(PROPS + "scaffold.tscn")

	s = _start_prop("GuardPost")
	_box(s, Vector3(Structures.SCAFFOLD.x, 0.05, Structures.SCAFFOLD.z), Vector3(0, 0.025, 0), _c(WOOD)) # floor
	for x: float in [-half.x + 0.07, half.x - 0.07]:
		for z: float in [-half.z + 0.07, half.z - 0.07]:
			_box(s, Vector3(0.12, Structures.POST_HEIGHT, 0.12), Vector3(x, Structures.POST_HEIGHT / 2.0, z), _c(WOOD_DARK))
	var short := (Structures.SCAFFOLD.x - Structures.POST_GAP) / 2.0
	var y := Structures.RAIL_HEIGHT / 2.0
	for rail: Array in [[Vector3(Structures.SCAFFOLD.x, Structures.RAIL_HEIGHT, 0.05), Vector3(0, y, -half.z + 0.03)],
			[Vector3(0.05, Structures.RAIL_HEIGHT, Structures.SCAFFOLD.z), Vector3(-half.x + 0.03, y, 0)],
			[Vector3(0.05, Structures.RAIL_HEIGHT, Structures.SCAFFOLD.z), Vector3(half.x - 0.03, y, 0)],
			[Vector3(short, Structures.RAIL_HEIGHT, 0.05), Vector3(-half.x + short / 2.0, y, half.z - 0.03)],
			[Vector3(short, Structures.RAIL_HEIGHT, 0.05), Vector3(half.x - short / 2.0, y, half.z - 0.03)]]:
		_box(s, rail[0], rail[1], _c(PLYWOOD))
	_box(s, Vector3(Structures.SCAFFOLD.x + 0.4, 0.1, Structures.SCAFFOLD.z + 0.4), Vector3(0, Structures.POST_HEIGHT, 0), _c(WOOD_DARK)) # roof
	_save(PROPS + "guard_post.tscn")

	var fence := Structures.FENCE
	s = _start_prop("Fence")
	for x: float in [-fence.x / 2.0, fence.x / 2.0]:
		_box(s, Vector3(0.14, fence.y + 0.1, 0.14), Vector3(x, (fence.y + 0.1) / 2.0, 0), _c(WOOD_DARK))
	_box(s, Vector3(fence.x, fence.y, 0.06), Vector3(0, fence.y / 2.0, 0), _c(PLYWOOD))
	for yy: float in [0.4, fence.y - 0.4]:
		for zz: float in [-0.05, 0.05]:
			_box(s, Vector3(fence.x, 0.1, 0.04), Vector3(0, yy, zz), _c(WOOD_DARK)) # rails both sides
	_save(PROPS + "fence.tscn")

	s = _start_prop("FencePlating") # sheet metal on both faces of a fence
	for z: float in [-0.08, 0.08]:
		_box(s, Vector3(fence.x - 0.1, fence.y - 0.1, 0.02), Vector3(0, fence.y / 2.0, z), _c(METAL))
	_save(PROPS + "fence_plating.tscn")

	s = _start_prop("FenceWreck") # a broken fence or gate: boards on the ground and a stump
	var wood := [Vector3(-0.8, 0.04, 0.3), Vector3(0.4, 0.04, -0.2), Vector3(0.9, 0.04, 0.5)]
	for i in wood.size():
		_box(s, Vector3(1.4, 0.05, 0.22), wood[i], _c(WOOD_DARK), "", 0.4 * (i - 1))
	_box(s, Vector3(0.14, 0.6, 0.14), Vector3(-fence.x / 2.0, 0.3, 0), _c(WOOD_DARK))
	_save(PROPS + "fence_wreck.tscn")

	s = _start_prop("GatePosts")
	for x: float in [-fence.x / 2.0, fence.x / 2.0]:
		_box(s, Vector3(0.16, fence.y + 0.2, 0.16), Vector3(x, (fence.y + 0.2) / 2.0, 0), _c(WOOD_DARK))
		_box(s, Vector3(0.22, 0.06, 0.22), Vector3(x, fence.y + 0.22, 0), _c(WOOD_DARK)) # caps
	_save(PROPS + "gate_posts.tscn")

	var width := fence.x - 0.2
	var leaf_middle := Vector3(fence.x / 2.0 - 0.08, 0, 0) # the leaf's origin is its hinge
	s = _start_prop("GateLeaf")
	for i in 5:
		var x := -width / 2.0 + width * (i + 0.5) / 5.0
		_box(s, Vector3(width / 5.0 - 0.04, fence.y - 0.15, 0.06), leaf_middle + Vector3(x, fence.y / 2.0 + 0.05, 0), _c(WOOD))
	for yy: float in [0.5, fence.y - 0.3]:
		_box(s, Vector3(width, 0.14, 0.08), leaf_middle + Vector3(0, yy, 0.05), _c(WOOD_DARK))
	_box(s, Vector3(width * 1.12, 0.12, 0.06), leaf_middle + Vector3(0, fence.y / 2.0, 0.06), _c(WOOD_DARK), "", 0.0, 0.0, 0.62) # brace
	for yy: float in [0.4, fence.y - 0.4]:
		_box(s, Vector3(0.14, 0.05, 0.1), Vector3(0.02, yy, 0.02), _c(IRON)) # hinges
	_save(PROPS + "gate_leaf.tscn")

	s = _start_prop("GatePlating") # on the leaf (hinge at the origin)
	for z: float in [-0.06, 0.1]:
		_box(s, Vector3(width, fence.y - 0.2, 0.02), leaf_middle + Vector3(0, fence.y / 2.0 + 0.05, z), _c(METAL))
	_save(PROPS + "gate_plating.tscn")

	s = _start_prop("Ladder") # one scaffold high; stretched to fit
	var h := Structures.SCAFFOLD.y
	for x: float in [-0.25, 0.25]:
		_box(s, Vector3(0.06, h + 1.0, 0.06), Vector3(x, (h + 1.0) / 2.0, 0), _c(WOOD_DARK))
	for i in int(h / 0.3):
		_box(s, Vector3(0.5, 0.04, 0.05), Vector3(0, 0.3 * (i + 1), 0), _c(WOOD))
	_save(PROPS + "ladder.tscn")

	var g := Structures.GARDEN / 2.0
	s = _start_prop("GardenPlot") # a raised bed of soil with rows of something growing
	for z: float in [-g.z, g.z]:
		_box(s, Vector3(Structures.GARDEN.x, Structures.GARDEN.y, 0.08), Vector3(0, g.y, z), _c(WOOD))
	for x: float in [-g.x, g.x]:
		_box(s, Vector3(0.08, Structures.GARDEN.y, Structures.GARDEN.z), Vector3(x, g.y, 0), _c(WOOD))
	_box(s, Vector3(Structures.GARDEN.x - 0.1, 0.05, Structures.GARDEN.z - 0.1), Vector3(0, Structures.GARDEN.y - 0.06, 0), _c(Structures.SOIL))
	for row in 3:
		for k in 6:
			var at := Vector3(-g.x + 0.3 + k * (Structures.GARDEN.x - 0.6) / 5.0, Structures.GARDEN.y + 0.08, -g.z + 0.45 + row * 0.55)
			_box(s, Vector3(0.22, 0.18, 0.22), at, _c(Structures.LEAVES), "", k * 0.7)
			_box(s, Vector3(0.04, 0.12, 0.04), at - Vector3(0, 0.12, 0), _c(Structures.LEAVES.darkened(0.3)))
	_save(PROPS + "garden_plot.tscn")

	var b := Structures.BENCH / 2.0
	for kind: String in Structures.BENCHES: # a heavy workbench with a press and a vise
		s = _start_prop(kind.to_pascal_case())
		for x: float in [-b.x + 0.08, b.x - 0.08]:
			for z: float in [-b.z + 0.08, b.z - 0.08]:
				_box(s, Vector3(0.08, Structures.BENCH.y - 0.08, 0.08), Vector3(x, (Structures.BENCH.y - 0.08) / 2.0, z), _c(WOOD_DARK))
		_box(s, Vector3(Structures.BENCH.x, 0.08, Structures.BENCH.z), Vector3(0, Structures.BENCH.y - 0.04, 0), _c(WOOD))
		_box(s, Vector3(Structures.BENCH.x - 0.2, 0.05, Structures.BENCH.z - 0.15), Vector3(0, 0.25, 0), _c(WOOD_DARK)) # shelf
		_box(s, Vector3(0.2, 0.55, 0.2), Vector3(-0.55, Structures.BENCH.y + 0.27, -0.15), _c(STEEL)) # reloading press
		_box(s, Vector3(0.08, 0.3, 0.45), Vector3(-0.55, Structures.BENCH.y + 0.5, 0.05), _c(STEEL)) # its lever
		_box(s, Vector3(0.25, 0.15, 0.18), Vector3(0.6, Structures.BENCH.y + 0.08, 0.1), _c(STEEL)) # vise
		_box(s, Vector3(0.3, 0.1, 0.2), Vector3(0.1, Structures.BENCH.y + 0.05, -0.1), _c(Structures.BENCHES[kind]), "", 0.3) # rounds
		_save(PROPS + kind + ".tscn")

	var bs := Fortifications.BARRICADE_SIZE
	s = _start_prop("Barricade")
	for x: float in [-bs.x / 2.0 + 0.1, bs.x / 2.0 - 0.1]: # posts
		_box(s, Vector3(0.14, bs.y, 0.14), Vector3(x, bs.y / 2.0, 0.0), _c(Fortifications.WOOD_DARK))
	for i in 4: # rails, a little crooked
		_box(s, Vector3(bs.x, 0.22, 0.06), Vector3(0.0, 0.3 + i * 0.36, 0.05), _c(Fortifications.WOOD), "", 0.0, [0.03, -0.05, 0.02, -0.03][i])
	_save(PROPS + "barricade.tscn")

	for count in [3, 4]: # boards nailed over a window (3) or a door (4); stretched to the opening
		s = _start_prop("WindowPlanks" if count == 3 else "DoorPlanks")
		var height := 1.2 if count == 3 else 2.2
		for i in count:
			var yy: float = -height / 2.0 + height * (i + 0.5) / count
			_box(s, Vector3(0.05, 0.22, 1.3), Vector3(0.0, yy, 0.0), _c(Fortifications.WOOD), "", 0.0, [0.04, -0.06, 0.03, -0.04][i])
			for z: float in [-0.55, 0.55]:
				_box(s, Vector3(0.03, 0.03, 0.03), Vector3(-0.03, yy, z), _c(IRON)) # nails
		_save(PROPS + ("window_planks.tscn" if count == 3 else "door_planks.tscn"))


# --- A camp's props (world/camp_site.gd puts them where they go) -----------------

func _camp() -> void:
	var s: Node3D
	s = _start_prop("Campfire") # a ring of stones, crossed logs, a flame and its glow, a pot on a tripod
	for i in 9:
		var a := TAU * i / 9.0
		_box(s, Vector3(0.22, 0.14, 0.18), Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), _c(STONE), "", -a)
	for k in 3:
		_box(s, Vector3(0.9, 0.1, 0.1), Vector3(0, 0.1, 0), _c(LOG), "", k * PI / 3.0)
	var flame := _box(s, Vector3(0.3, 0.35, 0.3), Vector3(0, 0.3, 0), null, "Flame")
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = FIRE
	flame_mat.emission_enabled = true
	flame_mat.emission = FIRE
	flame_mat.emission_energy_multiplier = 2.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = Vector3(0, 0.6, 0)
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 60.0
	_add(s, glow)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := _box(s, Vector3(0.04, 1.2, 0.04), Vector3(cos(a) * 0.45, 0.55, sin(a) * 0.45), _c(IRON))
		leg.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35) # leaning in to meet over the fire
	_box(s, Vector3(0.36, 0.28, 0.36), Vector3(0, 0.75, 0), _c(IRON)) # the pot
	_save(PROPS + "campfire.tscn")

	s = _start_prop("Tent") # a pup tent: two sloping sides meeting at a ridge, open at the front
	var depth := 2.1
	var half_width := 0.85
	var height := 1.15
	var slope := atan2(height, half_width)
	var side := sqrt(height * height + half_width * half_width)
	for sgn: float in [-1.0, 1.0]:
		_box(s, Vector3(side, 0.03, depth), Vector3(sgn * half_width / 2.0, height / 2.0, 0), _c(CANVAS if sgn < 0.0 else CANVAS_DARK), "", 0.0, 0.0, -sgn * slope)
	_box(s, Vector3(half_width * 2.0, 0.02, depth), Vector3(0, 0.01, 0), _c(CANVAS_DARK)) # the groundsheet
	_box(s, Vector3(0.04, height + 0.1, 0.04), Vector3(0, (height + 0.1) / 2.0, depth / 2.0), _c(WOOD_DARK)) # poles
	_box(s, Vector3(0.04, height + 0.1, 0.04), Vector3(0, (height + 0.1) / 2.0, -depth / 2.0), _c(WOOD_DARK))
	_save(PROPS + "tent.tscn")

	s = _start_prop("CampTable") # the table and chair, with the radio on it (the logbook goes on it too)
	_box(s, Vector3(1.4, 0.06, 0.8), Vector3(0, 0.74, 0), _c(TABLE_WOOD))
	for x: float in [-0.62, 0.62]:
		for z: float in [-0.32, 0.32]:
			_box(s, Vector3(0.06, 0.72, 0.06), Vector3(x, 0.36, z), _c(TABLE_WOOD))
	var chair := Vector3(0.2, 0, 0.75)
	_box(s, Vector3(0.45, 0.05, 0.45), chair + Vector3(0, 0.45, 0), _c(TABLE_WOOD))
	_box(s, Vector3(0.45, 0.5, 0.05), chair + Vector3(0, 0.72, 0.2), _c(TABLE_WOOD))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			_box(s, Vector3(0.04, 0.45, 0.04), chair + Vector3(x, 0.22, z), _c(TABLE_WOOD))
	_box(s, Vector3(0.34, 0.2, 0.18), Vector3(-0.38, 0.87, -0.1), _c(RADIO))
	_box(s, Vector3(0.06, 0.06, 0.02), Vector3(-0.3, 0.88, -0.005), _c(IRON)) # its dial
	_box(s, Vector3(0.015, 0.5, 0.015), Vector3(-0.5, 1.2, -0.12), _c(IRON)) # its aerial
	_save(PROPS + "camp_table.tscn")

	s = _start_prop("Logbook") # a closed book on a table (world/save_point.gd)
	_box(s, Vector3(0.28, 0.05, 0.38), Vector3(0, 0.025, 0), _c(Color(0.15, 0.3, 0.2)))
	_box(s, Vector3(0.26, 0.012, 0.36), Vector3(0.008, 0.056, 0), _c(Color(0.9, 0.87, 0.78)))
	_box(s, Vector3(0.02, 0.3, 0.005), Vector3(0.08, 0.05, 0.19), _c(Color(0.6, 0.1, 0.1)), "", 0.0, 0.0, 1.4) # bookmark
	_save(PROPS + "logbook.tscn")

	s = _start_prop("BulletinBoard") # a cork board on two posts (world/bulletin_board.gd writes on it)
	var board := Vector2(1.3, 0.95)
	for x: float in [-board.x / 2.0 + 0.05, board.x / 2.0 - 0.05]:
		_box(s, Vector3(0.08, 1.9, 0.08), Vector3(x, 0.95, -0.05), _c(Color(0.42, 0.31, 0.2)))
	_box(s, Vector3(board.x, board.y, 0.05), Vector3(0, 1.3, 0.0), _c(Color(0.62, 0.48, 0.32)))
	_box(s, Vector3(board.x + 0.1, 0.06, 0.08), Vector3(0, 1.3 + board.y / 2.0 + 0.03, 0.0), _c(Color(0.42, 0.31, 0.2))) # frame top
	_box(s, Vector3(board.x + 0.1, 0.06, 0.08), Vector3(0, 1.3 - board.y / 2.0 - 0.03, 0.0), _c(Color(0.42, 0.31, 0.2)))
	_save(PROPS + "bulletin_board.tscn")


# --- Doors and windows (stretched to fit each opening) ---------------------------

func _openings() -> void:
	var s := _start_prop("Door") # 0.9 m wide along +Z, 2.1 m tall, centered: a panel door with a knob
	_box(s, Vector3(0.06, 2.1, 0.9), Vector3.ZERO, _c(Color(0.36, 0.24, 0.14)), "Paint")
	for side: float in [-1.0, 1.0]: # raised panels and a knob on both faces
		for yy: float in [0.45, -0.5]:
			_box(s, Vector3(0.02, 0.75, 0.6), Vector3(side * 0.035, yy, 0), _c(Color(0.32, 0.21, 0.12)), "Paint%d" % (2 if side < 0 else 3) + ("a" if yy > 0 else "b"))
		_cyl(s, 0.035, 0.05, Vector3(side * 0.06, -0.05, 0.36), _c(Color(0.75, 0.65, 0.3)), Vector3(0, 0, PI / 2.0))
	_save(PROPS + "door.tscn")

	s = _start_prop("Window") # 1 m wide along +Z, 1.2 m tall, centered: a frame, a cross bar and the glass
	var glass := StandardMaterial3D.new()
	glass.albedo_color = KitMesh.GLASS
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.metallic_specular = 0.8
	var g := _box(s, Vector3(0.02, 1.16, 0.96), Vector3.ZERO, glass, "Glass")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # let sunlight in
	var frame := _c(Color(0.85, 0.83, 0.78))
	for yy: float in [-0.58, 0.58]:
		_box(s, Vector3(0.06, 0.05, 1.0), Vector3(0, yy, 0), frame)
	for zz: float in [-0.48, 0.48]:
		_box(s, Vector3(0.06, 1.2, 0.05), Vector3(0, 0, zz), frame)
	_box(s, Vector3(0.05, 1.16, 0.03), Vector3.ZERO, frame) # the cross bar
	_box(s, Vector3(0.05, 0.03, 0.96), Vector3.ZERO, frame)
	_save(PROPS + "window.tscn")

	s = _start_prop("GarageDoor") # 2.4 m wide along +Z, 2.1 m tall, centered: ribbed steel sections and a handle
	var steel := _c(Color(0.82, 0.81, 0.78))
	_box(s, Vector3(0.05, 2.1, 2.4), Vector3.ZERO, steel, "Paint")
	for i in 4: # the sections' seams, both faces
		for side: float in [-1.0, 1.0]:
			_box(s, Vector3(0.01, 0.04, 2.4), Vector3(side * 0.03, -1.05 + 0.525 * (i + 1) - 0.02, 0), _c(Color(0.6, 0.6, 0.58)))
	_box(s, Vector3(0.04, 0.05, 0.3), Vector3(-0.045, -0.75, 0), _c(IRON))
	_save(PROPS + "garage_door.tscn")

	s = _start_prop("CellarDoor") # a storm-cellar leaf: 1 m across along +Z, 2 m up its slope (Y), its top face -X
	_box(s, Vector3(0.05, 2.0, 1.0), Vector3.ZERO, _c(Color(0.3, 0.33, 0.3)), "Paint")
	for yy: float in [-0.7, 0.0, 0.7]: # stiffening ribs on top
		_box(s, Vector3(0.03, 0.06, 0.96), Vector3(-0.04, yy, 0), _c(Color(0.25, 0.27, 0.25)))
	_cyl(s, 0.02, 0.18, Vector3(-0.08, -0.85, 0.3), _c(IRON), Vector3(0, 0, PI / 2.0)) # the handle
	_save(PROPS + "cellar_door.tscn")

	s = _start_prop("ScreenDoor") # 0.9 m wide along +Z, 2.1 m tall, centered: a wood frame round a screen
	var wood := _c(Color(0.55, 0.42, 0.28))
	var screen := _mat("screen")
	_box(s, Vector3(0.01, 2.0, 0.8), Vector3.ZERO, screen, "Screen")
	for yy: float in [-1.02, 0.0, 1.02]:
		_box(s, Vector3(0.05, 0.08, 0.9), Vector3(0, yy, 0), wood, "Paint" if yy == 0.0 else "")
	for zz: float in [-0.42, 0.42]:
		_box(s, Vector3(0.05, 2.1, 0.07), Vector3(0, 0, zz), wood)
	_save(PROPS + "screen_door.tscn")


# --- Building blocks -------------------------------------------------------------

## A furniture stand-in: just the meshes, under a root named name.
func _start(name: String) -> Node3D:
	_colors.clear()
	_root = Node3D.new()
	_root.name = name
	return _root


## A KitProp scene; the stand-in goes under its StandIn child (returned).
func _start_prop(name: String) -> Node3D:
	_colors.clear()
	_root = KitPropScript.new()
	_root.name = name
	var stand_in := Node3D.new()
	stand_in.name = "StandIn"
	_add(_root, stand_in)
	return stand_in


func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = _root


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, name := "", yaw := 0.0,
		tilt := 0.0, roll := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	if name != "":
		inst.name = name
	inst.mesh = mesh
	inst.position = pos
	inst.rotation = Vector3(tilt, yaw, roll)
	_add(parent, inst)
	return inst


func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation = rot
	_add(parent, inst)
	return inst


## A plain material in this color (one per color in a scene).
func _c(color: Color) -> StandardMaterial3D:
	if not _colors.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_colors[color] = mat
	return _colors[color]


## One of the kit's materials (world/kit/materials/).
func _mat(name: String) -> Material:
	return load(M + name + ".tres")


func _save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if _root is KitProp and ResourceLoader.exists(path): # keep the Models set on it
		var old := (load(path) as PackedScene).instantiate()
		if old is KitProp:
			(_root as KitProp).models = (old as KitProp).models
		old.free()
	var scene := PackedScene.new()
	var err := scene.pack(_root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
	else:
		_made += 1
	_root.free()
