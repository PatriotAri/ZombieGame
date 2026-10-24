extends "res://world/props/prop_builder.gd"
## Stand-ins for the things you build, at structures.gd's sizes (make_props.gd).


func make() -> void:
	_built()


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
