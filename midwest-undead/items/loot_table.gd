class_name LootTable
extends Resource
## What a kind of container tends to have (see HOW_TO_ADD.md). Every file in
## items/loot/ is a table; a container's Loot Table setting names one (the
## file's name without .tres). At the start of each new game, every roll
## happens with its chance and adds one of its items.

@export var rolls: Array[LootRoll] = []
