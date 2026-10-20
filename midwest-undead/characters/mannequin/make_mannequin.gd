extends SceneTree
## Builds the stand-in character: a plain humanoid with a real skeleton, a
## skinned body and rough animations. It stands in for a real model until there
## is one (see HOW_TO_MODEL.md), and real models can borrow its animations.
##
## Run it from the project folder to rebuild the files after changing this:
##   godot --headless --path . -s res://characters/mannequin/make_mannequin.gd
## It writes, next to this script:
##   mannequin.tscn             the character (what zombie.gd uses with no model)
##   mannequin_body.res         its mesh
##   mannequin_animations.tres  its animations (an AnimationLibrary): the zombies'
##   people_animations.tres     people's animations (characters/npcs/human_npc.gd)
##
## It's built the way Godot's importer leaves a humanoid model after
## retargeting (a model imported with the Humanoid bone map): the skeleton is
## called GeneralSkeleton and is a unique node (%GeneralSkeleton), its bones are
## named like Godot's humanoid profile (Hips, Spine, LeftUpperArm...), it faces
## +Z, stands 1.8 m tall with its origin at its feet, and every bone's rest is
## unrotated (T-pose). So its animations line up with imported models', and
## theirs with it.

const DIR := "res://characters/mannequin/"
const BODY_MATERIAL := preload("res://characters/mannequin/body.tres")

## [bone, parent, where it starts (meters, T-pose, facing +Z)]. The character's
## left is +X.
const BONES := [
	["Root", "", Vector3(0, 0, 0)],
	["Hips", "Root", Vector3(0, 0.95, 0)],
	["Spine", "Hips", Vector3(0, 1.05, 0)],
	["Chest", "Spine", Vector3(0, 1.18, 0)],
	["UpperChest", "Chest", Vector3(0, 1.32, 0)],
	["Neck", "UpperChest", Vector3(0, 1.48, 0)],
	["Head", "Neck", Vector3(0, 1.58, 0)],
	["LeftShoulder", "UpperChest", Vector3(0.04, 1.42, 0)],
	["LeftUpperArm", "LeftShoulder", Vector3(0.18, 1.42, 0)],
	["LeftLowerArm", "LeftUpperArm", Vector3(0.46, 1.42, 0)],
	["LeftHand", "LeftLowerArm", Vector3(0.71, 1.42, 0)],
	["RightShoulder", "UpperChest", Vector3(-0.04, 1.42, 0)],
	["RightUpperArm", "RightShoulder", Vector3(-0.18, 1.42, 0)],
	["RightLowerArm", "RightUpperArm", Vector3(-0.46, 1.42, 0)],
	["RightHand", "RightLowerArm", Vector3(-0.71, 1.42, 0)],
	["LeftUpperLeg", "Hips", Vector3(0.1, 0.91, 0)],
	["LeftLowerLeg", "LeftUpperLeg", Vector3(0.1, 0.5, 0)],
	["LeftFoot", "LeftLowerLeg", Vector3(0.1, 0.09, 0)],
	["LeftToes", "LeftFoot", Vector3(0.1, 0.02, 0.13)],
	["RightUpperLeg", "Hips", Vector3(-0.1, 0.91, 0)],
	["RightLowerLeg", "RightUpperLeg", Vector3(-0.1, 0.5, 0)],
	["RightFoot", "RightLowerLeg", Vector3(-0.1, 0.09, 0)],
	["RightToes", "RightFoot", Vector3(-0.1, 0.02, 0.13)],
]

## Body regions, for the body shader's colors (vertex color red).
const SKIN := 0.0
const SHIRT := 1.0 / 3.0
const PANTS := 2.0 / 3.0
const SHOES := 1.0

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _indices := PackedInt32Array()
var _bone_index := {}


func _initialize() -> void:
	for i in BONES.size():
		_bone_index[BONES[i][0]] = i
	var root := Node3D.new()
	root.name = "Mannequin"
	var skeleton := _make_skeleton()
	root.add_child(skeleton)
	skeleton.owner = root
	skeleton.unique_name_in_owner = true

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _make_mesh()
	body.skeleton = NodePath("..")
	skeleton.add_child(body)
	body.owner = root
	ResourceSaver.save(body.mesh, DIR + "mannequin_body.res")
	body.mesh.take_over_path(DIR + "mannequin_body.res")

	var library := _make_animations()
	ResourceSaver.save(library, DIR + "mannequin_animations.tres")
	library.take_over_path(DIR + "mannequin_animations.tres")
	var people := _make_people_animations()
	ResourceSaver.save(people, DIR + "people_animations.tres")
	people.take_over_path(DIR + "people_animations.tres")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", library)
	root.add_child(player)
	player.owner = root

	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, DIR + "mannequin.tscn")
	print("mannequin: %d bones, %d triangles, %d + %d animations, saved: %s" % [skeleton.get_bone_count(),
			_indices.size() / 3, library.get_animation_list().size(), people.get_animation_list().size(), error_string(err)])
	root.free()
	quit()


# --- Skeleton ------------------------------------------------------------------

func _make_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	for bone: Array in BONES:
		var i := skeleton.add_bone(bone[0])
		var parent_at := Vector3.ZERO
		if bone[1] != "":
			skeleton.set_bone_parent(i, _bone_index[bone[1]])
			parent_at = BONES[_bone_index[bone[1]]][2]
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, bone[2] - parent_at))
	skeleton.reset_bone_poses()
	return skeleton


