extends GutTest
## Zombies far off becoming data only (world/zombies.gd, Dormant), in the real
## game scene: who does, what they do meanwhile, and coming back.

const MainScene := preload("res://world/main.tscn")
const Zombie := preload("res://characters/zombie/zombie.gd")
const GuardScene := preload("res://characters/npcs/guard.tscn") # (zombies go for guards and bandits, not traders or survivors)
const Ground := preload("res://world/ground.gd")
const SaveIO := preload("res://world/save_io.gd")
const Zombies := preload("res://world/zombies.gd")
const Door := preload("res://world/door.gd")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	main.extra_zombies = 0
	main.zombie_population = 0
	add_child(main)
	main.player.set_physics_process(false) # stays where it is


func after_each() -> void:
	main.queue_free()


## A spot this far behind you (out of your sight), on the ground.
func _behind(meters: float) -> Vector3:
	return Ground.snap(main.player.global_position + main.player.global_basis.z * meters, 0.1)


func _a_step() -> void:
	await wait_physics_frames(int(Zombies.STEP * Engine.physics_ticks_per_second) + 5)


func test_far_and_out_of_sight_it_becomes_data_and_keeps_roaming() -> void:
	var zombie: Zombie = main.zombies.add(_behind(150.0))
	zombie.roam_chance_day = 1.0 # (sets off whenever it can)
	zombie.roam_chance_night = 1.0
	await _a_step()
	assert_false(is_instance_valid(zombie) and zombie in main.zombies.all, "no longer a zombie in the game")
	assert_eq(main.zombies.dormant.size(), 1)
	var d: Zombies.Dormant = main.zombies.dormant[0]
	var was := d.position
	for i in 15:
		await _a_step()
	assert_gt(d.position.distance_to(was), 1.0, "roamed on")
	assert_eq(main.zombies.alive_count(), 1, "still counted")


func test_near_you_again_it_is_a_zombie_again() -> void:
	main.zombies.add(_behind(150.0))
	await _a_step()
	assert_eq(main.zombies.dormant.size(), 1)
	var d: Zombies.Dormant = main.zombies.dormant[0]
	main.player.global_position = d.position + main.player.global_basis.z * -50.0 # 50 m away, facing off
	await _a_step()
	assert_eq(main.zombies.dormant.size(), 0)
	assert_eq(main.zombies.all.size(), 1)
	assert_almost_eq(main.zombies.all[0].global_position.distance_to(d.position), 0.0, 0.5, "where the data was")


func test_near_people_it_stays_a_zombie() -> void:
	var at := _behind(150.0)
	var guard := GuardScene.instantiate()
	guard.fire_range = 0.0 # (it's only there to be near: nobody shoots)
	main.people.add_child(guard)
	guard.global_position = at + Vector3(10, 0, 0)
	var zombie: Zombie = main.zombies.add(at)
	zombie.sight_range = 0.1 # (and nobody sees anybody: it stays idle)
	await _a_step()
	assert_false(zombie.is_dead)
	assert_eq(zombie.state, Zombie.State.IDLE)
	assert_true(zombie in main.zombies.all, "people near: stays real")
	assert_eq(main.zombies.dormant.size(), 0)


func test_data_zombies_are_saved() -> void:
	main.zombies.add(_behind(150.0))
	main.zombies.add(_behind(5.0) + Vector3(5, 0, 0)) # near you: stays a zombie
	await _a_step()
	assert_eq(main.zombies.dormant.size(), 1)
	var saved: Array = SaveIO.collect(main)["sections"]["zombies"]
	assert_eq(saved.size(), 2, "the real one and the data one")


func test_a_data_zombie_on_a_horde_march_counts_as_marching() -> void:
	var zombie: Zombie = main.zombies.add(_behind(150.0))
	zombie.march_to = _behind(400.0)
	await _a_step()
	assert_eq(main.zombies.dormant.size(), 1)
	assert_true(main.zombies.any_marching())


func test_a_door_thats_shut_stops_a_data_zombie_an_open_one_doesnt() -> void:
	var door: Node3D = autofree(Door.new())
	main.zombies._add_opening(Vector3(300, 0, 300), door)
	var toward := [Vector3(303, 0, 300), Vector3(301, 0, 300)] # stepping closer
	assert_true(main.zombies._blocked_step(toward[0], toward[1]), "shut: stopped")
	assert_false(main.zombies._blocked_step(toward[1], toward[0]), "stepping away: fine")
	door.is_open = true
	assert_false(main.zombies._blocked_step(toward[0], toward[1]), "open: through")


func test_without_a_way_to_tell_what_you_can_see_nobody_becomes_data() -> void:
	main.zombies.seen = Callable()
	main.zombies.add(_behind(150.0))
	await _a_step()
	assert_eq(main.zombies.dormant.size(), 0)
