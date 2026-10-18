extends RefCounted
## Every input action in one place, for keyboard/mouse and Xbox-layout controllers.
## Godot maps any standard gamepad (Xbox, PlayStation, Switch Pro...) to the same
## button names, so "A" below is Cross on a PlayStation pad, and so on.
## main.gd (and the main menu) call setup() once at startup. Never instanced.
##
## The defaults:
##   Action           Keyboard / mouse   Controller
##   move             WASD               left stick
##   look             mouse              right stick
##   jump             Space              A
##   sprint           Shift (hold)       L3 / click left stick (toggles)
##   crouch           Ctrl (hold)        B (toggles)
##   use held item    left click         RT   (shoot, swing, heal, eat...)
##   aim (guns)       right click (hold) LT   (zooms; the rifle's scope)
##   next/prev item   mouse wheel        D-pad right = next, D-pad left = previous
##   pick held item   1-9                -    (numbered on the inventory screen)
##   inventory        Tab                View / Back
##   journal (quests) J                  D-pad down
##   interact         E                  X
##   reload           R                  X    (when there's nothing to interact with)
##   quick heal       Q                  LB   (switches to a health pack and uses it)
##   flashlight       F                  D-pad up
##   map              M                  Y
##   pause            Esc                Start (Menu button)
##   performance      F3                 -    (the readout: ui/perf_overlay.gd)
##   in menus: move a whole stack with Shift+click, or hold RB and press A.
##
## Most of them can be changed on the Controls page (ui/controls_page.gd,
## REBINDABLE below). Changes are saved in their own file (user://controls.cfg)
## and put on top of the defaults at startup. One controller button can do two
## things: set to both Interact and Reload (X, by default), it interacts when
## you're looking at something you can, and reloads when you're not (player.gd).

## True when the last input came from a controller; HUD prompts use it to show
## "X" instead of "E", etc. main.gd updates it as input arrives.
static var using_gamepad := false

const PATH := "user://controls.cfg"
const STICK_DEADZONE := 0.2 # analog stick actions: small deadzone for fine movement
const TRIGGER_PRESS := 0.5 # how far a trigger goes down to count as pressed

## The ones you can change: [action, what it's called, keyboard / mouse can be
## changed, controller can be changed].
const REBINDABLE := [
	["move_forward", "Move forward", true, false],
	["move_back", "Move back", true, false],
	["move_left", "Move left", true, false],
	["move_right", "Move right", true, false],
	["jump", "Jump", true, true],
	["sprint", "Sprint", true, true],
	["crouch", "Crouch", true, true],
	["use_held", "Use held item (shoot, swing, heal...)", true, true],
	["aim", "Aim (guns; the rifle's scope)", true, true],
	["item_next", "Next item", true, true],
	["item_prev", "Previous item", true, true],
	["interact", "Interact (search, pick up, talk, open)", true, true],
	["reload", "Reload", true, true],
	["use_health_pack", "Quick heal", true, true],
	["flashlight", "Flashlight", true, true],
	["inventory", "Inventory", true, true],
	["map", "Map", true, true],
	["journal", "Journal (quests)", true, true],
	["pause", "Pause", false, true],
	["performance", "Performance readout", true, false],
]
## Shown on the Controls page too, but fixed: [what it does, keyboard / mouse, controller].
const FIXED := [
	["Look", "Mouse", "Right stick"],
	["Move", "(above)", "Left stick"],
	["Pick an item", "1-9", "-"],
	["Salvage (holding the crowbar)", "Hold Interact", "Hold Interact"],
	["Move a whole stack (in menus)", "Shift + click", "RB + A"],
	["Pause", "Esc", "(above)"],
]
## Prompts that aren't one action: [keyboard / mouse, controller].
const FIXED_HINTS := {
	"continue": ["E / Space / Click", "A / X"],
	"leave": ["Esc", "B"],
}
const JOY_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


## The defaults, then your changes on top (from PATH).
static func setup() -> void:
	_defaults()
	_load_bindings()