# --- Body ------------------------------------------------------------------------

## Capsules and boxes, each stuck to one bone (rigid skinning: plain, but no
## stretching at the joints).
func _make_mesh() -> ArrayMesh:
	_box("Hips", Vector3(0, 0.93, 0), Vector3(0.32, 0.18, 0.2), PANTS)
	_capsule("Spine", Vector3(0, 1.0, 0), Vector3(0, 1.2, 0), 0.14, SHIRT)
	_capsule("Chest", Vector3(0, 1.17, 0), Vector3(0, 1.34, 0), 0.165, SHIRT)
	_box("UpperChest", Vector3(0, 1.4, 0), Vector3(0.36, 0.14, 0.2), SHIRT)
	_capsule("Neck", Vector3(0, 1.45, 0), Vector3(0, 1.6, 0), 0.05, SKIN)
	_capsule("Head", Vector3(0, 1.6, 0.01), Vector3(0, 1.8, 0.01), 0.105, SKIN)
	_box("Head", Vector3(0, 1.66, 0.09), Vector3(0.05, 0.05, 0.05), SKIN) # nose
	for side in [1.0, -1.0]:
		var s := "Left" if side > 0.0 else "Right"
		_capsule(s + "UpperArm", Vector3(0.17 * side, 1.42, 0), Vector3(0.47 * side, 1.42, 0), 0.055, SHIRT)
		_capsule(s + "LowerArm", Vector3(0.46 * side, 1.42, 0), Vector3(0.70 * side, 1.42, 0), 0.045, SKIN)
		_box(s + "Hand", Vector3(0.77 * side, 1.42, 0), Vector3(0.13, 0.035, 0.08), SKIN)
		_capsule(s + "UpperLeg", Vector3(0.1 * side, 0.93, 0), Vector3(0.1 * side, 0.49, 0), 0.075, PANTS)
		_capsule(s + "LowerLeg", Vector3(0.1 * side, 0.51, 0), Vector3(0.1 * side, 0.1, 0), 0.06, PANTS)
		_box(s + "Foot", Vector3(0.1 * side, 0.045, 0.05), Vector3(0.1, 0.09, 0.25), SHOES)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_BONES] = _bones
	arrays[Mesh.ARRAY_WEIGHTS] = _weights
	arrays[Mesh.ARRAY_INDEX] = _indices
	# Through ImporterMesh for simpler versions at a distance (LODs), like an
	# imported model gets.
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, BODY_MATERIAL, "body")
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


func _capsule(bone: String, from: Vector3, to: Vector3, radius: float, region: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to) + radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 3
	var up := (to - from).normalized()
	var basis := Basis(Quaternion(Vector3.UP, up)) if absf(up.dot(Vector3.UP)) < 0.999 \
			else (Basis.IDENTITY if up.y > 0.0 else Basis(Vector3.RIGHT, PI))
	_add(mesh.get_mesh_arrays(), Transform3D(basis, (from + to) / 2.0), bone, region)


func _box(bone: String, center: Vector3, size: Vector3, region: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(mesh.get_mesh_arrays(), Transform3D(Basis.IDENTITY, center), bone, region)


func _add(arrays: Array, xform: Transform3D, bone: String, region: float) -> void:
	var start := _verts.size()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var b: int = _bone_index[bone]
	for i in verts.size():
		_verts.append(xform * verts[i])
		_normals.append((xform.basis * normals[i]).normalized())
		_colors.append(Color(region, 0, 0, 1))
		_bones.append_array([b, 0, 0, 0])
		_weights.append_array([1.0, 0.0, 0.0, 0.0])
	for i: int in arrays[Mesh.ARRAY_INDEX]:
		_indices.append(start + i)


# --- Animations ------------------------------------------------------------------
# Every bone's rest is unrotated, so a pose is just each bone's rotation in the
# character's own axes (x: its left, y: up, z: forward), relative to its parent.
# A few helpers keep the poses readable:
#   leg(deg)     swings a leg forward (negative: back); knee(deg) bends a knee.
#   lean(deg)    tips the spine, neck or head forward (negative: back).
#   arm(side, reach, down): arms point out sideways at rest; this swings one
#                forward by reach (90: straight ahead) and down by down
#                (negative: up). side 1 is the left arm, -1 the right.
#   elbow(side, deg) bends a forearm down; elbow_fwd(side, deg) bends it forward.

func _make_animations() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _idle())
	lib.add_animation("walk", _walk())
	lib.add_animation("run", _run())
	lib.add_animation("attack", _attack())
	lib.add_animation("bash", _bash())
	lib.add_animation("hit_head", _hit("head"))
	lib.add_animation("hit_body", _hit("body"))
	lib.add_animation("hit_legs", _hit("legs"))
	lib.add_animation("climb", _climb())
	lib.add_animation("crawl_idle", _crawl_idle())
	lib.add_animation("crawl", _crawl())
	lib.add_animation("crawl_attack", _crawl_attack())
	lib.add_animation("crawl_hit", _crawl_hit())
	return lib


static func leg(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(-deg)) # -x turns a bone hanging down (-y) toward +z


static func lean(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(deg)) # +x turns a bone pointing up (+y) toward +z


static func side_tilt(deg: float) -> Quaternion: # toward the character's left (+x)
	return Quaternion(Vector3.BACK, deg_to_rad(-deg))


static func turn(deg: float) -> Quaternion: # turns to the character's left
	return Quaternion(Vector3.UP, deg_to_rad(deg))


