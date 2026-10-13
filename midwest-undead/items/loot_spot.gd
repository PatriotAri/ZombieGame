extends StaticBody3D
## A container you can open: a dumpster, a car, a pile of boxes.
## main.gd fills its inventory; the inventory screen moves items in and out.

const Inventory := preload("res://items/inventory.gd")

var label := "Boxes"
var inventory := Inventory.new()
var opened := false
var salvaged := false # stripped for materials with the crowbar (world/salvage.gd)
var _material: StandardMaterial3D


func setup(size: Vector3, color: Color, spot_label: String) -> void:
	label = spot_label
	_material = StandardMaterial3D.new()
	_material.albedo_color = color

	var box := BoxMesh.new()
	box.size = size
	box.material = _material
	var inst := MeshInstance3D.new()
	inst.mesh = box
	add_child(inst)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)


## Returns true the first time, when you're rummaging through it (that's noisy).
## Opened containers turn darker so you can tell them apart.
func open() -> bool:
	if opened:
		return false
	opened = true
	_material.albedo_color = _material.albedo_color.darkened(0.45)
	return true
