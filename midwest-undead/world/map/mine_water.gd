@tool
class_name MineWater
extends Node3D
## The water of a flooded part of a mine (MineFlood): answers where its surface
## is, for the player, zombies and anything else (world/water.gd), and shows a
## sheet of water where it's under the roof (or, flooded to the roof, a murky
## face of water where it starts). KitMine builds one per flood.

const Pond := preload("res://world/map/pond.gd")
const GameData := preload("res://core/game_data.gd")

var size := Vector2.ONE # meters across (x, z), centered on this node
var depth := 1.0 # surface height over this node
var room := 3.0 # how high the space it's in goes: no sheet of water if it's full to there


static var _face: StandardMaterial3D


func _ready() -> void:
	add_to_group("water")
	if depth < room - 0.05:
		var plane := PlaneMesh.new()
		plane.size = size
		_sheet(plane, Pond._water_material(), Transform3D(Basis.IDENTITY, Vector3(0, depth, 0)))
		return
	# Up to the roof: no surface to see, so a murky face of water at its edges
	# (the rock hides the parts that aren't in a tunnel's way).
	if _face == null:
		_face = StandardMaterial3D.new()
		_face.albedo_color = Color(0.08, 0.22, 0.24, 0.75)
		_face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_face.cull_mode = BaseMaterial3D.CULL_DISABLED
		_face.roughness = 0.1
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var quad := QuadMesh.new()
		quad.size = Vector2(size.y if side.x != 0.0 else size.x, room)
		var basis := Basis(Vector3.UP, atan2(side.x, side.y)) # its face out that way
		var out := Vector3(side.x * size.x / 2.0, room / 2.0, side.y * size.y / 2.0)
		_sheet(quad, _face, Transform3D(basis, out))


func _sheet(mesh: Mesh, mat: Material, at: Transform3D) -> void:
	var sheet := MeshInstance3D.new()
	sheet.mesh = mesh
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.layers = GameData.RENDER_UNDERGROUND
	sheet.transform = at
	add_child(sheet, false, Node.INTERNAL_MODE_BACK)


## The water surface over pos, or NAN outside it (world/water.gd). Only on its
## own level: from a little under its floor up to its surface (or its roof).
func surface_at(pos: Vector3) -> float:
	var local := to_local(pos)
	if absf(local.x) > size.x / 2.0 or absf(local.z) > size.y / 2.0:
		return NAN
	if local.y < -1.0 or local.y > maxf(depth, room) + 0.5:
		return NAN
	return global_position.y + depth


func water_rect() -> Rect2:
	var r := maxf(size.x, size.y) * 0.75 # covers it at any turn
	return Rect2(global_position.x - r, global_position.z - r, r * 2.0, r * 2.0)
