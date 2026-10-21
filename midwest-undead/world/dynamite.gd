class_name Dynamite
extends RigidBody3D
## A lit stick of dynamite: thrown (a 4 s fuse, less however long you held it
## lit first) or set down (8 s), it sputters, then goes off (player.gd lights
## them). The blast:
##   - zombies within RADIUS: killed close in, hurt further out (walls shelter them)
##   - you, the same (walls shelter you too)
##   - cave-ins within RADIUS: blown clear (world/map/mine_cave_in.gd)
##   - your own fences and gates, barricades and boarded-up planks within RADIUS: wrecked
##   - window glass: smashed
## and it's heard NOISE meters away.

const GameData := preload("res://core/game_data.gd")
const Hearing := preload("res://world/hearing.gd")
const Sound := preload("res://core/sound.gd")
const THROW_FUSE := 4.0
const PLACE_FUSE := 8.0
const RADIUS := 6.0
const NOISE := 80.0
## Damage at the middle of the blast and at its edge (lerped by distance).
const ZOMBIE_DAMAGE := Vector2(300.0, 30.0)
const PLAYER_DAMAGE := Vector2(120.0, 15.0)

var fuse := THROW_FUSE
var _spark: OmniLight3D
var _hiss := 0.0


## A lit stick at `at`, going off in `seconds`, moving at `velocity`. Add it to the tree yourself.
static func lit(at: Vector3, seconds: float, velocity := Vector3.ZERO) -> Dynamite:
	var stick := Dynamite.new()
	stick.position = at
	stick.fuse = seconds
	stick.linear_velocity = velocity
	stick.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	return stick


func _ready() -> void:
	collision_layer = 0 # nobody bumps into it
	collision_mask = GameData.LAYER_WORLD | GameData.LAYER_GLASS
	mass = 0.3
	continuous_cd = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.05, 0.05, 0.22)
	shape.shape = box
	add_child(shape)
	var stick := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.72, 0.12, 0.08)
	mesh.material = red
	stick.mesh = mesh
	add_child(stick)
	_spark = OmniLight3D.new() # the fuse, sputtering
	_spark.light_color = Color(1.0, 0.7, 0.3)
	_spark.omni_range = 2.5
	_spark.position = Vector3(0, 0, -0.12)
	add_child(_spark)


func _physics_process(delta: float) -> void:
	fuse -= delta
	_spark.light_energy = randf_range(0.6, 1.6)
	_hiss -= delta
	if _hiss <= 0.0:
		_hiss = 0.5
		Sound.play_at(self, "fuse_hiss", global_position, -6.0, 15.0)
	if fuse <= 0.0:
		explode(get_tree(), global_position)
		queue_free()


## The blast, at `at` (also used for one that goes off in your hand).
static func explode(tree: SceneTree, at: Vector3) -> void:
	var world := tree.root.get_world_3d()
	Hearing.make_noise(tree.root, at, NOISE)
	_effect(tree, at)
	for zombie in tree.get_nodes_in_group("zombies"):
		var z := zombie as Node3D
		if not is_instance_valid(z) or z.get("is_dead"):
			continue
		var d := at.distance_to(z.global_position)
		if d < RADIUS and _in_sight(world, at, z.global_position + Vector3.UP, [z.get_rid()]):
			z.call("take_hit", lerpf(ZOMBIE_DAMAGE.x, ZOMBIE_DAMAGE.y, d / RADIUS), at, 8.0)
	var player := tree.get_first_node_in_group("player") as Node3D
	if player and not player.get("is_dead"):
		var d := at.distance_to(player.global_position)
		if d < RADIUS and _in_sight(world, at, player.global_position + Vector3.UP, [player.get_rid()]):
			player.call("take_damage", lerpf(PLAYER_DAMAGE.x, PLAYER_DAMAGE.y, d / RADIUS), "blown_up")
	for cave_in in tree.root.find_children("*", "MineCaveIn", true, false):
		if is_instance_valid(cave_in) and at.distance_to((cave_in as Node3D).global_position + Vector3.UP * 1.5) < RADIUS:
			(cave_in as MineCaveIn).dig_out()
	var structures := tree.get_first_node_in_group("structures")
	if structures:
		for piece in (structures.get("pieces") as Array).duplicate():
			if piece.is_breakable() and not piece.broken and at.distance_to(piece.global_position) < RADIUS:
				piece.health = 0.0
				structures.call("damaged", piece)
	var fortifications := tree.get_first_node_in_group("fortifications")
	if fortifications:
		var torn: Array = (fortifications.get("barricades") as Array).duplicate()
		for o: Dictionary in fortifications.get("openings"):
			if o["planks"] != null:
				torn.append(o["planks"])
		for piece: Node3D in torn:
			if at.distance_to(piece.global_position) < RADIUS:
				fortifications.call("take_down", piece) # (blown apart: nothing to give back)
	for pane in tree.get_nodes_in_group("windows"):
		if is_instance_valid(pane) and at.distance_to((pane as Node3D).global_position) < RADIUS and pane.has_method("smash"):
			pane.call("smash")


## A clear line from the blast to what it'd hit: low or high, to its middle or
## its head (a crate or a cart doesn't shelter you; a wall does).
static func _in_sight(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	for rise: float in [0.3, 1.2]:
		for up: float in [0.0, 0.6]:
			var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * rise, to + Vector3.UP * up, GameData.LAYER_WORLD, exclude)
			if world.direct_space_state.intersect_ray(query).is_empty():
				return true
	return false


## The flash and the bang, and a puff of dust.
static func _effect(tree: SceneTree, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	tree.root.add_child(holder)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.45)
	flash.light_energy = 14.0
	flash.omni_range = 14.0
	holder.add_child(flash)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.6
	dust.explosiveness = 1.0
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 6.0
	dust.gravity = Vector3(0, -2.0, 0)
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.2
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE * 0.4
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.32, 0.3)
	puff.material = grey
	dust.mesh = puff
	holder.add_child(dust)
	dust.emitting = true
	Sound.play_at(holder, "explosion", at, 6.0, 120.0)
	var tween := holder.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_interval(1.4)
	tween.tween_callback(holder.queue_free)
