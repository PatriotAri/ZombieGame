extends Area3D
## An item lying on the ground. Look at it and press E to pick it up.
## It's an Area3D rather than a StaticBody3D, so you walk through it and it
## doesn't change zombie navigation. The player's interaction ray is told to
## detect areas on the items layer.

const GameData := preload("res://core/game_data.gd")
const ViewDistance := preload("res://core/view_distance.gd")
const VIEW_METERS := 30.0 # past this it isn't drawn (core/view_distance.gd)

@export var item_id := ""
@export var amount := 1


## For items made in code: call before adding it to the tree.
func setup(id: String, count := 1) -> void:
	item_id = id
	amount = count


## Items in the town scene come with their meshes and pickup zone already (made
## when the town was frozen); one placed with just an item_id gets them here. An
## item with a model (items/data/) shows that instead of the saved boxes.
func _ready() -> void:
	add_to_group("ground_items")
	collision_layer = GameData.LAYER_ITEMS
	collision_mask = 0
	var item := GameData.item(item_id)
	if item == null:
		return
	_limit_view.call_deferred() # once its meshes are in
	if get_child_count() == 0:
		_build(item)
	elif not item.model:
		# The town scene saved a material with each box: share one per color.
		for child in get_children():
			var mesh := child as MeshInstance3D
			if mesh and mesh.mesh and mesh.mesh.get_surface_count() > 0:
				var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
				if mat:
					mesh.set_surface_override_material(0, _shared(mat.albedo_color))
	elif item.model:
		for child in get_children():
			if child is MeshInstance3D:
				remove_child(child)
				child.queue_free()
		add_child(item.model.instantiate())


func _build(item: ItemData) -> void:
	var size := item.size
	if item.model:
		add_child(item.model.instantiate())
	else:
		_add_box(size, Vector3(0, size.y / 2.0, 0), item.color)

	# The pickup zone is bigger than the item so small things are easy to aim at.
	var zone := Vector3(maxf(size.x, 0.5), maxf(size.y, 0.3), maxf(size.z, 0.5))
	var shape := BoxShape3D.new()
	shape.size = zone
	var col := CollisionShape3D.new()
	col.name = "PickupZone"
	col.shape = shape
	col.position.y = zone.y / 2.0
	add_child(col)


func _limit_view() -> void:
	for geom: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		ViewDistance.limit(geom, VIEW_METERS)


func get_label() -> String:
	if amount > 1:
		return "%s (%d)" % [GameData.item_name(item_id), amount]
	return GameData.item_name(item_id)


## One material per color, shared by every item of that color.
static var _colors := {}


static func _shared(color: Color) -> StandardMaterial3D:
	if not _colors.has(color):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		_colors[color] = made
	return _colors[color]


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = _shared(color)
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = pos
	add_child(inst)
