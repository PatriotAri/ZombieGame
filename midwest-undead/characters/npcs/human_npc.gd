class_name HumanNPC
extends CharacterBody3D
## Base class for every human NPC: guards, traders, and later bandits and others.
##
## It owns what all humans share: a name, a faction, health, getting hurt and dying,
## being a target zombies can go after, an optional floating name tag, and a body
## whose clothes and skin colors can be set per scene.
##
## To make a new kind of NPC: create a new inherited scene from human_npc.tscn
## (Scene > New Inherited Scene), attach a script that starts with
## `extends HumanNPC`, and add whatever extra nodes it needs (a rifle, a backpack...).
## Override _npc_ready() for setup and _npc_physics(delta) for behavior, so the
## base class keeps doing its part.

signal died(npc: HumanNPC)

enum Faction { SURVIVOR, BANDIT }

const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")

@export_group("Identity")
@export var display_name := "Survivor"
@export var faction := Faction.SURVIVOR
## Show the name floating above their head.
@export var show_name_tag := false

@export_group("Look")
@export var outfit_color := Color(0.35, 0.33, 0.3)
@export var skin_color := Color(0.72, 0.56, 0.44)

@export_group("Survival")
@export var max_health := 100.0
## Whether zombies can spot and chase this NPC.
@export var zombies_target := true
## Whether your attacks hurt them. Off for friendlies, so a stray shot or swing
## doesn't kill the guard or the trader.
@export var player_can_hurt := false
## Stationary NPCs (a guard on a tower, a trader behind a counter) skip gravity
## and movement entirely. Turn off for NPCs that walk around.
@export var stationary := true

var health := 100.0
var is_dead := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []

@onready var visual: Node3D = $Visual # all body meshes hang off this, so they can topple on death
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var head_mesh: MeshInstance3D = $Visual/Head
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var name_tag: Label3D = $NameTag


func _ready() -> void:
	add_to_group("npcs")
	if zombies_target:
		add_to_group("zombie_targets")
	collision_layer = GameData.LAYER_NPC
	collision_mask = GameData.LAYER_WORLD | GameData.LAYER_PLAYER | GameData.LAYER_ZOMBIES \
			| GameData.LAYER_GLASS | GameData.LAYER_NPC
	health = max_health
	name_tag.text = display_name
	name_tag.visible = show_name_tag
	_apply_colors()
	_npc_ready()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not stationary:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
	_npc_physics(delta)


## Override in subclasses for one-time setup (called at the end of _ready).
func _npc_ready() -> void:
	pass


## Override in subclasses for per-frame behavior (skipped once dead).
func _npc_physics(_delta: float) -> void:
	pass


## Zombies call this to decide whether this NPC is worth chasing.
func is_targetable() -> bool:
	return zombies_target and not is_dead


## The action shown in the "E: ..." prompt when you look at this NPC, e.g.
## "trade with Quartermaster". Empty means there's nothing to do with them.
## Subclasses override this; main.gd decides what pressing E actually opens.
func interact_prompt() -> String:
	return ""


func is_hostile_to_player() -> bool:
	return faction == Faction.BANDIT


## Hits from weapons (player or NPC). Same signature zombies use, so attackers
## don't need to care what they hit.
func take_hit(damage: float, _from_pos: Vector3, _knockback: float, attacker: Node3D = null) -> void:
	if attacker != null and attacker.is_in_group("player") and not player_can_hurt:
		return
	take_damage(damage)


## Raw damage, e.g. a zombie biting.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	_flash()
	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	remove_from_group("zombie_targets")
	remove_from_group("npcs")
	name_tag.visible = false
	collision.set_deferred("disabled", true) # deferred: physics may be mid-step
	var tween := create_tween()
	tween.tween_property(visual, "rotation:x", PI / 2.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) # topple backward
	tween.parallel().tween_property(visual, "position:y", 0.3, 0.6)
	died.emit(self)


## A brief streak of light along a bullet's path, so you can see who's shooting
## at what. Shared by every NPC that carries a gun.
func _tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.55)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(inst)
	inst.global_position = (from + to) / 2.0
	var dir := (to - from).normalized()
	inst.look_at(to, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(inst.queue_free)


## Scene materials are shared by every instance, so give this NPC its own copies
## (otherwise recoloring or flashing one would change them all).
func _apply_colors() -> void:
	for pair in [[body_mesh, outfit_color], [head_mesh, skin_color]]:
		var mesh_inst: MeshInstance3D = pair[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = pair[1]
		mesh_inst.material_override = mat
		_materials.append(mat)
		_base_colors.append(mat.albedo_color)


func _flash() -> void:
	var tween := create_tween().set_parallel(true)
	for i in _materials.size():
		_materials[i].albedo_color = Color(1.0, 0.75, 0.75)
		tween.tween_property(_materials[i], "albedo_color", _base_colors[i], 0.25)
