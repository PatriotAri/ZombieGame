@tool
class_name KitPersonMarker
extends Marker3D
## Where someone (a person file, characters/npcs/people/) stands when a new
## game starts, facing the marker's way (-Z). Add one with Map Tools (Quests >
## New person) or drop in person_marker.tscn. main.gd puts them there.
## With Start Here off they're not there at the start: a quest brings them in
## (Spawn Person, at a quest marker), and this just shows on the map where
## that will be.

@export var person: PersonData:
	set(value):
		person = value
		_update_label()
## There when a new game starts. Off: a quest brings them in later.
@export var start_here := true:
	set(value):
		start_here = value
		_update_label()
## Held captive here: tied to a post at their back, until you untie them (they
## say their person file's Untie Talk, and quests hear person_freed).
@export var captive := false:
	set(value):
		captive = value
		_update_label()

const LABEL_COLOR := Color(0.55, 0.85, 1.0)

var _label: Label3D


func _ready() -> void:
	_update_label()


func _update_label() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.004
		_label.font_size = 48
		_label.outline_size = 12
		_label.visibility_range_end = 60.0
		_label.position.y = 2.0
		add_child(_label, false, Node.INTERNAL_MODE_BACK)
	_label.modulate = LABEL_COLOR
	var who := "no person file"
	if person:
		who = person.display_name if person.display_name != "" else person.id
	_label.text = who + ("" if start_here else " (later)") + (" (captive)" if captive else "")
