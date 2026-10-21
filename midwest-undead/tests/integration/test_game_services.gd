extends GutTest
## The pieces main.gd puts together (world/game_map.gd, world/zombies.gd,
## world/people.gd, ui/game_ui.gd), working with each other in the real game
## scene.

const MainScene := preload("res://world/main.tscn")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const Zombie := preload("res://characters/zombie/zombie.gd")
const SaveIO := preload("res://world/save_io.gd")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	add_child(main)


func after_each() -> void:
	main.queue_free()


func test_the_map_knows_where_you_start() -> void:
	var start: Node3D = main.map.spawn_point("player")
	assert_not_null(start)
	assert_eq(main.map.player_spawn.origin, start.global_position)
	assert_eq(main.player.global_position, start.global_position)


func test_zombies_added_are_counted_and_saved() -> void:
	var before: int = main.zombies.all.size()
	var zombie: Zombie = main.zombies.add(main.player.global_position + Vector3(30, 0, 0))
	assert_eq(main.zombies.all.size(), before + 1)
	assert_eq(zombie.get_parent(), main.zombies)
	var saved: Array = SaveIO.collect(main)["sections"]["zombies"]
	assert_eq(saved.size(), before + 1, "every one still up")


func test_a_zombie_after_you_holds_off_the_autosave() -> void:
	assert_false(main._player_threatened())
	var zombie: Zombie = main.zombies.add(main.player.global_position + Vector3(30, 0, 0))
	zombie.state = Zombie.State.HUNT
	zombie.target = main.player
	assert_true(main._player_threatened())


func test_talking_to_someone_goes_to_the_people() -> void:
	var chief := PoliceChiefScene.instantiate()
	main.people.add_child(chief)
	Interactable.of(chief).interact(main.player)
	assert_true(chief.talking, "people.gd took it from there")


func test_dying_shows_the_death_screen_and_frees_the_mouse() -> void:
	main.player.take_damage(10000.0)
	assert_true(main.player.is_dead)
	assert_true(main.ui.hud.message_label.visible)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func test_a_zombie_near_a_noise_comes_to_look() -> void:
	var near: Zombie = main.zombies.add(main.player.global_position + Vector3(15, 0, 0))
	var far: Zombie = main.zombies.add(main.player.global_position + Vector3(200, 0, 0))
	main.player.make_noise(30.0)
	assert_eq(near.state, Zombie.State.INVESTIGATE)
	assert_ne(far.state, Zombie.State.INVESTIGATE)
