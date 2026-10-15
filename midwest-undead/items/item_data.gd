class_name ItemData
extends Resource
## One kind of item. Every file in items/data/ is an item in the game (see
## HOW_TO_ADD.md). Guns and melee weapons are WeaponData, which is this plus how
## they fight.

## Unique, no spaces. Saves, loot tables, traders and recipes refer to it, so
## don't change it once it's in use.
@export var id := ""
@export var display_name := ""
## What the use button does while you hold it. "none": it can't be held (ammo,
## batteries, materials just sit in your inventory). "plate": puts metal over a
## fence or gate you built (sheet metal). Weapons set this themselves.
@export_enum("none", "heal", "eat", "board", "barricade", "build", "plate") var use := "none"
## Where it comes in inventory lists: lower first.
@export var order := 100

@export_group("Looks")
## What it looks like lying on the ground (and in your hands, for things you use
## up). Empty: a box of this size and color.
@export var model: PackedScene
@export var color := Color(0.5, 0.5, 0.5)
## Meters. Also the pickup zone's size (at least 0.5 x 0.3 x 0.5).
@export var size := Vector3(0.2, 0.1, 0.2)


## What the use button does: the weapon's "shoot" / "melee", this item's use,
## or "" if it can't be held.
func use_kind() -> String:
	return "" if use == "none" else use
