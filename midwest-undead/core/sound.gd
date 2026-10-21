extends RefCounted
## Plays sound effects. Never instanced: call Sound.play_at() / Sound.play_ui().
##
## A sound id like "zombie_groan" loads res://assets/audio/zombie_groan.wav, or,
## if that doesn't exist, every numbered variant (zombie_groan_1.wav,
## zombie_groan_2.wav, ...) and picks one at random each time. Missing sounds
## are skipped with a single warning, so gameplay never depends on audio files.
## To replace a placeholder, drop a new .wav or .ogg with the same name in
## assets/audio/ (and delete the old one if the extension changed).
##
## The players are kept and used again (a node under the tree's root holds
## them), not made and freed for every sound. At most MAX_WORLD_SOUNDS play out
## in the world at once: with a crowd groaning, a new sound takes the place of
## the farthest one playing, or isn't played if it's the farthest itself.

const Settings := preload("res://core/settings.gd")

const DIR := "res://assets/audio/"
const EXTENSIONS := ["wav", "ogg"]
const MAX_VARIANTS := 9

## Loaded sounds (id -> Array of AudioStream, empty when missing) live in a
## dictionary on the tree's root node rather than in a static var: a static var
## would keep them alive past engine shutdown ("resources still in use at exit").
const CACHE_META := &"sound_cache"
const POOL_NAME := "SoundPool"
const MAX_WORLD_SOUNDS := 32


## A sound out in the world, at a fixed spot. Fades out by max_distance meters.
## context is any node in the scene tree (needed to reach the tree).
## pitch: 1 as recorded, lower is deeper.
static func play_at(context: Node, id: String, pos: Vector3, volume_db := 0.0,
		max_distance := 30.0, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if not context.is_inside_tree():
		return
	# Out of earshot: don't bother (dozens of zombies moan all over town).
	var camera := context.get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(pos) > max_distance:
		return
	var stream := _pick(context, id)
	if stream == null:
		return
	var player := _world_player(_pool(context), pos, camera.global_position if camera else pos)
	if player == null:
		return # farther off than every sound playing, with no room left
	player.bus = Settings.SFX_BUS # the Effects volume slider
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = max_distance / 6.0 # stays clearly audible for the first sixth
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.global_position = pos
	player.play()


## A sound with no position: the player's own body, hands, and menus.
## pitch: 1 as recorded, lower is deeper.
static func play_ui(context: Node, id: String, volume_db := 0.0, pitch_jitter := 0.05, pitch := 1.0) -> void:
	if not context.is_inside_tree():
		return
	var stream := _pick(context, id)
	if stream == null:
		return
	var pool := _pool(context)
	var player: AudioStreamPlayer = null
	for idle: AudioStreamPlayer in pool.find_children("*", "AudioStreamPlayer", false, false):
		if not idle.playing:
			player = idle
			break
	if player == null:
		player = AudioStreamPlayer.new()
		pool.add_child(player)
	player.bus = Settings.SFX_BUS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


## How many world sounds are playing now (for tests).
static func world_sounds_playing(context: Node) -> int:
	var count := 0
	for player: AudioStreamPlayer3D in _pool(context).find_children("*", "AudioStreamPlayer3D", false, false):
		if player.playing:
			count += 1
	return count


## The node holding the players, under the tree's root (made the first time).
static func _pool(context: Node) -> Node:
	var root := context.get_tree().root
	var pool := root.get_node_or_null(POOL_NAME)
	if pool == null:
		pool = Node.new()
		pool.name = POOL_NAME
		root.add_child(pool)
	return pool


## A player for a world sound at pos, heard from listener: an idle one, a new
## one while there are fewer than MAX_WORLD_SOUNDS, or the farthest one playing
## if pos is nearer than it. null: pos is the farthest; no room.
static func _world_player(pool: Node, pos: Vector3, listener: Vector3) -> AudioStreamPlayer3D:
	var farthest: AudioStreamPlayer3D = null
	var farthest_sq := -1.0
	var players := pool.find_children("*", "AudioStreamPlayer3D", false, false)
	for player: AudioStreamPlayer3D in players:
		if not player.playing:
			return player
		var dist_sq := player.global_position.distance_squared_to(listener)
		if dist_sq > farthest_sq:
			farthest = player
			farthest_sq = dist_sq
	if players.size() < MAX_WORLD_SOUNDS:
		var made := AudioStreamPlayer3D.new()
		pool.add_child(made)
		return made
	if pos.distance_squared_to(listener) >= farthest_sq:
		return null
	farthest.stop()
	return farthest


static func _pick(context: Node, id: String) -> AudioStream:
	var root := context.get_tree().root
	if not root.has_meta(CACHE_META):
		root.set_meta(CACHE_META, {})
	var cache: Dictionary = root.get_meta(CACHE_META)
	if not cache.has(id):
		cache[id] = _load(id)
	var streams: Array = cache[id]
	return null if streams.is_empty() else streams.pick_random()


static func _load(id: String) -> Array:
	var found := []
	var single := _find(id)
	if single:
		found.append(single)
	else:
		for i in range(1, MAX_VARIANTS + 1):
			var variant := _find("%s_%d" % [id, i])
			if variant == null:
				break
			found.append(variant)
	if found.is_empty():
		push_warning("Sound '%s' not found in %s; it will be silent." % [id, DIR])
	return found


static func _find(name: String) -> AudioStream:
	for ext: String in EXTENSIONS:
		var path := "%s%s.%s" % [DIR, name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