static func _defaults() -> void:
	_key("move_forward", KEY_W); _axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_key("move_back", KEY_S); _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_key("move_left", KEY_A); _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_key("move_right", KEY_D); _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_key("jump", KEY_SPACE); _button("jump", JOY_BUTTON_A)
	_key("sprint", KEY_SHIFT); _button("sprint", JOY_BUTTON_LEFT_STICK)
	_key("crouch", KEY_CTRL); _button("crouch", JOY_BUTTON_B)
	_mouse("use_held", MOUSE_BUTTON_LEFT); _axis("use_held", JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_PRESS)
	_mouse("aim", MOUSE_BUTTON_RIGHT); _axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0, TRIGGER_PRESS)
	_key("interact", KEY_E); _button("interact", JOY_BUTTON_X)
	_key("reload", KEY_R); _button("reload", JOY_BUTTON_X)
	_key("use_health_pack", KEY_Q); _button("use_health_pack", JOY_BUTTON_LEFT_SHOULDER)
	_mouse("item_next", MOUSE_BUTTON_WHEEL_DOWN); _button("item_next", JOY_BUTTON_DPAD_RIGHT)
	_mouse("item_prev", MOUSE_BUTTON_WHEEL_UP); _button("item_prev", JOY_BUTTON_DPAD_LEFT)
	for i in range(1, 10):
		_key("slot_%d" % i, (KEY_0 + i) as Key)
	_key("flashlight", KEY_F); _button("flashlight", JOY_BUTTON_DPAD_UP)
	_key("map", KEY_M); _button("map", JOY_BUTTON_Y)
	_key("inventory", KEY_TAB); _button("inventory", JOY_BUTTON_BACK)
	_key("journal", KEY_J); _button("journal", JOY_BUTTON_DPAD_DOWN)
	_key("pause", KEY_ESCAPE); _button("pause", JOY_BUTTON_START)
	_key("performance", KEY_F3)
	_key("menu_stack", KEY_SHIFT); _button("menu_stack", JOY_BUTTON_RIGHT_SHOULDER)
	_key("restart", KEY_R); _button("restart", JOY_BUTTON_A)
	# Menus use Godot's built-in ui_* actions; make sure the left stick and D-pad
	# both navigate them (A = ui_accept and B = ui_cancel are built in).
	_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0, 0.5); _button("ui_up", JOY_BUTTON_DPAD_UP)
	_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0, 0.5); _button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_axis("ui_left", JOY_AXIS_LEFT_X, -1.0, 0.5); _button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_axis("ui_right", JOY_AXIS_LEFT_X, 1.0, 0.5); _button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_button("ui_accept", JOY_BUTTON_A)
	_button("ui_cancel", JOY_BUTTON_B)


# --- Names for prompts and the Controls page ----------------------------------------

## The key/button name to show in a prompt for an action, for whatever you're
## using now (keyboard / mouse or controller).
static func hint(action: String) -> String:
	if FIXED_HINTS.has(action):
		return FIXED_HINTS[action][1 if using_gamepad else 0]
	return binding_text(action, using_gamepad)


## What an action is set to on a controller (gamepad true) or keyboard / mouse:
## "E", "Left click", "X", "LB / RB"... "-" if nothing.
static func binding_text(action: String, gamepad: bool) -> String:
	var names := PackedStringArray()
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if _is_gamepad(ev) == gamepad:
				names.append(event_name(ev))
	return " / ".join(names) if not names.is_empty() else "-"


