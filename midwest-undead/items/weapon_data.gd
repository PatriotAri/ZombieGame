class_name WeaponData
extends ItemData
## A gun or a melee weapon: an item (see ItemData) plus how it fights. Make one
## in items/data/ like any other item (see HOW_TO_ADD.md).

@export_enum("gun", "melee") var weapon_kind := "gun"

@export_group("In your hands")
## The model in front of the camera. Empty: a box like on the ground. It can
## have named parts the game animates (Slide, Pump, Bolt, Magazine, LoadingPort,
## MuzzleFlash, Sight) and its own animations (draw, holster, fire, reload,
## swing): see items/held_model.gd and HOW_TO_MODEL.md.
@export var held_model: PackedScene
## Where it sits in front of the camera (meters; x right, y up, -z ahead).
@export var held_position := Vector3(0.25, -0.22, -0.45)
## Seconds to bring it up when you switch to it. It can't be used until it's up.
@export_range(0.05, 2.0, 0.05) var draw_time := 0.35

@export_group("Hitting")
## Per hit (a gun: per pellet). Headshots do more (the player's headshot_multiplier).
@export var damage := 50.0
## Meters: how far a shot goes, or a swing reaches.
@export var reach := 60.0
## Seconds between shots or swings.
@export var cooldown := 0.3
## How hard a hit shoves a zombie back.
@export var knockback := 1.5
## Meters: zombies this close hear it (a gun every shot, a melee weapon when it hits).
@export var noise := 40.0

@export_group("Gun")
## The item id it loads.
@export var ammo := ""
@export var magazine := 7
## Shots per pull of the trigger (a shotgun's pellets).
@export var pellets := 1
## Degrees off where you point, from the hip and while aiming.
@export var spread := 0.0
@export var aimed_spread := 0.0
@export var reload_time := 1.6
## Field of view while aiming (degrees; the normal view is 75).
@export_range(5.0, 75.0) var aim_fov := 60.0
## Aiming looks through a scope (the screen goes black around a reticle) once
## zoomed in past 40 degrees.
@export var scope := false
## Degrees the gun jerks up on each shot.
@export var kick := 14.0
## A sound name from sounds/ (see core/sound.gd).
@export var sound := "gunshot"
@export var sound_volume := 0.0
@export var sound_pitch := 1.0

@export_group("Melee")
## Stamina each swing takes.
@export var stamina_cost := 15.0
## Can pry things apart for materials (hold interact on a car, a fence...).
@export var salvages := false
## Digs through things (hold interact on a mine's cave-in: world/map/mine_cave_in.gd).
@export var digs := false


func use_kind() -> String:
	return "shoot" if weapon_kind == "gun" else "melee"


func is_gun() -> bool:
	return weapon_kind == "gun"
