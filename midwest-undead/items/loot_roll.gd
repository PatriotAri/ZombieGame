class_name LootRoll
extends Resource
## One roll on a loot table: with this chance, the container gets one of the
## items (picked evenly if there are several).

@export_range(0.0, 1.0, 0.01) var chance := 0.1
@export var items: Array[LootPick] = []
