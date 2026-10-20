@tool
extends RefCounted
## Map Tools' mine tools (map_tools.gd keeps one): with a mine selected,
## the tool chosen in the panel's Mines section decides what clicking in the
## 3D view does, on the level chosen: draw tunnels and chambers, mark
## entrances, place shafts, generators, cave-ins, floods, lockers, caches and
## zombies. Every change is undoable.

const MapTools := preload("res://addons/map_tools/map_tools.gd")
const MINE_TOOLS := ["Off", "Draw tunnel", "Draw chamber", "Mark entrance", "Place shaft", "Place generator", "Place cave-in", "Flood", "Place locker", "Place cache", "Place zombies"]
const SHAFT_KINDS := ["Ladder", "Open", "Cage"] # (MineShaft.Kind's order)
const RAMP_CELLS := 3 # a ramp's cells for each level it climbs: about 28 degrees

var plugin: MapTools # map_tools.gd
var tool_list: OptionButton
var level_box: SpinBox
var rails_box: CheckBox
var _planned: Node # the mine showing its plan
var _tunnel: MineTunnel # Draw tunnel: the one being drawn, or null
var _chamber_start := Vector3i.MAX # Draw chamber: its first corner, before the second click
var _shaft_start := Vector3i.MAX # Place shaft: its first end, before the click on the other level
var _flood_start := Vector3i.MAX # Flood: its first corner, before the second click
var _shaft_kind: OptionButton


func _init(tools: MapTools) -> void:
	plugin = tools


## Its part of the panel (under Mines): the tool list and its settings.
func build_section(mines: VBoxContainer) -> void:
	tool_list = OptionButton.new()
	for t: String in MINE_TOOLS:
		tool_list.add_item(t)
	tool_list.tooltip_text = "What clicking in the 3D view does to the selected mine."
	tool_list.item_selected.connect(_on_tool_chosen)
	mines.add_child(tool_list)
	var level_row := HBoxContainer.new()
	var level_label := Label.new()
	level_label.text = "Level"
	level_row.add_child(level_label)
	level_box = SpinBox.new()
	level_box.min_value = -10
	level_box.max_value = 3
	level_box.tooltip_text = "The level the tools draw on (0: the mine's own height, -1: 4 m under it...)."
	level_box.value_changed.connect(func(v: float) -> void:
		if plugin._selected is KitMine:
			plugin._selected.set("plan_level", int(v)))
	level_row.add_child(level_box)
	mines.add_child(level_row)
	rails_box = CheckBox.new()
	rails_box.text = "Rails"
	rails_box.tooltip_text = "New tunnels get rails (each tunnel's Rails and Carts are in the Inspector, Tunnels)."
	rails_box.button_pressed = true
	mines.add_child(rails_box)
	_shaft_kind = OptionButton.new()
	for k: String in SHAFT_KINDS:
		_shaft_kind.add_item(k + " shaft")
	_shaft_kind.tooltip_text = "What Place shaft puts in: a ladder (with landings), an open drop, or a cage elevator (it needs a generator running somewhere in the mine)."
	mines.add_child(_shaft_kind)


## The selection changed (the plugin's _on_selection_changed): the selected
## mine shows its plan, and the tool goes Off for anything else.
func selection_changed() -> void:
	if _planned != plugin._selected:
		if is_instance_valid(_planned):
			_planned.set("show_plan", false)
			_planned.set("draft", [] as Array[Vector3i])
		_planned = plugin._selected if plugin._selected is KitMine else null
		_tunnel = null
		_chamber_start = Vector3i.MAX
		if _planned:
			_planned.set("plan_level", int(level_box.value))
			_planned.set("show_plan", true)
	tool_list.disabled = not plugin._selected is KitMine
	if not plugin._selected is KitMine and tool_list.selected != 0:
		tool_list.select(0)


func _on_tool_chosen(_index: int) -> void:
	_tunnel = null
	_chamber_start = Vector3i.MAX
	_shaft_start = Vector3i.MAX
	_flood_start = Vector3i.MAX
	if plugin._selected is KitMine:
		plugin._selected.set("draft", [] as Array[Vector3i])
	plugin._on_selection_changed()


func help() -> String:
	match MINE_TOOLS[tool_list.selected]:
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
	var level := int(level_box.value)
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


func input(camera: Camera3D, event: InputEvent) -> int:
	var mine := plugin._selected as KitMine
	var tool: String = MINE_TOOLS[tool_list.selected]
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
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	var mouse := event as InputEventMouse
	if mouse == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var cell := _mine_cell(camera, mouse.position, mine)
	if cell == Vector3i.MAX:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion: # what a click would add
		var preview: Array[Vector3i] = [cell]
		if tool == "Draw tunnel" and _tunnel and not _tunnel.points.is_empty():
			preview = MineTunnel.make([_tunnel.points[-1], _straight(_tunnel.points[-1], cell)] as Array[Vector3i]).cells()
		elif tool == "Draw chamber" and _chamber_start != Vector3i.MAX:
			preview = MineChamber.make(_chamber_start, cell).cells()
		elif tool == "Flood" and _flood_start != Vector3i.MAX:
			preview = MineChamber.make(_flood_start, cell).cells()
		mine.draft = preview
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	var ur := plugin.get_undo_redo()
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
				_tunnel = MineTunnel.make([cell] as Array[Vector3i], rails_box.button_pressed)
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
						ur.add_undo_method(plugin, "_own", child, EditorInterface.get_edited_scene_root())
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
					ur.add_do_method(plugin, "_own", piece, EditorInterface.get_edited_scene_root())
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
						ur.add_undo_method(plugin, "_own", child, EditorInterface.get_edited_scene_root())
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
				ur.add_do_method(plugin, "_own", marker, EditorInterface.get_edited_scene_root())
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
						ur.add_undo_method(plugin, "_own", generator, EditorInterface.get_edited_scene_root())
						ur.add_undo_reference(generator)
						ur.commit_action()
						break
			else:
				var generator := MineGenerator.new()
				generator.name = "Generator"
				generator.position = at
				ur.create_action("Place generator") # (the mine stays selected: more to place)
				ur.add_do_method(mine, "add_child", generator, true)
				ur.add_do_method(plugin, "_own", generator, EditorInterface.get_edited_scene_root())
				ur.add_do_reference(generator)
				ur.add_undo_method(mine, "remove_child", generator)
				ur.commit_action()
		"Mark entrance":
			if right:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
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
	return EditorPlugin.AFTER_GUI_INPUT_STOP


## Takes a tunnel or chamber out of the mine's list, with undo.
func _remove_from(mine: KitMine, property: String, item: Resource, action: String) -> void:
	var list: Array = (mine.get(property) as Array).duplicate()
	list.erase(item)
	var ur := plugin.get_undo_redo()
	ur.create_action(action)
	ur.add_do_property(mine, property, list)
	ur.add_undo_property(mine, property, mine.get(property))
	ur.commit_action()
