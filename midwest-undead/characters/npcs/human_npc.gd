class_name HumanNPC
extends CharacterBody3D
## Base class for every human NPC: guards, traders, and later bandits and others.
##
## It owns what all humans share: a name, a faction, health, getting hurt and dying,
## being a target zombies can go after, an optional floating name tag, and a body
## (characters/humanoid_body.gd): their model, its animations, the ragdoll when
## they die, and blood where they're hit.
##
## Their model: Model in the Inspector. Set on human_npc.tscn it's everyone's
## (empty: the mannequin, in their outfit and skin colors); a kind's scene
## (guard.tscn, bandit.tscn...) or a person (a survivor's file) can set their
## own. Anything else under Visual (a hat, a bandana) rides on the nearest bone.
## See HOW_TO_MODEL.md.
##
## Animations, by name (the model's own, or the mannequin's people_animations):
##   idle, walk (1.4 m a cycle), run (2.8 m a cycle), talk (while you talk to
##   them), hit_head / hit_body / hit_legs (flinches), rifle_idle, rifle_walk,
##   rifle_aim, rifle_shoot, rifle_reload (guards and bandits), work_dig (a
##   garden plot), work_bench (a bench). Subclasses pick theirs in _animation().
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
const Blood := preload("res://effects/blood.gd")
const HumanoidBody := preload("res://characters/humanoid_body.gd")

const WALK_PACE := 1.4 # meters per cycle of the walk animation
const RUN_PACE := 2.8
const RUN_FROM := 3.2 # m/s: faster than this runs

@export_group("Identity")
@export var display_name := "Survivor"
@export var faction := Faction.SURVIVOR
## Show the name floating above their head.
@export var show_name_tag := false

@export_group("Look")
## Their model: a character scene with a humanoid skeleton (HOW_TO_MODEL.md).
## Empty: the mannequin.
@export var model: PackedScene
@export var outfit_color := Color(0.35, 0.33, 0.3)
@export var skin_color := Color(0.72, 0.56, 0.44)

@export_group("Rifle")
## Carries the rifle (its held model, items/data/rifle.tres) in the right hand.
@export var holds_rifle := false
## Where the rifle sits in the right hand (the hand bone's space). The default
## fits the mannequin; a model's hand can need its own.
@export var rifle_hold := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.14, -0.01, 0.0))

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
## True while you're talking to them (main.gd sets it; it goes once your menus close).
var talking := false
## The rifle in their hand (holds_rifle), and the flash at its muzzle; or null.
var rifle: Node3D
var muzzle_flash: OmniLight3D
var _last_blow: Array = [] # [impulse, where]: what knocks the body over if this hit kills
var _player: Node

@onready var visual: Node3D = $Visual
@onready var body: HumanoidBody = $Visual/Body
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
	_setup_body()
	_npc_ready()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not stationary:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
	_npc_physics(delta)
	if talking:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player")
		talking = _player != null and bool(_player.get("menu_open"))
	if not body.is_busy():
		var pick := _animation()
		body.set_action(pick[0], pick[1])


## Override in subclasses for one-time setup (called at the end of _ready).
func _npc_ready() -> void:
	pass


## Override in subclasses for per-frame behavior (skipped once dead).
func _npc_physics(_delta: float) -> void:
	pass


## What to play now: [animation, speed]. Override for more (call super for the
## rest): talking, then walking or running at their pace, else standing.
func _animation() -> Array:
	if talking:
		return ["talk", 1.0]
	var pace := Vector2(velocity.x, velocity.z).length()
	if pace > RUN_FROM:
		return ["run", clampf(pace / RUN_PACE, 0.5, 2.0)]
	if pace > 0.15:
		return ["walk", clampf(pace / WALK_PACE, 0.4, 2.0)]
	return ["idle", 1.0]


## Zombies call this to decide whether this NPC is worth chasing.
func is_targetable() -> bool:
	return zombies_target and not is_dead


## The action shown in the "E: ..." prompt when you look at this NPC, e.g.
## "trade with Quartermaster". Empty means there's nothing to do with them.
## Subclasses override this; main.gd decides what pressing E actually opens.
func interact_prompt() -> String:
	return ""


