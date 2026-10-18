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
## right angles unless Shift is held), places stairs (click where a flight
## starts, then which way it climbs) or puts doors and windows in its walls
## (click on a wall). Right-click takes back the last corner, or removes the
## stairs or opening under the mouse. Its walls' numbers show while it's selected.

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
const BUILDING_TOOLS := ["Off", "Draw outline", "Place stairs", "Add door", "Add window", "Add doorway"]
## Openings the tools add: [width, bottom, top].
const OPENING_SIZES := {"door": [1.0, 0.0, 2.2], "window": [1.2, 0.9, 2.3], "doorway": [1.2, 0.0, 2.4]}
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
var _numbered: Node # the building showing its wall numbers


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
	_building_floor.min_value = 0
	_building_floor.max_value = 19
	_building_floor.tooltip_text = "The floor the stairs and openings go on (0: the ground floor). Stairs climb from it to the next."
	floor_row.add_child(_building_floor)
	buildings.add_child(floor_row)

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
	_apply = _button(selected, "Apply", "Shapes, paints or opens the ground for the selected road, creek, crop field or mine entrance. Ctrl+Z undoes it.", _apply_selected)

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
			or nodes[0] is Rock or nodes[0] is MineEntrance or nodes[0] is PlantsLayer or nodes[0] is Zone or nodes[0] is Building):
		_selected = nodes[0]
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
	_apply.disabled = not ((path and not _selected is Zone) or _selected is MineEntrance)
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


func _new_mine() -> void:
	var mine := MineEntrance.new()
	mine.name = "MineEntrance"
	mine.position = _in_view()
	var ahead := _view_ahead()
	mine.rotation.y = atan2(ahead.x, ahead.z) # the tunnel (-Z) runs away from you
	_add(mine, _group("Mines"), "New mine entrance")


func _view_ahead() -> Vector3:
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var dir := -camera.global_basis.z
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD


# --- Apply, with undo ----------------------------------------------------------------

func _apply_selected() -> void:
	var terrain := _terrain()
	if terrain == null or not _selected or not _selected.has_method("apply"):
		push_warning("Select a road, creek, crop field or mine entrance in the map scene (world/map/map.tscn) to apply.")
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
			or object is Building


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _selected is PlantsLayer and _brush.selected != 0:
		return _brush_input(camera, event)
	if _selected is Building and _building_tool.selected != 0:
		return _building_input(camera, event)
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
	_on_selection_changed()


func _building_help() -> String:
	match BUILDING_TOOLS[_building_tool.selected]:
		"Draw outline":
			return "Click its corners on the ground, going round (it closes itself). Corners snap to a 0.5 m grid and walls to right angles; hold Shift for any angle. Right-click takes back the last corner. The first click starts a new outline. Walls are numbered from the first corner."
		"Place stairs":
			return "Click where the bottom step goes, then click which way it climbs (right angles; Shift for any). It climbs from the Floor set here to the next. Right-click removes the stairs under the mouse."
		"Add door", "Add window", "Add doorway":
			return "Click on a wall (on the Floor set here) where it goes. Right-click removes the door or window under the mouse. Fine-tune it in the Inspector (Openings)."
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
	var p := _on_floor(camera, mb.position, building, level)
	if p == Vector2.INF:
		return AFTER_GUI_INPUT_STOP
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	match tool:
		"Draw outline":
			_outline_click(building, p, right, mb.shift_pressed)
		"Place stairs":
			_stairs_click(building, p, right, mb.shift_pressed, level)
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


func _opening_click(building: Node3D, p: Vector2, right: bool, kind: String, level: int) -> void:
	var openings: Array = building.get("openings")
	# The wall nearest the click: its number, and how far along from its middle.
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
	var added := openings.duplicate()
	added.append(op)
	_set_list(building, "openings", added, "Add " + kind)


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