## An arm (side 1: left, -1: right) swung forward by reach_deg, then down by down_deg.
static func arm(side: float, reach_deg: float, down_deg: float) -> Quaternion:
	var forward := Quaternion(Vector3.UP, deg_to_rad(-reach_deg * side))
	var down := Quaternion(Vector3.BACK, deg_to_rad(-down_deg * side))
	return forward * down


## A forearm bent at the elbow by deg (downward, in the upper arm's frame).
static func elbow(side: float, deg: float) -> Quaternion:
	return Quaternion(Vector3.BACK, deg_to_rad(-deg * side))


## A forearm bent forward by deg (for an arm hanging down).
static func elbow_fwd(side: float, deg: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(-deg * side))


## A knee bent by deg (the shin swings back).
static func knee(deg: float) -> Quaternion:
	return leg(-deg)


## A new animation of this length; loop or not.
func _anim(length: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


## Keys a bone's rotation: times and values in step.
func _rot(a: Animation, bone: String, times: Array, values: Array) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, "%GeneralSkeleton:" + bone)
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for i in times.size():
		a.rotation_track_insert_key(t, times[i], values[i])


## Keys the hips' position (offset from where they rest).
func _hips(a: Animation, times: Array, offsets: Array) -> void:
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, "%GeneralSkeleton:Hips")
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	var rest: Vector3 = BONES[_bone_index["Hips"]][2]
	for i in times.size():
		a.position_track_insert_key(t, times[i], rest + offsets[i])


## One pose held for the whole animation (several bones).
func _hold(a: Animation, poses: Dictionary) -> void:
	for bone: String in poses:
		_rot(a, bone, [0.0], [poses[bone]])


## A looping swing: value_a, value_b, value_a over the length.
func _swing(a: Animation, bone: String, value_a: Quaternion, value_b: Quaternion) -> void:
	_rot(a, bone, [0.0, a.length / 2.0, a.length], [value_a, value_b, value_a])


## The zombie reach: both arms out ahead, a little uneven, elbows sagging.
func _zombie_arms(a: Animation, wobble: float) -> void:
	_swing(a, "LeftUpperArm", arm(1, 80, 15), arm(1, 80 - wobble, 15 + wobble))
	_swing(a, "RightUpperArm", arm(-1, 75, 22 + wobble), arm(-1, 75 + wobble, 22))
	_hold(a, {"LeftLowerArm": elbow(1, 15), "RightLowerArm": elbow(-1, 25)})


func _idle() -> Animation:
	var a := _anim(3.0, true)
	_zombie_arms(a, 6.0)
	_swing(a, "Spine", lean(8) * side_tilt(3), lean(10) * side_tilt(-3))
	_swing(a, "Neck", lean(15) * side_tilt(-8), lean(12) * side_tilt(10))
	_hips(a, [0.0, 1.5, 3.0], [Vector3(0, -0.02, 0), Vector3(0, -0.03, 0), Vector3(0, -0.02, 0)])
	_hold(a, {"LeftUpperLeg": leg(3), "RightUpperLeg": leg(-2), "LeftLowerLeg": knee(6), "RightLowerLeg": knee(4)})
	return a


## A shamble: 1.2 m per cycle (two steps), so it plays at speed / 1.2.
func _walk() -> Animation:
	var a := _anim(1.2, true)
	var t := [0.0, 0.3, 0.6, 0.9, 1.2]
	_rot(a, "LeftUpperLeg", t, [leg(25), leg(5), leg(-20), leg(0), leg(25)])
	_rot(a, "RightUpperLeg", t, [leg(-20), leg(0), leg(25), leg(5), leg(-20)])
	_rot(a, "LeftLowerLeg", t, [knee(5), knee(10), knee(15), knee(45), knee(5)])
	_rot(a, "RightLowerLeg", t, [knee(15), knee(45), knee(5), knee(10), knee(15)])
	_rot(a, "Hips", t, [side_tilt(4), side_tilt(0), side_tilt(-4), side_tilt(0), side_tilt(4)])
	_hips(a, t, [Vector3(0, -0.04, 0), Vector3(0, -0.01, 0), Vector3(0, -0.04, 0), Vector3(0, -0.01, 0), Vector3(0, -0.04, 0)])
	_swing(a, "Spine", lean(12) * turn(4), lean(12) * turn(-4))
	_swing(a, "Neck", lean(10) * side_tilt(6), lean(14) * side_tilt(-6))
	_zombie_arms(a, 8.0)
	return a


## Running flat out, leaning in: 2.8 m per cycle, so it plays at speed / 2.8.
func _run() -> Animation:
	var a := _anim(0.62, true)
	var t := [0.0, 0.155, 0.31, 0.465, 0.62]
	_rot(a, "LeftUpperLeg", t, [leg(45), leg(10), leg(-30), leg(20), leg(45)])
	_rot(a, "RightUpperLeg", t, [leg(-30), leg(20), leg(45), leg(10), leg(-30)])
	_rot(a, "LeftLowerLeg", t, [knee(15), knee(20), knee(40), knee(95), knee(15)])
	_rot(a, "RightLowerLeg", t, [knee(40), knee(95), knee(15), knee(20), knee(40)])
	_rot(a, "LeftUpperArm", t, [arm(1, 30, 70), arm(1, 60, 60), arm(1, -10, 75), arm(1, 60, 60), arm(1, 30, 70)])
	_rot(a, "RightUpperArm", t, [arm(-1, -10, 75), arm(-1, 60, 60), arm(-1, 30, 70), arm(-1, 60, 60), arm(-1, -10, 75)])
	_hold(a, {"LeftLowerArm": elbow_fwd(1, 70), "RightLowerArm": elbow_fwd(-1, 70), "Spine": lean(20), "Chest": lean(10), "Neck": lean(-10)})
	_hips(a, t, [Vector3(0, -0.05, 0), Vector3(0, 0.0, 0), Vector3(0, -0.05, 0), Vector3(0, 0.0, 0), Vector3(0, -0.05, 0)])
	return a


