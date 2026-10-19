@tool
extends EditorPlugin
## The Map Tools panel (along the bottom of the editor, next to Output): buttons
## to add roads, creeks, ponds, crop fields, rocks and mine entrances to the
## map (world/map/map.tscn), to draw paths and outlines by clicking on the
## ground, to Apply them to the terrain, and brushes to paint forest and
## plants. Everything can be undone (Ctrl+Z). HOW_TO_MAP.md walks through it.
##
## Drawing: select a road, creek or crop field, turn on "Draw points", and
## click on the ground in the 3D view: each click adds a point at the end.
## Right-click removes the last one. (Moving points afterwards: drag them, as
## with any path.)
## Plant brushes: pick a brush in the Plants section; the map's "Plants" node
## is selected and the 3D view paints where you click and drag.
## Buildings: select a Building and pick a tool in the Buildings section; the
## 3D view then draws its outline (corner by corner, on a 0.5 m grid, walls at
## right angles unless Shift is held), draws inner walls (click each end),
## places stairs (click where a flight starts, then which way it climbs), puts
## doors and windows in its walls, outside or inner (click on a wall), or marks
## a room to give it its own materials (click inside it), or places chimneys
## and dormers (click on the roof's level: a dormer goes on the slope nearest
## the click), porches and cellar doors (click on a wall). Right-click takes
## back the last corner, or removes the inner wall, stairs, opening, room,
## chimney, dormer, porch or cellar door under the mouse. Its walls' numbers
## show while it's selected. Apply opens the ground for its basement.
## Mines: select a KitMine and pick a tool in the Mines section; the 3D view
## then draws on the Level set there (its plan shows through the hill):
## tunnels (click each corner; Esc or Enter ends one), chambers (click two
## opposite corners), and entrances (click a tunnel's end). Right-click takes
## back the last corner, or removes the tunnel or chamber under the mouse.

const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const Road := preload("res://world/map/road.gd")
const RoadSpan := preload("res://world/map/road_span.gd")
const Creek := preload("res://world/map/creek.gd")
const CreekFalls := preload("res://world/map/creek_falls.gd")
const Pond := preload("res://world/map/pond.gd")
const CropField := preload("res://world/map/crop_field.gd")
const Rock := preload("res://world/map/rock.gd")
const MineEntrance := preload("res://world/map/mine_entrance.gd")
const PlantsLayer := preload("res://world/map/plants_layer.gd")
const Plants := preload("res://world/map/plants.gd")
const PlantPainter := preload("res://world/map/plant_painter.gd")
const Zone := preload("res://world/markers/zone.gd")
const BaseCampMarker := preload("res://world/markers/base_camp_marker.gd")
const Building := preload("res://world/building.gd")
const MINE_TOOLS := ["Off", "Draw tunnel", "Draw chamber", "Mark entrance", "Place shaft", "Place generator", "Place cave-in", "Flood", "Place locker", "Place cache", "Place zombies"]
const SHAFT_KINDS := ["Ladder", "Open", "Cage"] # (MineShaft.Kind's order)
const RAMP_CELLS := 3 # a ramp's cells for each level it climbs: about 28 degrees
const BUILDING_TOOLS := ["Off", "Draw outline", "Draw inner wall", "Place stairs", "Add door", "Add window", "Add doorway",
		"Add garage door", "Paint room", "Place chimney", "Place dormer", "Add porch", "Add cellar door"]
## Openings the tools add: [width, bottom, top]. Doors and doorways are as wide
## as zombies need to path through (Building.MIN_PASSAGE).
const OPENING_SIZES := {"door": [1.6, 0.0, 2.4], "window": [1.2, 0.9, 2.3], "doorway": [1.6, 0.0, 2.4],
		"garage door": [2.8, 0.0, 2.3]}
const GARAGE_WHITE := Color(0.85, 0.85, 0.82)
## The silos New from template adds: [radius, height, wall material, roof material].
const SILOS := {
	"Concrete": [3.0, 12.0, "concrete_block", "metal_gray"],
	"Metal": [3.5, 9.0, "metal_siding", "metal_gray"],
	"Tall": [3.0, 18.0, "concrete_slab", "metal_gray"],
}
const GRID := 0.5
const ROADS_DIR := "res://world/map/roads/"
const APPLY_MARGIN := 40.0 # meters around a path that an Apply's undo step covers
const BRUSHES := ["Off", "Forest", "Paint plant", "Place one", "Erase"]
const CREEK_KEPT := ["bed", "ground_before", "applied_points", "applied_depth"]

var _panel: Control
var _road_styles: OptionButton
var _selected_label: Label
var _help: Label
var _draw: CheckButton
var _apply: Button
var _template_list: OptionButton
var _add_span: Button
var _add_falls: Button
var _brush: OptionButton
var _plant: OptionButton
var _size: HSlider
var _density: HSlider
var _size_label: Label
var _density_label: Label
var _selected: Node # the road, creek, pond, field, rock or mine selected, or null
var _rng := RandomNumberGenerator.new()
var _painting := false
var _last_paint := Vector3.INF
var _stroke_before := {} # region location -> its plants before this stroke
var _ring: MeshInstance3D # the brush's circle on the ground
var _building_tool: OptionButton
var _building_floor: SpinBox
var _draft := PackedVector2Array() # the outline being drawn, in click order
var _stair_start := Vector2.INF # Place stairs: where the flight starts, before the second click
var _wall_start := Vector2.INF # Draw inner wall: its first end, before the second click
var _numbered: Node # the building showing its wall numbers
var _mine_tool: OptionButton
var _mine_level: SpinBox
var _mine_rails: CheckBox
var _planned: Node # the mine showing its plan
var _tunnel: MineTunnel # Draw tunnel: the one being drawn, or null
var _chamber_start := Vector3i.MAX # Draw chamber: its first corner, before the second click
var _shaft_start := Vector3i.MAX # Place shaft: its first end, before the click on the other level
var _flood_start := Vector3i.MAX # Flood: its first corner, before the second click
var _shaft_kind: OptionButton


func _enter_tree() -> void:
	_rng.randomize()
	_panel = _build_panel()
	add_control_to_bottom_panel(_panel, "Map Tools")
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
	if is_instance_valid(_ring):
		_ring.queue_free()


# --- The panel ----------------------------------------------------------------------

