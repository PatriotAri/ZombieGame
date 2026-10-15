extends StaticBody3D
## The logbook on the Quartermaster's counter. Look at it and press interact to
## open the save / load menu. Anything with an interact_prompt() method like this
## shows an "E: ..." prompt; main.gd decides what happens when you use it.

## In the map scene it comes with its book and collision already; only one
## made in code builds them.
func _ready() -> void:
	if get_child_count() > 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.3, 0.2)
	var book := BoxMesh.new()
	book.size = Vector3(0.28, 0.05, 0.38)
	book.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = book
	mesh.position.y = 0.025
	add_child(mesh)

	var page_mat := StandardMaterial3D.new()
	page_mat.albedo_color = Color(0.9, 0.87, 0.78)
	var pages := BoxMesh.new()
	pages.size = Vector3(0.26, 0.012, 0.36)
	pages.material = page_mat
	var page_mesh := MeshInstance3D.new()
	page_mesh.mesh = pages
	page_mesh.position.y = 0.056
	add_child(page_mesh)

	# Bigger than the book, so it's easy to aim at.
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.25, 0.6)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.12
	add_child(col)


func interact_prompt() -> String:
	return "open the logbook (save / load)"
