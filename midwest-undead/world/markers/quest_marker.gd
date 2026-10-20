@tool
class_name KitQuestMarker
extends Marker3D
## A spot on the map that quests point at by its Marker Id (QUESTS.md). Add
## one with Map Tools (Quests > New quest marker) or drop in quest_marker.tscn.
##   point  - just a spot: where a waypoint points, where someone is sent or
##            turns up.
##   area   - a round area, Radius across and Height above and below the
##            marker: coming into it and leaving it are events (area_entered,
##            area_left: core/game_events.gd).
##   usable - something to use: a box Use Size around the marker that you aim
##            at and press interact on. It offers itself only while a quest
##            wants it used; using it is the object_used event.
## world/quest_world.gd finds every one in the map scene.

const GameData := preload("res://core/game_data.gd")
const GameEvents := preload("res://core/game_events.gd")

## What quests call it. Unique on the map, no spaces (the_radio, barn_loft).
## Saves go by it, so don't change it once quests use it.
@export var marker_id := "":
	set(value):
		marker_id = value
		_update_editor_look()
@export_enum("point", "area", "usable") var kind := "point":
	set(value):
		kind = value
		_update_editor_look()
## area: how far from the marker counts as in it (meters, across the ground).
@export var radius := 10.0:
	set(value):
		radius = value
		_update_editor_look()
## area: how far above and below the marker counts (a mine level is 4 m).
@export var height := 4.0
## usable: what the prompt says ("E: search the desk").
@export var prompt := "use"
## usable: the box you can aim at, centered on the marker (meters).
@export var use_size := Vector3(0.6, 0.6, 0.6)
## The name the map screen writes by it when a quest points here. Empty: the
## quest's own label.
@export var map_label := ""

const LABEL_COLOR := Color(0.75, 1.0, 0.55)
const RING_SEGMENTS := 48

## usable: whether a quest wants it used right now (quests set it).
var usable := false

var _label: Label3D
var _ring: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_look()
		return
	if kind == "usable":
		var area := Area3D.new()
		area.name = "UseBox"
		area.collision_layer = GameData.LAYER_ITEMS # what the player's look ray hits
		area.collision_mask = 0
		area.monitoring = false # nothing to notice: it's only there to be aimed at (rays still find it)
		area.monitorable = false
		area.set_meta("part_of_parent", true) # looking at it is looking at the marker
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = use_size
		shape.shape = box
		area.add_child(shape)
		add_child(area)


## Whether pos is in the area (area markers; any other kind: within a meter).
func contains(pos: Vector3) -> bool:
	var reach := radius if kind == "area" else 1.0
	var up := height if kind == "area" else 2.0
	var d := pos - global_position
	return Vector2(d.x, d.z).length_squared() <= reach * reach and absf(d.y) <= up


func interact_prompt() -> String:
	return prompt if kind == "usable" and usable else ""


## The player pressed interact on it (main.gd's _on_object_interacted).
func interact(_player: Node) -> void:
	if kind == "usable" and usable:
		GameEvents.send(&"object_used", {"marker": marker_id})


# --- In the editor -----------------------------------------------------------------

## A floating id so you can tell markers apart, and a ring round an area.
func _update_editor_look() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true # seen through walls (markers inside buildings)
		_label.pixel_size = 0.004
		_label.font_size = 48
		_label.outline_size = 12
		_label.visibility_range_end = 60.0
		_label.position.y = 1.0
		add_child(_label, false, Node.INTERNAL_MODE_BACK)
	_label.modulate = LABEL_COLOR
	_label.text = "%s (%s)" % [marker_id if marker_id != "" else "no id", kind]
	if _ring == null:
		_ring = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = LABEL_COLOR
		mat.no_depth_test = true
		_ring.material_override = mat
		add_child(_ring, false, Node.INTERNAL_MODE_BACK)
	_ring.visible = kind == "area"
	if kind == "area":
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in RING_SEGMENTS + 1:
			var a := TAU * i / RING_SEGMENTS
			mesh.surface_add_vertex(Vector3(cos(a) * radius, 0.1, sin(a) * radius))
		mesh.surface_end()
		_ring.mesh = mesh
