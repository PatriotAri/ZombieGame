extends StaticBody3D
## A ground-floor pane of glass that zombies can smash. Glass blocks movement but
## not sight or bullets (it's on LAYER_GLASS, which the sight and shooting rays
## ignore). A zombie whose path runs through the window (world/fortifications.gd
## gives each one a NavigationLink) beats on it until it breaks, then climbs
## through. Planks over it (also fortifications.gd) stop all of that for good.

const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")

const BASH_INTERVAL := 0.6 # seconds between audible blows, however many zombies are at it

var max_health := 60.0 # glass gives faster than a door (150)
var health := 60.0
var is_broken := false
var planked := false # set by fortifications.gd

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_alpha := 0.22
var _next_bash_ms := 0


func setup(size: Vector3, color: Color) -> void:
	collision_layer = GameData.LAYER_GLASS
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.roughness = 0.1
	_base_alpha = color.a
	var box := BoxMesh.new()
	box.size = size
	box.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # let sunlight in
	add_child(_mesh)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)


func can_be_bashed() -> bool:
	return not is_broken and not planked


## Zombies can climb through once it's broken, unless it's been boarded up.
func is_passable() -> bool:
	return is_broken and not planked


## Called every physics frame by each zombie beating on it.
func bash(damage: float) -> void:
	if not can_be_bashed():
		return
	health -= damage
	if health <= 0.0:
		smash()
		return
	# Cracks: it clouds over as it takes a beating.
	_material.albedo_color.a = lerpf(0.75, _base_alpha, health / max_health)
	var now := Time.get_ticks_msec()
	if now >= _next_bash_ms:
		_next_bash_ms = now + int(BASH_INTERVAL * 1000.0)
		Sound.play_at(self, "glass_bash", global_position, -2.0, 25.0, 0.12)


func smash(silent := false) -> void:
	if is_broken:
		return
	is_broken = true
	health = 0.0
	_mesh.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true) # deferred: may be mid-physics
	if not silent:
		Sound.play_at(self, "glass_break", global_position, 2.0, 40.0, 0.1)


func save_state() -> Dictionary:
	return {"health": health, "broken": is_broken}


func load_state(data: Dictionary) -> void:
	health = float(data.get("health", max_health))
	if bool(data.get("broken", false)):
		smash(true)
	elif health < max_health:
		_material.albedo_color.a = lerpf(0.75, _base_alpha, health / max_health)
