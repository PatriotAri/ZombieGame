extends GutTest
## world/hearing.gd: a noise only reaches the listeners near enough.

const Hearing := preload("res://world/hearing.gd")


## Counts what it's asked about (as a zombie or bandit would be).
class Listener extends Node3D:
	var asked := 0

	func _ready() -> void:
		add_to_group(Hearing.LISTENERS)

	func hear_noise(_pos: Vector3, _radius: float) -> void:
		asked += 1


func _listener(at: Vector3) -> Listener:
	var listener := Listener.new()
	add_child_autofree(listener)
	listener.global_position = at
	return listener


func test_only_the_listeners_near_a_noise_are_asked() -> void:
	add_child_autofree(Hearing.new())
	var near := _listener(Vector3(10, 0, 0))
	var far := _listener(Vector3(500, 0, 0))
	Hearing.make_noise(self, Vector3.ZERO, 25.0)
	assert_eq(near.asked, 1)
	assert_eq(far.asked, 0)


func test_a_noise_near_the_edge_of_a_cell_reaches_the_next_one() -> void:
	add_child_autofree(Hearing.new())
	var across := _listener(Vector3(Hearing.CELL + 5.0, 0, 0)) # the next cell over
	Hearing.make_noise(self, Vector3(Hearing.CELL - 5.0, 0, 0), 15.0)
	assert_eq(across.asked, 1)


func test_a_very_loud_noise_asks_everyone() -> void:
	add_child_autofree(Hearing.new())
	var far := _listener(Vector3(2000, 0, 0))
	Hearing.make_noise(self, Vector3.ZERO, Hearing.WIDE + 1.0)
	assert_eq(far.asked, 1)


func test_without_hearing_every_listener_is_asked() -> void:
	var far := _listener(Vector3(500, 0, 0))
	Hearing.make_noise(self, Vector3.ZERO, 25.0)
	assert_eq(far.asked, 1)
