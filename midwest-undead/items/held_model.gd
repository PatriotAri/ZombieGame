extends Node3D
## One weapon in your hands, in first person, and its animations: drawing and
## putting it away, firing, reloading and swinging. characters/player/hands.gd
## makes one per weapon (and one for your fists) and says when to play what.
##
## Three layers, so the movements add up instead of fighting:
##   this node    where the weapon is held (hands.gd moves it to the aiming spot)
##   └ Kick       recoil: jerks up and back on each shot, then settles
##     └ Motion   reload tilt and melee swings
##       └ the model (the weapon's held_model scene, or a box)
##
## A model can bring its own animations: an AnimationPlayer anywhere in it (a
## .glb made in Blender brings one) with animations named draw, holster, fire,
## reload or swing. Each one it has is played instead of the code's version,
## sped up or slowed down to fit the time the game allows (draw: the weapon's
## draw_time; reload: its reload_time; fire: its cooldown, if longer). Recoil,
## sway and bob are always code.
##
## For what the model has no animation for, the code moves its parts, found by
## name anywhere in the model (all optional):
##   Slide        snaps back on each shot; stays back once the gun is empty
##   Pump         racks back and forward after each shot
##   Bolt         after each shot: lifts, pulls back, pushes forward, drops.
##                Open while reloading. Put its origin on the barrel's line.
##   Magazine     drops out and a fresh one goes in when reloading
##   LoadingPort  (a Marker3D) with no Magazine: rounds go in here one at a
##                time when reloading
##   MuzzleFlash  (an OmniLight3D) flashes on each shot
##   Sight        (a Marker3D) the point that lines up with the middle of the
##                screen when aiming; without one, aiming uses AIM_SPOT
## See HOW_TO_MODEL.md.

const GameData := preload("res://core/game_data.gd")

const AIM_SPOT := Vector3(0.0, -0.16, -0.4) # where a gun with no Sight sits when aiming
const AIM_DISTANCE := 0.3 # meters ahead of your eye a Sight lines up
const SLIDE_TRAVEL := 0.035
const PUMP_TRAVEL := 0.09
const BOLT_TRAVEL := 0.07
const BOLT_LIFT := 60.0 # degrees
const MAGAZINE_DROP := Vector3(0.0, -0.2, 0.0)
const RELOAD_TILT := Vector3(10.0, 12.0, 35.0) # degrees: nose up a little, turned in and canted over
const SWING_TO := Vector3(-70.0, 25.0, 0.0)
const SWING_HIT := 0.08 # seconds from the start of a swing to when it lands
const SWING_BACK := 0.25

var weapon: WeaponData # null for fists
var hold_position := Vector3.ZERO # where it sits at the hip
var aim_position := AIM_SPOT
var kick: Node3D
var motion: Node3D
var model: Node3D
var anim: AnimationPlayer # the model's own, or null
var parts := {} # part name -> Node3D
var _rest := {} # part name -> its Transform3D at rest
var _round: MeshInstance3D # the round you see going in, one at a time (LoadingPort)
var _recoil := Vector3.ZERO # degrees: x up, y sideways, z roll
var _recoil_back := 0.0 # meters toward you
var _recover_rate := 10.0
var _fire_tween: Tween
var _reload_tween: Tween
var _parts_tween: Tween
var _swing_tween: Tween
var _empty := false # the slide stays back


