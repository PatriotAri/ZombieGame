@tool
class_name PersonData
extends Resource
## Someone in the world (QUESTS.md, "People"): who they are, what kind of
## person (their scene), how they look and what they say when there's nothing
## else to talk about. Files go in characters/npcs/people/. Put them on the map
## with a person marker (Map Tools > Quests > New person), or have a quest
## bring them in (the Spawn Person action).
##
## Survivors you can recruit have their own files (survivor_data.gd).

## What quests call them (Npc Id): no spaces, unique, and saves go by it.
@export var id := ""
## Their name as the game shows it.
@export var display_name := ""
## What kind of person: their scene in characters/npcs/ (shopkeeper.tscn
## trades, woodworker.tscn builds, human_npc.tscn just talks...). Empty:
## human_npc.tscn.
@export var scene: PackedScene
## Float their name over their head.
@export var show_name_tag := true

@export_group("Look")
## Their own model (HOW_TO_MODEL.md). Empty: the scene's.
@export var model: PackedScene
## Leave at the default (all zero) to keep the scene's colors.
@export var outfit_color := Color(0, 0, 0, 0)
@export var skin_color := Color(0, 0, 0, 0)

@export_group("Talk")
## What they say when they have no quest business with you and nothing of
## their own (trading, building) to offer. Optional.
@export var talk: QuestDialogue
## What they say when you untie them, if they're held captive (a person
## marker's Captive). Optional.
@export var untie_talk: QuestDialogue

const DEFAULT_SCENE := "res://characters/npcs/human_npc.tscn"


## Them, ready to be put in the world (set where, then add them).
func make() -> HumanNPC:
	var person: HumanNPC = (scene if scene else load(DEFAULT_SCENE)).instantiate()
	apply_to(person)
	return person


## Makes an NPC this person (before it's in the tree: their look is built then).
func apply_to(person: HumanNPC) -> void:
	person.person = self
	if id != "":
		person.npc_id = id
	if display_name != "":
		person.display_name = display_name
	person.show_name_tag = show_name_tag
	if model:
		person.model = model
	if outfit_color.a > 0.0:
		person.outfit_color = outfit_color
	if skin_color.a > 0.0:
		person.skin_color = skin_color
