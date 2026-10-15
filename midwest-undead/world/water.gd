extends RefCounted
## Where the water is, for everyone who needs to know: the player (wading and
## swimming), zombies (slowed, and drowning in deep water) and anything else.
## Every pond and creek on the map (world/map/pond.gd, world/map/creek.gd) puts
## itself in the "water" group and answers surface_at(pos): the height of its
## water surface above that point, or NAN if it doesn't cover it. Never
## instanced.
##
##   shallow  (WADE_DEPTH to SWIM_DEPTH deep): you wade, slowly; zombies slower
##   deep     (SWIM_DEPTH or more): you swim (no guns); zombies sink and drown

const WADE_DEPTH := 0.25 # meters of water at your feet before it slows you
const SWIM_DEPTH := 1.3 # this deep and you're swimming (chest-deep)


## The water surface over pos (the highest, where two overlap), or NAN where
## there's no water.
static func surface_at(tree: SceneTree, pos: Vector3) -> float:
	var best := NAN
	for body in tree.get_nodes_in_group("water"):
		var s: float = body.call("surface_at", pos)
		if not is_nan(s) and (is_nan(best) or s > best):
			best = s
	return best


## How deep the water is at a point (its surface minus the point's height), 0
## where it's dry or the point is above the surface.
static func depth_at(tree: SceneTree, pos: Vector3) -> float:
	var s := surface_at(tree, pos)
	return 0.0 if is_nan(s) else maxf(s - pos.y, 0.0)
