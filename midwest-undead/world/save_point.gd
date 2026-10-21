extends StaticBody3D
## The logbook on the Quartermaster's counter. Look at it and press interact to
## open the save / load menu (ui/game_ui.gd opens it: Player.open_save_menu()).

const LOOK := preload("res://world/props/logbook.tscn")
const Player := preload("res://characters/player/player.gd")


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	Interactable.attach(self, interact_prompt).interacted.connect(_on_interacted)


## In the map scene it comes with its book and collision already; one made in
## code gets the logbook prop's look (world/props/logbook.tscn: set Models there
## to swap in a model; HOW_TO_MODEL.md, "Props").
func _build() -> void:
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


func _on_interacted(actor: Node3D) -> void:
	if actor is Player:
		(actor as Player).open_save_menu()
