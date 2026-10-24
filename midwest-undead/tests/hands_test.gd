extends SceneTree
## First-person weapon animations: draw/holster, fire (recoil, slide, pump, bolt),
## reload (magazine, rounds one at a time, bolt), swing, aim; then a model that
## brings its own AnimationPlayer (reload stretched to fit, draw on switch) and a
## Sight marker.
const GameData := preload("res://core/game_data.gd")
var main: Node
var p: Node
var h: Node
var f := 0
var fails := 0
var mark := {}
var custom := false

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	custom = OS.get_cmdline_user_args().has("custom")
	if custom:
		GameData.weapon("pistol").held_model = _custom_model()
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

## A pistol model with its own animations (named like Blender exports them) and a Sight.
func _custom_model() -> PackedScene:
	var r := Node3D.new(); r.name = "CustomPistol"
	var mesh := MeshInstance3D.new(); mesh.name = "Body"; mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.05, 0.1, 0.25)
	r.add_child(mesh); mesh.owner = r
	var sight := Marker3D.new(); sight.name = "Sight"; sight.position = Vector3(0, 0.06, 0.1)
	r.add_child(sight); sight.owner = r
	var ap := AnimationPlayer.new(); ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	for n in ["Armature|reload", "draw", "fire"]:
		var a := Animation.new(); a.length = 1.0
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, "Body:position")
		a.track_insert_key(t, 0.0, Vector3.ZERO); a.track_insert_key(t, 0.5, Vector3(0, -0.05, 0)); a.track_insert_key(t, 1.0, Vector3.ZERO)
		lib.add_animation(n, a)
	ap.add_animation_library("", lib)
	r.add_child(ap); ap.owner = r
	var ps := PackedScene.new(); ps.pack(r); r.free()
	return ps

func part(id: String, name: String) -> Node3D:
	return h.models[id].parts.get(name)

