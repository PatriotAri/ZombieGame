extends GutTest
## core/sound.gd: players are used again, and at most MAX_WORLD_SOUNDS play out
## in the world at once, the nearest winning.

const Sound := preload("res://core/sound.gd")

var _camera: Camera3D


func before_each() -> void:
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_quiet() # (what earlier tests' games left playing would take up room)


func after_each() -> void:
	_camera.free()
	_quiet()


func _quiet() -> void:
	var pool := get_tree().root.get_node_or_null(Sound.POOL_NAME)
	if pool:
		for player in pool.get_children():
			player.call("stop")


func test_only_the_nearest_play_once_its_full() -> void:
	for meters in range(40, 0, -1): # farthest first, so the near ones have to push them out
		Sound.play_at(self, "door_open", Vector3(meters, 0, 0), 0.0, 100.0)
	assert_eq(Sound.world_sounds_playing(self), Sound.MAX_WORLD_SOUNDS)
	var farthest := 0.0
	for player in _world_players():
		if player.playing:
			farthest = maxf(farthest, player.global_position.x)
	assert_eq(farthest, float(Sound.MAX_WORLD_SOUNDS), "the 8 farthest made room")


func test_a_sound_farther_than_all_the_rest_isnt_played_when_full() -> void:
	for meters in range(1, Sound.MAX_WORLD_SOUNDS + 1):
		Sound.play_at(self, "door_open", Vector3(meters, 0, 0), 0.0, 100.0)
	Sound.play_at(self, "door_open", Vector3(90, 0, 0), 0.0, 100.0)
	for player in _world_players():
		assert_ne(player.global_position.x, 90.0)


func test_players_are_used_again() -> void:
	Sound.play_at(self, "door_open", Vector3(1, 0, 0), 0.0, 100.0)
	var made := _world_players().size()
	for player in _world_players():
		player.stop()
	Sound.play_at(self, "door_open", Vector3(2, 0, 0), 0.0, 100.0)
	assert_eq(_world_players().size(), made, "a stopped one played the new sound")


## The pool's world-sound players (it holds the UI ones too).
func _world_players() -> Array[AudioStreamPlayer3D]:
	var found: Array[AudioStreamPlayer3D] = []
	for node in get_tree().root.get_node(Sound.POOL_NAME).get_children():
		if node is AudioStreamPlayer3D:
			found.append(node)
	return found
