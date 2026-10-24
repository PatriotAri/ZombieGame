extends SceneTree
## Mines phase 1, on its own (no map): the layout's cells, walls sealing it
## all round but at the entrances, frames, rails, carts, darkness, layers.
var f := 0
var fails := 0
var mine: KitMine

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	mine = KitMine.new()
	var a: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(0, 0, -8), Vector3i(6, 0, -8)]
	var t1 := MineTunnel.make(a, true)
	t1.carts = 2 # (no dead end: none)
	t1.entrance_at_start = true
	var b: Array[Vector3i] = [Vector3i(10, 0, -8), Vector3i(16, 0, -8)]
	var t2 := MineTunnel.make(b)
	t2.entrance_at_end = true
	var c: Array[Vector3i] = [Vector3i(11, 1, -7), Vector3i(14, 1, -7)] # a ledge into the chamber, one level up
	var t3 := MineTunnel.make(c, true)
	t3.carts = 2 # at its dead end
	var r: Array[Vector3i] = [Vector3i(20, 0, 0), Vector3i(20, 0, -2), Vector3i(20, -1, -6), Vector3i(20, -1, -9)] # a ramp down a level
	var t4 := MineTunnel.make(r)
	# A ladder shaft from level 0 down to -2, with tunnels in at each level; an open shaft to the surface.
	var u0: Array[Vector3i] = [Vector3i(24, 0, 0), Vector3i(24, 0, -3)]
	var u1: Array[Vector3i] = [Vector3i(25, -1, -4), Vector3i(28, -1, -4)]
	var u2: Array[Vector3i] = [Vector3i(24, -2, -5), Vector3i(24, -2, -8)]
	var o1: Array[Vector3i] = [Vector3i(31, -1, -4), Vector3i(33, -1, -4)]
	mine.tunnels = [t1, t2, t3, t4, MineTunnel.make(u0), MineTunnel.make(u1), MineTunnel.make(u2), MineTunnel.make(o1)]
	var open := MineShaft.make(Vector2i(30, -4), -1, 0, MineShaft.Kind.OPEN)
	open.to_surface = true
	open.surface_height = 8.0
	mine.shafts = [MineShaft.make(Vector2i(24, -4), 0, -2), open]
	mine.chambers = [MineChamber.make(Vector3i(6, 0, -10), Vector3i(10, 0, -6), 6.0)]
	mine.position = Vector3(5, 20, 7)
	mine.rotation.y = 0.4
	root.add_child(mine)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	return mine.get_world_3d().direct_space_state.intersect_ray(q)

