extends GutTest
## components/interactable.gd on its own: finding it, its prompt, and that it
## only fires while it has something to say.


func test_of_finds_one_added_in_code_before_it_is_in_the_tree() -> void:
	var host := Node3D.new()
	var it := Interactable.attach(host, func() -> String: return "open it")
	assert_eq(Interactable.of(host), it)
	host.free()


func test_of_is_null_without_one() -> void:
	var host: Node3D = autofree(Node3D.new())
	assert_null(Interactable.of(host))
	assert_null(Interactable.of(null))


func test_of_is_null_once_it_is_removed() -> void:
	var host: Node3D = autofree(Node3D.new())
	var it := Interactable.attach(host, Callable())
	host.remove_child(it)
	it.free()
	assert_null(Interactable.of(host))


func test_of_finds_one_placed_in_a_scene() -> void:
	var host := Node3D.new()
	var placed := Interactable.new()
	placed.prompt = "read the sign"
	host.add_child(placed)
	placed.owner = host
	var scene := PackedScene.new()
	scene.pack(host)
	host.free()
	var copy: Node = autofree(scene.instantiate())
	assert_not_null(Interactable.of(copy))
	assert_eq(Interactable.of(copy).get_prompt(), "read the sign")


func test_prompt_source_wins_over_prompt() -> void:
	var host: Node3D = autofree(Node3D.new())
	var it := Interactable.attach(host, func() -> String: return "from the source")
	it.prompt = "typed in"
	assert_eq(it.get_prompt(), "from the source")


func test_interact_tells_whoever_listens_who_used_it() -> void:
	var host: Node3D = autofree(Node3D.new())
	var actor: Node3D = autofree(Node3D.new())
	var it := Interactable.attach(host, func() -> String: return "open it")
	watch_signals(it)
	it.interact(actor)
	assert_signal_emitted_with_parameters(it, "interacted", [actor])


func test_interact_does_nothing_while_the_prompt_is_empty() -> void:
	var host: Node3D = autofree(Node3D.new())
	var it := Interactable.attach(host, func() -> String: return "")
	watch_signals(it)
	it.interact(autofree(Node3D.new()))
	assert_signal_not_emitted(it, "interacted")
