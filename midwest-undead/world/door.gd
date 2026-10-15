@tool
extends AnimatableBody3D
## A door you can open and close by looking at it and pressing interact.
## Zombies that walk into a closed one on their way somewhere bash it; enough
## blows and it bursts open for good. Unbreakable ones (the police compound
## gate) just hold.
##
## In the map scene a building's door sits under the building, but main.gd
## moves every door out of nav_region when the game starts, so the navigation
## bake ignores them: zombie paths run straight through doorways, and a closed door is
## something they run into and break down. The compound gate is the exception:
## main.gd bakes a stand-in wall where it is, and the gate switches on
## NavigationLinks across the gap only while it's open.
##
## The body sits on the pivot (the hinge, for a swinging door). Opening turns it
## by open_yaw and moves it by open_shift, both in its closed frame, so the same
## script does swinging doors and sliding gate leaves.

const Sound := preload("res://core/sound.gd")
const ViewDistance := preload("res://core/view_distance.gd")
const VIEW_METERS := 90.0 # past this the door isn't drawn (core/view_distance.gd)

const OPEN_TIME := 0.6
const BASH_WOBBLE := 0.04 # meters the leaf jumps per blow
const BASH_INTERVAL := 0.6 # seconds between visible blows, however many zombies are at it
const BODY_CLEARANCE := 0.45 # zombie / player radius plus a little, for clear_path_when_closing

@export var label := "door"
@export var breakable := true
## Can be boarded up with planks (fortifications.gd). Off for the compound gate.
@export var boardable := true
## Planked shut when a new game starts (like the survivors' houses).
@export var boarded_at_start := false
## Standing open when a new game starts. Save the scene with the door shut: the
## node's transform is the closed position.
@export var start_open := false
## The panel's size, and where its middle is from the node (the hinge).
@export var leaf_size := Vector3(0.08, 2.4, 1.5)
@export var leaf_offset := Vector3(0.0, 1.2, 0.8)
@export var color := Color(0.36, 0.24, 0.14)
## Opening turns it this much (radians) about the hinge and slides it this far,
## both in its closed frame: a swinging door turns, a sliding gate leaf slides.
@export var open_yaw := PI / 2.0
@export var open_shift := Vector3.ZERO
## Other leaves of the same gate: they open and close together.
@export var linked: Array[Node] = []
## Zombie paths through the opening, enabled only while it's open.
@export var nav_links: Array[NavigationLink3D] = []
## The compound gate: while it closes, zombies (and you) standing where a leaf is
## about to be are moved out of its way, to whichever side of the gate line they're
## on (the outside if dead center). Without this the leaves slide through bodies
## and the physics engine pops them out on a random side, sometimes inside.
@export var clear_path_when_closing := false
var max_health := 150.0
var health := 150.0
var is_open := false
var is_broken := false
## Planks nailed over it (fortifications.gd): it can't be opened or bashed.
var boarded := false

var _closed := Transform3D.IDENTITY
var _amount := 0.0 # 0 = shut, 1 = open; tweened in between
var _closing := false
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _move_tween: Tween
var _bash_tween: Tween
var _next_bash_ms := 0


## For doors made in code: leaf_size and leaf_offset place the panel relative to
## the pivot; closed is the pivot's transform when shut, in the parent's space.
func setup(leaf: Vector3, offset: Vector3, leaf_color: Color, closed: Transform3D,
		yaw: float, shift := Vector3.ZERO) -> void:
	leaf_size = leaf
	leaf_offset = offset
	color = leaf_color
	open_yaw = yaw
	open_shift = shift
	transform = closed
	_build()


## Doors in the map scene come with their panel and collision already (made by
## _build when the town was frozen); ones made in code get them from setup().
func _ready() -> void:
	_closed = transform
	if _mesh == null:
		for child in get_children():
			if child is MeshInstance3D:
				_mesh = child
				break
		if _mesh == null:
			_build()
		else:
			# Shared with the other doors of its color until this one takes a
			# beating (_tint). The map scene saved a copy with each door: swap
			# in the shared one.
			_material = _shared(_mesh.mesh.surface_get_material(0) as StandardMaterial3D)
			_mesh.set_surface_override_material(0, _material)
	_base_color = _material.albedo_color
	ViewDistance.limit(_mesh, VIEW_METERS)
	if start_open and not Engine.is_editor_hint(): # the editor shows it shut
		set_open(true, false)


func _build() -> void:
	if not _colors.has(color):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		_colors[color] = made
	_material = _colors[color] # shared until it takes a beating (_tint)
	var box := BoxMesh.new()
	box.size = leaf_size
	box.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.name = "Panel"
	_mesh.mesh = box
	_mesh.position = leaf_offset
	add_child(_mesh)

	var shape := BoxShape3D.new()
	shape.size = leaf_size
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	col.position = leaf_offset
	add_child(col)