## instance: the model; weapon: its file (null for fists).
func setup(instance: Node3D, weapon_data: WeaponData, at: Vector3) -> void:
	weapon = weapon_data
	hold_position = at
	position = at
	kick = Node3D.new()
	kick.name = "Kick"
	add_child(kick)
	motion = Node3D.new()
	motion.name = "Motion"
	kick.add_child(motion)
	model = instance
	if model.get_parent():
		model.reparent(motion, false)
	else:
		motion.add_child(model)
	anim = _find_animation_player(model)
	for part_name in ["Slide", "Pump", "Bolt", "Magazine", "LoadingPort", "MuzzleFlash", "Sight"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			parts[part_name] = part
			_rest[part_name] = part.transform
	if parts.has("Sight"):
		# Aiming puts the Sight AIM_DISTANCE straight ahead of your eye.
		var sight := _relative_to(parts["Sight"], motion).origin
		aim_position = Vector3(0.0, 0.0, -AIM_DISTANCE) - sight
	if parts.has("LoadingPort"):
		_round = _make_round()
		(parts["LoadingPort"] as Node3D).add_child(_round)


func _process(delta: float) -> void:
	if _recoil == Vector3.ZERO and _recoil_back == 0.0:
		return
	var keep := exp(-_recover_rate * delta)
	_recoil *= keep
	_recoil_back *= keep
	if _recoil.length() < 0.01 and _recoil_back < 0.0001:
		_recoil = Vector3.ZERO
		_recoil_back = 0.0
	kick.rotation_degrees = _recoil
	kick.position = Vector3(0.0, 0.0, _recoil_back)


# --- The model's own animations ------------------------------------------------

## The model's animation for this action ("fire", "reload"...), or "". Names
## from Blender can come with a prefix ("Armature|reload", "weapons/reload").
func animation_for(action: String) -> String:
	if anim == null:
		return ""
	for full_name in anim.get_animation_list():
		var lower := String(full_name).to_lower()
		if lower == action or lower.ends_with("|" + action) or lower.ends_with("/" + action):
			return full_name
	return ""


## Plays the model's animation for action, if it has one, fitted to fit_time
## seconds (0: as made). Returns whether it did.
func _play(action: String, fit_time := 0.0, only_if_longer := false) -> bool:
	var found := animation_for(action)
	if found == "":
		return false
	var length := anim.get_animation(found).length
	var speed := 1.0
	if fit_time > 0.0 and length > 0.0 and (not only_if_longer or length > fit_time):
		speed = length / fit_time
	anim.stop()
	anim.play(found, -1, speed)
	return true


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


# --- Drawing and putting away --------------------------------------------------

## Returns whether the model has its own animation for it (if not, hands.gd
## lowers or raises everything in your hands instead).
func draw(time: float) -> bool:
	return _play("draw", time)


func holster(time: float) -> bool:
	return _play("holster", time)


# --- Firing --------------------------------------------------------------------

## A shot. empty: that was the last round (the slide stays back).
func fire(empty: bool) -> void:
	_add_recoil()
	_flash()
	if _play("fire", weapon.cooldown, true):
		return
	_kill(_fire_tween)
	_reset_part("Slide")
	_reset_part("Pump")
	_reset_part("Bolt")
	if not (parts.has("Slide") or parts.has("Pump") or parts.has("Bolt")):
		return # nothing to move (an empty tween is an error)
	_fire_tween = create_tween()
	var length := 0.0
	if parts.has("Slide"):
		_fire_tween.tween_property(parts["Slide"], "position", _slid("Slide", SLIDE_TRAVEL), 0.03)
		length += 0.03
		if not empty:
			_fire_tween.tween_property(parts["Slide"], "position", _slid("Slide", 0.0), 0.07)
			length += 0.07
	if parts.has("Pump"):
		_fire_tween.tween_interval(0.25)
		_fire_tween.tween_property(parts["Pump"], "position", _slid("Pump", PUMP_TRAVEL), 0.12)
		_fire_tween.tween_property(parts["Pump"], "position", _slid("Pump", 0.0), 0.12)
		length += 0.49
	if parts.has("Bolt"):
		_fire_tween.tween_interval(0.35)
		_cycle_bolt(_fire_tween, 0.1)
		length += 0.35 + 0.4
	# Always done before you can fire again.
	if length > weapon.cooldown * 0.9:
		_fire_tween.set_speed_scale(length / (weapon.cooldown * 0.9))
	_empty = empty and parts.has("Slide")


## The slide back (empty) or home, without animating: a gun you switch to or load.
func set_empty(empty: bool) -> void:
	_empty = empty and parts.has("Slide")
	if parts.has("Slide"):
		(parts["Slide"] as Node3D).position = _slid("Slide", SLIDE_TRAVEL if _empty else 0.0)


func _add_recoil() -> void:
	var k := weapon.kick
	_recoil += Vector3(k, randf_range(-0.15, 0.15) * k, randf_range(-0.2, 0.2) * k)
	_recoil_back += k * 0.003 # 18 degrees of kick: about 5 cm back
	# Most of the way back in 0.15 s plus a bit more for a bigger kick.
	_recover_rate = 3.0 / (0.15 + k / 100.0)


func _flash() -> void:
	var flash := parts.get("MuzzleFlash") as Node3D
	if flash:
		flash.visible = true
		get_tree().create_timer(0.05).timeout.connect(func() -> void: flash.visible = false)


# --- Reloading -----------------------------------------------------------------

## A reload taking time seconds, putting in rounds rounds.
func reload(time: float, rounds: int) -> void:
	cancel_reload()
	if _play("reload", time):
		return
	var move := minf(0.15, time * 0.1)
	_reload_tween = create_tween()
	_reload_tween.tween_property(motion, "rotation_degrees", RELOAD_TILT, 0.25)
	_reload_tween.tween_interval(maxf(time - 0.5, 0.0))
	_reload_tween.tween_property(motion, "rotation_degrees", Vector3.ZERO, 0.25)
	if not (parts.has("Magazine") or parts.has("Bolt") or parts.has("LoadingPort")):
		return
	# The parts, on their own timeline: moments are fractions of the whole reload.
	_parts_tween = create_tween()
	var at := 0.0
	if parts.has("Bolt"):
		_parts_tween.tween_interval(time * 0.08)
		_parts_tween.tween_property(parts["Bolt"], "rotation_degrees", _turned("Bolt", BOLT_LIFT), move)
		_parts_tween.tween_property(parts["Bolt"], "position", _slid("Bolt", BOLT_TRAVEL), move)
		at = time * 0.08 + move * 2.0
	if parts.has("Magazine"):
		var mag := parts["Magazine"] as Node3D
		var rest: Transform3D = _rest["Magazine"]
		_parts_tween.tween_interval(maxf(time * 0.15 - at, 0.0))
		_parts_tween.tween_property(mag, "position", rest.origin + MAGAZINE_DROP, move)
		_parts_tween.tween_callback(mag.hide)
		_parts_tween.tween_interval(maxf(time * 0.55 - time * 0.15 - move, 0.0))
		_parts_tween.tween_callback(mag.show)
		_parts_tween.tween_property(mag, "position", rest.origin, move)
		at = time * 0.55 + move
	elif _round:
		var start := maxf(at, time * 0.25)
		var gap := maxf(time * 0.75 - start, 0.1) / maxf(rounds, 1)
		_parts_tween.tween_interval(maxf(start - at, 0.0))
		for i in maxi(rounds, 1):
			_parts_tween.tween_callback(func() -> void:
				_round.position = Vector3(0.0, -0.07, 0.04)
				_round.show())
			_parts_tween.tween_property(_round, "position", Vector3.ZERO, gap * 0.6)
			_parts_tween.tween_callback(_round.hide)
			_parts_tween.tween_interval(gap * 0.4)
		at = start + gap * maxi(rounds, 1)
	if parts.has("Bolt"):
		_parts_tween.tween_interval(maxf(time * 0.8 - at, 0.0))
		_parts_tween.tween_property(parts["Bolt"], "position", _slid("Bolt", 0.0), move)
		_parts_tween.tween_property(parts["Bolt"], "rotation_degrees", _turned("Bolt", 0.0), move)
		at = time * 0.8 + move * 2.0
	if _empty:
		_parts_tween.tween_interval(maxf(time * 0.85 - at, 0.0))
		_parts_tween.tween_property(parts["Slide"], "position", _slid("Slide", 0.0), 0.06)
		_parts_tween.tween_callback(func() -> void: _empty = false)


## Stops a reload partway (or tidies up after one): everything back in place.
func cancel_reload() -> void:
	_kill(_reload_tween)
	_kill(_parts_tween)
	if animation_for("reload") != "" and anim.current_animation == animation_for("reload"):
		anim.stop()
	motion.rotation_degrees = Vector3.ZERO
	_reset_part("Magazine")
	_reset_part("Bolt")
	if _round:
		_round.hide()
	set_empty(_empty)


# --- Swinging (melee and fists) ------------------------------------------------

## A swing; hit is called the moment it lands.
func swing(hit: Callable) -> void:
	_kill(_swing_tween)
	_swing_tween = create_tween()
	if _play("swing", weapon.cooldown if weapon else 0.0, true):
		_swing_tween.tween_interval(SWING_HIT)
		_swing_tween.tween_callback(hit)
		return
	_swing_tween.tween_property(motion, "rotation_degrees", SWING_TO, SWING_HIT)
	_swing_tween.tween_callback(hit)
	_swing_tween.tween_property(motion, "rotation_degrees", Vector3.ZERO, SWING_BACK)


# --- Helpers -------------------------------------------------------------------

## A part's rest position moved back toward you (+z, the model's back) by travel.
func _slid(part_name: String, travel: float) -> Vector3:
	var rest: Transform3D = _rest[part_name]
	return rest.origin + rest.basis.z * travel


## A part's rest rotation turned about the barrel (z) by degrees.
func _turned(part_name: String, degrees: float) -> Vector3:
	var rest: Transform3D = _rest[part_name]
	return rest.basis.get_euler() * (180.0 / PI) + Vector3(0.0, 0.0, degrees)


func _cycle_bolt(tween: Tween, step: float) -> void:
	tween.tween_property(parts["Bolt"], "rotation_degrees", _turned("Bolt", BOLT_LIFT), step)
	tween.tween_property(parts["Bolt"], "position", _slid("Bolt", BOLT_TRAVEL), step)
	tween.tween_property(parts["Bolt"], "position", _slid("Bolt", 0.0), step)
	tween.tween_property(parts["Bolt"], "rotation_degrees", _turned("Bolt", 0.0), step)


func _reset_part(part_name: String) -> void:
	if parts.has(part_name):
		var part := parts[part_name] as Node3D
		part.transform = _rest[part_name]
		part.show()


## node's transform as seen from ancestor (works before either is in the tree).
static func _relative_to(node: Node3D, ancestor: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var at: Node = node
	while at and at != ancestor:
		if at is Node3D:
			xform = (at as Node3D).transform * xform
		at = at.get_parent()
	return xform


func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


## A shell or cartridge: a little cylinder lying along the barrel, the color of
## the ammo item.
func _make_round() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	var ammo := GameData.item(weapon.ammo) if weapon else null
	mat.albedo_color = ammo.color if ammo else Color(0.7, 0.55, 0.2)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.011
	mesh.bottom_radius = 0.011
	mesh.height = 0.06
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.name = "Round"
	inst.mesh = mesh
	inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visible = false
	return inst

