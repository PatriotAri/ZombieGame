extends Node
## Who hears a noise: only the listeners (zombies, bandits: the
## "noise_listeners" group, each with hear_noise(pos, radius)) near enough to,
## found on a grid of CELL meter squares instead of asking every one of them.
## Each listener still checks the distance itself.
## Anything that makes a noise calls Hearing.make_noise(); main.gd makes the
## game's one. Without one (another scene, a test), every listener is asked.

const GROUP := &"hearing"
const LISTENERS := &"noise_listeners"
const CELL := 32.0 # meters
## How old the grid can get before a noise has it made again. Listeners move a
## little meanwhile (a running zombie about 2 m): SLACK covers that.
const MAX_AGE_MS := 250
const SLACK := 4.0
## Louder than this reaches more than the grid is worth: everyone's asked.
const WIDE := 300.0

var _cells := {} # Vector2i -> Array[Node3D]
var _built_ms := -MAX_AGE_MS


## A noise at pos that carries radius meters.
static func make_noise(context: Node, pos: Vector3, radius: float) -> void:
	var tree := context.get_tree()
	var hearing := tree.get_first_node_in_group(GROUP)
	if hearing == null or radius > WIDE:
		tree.call_group(LISTENERS, "hear_noise", pos, radius)
	else:
		hearing.noise(pos, radius)


func _ready() -> void:
	add_to_group(GROUP)


func noise(pos: Vector3, radius: float) -> void:
	if Time.get_ticks_msec() - _built_ms >= MAX_AGE_MS:
		_build()
	var reach := radius + SLACK
	var low := _cell_of(pos - Vector3(reach, 0, reach))
	var high := _cell_of(pos + Vector3(reach, 0, reach))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for listener: Node3D in _cells.get(Vector2i(x, y), []):
				if is_instance_valid(listener) and listener.is_inside_tree():
					listener.call("hear_noise", pos, radius)


func _build() -> void:
	_cells.clear()
	for node in get_tree().get_nodes_in_group(LISTENERS):
		var listener := node as Node3D
		if listener == null:
			continue
		var cell := _cell_of(listener.global_position)
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(listener)
	_built_ms = Time.get_ticks_msec()


static func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
