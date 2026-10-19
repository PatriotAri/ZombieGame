extends Node
## The woodworker the bandits are holding at their camp, and how he gets home.
##   CAPTIVE    - tied to a post at the bandit camp. Untie him (interact) and he
##                tells you who he is.
##   TRAVELLING - making his own way to the station. He leaves once you're out of
##                sight of him and of the station yard (so you never see him pop
##                between the two).
##   HOME       - at his workbench in the station yard. Bring him materials and
##                he makes scaffolding, guard posts, fences, fence gates and
##                garden plots (core/recipes.gd).
## Finding him there the first time is announced. main.gd creates it, sends the
## interaction here, and the quest follows along through the signals.
## Where he's tied up and where he works are SpawnPoints in the map scene
## (roles "woodworker_captive" and "woodworker_home").
## Saved: where he's got to, and whether you've found him at home.

signal freed
signal seen # the first time you find him in the station yard

const Woodworker := preload("res://characters/npcs/woodworker.gd")
const WoodworkerScene := preload("res://characters/npcs/woodworker.tscn")

const NAME := "Woodworker"
const OUT_OF_SIGHT := 40.0
const SEEN_DISTANCE := 25.0
const CHECK_INTERVAL := 0.5
const UNTIE_LINES: Array[String] = [
	"Easy... easy. You're not one of them.",
	"They grabbed me off the road a week back. Made me patch up their junk, kept me tied to this post the rest of the time.",
	"I'm a woodworker. Scaffolding, lookout posts, fences, gates. If it's made of wood, I can build it.",
	"The police station? Then that's where I'm going. Find me in the yard. I owe you one.",
]

var woodworker: Woodworker
var was_seen := false
var captive_spot := Transform3D.IDENTITY # tied to a post, behind the bandits' tents
var home_spot := Transform3D.IDENTITY # his workbench in the station yard
var _player: Node3D
var _dialogue: Node
var _post: Node3D
var _bench: Node3D
var _timer := 0.0


func setup(player: Node3D, dialogue: Node, captive: Transform3D, home: Transform3D) -> void:
	_player = player
	_dialogue = dialogue
	captive_spot = captive
	home_spot = home
	woodworker = WoodworkerScene.instantiate() as Woodworker
	get_parent().add_child(woodworker)
	_place(Woodworker.State.CAPTIVE)


func state() -> Woodworker.State:
	return woodworker.state


## Interact on him while he's tied up.
func untie() -> void:
	if woodworker.state != Woodworker.State.CAPTIVE:
		return
	_dialogue.call("start", NAME, UNTIE_LINES, _player, _on_untied)


func _on_untied() -> void:
	_place(Woodworker.State.TRAVELLING)
	freed.emit()


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var at := _player.global_position
	if woodworker.state == Woodworker.State.TRAVELLING and at.distance_to(woodworker.global_position) > OUT_OF_SIGHT \
			and at.distance_to(home_spot.origin) > OUT_OF_SIGHT:
		_place(Woodworker.State.HOME)
	if woodworker.state == Woodworker.State.HOME and not was_seen and at.distance_to(home_spot.origin) <= SEEN_DISTANCE:
		was_seen = true
		seen.emit()


func save_state() -> Dictionary:
	return {"state": woodworker.state, "seen": was_seen}


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return # nothing saved: still at the camp
	was_seen = bool(data.get("seen", false))
	var saved := int(data.get("state", Woodworker.State.CAPTIVE))
	_place(saved as Woodworker.State if saved >= 0 and saved < Woodworker.State.size() else Woodworker.State.CAPTIVE)


## Puts him where his state says, with the post or the workbench to match.
func _place(new_state: Woodworker.State) -> void:
	woodworker.state = new_state
	if new_state == Woodworker.State.HOME:
		woodworker.position = home_spot.origin
		woodworker.rotation.y = home_spot.basis.get_euler().y
		if _post:
			_post.queue_free()
			_post = null
		if _bench == null:
			# Behind him and to his left.
			_bench = _prop(Vector3(1.8, 0.9, 0.8), home_spot * Vector3(-1.4, 0.35, 1.8), Color(0.5, 0.36, 0.22),
					home_spot.basis.get_euler().y)
	elif new_state == Woodworker.State.CAPTIVE:
		woodworker.position = captive_spot.origin
		woodworker.rotation.y = captive_spot.basis.get_euler().y
		if _post == null: # the post he's tied to, at his back
			_post = _prop(Vector3(0.22, 2.2, 0.22), captive_spot * Vector3(0, 1.0, 0.45), Color(0.33, 0.24, 0.16))
	# TRAVELLING: he stays put until you're out of sight (see _process).


func _prop(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	body.add_child(inst)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	get_parent().add_child(body)
	return body
