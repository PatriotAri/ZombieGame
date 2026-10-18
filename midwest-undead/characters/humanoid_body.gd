extends Node3D
## A character's body: its model (a real one, or the mannequin stand-in), its
## animations, ragdoll, blood marks and colors. zombie.gd puts one in each
## zombie and person (characters/npcs/human_npc.gd) and says what it's doing;
## this does the showing.
##
## The model: any character scene with a humanoid skeleton named like Godot's
## humanoid profile (Hips, Spine, Chest, Head, LeftUpperArm...), the way the
## importer leaves a model imported with the Humanoid bone map. With none it's
## the mannequin (characters/mannequin/). See HOW_TO_MODEL.md.
##
## Animations: by name (zombies: idle, walk, run, attack, bash, hit_head,
## hit_body, hit_legs, climb; crawl_idle, crawl, crawl_attack, crawl_hit for
## crawlers. People: see human_npc.gd). The model's own are used when it has
## them; for any it hasn't, the mannequin's (zombies' or people's, as setup()
## is told). aim_pitch tips the spine up or down on top (aiming at something). Distance matters: up close they move every frame, further away
## or out of sight less often (nobody can tell, and it saves a lot with a horde):
##   under NEAR_DISTANCE: every frame; under MID_DISTANCE: every MID_EVERY
##   frames; beyond, or off screen: every FAR_EVERY frames.
##
## Ragdoll: when it dies its limbs go limp and fall by physics (physical bones,
## made for the bones in RAGDOLL), pushed by the blow that killed it. Once it's
## stopped moving (or after RAGDOLL_TIME) it's frozen in the pose it landed in
## and the physics bodies go: a body on the ground costs nothing after that.
## At most MAX_RAGDOLLS fall at once; more, and the oldest freezes early.
##
## Blood marks on the body (wound()) stick to the bone they landed on; the
## splatter on the ground and walls is effects/blood.gd.

signal settled # the ragdoll has come to rest (frozen)

const Blood := preload("res://effects/blood.gd")
const MANNEQUIN := preload("res://characters/mannequin/mannequin.tscn")
const MANNEQUIN_ANIMATIONS := preload("res://characters/mannequin/mannequin_animations.tres")
const PEOPLE_ANIMATIONS := preload("res://characters/mannequin/people_animations.tres")
const BODY_SHADER := preload("res://characters/mannequin/body.gdshader")
const FALLBACK_LIBRARY := "mannequin"

## Visual layer 20 is for bodies only: blood marks on bodies project onto it and
## nothing else, and the splatter on the ground skips it (effects/blood.gd).
const BODY_LAYER := 1 << 19
const RAGDOLL_COLLISION_LAYER := 256 # physics layer 9: falling bodies (collide with the world only)

const NEAR_DISTANCE := 25.0
const MID_DISTANCE := 60.0
const MID_EVERY := 3
const FAR_EVERY := 8

## bone -> [the bone its length runs to ("" = HEAD_LENGTH up), radius, mass kg,
## swing degrees, twist degrees]. Bones not here (spine, neck, hands, feet) ride
## along with the nearest one that is.
const RAGDOLL := {
	"Hips": ["Spine", 0.14, 12.0, 0.0, 0.0],
	"Chest": ["Neck", 0.15, 10.0, 25.0, 15.0],
	"Head": ["", 0.11, 4.0, 40.0, 30.0],
	"LeftUpperArm": ["LeftLowerArm", 0.055, 2.5, 80.0, 30.0],
	"LeftLowerArm": ["LeftHand", 0.045, 1.5, 70.0, 10.0],
	"RightUpperArm": ["RightLowerArm", 0.055, 2.5, 80.0, 30.0],
	"RightLowerArm": ["RightHand", 0.045, 1.5, 70.0, 10.0],
	"LeftUpperLeg": ["LeftLowerLeg", 0.075, 7.0, 50.0, 15.0],
	"LeftLowerLeg": ["LeftFoot", 0.06, 4.0, 60.0, 5.0],
	"RightUpperLeg": ["RightLowerLeg", 0.075, 7.0, 50.0, 15.0],
	"RightLowerLeg": ["RightFoot", 0.06, 4.0, 60.0, 5.0],
}
const HEAD_LENGTH := 0.22
const HEAD_CENTER := Vector3(0, 0.1, 0) # from the Head bone (its own space) to the middle of the head
const RAGDOLL_TIME := 6.0 # seconds at most before it's frozen
const SETTLE_SPEED := 0.2 # m/s: slower than this (every bone) counts as still
const MAX_RAGDOLLS := 12
const MAX_WOUNDS := 5 # blood marks on one body; more replace the oldest

