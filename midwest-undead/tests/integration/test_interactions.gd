extends GutTest
## Everything you can use, in the real game scene: each kind is put down next
## to you and used through its Interactable (components/interactable.gd), the
## way pressing interact does. A ground item and a container go the whole way:
## you look at them and press interact.

const MainScene := preload("res://world/main.tscn")
const PoliceChiefScene := preload("res://characters/npcs/police_chief.tscn")
const SupplyCrate := preload("res://world/kit/furniture/supply_crate.tscn")
const Door := preload("res://world/door.gd")
const SavePoint := preload("res://world/save_point.gd")
const BulletinBoard := preload("res://world/bulletin_board.gd")
const Player := preload("res://characters/player/player.gd")

var main: Node
var player: Player


func before_all() -> void:
	main = MainScene.instantiate()
	add_child(main)
	player = main.player


func after_all() -> void:
	main.queue_free()


func after_each() -> void:
	for menu: Node in [main.inventory_menu, main.save_menu, main.choice_menu, main.dialogue, main.shop_menu]:
		menu.call("close")


## A spot on the ground a few meters to your side: out of your way, and out of
## the way of the other tests' things.
func _beside(meters: float) -> Vector3:
	return player.global_position + player.global_basis.x * meters


## Where you're looking, this far ahead.
func _ahead(meters: float) -> Vector3:
	return player.camera.global_position - player.camera.global_basis.z * meters


func _use(thing: Node) -> void:
	Interactable.of(thing).interact(player)


func test_looking_at_a_ground_item_and_pressing_interact_picks_it_up() -> void:
	var before := player.inventory.count("canned_food")
	main.add_ground_item("canned_food", 2, _ahead(1.2) - Vector3.UP * 0.15, 0.0)
	await wait_physics_frames(2)
	player.call("_update_prompt")
	assert_string_contains(player.prompt_text, "pick up")
	player.call("_interact")
	assert_eq(player.inventory.count("canned_food"), before + 2)


func test_looking_at_a_container_and_pressing_interact_opens_it() -> void:
	var crate := SupplyCrate.instantiate()
	main.add_child(crate)
	crate.global_position = _ahead(1.5) - Vector3.UP * 0.45
	await wait_physics_frames(2)
	player.call("_update_prompt")
	assert_string_contains(player.prompt_text, "search Supply crate")
	watch_signals(player)
	player.call("_interact")
	assert_signal_emitted_with_parameters(player, "container_opened", [crate])
	assert_true(crate.opened)
	crate.queue_free()


func test_a_door_opens_and_shuts() -> void:
	var door := Door.new()
	main.add_child(door)
	door.global_position = _beside(6.0)
	assert_eq(Interactable.of(door).get_prompt(), "open the door")
	_use(door)
	assert_true(door.is_open)
	assert_eq(Interactable.of(door).get_prompt(), "close the door")
	_use(door)
	assert_false(door.is_open)
	door.queue_free()


func test_the_logbook_asks_for_the_save_menu() -> void:
	var logbook := SavePoint.new()
	main.add_child(logbook)
	watch_signals(player)
	_use(logbook)
	assert_signal_emitted(player, "save_menu_requested")
	logbook.queue_free()


func test_the_bulletin_board_is_read_in_full() -> void:
	var board := BulletinBoard.new()
	main.add_child(board)
	board.show_camp("Test camp", 1, 4, PackedStringArray(["Ann"]))
	watch_signals(player)
	_use(board)
	assert_signal_emitted_with_parameters(player, "reading_requested", ["Test camp", "Members 1 / 4\n\nAnn"])
	board.queue_free()


func test_a_fence_comes_down_into_your_hands() -> void:
	var before := player.inventory.count("fence")
	var fence: Node = main.structures.build("fence", Transform3D(Basis.IDENTITY, _beside(9.0)), null, true)
	_use(fence)
	assert_eq(player.inventory.count("fence"), before + 1)
	assert_false(fence in main.structures.pieces)


func test_a_gate_opens_from_its_leaf() -> void:
	var gate: Node = main.structures.build("fence_gate", Transform3D(Basis.IDENTITY, _beside(12.0)), null, true)
	_use(gate.leaf)
	assert_true(gate.gate_open)
	_use(gate.leaf)
	assert_false(gate.gate_open)
	main.structures.take_down(gate)


func test_a_camp_kit_asks_main_to_pack_up_the_camp() -> void:
	var kit: Node = main.structures.build("camp_kit", Transform3D(Basis.IDENTITY, _beside(-6.0)), null, true)
	watch_signals(main.structures)
	_use(kit)
	assert_signal_emitted_with_parameters(main.structures, "camp_take_down_requested", [kit])
	assert_false(kit in main.structures.pieces, "main.gd packed the camp up")


func test_a_barricade_comes_down_into_your_hands() -> void:
	var before := player.inventory.count("barricade")
	main.fortifications.place_barricade(Transform3D(Basis.IDENTITY, _beside(-9.0)), true)
	var barricade: Node = main.fortifications.barricades.back()
	_use(barricade)
	assert_eq(player.inventory.count("barricade"), before + 1)


func test_the_generator_takes_a_gas_can() -> void:
	var generator := MineGenerator.new()
	main.add_child(generator)
	generator.global_position = _beside(-12.0)
	player.take_item("gas_can", player.inventory.count("gas_can"))
	watch_signals(player)
	_use(generator)
	assert_signal_emitted_with_parameters(player, "notify", ["It needs a gas can."])
	player.give_item("gas_can")
	_use(generator)
	assert_eq(player.inventory.count("gas_can"), 0)
	assert_gt(generator.fuel, 0.0)
	generator.queue_free()


func test_a_mine_control_does_what_its_owner_says() -> void:
	var lever := MineControl.new()
	var pulled_by: Array[Node3D] = []
	lever.prompt = func() -> String: return "pull the lever"
	lever.action = func(by: Node3D) -> void: pulled_by.append(by)
	main.add_child(lever)
	_use(lever)
	assert_eq(pulled_by, [player] as Array[Node3D])
	lever.queue_free()


func test_a_cave_in_says_it_needs_a_pickaxe() -> void:
	var heap := MineCaveIn.new()
	main.add_child(heap)
	watch_signals(player)
	_use(heap)
	assert_signal_emitted(player, "notify")
	heap.queue_free()


func test_talking_to_someone_and_not_to_the_dead() -> void:
	var chief := PoliceChiefScene.instantiate()
	main.add_child(chief)
	chief.global_position = _beside(15.0)
	assert_eq(Interactable.of(chief).get_prompt(), "talk to " + chief.display_name)
	watch_signals(player)
	_use(chief)
	assert_signal_emitted_with_parameters(player, "npc_interacted", [chief])
	chief.is_dead = true
	assert_eq(Interactable.of(chief).get_prompt(), "")
	chief.queue_free()
