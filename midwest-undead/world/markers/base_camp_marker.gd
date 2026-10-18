@tool
class_name KitBaseCamp
extends Marker3D
## A base camp that's there from the start: the police station. Put it in the
## station; drag its three child markers to where its logbook (save / load),
## bulletin board (who lives here) and supply crate (each morning's food and
## ammo) should be. world/camps.gd makes the camp from it. It's permanent: it
## can't be taken down.
## (The camps you build yourself come from the woodworker's camp kit instead.)

@export var camp_name := "Police Station":
	set(value):
		camp_name = value
		_update_label()

const LABEL_COLOR := Color(1.0, 0.6, 0.3)
## Its child markers, and where a new one puts them (meters from the marker).
const PARTS := {"Logbook": Vector3(1.5, 0.9, 0.0), "Board": Vector3(-1.5, 0.0, 0.0), "Crate": Vector3(0.0, 0.0, 1.5)}

var _label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		# A new one (from Map Tools or dropped in): its three spots.
		for part: String in PARTS:
			if get_node_or_null(part) == null and is_inside_tree() and get_tree().edited_scene_root:
				var spot := Marker3D.new()
				spot.name = part
				spot.position = PARTS[part]
				add_child(spot)
				spot.owner = get_tree().edited_scene_root
	_update_label()


## Where a part goes (Logbook, Board, Crate), in the world: its child marker, or
## the default spot.
func part_transform(part: String) -> Transform3D:
	var spot := get_node_or_null(part) as Node3D
	if spot:
		return spot.global_transform
	return global_transform * Transform3D(Basis.IDENTITY, PARTS[part])


func _update_label() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.005
		_label.font_size = 56
		_label.outline_size = 12
		_label.position.y = 2.0
		add_child(_label, false, Node.INTERNAL_MODE_BACK)
	_label.modulate = LABEL_COLOR
	_label.text = "Base camp: " + camp_name
