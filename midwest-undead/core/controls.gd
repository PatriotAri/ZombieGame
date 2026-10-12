extends RefCounted
## Every input action in one place, for keyboard/mouse and Xbox-layout controllers.
## Godot maps any standard gamepad (Xbox, PlayStation, Switch Pro...) to the same
## button names, so "A" below is Cross on a PlayStation pad, and so on.
## main.gd calls setup() once at startup. Never instanced.
##
##   Action           Keyboard / mouse   Controller
##   move             WASD               left stick
##   look             mouse              right stick
##   jump             Space              A
##   sprint           Shift (hold)       L3 / click left stick (toggles)
##   crouch           Ctrl (hold)        B (toggles)
##   use held item    left click         RT   (shoot, swing, heal, eat...)
##   next/prev item   mouse wheel        D-pad right = next, D-pad left = previous
##   pick held item   1-9                -    (numbered on the inventory screen)
##   inventory        Tab                Y
##   interact         E                  X
##   reload           R                  RB
##   quick heal       Q                  LB   (switches to a health pack and uses it)
##   flashlight       F                  D-pad up
##   map              M                  Back / View
##   pause            Esc                Start (Menu button)
##   in menus: move a whole stack with Shift+click, or hold RB and press A.

## True when the last input came from a controller; HUD prompts use it to show
## "X" instead of "E", etc. main.gd updates it as input arrives.
static var using_gamepad := false

const STICK_DEADZONE := 0.2 # analog stick actions: small deadzone for fine movement

const HINTS := {
	"interact": ["E", "X"],
	"reload": ["R", "RB"],
	"use_health_pack": ["Q", "LB"],
	"use_held": ["Click", "RT"],
	"restart": ["R", "A"],
	"continue": ["E / Space / Click", "A / X"],
	"map": ["M", "Back"],
	"inventory": ["Tab", "Y"],
	"leave": ["Esc", "B"],
}

## The pause menu's Controls page: [what it does, keyboard / mouse, controller].
## Keep in step with setup() below.
const TABLE := [
	["Move", "WASD", "Left stick"],
	["Look", "Mouse", "Right stick"],
	["Sprint", "Shift (hold)", "L3 (toggle)"],
	["Crouch", "Ctrl (hold)", "B (toggle)"],
	["Jump", "Space", "A"],
	["Use held item", "Left click", "RT"],
	["Switch item", "Wheel / 1-9", "D-pad left / right"],
	["Inventory", "Tab", "Y"],
	["Search / pick up / talk / open", "E", "X"],
	["Reload", "R", "RB"],
	["Quick heal", "Q", "LB"],
	["Flashlight", "F", "D-pad up"],
	["Map", "M", "Back"],
	["Pause", "Esc", "Start"],
	["Move a whole stack (in menus)", "Shift + click", "RB + A"],
]


static func setup() -> void:
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
	_mouse("use_held", MOUSE_BUTTON_LEFT); _axis("use_held", JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.5)
	_key("interact", KEY_E); _button("interact", JOY_BUTTON_X)
	_key("reload", KEY_R); _button("reload", JOY_BUTTON_RIGHT_SHOULDER)
	_key("use_health_pack", KEY_Q); _button("use_health_pack", JOY_BUTTON_LEFT_SHOULDER)
	_mouse("item_next", MOUSE_BUTTON_WHEEL_DOWN); _button("item_next", JOY_BUTTON_DPAD_RIGHT)
	_mouse("item_prev", MOUSE_BUTTON_WHEEL_UP); _button("item_prev", JOY_BUTTON_DPAD_LEFT)
	for i in range(1, 10):
		_key("slot_%d" % i, (KEY_0 + i) as Key)
	_key("flashlight", KEY_F); _button("flashlight", JOY_BUTTON_DPAD_UP)
	_key("map", KEY_M); _button("map", JOY_BUTTON_BACK)
	_key("inventory", KEY_TAB); _button("inventory", JOY_BUTTON_Y)
	_key("pause", KEY_ESCAPE); _button("pause", JOY_BUTTON_START)
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


## The key/button name to show in a prompt for an action.
static func hint(action: String) -> String:
	var pair: Array = HINTS.get(action, ["?", "?"])
	return pair[1] if using_gamepad else pair[0]


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
