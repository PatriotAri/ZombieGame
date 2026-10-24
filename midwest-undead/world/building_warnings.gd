@tool
extends RefCounted
## What's wrong with a building, for the editor's warning triangle on it
## (KitBuilding._get_configuration_warnings): an outline that crosses itself,
## floors nothing goes up to, openings that don't fit their walls, rooms
## outside it, cellar doors and porches that don't fit. Never instanced.

const KitRoof := preload("res://world/kit/kit_roof.gd")
const PorchBuilder := preload("res://world/porch_builder.gd")


static func of(building: KitBuilding) -> PackedStringArray:
	var warnings := PackedStringArray()
	if building.footprint.size() > 0 and building.footprint.size() < 3:
		warnings.append("The drawn outline needs at least 3 corners (it's using the Size rectangle until then).")
	elif building.footprint.size() >= 3 and not Geometry2D.triangulate_polygon(building.footprint).size():
		warnings.append("The drawn outline crosses itself: draw it again going round once.")
	if building.roof_shape != "Flat" and not KitRoof.fits(building.outline()):
		warnings.append("A pitched roof needs walls that all meet at right angles (along x or z): this one gets a flat roof.")
	for k in building._top_level():
		if not building._flights().any(func(f: Dictionary) -> bool: return f["level"] == k):
			warnings.append("Nothing goes up from floor %d to floor %d: place stairs (Map Tools, Buildings)." % [k, k + 1] if building.footprint.size() >= 3 or building.stairs.any(func(st: KitStair) -> bool: return st != null and st.level >= 0)
					else "Too shallow for the staircase to floor %d: it needs %.1f m of depth." % [k + 1, building._stairs_needs(k)])
	if building.basement and not building._flights().any(func(f: Dictionary) -> bool: return f["level"] == -1) \
			and not building.cellar_doors.any(func(c: KitCellarDoor) -> bool: return c != null):
		warnings.append("Nothing goes down to the basement: place stairs from floor -1, or add a cellar door.")
	for flight in building._flights():
		if flight["level"] < building.bottom_level():
			warnings.append("A staircase starts on floor -1, but the building has no Basement.")
		elif flight["level"] >= building._top_level():
			warnings.append("A staircase starts on floor %d, but there's nothing above it (%d floor(s)%s)." % [flight["level"], building.floors, ", and no walk-in attic" if flight["level"] == building.floors - 1 else ""])
		elif flight["level"] == building.floors - 1 and building._walk_in_attic() and building._headroom(flight) < 2.0:
			warnings.append("The stairs to the attic come up where the roof is only %.1f m above the attic floor: move them under the ridge." % building._headroom(flight))
		elif not building._flight_fits(flight):
			warnings.append("A staircase on floor %d doesn't fit inside the building (it needs %.1f m of room ahead of its bottom step)." % [flight["level"], building._run(flight["level"]) + KitBuilding.LANDING])
	for op in building.openings:
		if op == null:
			continue
		var n := building.edge_of(op)
		if n >= building.edge_count():
			warnings.append("An opening is on wall %d, but the building has %d walls." % [n, building.edge_count()])
			continue
		var ends := building.edge_ends(n)
		var length := ends[0].distance_to(ends[1])
		if absf(op.offset) + op.width / 2.0 > length / 2.0 - KitBuilding.WALL or op.top > KitBuilding.STOREY - 0.25 or op.bottom < 0.0:
			warnings.append("An opening on wall %d (floor %d) doesn't fit in the wall." % [n, op.level])
		if op.level >= building.floors:
			warnings.append("An opening is on floor %d, but the building has %d floor(s)." % [op.level, building.floors])
		if op.kind != "window" and op.width < KitBuilding.MIN_PASSAGE - 0.01:
			warnings.append("A %s on wall %d (floor %d) is under %.1f m wide: zombies can't find their way through it." % [op.kind, n, op.level, KitBuilding.MIN_PASSAGE])
		if op.kind == "garage door" and op.level != 0:
			warnings.append("A garage door on wall %d is on floor %d: they go on the ground floor." % [n, op.level])
		if op.level == 0 and PorchBuilder.on_wall(building, n) and building.floor_top(0) + op.top > PorchBuilder.roof_y(building) - KitBuilding.PORCH_ROOF:
			warnings.append("A %s on wall %d comes up higher than the porch roof in front of it (%.1f m above the floor at most)." % [op.kind, n, PorchBuilder.roof_y(building) - KitBuilding.PORCH_ROOF - building.floor_top(0)])
	for i in building.inner_walls.size():
		var inner := building.inner_walls[i]
		if inner == null:
			continue
		if inner.level >= building.floors or inner.level < building.bottom_level():
			warnings.append("Inner wall %d is on floor %d, but the building has %d floor(s)%s." % [i + 1, inner.level, building.floors, "" if building.basement else " and no basement"])
		if not building.contains_local(inner.start.lerp(inner.end, 0.5)):
			warnings.append("Inner wall %d is outside the building." % (i + 1))
		var length := inner.start.distance_to(inner.end)
		for op in inner.openings:
			if op == null:
				continue
			if absf(op.offset) + op.width / 2.0 > length / 2.0 or op.top > KitBuilding.STOREY - 0.25 or op.bottom < 0.0:
				warnings.append("An opening in inner wall %d doesn't fit in the wall." % (i + 1))
			if op.kind != "window" and op.width < KitBuilding.MIN_PASSAGE - 0.01:
				warnings.append("A %s in inner wall %d is under %.1f m wide: zombies can't find their way through it." % [op.kind, i + 1, KitBuilding.MIN_PASSAGE])
			if op.kind == "garage door":
				warnings.append("Inner wall %d has a garage door: they only go in outside walls (it's left as a doorway)." % (i + 1))
	for room in building.rooms:
		if room and not building.contains_local(room.point):
			warnings.append("A room's point (floor %d) is outside the building." % room.level)
		elif room and room.level < building.bottom_level():
			warnings.append("A room is on floor -1, but the building has no Basement.")
	for i in building.cellar_doors.size():
		var cellar := building.cellar_doors[i]
		if cellar == null:
			continue
		if not building.basement:
			warnings.append("Cellar door %d: the building has no Basement for it to go down to." % (i + 1))
		elif cellar.wall >= building.edge_count():
			warnings.append("Cellar door %d is on wall %d, but the building has %d walls." % [i + 1, cellar.wall, building.edge_count()])
		else:
			var ends := building.edge_ends(cellar.wall)
			if absf(cellar.offset) + KitBuilding.CELLAR_WIDE / 2.0 > ends[0].distance_to(ends[1]) / 2.0 - KitBuilding.WALL:
				warnings.append("Cellar door %d doesn't fit along wall %d." % [i + 1, cellar.wall])
	for i in building.porches.size():
		var porch := building.porches[i]
		if porch == null:
			continue
		var walls := Array(porch.walls)
		if walls.is_empty() or walls.any(func(n: int) -> bool: return n < 0 or n >= building.edge_count()):
			warnings.append("Porch %d is on a wall the building doesn't have (it has %d)." % [i + 1, building.edge_count()])
			continue
		for k in range(1, walls.size()):
			if walls[k] != (walls[k - 1] + 1) % building.edge_count():
				warnings.append("Porch %d: its walls have to follow on round the building (%d then %d)." % [i + 1, walls[k - 1], walls[k]])
				break
		if porch.steps_wall >= 0 and not porch.steps_wall in walls:
			warnings.append("Porch %d's steps are on wall %d, which it isn't along." % [i + 1, porch.steps_wall])
		var headroom := PorchBuilder.roof_y(building) - (porch.depth + KitBuilding.PORCH_EAVE) * tan(deg_to_rad(KitBuilding.PORCH_PITCH)) - KitBuilding.PORCH_ROOF - building.floor_top(0)
		if porch.kind != "Open" and headroom < 2.0:
			warnings.append("Porch %d's roof is only %.1f m above its deck at the edge: make it less deep, or lower Floor Y." % [i + 1, headroom])
	return warnings