## Hits from weapons (player or NPC). Same signature zombies use, so attackers
## don't need to care what they hit.
## Blood where it landed (on them and whatever's behind), a flinch, and the
## blow that knocks them over if it kills.
func take_hit(damage: float, from_pos: Vector3, knockback: float, attacker: Node3D = null, hit_pos := Vector3.INF) -> void:
	if is_dead or (attacker != null and attacker.is_in_group("player") and not player_can_hurt):
		return
	if hit_pos == Vector3.INF:
		hit_pos = global_position + Vector3(0, 1.2, 0)
	var dir := hit_pos - from_pos
	dir = dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.hit(get_parent(), hit_pos, dir, [get_rid()])
	body.wound(hit_pos, -dir)
	_last_blow = [dir * (40.0 + knockback * 25.0) + Vector3.UP * 10.0, hit_pos]
	if health > damage:
		body.one_shot("hit_" + body.zone_of(hit_pos))
	take_damage(damage)


## Raw damage, e.g. a zombie biting.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	_flash()
	if not body.is_busy() and health > 0.0:
		body.one_shot("hit_body")
	if health <= 0.0:
		die()


## They go limp and fall (a ragdoll), pushed by the blow that killed them.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false) # (it returned at once from now on anyway)
	health = 0.0
	talking = false
	remove_from_group("zombie_targets")
	remove_from_group("npcs")
	name_tag.visible = false
	collision.set_deferred("disabled", true) # deferred: physics may be mid-step
	if muzzle_flash:
		muzzle_flash.visible = false
	var blow: Array = _last_blow if not _last_blow.is_empty() else [Vector3.UP * 5.0, global_position + Vector3(0, 1.2, 0)]
	body.ragdoll(blow[0], blow[1], Vector3(velocity.x, 0.0, velocity.z))
	died.emit(self)


## Where shots come out of the rifle (its MuzzleFlash), in the world.
func muzzle() -> Vector3:
	return muzzle_flash.global_position if muzzle_flash else global_position + Vector3(0, 1.4, 0)


## A quick flash at the muzzle.
func _flash_muzzle() -> void:
	if muzzle_flash == null:
		return
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: muzzle_flash.visible = false)


## Turns the upper body up or down to aim at a point (the animation aims level).
func _aim_at(point: Vector3) -> void:
	var from := global_position + Vector3(0, 1.45, 0)
	var flat := Vector2(point.x - from.x, point.z - from.z).length()
	body.aim_pitch = clampf(atan2(point.y - from.y, maxf(flat, 0.1)), deg_to_rad(-60.0), deg_to_rad(60.0))


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


## Their model in their colors (the shirt and pants from outfit_color), what's
## under Visual put on the nearest bone, and the rifle in their hand.
func _setup_body() -> void:
	body.setup(model, HumanoidBody.PEOPLE_ANIMATIONS)
	body.set_colors(skin_color, outfit_color, outfit_color.darkened(0.35))
	body.settled.connect(func() -> void: Blood.pool(get_parent(), body.head_center().lerp(global_position, 0.6)))
	for extra in visual.get_children():
		if extra != body and extra is Node3D:
			var bone := body.nearest_bone((extra as Node3D).global_position)
			if bone >= 0:
				extra.reparent(body.attachment(bone))
	if holds_rifle:
		_take_rifle()


func _take_rifle() -> void:
	var hand := body.skeleton.find_bone("RightHand")
	var weapon := GameData.weapon("rifle")
	if hand < 0 or weapon == null or weapon.held_model == null:
		return
	rifle = weapon.held_model.instantiate()
	rifle.name = "Rifle"
	rifle.transform = rifle_hold
	body.attachment(hand).add_child(rifle)
	muzzle_flash = rifle.find_child("MuzzleFlash", true, false) as OmniLight3D
	if muzzle_flash == null: # a model without one
		muzzle_flash = OmniLight3D.new()
		muzzle_flash.position = Vector3(0, 0, -0.65)
		muzzle_flash.light_color = Color(1, 0.8, 0.5)
		muzzle_flash.light_energy = 5.0
		muzzle_flash.omni_range = 8.0
		rifle.add_child(muzzle_flash)
	muzzle_flash.visible = false


func _flash() -> void:
	create_tween().tween_method(body.set_flash, 1.0, 0.0, 0.25)
