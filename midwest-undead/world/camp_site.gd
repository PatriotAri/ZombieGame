extends RefCounted
## What a base camp you build looks like (world/structures.gd builds the camp
## kit with it): a campfire with a cooking pot hung over it, two small tents
## behind it, a table and chair with a radio and the camp's logbook (save /
## load) on it, the bulletin board (who lives here) and the supply crate (each
## morning's food and ammo). The camp's +z side faces whoever built it.
## Each part's look is a prop scene in world/props/ (the crate is the kit's
## supply crate): set Models on one to swap in a model (HOW_TO_MODEL.md,
## "Props"). Never instanced: build() adds it all to the camp's StructurePiece.

const SavePoint := preload("res://world/save_point.gd")
const BulletinBoard := preload("res://world/bulletin_board.gd")
const CAMPFIRE := preload("res://world/props/campfire.tscn")
const TENT := preload("res://world/props/tent.tscn")
const TABLE := preload("res://world/props/camp_table.tscn")
const SUPPLY_CRATE := preload("res://world/kit/furniture/supply_crate.tscn")

## The ground it takes up (meters; x across, z front to back): build() fits in it.
const SIZE := Vector3(7.4, 2.4, 6.4)
const TABLE_AT := Vector3(0.4, 0, 2.2)
const TENTS: Array[Vector3] = [Vector3(-2.4, 0, -1.6), Vector3(2.4, 0, -1.6)]
## Where it's solid, for props without collision shapes of their own: [size, middle].
const TENT_BOX := [Vector3(1.7, 1.15, 2.1), Vector3(0, 0.575, 0)]
const TABLE_BOX := [Vector3(1.4, 0.78, 0.8), Vector3(0, 0.39, 0)]


## Adds the camp: the props' looks under holder, their collision and the parts
## (named Logbook, Board and Crate: world/camps.gd finds them) on body.
static func build(holder: Node3D, body: CollisionObject3D) -> void:
	_add(holder, CAMPFIRE, Vector3.ZERO)
	for at in TENTS:
		if not _add(holder, TENT, at).take_shapes(body):
			_shape(body, TENT_BOX[0], at + TENT_BOX[1])
	if not _add(holder, TABLE, TABLE_AT).take_shapes(body):
		_shape(body, TABLE_BOX[0], TABLE_AT + TABLE_BOX[1])
	var logbook := SavePoint.new()
	logbook.name = "Logbook"
	logbook.position = TABLE_AT + Vector3(0.25, 0.77, 0)
	body.add_child(logbook)
	var board := BulletinBoard.new()
	board.name = "Board"
	board.position = Vector3(2.6, 0, 2.3)
	body.add_child(board)
	var crate := make_crate()
	crate.name = "Crate"
	crate.position = Vector3(-2.4, 0, 2.3)
	body.add_child(crate)


## The see-through preview while placing a camp kit: just its fire, tents and table.
static func preview(holder: Node3D) -> void:
	_add(holder, CAMPFIRE, Vector3.ZERO)
	for at in TENTS:
		_add(holder, TENT, at)
	_add(holder, TABLE, TABLE_AT)


## A camp's supply crate (also the police station's: world/camps.gd).
static func make_crate() -> KitContainer:
	var crate: KitContainer = SUPPLY_CRATE.instantiate()
	crate.label = "Supply crate"
	crate.fixed_items = {} # filled each morning (world/camps.gd)
	crate.loot_table = "none"
	crate.size = Vector3(1.0, 0.7, 0.7)
	return crate


static func _add(holder: Node3D, scene: PackedScene, at: Vector3) -> KitProp:
	var prop := KitProp.make(scene)
	prop.position = at
	holder.add_child(prop)
	return prop


static func _shape(body: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
