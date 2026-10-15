extends StaticBody3D
## Something you built (structures.gd builds and manages them): scaffolding, a
## guard post (on scaffolding it's the top of a guard tower, with a ladder down
## the side), a fence section, a fence gate, a garden plot or an ammo bench.
## Look at it and press interact to take it down and get it back (what's on top
## of scaffolding has to come down first).
##
## Fences and fence gates can be broken: they have MAX_HEALTH, and zombies bash
## them the way they bash doors (only while after someone or a noise on the
## other side; zombie.gd). They darken as they take a beating. Planks repair
## them; sheet metal plates them, after which nothing breaks them. A broken one
## is a wreck you (and zombies) walk through; take it down for some materials.
## Everything else you build can't be broken.

const GameData := preload("res://core/game_data.gd")
const Sound := preload("res://core/sound.gd")

## Fences and gates: 50 doors' worth (one zombie takes ~7 minutes, ten ~40 seconds).
const MAX_HEALTH := 7500.0
const BREAKABLE := ["fence", "fence_gate"]
## Sheet metal it takes to plate one.
const SHEETS := {"fence": 1, "fence_gate": 3}
const BASH_INTERVAL := 0.6 # seconds between bash sounds, however many zombies are at it

var kind := "" # an item id: "scaffold", "guard_post", "fence", "fence_gate"
var below: Node3D = null # the scaffolding it stands on (null: on the ground)
var above: Node3D = null # what stands on it (scaffolding only)
var gate_open := false
var leaf: Node3D = null # fence gates: the part that swings (gate_leaf.gd)
var ladder: Area3D = null # a guard post on scaffolding: the ladder's climbing area
var worker: Node3D = null # garden plots and ammo benches: the survivor working it (base_camp.gd)
var health := MAX_HEALTH
var plated := false
var broken := false
var structures: Node # structures.gd, which looks after damage, plating and wrecks
var _next_bash_ms := 0


## Where its worker stands: just in front of it (its +z side), clear of its edge.
func work_spot() -> Vector3:
	var out := 1.5 if kind == "garden_plot" else 0.95 # half its depth, plus room for them
	return global_transform * Vector3(0, 0.1, out)


func interact_prompt() -> String:
	var label := GameData.item_name(kind).to_lower()
	return "take down the broken " + label if broken else "take down the " + label


func is_breakable() -> bool:
	return kind in BREAKABLE


## Zombies bash what they run into on their way somewhere (zombie.gd).
func can_be_bashed() -> bool:
	return is_breakable() and not plated and not broken


func bash(damage: float) -> void:
	if not can_be_bashed():
		return
	health -= damage
	var now := Time.get_ticks_msec()
	if now >= _next_bash_ms:
		_next_bash_ms = now + int(BASH_INTERVAL * 1000.0)
		Sound.play_at(self, "door_bash", global_position + Vector3.UP, 0.0, 30.0, 0.12)
	structures.call("damaged", self)


func is_damaged() -> bool:
	return is_breakable() and not broken and health < MAX_HEALTH
