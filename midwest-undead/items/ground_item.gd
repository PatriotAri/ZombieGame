extends Area3D
## An item lying on the ground. Look at it and press E to pick it up.
## It's an Area3D rather than a StaticBody3D, so you walk through it and it
## doesn't change zombie navigation. The player's interaction ray is told to
## detect areas on the items layer.

const GameData := preload("res://core/game_data.gd")

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
	if get_child_count() == 0:
		_build(item)
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


func get_label() -> String:
	if amount > 1:
		return "%s (%d)" % [GameData.item_name(item_id), amount]
	return GameData.item_name(item_id)


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = pos
	add_child(inst)