## Which bones count as the head and the legs (for flinches); the rest is body.
const HEAD_BONES := ["Head", "Neck"]
const LEG_BONES := ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]

static var _falling: Array = [] # bodies ragdolling right now, oldest first

var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
## A CollisionShape3D to keep on the head (the owner's headshot hitbox), or null.
var head_shape: CollisionShape3D
var current := "" # the looping animation playing
## Radians, up positive: the spine tips this far on top of the animation.
var aim_pitch := 0.0
var is_ragdoll := false
var is_settled := false # ragdoll frozen
var _one_shot_left := 0.0 # > 0: a one-off (flinch, climb) is playing; set_action waits
var _pending := 0.0 # time saved up since the last animation step
var _frame := 0
var _phase := 0
var _notifier: VisibleOnScreenNotifier3D
var _meshes: Array[MeshInstance3D] = []
var _tinted: Array[MeshInstance3D] = [] # the ones using the body shader
var _sim: PhysicalBoneSimulator3D
var _bones: Array[PhysicalBone3D] = []
var _ragdoll_time := 0.0
var _still_time := 0.0
var _wounds: Array[Node3D] = []
var _attachments := {} # bone index -> BoneAttachment3D
var _spine := -1
var _spine_unaimed := Quaternion.IDENTITY # its rotation before aim_pitch went on
var _aimed := false


## scene: the model (null: the mannequin). library: the mannequin's animations
## it borrows from (the zombies', or PEOPLE_ANIMATIONS).
func setup(scene: PackedScene, library: AnimationLibrary = MANNEQUIN_ANIMATIONS) -> void:
	model = (scene if scene else MANNEQUIN).instantiate()
	add_child(model)
	skeleton = model.get_node_or_null("%GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		skeleton = _find(model, "Skeleton3D") as Skeleton3D
	animator = _find(model, "AnimationPlayer") as AnimationPlayer
	if animator == null:
		animator = AnimationPlayer.new()
		model.add_child(animator)
	# The mannequin's animations for whatever the model hasn't got. The mannequin
	# comes with the zombies'; borrowing people's, those go.
	var has_them := false
	for name in animator.get_animation_library_list():
		var own := animator.get_animation_library(name)
		if own == MANNEQUIN_ANIMATIONS and library != MANNEQUIN_ANIMATIONS:
			animator.remove_animation_library(name)
		has_them = has_them or own == library
	if not has_them:
		animator.add_animation_library(FALLBACK_LIBRARY, library)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.layers = BODY_LAYER
		_meshes.append(mesh)
		var mat := mesh.material_override if mesh.material_override else \
				(mesh.mesh.surface_get_material(0) if mesh.mesh and mesh.mesh.get_surface_count() > 0 else null)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == BODY_SHADER:
			_tinted.append(mesh)
	_spine = skeleton.find_bone("Spine")
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.aabb = AABB(Vector3(-0.7, 0.0, -0.9), Vector3(1.4, 2.0, 1.8))
	add_child(_notifier)
	_phase = randi() % FAR_EVERY


static func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := _find(child, type)
		if found:
			return found
	return null


# --- Animation -------------------------------------------------------------------

## The animation to play for action: the model's own, the mannequin's, or "".
func animation_for(action: String) -> String:
	if animator.has_animation(action):
		return action
	var fallback := FALLBACK_LIBRARY + "/" + action
	return fallback if animator.has_animation(fallback) else ""


## Keeps a looping animation going (idle, walk...), at speed times its own pace.
## Waits while a one-off is playing.
func set_action(action: String, speed := 1.0, blend := 0.25) -> void:
	if is_ragdoll:
		return
	animator.speed_scale = speed
	if _one_shot_left > 0.0 or action == current:
		return
	var anim := animation_for(action)
	if anim == "":
		return
	current = action
	animator.play(anim, blend)


## Plays a one-off (a flinch, the climb) over whatever's looping; fit_time > 0
## stretches it to last that long. The looping animation picks up after.
func one_shot(action: String, fit_time := 0.0, blend := 0.06) -> void:
	if is_ragdoll:
		return
	var anim := animation_for(action)
	if anim == "":
		return
	var length := animator.get_animation(anim).length
	var speed := length / fit_time if fit_time > 0.0 and length > 0.0 else 1.0
	animator.speed_scale = 1.0
	animator.play(anim, blend, speed)
	_one_shot_left = length / speed
	current = ""


func is_busy() -> bool:
	return _one_shot_left > 0.0


func _process(delta: float) -> void:
	if is_ragdoll:
		if not is_settled:
			_update_ragdoll(delta)
		return
	if animator == null:
		return
	_one_shot_left = maxf(_one_shot_left - delta, 0.0)
	_pending += delta
	_frame += 1
	var every := _update_every()
	if every > 1 and (_frame + _phase) % every != 0:
		return
	if _aimed: # back to the animation's own, so the tip doesn't add up
		skeleton.set_bone_pose_rotation(_spine, _spine_unaimed)
		_aimed = false
	animator.advance(_pending)
	_pending = 0.0
	_aim()
	_place_head_shape()


## Tips the spine by aim_pitch (about the body's left-right axis), whatever its
## animation is doing.
func _aim() -> void:
	if is_zero_approx(aim_pitch) or _spine < 0:
		return
	_spine_unaimed = skeleton.get_bone_pose_rotation(_spine)
	var parent := skeleton.get_bone_parent(_spine)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var tipped := Basis(Vector3.RIGHT, -aim_pitch) * skeleton.get_bone_global_pose(_spine).basis
	skeleton.set_bone_pose_rotation(_spine, (parent_basis.inverse() * tipped).get_rotation_quaternion())
	_aimed = true


## How many frames between animation steps, by distance from the camera.
func _update_every() -> int:
	if not _notifier.is_on_screen():
		return FAR_EVERY
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1
	var dist_sq := global_position.distance_squared_to(camera.global_position)
	if dist_sq < NEAR_DISTANCE * NEAR_DISTANCE:
		return 1
	return MID_EVERY if dist_sq < MID_DISTANCE * MID_DISTANCE else FAR_EVERY


func on_screen() -> bool:
	return _notifier != null and _notifier.is_on_screen()


# --- Where things are ------------------------------------------------------------

## The middle of its head, in the world.
func head_center() -> Vector3:
	var head := skeleton.find_bone("Head")
	if head < 0:
		return global_position + global_basis.y * 1.65
	return skeleton.global_transform * skeleton.get_bone_global_pose(head) * HEAD_CENTER


func _place_head_shape() -> void:
	if head_shape:
		head_shape.global_position = head_center()


## The bone nearest a point in the world (its index), or -1.
func nearest_bone(at: Vector3) -> int:
	var local := skeleton.global_transform.affine_inverse() * at
	var best := -1
	var best_dist := INF
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) == "Root":
			continue # at the feet, and not part of the body
		var pose := skeleton.get_bone_global_pose(i)
		# The middle of the bone (to its first child), not its start.
		var mid := pose.origin
		var children := skeleton.get_bone_children(i)
		if not children.is_empty():
			mid = (mid + skeleton.get_bone_global_pose(children[0]).origin) / 2.0
		elif skeleton.get_bone_name(i) == "Head":
			mid = pose * HEAD_CENTER
		var dist := local.distance_squared_to(mid)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


