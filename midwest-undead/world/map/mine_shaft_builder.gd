@tool
extends RefCounted
## A mine's shafts (world/map/mine_shaft.gd), for KitMine to build: the
## ladder and its landings, the cage (world/map/mine_cage.gd) with its gates,
## call buttons and the stops' floors for the navigation bake, and out on the
## surface a stone collar and a timber headframe. Never instanced.

const KitMesh := preload("res://world/kit/kit_mesh.gd")
const GameData := preload("res://core/game_data.gd")
const ClimbArea := preload("res://world/climb_area.gd")


## The levels a tunnel (or chamber) comes into the shaft on: level -> [sides].
static func _entries(mine: KitMine, shaft: MineShaft) -> Dictionary:
	var entries := {}
	for level in range(shaft.bottom, shaft.top + 1):
		var on := Vector2(level * KitMine.LEVEL, level * KitMine.LEVEL + KitMine.TUNNEL_HEIGHT)
		for side in KitMine.SIDES:
			if KitMine._overlaps(mine._columns.get(shaft.column + side, []), on):
				if not entries.has(level):
					entries[level] = []
				(entries[level] as Array).append(side)
	return entries


## A shaft's insides: for a ladder shaft, the ladder up the middle of the wall
## no tunnel comes in by (or the fewest), and landings (the half of the shaft
## away from the ladder) on the levels tunnels come in on, to step off onto.
## Out on the surface, a stone collar round it and a timber headframe over it.
static func build(mine: KitMine, shaft: MineShaft, inside: KitMesh, outside: KitMesh) -> void:
	var center := KitMine.cell_position(Vector3i(shaft.column.x, 0, shaft.column.y))
	var entries := _entries(mine, shaft)
	var surface := shaft.top * KitMine.LEVEL + shaft.surface_height
	if shaft.kind == MineShaft.Kind.LADDER:
		var wall: Vector2i = KitMine.SIDES[0]
		var fewest := INF
		for side in KitMine.SIDES:
			var count := 0
			for level: int in entries:
				count += (entries[level] as Array).count(side)
			if count < fewest:
				fewest = count
				wall = side
		var w := Vector3(wall.x, 0, wall.y)
		var across := Vector3(absi(wall.y), 0, absi(wall.x))
		# Where you can step off: the bottom, each level a tunnel comes in on, the top.
		var stops: Array[float] = [shaft.bottom * KitMine.LEVEL]
		for level in range(shaft.bottom + 1, shaft.top + 1):
			if entries.has(level) or (level == shaft.top and not shaft.to_surface):
				stops.append(level * KitMine.LEVEL)
				# The landing.
				inside.box(across * KitMine.CELL + Vector3(absi(wall.x), 0, absi(wall.y)) * (KitMine.CELL / 2.0) + Vector3(0, 0.15, 0),
						Transform3D(Basis.IDENTITY, center - w * KitMine.CELL / 4.0 + Vector3(0, level * KitMine.LEVEL - 0.075, 0)), KitMesh.all(KitMine.PLANKS))
		if shaft.to_surface:
			stops.append(surface)
		var foot := center + w * (KitMine.CELL / 2.0 - 0.05) + Vector3(0, stops[0], 0)
		var basis := Basis(Vector3.UP, atan2(-w.x, -w.z)) # its +Z out from the wall
		var length := stops[-1] - stops[0] + 1.0
		var look := KitProp.make(KitMine.LADDER, [], Vector3(0.56, length, 0.06), Vector3(0, length / 2.0, 0))
		look.transform = Transform3D(basis, foot)
		mine.add_child(look, false, Node.INTERNAL_MODE_BACK)
		mine._generated.append(look)
		if not Engine.is_editor_hint():
			_climb_area(mine, Transform3D(basis, foot), stops[-1] - stops[0], stops.slice(1, stops.size() - 1))
	if shaft.kind == MineShaft.Kind.CAGE:
		_cage(mine, shaft, center, entries, surface)
	if shaft.to_surface:
		# The collar: flush with the ground, round the top.
		for side in KitMine.SIDES:
			var s := Vector3(side.x, 0, side.y)
			var along := Vector3(absi(side.y), 0, absi(side.x))
			outside.box(along * (KitMine.CELL + 2.0 * KitMine.COLLAR) + Vector3(absi(side.x), 0, absi(side.y)) * KitMine.COLLAR + Vector3(0, 0.85, 0),
					Transform3D(Basis.IDENTITY, center + s * (KitMine.CELL + KitMine.COLLAR) / 2.0 + Vector3(0, surface - 0.4, 0)), KitMesh.all(KitMine.STONE))
		# The headframe: two posts and a beam across, over the shaft.
		for s: float in [-1.0, 1.0]:
			outside.box(Vector3(0.3, 5.0, 0.3), Transform3D(Basis.IDENTITY, center + Vector3(s * (KitMine.CELL / 2.0 + 0.5), surface + 2.5, 0)),
					KitMesh.all(KitMine.TIMBER))
		outside.box(Vector3(KitMine.CELL + 1.6, 0.35, 0.35), Transform3D(Basis.IDENTITY, center + Vector3(0, surface + 5.0, 0)), KitMesh.all(KitMine.TIMBER))


