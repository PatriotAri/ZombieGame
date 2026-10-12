extends Node
## The woodworker the bandits are holding at their camp, and how he gets home.
##   CAPTIVE    - tied to a post at the bandit camp. Untie him (interact) and he
##                tells you who he is.
##   TRAVELLING - making his own way to the station. He leaves once you're out of
##                sight of him and of the station yard (so you never see him pop
##                between the two).
##   HOME       - at his workbench in the station yard, selling scaffolding, guard
##                posts, fences and fence gates (world/structures.gd).
## Finding him there the first time is announced. main.gd creates it, sends the
## interaction here, and the quest follows along through the signals.
## Saved: where he's got to, whether you've found him at home, and his stock.

signal freed
signal seen # the first time you find him in the station yard

const Woodworker := preload("res://characters/npcs/woodworker.gd")
const WoodworkerScene := preload("res://characters/npcs/woodworker.tscn")
const BanditCamp := preload("res://world/areas/bandit_camp.gd")

const NAME := "Woodworker"
const CAPTIVE_SPOT := BanditCamp.CAMP_CENTER + Vector3(2.5, 0.1, -7.0) # behind the tents, tied up
const HOME_SPOT := Vector3(39.0, 0.1, 15.0) # the station yard's west strip
const OUT_OF_SIGHT := 40.0
const SEEN_DISTANCE := 25.0
const CHECK_INTERVAL := 0.5
const UNTIE_LINES: Array[String] = [
	"Easy... easy. You're not one of them.",
	"They grabbed me off the road a week back. Made me patch up their junk, kept me tied to this post the rest of the time.",
	"I'm a woodworker. Scaffolding, lookout posts, fences, gates. If it's made of wood, I can build it.",
	"The police station? Then that's where I'm going. Find me in the yard. I owe you one.",
]
const HOME_STORY := "The woodworker has set up in the station yard.\nScaffolding, guard posts and fences are for sale."

var woodworker: Woodworker
var was_seen := false
var _player: Node3D
var _dialogue: Node
var _post: Node3D
var _bench: Node3D
var _timer := 0.0


func setup(player: Node3D, day_night: Node, dialogue: Node) -> void:
	_player = player
	_dialogue = dialogue
	woodworker = WoodworkerScene.instantiate() as Woodworker
	woodworker.day_night = day_night # restocks each morning, once he's home
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
			and at.distance_to(HOME_SPOT) > OUT_OF_SIGHT:
		_place(Woodworker.State.HOME)
	if woodworker.state == Woodworker.State.HOME and not was_seen and at.distance_to(HOME_SPOT) <= SEEN_DISTANCE:
		was_seen = true
		seen.emit()


func save_state() -> Dictionary:
	return {"state": woodworker.state, "seen": was_seen, "stock": woodworker.stock.to_dict(),
			"restocked_day": woodworker.restocked_day}


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return # older saves: still at the camp
	was_seen = bool(data.get("seen", false))
	var saved := int(data.get("state", Woodworker.State.CAPTIVE))
	_place(saved as Woodworker.State if saved >= 0 and saved < Woodworker.State.size() else Woodworker.State.CAPTIVE)
	if data.has("stock"):
		woodworker.stock.from_dict(data["stock"])
	woodworker.restocked_day = int(data.get("restocked_day", woodworker.restocked_day))


## Puts him where his state says, with the post or the workbench to match.
func _place(new_state: Woodworker.State) -> void:
	woodworker.state = new_state
	if new_state == Woodworker.State.HOME:
		woodworker.position = HOME_SPOT
		woodworker.rotation.y = 0.0 # facing the front yard, where you come in
		if _post:
			_post.queue_free()
			_post = null
		if _bench == null:
			_bench = _prop(Vector3(1.8, 0.9, 0.8), HOME_SPOT + Vector3(-1.4, 0.35, 1.8), Color(0.5, 0.36, 0.22))
		# The day he arrives counts as restocked; his first restock is the next morning.
		woodworker.restocked_day = int(woodworker.day_night.get("day")) if woodworker.day_night else 1
	elif new_state == Woodworker.State.CAPTIVE:
		woodworker.position = CAPTIVE_SPOT
		woodworker.rotation.y = PI # facing into the camp
		if _post == null:
			_post = _prop(Vector3(0.22, 2.2, 0.22), CAPTIVE_SPOT + Vector3(0, 1.0, -0.45), Color(0.33, 0.24, 0.16))
	# TRAVELLING: he stays put until you're out of sight (see _process).


func _prop(size: Vector3, pos: Vector3, color: Color) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
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
