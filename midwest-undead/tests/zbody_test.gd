extends SceneTree
## Zombie bodies: the mannequin, animations by what it's doing, the head hitbox,
## flinches by hit zone, ragdoll deaths that settle on the ground, blood, the
## 1.5 s window climb, the ragdoll cap, and bodies cleared once you're away.
const HumanoidBody := preload("res://characters/humanoid_body.gd")
const Blood := preload("res://effects/blood.gd")
var main: Node
var p: Node
var f := 0
var fails := 0
var z: Node # the walker under test
var z2: Node # a tough one, for flinches
var cr: Node # a crawler
var many: Array = []
var mark := {}

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func ground(x: float, zz: float) -> Vector3:
	return Vector3(x, main.terrain.data.get_height(Vector3(x, 0, zz)), zz)

func spawn(at: Vector3, kind: String) -> Node:
	var q = main._add_zombie(at + Vector3(0, 0.1, 0), null, kind)
	return q

## Aim the camera at a point and fire the held gun once.
func shoot_at(point: Vector3) -> void:
	var cam: Camera3D = p.camera
	var to := point - cam.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	p.attack_cooldown = 0.0
	p.mags[p.held] = 7
	p._try_shoot()

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 2:
		p = main.player
		p.health = 1e9
		p.set_physics_process(false)
		for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
		p.global_position = ground(100, 100) + Vector3(0, 0.05, 0)
		z = spawn(ground(100, 92), "walker")
		z2 = spawn(ground(104, 92), "walker")
		cr = spawn(ground(96, 92), "crawler")
		for q in [z, z2, cr]: q.set_physics_process(false) # posed by hand below
	match f:
		10:
			var b: HumanoidBody = z.body
			check(b.model != null and b.skeleton != null and b.skeleton.get_bone_count() == 23, "a zombie gets the mannequin: a skeleton of %d bones" % (b.skeleton.get_bone_count() if b.skeleton else 0))
			check(b.animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL and b.animation_for("walk") == "walk", "its animations come from the mannequin's library, stepped by hand")
			check(z.visual.scale.y >= 0.92 and z.visual.scale.y <= 1.08, "a random size (%.2f)" % z.visual.scale.y)
			z.set_physics_process(true)
			z._investigate(z.global_position + Vector3(0, 0, -15))
			z.linger_time = 100.0
		70:
			check(z.body.current == "walk" and z.body.animator.current_animation == "walk", "walking: the walk animation (%s)" % z.body.current)
			z.set_physics_process(false)
			z.velocity = Vector3.ZERO
			z._animate(false)
		75:
			check(z.body.current == "idle", "standing: idle (%s)" % z.body.current)
			cr._animate(false)
		80:
			check(cr.body.current == "crawl_idle", "a crawler lies there: crawl_idle (%s)" % cr.body.current)
			z.body.animator.advance(0.0); z.body._place_head_shape()
			var head: Vector3 = z.body.head_center()
			check(head.y - z.global_position.y > 1.4 and head.y - z.global_position.y < 1.85, "the head's at head height (%.2f m)" % (head.y - z.global_position.y))
			check(z.head_shape.global_position.distance_to(head) < 0.01, "the head hitbox sits on the head")
			check(z.is_headshot(head + Vector3(0, 0, 0.15)) and not z.is_headshot(z.global_position + Vector3(0, 1.2, 0.3)), "a hit on the head hitbox is a headshot; on the chest it isn't")
			cr.body.animator.advance(0.0); cr.body._place_head_shape()
			var crawl_head: Vector3 = cr.body.head_center()
			check(crawl_head.y - cr.global_position.y < 0.6, "a crawler's head is down near the ground (%.2f m)" % (crawl_head.y - cr.global_position.y))
			# A leg shot on a tough one: it flinches at the legs.
			z2.health = 1000.0
			mark["splats"] = Blood._splats.size()
			shoot_at(z2.global_position + Vector3(0, 0.5, 0))
		82:
			check(z2.health < 1000.0, "the leg shot hit (%.0f health left)" % z2.health)
			check(z2.body.animator.current_animation == "hit_legs", "a leg shot: it flinches at the legs (%s)" % z2.body.animator.current_animation)
			check(z2.body._wounds.size() == 1, "...a blood mark on its body")
			check(Blood._splats.size() > mark["splats"], "...and splatter around (%d)" % (Blood._splats.size() - mark["splats"]))
			shoot_at(z2.global_position + Vector3(0, 1.1, 0))
		84:
			check(z2.body.animator.current_animation == "hit_body", "a body shot: a body flinch (%s)" % z2.body.animator.current_animation)
			# A headshot kills the walker (pistol 55 x 2.5).
			z.body.animator.advance(0.0); z.body._place_head_shape()
			shoot_at(z.head_shape.global_position)
		86:
			check(z.is_dead, "a pistol headshot kills a walker")
			check(z.body.is_ragdoll and z.body._bones.size() == 11, "it goes limp: %d physical bones" % z.body._bones.size())
		300: # 3.6 s later
			check(z.body.is_settled and z.body._bones.is_empty(), "...settles and freezes (the physics bodies are gone)")
			var hips: Vector3 = z.body.skeleton.global_transform * z.body.skeleton.get_bone_global_pose(z.body.skeleton.find_bone("Hips")).origin
			var floor_y: float = main.terrain.data.get_height(hips)
			check(hips.y - floor_y < 0.45 and hips.y - floor_y > -0.2, "...lying on the ground (hips %.2f m up)" % (hips.y - floor_y))
			check(not is_nan(hips.x) and hips.distance_to(z.global_position) < 3.0, "...near where it fell (%.1f m)" % hips.distance_to(z.global_position))
			# The window climb, on a made-up window.
			var link := NavigationLink3D.new()
			link.set_meta("window", null)
			link.set_meta("sill_y", z2.global_position.y + 0.9)
			main.add_child(link)
			z2._window_link = link
			z2._window_entry = z2.global_position
			z2._window_exit = z2.global_position + Vector3(0, 0, -1.2)
			z2.body._one_shot_left = 0.0
			z2._vault()
			mark["vault_start"] = f
		301:
			check(z2.body.animator.current_animation == "climb", "climbing in through a window: the climb animation")
			check(not z2.collision.disabled, "...and it can be hit while it climbs")
		384: # 1.38 s in
			check(z2._vaulting, "still climbing after 1.4 s")
		396: # 1.58 s
			check(not z2._vaulting, "...and through by 1.6 s")
			# Fifteen die at once: at most MAX_RAGDOLLS fall together.
			for i in 15:
				var q = spawn(ground(110 + i, 80), "walker")
				q.set_physics_process(false)
				many.append(q)
		400:
			for q in many:
				q.take_hit(500.0, q.global_position + Vector3(0, 1, 3), 2.0, p)
			check(HumanoidBody._falling.size() <= HumanoidBody.MAX_RAGDOLLS, "15 die at once: %d ragdolls fall (cap %d)" % [HumanoidBody._falling.size(), HumanoidBody.MAX_RAGDOLLS])
			check(many.all(func(q) -> bool: return q.body.is_ragdoll), "...the rest freeze where they are")
		800:
			check(many.all(func(q) -> bool: return q.body.is_settled), "after 6.7 s every body has settled")
			mark["count"] = main.zombies.size()
			p.global_position = ground(250, 250) # well away (and headless: nothing's on screen)
		880:
			var left: int = main.zombies.filter(func(q) -> bool: return is_instance_valid(q) and q.is_dead).size()
			check(left == 0 and main.zombies.size() < mark["count"], "away from them, the bodies are cleared (%d left)" % left)
			print("FAILS: %d" % fails)
			return true
	return false
