extends AnimatableBody3D
## A door you can open and close by looking at it and pressing interact.
## Zombies that walk into a closed one on their way somewhere bash it; enough
## blows and it bursts open for good. Unbreakable ones (the police compound
## gate) just hold.
##
## Doors live outside main.gd's nav_region, so the navigation bake ignores
## them: zombie paths run straight through doorways, and a closed door is
## something they run into and break down. The compound gate is the exception:
## main.gd bakes a stand-in wall where it is, and the gate switches on
## NavigationLinks across the gap only while it's open.
##
## The body sits on the pivot (the hinge, for a swinging door). Opening turns it
## by open_yaw and moves it by open_shift, both in its closed frame, so the same
## script does swinging doors and sliding gate leaves.

const OPEN_TIME := 0.6
const BASH_WOBBLE := 0.04 # meters the leaf jumps per blow
const BASH_INTERVAL := 0.6 # seconds between visible blows, however many zombies are at it

var label := "door"
var max_health := 150.0
var health := 150.0
var breakable := true
var is_open := false
var is_broken := false
## Other leaves of the same gate: they open and close together.
var linked: Array = []
## Zombie paths through the opening, enabled only while it's open.
var nav_links: Array[NavigationLink3D] = []

var _closed := Transform3D.IDENTITY
var _open_yaw := 0.0
var _open_shift := Vector3.ZERO
var _amount := 0.0 # 0 = shut, 1 = open; tweened in between
var _leaf_offset := Vector3.ZERO
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _move_tween: Tween
var _bash_tween: Tween
var _next_bash_ms := 0


## leaf_size and leaf_offset place the panel relative to the pivot; closed is the
## pivot's transform when shut, in the parent's space.
func setup(leaf_size: Vector3, leaf_offset: Vector3, color: Color, closed: Transform3D,
		open_yaw: float, open_shift := Vector3.ZERO) -> void:
	_closed = closed
	_open_yaw = open_yaw
	_open_shift = open_shift
	_leaf_offset = leaf_offset
	transform = closed
	_base_color = color
	_material = StandardMaterial3D.new()
	_material.albedo_color = color

	var box := BoxMesh.new()
	box.size = leaf_size
	box.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.position = leaf_offset
	add_child(_mesh)

	var shape := BoxShape3D.new()
	shape.size = leaf_size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = leaf_offset
	add_child(col)


func interact_prompt() -> String:
	if is_broken:
		return ""
	return ("close the %s" if is_open else "open the %s") % label


## The player pressed interact on it.
func toggle() -> void:
	if not is_broken:
		set_open(not is_open)


func set_open(value: bool, animate := true) -> void:
	for door in [self] + linked:
		door._set_open_one(value, animate)


func can_be_bashed() -> bool:
	return breakable and not is_open and not is_broken


## Called every physics frame by each zombie pushing against it.
func bash(damage: float) -> void:
	if not can_be_bashed():
		return
	health -= damage
	if health <= 0.0:
		_burst()
		return
	# Splinter and darken as it takes a beating.
	_material.albedo_color = _base_color.darkened(0.5 * (1.0 - health / max_health))
	var now := Time.get_ticks_msec()
	if now < _next_bash_ms:
		return
	_next_bash_ms = now + int(BASH_INTERVAL * 1000.0)
	if _bash_tween:
		_bash_tween.kill()
	_mesh.position = _leaf_offset + Vector3(BASH_WOBBLE, 0.0, 0.0)
	_bash_tween = create_tween()
	_bash_tween.tween_property(_mesh, "position", _leaf_offset, 0.15)


func save_state() -> Dictionary:
	return {"open": is_open, "health": health, "broken": is_broken}


func load_state(data: Dictionary) -> void:
	health = float(data.get("health", max_health))
	is_broken = bool(data.get("broken", false))
	_set_open_one(bool(data.get("open", is_open)) or is_broken, false)
	if is_broken:
		_material.albedo_color = _base_color.darkened(0.6)
	elif health < max_health:
		_material.albedo_color = _base_color.darkened(0.5 * (1.0 - health / max_health))


## Smashed: it flies open and hangs off its hinges for good.
func _burst() -> void:
	health = 0.0
	is_broken = true
	_material.albedo_color = _base_color.darkened(0.6)
	_mesh.position = _leaf_offset
	_set_open_one(true, true, 0.15)


func _set_open_one(value: bool, animate: bool, duration := OPEN_TIME) -> void:
	if value == is_open and animate:
		return
	is_open = value
	for link in nav_links:
		link.enabled = value
	if _move_tween:
		_move_tween.kill()
	var goal := 1.0 if value else 0.0
	if not animate or not is_inside_tree():
		_apply_amount(goal)
		return
	# Physics-step tween: an AnimatableBody should move in step with physics so it
	# pushes whoever is in its way instead of jumping through them.
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_method(_apply_amount, _amount, goal, duration * absf(goal - _amount)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_amount(amount: float) -> void:
	_amount = amount
	transform = _closed * Transform3D(Basis(Vector3.UP, _open_yaw * amount), _open_shift * amount)
