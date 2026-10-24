@tool
extends RefCounted
## A mine's plan in the editor (KitMine's show_plan, for Map Tools: Mines):
## lines drawn over everything, since the hill hides the mine. Never instanced.


## Its walls' outline on each level, over everything (the hill hides the mine):
## the Level being drawn on bright, the others faint, entrances green, shafts
## a purple X, cave-ins a brown box, floods outlined blue, and what's being
## drawn orange.
static func draw(mine: KitMine) -> void:
	if not Engine.is_editor_hint() or not mine.is_inside_tree():
		return
	if not mine.show_plan:
		if mine._plan:
			mine._plan.visible = false
		return
	if mine._plan == null:
		mine._plan = MeshInstance3D.new()
		mine._plan.name = "Plan"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 10
		mine._plan.material_override = mat
		mine._plan.mesh = ImmediateMesh.new()
		mine.add_child(mine._plan, false, Node.INTERNAL_MODE_BACK)
	mine._plan.visible = true
	mine._collect()
	var mesh := mine._plan.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var lines := 0
	for cell: Vector3i in mine._cells:
		var color := Color(1.0, 0.85, 0.2) if cell.y == mine.plan_level else Color(0.6, 0.7, 0.9, 0.35)
		var y: float = mine._cells[cell]["floor"] + mine._cells[cell]["rise"] / 2.0 + 0.05
		var c := KitMine.cell_position(cell)
		for side in KitMine.SIDES:
			if mine._cells.has(cell + Vector3i(side.x, 0, side.y)):
				continue
			var open := mine._open.has(Vector4i(cell.x, cell.z, side.x, side.y))
			var out := Vector3(side.x, 0, side.y) * KitMine.CELL / 2.0
			var along := Vector3(absi(side.y), 0, absi(side.x)) * KitMine.CELL / 2.0
			mesh.surface_set_color(Color(0.3, 1.0, 0.4) if open else color)
			mesh.surface_add_vertex(Vector3(c.x, y, c.z) + out - along)
			mesh.surface_add_vertex(Vector3(c.x, y, c.z) + out + along)
			lines += 1
	for shaft in mine.shafts: # an X across it on every level it passes
		if shaft == null:
			continue
		for level in range(shaft.bottom, shaft.top + 1):
			var c := KitMine.cell_position(Vector3i(shaft.column.x, level, shaft.column.y)) + Vector3(0, 0.05, 0)
			var h := KitMine.CELL / 2.0 - 0.15
			mesh.surface_set_color(Color(0.8, 0.4, 1.0) if level == mine.plan_level else Color(0.8, 0.4, 1.0, 0.35))
			for corner: Vector3 in [Vector3(-h, 0, -h), Vector3(h, 0, h), Vector3(h, 0, -h), Vector3(-h, 0, h)]:
				mesh.surface_add_vertex(c + corner)
			lines += 2
	for cell in mine.cave_ins: # a brown box in each cave-in
		var c := KitMine.cell_position(cell) + Vector3(0, 0.08, 0)
		var h := KitMine.CELL / 2.0 - 0.35
		mesh.surface_set_color(Color(0.8, 0.5, 0.2) if cell.y == mine.plan_level else Color(0.8, 0.5, 0.2, 0.35))
		for i in 4:
			var a := Vector3(h, 0, h).rotated(Vector3.UP, i * PI / 2.0)
			mesh.surface_add_vertex(c + a)
			mesh.surface_add_vertex(c + a.rotated(Vector3.UP, PI / 2.0))
		lines += 4
	for flood in mine.floods: # a blue outline round each flood
		if flood == null:
			continue
		var r := flood.rect()
		var y := flood.corner_a.y * KitMine.LEVEL + 0.12
		var lo := Vector3((r.position.x - 0.5) * KitMine.CELL + 0.2, y, (r.position.y - 0.5) * KitMine.CELL + 0.2)
		var hi := Vector3((r.end.x - 0.5) * KitMine.CELL - 0.2, y, (r.end.y - 0.5) * KitMine.CELL - 0.2)
		var corners := [lo, Vector3(hi.x, y, lo.z), hi, Vector3(lo.x, y, hi.z)]
		mesh.surface_set_color(Color(0.3, 0.6, 1.0) if flood.corner_a.y == mine.plan_level else Color(0.3, 0.6, 1.0, 0.35))
		for i in 4:
			mesh.surface_add_vertex(corners[i])
			mesh.surface_add_vertex(corners[(i + 1) % 4])
		lines += 4
	for i in mine.draft.size():
		var c := KitMine.cell_position(mine.draft[i]) + Vector3(0, 0.1, 0)
		for side in KitMine.SIDES: # a box round each cell
			var out := Vector3(side.x, 0, side.y) * (KitMine.CELL / 2.0 - 0.1)
			var along := Vector3(absi(side.y), 0, absi(side.x)) * (KitMine.CELL / 2.0 - 0.1)
			mesh.surface_set_color(Color(1.0, 0.5, 0.1))
			mesh.surface_add_vertex(c + out - along)
			mesh.surface_add_vertex(c + out + along)
			lines += 1
	if lines == 0: # (an empty surface is an error)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()
