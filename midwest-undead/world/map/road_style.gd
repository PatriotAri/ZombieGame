@tool
class_name RoadStyle
extends Resource
## What kind of road a Road (world/map/road.gd) is: how wide, what it's made of,
## its markings, and how it cuts into hills. Every file in world/map/roads/ is
## one: paved two-lane, gravel road, dirt track. To make a new kind, duplicate
## one of those files and change it in the Inspector (HOW_TO_MAP.md).
##
## Ground textures are the terrain's texture list (world/map/terrain_assets.tres):
## Grass 0, Rock 1, Forest floor 2, Dirt 3, Worn path 4, Gravel 5, Mud 6,
## Plowed field 7, Red clay 8, Creek stones 9.

@export var display_name := "Road"

@export_group("Surface")
## Meters: the part you drive on (both lanes together).
@export_range(1.0, 20.0, 0.1) var width := 7.0
## "Paved": a surface of its own on top of the ground (asphalt, concrete), in
## surface_color. "Painted": the ground itself, painted with surface_texture
## (gravel, dirt).
@export_enum("Paved", "Painted") var surface := "Paved"
## The paved surface's color.
@export var surface_color := Color(0.16, 0.16, 0.17)
## The ground painted under the road (and as the road, when it's painted).
@export_enum("Grass:0", "Rock:1", "Forest floor:2", "Dirt:3", "Worn path:4", "Gravel:5", "Mud:6", "Plowed field:7", "Red clay:8", "Creek stones:9") var surface_texture := 5
## Painted roads only: just two wheel ruts of surface_texture, with grass
## between them and either side (a dirt track or logging road).
@export var ruts := false
## Meters across each rut, and between the middle of the two.
@export_range(0.2, 1.5, 0.05) var rut_width := 0.6
@export_range(1.0, 2.5, 0.05) var rut_spacing := 1.7

@export_group("Shoulders")
## Meters of shoulder each side, painted with shoulder_texture.
@export_range(0.0, 5.0, 0.1) var shoulder_width := 1.0
@export_enum("Grass:0", "Rock:1", "Forest floor:2", "Dirt:3", "Worn path:4", "Gravel:5", "Mud:6", "Plowed field:7", "Red clay:8", "Creek stones:9") var shoulder_texture := 5

@export_group("Markings")
## Paved roads only.
@export_enum("None", "Dashed", "Solid", "Double") var center_line := "Dashed"
@export var center_line_color := Color(0.85, 0.7, 0.15)
@export var edge_lines := true
@export var edge_line_color := Color(0.9, 0.9, 0.88)

@export_group("Hills")
## Where the road runs across a hillside, the ground is cut away above it and
## built up below it. Steepness of the cut bank above (rise over run: 1 is 45
## degrees; steeper banks turn to rock, like a real road cut) and of the fill
## below.
@export_range(0.2, 3.0, 0.05) var cut_slope := 1.2
@export_range(0.2, 2.0, 0.05) var fill_slope := 0.6
## Meters along the road over which bumps in the ground are smoothed out (the
## road rises and falls with the land, but gently).
@export_range(2.0, 60.0, 1.0) var smoothing := 20.0
