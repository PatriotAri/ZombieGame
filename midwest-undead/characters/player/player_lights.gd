extends Node
## The player's lights (player.gd keeps one, as its "Lights" child): the
## flashlight (in player.tscn), the helmet lamp and a carried lantern.
##   - The flashlight runs on batteries: battery_life seconds a set. Running
##     low, it dims and flickers; running out, it swaps in a spare set from
##     your inventory, or goes dark.
##   - The helmet lamp (an item: wear it from the backpack, and the flashlight
##     key switches it instead): LAMP_BRIGHTER times as bright and wider than
##     the flashlight, and its own batteries last LAMP_LASTS times as long.
##   - A lantern lights up round you while it's in your hands (it never runs out).

const Sound := preload("res://core/sound.gd")
const Inventory := preload("res://items/inventory.gd")
const LAMP_BRIGHTER := 1.6
const LAMP_LASTS := 2.0

var flashlight: SpotLight3D
var flashlight_charge := 1.0 # what's left in the batteries in the flashlight, 0-1
var lamp_worn := false
var lamp_charge := 1.0 # its own batteries, 0-1
var battery_life := 240.0 # real seconds of light from one set of batteries
var low_battery := 0.2 # below this much charge, the light dims and flickers
var _inventory: Inventory
var _notify: Callable # (text: String): tells you, on screen
var _flashlight_energy := 1.0 # the beam's full brightness, from player.tscn
var _lamp: SpotLight3D
var _lantern: OmniLight3D


## Makes the helmet lamp (on `camera`) and the lantern (on `body`) to go with
## the flashlight.
func setup(light: SpotLight3D, camera: Camera3D, body: Node3D, inventory: Inventory, notify: Callable,
		life: float, low: float) -> void:
	flashlight = light
	_inventory = inventory
	_notify = notify
	battery_life = life
	low_battery = low
	_flashlight_energy = flashlight.light_energy
	_lamp = flashlight.duplicate() as SpotLight3D
	_lamp.name = "HelmetLamp"
	_lamp.light_energy = _flashlight_energy * LAMP_BRIGHTER
	_lamp.spot_angle = flashlight.spot_angle + 12.0
	_lamp.spot_range = flashlight.spot_range * 1.3
	_lamp.position.y += 0.15 # on your forehead
	_lamp.visible = false
	camera.add_child(_lamp)
	_lantern = OmniLight3D.new()
	_lantern.name = "Lantern"
	_lantern.light_color = Color(1.0, 0.75, 0.45)
	_lantern.light_energy = 1.2
	_lantern.omni_range = 8.0
	_lantern.position = Vector3(0.3, 1.1, -0.3) # at your side
	_lantern.visible = false
	body.add_child(_lantern)


## The flashlight key: the flashlight, or the helmet lamp while you wear it.
func toggle() -> void:
	Sound.play_ui(self, "flashlight_click", -8.0)
	if lamp_worn:
		_toggle_lamp()
		return
	if flashlight.visible:
		flashlight.visible = false
		return
	if flashlight_charge <= 0.0 and not _swap_batteries():
		_notify.call("The flashlight's dead. Find batteries.")
		return
	flashlight.visible = true


func _toggle_lamp() -> void:
	if _lamp.visible:
		_lamp.visible = false
		return
	if lamp_charge <= 0.0:
		if _inventory.remove("batteries") == 0:
			_notify.call("The helmet lamp's dead. Find batteries.")
			return
		lamp_charge = 1.0
		Sound.play_ui(self, "battery_swap", -6.0)
	_lamp.visible = true


## Puts the helmet lamp on or takes it off (the backpack): while it's on, the
## flashlight key switches it instead of the flashlight.
func wear_lamp(on: bool) -> void:
	on = on and _inventory.has("helmet_lamp")
	if on == lamp_worn:
		return
	lamp_worn = on
	var was_lit := flashlight.visible or _lamp.visible
	flashlight.visible = false
	_lamp.visible = false
	if was_lit:
		toggle() # the light you had on carries over to the other
	_notify.call("You put on the helmet lamp." if on else "You take off the helmet lamp.")


## Every frame: drains the batteries of whatever's on. lantern: holding one.
func update(delta: float, lantern: bool) -> void:
	_update_lamp(delta)
	_lantern.visible = lantern
	if not flashlight.visible:
		return
	flashlight_charge = maxf(flashlight_charge - delta / battery_life, 0.0)
	if flashlight_charge <= 0.0:
		if _swap_batteries():
			_notify.call("Swapped in fresh batteries (%d left)." % _inventory.count("batteries"))
		else:
			flashlight.visible = false
			_notify.call("The flashlight died.")
			return
	flashlight.light_energy = _energy(_flashlight_energy, flashlight_charge)


## The helmet lamp's batteries, as the flashlight's (it runs LAMP_LASTS times as long).
func _update_lamp(delta: float) -> void:
	if lamp_worn and not _inventory.has("helmet_lamp"):
		wear_lamp(false) # (sold or stored)
	if not _lamp.visible:
		return
	lamp_charge = maxf(lamp_charge - delta / (battery_life * LAMP_LASTS), 0.0)
	if lamp_charge <= 0.0:
		if _inventory.remove("batteries") > 0:
			lamp_charge = 1.0
			Sound.play_ui(self, "battery_swap", -6.0)
			_notify.call("Swapped fresh batteries into the helmet lamp (%d left)." % _inventory.count("batteries"))
		else:
			_lamp.visible = false
			_notify.call("The helmet lamp died.")
			return
	_lamp.light_energy = _energy(_flashlight_energy * LAMP_BRIGHTER, lamp_charge)


## Full brightness, dimmed and flickering once the charge runs low.
func _energy(full: float, charge: float) -> float:
	if charge >= low_battery:
		return full
	var energy := full * lerpf(0.35, 1.0, charge / low_battery)
	return energy * 0.15 if randf() < 0.05 else energy # flicker


func _swap_batteries() -> bool:
	if _inventory.remove("batteries") == 0:
		return false
	flashlight_charge = 1.0
	Sound.play_ui(self, "battery_swap", -6.0)
	return true


## Everything off (you died).
func all_off() -> void:
	flashlight.visible = false
	_lamp.visible = false
	_lantern.visible = false


## For the inventory screen: the light's charge and the spare batteries.
func text() -> String:
	var line := "Helmet lamp %d%%" % ceili(lamp_charge * 100.0) if lamp_worn else "Flashlight %d%%" % ceili(flashlight_charge * 100.0)
	if _inventory.has("batteries"):
		line += "  (+%d batteries)" % _inventory.count("batteries")
	return line


## Into a save (player.gd's save_state: the same keys as ever).
func save_into(data: Dictionary) -> void:
	data["flashlight"] = flashlight.visible
	data["flashlight_charge"] = flashlight_charge
	data["lamp_worn"] = lamp_worn
	data["lamp_on"] = _lamp.visible
	data["lamp_charge"] = lamp_charge


## From a save (after the inventory: the lamp has to be in it to be worn).
func load_from(data: Dictionary) -> void:
	flashlight_charge = clampf(float(data.get("flashlight_charge", 1.0)), 0.0, 1.0)
	flashlight.visible = bool(data.get("flashlight", false)) and flashlight_charge > 0.0
	lamp_charge = clampf(float(data.get("lamp_charge", 1.0)), 0.0, 1.0)
	lamp_worn = bool(data.get("lamp_worn", false)) and _inventory.has("helmet_lamp")
	_lamp.visible = lamp_worn and bool(data.get("lamp_on", false)) and lamp_charge > 0.0