## Where it is when shut, in the world (fortifications.gd boards it there).
func closed_transform() -> Transform3D:
	var parent := get_parent() as Node3D
	return parent.global_transform * _closed if parent else _closed


func interact_prompt() -> String:
	if is_broken or boarded:
		return ""
	return ("close the %s" if is_open else "open the %s") % label


## The player pressed interact on it.
func toggle() -> void:
	if is_broken or boarded:
		return
	set_open(not is_open)
	if label == "gate":
		Sound.play_at(self, "gate_slide", global_position, 0.0, 30.0, 0.05)
	else:
		Sound.play_at(self, "door_open" if is_open else "door_close", global_position, -4.0, 20.0)


func set_open(value: bool, animate := true) -> void:
	for door in [self] + linked:
		door._set_open_one(value, animate)


func can_be_bashed() -> bool:
	return breakable and not is_open and not is_broken and not boarded


## Called every physics frame by each zombie pushing against it.
func bash(damage: float) -> void:
	if not can_be_bashed():
		return
	health -= damage
	if health <= 0.0:
		_burst()
		return
	# Splinter and darken as it takes a beating.
	_tint(_base_color.darkened(0.5 * (1.0 - health / max_health)))
	var now := Time.get_ticks_msec()
	if now < _next_bash_ms:
		return
	_next_bash_ms = now + int(BASH_INTERVAL * 1000.0)
	Sound.play_at(self, "door_bash", global_position + Vector3.UP, 0.0, 30.0, 0.12)
	if _bash_tween:
		_bash_tween.kill()
	_mesh.position = leaf_offset + Vector3(BASH_WOBBLE, 0.0, 0.0)
	_bash_tween = create_tween()
	_bash_tween.tween_property(_mesh, "position", leaf_offset, 0.15)


func save_state() -> Dictionary:
	return {"open": is_open, "health": health, "broken": is_broken}


func load_state(data: Dictionary) -> void:
	health = float(data.get("health", max_health))
	is_broken = bool(data.get("broken", false))
	_set_open_one(bool(data.get("open", is_open)) or is_broken, false)
	if is_broken:
		_tint(_base_color.darkened(0.6))
	elif health < max_health:
		_tint(_base_color.darkened(0.5 * (1.0 - health / max_health)))


## One material per door color, shared until a door takes a beating.
static var _colors := {}


static func _shared(mat: StandardMaterial3D) -> StandardMaterial3D:
	if not _colors.has(mat.albedo_color):
		_colors[mat.albedo_color] = mat
	return _colors[mat.albedo_color]


## Splintered and darkened as it takes a beating. The first time gives it its
## own material (until then it shares one with the other doors).
func _tint(c: Color) -> void:
	if _mesh.material_override == null:
		_material = _material.duplicate()
		_mesh.material_override = _material
	_material.albedo_color = c


## Smashed: it flies open and hangs off its hinges for good.
func _burst() -> void:
	health = 0.0
	is_broken = true
	_tint(_base_color.darkened(0.6))
	_mesh.position = leaf_offset
	_set_open_one(true, true, 0.15)
	Sound.play_at(self, "door_break", global_position + Vector3.UP, 2.0, 35.0, 0.08)


func _set_open_one(value: bool, animate: bool, duration := OPEN_TIME) -> void:
	if value == is_open and animate:
		return
	is_open = value
	_closing = not value
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
	transform = _closed * Transform3D(Basis(Vector3.UP, open_yaw * amount), open_shift * amount)
	if clear_path_when_closing and _closing and is_inside_tree():
		_clear_path()


## For sliding leaves (clear_path_when_closing): works in the closed leaf's frame,
## where the leaf runs along x and its thickness is z. Only the stretch the leaf
## currently covers is cleared, so bodies are nudged as the leaf edge reaches them.
func _clear_path() -> void:
	var shift := open_shift * _amount
	var half := leaf_size / 2.0
	var x_min := leaf_offset.x + shift.x - half.x - BODY_CLEARANCE
	var x_max := leaf_offset.x + shift.x + half.x + BODY_CLEARANCE
	var depth := half.z + BODY_CLEARANCE
	var closed := closed_transform()
	var to_local := closed.affine_inverse()
	for body: Node3D in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player"):
		var local := to_local * body.global_position
		var off := local.z - leaf_offset.z
		if local.x < x_min or local.x > x_max or absf(off) >= depth:
			continue
		# -z is the outside for the compound gate; a tie goes there too.
		local.z = leaf_offset.z + (1.0 if off > 0.0 else -1.0) * depth
		body.global_position = closed * local