func _physics_process(_d: float) -> bool:
	f += 1
	if f < 3:
		return false
	check(mine.is_open(Vector3i(0, 0, -4)) and mine.is_open(Vector3i(8, 0, -8)) and not mine.is_open(Vector3i(3, 0, -4)), "cells: tunnel and chamber open, rock between closed")
	check(is_equal_approx(mine.lowest_floor(), 20.0 - 2.0 * KitMine.LEVEL - KitMine.THICK), "lowest floor %.2f" % mine.lowest_floor())
	# The ramp: its floor steps down evenly from level 0 to level -1 over 3 cells.
	var heights := []
	var expect := [0.0, -0.67, -2.0, -3.33, -4.0]
	for z in range(-2, -7, -1):
		var top := mine.to_global(KitMine.cell_position(Vector3i(20, 0, z)) + Vector3(0.2, expect[-2 - z] + 1.5, 0))
		var hit := ray(top, top + Vector3.DOWN * 8.0)
		heights.append(snappedf(hit.position.y - 20.0, 0.01) if not hit.is_empty() else 99.0)
	check(heights == expect, "ramp floor down a level at the cells' middles %s" % str(heights))
	var slope_hit := ray(mine.to_global(KitMine.cell_position(Vector3i(20, 0, -4)) + Vector3(0, 0.5, 0)), mine.to_global(KitMine.cell_position(Vector3i(20, 0, -4)) + Vector3(0, -6, 0)))
	check(not slope_hit.is_empty() and rad_to_deg(slope_hit.normal.angle_to(Vector3.UP)) < 30.0, "its slope walkable (%.0f deg)" % (rad_to_deg(slope_hit.normal.angle_to(Vector3.UP)) if not slope_hit.is_empty() else -1.0))
	var head := mine.to_global(KitMine.cell_position(Vector3i(20, 0, -4)) + Vector3(0, -2.0, 0))
	var head_hit := ray(head, head + Vector3.UP * 6.0)
	check(not head_hit.is_empty() and absf(head_hit.position.y - 20.0 - (-2.0 + KitMine.TUNNEL_HEIGHT)) < 0.05, "3 m headroom over the ramp (%.2f)" % (head_hit.position.y - head.y + 2.0 - 2.0 if not head_hit.is_empty() else -1.0))
	# Sealed: from inside every open cell, every way out hits rock within a few meters,
	# but out of each entrance's mouth.
	var leaks := []
	var dirs := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN,
			Vector3(1, 0.3, 1).normalized(), Vector3(-1, 0.6, 1).normalized(), Vector3(1, -0.4, -1).normalized()]
	mine._collect()
	for cell: Vector3i in mine._cells:
		for d: Vector3 in dirs:
			for h: float in [0.3, 1.5, 2.8]:
				var base := KitMine.cell_position(cell)
				base.y = mine._cells[cell]["floor"] + mine._cells[cell]["rise"] / 2.0
				var from := mine.to_global(base + Vector3(0.5, h, -0.3))
				var hit := ray(from, from + mine.global_basis * d * 60.0)
				if hit.is_empty():
					leaks.append([cell, d, h, mine.to_local(from)])
	# (Out through a mouth is fine: the ray passes through the mouth cell.)
	var mouth_leaks := leaks.filter(func(l: Array) -> bool:
		for k in 240: # (up the surface shaft and out)
			var q: Vector3 = l[3] + (l[1] as Vector3) * k * 0.25
			if absf(q.x - 75.0) <= 1.25 and absf(q.z + 10.0) <= 1.25 and q.y > 3.0:
				return true
		for mouth: Vector3i in [Vector3i(0, 0, 0), Vector3i(16, 0, -8)]:
			var mc := KitMine.cell_position(mouth)
			for k in 240:
				var p: Vector3 = l[3] + (l[1] as Vector3) * k * 0.25
				if absf(p.x - mc.x) <= 1.25 and absf(p.z - mc.z) <= 1.25 and p.y > mc.y and p.y < mc.y + 3.0:
					return true
		return false)
	check(leaks.size() == mouth_leaks.size(), "no way out but the mouths (%d leaks elsewhere: %s)" % [leaks.size() - mouth_leaks.size(), str(leaks.filter(func(l): return not l in mouth_leaks).slice(0, 6))])
	# Out of the mouths, straight ahead.
	var m1 := mine.to_global(KitMine.cell_position(Vector3i(0, 0, 0)) + Vector3(0, 1.5, 0))
	check(ray(m1, m1 + mine.global_basis * Vector3.BACK * 30.0).is_empty(), "entrance 1 opens out (+Z)")
	var m2 := mine.to_global(KitMine.cell_position(Vector3i(16, 0, -8)) + Vector3(0, 1.5, 0))
	check(ray(m2, m2 + mine.global_basis * Vector3.RIGHT * 30.0).is_empty(), "entrance 2 opens out (+X)")
	# Walkable floor where it's open; headroom in a tunnel; the ledge over the chamber.
	var fl := mine.to_global(KitMine.cell_position(Vector3i(0, 0, -5)) + Vector3(0.3, 1.0, 0))
	var down := ray(fl, fl + Vector3.DOWN * 3.0)
	check(not down.is_empty() and absf(down.position.y - 20.0) < 0.05, "tunnel floor at the level (%.2f)" % (down.position.y if not down.is_empty() else -1.0))
	var ch := mine.to_global(KitMine.cell_position(Vector3i(8, 0, -8)) + Vector3(0, 0.5, 0))
	var up := ray(ch, ch + Vector3.UP * 10.0)
	check(not up.is_empty() and absf(up.position.y - 26.0) < 0.05, "chamber ceiling 6 m up (%.2f)" % (up.position.y - 20.0 if not up.is_empty() else -1.0))
	var ledge := mine.to_global(KitMine.cell_position(Vector3i(11, 1, -7)) + Vector3(0, 1.0, 0))
	var into := ray(ledge, ledge + mine.global_basis * Vector3.LEFT * 2.5)
	check(into.is_empty(), "the upper tunnel opens over the chamber (a ledge)")
	var header := ray(ch + Vector3(0, 5.0, 0), ch + Vector3(0, 5.0, 0) + mine.global_basis * Vector3.RIGHT * 10.0)
	check(not header.is_empty(), "rock over where tunnel 2 meets the chamber (its header)")
	# The ladder shaft: landings on levels -1 and 0, the half by the ladder open to the bottom.
	var shaft_c := KitMine.cell_position(Vector3i(24, 0, -4))
	var landing_hits := []
	var open_hits := []
	for lv: int in [0, -1]:
		for half: float in [-1.0, 1.0]:
			var probe_at := mine.to_global(shaft_c + Vector3(half * 0.6, lv * KitMine.LEVEL + 1.0, 0.6 * half * 0.0))
			var hd := ray(probe_at, probe_at + Vector3.DOWN * 12.0)
			(landing_hits if not hd.is_empty() and absf(hd.position.y - 20.0 - lv * KitMine.LEVEL) < 0.05 else open_hits).append([lv, half])
	check(landing_hits.size() == 2 and open_hits.size() == 2 and landing_hits[0][1] == landing_hits[1][1], "ladder shaft: landings on one half, the other open (%s / %s)" % [str(landing_hits), str(open_hits)])
	var climb: Array = mine.get_children(true).filter(func(n: Node) -> bool: return n is Area3D and n.name.begins_with("Climb"))
	check(climb.size() == 1, "one climbing area up the ladder")
	if climb.size() == 1:
		var lands: Array = climb[0].get_meta("landings", [])
		check(lands.size() == 1 and is_equal_approx(lands[0], 16.0) and is_equal_approx(climb[0].get_meta("top_y"), 20.3),
				"steps off at level -1 on the way, and at the top on level 0 (%s, top %.2f)" % [str(lands), climb[0].get_meta("top_y")])
	var bottom := mine.to_global(shaft_c + Vector3(0, -2 * KitMine.LEVEL + 1.0, 0))
	var bh := ray(bottom, bottom + Vector3.DOWN * 3.0)
	check(not bh.is_empty() and absf(bh.position.y - 12.0) < 0.05, "a floor at the bottom")
	# The surface shaft: open to the sky, dark only below its top level.
	var sky := mine.to_global(KitMine.cell_position(Vector3i(30, 0, -4)) + Vector3(0, 2.0, 0.8)) # (beside the headframe's beam)
	check(ray(sky, sky + Vector3.UP * 30.0).is_empty(), "the surface shaft is open to the sky")
	# Timber posts narrow a tunnel to about 2 m at a frame.
	var post_found := false
	for i in range(1, 8):
		var p := mine.to_global(KitMine.cell_position(Vector3i(0, 0, -i)) + Vector3(0, 1.5, 0))
		var side := ray(p, p + mine.global_basis * Vector3.LEFT * 2.0)
		if not side.is_empty() and p.distance_to(side.position) < 1.05:
			post_found = true
	check(post_found, "timber frames along tunnel 1")
	# Carts, on the rails.
	var carts := mine.get_children(true).filter(func(n: Node) -> bool: return n.name.begins_with("Cart"))
	check(carts.size() == 2, "two carts (%d)" % carts.size())
	var tips := carts.map(func(c: Node3D) -> Vector3i: return KitMine.cell_at(c.position, 1))
	check(Vector3i(14, 1, -7) in tips and Vector3i(13, 1, -7) in tips, "at the dead end of the rails, one behind the other (%s)" % str(tips))
	# Darkness: probes over the mine, but not over the mouth's daylight cells.
	var probes := mine.get_children(true).filter(func(n: Node) -> bool: return n is ReflectionProbe)
	var covers := func(local: Vector3) -> bool:
		for p: ReflectionProbe in probes:
			if AABB(p.position - p.size / 2.0, p.size).has_point(local):
				return true
		return false
	check(probes.size() > 0 and probes.size() < 20, "%d darkness probes" % probes.size())
	check(not covers.call(KitMine.cell_position(Vector3i(0, 0, 0)) + Vector3(0, 1.5, 0)), "the mouth is in daylight")
	var dark_everywhere := true
	for cell: Vector3i in mine._cells:
		if mine._lit.has(Vector2i(cell.x, cell.z)):
			continue
		var mid := KitMine.cell_position(cell)
		mid.y = mine._cells[cell]["floor"] + mine._cells[cell]["rise"] / 2.0
		if not covers.call(mid + Vector3(0, 1.5, 0)):
			dark_everywhere = false
			print("    not dark: ", cell)
	check(dark_everywhere, "dark everywhere else")
	# Underground layer, carts' looks too.
	var wrong := 0
	var total := 0
	for g in mine.find_children("*", "GeometryInstance3D", true, false):
		if g.name == "Portals":
			continue
		total += 1
		if (g as GeometryInstance3D).layers != 2:
			wrong += 1
	check(total > 1 and wrong == 0, "all %d meshes on the underground layer (%d not)" % [total, wrong])
	print("FAILS: %d" % fails)
	quit()
	return true
