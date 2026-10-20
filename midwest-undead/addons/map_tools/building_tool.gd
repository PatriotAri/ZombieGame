@tool
extends RefCounted
## Map Tools' building tools (map_tools.gd keeps one): with a building
## selected, the tool chosen in the panel's Buildings section decides what
## clicking in the 3D view does: draw its outline or an inner wall, place
## stairs, add doors and windows, paint rooms, place chimneys and dormers, add
## porches and cellar doors. Every change is undoable.

const MapTools := preload("res://addons/map_tools/map_tools.gd")
const Building := preload("res://world/building.gd")
const BUILDING_TOOLS := ["Off", "Draw outline", "Draw inner wall", "Place stairs", "Add door", "Add window", "Add doorway",
		"Add garage door", "Paint room", "Place chimney", "Place dormer", "Add porch", "Add cellar door"]
## Openings the tools add: [width, bottom, top]. Doors and doorways are as wide
## as zombies need to path through (Building.MIN_PASSAGE).
const OPENING_SIZES := {"door": [1.6, 0.0, 2.4], "window": [1.2, 0.9, 2.3], "doorway": [1.6, 0.0, 2.4],
		"garage door": [2.8, 0.0, 2.3]}
const GARAGE_WHITE := Color(0.85, 0.85, 0.82)
const GRID := 0.5

var plugin: MapTools # map_tools.gd
var tool_list: OptionButton
var _floor_box: SpinBox
var _draft := PackedVector2Array() # the outline being drawn, in click order
var _stair_start := Vector2.INF # Place stairs: where the flight starts, before the second click
var _wall_start := Vector2.INF # Draw inner wall: its first end, before the second click
var _numbered: Node # the building showing its wall numbers


func _init(tools: MapTools) -> void:
	plugin = tools


## Its part of the panel (under Buildings): the tool list and its settings.
func build_section(buildings: VBoxContainer) -> void:
	tool_list = OptionButton.new()
	for t: String in BUILDING_TOOLS:
		tool_list.add_item(t)
	tool_list.tooltip_text = "What clicking in the 3D view does to the selected building."
	tool_list.item_selected.connect(_on_tool_chosen)
	buildings.add_child(tool_list)
	var floor_row := HBoxContainer.new()
	var floor_label := Label.new()
	floor_label.text = "Floor"
	floor_row.add_child(floor_label)
	_floor_box = SpinBox.new()
	_floor_box.min_value = -1
	_floor_box.max_value = 19
	_floor_box.tooltip_text = "The floor the stairs and openings go on (0: the ground floor, -1: the basement). Stairs climb from it to the next."
	floor_row.add_child(_floor_box)
	buildings.add_child(floor_row)


## The selection changed (the plugin's _on_selection_changed): the selected
## building shows its wall numbers, and the tool goes Off for anything else.
func selection_changed() -> void:
	if _numbered != plugin._selected:
		if is_instance_valid(_numbered):
			_numbered.set("show_numbers", false)
		_numbered = plugin._selected if plugin._selected is Building else null
		if _numbered:
			_numbered.set("show_numbers", true)
	tool_list.disabled = not plugin._selected is Building
	if not plugin._selected is Building and tool_list.selected != 0:
		tool_list.select(0)


func _on_tool_chosen(_index: int) -> void:
	_draft = PackedVector2Array()
	_stair_start = Vector2.INF
	_wall_start = Vector2.INF
	plugin._on_selection_changed()


func help() -> String:
	match BUILDING_TOOLS[tool_list.selected]:
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


func input(camera: Camera3D, event: InputEvent) -> int:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var building := plugin._selected as Node3D
	var tool: String = BUILDING_TOOLS[tool_list.selected]
	var level := int(_floor_box.value) if tool != "Draw outline" else 0
	if tool in ["Place chimney", "Place dormer"]:
		level = int(building.get("floors")) # the top of the walls
	var p := _on_floor(camera, mb.position, building, level)
	if p == Vector2.INF:
		return EditorPlugin.AFTER_GUI_INPUT_STOP
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
	return EditorPlugin.AFTER_GUI_INPUT_STOP


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
	var ur := plugin.get_undo_redo()
	ur.create_action("Draw outline")
	ur.add_do_property(building, "footprint", _draft.duplicate())
	ur.add_undo_property(building, "footprint", building.get("footprint"))
	ur.commit_action()
	plugin._help.text = help() + "\n%d corners." % _draft.size()


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
		plugin._help.text = help() + "\nNow click which way it climbs."
		return
	var toward := p - _stair_start
	var degrees := rad_to_deg(atan2(toward.y, toward.x))
	if not free_angle:
		degrees = roundf(degrees / 90.0) * 90.0
	var added := stairs.duplicate()
	added.append(KitStair.make(level, _stair_start, degrees))
	_set_list(building, "stairs", added, "Place stairs")
	_stair_start = Vector2.INF
	plugin._help.text = help()


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
		plugin._help.text = help() + "\nNow click its other end."
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
	plugin._help.text = help()


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
	var ur := plugin.get_undo_redo()
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
	var ur := plugin.get_undo_redo()
	ur.create_action(("Remove opening" if right else "Add " + kind))
	ur.add_do_property(wall, "openings", list)
	ur.add_undo_property(wall, "openings", wall.openings)
	ur.commit_action()


## Sets one of the building's lists (stairs, openings) as one undo step.
func _set_list(building: Node3D, property: String, value: Array, action: String) -> void:
	var typed: Array = building.get(property).duplicate()
	typed.clear()
	typed.append_array(value)
	var ur := plugin.get_undo_redo()
	ur.create_action(action)
	ur.add_do_property(building, property, typed)
	ur.add_undo_property(building, property, building.get(property))
	ur.commit_action()
