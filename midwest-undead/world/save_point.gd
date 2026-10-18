extends StaticBody3D
## The logbook on the Quartermaster's counter. Look at it and press interact to
## open the save / load menu. Anything with an interact_prompt() method like this
## shows an "E: ..." prompt; main.gd decides what happens when you use it.

const LOOK := preload("res://world/props/logbook.tscn")


## In the map scene it comes with its book and collision already; one made in
## code gets the logbook prop's look (world/props/logbook.tscn: set Models there
## to swap in a model; HOW_TO_MODEL.md, "Props").
func _ready() -> void:
	if get_child_count() > 0:
		return
	add_child(KitProp.make(LOOK))
	# Bigger than the book, so it's easy to aim at.
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.25, 0.6)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.12
	add_child(col)


func interact_prompt() -> String:
	return "open the logbook (save / load)"
