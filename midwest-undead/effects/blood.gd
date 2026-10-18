extends RefCounted
## Blood: a spray where a hit lands, splatter on the ground and walls, and
## marks on bodies. Plain functions; zombie.gd calls them.
##
## Splatter (decals: images projected onto whatever's under them) is kept to
## MAX_SPLATS on the whole map: past that the oldest fades away. It doesn't
## land on bodies (they're on HumanoidBody.BODY_LAYER); body marks land only on
## bodies. The images are effects/blood/splat_*.png (make_blood.gd makes them;
## replace them with your own art if you like).

const SPLATS: Array[Texture2D] = [
	preload("res://effects/blood/splat_1.png"),
	preload("res://effects/blood/splat_2.png"),
	preload("res://effects/blood/splat_3.png"),
]
const BODY_LAYER := 1 << 19 # HumanoidBody.BODY_LAYER (not preloaded: it preloads this)
const MAX_SPLATS := 200
const MAX_BODY_MARKS := 120 # on all bodies together
const SPLAT_REACH := 2.5 # meters past a hit that a wall or the ground gets splattered
const FADE_TIME := 1.5
const SPLAT_FADE_DISTANCE := 45.0 # splatter further than this from the camera isn't drawn

static var _splats: Array[Decal] = [] # oldest first
static var _marks: Array[Decal] = []
static var _spray_material: StandardMaterial3D
static var _spray_mesh: QuadMesh


## A hit at `at`, travelling along `dir`: a spray of drops, and splatter on a
## wall or the ground just past it. parent: where the splatter goes (the map).
static func hit(parent: Node, at: Vector3, dir: Vector3, exclude: Array[RID] = []) -> void:
	spray(parent, at, -dir.normalized() * 0.4 + dir.normalized() + Vector3.UP * 0.2)
	var space := parent.get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at, at + dir.normalized() * SPLAT_REACH, 1, exclude)
	var behind := space.intersect_ray(query)
	if not behind.is_empty():
		splat(parent, behind["position"], behind["normal"], randf_range(0.45, 0.8))
	# Some drips on the ground below, too.
	query = PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 2.5, 1, exclude)
	var below := space.intersect_ray(query)
	if not below.is_empty():
		splat(parent, below["position"] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)),
				below["normal"], randf_range(0.3, 0.55))


## A pool where a body lies.
static func pool(parent: Node, at: Vector3) -> void:
	var space := parent.get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 1.5, 1)
	var below := space.intersect_ray(query)
	if not below.is_empty():
		splat(parent, below["position"], below["normal"], randf_range(1.0, 1.4))


## One splatter decal on a surface (normal: which way it faces), size meters across.
static func splat(parent: Node, at: Vector3, normal: Vector3, size: float) -> Decal:
	var decal := _decal(size, 0.4)
	decal.cull_mask = 0xFFFFF & ~BODY_LAYER # everything but bodies
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = SPLAT_FADE_DISTANCE
	decal.distance_fade_length = 10.0
	parent.add_child(decal)
	_face(decal, at, normal)
	_splats.append(decal)
	_trim(_splats, MAX_SPLATS)
	return decal


## A blood mark on a body: a small decal under `attach` (it follows the bone),
## at a point on the body, facing out of it.
static func body_mark(attach: Node3D, at: Vector3, normal: Vector3) -> Decal:
	var decal := _decal(randf_range(0.14, 0.22), 0.15)
	decal.cull_mask = BODY_LAYER
	attach.add_child(decal)
	_face(decal, at, normal)
	_marks.append(decal)
	_trim(_marks, MAX_BODY_MARKS)
	return decal


## A burst of drops flying off along dir, gone in half a second.
static func spray(parent: Node, at: Vector3, dir: Vector3) -> void:
	if _spray_material == null:
		_spray_material = StandardMaterial3D.new()
		_spray_material.albedo_color = Color(0.35, 0.02, 0.02)
		_spray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spray_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spray_mesh = QuadMesh.new()
		_spray_mesh.size = Vector2(0.035, 0.035)
		_spray_mesh.material = _spray_material
	var drops := CPUParticles3D.new()
	drops.mesh = _spray_mesh
	drops.amount = 12
	drops.lifetime = 0.5
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	drops.spread = 30.0
	drops.initial_velocity_min = 1.5
	drops.initial_velocity_max = 3.5
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.4
	drops.local_coords = false
	parent.add_child(drops)
	drops.global_position = at
	drops.emitting = true
	drops.get_tree().create_timer(1.0).timeout.connect(drops.queue_free)


static func _decal(size: float, depth: float) -> Decal:
	var decal := Decal.new()
	decal.size = Vector3(size, depth, size)
	decal.texture_albedo = SPLATS[randi() % SPLATS.size()]
	decal.modulate = Color(1, 1, 1, randf_range(0.8, 1.0))
	decal.normal_fade = 0.3
	decal.upper_fade = 0.1
	decal.lower_fade = 0.3
	return decal


## Puts a decal at a point, projecting into the surface (its -Y down the normal),
## spun at random about it.
static func _face(decal: Decal, at: Vector3, normal: Vector3) -> void:
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var basis := Basis(side, up, side.cross(up)).orthonormalized()
	decal.global_transform = Transform3D(basis.rotated(up, randf() * TAU), at)


## Over the limit: the oldest fade out and go. Freed ones (their map or body
## went) just drop off the list.
static func _trim(list: Array[Decal], limit: int) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	while list.size() > limit:
		var oldest: Decal = list.pop_front()
		var fade := oldest.create_tween()
		fade.tween_property(oldest, "modulate:a", 0.0, FADE_TIME)
		fade.tween_callback(oldest.queue_free)
