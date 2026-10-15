@tool
class_name KitZombieSpawn
extends Marker3D
## Where zombies can be when a new game starts. Each of `count` zombies turns up
## with `chance`, somewhere in the box `spread` around the marker (half its size
## in meters, along the marker's own X and Z; zero = right on the marker).
## main.gd reads every ZombieSpawn in the map scene. Which ones turn up is
## random every new game; the extra zombies and the ones arriving over time come
## from world/zombie_population.gd instead.

@export_range(0, 50) var count := 1:
	set(value):
		count = value
		_update_label()
@export_range(0.0, 1.0) var chance := 1.0:
	set(value):
		chance = value
		_update_label()
@export var spread := Vector2.ZERO

const LABEL_COLOR := Color(1.0, 0.45, 0.4)

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
	if count == 1 and chance >= 1.0:
		return "zombie"
	return "%d zombie%s, %d%%" % [count, "s" if count != 1 else "", roundi(chance * 100.0)]
