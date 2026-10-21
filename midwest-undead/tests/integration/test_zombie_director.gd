extends GutTest
## world/zombies.gd giving out the zombies' turns, in the real game scene:
## far ones glide and stay on the ground, doors and windows stop that, every
## one gets its turn however small the budget, and a far body out of sight
## holds still.

const MainScene := preload("res://world/main.tscn")
const Zombie := preload("res://characters/zombie/zombie.gd")
const Ground := preload("res://world/ground.gd")
const Door := preload("res://world/door.gd")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	main.extra_zombies = 0
	main.zombie_population = 0
	add_child(main)


func after_each() -> void:
	main.queue_free()


func _add(offset: Vector3) -> Zombie:
	return main.zombies.add(Ground.snap(main.player.global_position + offset, 0.1))


func test_far_zombies_glide_and_stay_on_the_ground() -> void:
	var far := _add(Vector3(90, 0, 0)) # (gliding range: past GLIDE_DISTANCE, short of turning into data)
	far.roaming = true
	far.wander_target = Ground.snap(far.global_position + Vector3(0, 0, 30), 0.1)
	var glided := 0
	for i in 300:
		await wait_physics_frames(1)
		glided += main.zombies.glides
	assert_gt(glided, 0, "it glided")
	var ground := Ground.height_at(far.global_position)
	assert_almost_eq(far.global_position.y, ground, 0.7, "on the ground (give or take the glide lift)")


func test_near_a_door_or_window_it_doesnt_glide() -> void:
	main.zombies._add_opening(Vector3(300, 0, 300), autofree(Door.new()))
	assert_true(main.zombies._near_opening(Vector3(301.5, 0, 300)))
	assert_false(main.zombies._near_opening(Vector3(310, 0, 300)))


func test_every_zombie_gets_its_turn_however_small_the_budget() -> void:
	main.zombies.budget_usec = 0
	var crowd: Array[Zombie] = []
	for i in 20:
		crowd.append(_add(Vector3(70 + i * 2, 0, 20)))
	await wait_physics_frames(60)
	for zombie in crowd:
		assert_lt(zombie.frames_waited, 60, "had a turn in the last second")


func test_a_far_body_out_of_sight_holds_still() -> void:
	var near := _add(Vector3(10, 0, 0))
	var far := _add(Vector3(90, 0, 0))
	await wait_physics_frames(5)
	var near_at: float = near.body.animator.current_animation_position
	var far_at: float = far.body.animator.current_animation_position
	await wait_physics_frames(30)
	assert_ne(near.body.animator.current_animation_position, near_at, "near: animated")
	assert_eq(far.body.animator.current_animation_position, far_at, "far and off screen: held")
