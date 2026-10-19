extends RefCounted
## The building blocks the stand-ins are made of (world/props/make_props.gd
## runs it; each kind of prop has its own script extending this one): a
## scene's root, boxes and cylinders, plain colors and the kit's materials,
## and saving the scene.

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