## "head", "legs" or "body": which part a hit at this point landed on.
func zone_of(at: Vector3) -> String:
	var bone := nearest_bone(at)
	if bone < 0:
		return "body"
	var bone_name := skeleton.get_bone_name(bone)
	if bone_name in HEAD_BONES:
		return "head"
	return "legs" if bone_name in LEG_BONES else "body"


# --- Looks -----------------------------------------------------------------------

## Colors for the parts of the body (models using the body shader: the mannequin).
func set_colors(skin: Color, shirt: Color, pants: Color) -> void:
	for mesh in _tinted:
		mesh.set_instance_shader_parameter("skin", skin)
		mesh.set_instance_shader_parameter("shirt", shirt)
		mesh.set_instance_shader_parameter("pants", pants)


## 0-1: flashed pale red (just hit).
func set_flash(amount: float) -> void:
	for mesh in _tinted:
		mesh.set_instance_shader_parameter("flash", amount)


## A node that follows a bone (index) around: its animation, the ragdoll.
## Things added to it go with the bone (blood marks, a hat, a rifle in the hand).
func attachment(bone: int) -> BoneAttachment3D:
	if not _attachments.has(bone):
		var attach := BoneAttachment3D.new()
		attach.bone_idx = bone
		skeleton.add_child(attach)
		_attachments[bone] = attach
	return _attachments[bone]


## A blood mark where a hit landed, stuck to the nearest bone so it moves with it.
func wound(at: Vector3, normal: Vector3) -> void:
	var bone := nearest_bone(at)
	if bone < 0:
		return
	var mark := Blood.body_mark(attachment(bone), at, normal)
	if mark == null:
		return
	_wounds.append(mark)
	if _wounds.size() > MAX_WOUNDS:
		var oldest: Node3D = _wounds.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


# --- Ragdoll ---------------------------------------------------------------------

