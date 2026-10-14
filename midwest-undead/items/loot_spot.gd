@tool
class_name KitContainer
extends StaticBody3D
## A container you can open: a dumpster, a car, a pile of boxes, a dresser.
## What's in it when a new game starts: fixed_items, always, plus a roll on its
## loot table (a file in items/loot/; see world/loot.gd). The inventory screen moves items
## in and out.
## It's a box of `size` in `material`, made fresh from those settings (in the
## editor too). Ready-made ones are in world/kit/furniture/.

const Inventory := preload("res://items/inventory.gd")
const KitMesh := preload("res://world/kit/kit_mesh.gd")
const ViewDistance := preload("res://core/view_distance.gd")
const DEFAULT_MATERIAL := preload("res://world/kit/materials/wood_planks.tres")

## What the prompt calls it ("search the Dresser"). Salvage (world/salvage.gd) goes by it too.
@export var label := "Boxes"
## Always in it at the start: item id -> how many (the files in items/data/).
@export var fixed_items: Dictionary[String, int] = {}
## Random extras rolled at the start of every new game: a table in items/loot/
## (the list shows them all). "none": just the fixed items.
@export var loot_table := "standard"
@export_group("Look")
## In meters; the box is centered on the node (see Sits On Floor).
@export var size := Vector3(1.0, 1.0, 1.0):
	set(value):
		size = value
		_changed()
@export var material: Material:
	set(value):
		material = value
		_changed()
## The node is at the bottom of the box instead of its middle: put it on a floor
## and the box stands on it. (The kit's furniture scenes have this on.)
@export var sits_on_floor := false:
	set(value):
		sits_on_floor = value
		_changed()

var inventory := Inventory.new()
var opened := false
var salvaged := false # stripped for materials with the crowbar (world/salvage.gd)
var _generated: Array[Node] = []
var _dirty := true
var _queued := false


## The Loot Table setting is a list of the tables in items/loot/, so a new
## table file shows up in it. (loaded, not preloaded: world/loot.gd preloads this.)
func _validate_property(property: Dictionary) -> void:
	if property["name"] == "loot_table":
		var names: PackedStringArray = load("res://world/loot.gd").table_names()
		names.insert(0, "none")
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = ",".join(names)


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _dirty:
		_rebuild()


## Returns true the first time, when you're rummaging through it (that's noisy).
## Opened containers turn darker so you can tell them apart.
func open() -> bool:
	if opened:
		return false
	opened = true
	darken(0.45)
	return true


## Darker from now on (searched, or stripped: world/salvage.gd).
func darken(amount: float) -> void:
	for node in _generated:
		if node is MeshInstance3D:
			KitMesh.darken(node, amount)


func _changed() -> void:
	_dirty = true
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_queued = false
	_dirty = false
	for node in _generated:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_generated.clear()
	var km := KitMesh.new()
	var at := Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0 if sits_on_floor else 0.0, 0))
	km.box(size, at, KitMesh.all(material if material else DEFAULT_MATERIAL))
	_generated = km.add_to(self)
	for node in _generated:
		if node is GeometryInstance3D:
			ViewDistance.limit_by_size(node, size)
