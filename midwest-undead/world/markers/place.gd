@tool
class_name KitPlace
extends Marker3D
## A named place for the map screen (ui/map_menu.gd).
##   discoverable - found by coming within `radius` of the marker
##                  (world/discoveries.gd); the map names it only after that.
##   street       - a street name, always shown.
## main.gd reads every Place in the map scene. The quest and the wagon trader
## also go by the "Safe House" and "Police Station" places.

@export var place_name := "":
	set(value):
		place_name = value
		_update_label()
@export_enum("discoverable", "street") var kind := "discoverable":
	set(value):
		kind = value
		_update_label()
@export var radius := 25.0
## Where the map writes the name, relative to the marker (meters; x east, z south).
@export var label_offset := Vector2.ZERO

const LABEL_COLOR := Color(1.0, 0.9, 0.5)

var _label: Label3D


## In the editor, a floating name so you can tell markers apart.
func _ready() -> void:
	_update_label()


func _update_label() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true # seen through walls (markers inside buildings)
		_label.pixel_size = 0.004
		_label.font_size = 48
		_label.outline_size = 12
		_label.visibility_range_end = 35.0 # far ones would only clutter the view
		_label.position.y = 1.0
		add_child(_label, false, Node.INTERNAL_MODE_BACK)
	_label.modulate = LABEL_COLOR
	_label.text = _label_text()


func _label_text() -> String:
	return place_name + (" (street)" if kind == "street" else "")
