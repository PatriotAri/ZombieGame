@tool
extends StaticBody3D
## A ground-floor pane of glass that zombies can smash. Glass blocks movement but
## not sight or bullets (it's on LAYER_GLASS, which the sight and shooting rays
## ignore). A zombie whose path runs through the window (world/fortifications.gd
## gives each one a NavigationLink) beats on it until it breaks, then climbs
## through. Planks over it (also fortifications.gd) stop all of that for good.
## One made in code (a building's) looks like world/props/window.tscn, or one of
## the building's Window Models, stretched to the opening (HOW_TO_MODEL.md,
## "Props"); its parts named Glass go when it's smashed. What stops you is
## always the pane's box (glass blocks you, not sight or bullets).

const GameData := preload("res://core/game_data.gd")
const ViewDistance := preload("res://core/view_distance.gd")
const VIEW_METERS := 70.0 # past this the glass isn't drawn (core/view_distance.gd)
const Sound := preload("res://core/sound.gd")
const WINDOW_PROP := preload("res://world/props/window.tscn")

const BASH_INTERVAL := 0.6 # seconds between audible blows, however many zombies are at it

## Can be boarded up with planks (fortifications.gd). Off for upstairs windows.
@export var boardable := true
## Planked shut when a new game starts (like the survivors' houses).
@export var boarded_at_start := false
var max_health := 60.0 # glass gives faster than a door (150)
var health := 60.0
var is_broken := false
var planked := false # set by fortifications.gd

var _mesh: MeshInstance3D # a pane in the map scene: its glass
var _look: KitProp # one made in code: its look
var _material: StandardMaterial3D
var _base_alpha := 0.22
var _next_bash_ms := 0


## Which way is outside: the pane's -X. fortifications.gd boards it from that side.
func outward() -> Vector3:
	return -global_basis.x


## Panes in the map scene come with their glass and collision already (made by
## setup when the town was frozen); this picks them up.
func _ready() -> void:
	if _mesh != null or _look != null:
		return
	for child in get_children():
		if child is MeshInstance3D:
			_mesh = child
			# Shared with every other pane of its color until this one cracks
			# (_crack). The map scene saved a copy with each pane: swap in the
			# shared one.
			_material = _shared(_mesh.mesh.surface_get_material(0) as StandardMaterial3D)
			_mesh.material_override = null
			_mesh.set_surface_override_material(0, _material)
			_base_alpha = _material.albedo_color.a
			ViewDistance.limit(_mesh, VIEW_METERS)
			return


## The pane's size (its collision box).
func pane_size() -> Vector3:
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size
	return Vector3.ZERO


## size: the pane (the opening: thickness, height, width); models: a building's
## Window Models (empty: the window prop's).
func setup(size: Vector3, models: Array = []) -> void:
	collision_layer = GameData.LAYER_GLASS
	_look = KitProp.make(WINDOW_PROP, models, Vector3(0.08, size.y, size.z))
	_look.name = "Look"
	add_child(_look)
	for mesh in _look.meshes():
		ViewDistance.limit(mesh, VIEW_METERS)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = "Collision"
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
	_crack()
	var now := Time.get_ticks_msec()
	if now >= _next_bash_ms:
		_next_bash_ms = now + int(BASH_INTERVAL * 1000.0)
		Sound.play_at(self, "glass_bash", global_position, -2.0, 25.0, 0.12)


func smash(silent := false) -> void:
	if is_broken:
		return
	is_broken = true
	health = 0.0
	if _look:
		_look.hide_part("Glass")
	else:
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
		_crack()


## One material per glass color, shared by every pane until it cracks.
static var _glass := {}


static func _shared(mat: StandardMaterial3D) -> StandardMaterial3D:
	var key := mat.albedo_color
	if not _glass.has(key):
		_glass[key] = mat
	return _glass[key]


## Cracks: it clouds over as it takes a beating. The first crack gives it its
## own material (until then it shares one with every other pane).
func _crack() -> void:
	if _look:
		_look.darken(0.35 * (1.0 - health / max_health))
		return
	if _mesh.material_override == null:
		_material = _material.duplicate()
		_mesh.material_override = _material
	_material.albedo_color.a = lerpf(0.75, _base_alpha, health / max_health)