func _attack() -> Animation:
	var a := _anim(0.9, true)
	var t := [0.0, 0.3, 0.45, 0.9]
	_rot(a, "LeftUpperArm", t, [arm(1, 70, 0), arm(1, 95, 30), arm(1, 90, 35), arm(1, 70, 0)])
	_rot(a, "RightUpperArm", t, [arm(-1, 95, 30), arm(-1, 70, 0), arm(-1, 75, 10), arm(-1, 95, 30)])
	_rot(a, "Spine", t, [lean(15), lean(28), lean(30), lean(15)])
	_rot(a, "Neck", t, [lean(5), lean(25), lean(30), lean(5)])
	_hold(a, {"LeftLowerArm": elbow(1, 30), "RightLowerArm": elbow(-1, 30), "LeftUpperLeg": leg(15), "LeftLowerLeg": knee(20), "RightUpperLeg": leg(-10), "RightLowerLeg": knee(10)})
	return a


## Beating on a door or fence: arms up, then down hard.
func _bash() -> Animation:
	var a := _anim(0.8, true)
	var t := [0.0, 0.45, 0.6, 0.8]
	_rot(a, "LeftUpperArm", t, [arm(1, 60, -60), arm(1, 70, -70), arm(1, 90, 10), arm(1, 60, -60)])
	_rot(a, "RightUpperArm", t, [arm(-1, 60, -55), arm(-1, 70, -65), arm(-1, 90, 15), arm(-1, 60, -55)])
	_rot(a, "Spine", t, [lean(-5), lean(-8), lean(20), lean(-5)])
	_hold(a, {"LeftLowerArm": elbow(1, -20), "RightLowerArm": elbow(-1, -20), "LeftUpperLeg": leg(10), "LeftLowerLeg": knee(15)})
	return a


## Flinching from a hit: the head snaps back, the body rocks back, or a leg buckles.
func _hit(zone: String) -> Animation:
	var a := _anim(0.45, false)
	var t := [0.0, 0.1, 0.45]
	_zombie_arms(a, 4.0)
	match zone:
		"head":
			_rot(a, "Neck", t, [lean(10), lean(-35), lean(10)])
			_rot(a, "Spine", t, [lean(10), lean(-12), lean(10)])
		"body":
			_rot(a, "Spine", t, [lean(10), lean(-25), lean(10)])
			_rot(a, "Chest", t, [lean(0), lean(-10) * turn(10), lean(0)])
			_hips(a, t, [Vector3(0, -0.02, 0), Vector3(0, -0.02, -0.06), Vector3(0, -0.02, 0)])
		"legs":
			_rot(a, "LeftUpperLeg", t, [leg(3), leg(30), leg(3)])
			_rot(a, "LeftLowerLeg", t, [knee(5), knee(70), knee(5)])
			_rot(a, "Spine", t, [lean(10), lean(25), lean(10)])
			_hips(a, t, [Vector3(0, -0.02, 0), Vector3(0, -0.15, 0), Vector3(0, -0.02, 0)])
	return a


## Over a windowsill: hands on the sill, a knee up, over, and down (1.5 s; the
## game fits it to the climb).
func _climb() -> Animation:
	var a := _anim(1.5, false)
	var t := [0.0, 0.4, 0.8, 1.1, 1.5]
	_rot(a, "LeftUpperArm", t, [arm(1, 80, 15), arm(1, 90, 40), arm(1, 90, 60), arm(1, 70, 50), arm(1, 80, 15)])
	_rot(a, "RightUpperArm", t, [arm(-1, 75, 20), arm(-1, 90, 40), arm(-1, 90, 60), arm(-1, 70, 50), arm(-1, 75, 20)])
	_rot(a, "Spine", t, [lean(10), lean(30), lean(55), lean(30), lean(10)])
	_rot(a, "LeftUpperLeg", t, [leg(0), leg(80), leg(70), leg(20), leg(0)])
	_rot(a, "LeftLowerLeg", t, [knee(5), knee(100), knee(90), knee(30), knee(5)])
	_rot(a, "RightUpperLeg", t, [leg(0), leg(-10), leg(60), leg(30), leg(0)])
	_rot(a, "RightLowerLeg", t, [knee(5), knee(20), knee(100), knee(40), knee(5)])
	return a


# Crawling: the hips turned face down (head toward +z) and lowered to the ground.
# Arms reach "up" past the head, which is ahead of it now.

func _prone(a: Animation, bob: float) -> void:
	_rot(a, "Hips", [0.0], [Quaternion(Vector3.RIGHT, PI / 2.0)])
	_hips(a, [0.0, a.length / 2.0, a.length], [Vector3(0, -0.8, -0.15), Vector3(0, -0.8 + bob, -0.15), Vector3(0, -0.8, -0.15)])
	_hold(a, {"Neck": lean(-40), "Head": lean(-15)})


