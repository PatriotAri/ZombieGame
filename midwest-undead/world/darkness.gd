extends RefCounted
## A reflection probe that stands in for the sky's light where it can't reach:
## inside it, the ambient light is `color` (near black) instead of the sky's.
## Basements (building.gd) and mines (world/map/kit_mine.gd) make theirs here.
## Never instanced.


## A probe `size` big at `position`, its edges fading out over `blend` meters.
## Add it to the tree yourself.
static func probe(size: Vector3, position: Vector3, color: Color, blend: float) -> ReflectionProbe:
	var dark := ReflectionProbe.new()
	dark.size = size
	dark.position = position
	dark.interior = true
	dark.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	dark.ambient_color = color
	dark.ambient_color_energy = 1.0
	dark.blend_distance = blend
	dark.intensity = 0.2
	return dark
