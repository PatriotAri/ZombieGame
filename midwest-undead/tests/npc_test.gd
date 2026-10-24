extends SceneTree
## NPC models: every person has a body (the mannequin, in their colors), the
## people animations (idle, walk, talk, rifle, work, flinches), a rifle in a
## guard's / bandit's hand that aims and reloads, hats on heads, and a ragdoll
## and blood when they die. Plus a model set per person.
const GuardScene := preload("res://characters/npcs/guard.tscn")
const BanditScene := preload("res://characters/npcs/bandit.tscn")
const HumanScene := preload("res://characters/npcs/human_npc.tscn")
const ChiefScene := preload("res://characters/npcs/police_chief.tscn")
var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var p: Node
var guard: Node
var bandit: Node
var chief: Node
var corpse: Node
var survivor: Node
var plot: Node
var zed: Node
var mark := {}

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	var markers := map_root.get_node("Markers")
	var camp := KitBaseCamp.new(); camp.name = "Station"; camp.position = Vector3(0, 0, 20)
	markers.add_child(camp); camp.owner = map_root
	var sp := KitSpawnPoint.new(); sp.name = "Dale"; sp.role = "survivor"; sp.person = "Dale Hutchins"
	sp.position = Vector3(-60, 0, -60)
	markers.add_child(sp); sp.owner = map_root
	test_map = PackedScene.new(); test_map.pack(map_root); map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)

func g(x: float, z: float) -> Vector3:
	return Vector3(x, main.terrain.data.get_height(Vector3(x, 0, z)), z)

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		3:
			p = main.player
			p.health = 1e9
			p.set_physics_process(false)
			for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
			p.global_position = g(40, 40) + Vector3(0, 0.1, 0)
			chief = main.chief if main.chief else ChiefScene.instantiate()
			if not chief.is_inside_tree():
				chief.position = g(42, 40); main.add_child(chief)
			guard = GuardScene.instantiate(); guard.position = g(30, 30)
			main.add_child(guard)
			# Out of sight of you and the guard (both his enemies), so he idles.
			bandit = BanditScene.instantiate(); bandit.home = g(150, 150); bandit.position = g(150, 150)
			bandit.model = load("res://characters/mannequin/mannequin.tscn") # a model set on the person
			main.add_child(bandit)
			corpse = HumanScene.instantiate(); corpse.zombies_target = false; corpse.position = g(44, 44)
			main.add_child(corpse); corpse.die()
			survivor = main.survivors.survivors[0]
		6:
			var everyone := root.find_children("*", "CharacterBody3D", true, false).filter(func(n): return n is HumanNPC)
			check(everyone.all(func(n): return n.body.skeleton != null and n.body.animator != null), "every person (%d) has a body with a skeleton" % everyone.size())
			check(chief.body.current == "idle" and chief.body.animator.current_animation == "mannequin/idle", "standing: the people's idle (%s)" % chief.body.animator.current_animation)
			check(not chief.body.animator.has_animation("attack"), "...not the zombies' animations")
			var hat: Node = chief.find_child("Hat", true, false)
			check(hat != null and hat.get_parent() is BoneAttachment3D and chief.body.skeleton.get_bone_name(hat.get_parent().bone_idx) == "Head", "the chief's hat is on his head bone")
			check(guard.rifle != null and guard.rifle.get_parent() is BoneAttachment3D and guard.body.skeleton.get_bone_name(guard.rifle.get_parent().bone_idx) == "RightHand", "the guard's rifle is in his right hand")
			check(guard.muzzle_flash != null and not guard.muzzle_flash.visible, "...with a muzzle flash (off)")
			check(guard.body.current == "rifle_idle" and bandit.body.current in ["rifle_idle", "rifle_walk"], "guard and bandit hold it low (%s, %s)" % [guard.body.current, bandit.body.current])
			check(corpse.body.is_ragdoll, "a corpse is a ragdoll")
			# A zombie below the guard: he aims down at it and shoots.
			zed = main._add_zombie(g(30, 42) + Vector3(0, 0.1, 0), null, "walker")
			zed.set_physics_process(false)
			guard.position.y += 4.0 # up a tower
			guard._cooldown = 0.0
		12:
			check(guard.body.current == "rifle_aim" or guard.body.is_busy(), "the guard aims (%s)" % guard.body.current)
			check(guard.body.aim_pitch < -0.1, "...down at the zombie below (%.0f degrees)" % rad_to_deg(guard.body.aim_pitch))
			guard.rounds = 1
			guard._cooldown = 0.0
			mark["muzzle"] = guard.muzzle()
		20:
			check(guard._reload_left > 0.0 and guard.body.is_busy(), "out of rounds: the reload plays")
			check(guard.muzzle().distance_to(guard.global_position + Vector3(0, 1.4, 0)) < 1.2, "the muzzle is at the rifle, in front of him")
			# Talking to the chief.
			main._on_npc_interacted(chief)
		24:
			check(chief.talking and chief.body.current == "talk", "talking to the chief: he talks with his hands (%s, menu %s)" % [chief.body.current, p.menu_open])
			if main.choice_menu.visible: main.choice_menu.close()
			p.menu_open = false
		28:
			check(not chief.talking and chief.body.current == "idle", "menus closed: back to standing")
			# The survivor at work on a garden plot.
			main.survivors._send_to(survivor, main.camps.station)
		60:
			plot = main.structures.build("garden_plot", Transform3D(Basis.IDENTITY, g(6, 26)), null)
		64:
			check(main.camps.assign(survivor, "garden_plot"), "the survivor is put on the garden")
		68:
			check(survivor.body.current == "work_dig", "...and digs (%s)" % survivor.body.current)
			# A bandit walking about camp; then shot.
			p.global_position = g(300, 300) + Vector3(0, 0.1, 0) # out of his sight
			bandit.state = bandit.State.IDLE
			bandit.target = null
			bandit._wander_target = bandit.home + Vector3(5, 0, 0)
			bandit._wander_timer = 99.0
		100:
			p.global_position = g(152, 144) + Vector3(0, 0.1, 0)
			check(bandit.body.current == "rifle_walk", "a bandit walking about with the rifle (%s, %.1f m/s)" % [bandit.body.current, Vector2(bandit.velocity.x, bandit.velocity.z).length()])
			mark["splats"] = root.find_children("*", "Decal", true, false).size()
			bandit.take_hit(10.0, bandit.global_position + Vector3(0, 1.2, -5), 1.0, p, bandit.global_position + Vector3(0, 1.3, 0))
			check(bandit.body.is_busy(), "hit: he flinches")
			check(root.find_children("*", "Decal", true, false).size() > mark["splats"], "blood on him and behind")
			bandit.take_hit(500.0, bandit.global_position + Vector3(0, 1.2, -5), 1.0, p, bandit.global_position + Vector3(0, 1.3, 0))
		101:
			check(bandit.is_dead and bandit.body.is_ragdoll, "killed: a ragdoll")
			check(bandit.rifle.get_parent() is BoneAttachment3D, "...the rifle still in his hand")
		500:
			check(bandit.body.is_settled, "the body comes to rest")
			var below: float = main.terrain.data.get_height(bandit.body.head_center())
			check(bandit.body.head_center().y - below < 0.6, "...lying on the ground (head %.2f m up)" % (bandit.body.head_center().y - below))
			print("FAILS: %d" % fails)
			return true
	return false