func _build_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "MapTools"
	scroll.custom_minimum_size = Vector2(0, 170)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	scroll.add_child(root)

	var roads := _section(root, "Roads")
	_road_styles = OptionButton.new()
	_road_styles.tooltip_text = "The kind of road to add (a file in world/map/roads/)."
	roads.add_child(_road_styles)
	_fill_road_styles()
	_button(roads, "New road", "Adds a road in front of the camera. Then turn on Draw points and click along where it goes.", _new_road)
	_add_span = _button(roads, "Add bridge span", "Adds a bridge span to the selected road. Move it to the crossing and up to the deck height.", _new_span)

	var water := _section(root, "Water")
	_button(water, "New creek", "Adds a creek in front of the camera. Draw it from upstream to downstream.", _new_creek)
	_add_falls = _button(water, "Add waterfall", "Adds a waterfall to the selected creek. Move it to where the ledge should be.", _new_falls)
	_button(water, "New pond", "Adds a pond in front of the camera. Dig the basin first, then raise or lower the pond to the water level.", _new_pond)

	var plants := _section(root, "Plants")
	_brush = OptionButton.new()
	for b: String in BRUSHES:
		_brush.add_item(b)
	_brush.tooltip_text = "Forest: a natural mix of trees and undergrowth. Paint plant: just the plant chosen below. Place one: one plant where you click. Erase: removes plants (all but crops)."
	_brush.item_selected.connect(_on_brush_chosen)
	plants.add_child(_brush)
	_plant = OptionButton.new()
	_plant.tooltip_text = "The plant for Paint plant and Place one."
	plants.add_child(_plant)
	_fill_plants()
	_size_label = Label.new()
	plants.add_child(_size_label)
	_size = _slider(plants, 2.0, 60.0, 12.0, "Brush size: meters across the circle.")
	_density_label = Label.new()
	plants.add_child(_density_label)
	_density = _slider(plants, 0.2, 8.0, 2.0, "Trees (or plants) per 100 square meters. Forest: 1 open woods, 2-3 forest, 4+ thick.")
	_update_slider_labels()
	_button(plants, "Update plant list", "After adding or changing a plant file in world/map/plants/ (or a road kind in world/map/roads/): puts it in the lists.", _update_plant_list)

	var features := _section(root, "Fields and features")
	_button(features, "New crop field", "Adds a crop field in front of the camera. Then Draw points around its edge and press Apply to plow it.", _new_field)
	_button(features, "New rock", "Adds a rock in front of the camera. Move, turn and scale it; change Shape for another one.", _new_rock)
	_button(features, "New mine entrance", "Adds a mine entrance in front of the camera. Turn it into the hillside, then Apply to open the hill.", _new_mine)

	var buildings := _section(root, "Buildings")
	_button(buildings, "New building", "Adds a 10 x 10 m building with a door and windows in front of the camera. Then reshape it with the tools below or the Inspector.", _new_building)
	_template_list = OptionButton.new()
	_template_list.add_item("New from template...")
	_template_list.set_item_disabled(0, true)
	for t: String in KitTemplates.NAMES:
		_template_list.add_separator(t)
		for v: String in KitTemplates.VARIANTS[t]:
			_template_list.add_item("%s: %s" % [t, v])
			_template_list.set_item_metadata(_template_list.item_count - 1, [t, KitTemplates.VARIANTS[t].find(v)])
	_template_list.add_separator("Silo")
	for v: String in SILOS:
		_template_list.add_item("Silo: " + v)
		_template_list.set_item_metadata(_template_list.item_count - 1, ["Silo", SILOS.keys().find(v)])
	_template_list.tooltip_text = "Adds a ready-made building in front of the camera (its Template settings in the Inspector change it later). Furnish its rooms with Furnish rooms."
	_template_list.item_selected.connect(_new_from_template)
	buildings.add_child(_template_list)
	_button(buildings, "Furnish rooms", "Puts furniture in the selected building's rooms that have a Kind (Paint room, or a template's). Again: replaces what it put in. Ctrl+Z undoes it.", _furnish_selected)
	_building_tool = OptionButton.new()
	for t: String in BUILDING_TOOLS:
		_building_tool.add_item(t)
	_building_tool.tooltip_text = "What clicking in the 3D view does to the selected building."
	_building_tool.item_selected.connect(_on_building_tool)
	buildings.add_child(_building_tool)
	var floor_row := HBoxContainer.new()
	var floor_label := Label.new()
	floor_label.text = "Floor"
	floor_row.add_child(floor_label)
	_building_floor = SpinBox.new()
	_building_floor.min_value = -1
	_building_floor.max_value = 19
	_building_floor.tooltip_text = "The floor the stairs and openings go on (0: the ground floor, -1: the basement). Stairs climb from it to the next."
	floor_row.add_child(_building_floor)
	buildings.add_child(floor_row)

	var mines := _section(root, "Mines")
	_button(mines, "New mine", "Adds a mine in front of the camera: a tunnel into the hill from an entrance. Draw more with the tools below; Apply opens the hill.", _new_kit_mine)
	_mine_tool = OptionButton.new()
	for t: String in MINE_TOOLS:
		_mine_tool.add_item(t)
	_mine_tool.tooltip_text = "What clicking in the 3D view does to the selected mine."
	_mine_tool.item_selected.connect(_on_mine_tool)
	mines.add_child(_mine_tool)
	var level_row := HBoxContainer.new()
	var level_label := Label.new()
	level_label.text = "Level"
	level_row.add_child(level_label)
	_mine_level = SpinBox.new()
	_mine_level.min_value = -10
	_mine_level.max_value = 3
	_mine_level.tooltip_text = "The level the tools draw on (0: the mine's own height, -1: 4 m under it...)."
	_mine_level.value_changed.connect(func(v: float) -> void:
		if _selected is KitMine:
			_selected.set("plan_level", int(v)))
	level_row.add_child(_mine_level)
	mines.add_child(level_row)
	_mine_rails = CheckBox.new()
	_mine_rails.text = "Rails"
	_mine_rails.tooltip_text = "New tunnels get rails (each tunnel's Rails and Carts are in the Inspector, Tunnels)."
	_mine_rails.button_pressed = true
	mines.add_child(_mine_rails)
	_shaft_kind = OptionButton.new()
	for k: String in SHAFT_KINDS:
		_shaft_kind.add_item(k + " shaft")
	_shaft_kind.tooltip_text = "What Place shaft puts in: a ladder (with landings), an open drop, or a cage elevator (it needs a generator running somewhere in the mine)."
	mines.add_child(_shaft_kind)

	var places := _section(root, "Zones and camps")
	_button(places, "New zone", "Adds a zone (a named area) in front of the camera. Name it in the Inspector, then Draw points around its edge.", _new_zone)
	_button(places, "Police station camp", "Adds the police station's base camp marker in front of the camera (one per map). Drag its Logbook, Board and Crate markers where they go.", _new_base_camp)

	var selected := _section(root, "Selected")
	_selected_label = Label.new()
	selected.add_child(_selected_label)
	_draw = CheckButton.new()
	_draw.text = "Draw points"
	_draw.tooltip_text = "Click on the ground in the 3D view to add points to the selected road, creek, crop field or zone. Right-click removes the last point."
	selected.add_child(_draw)
	_apply = _button(selected, "Apply", "Shapes, paints or opens the ground for the selected road, creek, crop field, mine, mine entrance or building with a basement. Ctrl+Z undoes it.", _apply_selected)

	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(320, 0)
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_help)
	return scroll


