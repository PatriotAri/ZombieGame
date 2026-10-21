extends SceneTree
## The smoke test: boots the main menu, then the game, with no window, lets
## the game run for GAME_SECONDS of play, and fails if anything printed an
## error on the way (script errors, engine errors, a scene that won't load).
## Warnings are printed but don't fail it. See HOW_TO_TEST.md.
##
## Run it from the folder holding this project's folder:
##   godot --headless --path midwest-undead --script res://tests/smoke/smoke.gd
## It exits with 0 if it passed, 1 if not.

const MENU_SCENE := "res://ui/main_menu.tscn"
const GAME_SCENE := "res://world/main.tscn"
const MENU_SECONDS := 1.0
## Long enough for zombies to wander, the clock to tick and the population to
## top up; short enough to run on every push.
const GAME_SECONDS := 10.0


## Counts every error printed anywhere in the engine, from any thread.
class ErrorCounter extends Logger:
	var count := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		count += 1
		_lock.unlock()

	func total() -> int:
		_lock.lock()
		var n := count
		_lock.unlock()
		return n


var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


func _run() -> void:
	var passed: bool = await _play(MENU_SCENE, MENU_SECONDS)
	if passed:
		passed = await _play(GAME_SCENE, GAME_SECONDS)
	var errors := _errors.total()
	if errors > 0:
		passed = false
		printerr("SMOKE TEST: %d error(s) printed above." % errors)
	print("SMOKE TEST: %s" % ("passed" if passed else "FAILED"))
	OS.remove_logger(_errors)
	quit(0 if passed else 1)


## Opens the scene and runs it for that many seconds of physics. False if it
## didn't open.
func _play(path: String, seconds: float) -> bool:
	print("SMOKE TEST: %s for %.0f s" % [path, seconds])
	if change_scene_to_file(path) != OK:
		printerr("SMOKE TEST: couldn't open %s." % path)
		return false
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		await physics_frame
	if current_scene == null or current_scene.scene_file_path != path:
		printerr("SMOKE TEST: %s isn't the running scene." % path)
		return false
	return true
