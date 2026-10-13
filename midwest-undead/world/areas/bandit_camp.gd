extends RefCounted
## The bandit camp: two tents, a campfire, a wrecked car for cover, their stash,
## and the five bandits. Never instanced: main.gd calls build(), then spawn()
## once the navigation mesh is baked.
##
## It's in the open field north of the cross street, behind the west side of
## Main Street; walking the cross street to the safe house takes you within
## sight of it. Placement is set by distance (checked in testing): bandits never
## stray more than their leash (15 m) from camp, see at most 25 m in daylight, and
## their shots carry 25 m. The camp is ~130 m from the nearest safe house zombie,
## ~94 m from the station and ~55 m from the nearest house, so none is within reach.
## Moving the camp (or raising leash/sight)? Keep leash + sight comfortably under
## those distances.

const WorldBuilder := preload("res://world/world_builder.gd")
const Bandit := preload("res://characters/npcs/bandit.gd")
const BanditScene := preload("res://characters/npcs/bandit.tscn")

const CAMP_CENTER := Vector3(-28.0, 0.0, -35.0)
const BANDIT_COUNT := 5
const SPAWN_OFFSETS := [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(-2, 0, 2), Vector3(2.5, 0, 1.5), Vector3(0, 0, -4)]


static func build(b: WorldBuilder) -> void:
	var canvas := Color(0.33, 0.35, 0.22)
	b.add_box(Vector3(3.0, 1.8, 2.4), CAMP_CENTER + Vector3(-5.0, 0.9, 3.5), canvas, 0.2)
	b.add_box(Vector3(3.0, 1.8, 2.4), CAMP_CENTER + Vector3(4.5, 0.9, 4.0), canvas, -0.3)
	b.add_box(Vector3(1.9, 0.9, 4.4), CAMP_CENTER + Vector3(0.0, 0.45, 7.5), Color(0.35, 0.2, 0.15), 1.4) # burned-out car
	b.add_box(Vector3(0.9, 0.25, 0.9), CAMP_CENTER + Vector3(0.0, 0.125, 0.0), Color(0.12, 0.1, 0.08)) # fire pit
	var fire := OmniLight3D.new()
	fire.position = CAMP_CENTER + Vector3(0.0, 0.8, 0.0)
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 2.0
	fire.omni_range = 10.0
	b.main.add_child(fire)

	var stash := b.add_loot(Vector3(1.2, 0.8, 0.9), CAMP_CENTER + Vector3(-1.5, 0.4, 5.0), Color(0.3, 0.25, 0.15), "Bandit stash")
	stash.inventory.add("pistol_ammo", 16)
	stash.inventory.add("health_pack", 1)
	stash.inventory.add("canned_food", 2)
	stash.inventory.add("batteries", 2)


## The bandits themselves, after the navigation bake (so they can path).
static func spawn(b: WorldBuilder) -> Array[Bandit]:
	var bandits: Array[Bandit] = []
	for offset: Vector3 in SPAWN_OFFSETS.slice(0, BANDIT_COUNT):
		var bandit := BanditScene.instantiate() as Bandit
		bandit.home = CAMP_CENTER
		bandit.position = CAMP_CENTER + offset + Vector3(0, 0.15, 0)
		bandit.rotation.y = b.rng.randf_range(0.0, TAU)
		b.main.add_child(bandit)
		bandits.append(bandit)
	return bandits