## A cage shaft's cage (world/map/mine_cage.gd), its stops' gates and call
## buttons, and a floor the navigation bake sees (only) at each stop, so
## zombies can follow you in when its gate's open. It starts at the top.
static func _cage(mine: KitMine, shaft: MineShaft, center: Vector3, entries: Dictionary, surface: float) -> void:
	var stops: Array[float] = []
	var sides: Array = [] # each stop's sides with a way in
	for level in range(shaft.bottom, shaft.top + 1):
		if entries.has(level) or level == shaft.bottom or (level == shaft.top and not shaft.to_surface):
			stops.append(level * KitMine.LEVEL)
			sides.append(entries.get(level, []))
	if shaft.to_surface:
		stops.append(surface)
		sides.append(KitMine.SIDES.duplicate())
	var barred: Array = []
	for side in KitMine.SIDES:
		if not sides.any(func(at: Array) -> bool: return side in at):
			barred.append(side)
	var cage := MineCage.new()
	cage.name = "Cage"
	cage.mine = mine
	cage.stops = stops
	cage.at = stops.size() - 1
	cage.build(KitMine.CELL - 0.3, barred)
	cage.position = center + Vector3(0, stops[-1], 0)
	cage.add_to_group(&"not_in_navigation")
	var iron := StandardMaterial3D.new()
	iron.albedo_color = MineCage.IRON
	for i in stops.size():
		var stop_gates: Array = []
		for side: Vector2i in sides[i]:
			var out := Vector3(side.x, 0, side.y)
			var along := Vector3(absi(side.y), 0, absi(side.x))
			var gate := StaticBody3D.new()
			gate.name = "Gate%d" % (cage.gates.size() * 4 + stop_gates.size())
			var gk := KitMesh.new()
			for b in 9:
				gk.box(Vector3(0.04, 2.2, 0.04), Transform3D(Basis.IDENTITY, along * (-KitMine.CELL / 2.0 + 0.15 + b * (KitMine.CELL - 0.3) / 8.0) + Vector3(0, 1.15, 0)),
						KitMesh.all(iron), false)
			gk.box(along * (KitMine.CELL - 0.1) + Vector3(0, 0.08, 0) + out.abs() * 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0)), KitMesh.all(iron), false)
			gk.box(along * (KitMine.CELL - 0.1) + Vector3(0, 0.08, 0) + out.abs() * 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), KitMesh.all(iron), false)
			gk.box(along * (KitMine.CELL - 0.1) + Vector3(0, 2.3, 0) + out.abs() * 0.08, Transform3D(Basis.IDENTITY, Vector3(0, 1.15, 0)), [null, null, null, null, null, null])
			for node in gk.add_to(gate):
				if node is MeshInstance3D:
					(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
			gate.position = center + out * (KitMine.CELL / 2.0 - 0.06) + Vector3(0, stops[i], 0)
			gate.add_to_group(&"not_in_navigation")
			mine.add_child(gate, false, Node.INTERNAL_MODE_BACK)
			mine._generated.append(gate)
			stop_gates.append(gate)
			# Its call button, on the wall beside it (on the surface: on the headframe's post).
			var button := MineControl.new()
			button.name = "Call%d_%d" % [i, stop_gates.size()]
			button.collision_layer = GameData.LAYER_ITEMS # (found by interact's ray only)
			button.collision_mask = 0
			var bk := KitMesh.new()
			var red := StandardMaterial3D.new()
			red.albedo_color = Color(0.6, 0.1, 0.08)
			bk.box(Vector3(0.18, 0.25, 0.18), Transform3D.IDENTITY, KitMesh.all(iron))
			bk.box(Vector3(0.1, 0.1, 0.1), Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0) + out * 0.09), KitMesh.all(red), false)
			for node in bk.add_to(button):
				if node is MeshInstance3D:
					(node as MeshInstance3D).layers = GameData.RENDER_UNDERGROUND
			var stop := i
			button.prompt = func() -> String: return cage.call_prompt(stop)
			button.action = func(player: Node) -> void: cage.go_to(stop, player)
			button.position = center + out * (KitMine.CELL / 2.0 + 0.35) + along * (KitMine.CELL / 2.0 - 0.1) + Vector3(0, stops[i] + 1.2, 0)
			mine.add_child(button, false, Node.INTERNAL_MODE_BACK)
			mine._generated.append(button)
		cage.gates.append(stop_gates)
		if i > 0: # (the bottom has a floor already)
			var nav_floor := StaticBody3D.new()
			nav_floor.name = "CageStop%d" % i
			nav_floor.collision_layer = GameData.LAYER_NAV_ONLY
			nav_floor.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(KitMine.CELL, 0.1, KitMine.CELL)
			shape.shape = box
			nav_floor.add_child(shape)
			nav_floor.position = center + Vector3(0, stops[i] - 0.05, 0)
			mine.add_child(nav_floor, false, Node.INTERNAL_MODE_BACK)
			mine._generated.append(nav_floor)
	mine.add_child(cage, false, Node.INTERNAL_MODE_BACK)
	mine._generated.append(cage)


## A ladder's climbing area, from its foot up `height`: you hold on while
## you're in it (player.gd), as for the silo's ladder, but can step off at its
## top and at the landings on the way (heights in the mine's space).
static func _climb_area(mine: KitMine, at: Transform3D, height: float, landings: Array[float]) -> void:
	var area := ClimbArea.make(Vector3(0.9, height + 1.0, KitMine.CLIMB_REACH), Vector3(0, (height + 1.0) / 2.0, KitMine.CLIMB_REACH / 2.0))
	area.name = "Climb"
	area.transform = at
	mine.add_child(area, false, Node.INTERNAL_MODE_BACK)
	mine._generated.append(area)
	var place := func() -> void: # (the map's heights, once it's placed)
		var y0 := area.global_position.y - at.origin.y
		area.set_meta("top_y", y0 + at.origin.y + height + 0.3)
		area.set_meta("landings", landings.map(func(l: float) -> float: return y0 + l))
	if area.is_inside_tree():
		place.call()
	else:
		area.ready.connect(place, CONNECT_ONE_SHOT)