static func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key := ev as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		# The key with that position on your keyboard layout (Z for W's spot on AZERTY).
		# The headless display server (tests) has no layout: the US name then.
		if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		return MOUSE_BUTTONS.get((ev as InputEventMouseButton).button_index, "Mouse %d" % (ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return JOY_BUTTONS.get((ev as InputEventJoypadButton).button_index, "Button %d" % (ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var motion := ev as InputEventJoypadMotion
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "Left stick"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "Right stick"
	return "?"


static func _is_gamepad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


# --- Changing them -------------------------------------------------------------------

## Something you pressed that can be a binding on that kind of device (gamepad
## true: a controller button or a trigger; false: a key or mouse button), or null.
static func bindable(ev: InputEvent, gamepad: bool) -> InputEvent:
	if gamepad:
		if ev is InputEventJoypadButton and ev.pressed:
			var button := InputEventJoypadButton.new()
			button.button_index = (ev as InputEventJoypadButton).button_index
			return button
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] \
				and (ev as InputEventJoypadMotion).axis_value > 0.6:
			var trigger := InputEventJoypadMotion.new()
			trigger.axis = (ev as InputEventJoypadMotion).axis
			trigger.axis_value = 1.0
			return trigger
		return null
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var key := InputEventKey.new()
		key.physical_keycode = (ev as InputEventKey).physical_keycode
		return key
	if ev is InputEventMouseButton and ev.pressed:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (ev as InputEventMouseButton).button_index
		return mouse
	return null


## Sets an action to ev on its kind of device (replacing what it was there),
## and saves.
static func bind(action: String, ev: InputEvent) -> void:
	var gamepad := _is_gamepad(ev)
	for old in InputMap.action_get_events(action):
		if _is_gamepad(old) == gamepad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)
	if ev is InputEventJoypadMotion:
		InputMap.action_set_deadzone(action, TRIGGER_PRESS)
	save_bindings()


## The other rebindable actions also set to ev (to point out on the page).
static func also_on(action: String, ev: InputEvent) -> PackedStringArray:
	var result := PackedStringArray()
	for row: Array in REBINDABLE:
		if row[0] != action and InputMap.action_has_event(row[0], ev):
			result.append(row[1])
	return result


## Back to the defaults for everything (and forgets the saved changes).
static func reset_to_defaults() -> void:
	for row: Array in REBINDABLE:
		if InputMap.has_action(row[0]):
			InputMap.action_erase_events(row[0])
	_defaults()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Every rebindable action as it is now: [section][action] = [descriptions].
static func save_bindings() -> void:
	var file := ConfigFile.new()
	for row: Array in REBINDABLE:
		var keyboard := []
		var controller := []
		for ev in InputMap.action_get_events(row[0]):
			(controller if _is_gamepad(ev) else keyboard).append(_describe(ev))
		file.set_value("keyboard", row[0], keyboard)
		file.set_value("controller", row[0], controller)
	var err := file.save(PATH)
	if err != OK:
		push_error("Couldn't save the controls: %s" % error_string(err))


static func _load_bindings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return # never changed: the defaults
	for row: Array in REBINDABLE:
		for section: String in ["keyboard", "controller"]:
			if not file.has_section_key(section, row[0]):
				continue
			var gamepad := section == "controller"
			for old in InputMap.action_get_events(row[0]):
				if _is_gamepad(old) == gamepad:
					InputMap.action_erase_event(row[0], old)
			for entry: Variant in file.get_value(section, row[0], []):
				var ev := _from_description(entry)
				if ev:
					InputMap.action_add_event(row[0], ev)
					if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
						InputMap.action_set_deadzone(row[0], TRIGGER_PRESS)


## An input as plain data, for the file.
static func _describe(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"key": int((ev as InputEventKey).physical_keycode)}
	if ev is InputEventMouseButton:
		return {"mouse": int((ev as InputEventMouseButton).button_index)}
	if ev is InputEventJoypadButton:
		return {"button": int((ev as InputEventJoypadButton).button_index)}
	var motion := ev as InputEventJoypadMotion
	return {"axis": int(motion.axis), "direction": motion.axis_value}


static func _from_description(entry: Variant) -> InputEvent:
	if not entry is Dictionary:
		return null
	var d: Dictionary = entry
	if d.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = int(d["key"]) as Key
		return key
	if d.has("mouse"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(d["mouse"]) as MouseButton
		return mouse
	if d.has("button"):
		var button := InputEventJoypadButton.new()
		button.button_index = int(d["button"]) as JoyButton
		return button
	if d.has("axis"):
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(d["axis"]) as JoyAxis
		motion.axis_value = float(d.get("direction", 1.0))
		return motion
	return null


# --- Making the defaults -------------------------------------------------------------

static func _ensure(action: StringName, deadzone := 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


static func _add(action: StringName, ev: InputEvent, deadzone := 0.5) -> void:
	_ensure(action, deadzone)
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## Physical keys = same positions on any keyboard layout.
static func _key(action: StringName, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	_add(action, ev)


static func _mouse(action: StringName, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	_add(action, ev)


static func _button(action: StringName, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	_add(action, ev)


static func _axis(action: StringName, axis: JoyAxis, direction: float, deadzone := STICK_DEADZONE) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	_add(action, ev, deadzone)
	# The deadzone belongs to the whole action, so set it even if a key created it first.
	InputMap.action_set_deadzone(action, deadzone)
