extends RefCounted
## A dense test town (never in the real map): the map scene with rows of
## furnished template buildings round the start, packed into a new scene for
## main.gd to load as usual. Built once per run.
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
static var COLS := 10
static var ROWS := 8
const SPACING := 28.0

static func make(tree: SceneTree) -> PackedScene:
	var map: Node3D = load("res://world/map/map.tscn").instantiate()
	tree.root.add_child(map) # (the terrain loads, to stand things on)
	var terrain: Node = TerrainEdit.find_terrain(map)
	var group := Node3D.new()
	group.name = "StressTown"
	map.add_child(group)
	group.owner = map
	var i := 0
	for r in ROWS:
		for c in COLS:
			var t: String = KitTemplates.NAMES[i % KitTemplates.NAMES.size()]
			var b := KitBuilding.new()
			b.name = "B%d" % i
			b.template = t
			b.template_variant = (i / KitTemplates.NAMES.size()) % 3
			b.apply_template()
			var at := Vector3(-COLS * SPACING / 2.0 + c * SPACING, 0, 20.0 + r * SPACING)
			at.y = TerrainEdit.height_at(terrain, at)
			b.position = at
			b.rotation.y = PI if r % 2 == 1 else 0.0
			group.add_child(b)
			b.furnish_rooms()
			_own(b, map)
			i += 1
	tree.root.remove_child(map)
	var scene := PackedScene.new()
	var err := scene.pack(map)
	map.free()
	assert(err == OK)
	return scene

static func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_own_deep(child, owner)

static func _own_deep(node: Node, owner: Node) -> void:
	if node.owner == null:
		node.owner = owner
	if node.scene_file_path == "": # (an instanced scene's insides are its own)
		for child in node.get_children():
			_own_deep(child, owner)