func _crawl_idle() -> Animation:
	var a := _anim(2.4, true)
	_prone(a, 0.01)
	_swing(a, "LeftUpperArm", arm(1, 0, -70), arm(1, 10, -75))
	_swing(a, "RightUpperArm", arm(-1, 0, -60), arm(-1, -10, -65))
	_hold(a, {"LeftLowerArm": elbow(1, 20), "RightLowerArm": elbow(-1, 30), "LeftUpperLeg": side_tilt(8), "RightUpperLeg": side_tilt(-5)})
	return a


## Dragging itself along: 0.6 m per cycle, so it plays at speed / 0.6.
func _crawl() -> Animation:
	var a := _anim(1.4, true)
	_prone(a, 0.03)
	var t := [0.0, 0.35, 0.7, 1.05, 1.4]
	_rot(a, "LeftUpperArm", t, [arm(1, 0, -80), arm(1, 20, -45), arm(1, 0, -10), arm(1, -10, -45), arm(1, 0, -80)])
	_rot(a, "RightUpperArm", t, [arm(-1, 0, -10), arm(-1, -10, -45), arm(-1, 0, -80), arm(-1, 20, -45), arm(-1, 0, -10)])
	_rot(a, "LeftLowerArm", t, [elbow(1, 10), elbow(1, 40), elbow(1, 70), elbow(1, 40), elbow(1, 10)])
	_rot(a, "RightLowerArm", t, [elbow(-1, 70), elbow(-1, 40), elbow(-1, 10), elbow(-1, 40), elbow(-1, 70)])
	_swing(a, "Spine", side_tilt(5), side_tilt(-5))
	_swing(a, "LeftLowerLeg", knee(5), knee(25))
	_swing(a, "RightLowerLeg", knee(25), knee(5))
	return a


func _crawl_attack() -> Animation:
	var a := _anim(0.9, true)
	_prone(a, 0.05)
	var t := [0.0, 0.3, 0.9]
	_rot(a, "LeftUpperArm", t, [arm(1, 0, -70), arm(1, 30, -30), arm(1, 0, -70)])
	_rot(a, "RightUpperArm", t, [arm(-1, 30, -30), arm(-1, 0, -70), arm(-1, 30, -30)])
	_rot(a, "Chest", t, [lean(-10), lean(-25), lean(-10)])
	return a


func _crawl_hit() -> Animation:
	var a := _anim(0.4, false)
	_prone(a, 0.0)
	_rot(a, "Chest", [0.0, 0.1, 0.4], [lean(0), lean(-30), lean(0)])
	_hold(a, {"LeftUpperArm": arm(1, 0, -70), "RightUpperArm": arm(-1, 0, -60)})
	return a


# --- People ----------------------------------------------------------------------
# Standing upright, arms at their sides. Poses that hold something (the rifle, a
# bench, the ground) say where the hands go and an arm solver bends the arms to
# reach (_posed): a key's "right_hand" / "left_hand" is [where (meters, the
# character's own space, as in BONES), which way the hand turns], and its
# "right_elbow" / "left_elbow" which way that elbow points.

const UPPER_ARM := 0.28
const FOREARM := 0.25
## The hand turned so a rifle in it (characters/npcs/human_npc.gd: rifle_hold)
## points straight ahead.
const RIFLE_AHEAD := Quaternion(Vector3.UP, PI / 2.0)
## Where the right hand holds a rifle at the shoulder, and how far along the
## barrel the left hand holds it.
const SHOULDER_GRIP := Vector3(-0.1, 1.47, 0.3)
const FORE_END := 0.24


func _make_people_animations() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _person_idle())
	lib.add_animation("walk", _person_walk())
	lib.add_animation("run", _run())
	lib.add_animation("talk", _talk())
	lib.add_animation("hit_head", _person_hit("head"))
	lib.add_animation("hit_body", _person_hit("body"))
	lib.add_animation("hit_legs", _person_hit("legs"))
	lib.add_animation("rifle_idle", _rifle_idle())
	lib.add_animation("rifle_walk", _rifle_walk())
	lib.add_animation("rifle_aim", _rifle_aim())
	lib.add_animation("rifle_shoot", _rifle_shoot())
	lib.add_animation("rifle_reload", _rifle_reload())
	lib.add_animation("work_dig", _work_dig())
	lib.add_animation("work_bench", _work_bench())
	return lib


## Arms hanging at the sides, elbows a little bent.
func _arms_down(a: Animation, sway: float) -> void:
	_swing(a, "LeftUpperArm", arm(1, 0, 80), arm(1, sway, 80))
	_swing(a, "RightUpperArm", arm(-1, sway, 80), arm(-1, 0, 80))
	_hold(a, {"LeftLowerArm": elbow_fwd(1, 12), "RightLowerArm": elbow_fwd(-1, 12)})


func _person_idle() -> Animation:
	var a := _anim(4.0, true)
	_arms_down(a, 3.0)
	_swing(a, "Chest", lean(1), lean(-1)) # breathing
	_swing(a, "Neck", lean(2) * turn(4), lean(3) * turn(-4))
	_hips(a, [0.0, 2.0, 4.0], [Vector3(0, -0.01, 0), Vector3(0.01, -0.015, 0), Vector3(0, -0.01, 0)])
	_hold(a, {"LeftUpperLeg": leg(2) * side_tilt(2), "RightUpperLeg": leg(-1) * side_tilt(-2), "LeftLowerLeg": knee(4), "RightLowerLeg": knee(3)})
	return a


