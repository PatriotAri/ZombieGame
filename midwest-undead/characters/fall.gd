extends RefCounted
## Falling hurts: nothing from a fall of up to SAFE meters, then more the
## further you fall, until DEADLY kills you outright. Measured by how fast
## you're falling when you land (a free fall of h meters lands at
## sqrt(2 g h)), so riding a cage down or being moved somewhere doesn't count.
## The player and zombies each keep one of these and call update() every
## physics frame, after moving. Landing in water, or holding on to a ladder,
## breaks the fall.

const SAFE := 4.0
const DEADLY := 12.0

var _speed := 0.0 # the fastest it's fallen since it left the ground (m/s)


## How much of max_health this frame's landing costs (0 for most frames).
## gravity: the body's own (m/s²). safe: on a ladder, swimming...
func update(body: CharacterBody3D, max_health: float, gravity: float, safe := false) -> float:
	if safe:
		_speed = 0.0
		return 0.0
	if not body.is_on_floor():
		_speed = maxf(_speed, -body.velocity.y)
		return 0.0
	var speed := _speed
	_speed = 0.0
	return damage(speed * speed / (2.0 * gravity), max_health)


## What a fall of `drop` meters costs.
static func damage(drop: float, max_health: float) -> float:
	if drop <= SAFE:
		return 0.0
	return max_health * clampf((drop - SAFE) / (DEADLY - SAFE), 0.0, 1.0)