func _process(_d: float) -> bool:
	f += 1
	if f == 2:
		p = main.player; h = p.hands
		p.health = 1e9
		for id in ["shotgun", "rifle", "crowbar"]: p.give_item(id)
		for a in ["pistol_ammo", "shotgun_shells", "rifle_rounds"]: p.give_item(a, 50)
		for id in ["shotgun", "rifle"]: p.mags[id] = GameData.weapon(id).magazine
		for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
		return false
	if custom:
		return _custom_steps()
	match f:
		10:
			var GameData := preload("res://core/game_data.gd")
			var weapons := GameData.item_ids().filter(func(id: String) -> bool: return GameData.weapon(id) != null).size()
			check(h.models.size() == weapons + 1 and h.shown == "pistol" and h.models["pistol"].visible,
					"a model per weapon (%d) plus fists; the pistol's showing (%d)" % [weapons, h.models.size()])
			check(part("pistol", "Slide") != null and part("pistol", "Magazine") != null and part("shotgun", "Pump") != null and part("shotgun", "LoadingPort") != null and part("rifle", "Bolt") != null and part("rifle", "LoadingPort") != null, "the box guns' parts are found")
			mark["slide"] = part("pistol", "Slide").position
			p.attack_cooldown = 0.0
			p._try_shoot()
		12:
			check(h.models["pistol"].kick.rotation_degrees.x > 5.0, "a shot kicks the pistol up (%.1f deg)" % h.models["pistol"].kick.rotation_degrees.x)
			check(part("pistol", "Slide").position.z > mark["slide"].z + 0.01, "...and the slide's back")
		50:
			check(h.models["pistol"].kick.rotation_degrees.length() < 1.0, "recoil settles (%.2f deg)" % h.models["pistol"].kick.rotation_degrees.length())
			check(part("pistol", "Slide").position.distance_to(mark["slide"]) < 0.001, "...and the slide's home")
			p.mags["pistol"] = 1; p.attack_cooldown = 0.0
			p._try_shoot()
		80:
			check(part("pistol", "Slide").position.z > mark["slide"].z + 0.03, "last round: the slide stays back")
			p._start_reload()
			mark["mag"] = part("pistol", "Magazine").position
		120: # 0.67 s into a 1.6 s reload: the old magazine's out
			check(not part("pistol", "Magazine").visible or part("pistol", "Magazine").position.y < mark["mag"].y - 0.1, "reload: the magazine drops out")
			check(h.models["pistol"].motion.rotation_degrees.length() > 20.0, "...with the gun tilted")
		190:
			check(p.mags["pistol"] == 7 and part("pistol", "Magazine").visible and part("pistol", "Magazine").position.distance_to(mark["mag"]) < 0.001, "reloaded: a magazine's back in")
			check(part("pistol", "Slide").position.distance_to(mark["slide"]) < 0.001 and h.models["pistol"].motion.rotation_degrees.length() < 0.01, "...the slide's released and the gun's level")
			mark["cool"] = p.select("shotgun") if false else 0
			p.select("shotgun")
			mark["cool"] = p.attack_cooldown
			check(absf(mark["cool"] - 0.6) < 0.01, "switching to the shotgun: usable after 0.15 s put away + 0.45 s drawn (%.2f)" % mark["cool"])
		196: # 0.1 s in: the pistol's going down
			check(h.shown == "pistol" and h.position.y < -0.1, "the pistol goes down first (%.2f m)" % h.position.y)
		206:
			check(h.shown == "shotgun" and h.models["shotgun"].visible and not h.models["pistol"].visible, "halfway: the shotgun's in your hands")
		240:
			check(absf(h._drawn - 1.0) < 0.001 and h.position.length() < 0.05, "...and up (%.3f m off)" % h.position.length())
			mark["pump"] = part("shotgun", "Pump").position
			p.attack_cooldown = 0.0
			p._try_shoot()
		262: # 0.37 s after the shot: racking the pump
			check(part("shotgun", "Pump").position.z > mark["pump"].z + 0.03, "shotgun: the pump racks after a shot")
		300:
			check(part("shotgun", "Pump").position.distance_to(mark["pump"]) < 0.001, "...and goes home")
			p.mags["shotgun"] = 2
			p._start_reload()
			mark["seen_round"] = false
		301, 302, 303:
			pass
		460:
			check(mark["seen_round"], "shotgun reload: shells go in one at a time")
			check(p.mags["shotgun"] == 5 and not h.models["shotgun"].get("_round").visible, "...all loaded, none left showing")
			p.select("rifle")
		520:
			mark["bolt"] = part("rifle", "Bolt").rotation_degrees
			p.attack_cooldown = 0.0
			p._try_shoot()
		551: # 0.5 s after: working the bolt
			check(absf(part("rifle", "Bolt").rotation_degrees.z - mark["bolt"].z) > 20.0 or part("rifle", "Bolt").position.z > 0.15, "rifle: the bolt's worked after a shot")
		620:
			check(part("rifle", "Bolt").rotation_degrees.distance_to(mark["bolt"]) < 0.01, "...and closed")
			p.mags["rifle"] = 0
			p._start_reload()
		650: # 0.5 s into 2.8 s: bolt open
			check(absf(part("rifle", "Bolt").rotation_degrees.z - mark["bolt"].z) > 50.0, "rifle reload: the bolt's open")
			p.select("pistol") # switching cancels it
		660:
			check(p.reload_timer == 0.0 and part("rifle", "Bolt").rotation_degrees.distance_to(mark["bolt"]) < 0.01 and p.mags["rifle"] == 0, "switching away cancels the reload; the bolt's put back")
			Input.action_press("aim")
		720:
			var g: Node3D = h.models["pistol"]
			check(g.position.distance_to(g.aim_position) < 0.01, "aiming brings the pistol to the middle")
			Input.action_release("aim")
			p.select("crowbar")
		780:
			p.attack_cooldown = 0.0
			p._try_melee()
		783:
			check(h.models["crowbar"].motion.rotation_degrees.x < -20.0, "the crowbar swings")
		830:
			check(h.models["crowbar"].motion.rotation_degrees.length() < 0.01, "...and comes back")
			p.select("hands")
		870:
			p.attack_cooldown = 0.0
			p._try_melee()
		873:
			check(h.models["hands"].motion.rotation_degrees.x < -20.0 and h.models["hands"].visible, "punching swings your fists")
			print("FAILS: %d" % fails)
			return true
	if f > 300 and f < 460 and h.models["shotgun"].get("_round").visible:
		mark["seen_round"] = true
	return false

func _custom_steps() -> bool:
	match f:
		10:
			var g: Node3D = h.models["pistol"]
			check(g.anim != null and g.animation_for("reload") == "Armature|reload", "a model's own reload is found (named like a Blender export)")
			check(g.aim_position.distance_to(Vector3(0, -0.06, -0.4)) < 0.001, "a Sight marker sets the aiming spot (%s)" % g.aim_position)
			p.mags["pistol"] = 0
			p._start_reload()
		12:
			var g: Node3D = h.models["pistol"]
			check(g.anim.current_animation == "Armature|reload" and absf(g.anim.get_playing_speed() - 1.0 / 1.6) < 0.01, "its reload plays, stretched to the 1.6 s reload (speed %.3f)" % g.anim.get_playing_speed())
			check(g.motion.rotation_degrees.length() < 0.01, "...instead of the code's tilt")
		120:
			p.select("shotgun")
		170:
			p.select("pistol")
		180: # 0.15 s put away, then its own draw
			var g: Node3D = h.models["pistol"]
			check(g.anim.current_animation == "draw" and absf(g.anim.get_playing_speed() - 1.0 / 0.3) < 0.01, "switching back plays its draw, fitted to draw_time")
			check(absf(h._drawn - 1.0) < 0.001, "...instead of the code's raise")
		220:
			p.attack_cooldown = 0.0
			p._try_shoot()
		222:
			var g: Node3D = h.models["pistol"]
			check(g.anim.current_animation == "fire" and absf(g.anim.get_playing_speed() - 1.0 / 0.3) < 0.01, "its fire plays, sped up to the 0.3 s cooldown")
			check(g.kick.rotation_degrees.x > 5.0, "...with the code's recoil on top")
			print("FAILS: %d" % fails)
			return true
	return false
