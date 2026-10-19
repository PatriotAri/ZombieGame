extends RefCounted
## What the map screen (ui/map_menu.gd) and discoveries (world/discoveries.gd)
## need to know about the map, worked out once from it when the game starts
## (main.gd). Never instanced.

const Building := preload("res://world/building.gd")
const Place := preload("res://world/markers/place.gd")


## Every building's outline on the ground, (x, z) corners.
static func buildings(town: Node) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for node in town.find_children("*", "Node3D", true, false):
		if node is Building and (node as Building).size_depth > 0.0:
			result.append((node as Building).ground_corners())
	return result


## One rectangle on the ground (x, z) for each node in the group, covering its
## box collision shapes: the roads ("map_road") and the compound fence ("map_fence").
static func rects(tree: SceneTree, group: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for node in tree.get_nodes_in_group(group):
		var rect := Rect2()
		var first := true
		for col: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
			if not col.shape is BoxShape3D:
				continue
			var half := (col.shape as BoxShape3D).size / 2.0
			for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z),
					Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
				var p := col.global_transform * corner
				if first:
					rect = Rect2(p.x, p.z, 0, 0)
					first = false
				else:
					rect = rect.expand(Vector2(p.x, p.z))
		if not first:
			result.append(rect)
	return result


## Street names for the map screen, as [name, (x, z)]. Always shown.
static func streets(places: Array[Place]) -> Array:
	var result := []
	for place in places:
		if place.kind == "street":
			result.append([place.place_name, Vector2(place.global_position.x, place.global_position.z) + place.label_offset])
	return result


## Places you find by going near them (world/discoveries.gd); the map names each
## one only after that. center and label_at are (x, z); radius is in meters.
static func discoverable(places: Array[Place]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place in places:
		if place.kind == "discoverable":
			var center := Vector2(place.global_position.x, place.global_position.z)
			result.append({"name": place.place_name, "center": center, "radius": place.radius,
					"label_at": center + place.label_offset})
	return result
