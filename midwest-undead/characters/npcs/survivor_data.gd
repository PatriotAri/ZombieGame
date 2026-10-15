class_name SurvivorData
extends Resource
## One survivor holed up in town (see HOW_TO_ADD.md). Every file in
## characters/npcs/survivors/ is a survivor. Where they start and their spot in
## the station's back yard are SpawnPoints in the map scene (roles "survivor"
## and "survivor_home", Person set to their name).

## Their name as the game shows it. Saves, SpawnPoints and quests go by it.
@export var display_name := ""
## What they do at the base besides working a station. "machinist": makes
## benches (once the woodworker's at the station) instead of working one.
@export_enum("none", "machinist") var job := "none"
@export var outfit_color := Color(0.4, 0.4, 0.4)
@export var skin_color := Color(0.7, 0.55, 0.45)

@export_group("Talk")
## When you find them. With a "join" reply somewhere in it, picking that is what
## brings them (a "decline" reply leaves them there for now). Without one,
## hearing it out does.
@export var join_talk: QuestDialogue
## At the base, before their work menu. Optional.
@export var base_talk: QuestDialogue
## What they say over their work menu at the base.
@export var base_line := ""