## Goes limp: the bones fall by physics. impulse pushes the bone nearest at
## (the blow that killed it); velocity is how it was moving.
func ragdoll(impulse: Vector3, at: Vector3, velocity: Vector3) -> void:
	if is_ragdoll:
		return
	is_ragdoll = true
	_one_shot_left = 0.0
	animator.pause()
	_build_ragdoll()
	if _bones.is_empty():
		_settle() # a model without the humanoid bones: it just stays as it is
		return
	_sim.physical_bones_start_simulation()
	var hit := _bones[0]
	var best := INF
	for bone in _bones:
		bone.linear_velocity = velocity
		var dist := bone.global_position.distance_squared_to(at)
		if dist < best:
			best = dist
			hit = bone
	hit.apply_impulse(impulse, at - hit.global_position)
	_falling.append(self)
	while _falling.size() > MAX_RAGDOLLS:
		var oldest = _falling.pop_front()
		if is_instance_valid(oldest) and oldest != self:
			oldest._settle()


## A physical bone for each bone in RAGDOLL the skeleton has, placed where the
## bone is now. Shapes and joints are set up like the editor's "Create Physical
## Skeleton" does: a capsule from the bone to the next, the joint at its start.
func _build_ragdoll() -> void:
	_sim = PhysicalBoneSimulator3D.new()
	skeleton.add_child(_sim)
	var to_world := skeleton.global_transform
	for bone_name: String in RAGDOLL:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var spec: Array = RAGDOLL[bone_name]
		var to_child := Vector3(0, HEAD_LENGTH, 0)
		var child := skeleton.find_bone(spec[0]) if spec[0] != "" else -1
		if child >= 0:
			to_child = skeleton.get_bone_global_rest(index).affine_inverse() * skeleton.get_bone_global_rest(child).origin
		var half := maxf(to_child.length() * 0.5, 0.02)
		var radius: float = minf(spec[1], half)
		var up := Vector3.UP if not Vector3.UP.cross(to_child).is_zero_approx() else Vector3.BACK
		var body_basis := Basis.looking_at(to_child, up)
		var bone := PhysicalBone3D.new()
		bone.name = "Physical_" + bone_name
		bone.bone_name = bone_name
		bone.body_offset = Transform3D(body_basis, body_basis * Vector3(0, 0, -half))
		# The joint at the bone's start; its X axis along the bone (the cone's axis).
		bone.joint_offset = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0, half))
		bone.mass = spec[2]
		bone.friction = 0.8
		bone.linear_damp = 0.1
		bone.angular_damp = 0.8
		bone.collision_layer = RAGDOLL_COLLISION_LAYER
		bone.collision_mask = 1 # the world
		if bone_name != "Hips":
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			bone.set("joint_constraints/swing_span", spec[3])
			bone.set("joint_constraints/twist_span", spec[4])
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(half * 2.0 + radius * 2.0 * 0.5, radius * 2.0 + 0.01)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO) # the capsule's length along -z
		bone.add_child(collider)
		_sim.add_child(bone)
		bone.global_transform = to_world * skeleton.get_bone_global_pose(index) * bone.body_offset
		_bones.append(bone)


func _update_ragdoll(delta: float) -> void:
	_ragdoll_time += delta
	var fastest := 0.0
	for bone in _bones:
		fastest = maxf(fastest, bone.linear_velocity.length())
	_still_time = _still_time + delta if fastest < SETTLE_SPEED else 0.0
	if _still_time > 0.5 or _ragdoll_time > RAGDOLL_TIME:
		_settle()


## Freezes it as it lies: the bones keep the pose physics left them in, and the
## physics bodies go.
func _settle() -> void:
	if is_settled:
		return
	is_settled = true
	_falling.erase(self)
	if _sim:
		var to_skeleton := skeleton.global_transform.affine_inverse()
		var landed := {} # bone index -> its pose (skeleton space), from its physics body
		for bone in _bones:
			var index := skeleton.find_bone(bone.bone_name)
			landed[index] = to_skeleton * bone.global_transform * bone.body_offset.affine_inverse()
		# Every bone's pose in skeleton space, parents first: the simulated ones
		# where they landed, the rest riding along with their parent.
		var global := {}
		for i in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(i)
			var parent_pose: Transform3D = global[parent] if parent >= 0 else Transform3D.IDENTITY
			var pose: Transform3D = landed[i] if landed.has(i) else parent_pose * skeleton.get_bone_pose(i)
			global[i] = pose
			if landed.has(i):
				var local := parent_pose.affine_inverse() * pose
				skeleton.set_bone_pose_position(i, local.origin)
				skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		_sim.physical_bones_stop_simulation()
		_sim.queue_free()
		_sim = null
		_bones.clear()
	settled.emit()


func _exit_tree() -> void:
	_falling.erase(self)