## A steady walk: 1.4 m per cycle (two steps), so it plays at speed / 1.4.
func _person_walk() -> Animation:
	var a := _anim(1.0, true)
	_walking_legs(a)
	_rot(a, "LeftUpperArm", [0.0, 0.5, 1.0], [arm(1, -20, 80), arm(1, 22, 80), arm(1, -20, 80)])
	_rot(a, "RightUpperArm", [0.0, 0.5, 1.0], [arm(-1, 22, 80), arm(-1, -20, 80), arm(-1, 22, 80)])
	_hold(a, {"LeftLowerArm": elbow_fwd(1, 20), "RightLowerArm": elbow_fwd(-1, 20)})
	_swing(a, "Spine", lean(3) * turn(-4), lean(3) * turn(4))
	return a


func _walking_legs(a: Animation) -> void:
	var t := [0.0, 0.25, 0.5, 0.75, 1.0]
	_rot(a, "LeftUpperLeg", t, [leg(25), leg(5), leg(-20), leg(0), leg(25)])
	_rot(a, "RightUpperLeg", t, [leg(-20), leg(0), leg(25), leg(5), leg(-20)])
	_rot(a, "LeftLowerLeg", t, [knee(5), knee(10), knee(15), knee(50), knee(5)])
	_rot(a, "RightLowerLeg", t, [knee(15), knee(50), knee(5), knee(10), knee(15)])
	_hips(a, t, [Vector3(0, -0.03, 0), Vector3(0, 0.0, 0), Vector3(0, -0.03, 0), Vector3(0, 0.0, 0), Vector3(0, -0.03, 0)])


## Talking with their hands: the right hand comes up and moves, the head nods.
func _talk() -> Animation:
	var t := [0.0, 0.6, 1.2, 1.8, 2.4]
	var hand := [Vector3(-0.2, 1.1, 0.3), Vector3(-0.16, 1.18, 0.34), Vector3(-0.24, 1.12, 0.32), Vector3(-0.15, 1.2, 0.3), Vector3(-0.2, 1.1, 0.3)]
	var keys: Array[Dictionary] = []
	for i in t.size():
		keys.append({"right_hand": [hand[i], Quaternion(Vector3.FORWARD, deg_to_rad(-30 + 15 * (i % 2)))],
				"right_elbow": Vector3(-0.6, -1, -0.3),
				"LeftUpperArm": arm(1, 5, 80), "LeftLowerArm": elbow_fwd(1, 15),
				"Neck": lean(4 if i % 2 == 0 else -2) * side_tilt(3 if i < 2 else -3)})
	var a := _posed(2.4, true, t, keys)
	_hold(a, {"LeftUpperLeg": leg(2), "RightUpperLeg": leg(-2), "LeftLowerLeg": knee(4), "RightLowerLeg": knee(3)})
	return a


func _person_hit(zone: String) -> Animation:
	var a := _anim(0.45, false)
	var t := [0.0, 0.1, 0.45]
	_hold(a, {"LeftLowerArm": elbow_fwd(1, 25), "RightLowerArm": elbow_fwd(-1, 25)})
	_rot(a, "LeftUpperArm", t, [arm(1, 0, 80), arm(1, 20, 60), arm(1, 0, 80)])
	_rot(a, "RightUpperArm", t, [arm(-1, 0, 80), arm(-1, 20, 60), arm(-1, 0, 80)])
	match zone:
		"head":
			_rot(a, "Neck", t, [lean(0), lean(-35), lean(0)])
			_rot(a, "Spine", t, [lean(0), lean(-10), lean(0)])
		"body":
			_rot(a, "Spine", t, [lean(0), lean(20), lean(0)])
			_rot(a, "Chest", t, [lean(0), lean(10) * turn(10), lean(0)])
			_hips(a, t, [Vector3.ZERO, Vector3(0, -0.02, -0.06), Vector3.ZERO])
		"legs":
			_rot(a, "LeftUpperLeg", t, [leg(0), leg(30), leg(0)])
			_rot(a, "LeftLowerLeg", t, [knee(3), knee(70), knee(3)])
			_rot(a, "Spine", t, [lean(0), lean(20), lean(0)])
			_hips(a, t, [Vector3.ZERO, Vector3(0, -0.14, 0), Vector3.ZERO])
	return a


# Holding the rifle. The body turns a little side-on (the left shoulder ahead)
# so the left hand reaches the barrel.

## The rifle's hands for one key: the right hand on the grip at grip, the
## rifle pitched down by down_deg, the left hand along the barrel.
func _rifle_hands(key: Dictionary, grip: Vector3, down_deg: float) -> Dictionary:
	var pitch := Quaternion(Vector3.RIGHT, deg_to_rad(down_deg))
	var ahead := pitch * Vector3.BACK # +z, pitched down
	key["right_hand"] = [grip, pitch * RIFLE_AHEAD]
	key["left_hand"] = [grip + ahead * FORE_END + Vector3(0, -0.04, 0), pitch * RIFLE_AHEAD * Quaternion(Vector3.UP, PI)]
	key["right_elbow"] = Vector3(-1, -0.6, -0.3)
	key["left_elbow"] = Vector3(0.3, -1, 0)
	return key


func _rifle_stance(key: Dictionary, upper_body_turn := -20.0) -> Dictionary:
	key["Spine"] = turn(upper_body_turn * 0.5)
	key["Chest"] = turn(upper_body_turn * 0.5)
	return key


