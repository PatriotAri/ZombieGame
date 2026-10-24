@tool
class_name KitZone
extends Path3D
## A zone: a named area of the map (a valley, a town, a farm), drawn as an
## outline. Click its corners with Map Tools' Draw points (it closes itself);
## drag points to reshape it. Zones are just names: walking into one shows its
## name, and the map screen can outline them (world/zones.gd reads them all).

@export var zone_name := "New Zone":
	set(value):
		zone_name = value
		_update_label()

const LABEL_COLOR := Color(0.6, 1.0, 0.6)

var _label: Label3D


func _ready() -> void:
	if curve == null:
		curve = Curve3D.new()
	_update_label()


## Its corners on the ground (x, z).
func outline() -> PackedVector2Array:
	var result := PackedVector2Array()
	if curve == null:
		return result
	for i in curve.point_count:
		var p := global_transform * curve.get_point_position(i)
		result.append(Vector2(p.x, p.z))
	return result


## In the editor, its name floating over its first corner.
func _update_label() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.01
		_label.font_size = 64
		_label.outline_size = 14
		add_child(_label, false, Node.INTERNAL_MODE_BACK)
	_label.modulate = LABEL_COLOR
	_label.text = "Zone: " + zone_name
	_label.position = (curve.get_point_position(0) if curve and curve.point_count > 0 else Vector3.ZERO) + Vector3(0, 4.0, 0)
