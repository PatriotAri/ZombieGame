class_name ZombieKind
extends Resource
## One kind of zombie (see HOW_TO_ADD.md). Every file in characters/zombie/kinds/
## is a kind: every new zombie, at the start and arriving later, rolls one by
## their spawn chances. The kind marked Fills The Rest (the walker) is what's
## left over.

const DIR := "res://characters/zombie/kinds/"

## Unique, no spaces. Saves remember each zombie's kind by it.
@export var id := ""
## The chance (0-1) that a new zombie is this kind.
@export_range(0.0, 1.0, 0.005) var spawn_chance := 0.05
## Ignore the spawn chance: whatever's left after the other kinds is this kind.
## Exactly one kind should have it.
@export var fills_the_rest := false

@export_group("Body")
@export var health := 100.0
## Each one picks a walking speed in this range (m/s). You walk at 4.
@export var min_speed := 1.2
@export var max_speed := 2.2
## Speed while chasing someone. 0: its walking speed.
@export var hunt_speed := 0.0
## Leans forward when running flat out.
@export var leans_when_running := false
## "crawling": lies flat and drags itself along: low (shots at chest height go
## over it; its head is at the front, near the ground).
@export_enum("standing", "crawling") var posture := "standing"
## Stretches its body (1, 1, 1: as built). 0.75 wide and deep looks thin.
@export var body_scale := Vector3.ONE
## Skin color. Fully transparent (the default): the scene's usual skin.
@export var skin_color := Color(0, 0, 0, 0)
## Its groans, snarls and death: 1 is normal, higher is shriller.
@export var voice_pitch := 1.0

static var _kinds := {} # id -> ZombieKind
static var _rolled: Array[ZombieKind] = [] # the ones with a chance, in id order
static var _rest: ZombieKind = null


static func _load() -> void:
	if not _kinds.is_empty():
		return
	for file in DirAccess.get_files_at(DIR):
		file = file.trim_suffix(".remap") # exported games list "x.tres.remap"
		if not file.ends_with(".tres"):
			continue
		var kind := load(DIR + file) as ZombieKind
		if kind == null or kind.id == "":
			push_warning("%s isn't a zombie kind with an id: skipped." % (DIR + file))
			continue
		_kinds[kind.id] = kind
		if kind.fills_the_rest:
			if _rest:
				push_warning("Both %s and %s fill the rest; %s does." % [_rest.id, kind.id, _rest.id])
			else:
				_rest = kind
		else:
			_rolled.append(kind)
	_rolled.sort_custom(func(a: ZombieKind, b: ZombieKind) -> bool: return a.id < b.id)
	if _rest == null and not _rolled.is_empty():
		push_warning("No zombie kind fills the rest: %s does." % _rolled[0].id)
		_rest = _rolled[0]


## The kind called id, or the one that fills the rest if there's none by that name.
static func find(id: String) -> ZombieKind:
	_load()
	return _kinds.get(id, _rest)


## A kind picked by the spawn chances, with these dice.
static func roll(dice: RandomNumberGenerator) -> ZombieKind:
	_load()
	var r := dice.randf()
	for kind in _rolled:
		if r < kind.spawn_chance:
			return kind
		r -= kind.spawn_chance
	return _rest
