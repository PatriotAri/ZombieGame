@tool
class_name PlantData
extends Resource
## One kind of plant you can paint on the map: a tree, undergrowth (bushes,
## ferns, fallen logs) or a crop. Every file in world/map/plants/ is one. To add
## a plant, make a scene with its model, then a new PlantData file pointing at
## it (duplicate one and change it in the Inspector) and press "Update plant
## list" in the Map Tools panel (HOW_TO_MAP.md). world/map/plants.gd reads them.

@export var display_name := "Plant"
## Its model: a scene with a MeshInstance3D at the top.
@export var scene: PackedScene
@export_enum("Tree", "Undergrowth", "Crop") var kind := "Tree"
## The terrain's number for it (its slot in the terrain's mesh list). Set by
## "Update plant list"; never change it by hand: painted plants are stored by
## this number. -1: not in the list yet.
@export var mesh_id := -1

@export_group("Painting")
## Its share of the forest brush's mix (relative: 35 and 25 is 7 to 5). 0: the
## forest brush never paints it (crops).
@export_range(0.0, 100.0, 1.0) var forest_share := 0.0
## Random size range (1 = the model as made).
@export var scale_min := 0.8
@export var scale_max := 1.2
## Meters: the brushes keep plants of this kind at least this far apart.
@export_range(0.2, 20.0, 0.1) var spacing := 4.0
## The steepest slope (degrees) the brushes put it on.
@export_range(0.0, 90.0, 1.0) var max_slope := 35.0

@export_group("In the game")
## Meters: a solid trunk this thick (times the plant's size) stops people and
## bullets and blocks sight. 0: you walk through it.
@export_range(0.0, 2.0, 0.01) var trunk_radius := 0.0
## Crouching in it hides you from zombies (world/cover.gd).
@export var hides := false
## Meters: not drawn past this.
@export_range(10.0, 2000.0, 10.0) var view_distance := 300.0
@export var shadows := true
