extends CanvasLayer
## Every scene change (Continue, Load game, New game, restarting after you die,
## back to the main menu): the screen fades to black over FADE_TIME, "Loading..."
## shows while the next scene loads, then it cuts straight in.
## Use change_to() instead of SceneTree.change_scene_to_file(). It sits on the
## tree's root, outside both scenes, so it lasts through the change, and it's
## gone once the new scene is up. Nothing reacts to input while it's fading.

const PATH := "res://ui/scene_fade.gd"
const NAME := "SceneFade"
const FADE_TIME := 1.0

var _black: ColorRect
var _loading: Label


## Fades out, then changes to the scene at path. Does nothing if a change is
## already under way (a second press during the fade).
static func change_to(tree: SceneTree, path: String) -> void:
	if busy(tree):
		return
	var fade: CanvasLayer = load(PATH).new()
	tree.root.add_child(fade)
	fade.call("_run", path)


## Whether a change is under way.
static func busy(tree: SceneTree) -> bool:
	return tree.root.has_node(NAME)


func _init() -> void:
	name = NAME
	layer = 128 # over every menu and the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS # fades over the paused game too
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading = Label.new()
	_loading.text = "Loading..."
	_loading.visible = false
	_loading.add_theme_font_size_override("font_size", 24)
	add_child(_loading)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 32)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loading.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _run(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FADE_TIME)
	await tween.finished
	_loading.visible = true
	# Let a frame or two draw with "Loading..." up: loading holds the screen as it is.
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	tree.paused = false # pause survives a scene change, so clear it first
	tree.change_scene_to_file(path)
	await tree.scene_changed
	queue_free()