func _section(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	box.add_child(label)
	parent.add_child(box)
	return box


func _button(parent: Control, text: String, tip: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


func _slider(parent: Control, low: float, high: float, value: float, tip: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = 0.1
	s.value = value
	s.custom_minimum_size = Vector2(140, 0)
	s.tooltip_text = tip
	s.value_changed.connect(func(_v: float) -> void: _update_slider_labels())
	parent.add_child(s)
	return s


func _update_slider_labels() -> void:
	_size_label.text = "Size: %d m" % int(_size.value)
	_density_label.text = "Density: %.1f per 100 m²" % _density.value


func _fill_road_styles() -> void:
	_road_styles.clear()
	var files := Array(DirAccess.get_files_at(ROADS_DIR))
	files.sort()
	for file: String in files:
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var style := load(ROADS_DIR + file) as RoadStyle
		if style:
			_road_styles.add_item(style.display_name)
			_road_styles.set_item_metadata(_road_styles.item_count - 1, ROADS_DIR + file)


func _fill_plants() -> void:
	_plant.clear()
	for plant in Plants.all():
		_plant.add_item("%s (%s)" % [plant.display_name, plant.kind.to_lower()])
		_plant.set_item_metadata(_plant.item_count - 1, plant.resource_path)


func _on_selection_changed() -> void:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	_selected = null
	if nodes.size() == 1 and (nodes[0] is Road or nodes[0] is Creek or nodes[0] is Pond or nodes[0] is CropField
			or nodes[0] is Rock or nodes[0] is MineEntrance or nodes[0] is PlantsLayer or nodes[0] is Zone or nodes[0] is Building
			or nodes[0] is KitMine):
		_selected = nodes[0]
	if _planned != _selected:
		if is_instance_valid(_planned):
			_planned.set("show_plan", false)
			_planned.set("draft", [] as Array[Vector3i])
		_planned = _selected if _selected is KitMine else null
		_tunnel = null
		_chamber_start = Vector3i.MAX
		if _planned:
			_planned.set("plan_level", int(_mine_level.value))
			_planned.set("show_plan", true)
	_mine_tool.disabled = not _selected is KitMine
	if not _selected is KitMine and _mine_tool.selected != 0:
		_mine_tool.select(0)
	if _numbered != _selected:
		if is_instance_valid(_numbered):
			_numbered.set("show_numbers", false)
		_numbered = _selected if _selected is Building else null
		if _numbered:
			_numbered.set("show_numbers", true)
	_building_tool.disabled = not _selected is Building
	if not _selected is Building and _building_tool.selected != 0:
		_building_tool.select(0)
	var path := _selected is Road or _selected is Creek or _selected is CropField or _selected is Zone
	_draw.disabled = not path
	if not path:
		_draw.button_pressed = false
	_apply.disabled = not ((path and not _selected is Zone) or _selected is MineEntrance or _selected is Building
			or _selected is KitMine)
	_add_span.disabled = not _selected is Road
	_add_falls.disabled = not _selected is Creek
	if not _selected is PlantsLayer and _brush.selected != 0:
		_brush.select(0) # selected something else: the brush is off
		_show_ring(false)
	if _selected == null:
		_selected_label.text = "Nothing selected"
		_help.text = "Add things with the buttons, or select one in the Scene dock. Open world/map/map.tscn first. Sculpting and painting the ground itself: select the Terrain node and use the Terrain3D toolbar."
	elif _selected is PlantsLayer:
		_selected_label.text = "Plant brush: %s" % BRUSHES[_brush.selected]
		_help.text = "Click and drag on the ground to paint (Place one: click). Ctrl+Z undoes a stroke. Choose another brush, or Off, in the Plants section."
	elif _selected is Zone:
		_selected_label.text = "Zone: %s (%d corners)" % [(_selected as Zone).zone_name, (_selected as Path3D).curve.point_count if (_selected as Path3D).curve else 0]
		_help.text = "Name it in the Inspector (Zone Name). Turn on Draw points and click its corners on the ground, all the way round (it closes itself; right-click removes the last). Drag points to reshape it."
	elif path:
		_selected_label.text = "%s (%d points)" % [_selected.name, (_selected as Path3D).curve.point_count if (_selected as Path3D).curve else 0]
		_help.text = "Turn on Draw points and click on the ground to add points (right-click removes the last). Drag points to move them. Then press Apply. Ctrl+Z undoes an Apply."
	elif _selected is Building:
		_selected_label.text = "%s (%s)" % [_selected.name, BUILDING_TOOLS[_building_tool.selected]]
		_help.text = _building_help()
	elif _selected is KitMine:
		_selected_label.text = "%s (%s, level %d)" % [_selected.name, MINE_TOOLS[_mine_tool.selected], int(_mine_level.value)]
		_help.text = _mine_help()
	elif _selected is MineEntrance:
		_selected_label.text = "%s" % _selected.name
		_help.text = "Turn it so the tunnel runs into a steep hillside and set its floor at the ground, then press Apply to open the hill."
	elif _selected is Rock:
		_selected_label.text = "%s" % _selected.name
		_help.text = "Move, turn and scale it (flat for a ledge, tall for a crag, half in the ground for an outcrop). Change Shape in the Inspector for another one."
	else:
		_selected_label.text = "%s" % _selected.name
		_help.text = "Move the pond up or down to its water level, and set its size in the Inspector. The water shows wherever the ground is lower."


# --- Adding things ---------------------------------------------------------------------

## The edited scene's group node called group_name (made if missing), for
## keeping the Scene dock tidy.
func _group(group_name: String, script: Script = null) -> Node3D:
	var root := EditorInterface.get_edited_scene_root()
	var group := root.get_node_or_null(group_name) as Node3D
	if group == null:
		group = Node3D.new()
		if script:
			group.set_script(script)
		group.name = group_name
		root.add_child(group)
		group.owner = root
	return group


## Where the middle of the 3D view is looking, on the ground (or 30 m ahead).
func _in_view() -> Vector3:
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	var terrain := _terrain()
	if terrain:
		var hit: Vector3 = terrain.get_intersection(origin, dir, false)
		if hit.is_finite() and hit.distance_to(origin) < 2000.0:
			return hit
	return origin + dir * 30.0


func _terrain() -> Node:
	var root := EditorInterface.get_edited_scene_root()
	return TerrainEdit.find_terrain(root.get_child(0)) if root and root.get_child_count() > 0 else null


## Adds node under parent as one undo step, and selects it.
func _add(node: Node, parent: Node, action: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("Open the map scene (world/map/map.tscn) first.")
		return
	var ur := get_undo_redo()
	ur.create_action(action)
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(self, "_own", node, root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)


func _own(node: Node, root: Node) -> void:
	node.owner = root
	for child in node.get_children():
		if child.owner == null and child.name != "Built":
			child.owner = root


func _new_road() -> void:
	if _road_styles.selected < 0:
		return
	var road := Road.new()
	road.name = "Road"
	road.style = load(_road_styles.get_item_metadata(_road_styles.selected))
	road.curve = Curve3D.new()
	var at := _in_view()
	road.curve.add_point(at)
	road.curve.add_point(at + _view_ahead() * 20.0)
	_add(road, _group("Roads"), "New road")


func _new_creek() -> void:
	var creek := Creek.new()
	creek.name = "Creek"
	creek.curve = Curve3D.new()
	var at := _in_view()
	creek.curve.add_point(at)
	creek.curve.add_point(at + _view_ahead() * 20.0)
	_add(creek, _group("Water"), "New creek")


func _new_pond() -> void:
	var pond := Pond.new()
	pond.name = "Pond"
	pond.position = _in_view() + Vector3(0, 0.5, 0)
	_add(pond, _group("Water"), "New pond")


func _new_span() -> void:
	if not _selected is Road:
		return
	var road := _selected as Road
	var span := RoadSpan.new()
	span.name = "Span"
	var mid := road.curve.sample_baked(road.curve.get_baked_length() / 2.0)
	span.position = mid + Vector3(0, 2.0, 0)
	_add(span, road, "Add bridge span")


func _new_falls() -> void:
	if not _selected is Creek:
		return
	var creek := _selected as Creek
	var falls := CreekFalls.new()
	falls.name = "Falls"
	falls.position = creek.curve.sample_baked(creek.curve.get_baked_length() / 2.0)
	_add(falls, creek, "Add waterfall")


func _new_field() -> void:
	var field := CropField.new()
	field.name = "CropField"
	field.curve = Curve3D.new()
	for plant in Plants.all():
		if plant.kind == "Crop":
			field.crop = plant
			break
	var at := _in_view()
	var ahead := _view_ahead()
	var side := Vector3(-ahead.z, 0, ahead.x)
	for corner: Vector3 in [Vector3.ZERO, ahead * 30.0, ahead * 30.0 + side * 20.0, side * 20.0]:
		field.curve.add_point(at + corner)
	_add(field, _group("Fields"), "New crop field")


func _new_rock() -> void:
	var rock := Rock.new()
	rock.name = "Rock"
	rock.shape = _rng.randi_range(1, 9999)
	rock.position = _in_view()
	rock.scale = Vector3.ONE * 1.5
	_add(rock, _group("Rocks"), "New rock")


func _new_zone() -> void:
	var zone := Zone.new()
	zone.name = "Zone"
	zone.curve = Curve3D.new()
	_add(zone, _group("Zones"), "New zone")


func _new_base_camp() -> void:
	var markers := _group("Markers")
	for node in EditorInterface.get_edited_scene_root().find_children("*", "Marker3D", true, false):
		if node is BaseCampMarker:
			push_warning("The map already has a police station camp marker (%s): move that one." % node.name)
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(node)
			return
	var camp := BaseCampMarker.new()
	camp.name = "PoliceStationCamp"
	camp.position = _in_view()
	_add(camp, markers, "Police station camp")
	camp._ready() # its Logbook, Board and Crate markers, now that it's in the scene


func _new_building() -> void:
	var building := Building.new()
	building.name = "Building"
	building.position = _in_view()
	building.floor_y = 0.02
	building.default_openings()
	_add(building, _group("Buildings"), "New building")


func _new_from_template(index: int) -> void:
	var picked: Array = _template_list.get_item_metadata(index)
	_template_list.select(0)
	if picked[0] == "Silo":
		var spec: Array = SILOS.values()[picked[1]]
		var silo := KitSilo.new()
		silo.name = "Silo"
		silo.position = _in_view()
		silo.radius = spec[0]
		silo.height = spec[1]
		silo.wall_material = load("res://world/kit/materials/%s.tres" % spec[2])
		silo.roof_material = load("res://world/kit/materials/%s.tres" % spec[3])
		_add(silo, _group("Buildings"), "New silo")
		return
	var building := Building.new()
	building.name = (picked[0] as String).to_pascal_case()
	building.position = _in_view()
	building.template = picked[0]
	building.template_variant = picked[1]
	building.apply_template() # (not in the scene yet: the add below is the undo step)
	_add(building, _group("Buildings"), "New " + picked[0])


func _furnish_selected() -> void:
	if not _selected is Building:
		push_warning("Select a building in the map scene to furnish.")
		return
	_selected.call("furnish_rooms")


func _new_mine() -> void:
	var mine := MineEntrance.new()
	mine.name = "MineEntrance"
	mine.position = _in_view()
	var ahead := _view_ahead()
	mine.rotation.y = atan2(ahead.x, ahead.z) # the tunnel (-Z) runs away from you
	_add(mine, _group("Mines"), "New mine entrance")


func _new_kit_mine() -> void:
	var mine := KitMine.new()
	mine.name = "Mine"
	mine.position = _in_view()
	var ahead := _view_ahead()
	mine.rotation.y = atan2(ahead.x, ahead.z) # its tunnel (-Z) runs away from you
	var points: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(0, 0, -6)]
	var tunnel := MineTunnel.make(points, _mine_rails.button_pressed)
	tunnel.entrance_at_start = true
	mine.tunnels = [tunnel]
	_add(mine, _group("Mines"), "New mine")


func _view_ahead() -> Vector3:
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var dir := -camera.global_basis.z
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD


# --- Apply, with undo ----------------------------------------------------------------

func _apply_selected() -> void:
	var terrain := _terrain()
	if terrain == null or not _selected or not _selected.has_method("apply"):
		push_warning("Select a road, creek, crop field, mine, mine entrance or building in the map scene (world/map/map.tscn) to apply.")
		return
	var node := _selected as Node3D
	var rect: Rect2
	if node is Path3D:
		rect = TerrainEdit.path_rect(node).grow(APPLY_MARGIN)
	else:
		rect = Rect2(node.global_position.x, node.global_position.z, 0, 0).grow(APPLY_MARGIN + 40.0)
	var before := TerrainEdit.snapshot(terrain, rect)
	var kept_before := {} # a creek's remembered bed and ground
	for prop: String in CREEK_KEPT:
		if node is Creek:
			kept_before[prop] = node.get(prop)
	node.call("apply", terrain)
	var after := TerrainEdit.snapshot(terrain, rect)
	var ur := get_undo_redo()
	ur.create_action("Apply " + node.name)
	ur.add_do_method(self, "_restore", terrain, after)
	ur.add_undo_method(self, "_restore", terrain, before)
	for prop: String in kept_before:
		ur.add_do_property(node, prop, node.get(prop))
		ur.add_undo_property(node, prop, kept_before[prop])
	if node.has_method("rebuild_later"):
		ur.add_do_method(node, "rebuild_later")
		ur.add_undo_method(node, "rebuild_later")
	ur.commit_action(false) # already done
	EditorInterface.mark_scene_as_unsaved()


func _restore(terrain: Node, shot: Dictionary) -> void:
	TerrainEdit.restore(terrain, shot)
	EditorInterface.mark_scene_as_unsaved()


# --- Plants -------------------------------------------------------------------------------

func _on_brush_chosen(index: int) -> void:
	if index == 0:
		_show_ring(false)
		_on_selection_changed()
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null or _terrain() == null:
		push_warning("Open the map scene (world/map/map.tscn) first.")
		_brush.select(0)
		return
	var layer := _group("Plants", PlantsLayer)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(layer)
	_brush.select(index) # (selecting may have reset it)
	_on_selection_changed()


func _update_plant_list() -> void:
	var terrain := _terrain()
	if terrain == null:
		push_warning("Open the map scene (world/map/map.tscn) first.")
		return
	var added := Plants.sync(terrain.assets)
	ResourceSaver.save(terrain.assets, terrain.assets.resource_path)
	_fill_plants()
	_fill_road_styles()
	print("Map Tools: plant list updated (%d new)." % added)


func _chosen_plant() -> PlantData:
	if _plant.selected < 0:
		return null
	return load(_plant.get_item_metadata(_plant.selected)) as PlantData


## One dab of the brush at pos.
func _paint(terrain: Node, pos: Vector3) -> void:
	var radius := _size.value / 2.0
	var before := PlantPainter.snapshot(terrain, pos, radius + 1.0)
	for loc: Vector2i in before:
		if not _stroke_before.has(loc):
			_stroke_before[loc] = before[loc]
	match BRUSHES[_brush.selected]:
		"Forest":
			PlantPainter.paint_forest(terrain, pos, radius, _density.value, _rng)
		"Paint plant":
			var plant := _chosen_plant()
			if plant:
				PlantPainter.paint_one(terrain, pos, radius, plant, _density.value, _rng)
		"Place one":
			var plant := _chosen_plant()
			if plant:
				PlantPainter.place_one(terrain, pos, plant, _rng)
		"Erase":
			PlantPainter.erase(terrain, pos, radius, ["Tree", "Undergrowth"])


## The stroke's one undo step: the plants before it, and after.
func _end_stroke(terrain: Node) -> void:
	_painting = false
	_last_paint = Vector3.INF
	if _stroke_before.is_empty():
		return
	var after := {}
	for loc: Vector2i in _stroke_before:
		var region = terrain.data.get_region(loc)
		if region:
			after[loc] = region.instances.duplicate(true)
	var ur := get_undo_redo()
	ur.create_action("Paint plants")
	ur.add_do_method(self, "_restore_plants", terrain, after)
	ur.add_undo_method(self, "_restore_plants", terrain, _stroke_before.duplicate())
	ur.commit_action(false) # already done
	_stroke_before = {}
	EditorInterface.mark_scene_as_unsaved()


func _restore_plants(terrain: Node, shot: Dictionary) -> void:
	PlantPainter.restore(terrain, shot)
	EditorInterface.mark_scene_as_unsaved()


func _show_ring(on: bool, at := Vector3.ZERO) -> void:
	if not on:
		if is_instance_valid(_ring):
			_ring.visible = false
		return
	if not is_instance_valid(_ring):
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.97
		torus.outer_radius = 1.0
		torus.rings = 48
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.2)
		mat.no_depth_test = true
		torus.material = mat
		_ring.mesh = torus
		_selected.add_child(_ring) # not owned: never saved
	_ring.visible = true
	_ring.global_position = at + Vector3(0, 0.2, 0)
	var r := _size.value / 2.0 if BRUSHES[_brush.selected] != "Place one" else 0.5
	_ring.scale = Vector3(r, 1.0, r)


# --- Mouse in the 3D view ----------------------------------------------------------------

func _handles(object: Object) -> bool:
	return object is Road or object is Creek or object is CropField or object is PlantsLayer or object is Zone \
			or object is Building or object is KitMine


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _selected is PlantsLayer and _brush.selected != 0:
		return _brush_input(camera, event)
	if _selected is Building and _building_tool.selected != 0:
		return _building_input(camera, event)
	if _selected is KitMine and _mine_tool.selected != 0:
		return _mine_input(camera, event)
	if not _draw.button_pressed or not (_selected is Road or _selected is Creek or _selected is CropField or _selected is Zone):
		return AFTER_GUI_INPUT_PASS
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return AFTER_GUI_INPUT_PASS
	var path := _selected as Path3D
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if path.curve.point_count > 0:
			var removed := path.curve.get_point_position(path.curve.point_count - 1)
			var ur := get_undo_redo()
			ur.create_action("Remove point")
			ur.add_do_method(path.curve, "remove_point", path.curve.point_count - 1)
			ur.add_undo_method(path.curve, "add_point", removed)
			ur.commit_action()
		return AFTER_GUI_INPUT_STOP
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	var hit := _ground_under(camera, mb.position)
	if hit == Vector3.INF:
		return AFTER_GUI_INPUT_STOP
	var ur := get_undo_redo()
	ur.create_action("Add point")
	ur.add_do_method(path.curve, "add_point", path.to_local(hit))
	ur.add_undo_method(path.curve, "remove_point", path.curve.point_count)
	ur.commit_action()
	_on_selection_changed() # the point count
	return AFTER_GUI_INPUT_STOP


func _brush_input(camera: Camera3D, event: InputEvent) -> int:
	var terrain := _terrain()
	if terrain == null:
		return AFTER_GUI_INPUT_PASS
	var mouse := event as InputEventMouse
	if mouse == null:
		return AFTER_GUI_INPUT_PASS
	var hit := _ground_under(camera, mouse.position)
	_show_ring(hit != Vector3.INF, hit)
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and hit != Vector3.INF:
			_painting = true
			_stroke_before = {}
			_paint(terrain, hit)
			_last_paint = hit
		elif not mb.pressed and _painting:
			_end_stroke(terrain)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and _painting and hit != Vector3.INF \
			and BRUSHES[_brush.selected] != "Place one" \
			and hit.distance_to(_last_paint) > _size.value * 0.25:
		_paint(terrain, hit)
		_last_paint = hit
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


## Where the mouse points on the ground, or Vector3.INF.
func _ground_under(camera: Camera3D, at: Vector2) -> Vector3:
	var terrain := _terrain()
	if terrain == null:
		return Vector3.INF
	var hit: Vector3 = terrain.get_intersection(camera.project_ray_origin(at), camera.project_ray_normal(at), false)
	if not hit.is_finite() or hit.distance_to(camera.global_position) > 3000.0:
		return Vector3.INF
	return hit


# --- Buildings ---------------------------------------------------------------------------

func _on_building_tool(_index: int) -> void:
	_draft = PackedVector2Array()
	_stair_start = Vector2.INF
	_wall_start = Vector2.INF
	_on_selection_changed()


func _building_help() -> String:
	match BUILDING_TOOLS[_building_tool.selected]:
		"Draw outline":
			return "Click its corners on the ground, going round (it closes itself). Corners snap to a 0.5 m grid and walls to right angles; hold Shift for any angle. Right-click takes back the last corner. The first click starts a new outline. Walls are numbered from the first corner."
		"Draw inner wall":
			return "Click one end of the wall, then the other (on the Floor set here; right angles, Shift for any). Ends snap to a 0.5 m grid: start and end on an outside wall or another inner wall to close off a room. Right-click removes the inner wall under the mouse. Then add doorways with Add doorway."
		"Paint room":
			return "Click inside a room (on the Floor set here): it's marked and opens in the Inspector, to set its Kind (what Furnish rooms puts in it) and give its walls and floor their own materials. Right-click on a room removes its mark."
		"Place chimney":
			return "Click where it goes (clicks land at the top of the walls). It stands from the ground up through the roof. Right-click removes the one under the mouse."
		"Place dormer":
			return "Pick a pitched Roof Shape first. Click near the edge of the roof where it goes (clicks land at the top of the walls); it sits on the nearest slope. Right-click removes the one under the mouse. Change its width in the Inspector (Dormers)."
		"Place stairs":
			return "Click where the bottom step goes, then click which way it climbs (right angles; Shift for any). It climbs from the Floor set here to the next. Right-click removes the stairs under the mouse."
		"Add door", "Add window", "Add doorway":
			return "Click on a wall, outside or inner (on the Floor set here), where it goes. Right-click removes the door or window under the mouse. Fine-tune it in the Inspector (Openings)."
		"Add garage door":
			return "Click on an outside wall of the ground floor where it goes (2.8 m wide; set Width in the Inspector, Openings, for a double). It tips up into the ceiling; zombies can't break it. Right-click removes the one under the mouse. A detached garage is a building of its own with one."
		"Add porch":
			return "Click on a wall for a roofed porch along it (it opens in the Inspector: Kind, Depth, Length, steps). Click the next wall round from a porch to wrap it round the corner. Right-click on a porch's wall removes it from the porch."
		"Add cellar door":
			return "Turn on Basement first. Click on a wall where the cellar door goes (beside the wall, outside). Then press Apply (Selected) to open the ground for the basement and the steps down. Right-click removes the one under the mouse."
	return "Pick a tool to draw its outline, place stairs, or add doors and windows. Or set it all in the Inspector. Its walls' numbers show while it's selected."


## Where the mouse points on the level of floor `level` of the building (its own x, z), or Vector2.INF.
func _on_floor(camera: Camera3D, at: Vector2, building: Node3D, level: int) -> Vector2:
	var height: float = building.call("floor_top", level) if level > 0 else 0.0
	var plane := Plane(building.global_basis.y.normalized(), building.global_transform * Vector3(0, height, 0))
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
	if hit == null:
		return Vector2.INF
	var local: Vector3 = building.to_local(hit)
	return Vector2(local.x, local.z)


static func _snap(p: Vector2) -> Vector2:
	return (p / GRID).round() * GRID


func _building_input(camera: Camera3D, event: InputEvent) -> int:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return AFTER_GUI_INPUT_PASS
	var building := _selected as Node3D
	var tool: String = BUILDING_TOOLS[_building_tool.selected]
	var level := int(_building_floor.value) if tool != "Draw outline" else 0
	if tool in ["Place chimney", "Place dormer"]:
		level = int(building.get("floors")) # the top of the walls
	var p := _on_floor(camera, mb.position, building, level)
	if p == Vector2.INF:
		return AFTER_GUI_INPUT_STOP
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	match tool:
		"Draw outline":
			_outline_click(building, p, right, mb.shift_pressed)
		"Place stairs":
			_stairs_click(building, p, right, mb.shift_pressed, level)
		"Draw inner wall":
			_inner_wall_click(building, p, right, mb.shift_pressed, level)
		"Paint room":
			_room_click(building, p, right, level)
		"Place chimney":
			_point_click(building, "chimneys", p, right, func(at: Vector2) -> Resource: return KitChimney.make(at), "chimney")
		"Place dormer":
			_point_click(building, "dormers", p, right, func(at: Vector2) -> Resource: return KitDormer.make(at), "dormer")
		"Add porch":
			_porch_click(building, p, right)
		"Add cellar door":
			_cellar_click(building, p, right)
		_:
			_opening_click(building, p, right, tool.trim_prefix("Add ").to_lower(), level)
	return AFTER_GUI_INPUT_STOP


func _outline_click(building: Node3D, p: Vector2, right: bool, free_angle: bool) -> void:
	if right:
		if _draft.is_empty():
			return
		_draft.remove_at(_draft.size() - 1)
	else:
		p = _snap(p)
		if not _draft.is_empty() and not free_angle: # a right angle to the last wall
			var last := _draft[_draft.size() - 1]
			if absf(p.x - last.x) > absf(p.y - last.y):
				p.y = last.y
			else:
				p.x = last.x
		if not _draft.is_empty() and p.is_equal_approx(_draft[_draft.size() - 1]):
			return
		_draft.append(p)
	var ur := get_undo_redo()
	ur.create_action("Draw outline")
	ur.add_do_property(building, "footprint", _draft.duplicate())
	ur.add_undo_property(building, "footprint", building.get("footprint"))
	ur.commit_action()
	_help.text = _building_help() + "\n%d corners." % _draft.size()


func _stairs_click(building: Node3D, p: Vector2, right: bool, free_angle: bool, level: int) -> void:
	var stairs: Array = building.get("stairs")
	if right:
		_stair_start = Vector2.INF
		for stair: KitStair in stairs:
			if stair and stair.level == level and stair.start.distance_to(p) < 2.5:
				_set_list(building, "stairs", stairs.filter(func(s: KitStair) -> bool: return s != stair), "Remove stairs")
				return
		return
	if _stair_start == Vector2.INF:
		_stair_start = _snap(p)
		_help.text = _building_help() + "\nNow click which way it climbs."
		return
	var toward := p - _stair_start
	var degrees := rad_to_deg(atan2(toward.y, toward.x))
	if not free_angle:
		degrees = roundf(degrees / 90.0) * 90.0
	var added := stairs.duplicate()
	added.append(KitStair.make(level, _stair_start, degrees))
	_set_list(building, "stairs", added, "Place stairs")
	_stair_start = Vector2.INF
	_help.text = _building_help()


func _inner_wall_click(building: Node3D, p: Vector2, right: bool, free_angle: bool, level: int) -> void:
	var walls: Array = building.get("inner_walls")
	if right:
		_wall_start = Vector2.INF
		for wall: KitInnerWall in walls:
			if wall and wall.level == level and Geometry2D.get_closest_point_to_segment(p, wall.start, wall.end).distance_to(p) < 0.6:
				_set_list(building, "inner_walls", walls.filter(func(w: KitInnerWall) -> bool: return w != wall), "Remove inner wall")
				return
		return
	p = _snap(p)
	if _wall_start == Vector2.INF:
		_wall_start = p
		_help.text = _building_help() + "\nNow click its other end."
		return
	if not free_angle:
		if absf(p.x - _wall_start.x) > absf(p.y - _wall_start.y):
			p.y = _wall_start.y
		else:
			p.x = _wall_start.x
	if p.distance_to(_wall_start) >= 0.5:
		var added := walls.duplicate()
		added.append(KitInnerWall.make(level, _wall_start, p))
		_set_list(building, "inner_walls", added, "Draw inner wall")
	_wall_start = Vector2.INF
	_help.text = _building_help()


func _room_click(building: Node3D, p: Vector2, right: bool, level: int) -> void:
	var rooms: Array = building.get("rooms")
	var marked: KitRoom = building.call("room_at", level, p)
	if right:
		if marked:
			_set_list(building, "rooms", rooms.filter(func(r: KitRoom) -> bool: return r != marked), "Remove room")
		return
	if marked:
		EditorInterface.edit_resource(marked) # already marked: just open it
		return
	var room := KitRoom.make(level, _snap(p))
	var added := rooms.duplicate()
	added.append(room)
	_set_list(building, "rooms", added, "Paint room")
	EditorInterface.edit_resource(room)


func _opening_click(building: Node3D, p: Vector2, right: bool, kind: String, level: int) -> void:
	var openings: Array = building.get("openings")
	# The wall nearest the click (the outline's by number, or an inner wall),
	# and how far along from its middle.
	var best := -1
	var best_inner: KitInnerWall = null
	var best_dist := 1.5
	var along := 0.0
	for n in int(building.call("edge_count")):
		var ends: Array = building.call("edge_ends", n)
		var on := Geometry2D.get_closest_point_to_segment(p, ends[0], ends[1])
		if on.distance_to(p) < best_dist:
			best = n
			best_dist = on.distance_to(p)
			along = (on - (ends[0] + ends[1]) / 2.0).dot((ends[1] - ends[0]).normalized())
	for wall: KitInnerWall in building.get("inner_walls"):
		if wall == null or wall.level != level:
			continue
		var on := Geometry2D.get_closest_point_to_segment(p, wall.start, wall.end)
		if on.distance_to(p) < best_dist:
			best_inner = wall
			best_dist = on.distance_to(p)
			along = (on - (wall.start + wall.end) / 2.0).dot((wall.end - wall.start).normalized())
	if best_inner:
		if kind == "garage door":
			push_warning("Garage doors go in outside walls.")
			return
		_inner_opening_click(best_inner, along, right, kind)
		return
	if best < 0:
		return
	if right:
		for op: KitOpening in openings:
			if op and op.level == level and int(building.call("edge_of", op)) == best and absf(op.offset - along) < op.width / 2.0 + 0.2:
				_set_list(building, "openings", openings.filter(func(o: KitOpening) -> bool: return o != op), "Remove opening")
				return
		return
	var size: Array = OPENING_SIZES[kind]
	var op := KitOpening.make_on_edge(best, kind, snappedf(along, 0.1), size[0], size[1], size[2])
	op.level = level
	if kind == "garage door":
		op.door_color = GARAGE_WHITE
	var added := openings.duplicate()
	added.append(op)
	_set_list(building, "openings", added, "Add " + kind)


## The outside wall nearest p (within 1.5 m), and how far along from its
## middle: [wall number, along], or [-1, 0].
func _nearest_wall(building: Node3D, p: Vector2) -> Array:
	var best := -1
	var best_dist := 1.5
	var along := 0.0
	for n in int(building.call("edge_count")):
		var ends: Array = building.call("edge_ends", n)
		var on := Geometry2D.get_closest_point_to_segment(p, ends[0], ends[1])
		if on.distance_to(p) < best_dist:
			best = n
			best_dist = on.distance_to(p)
			along = (on - (ends[0] + ends[1]) / 2.0).dot((ends[1] - ends[0]).normalized())
	return [best, along]


## A porch on the clicked wall: a new one, or the porch on the wall before or
## after it wrapped round onto it. Right-click: that wall comes off its porch
## (the porch goes when it's on no walls).
func _porch_click(building: Node3D, p: Vector2, right: bool) -> void:
	var n: int = _nearest_wall(building, p)[0]
	if n < 0:
		return
	var count := int(building.call("edge_count"))
	var porches: Array = building.get("porches")
	var ur := get_undo_redo()
	for porch: KitPorch in porches:
		if porch == null:
			continue
		var walls := porch.walls
		if n in walls:
			if not right:
				EditorInterface.edit_resource(porch)
				return
			if walls.size() == 1:
				_set_list(building, "porches", porches.filter(func(q: KitPorch) -> bool: return q != porch), "Remove porch")
				return
			if n != walls[0] and n != walls[walls.size() - 1]:
				push_warning("Take a wall off a porch from either end of it.")
				return
			var fewer := walls.duplicate()
			fewer.remove_at(walls.find(n))
			ur.create_action("Shorten porch")
			ur.add_do_property(porch, "walls", fewer)
			ur.add_undo_property(porch, "walls", walls)
			ur.commit_action()
			return
	if right:
		return
	for porch: KitPorch in porches:
		if porch == null or porch.walls.is_empty():
			continue
		var walls := porch.walls
		var more := walls.duplicate()
		if walls[walls.size() - 1] == posmod(n - 1, count):
			more.append(n)
		elif walls[0] == (n + 1) % count:
			more.insert(0, n)
		else:
			continue
		ur.create_action("Wrap porch round")
		ur.add_do_property(porch, "walls", more)
		ur.add_do_property(porch, "length", 0.0)
		ur.add_undo_property(porch, "walls", walls)
		ur.add_undo_property(porch, "length", porch.length)
		ur.commit_action()
		return
	var porch := KitPorch.make(PackedInt32Array([n]))
	var added := porches.duplicate()
	added.append(porch)
	_set_list(building, "porches", added, "Add porch")
	EditorInterface.edit_resource(porch)


func _cellar_click(building: Node3D, p: Vector2, right: bool) -> void:
	var hit := _nearest_wall(building, p)
	var cellars: Array = building.get("cellar_doors")
	if right:
		for cellar: KitCellarDoor in cellars:
			if cellar and cellar.wall == hit[0] and absf(cellar.offset - hit[1]) < 1.5:
				_set_list(building, "cellar_doors", cellars.filter(func(c: KitCellarDoor) -> bool: return c != cellar), "Remove cellar door")
				return
		return
	if hit[0] < 0:
		return
	var added := cellars.duplicate()
	added.append(KitCellarDoor.make(hit[0], snappedf(hit[1], 0.1)))
	_set_list(building, "cellar_doors", added, "Add cellar door")


## Chimneys and dormers: one added where clicked (on the 0.5 m grid), or the
## one under the mouse removed.
func _point_click(building: Node3D, property: String, p: Vector2, right: bool, make: Callable, what: String) -> void:
	var list: Array = building.get(property)
	if right:
		for item: Resource in list:
			if item and (item.get("position") as Vector2).distance_to(p) < 1.5:
				_set_list(building, property, list.filter(func(i: Resource) -> bool: return i != item), "Remove " + what)
				return
		return
	var added := list.duplicate()
	added.append(make.call(_snap(p)))
	_set_list(building, property, added, "Place " + what)


## An opening in an inner wall: added to (or removed from) its own list.
func _inner_opening_click(wall: KitInnerWall, along: float, right: bool, kind: String) -> void:
	var list: Array[KitOpening] = wall.openings.duplicate()
	if right:
		var keep: Array[KitOpening] = []
		var removed := false
		for op in list:
			if not removed and op and absf(op.offset - along) < op.width / 2.0 + 0.2:
				removed = true
				continue
			keep.append(op)
		if not removed:
			return
		list = keep
	else:
		var size: Array = OPENING_SIZES[kind]
		list.append(KitOpening.make("front", kind, snappedf(along, 0.1), size[0], size[1], size[2]))
	var ur := get_undo_redo()
	ur.create_action(("Remove opening" if right else "Add " + kind))
	ur.add_do_property(wall, "openings", list)
	ur.add_undo_property(wall, "openings", wall.openings)
	ur.commit_action()


## Sets one of the building's lists (stairs, openings) as one undo step.
func _set_list(building: Node3D, property: String, value: Array, action: String) -> void:
	var typed: Array = building.get(property).duplicate()
	typed.clear()
	typed.append_array(value)
	var ur := get_undo_redo()
	ur.create_action(action)
	ur.add_do_property(building, property, typed)
	ur.add_undo_property(building, property, building.get(property))
	ur.commit_action()


# --- Mines ---------------------------------------------------------------------------------

func _on_mine_tool(_index: int) -> void:
	_tunnel = null
	_chamber_start = Vector3i.MAX
	_shaft_start = Vector3i.MAX
	_flood_start = Vector3i.MAX
	if _selected is KitMine:
		_selected.set("draft", [] as Array[Vector3i])
	_on_selection_changed()


func _mine_help() -> String:
	match MINE_TOOLS[_mine_tool.selected]:
		"Draw tunnel":
			return "Click where the tunnel starts, then each corner (straight lines, on the 2.5 m grid). Change the Level between corners for a ramp (at least 3 cells per level; longer is gentler). Esc or Enter ends it; the next click starts another. Start or end on another tunnel or a chamber to join them. Right-click takes back the last corner, or removes the tunnel under the mouse. Rails and Carts: in the Inspector (Tunnels)."
		"Draw chamber":
			return "Click one corner of the chamber, then the opposite one. Its Height is in the Inspector (Chambers): taller than 4 m, a tunnel on the level above that reaches it opens onto a ledge. Right-click removes the chamber under the mouse."
		"Place shaft":
			return "Pick its kind below the Rails box. Click where it goes on one Level, then change the Level and click again: it runs between the two (tunnels there that reach its side open into it). Coming out on the surface (To Surface, Surface Height) is in the Inspector (Shafts). Esc cancels; right-click removes the shaft under the mouse."
		"Place cave-in":
			return "Click a tunnel's cell to block it with a cave-in, floor to roof (again, or right-click, to take it away). In the game it takes a pickaxe to dig through, and once it's dug out it's gone for good."
		"Flood":
			return "Click one corner of the flooded stretch, then the opposite one (on the Level set here). Its Depth is in the Inspector (Floods): 1.3 m and over you swim; 3 m and over a tunnel's flooded to its roof and you hold your breath. Right-click removes the flood under the mouse."
		"Place locker", "Place cache":
			return "Click a cell: a miner's locker (dynamite, batteries, food, now and then a helmet lamp or lantern) or a supply cache (dynamite, steel bars, scrap and sheet metal, gas) goes against its wall. Right-click removes the one under the mouse. Scatter Loot (Inspector) puts some in by itself."
		"Place zombies":
			return "Click a cell: a ZombieSpawn marker (3 zombies; Count, Chance and Spread in the Inspector). In a new game they turn up on the open cells within Spread of it (never in rock, the daylight, a cave-in or a flood), many of them miners. Right-click removes the marker under the mouse. Zombie Density on the mine (Inspector) fills it by itself too."
		"Place generator":
			return "Click where it goes (on the Level set here). It powers every cage in this mine while it runs: pour in a gas can in the game for an hour's running, and it's loud. Right-click removes the one under the mouse."
		"Mark entrance":
			return "Click the end of a tunnel that comes out of the hill: no wall there, a timber portal and the floor running on 1.5 m. Again: back to a dead end. Then set the ground level with the floor where it ends, and press Apply."
	return "Pick a tool to draw tunnels and chambers, and put in shafts and generators, on the Level set here (the plan shows through the hill: this level yellow, others blue, entrances green). Put the node where the entrance meets the hillside and press Apply to open the hill. Everything's also in the Inspector."


## Where the mouse points on the mine's Level, as a cell, or Vector3i.MAX.
func _mine_cell(camera: Camera3D, at: Vector2, mine: KitMine) -> Vector3i:
	var level := int(_mine_level.value)
	var plane := Plane(mine.global_basis.y.normalized(), mine.global_transform * Vector3(0, level * KitMine.LEVEL, 0))
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
	if hit == null:
		return Vector3i.MAX
	return KitMine.cell_at(mine.to_local(hit), level)


## The corner a click makes after `last`: straight on from it, along whichever
## way is further. On another level it's a ramp: at least RAMP_CELLS cells
## between for each level, so it's lengthened if the click was closer.
static func _straight(last: Vector3i, cell: Vector3i) -> Vector3i:
	var along_x := absi(cell.x - last.x) >= absi(cell.z - last.z)
	var corner := Vector3i(cell.x, cell.y, last.z) if along_x else Vector3i(last.x, cell.y, cell.z)
	var need := RAMP_CELLS * absi(cell.y - last.y) + 1 if cell.y != last.y else 0
	var run := (corner.x - last.x) if along_x else (corner.z - last.z)
	if absi(run) < need:
		run = need * (signi(run) if run != 0 else 1)
		if along_x:
			corner.x = last.x + run
		else:
			corner.z = last.z + run
	return corner


func _mine_input(camera: Camera3D, event: InputEvent) -> int:
	var mine := _selected as KitMine
	var tool: String = MINE_TOOLS[_mine_tool.selected]
	if _tunnel and not _tunnel in mine.tunnels:
		_tunnel = null # its start was undone
	var key := event as InputEventKey
	if key and key.pressed and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER] \
			and (_tunnel or _chamber_start != Vector3i.MAX or _shaft_start != Vector3i.MAX or _flood_start != Vector3i.MAX):
		_tunnel = null
		_chamber_start = Vector3i.MAX
		_shaft_start = Vector3i.MAX
		_flood_start = Vector3i.MAX
		mine.draft = [] as Array[Vector3i]
		return AFTER_GUI_INPUT_STOP
	var mouse := event as InputEventMouse
	if mouse == null:
		return AFTER_GUI_INPUT_PASS
	var cell := _mine_cell(camera, mouse.position, mine)
	if cell == Vector3i.MAX:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion: # what a click would add
		var preview: Array[Vector3i] = [cell]
		if tool == "Draw tunnel" and _tunnel and not _tunnel.points.is_empty():
			preview = MineTunnel.make([_tunnel.points[-1], _straight(_tunnel.points[-1], cell)] as Array[Vector3i]).cells()
		elif tool == "Draw chamber" and _chamber_start != Vector3i.MAX:
			preview = MineChamber.make(_chamber_start, cell).cells()
		elif tool == "Flood" and _flood_start != Vector3i.MAX:
			preview = MineChamber.make(_flood_start, cell).cells()
		mine.draft = preview
		return AFTER_GUI_INPUT_PASS
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return AFTER_GUI_INPUT_PASS
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	var ur := get_undo_redo()
	match tool:
		"Draw tunnel":
			if right and _tunnel:
				var points := _tunnel.points.duplicate()
				points.pop_back()
				if points.is_empty():
					_remove_from(mine, "tunnels", _tunnel, "Remove tunnel")
					_tunnel = null
				else:
					ur.create_action("Take back tunnel corner")
					ur.add_do_property(_tunnel, "points", points)
					ur.add_undo_property(_tunnel, "points", _tunnel.points)
					ur.commit_action()
			elif right:
				for tunnel in mine.tunnels:
					if tunnel and cell in tunnel.cells():
						_remove_from(mine, "tunnels", tunnel, "Remove tunnel")
						break
			elif _tunnel == null:
				_tunnel = MineTunnel.make([cell] as Array[Vector3i], _mine_rails.button_pressed)
				var list := mine.tunnels.duplicate()
				list.append(_tunnel)
				ur.create_action("Start tunnel")
				ur.add_do_property(mine, "tunnels", list)
				ur.add_undo_property(mine, "tunnels", mine.tunnels)
				ur.commit_action()
			else:
				var corner := _straight(_tunnel.points[-1], cell)
				if corner != _tunnel.points[-1]:
					var points := _tunnel.points.duplicate()
					points.append(corner)
					ur.create_action("Add tunnel corner")
					ur.add_do_property(_tunnel, "points", points)
					ur.add_undo_property(_tunnel, "points", _tunnel.points)
					ur.commit_action()
		"Draw chamber":
			if right and _chamber_start != Vector3i.MAX:
				_chamber_start = Vector3i.MAX
			elif right:
				for chamber in mine.chambers:
					if chamber and cell in chamber.cells():
						_remove_from(mine, "chambers", chamber, "Remove chamber")
						break
			elif _chamber_start == Vector3i.MAX:
				_chamber_start = cell
			else:
				var list := mine.chambers.duplicate()
				list.append(MineChamber.make(_chamber_start, cell))
				ur.create_action("Add chamber")
				ur.add_do_property(mine, "chambers", list)
				ur.add_undo_property(mine, "chambers", mine.chambers)
				ur.commit_action()
				_chamber_start = Vector3i.MAX
		"Place shaft":
			if right and _shaft_start != Vector3i.MAX:
				_shaft_start = Vector3i.MAX
			elif right:
				for shaft in mine.shafts:
					if shaft and shaft.column == Vector2i(cell.x, cell.z):
						_remove_from(mine, "shafts", shaft, "Remove shaft")
						break
			elif _shaft_start == Vector3i.MAX:
				_shaft_start = cell
			elif cell.y != _shaft_start.y:
				var list := mine.shafts.duplicate()
				list.append(MineShaft.make(Vector2i(_shaft_start.x, _shaft_start.z), _shaft_start.y, cell.y, _shaft_kind.selected))
				ur.create_action("Place shaft")
				ur.add_do_property(mine, "shafts", list)
				ur.add_undo_property(mine, "shafts", mine.shafts)
				ur.commit_action()
				_shaft_start = Vector3i.MAX
		"Place cave-in":
			var list := mine.cave_ins.duplicate()
			if right:
				list.erase(cell)
			elif not cell in list:
				list.append(cell)
			if list != mine.cave_ins:
				ur.create_action("Remove cave-in" if right else "Place cave-in")
				ur.add_do_property(mine, "cave_ins", list)
				ur.add_undo_property(mine, "cave_ins", mine.cave_ins)
				ur.commit_action()
		"Flood":
			if right and _flood_start != Vector3i.MAX:
				_flood_start = Vector3i.MAX
			elif right:
				for flood in mine.floods:
					if flood and flood.corner_a.y == cell.y and flood.rect().has_point(Vector2i(cell.x, cell.z)):
						_remove_from(mine, "floods", flood, "Remove flood")
						break
			elif _flood_start == Vector3i.MAX:
				_flood_start = cell
			else:
				var list := mine.floods.duplicate()
				list.append(MineFlood.make(_flood_start, cell))
				ur.create_action("Flood")
				ur.add_do_property(mine, "floods", list)
				ur.add_undo_property(mine, "floods", mine.floods)
				ur.commit_action()
				_flood_start = Vector3i.MAX
		"Place locker", "Place cache":
			var path: String = KitMine.LOCKER if tool == "Place locker" else KitMine.CACHE
			if right:
				for child in mine.get_children():
					if child is KitContainer and KitMine.cell_at((child as Node3D).position, cell.y) == cell:
						ur.create_action("Remove " + child.name)
						ur.add_do_method(mine, "remove_child", child)
						ur.add_undo_method(mine, "add_child", child, true)
						ur.add_undo_method(self, "_own", child, EditorInterface.get_edited_scene_root())
						ur.add_undo_reference(child)
						ur.commit_action()
						break
			else:
				var spot: Variant = mine.wall_spot(cell, 0.6)
				if spot == null:
					push_warning("No wall in that cell to put it against.")
				else:
					var piece := (load(path) as PackedScene).instantiate() as Node3D
					piece.transform = spot
					ur.create_action(tool) # (the mine stays selected: more to place)
					ur.add_do_method(mine, "add_child", piece, true)
					ur.add_do_method(self, "_own", piece, EditorInterface.get_edited_scene_root())
					ur.add_do_reference(piece)
					ur.add_undo_method(mine, "remove_child", piece)
					ur.commit_action()
		"Place zombies":
			if right:
				for child in mine.get_children():
					if child is KitZombieSpawn and KitMine.cell_at((child as Node3D).position, cell.y) == cell:
						ur.create_action("Remove zombies")
						ur.add_do_method(mine, "remove_child", child)
						ur.add_undo_method(mine, "add_child", child, true)
						ur.add_undo_method(self, "_own", child, EditorInterface.get_edited_scene_root())
						ur.add_undo_reference(child)
						ur.commit_action()
						break
			else:
				var marker := KitZombieSpawn.new()
				marker.name = "Zombies"
				marker.count = 3
				marker.spread = Vector2.ONE * KitMine.CELL * 2.0 # (in a mine: cells round it)
				marker.position = KitMine.cell_position(cell) + Vector3(0, 0.1, 0)
				ur.create_action("Place zombies") # (the mine stays selected)
				ur.add_do_method(mine, "add_child", marker, true)
				ur.add_do_method(self, "_own", marker, EditorInterface.get_edited_scene_root())
				ur.add_do_reference(marker)
				ur.add_undo_method(mine, "remove_child", marker)
				ur.commit_action()
		"Place generator":
			var at := KitMine.cell_position(cell)
			if right:
				for generator in mine.find_children("*", "MineGenerator", true, true):
					if KitMine.cell_at((generator as Node3D).position, cell.y) == cell:
						ur.create_action("Remove generator")
						ur.add_do_method(mine, "remove_child", generator)
						ur.add_undo_method(mine, "add_child", generator, true)
						ur.add_undo_method(self, "_own", generator, EditorInterface.get_edited_scene_root())
						ur.add_undo_reference(generator)
						ur.commit_action()
						break
			else:
				var generator := MineGenerator.new()
				generator.name = "Generator"
				generator.position = at
				ur.create_action("Place generator") # (the mine stays selected: more to place)
				ur.add_do_method(mine, "add_child", generator, true)
				ur.add_do_method(self, "_own", generator, EditorInterface.get_edited_scene_root())
				ur.add_do_reference(generator)
				ur.add_undo_method(mine, "remove_child", generator)
				ur.commit_action()
		"Mark entrance":
			if right:
				return AFTER_GUI_INPUT_STOP
			for tunnel in mine.tunnels:
				if tunnel == null or tunnel.points.size() < 2:
					continue
				var cells := tunnel.cells()
				var property := "entrance_at_start" if cells[0] == cell else "entrance_at_end" if cells[-1] == cell else ""
				if property != "":
					ur.create_action("Mark entrance" if not tunnel.get(property) else "Unmark entrance")
					ur.add_do_property(tunnel, property, not tunnel.get(property))
					ur.add_undo_property(tunnel, property, tunnel.get(property))
					ur.commit_action()
					break
	mine.draft = [cell] as Array[Vector3i]
	return AFTER_GUI_INPUT_STOP


## Takes a tunnel or chamber out of the mine's list, with undo.
func _remove_from(mine: KitMine, property: String, item: Resource, action: String) -> void:
	var list: Array = (mine.get(property) as Array).duplicate()
	list.erase(item)
	var ur := get_undo_redo()
	ur.create_action(action)
	ur.add_do_property(mine, property, list)
	ur.add_undo_property(mine, property, mine.get(property))
	ur.commit_action()
