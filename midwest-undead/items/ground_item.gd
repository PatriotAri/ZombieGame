extends Area3D
## An item lying on the ground. Look at it and press E to pick it up.
## It's an Area3D rather than a StaticBody3D, so you walk through it and it
## doesn't change zombie navigation. The player's interaction ray is told to
## detect areas on the items layer.

const GameData := preload("res://core/game_data.gd")

var item_id := ""
var amount := 1


func setup(id: String, count := 1) -> void:
	item_id = id
	amount = count
	add_to_group("ground_items")
	collision_layer = GameData.LAYER_ITEMS
	collision_mask = 0

	var def: Dictionary = GameData.ITEMS[id]
	var size: Vector3 = def["size"]
	_add_box(size, Vector3(0, size.y / 2.0, 0), def["color"])
	if id == "health_pack":
		var red := Color(0.8, 0.1, 0.1)
		_add_box(Vector3(size.x * 0.6, 0.01, 0.06), Vector3(0, size.y + 0.005, 0), red)
		_add_box(Vector3(0.06, 0.01, size.z * 0.6), Vector3(0, size.y + 0.005, 0), red)

	# The pickup zone is bigger than the item so small things are easy to aim at.
	var zone := Vector3(maxf(size.x, 0.5), maxf(size.y, 0.3), maxf(size.z, 0.5))
	var shape := BoxShape3D.new()
	shape.size = zone
	var col := CollisionShape3D.new()
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
