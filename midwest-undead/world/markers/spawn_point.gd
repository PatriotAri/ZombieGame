@tool
class_name KitSpawnPoint
extends Marker3D
## Where someone is when a new game starts, and which way they face (the
## marker's forward, -Z). main.gd reads every SpawnPoint in the map scene.
## A few roles also use the node the marker sits under:
##   guard     - under its guard tower: the guard's aim ignores the tower's own parts.
##   bandit    - under their camp: they stay near the camp node's position.
##   survivor  - inside the house (a Building) they're holed up in.

@export_enum("player", "guard", "bandit", "corpse", "survivor", "survivor_home") var role := "player":
	set(value):
		role = value
		_update_label()
## survivor and survivor_home: whose spot it is (a survivor's name, from their file
## in characters/npcs/survivors/).
@export var person := "":
	set(value):
		person = value
		_update_label()
## corpse: the color of their clothes.
@export var outfit_color := Color(0.4, 0.4, 0.4)
## guard: the stretch of road they shoot zombies on (world positions; the gate's two ends).
@export var watch_from := Vector3.ZERO
@export var watch_to := Vector3.ZERO

const LABEL_COLOR := Color(0.5, 0.9, 1.0)

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
	return role.replace("_", " ") + (": " + person if person != "" else "")