## Standing ready: the rifle held low across the body.
func _rifle_idle() -> Animation:
	var t := [0.0, 2.0, 4.0]
	var keys: Array[Dictionary] = []
	for i in t.size():
		keys.append(_rifle_hands(_rifle_stance({}, -10.0), Vector3(-0.14, 1.12 + 0.01 * (i % 2), 0.26), 35.0))
	var a := _posed(4.0, true, t, keys)
	_hold(a, {"LeftUpperLeg": leg(2), "RightUpperLeg": leg(-2), "LeftLowerLeg": knee(4), "RightLowerLeg": knee(3)})
	return a


## Walking with the rifle held low: 1.4 m per cycle, like walk.
func _rifle_walk() -> Animation:
	var t := [0.0, 0.25, 0.5, 0.75, 1.0]
	var keys: Array[Dictionary] = []
	for i in t.size():
		keys.append(_rifle_hands(_rifle_stance({}, -10.0), Vector3(-0.14, 1.12 + (0.015 if i % 2 == 1 else 0.0), 0.26), 35.0))
	var a := _posed(1.0, true, t, keys, [Vector3(0, -0.03, 0), Vector3(0, 0.0, 0), Vector3(0, -0.03, 0), Vector3(0, 0.0, 0), Vector3(0, -0.03, 0)])
	var legs := [0.0, 0.25, 0.5, 0.75, 1.0]
	_rot(a, "LeftUpperLeg", legs, [leg(25), leg(5), leg(-20), leg(0), leg(25)])
	_rot(a, "RightUpperLeg", legs, [leg(-20), leg(0), leg(25), leg(5), leg(-20)])
	_rot(a, "LeftLowerLeg", legs, [knee(5), knee(10), knee(15), knee(50), knee(5)])
	_rot(a, "RightLowerLeg", legs, [knee(15), knee(50), knee(5), knee(10), knee(15)])
	return a


## The rifle at the shoulder, aimed straight ahead (the game tips the spine up or
## down toward what it's aiming at).
func _rifle_aim() -> Animation:
	var t := [0.0, 1.5, 3.0]
	var keys: Array[Dictionary] = []
	for i in t.size():
		var key := _rifle_hands(_rifle_stance({}), SHOULDER_GRIP + Vector3(0, 0.004 * (i % 2), 0), 0.0)
		key["Neck"] = lean(8) * turn(-10)
		keys.append(key)
	var a := _posed(3.0, true, t, keys)
	_hold(a, {"LeftUpperLeg": leg(12) * side_tilt(4), "RightUpperLeg": leg(-6) * side_tilt(-4), "LeftLowerLeg": knee(12), "RightLowerLeg": knee(6)})
	return a


## One shot: the rifle kicks up and back, then settles (0.4 s).
func _rifle_shoot() -> Animation:
	var t := [0.0, 0.05, 0.4]
	var kick := [Vector3.ZERO, Vector3(0, 0.02, -0.06), Vector3.ZERO]
	var pitch := [0.0, -8.0, 0.0]
	var keys: Array[Dictionary] = []
	for i in t.size():
		var key := _rifle_hands(_rifle_stance({}), SHOULDER_GRIP + kick[i], pitch[i])
		key["Neck"] = lean(8) * turn(-10)
		key["Chest"] = turn(-10) * lean(-4.0 if i == 1 else 0.0)
		keys.append(key)
	var a := _posed(0.4, false, t, keys)
	_hold(a, {"LeftUpperLeg": leg(12) * side_tilt(4), "RightUpperLeg": leg(-6) * side_tilt(-4), "LeftLowerLeg": knee(12), "RightLowerLeg": knee(6)})
	return a


## Reloading (2 s; the game fits it to the reload time): the rifle comes down,
## the left hand goes to the belt for rounds and feeds them in, twice.
func _rifle_reload() -> Animation:
	var t := [0.0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.0]
	var port := Vector3(-0.08, 1.18, 0.34) # where the rounds go in (the right hand holds it low)
	var belt := Vector3(0.14, 0.98, 0.1)
	var left := [null, port, belt, port, belt, port, port, null]
	var keys: Array[Dictionary] = []
	for i in t.size():
		var down := 0.0 if i == 0 or i == t.size() - 1 else 30.0
		var grip := SHOULDER_GRIP if down == 0.0 else Vector3(-0.12, 1.15, 0.24)
		var key := _rifle_hands(_rifle_stance({}), grip, down)
		if left[i] != null:
			key["left_hand"] = [left[i], Quaternion(Vector3.FORWARD, deg_to_rad(-60))]
			key["left_elbow"] = Vector3(0.5, -1, -0.4)
		key["Neck"] = lean(25 if down > 0.0 else 8)
		keys.append(key)
	var a := _posed(2.0, false, t, keys)
	_hold(a, {"LeftUpperLeg": leg(8), "RightUpperLeg": leg(-4), "LeftLowerLeg": knee(10), "RightLowerLeg": knee(5)})
	return a


## Working a garden plot: bent over, pulling at the ground a hand at a time.
func _work_dig() -> Animation:
	var t := [0.0, 0.4, 0.8, 1.2, 1.6]
	var reach := [0.0, 1.0, 0.0, -1.0, 0.0] # which hand's reaching furthest in
	var keys: Array[Dictionary] = []
	for i in t.size():
		var key := {"Spine": lean(30), "Chest": lean(20), "Neck": lean(10),
				"left_elbow": Vector3(1, 0, -1), "right_elbow": Vector3(-1, 0, -1)}
		key["left_hand"] = [Vector3(0.18, 0.32 + 0.06 * maxf(-reach[i], 0.0), 0.55 + 0.1 * reach[i]), Quaternion(Vector3.BACK, deg_to_rad(-70))]
		key["right_hand"] = [Vector3(-0.18, 0.32 + 0.06 * maxf(reach[i], 0.0), 0.55 - 0.1 * reach[i]), Quaternion(Vector3.BACK, deg_to_rad(70))]
		keys.append(key)
	var bent := Vector3(0, -0.28, -0.12)
	var a := _posed(1.6, true, t, keys, [bent, bent, bent, bent, bent])
	_hold(a, {"LeftUpperLeg": leg(55) * side_tilt(10), "RightUpperLeg": leg(45) * side_tilt(-10), "LeftLowerLeg": knee(80), "RightLowerLeg": knee(70)})
	return a


## Working at a bench: the left hand holds the work, the right taps away at it.
func _work_bench() -> Animation:
	var t := [0.0, 0.25, 0.5, 0.8]
	var tap := [0.0, 0.12, 0.0, 0.0]
	var keys: Array[Dictionary] = []
	for i in t.size():
		keys.append({"Spine": lean(10), "Neck": lean(20),
				"left_hand": [Vector3(0.1, 1.0, 0.42), Quaternion(Vector3.BACK, deg_to_rad(-80))],
				"right_hand": [Vector3(-0.08, 1.02 + tap[i], 0.4), Quaternion(Vector3.BACK, deg_to_rad(70)) * Quaternion(Vector3.FORWARD, deg_to_rad(-30 * tap[i] / 0.12))],
				"left_elbow": Vector3(1, -1, 0), "right_elbow": Vector3(-1, -1, 0)})
	var a := _posed(0.8, true, t, keys)
	_hold(a, {"LeftUpperLeg": leg(3), "RightUpperLeg": leg(-3), "LeftLowerLeg": knee(5), "RightLowerLeg": knee(5)})
	return a


## Keys at times from poses (bone -> rotation, plus where the hands go: see
## above), with the arms solved to reach. hips: the hips' offsets at the same
## times, or none.
func _posed(length: float, loop: bool, times: Array, keys: Array[Dictionary], hips: Array = []) -> Animation:
	var a := _anim(length, loop)
	var tracks := {} # bone -> [rotations, one per key]
	for i in keys.size():
		var pose := _solve_arms(keys[i], hips[i] if not hips.is_empty() else Vector3.ZERO)
		for bone: String in pose:
			if not tracks.has(bone):
				tracks[bone] = []
			tracks[bone].append(pose[bone])
	for bone: String in tracks:
		if (tracks[bone] as Array).size() == keys.size():
			_rot(a, bone, times, tracks[bone])
		else:
			push_error("%s isn't in every key" % bone)
	if not hips.is_empty():
		_hips(a, times, hips)
	return a


## The pose's bone rotations, with each arm that has a hand target bent to reach it.
func _solve_arms(key: Dictionary, hips_offset: Vector3) -> Dictionary:
	var pose := {}
	for bone: String in key:
		if key[bone] is Quaternion:
			pose[bone] = key[bone]
	for side in [1.0, -1.0]:
		var s := "left" if side > 0.0 else "right"
		var S := "Left" if side > 0.0 else "Right"
		if not key.has(s + "_hand"):
			continue
		var target: Vector3 = key[s + "_hand"][0]
		var hand_turn: Quaternion = key[s + "_hand"][1]
		var pole: Vector3 = key.get(s + "_elbow", Vector3(side, -1, 0))
		var shoulder := _global(pose, S + "Shoulder", hips_offset)
		var start := _global(pose, S + "UpperArm", hips_offset).origin
		var to := target - start
		var dist := clampf(to.length(), absf(UPPER_ARM - FOREARM) + 0.01, UPPER_ARM + FOREARM - 0.001)
		var dir := to.normalized()
		var along := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + dist * dist) / (2.0 * dist)
		var out := sqrt(maxf(UPPER_ARM * UPPER_ARM - along * along, 0.0))
		var bend := (pole - dir * pole.dot(dir)).normalized()
		var elbow_at := start + dir * along + bend * out
		var hand_at := start + dir * dist
		var rest := Vector3(side, 0, 0) # the arm's direction at rest
		var upper := Quaternion(rest, (elbow_at - start).normalized())
		var lower := Quaternion(rest, (hand_at - elbow_at).normalized())
		var shoulder_turn := shoulder.basis.get_rotation_quaternion()
		pose[S + "UpperArm"] = shoulder_turn.inverse() * upper
		pose[S + "LowerArm"] = upper.inverse() * lower
		pose[S + "Hand"] = lower.inverse() * hand_turn
	return pose


## Where a bone is (the character's own space) in a pose: its parents' rotations
## from the pose, each bone's place from BONES.
func _global(pose: Dictionary, bone: String, hips_offset: Vector3) -> Transform3D:
	var i: int = _bone_index[bone]
	var parent: String = BONES[i][1]
	var at: Vector3 = BONES[i][2]
	var turn_now: Quaternion = pose.get(bone, Quaternion.IDENTITY)
	if parent == "":
		return Transform3D(Basis(turn_now), at)
	var parent_xform := _global(pose, parent, hips_offset)
	var offset: Vector3 = at - BONES[_bone_index[parent]][2]
	if bone == "Hips":
		offset += hips_offset
	return parent_xform * Transform3D(Basis(turn_now), offset)
