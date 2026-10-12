extends CanvasLayer
## The map (M, or Back/View on a controller): the town from above, with the zone
## grid colored by how safe each square is (see world/zones.gd), the main places
## labeled, and you. North is up. It shows exactly the area the grid covers.
## Like the inventory, it doesn't pause the game: your hands are busy and the
## world keeps going. Esc closes it (so does dying).

const Zones := preload("res://world/zones.gd")
const Controls := preload("res://core/controls.gd")

const ZONE_COLORS := {
	Zones.Status.DANGER: Color(0.85, 0.12, 0.08, 0.55),
	Zones.Status.HOSTILE: Color(0.95, 0.78, 0.12, 0.5),
	Zones.Status.SAFE: Color(0.0, 0.0, 0.0, 0.0),
}
const BACKGROUND := Color(0.2, 0.22, 0.15)
const ROAD := Color(0.36, 0.36, 0.37)
const BUILDING := Color(0.62, 0.58, 0.5)
const FENCE := Color(0.55, 0.42, 0.25)
const ZONE_BORDER := Color(1.0, 1.0, 1.0, 0.35)
const PLAYER := Color(0.3, 0.85, 1.0)
const CELL_NAME := Color(1.0, 1.0, 1.0, 0.55)
const REDRAW_INTERVAL := 0.2

var _player: Node3D
var _zones: Zones
var _roads: Array[Rect2] = []
var _buildings: Array[PackedVector2Array] = []
var _fences: Array[Rect2] = []
var _landmarks: Array = [] # [name, (x, z) position]
var _view: Control
var _redraw_timer := 0.0


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Control.new()
	add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_map)


## main.gd hands over what to draw. Roads and fences are rectangles in world
## (x, z); buildings are their four ground corners; landmarks are [name, (x, z)].
func setup(player: Node3D, zones: Zones, roads: Array[Rect2], buildings: Array[PackedVector2Array],
		fences: Array[Rect2], landmarks: Array) -> void:
	_player = player
	_zones = zones
	_roads = roads
	_buildings = buildings
	_fences = fences
	_landmarks = landmarks


func open() -> void:
	if visible or _player.get("is_dead") or _player.get("menu_open"):
		return
	_player.set("menu_open", true)
	visible = true
	_view.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_player.set("menu_open", false)
	if not _player.get("is_dead"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


## Zombies move and zones change color while it's open.
func _process(delta: float) -> void:
	if not visible:
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		_view.queue_redraw()


# --- Drawing -------------------------------------------------------------------

## Where the map sits on screen: a square as big as fits, with room for the
## title above and the legend below.
func _map_rect() -> Rect2:
	var screen := _view.size
	var side := minf(screen.x - 80.0, screen.y - 150.0)
	return Rect2((screen.x - side) / 2.0, 70.0, side, side)


## World (x, z) to screen. North (-z) is up, east (+x) is right: the same way
## round as the world, so turning left on the map is turning left in the game.
func _to_screen(world: Vector2) -> Vector2:
	var area := _map_rect()
	var bounds := Zones.bounds()
	return area.position + (world - bounds.position) / bounds.size * area.size


func _rect_to_screen(rect: Rect2) -> Rect2:
	var a := _to_screen(rect.position)
	return Rect2(a, _to_screen(rect.end) - a)


func _draw_map() -> void:
	if _player == null:
		return
	var font := ThemeDB.fallback_font
	var area := _map_rect()
	_view.draw_rect(area, BACKGROUND)

	for road in _roads:
		_view.draw_rect(_rect_to_screen(road), ROAD)
	for corners in _buildings:
		var points := PackedVector2Array()
		for corner in corners:
			points.append(_to_screen(corner))
		_view.draw_colored_polygon(points, BUILDING)
	for fence in _fences:
		_view.draw_rect(_rect_to_screen(fence), FENCE, false, 2.0)

	# The zone grid: fill each square by status, outline it, its name in the corner.
	for cell: Array in Zones.cells():
		var rect := _rect_to_screen(cell[1])
		var status := _zones.status_of(cell[0])
		if status != Zones.Status.SAFE:
			_view.draw_rect(rect, ZONE_COLORS[status])
		_view.draw_rect(rect, ZONE_BORDER, false, 1.0)
		_view.draw_string(font, rect.position + Vector2(5.0, 15.0), cell[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CELL_NAME)
	for landmark: Array in _landmarks:
		_draw_label(font, landmark[0], _to_screen(landmark[1]), 14)

	_draw_player()
	_view.draw_rect(area, Color(1, 1, 1, 0.5), false, 2.0)

	# Title, compass, legend.
	_view.draw_string(font, Vector2(area.position.x, area.position.y - 22.0), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	_view.draw_string(font, Vector2(area.position.x, area.position.y - 22.0),
			"%s to close" % Controls.hint("map"), HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, 16, Color(1, 1, 1, 0.7))
	_draw_compass(font, area.position + Vector2(area.size.x - 28.0, 34.0))
	var legend_y := area.end.y + 28.0
	var x := area.position.x
	for entry: Array in [[Zones.Status.DANGER, "Zombies"], [Zones.Status.HOSTILE, "Bandits only"],
			[Zones.Status.SAFE, "Safe"], [-1, "You"]]:
		var swatch := Rect2(x, legend_y - 13.0, 16.0, 16.0)
		if entry[0] == -1:
			_view.draw_colored_polygon(_arrow(swatch.get_center(), Vector2.UP, 9.0), PLAYER)
		else:
			_view.draw_rect(swatch, BACKGROUND)
			_view.draw_rect(swatch, ZONE_COLORS[entry[0]])
			_view.draw_rect(swatch, ZONE_BORDER, false, 1.0)
		_view.draw_string(font, Vector2(x + 24.0, legend_y), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		x += 40.0 + font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


## You: an arrow pointing the way you're facing.
func _draw_player() -> void:
	var pos := _to_screen(Vector2(_player.global_position.x, _player.global_position.z))
	var forward := -_player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var arrow := _arrow(pos, dir, 11.0)
	_view.draw_colored_polygon(arrow, PLAYER)
	_view.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color.BLACK, 1.5)


## A slim arrowhead pointing along dir. Kept narrow on purpose: a wide one
## reads as a triangle pointing the wrong way at most angles.
func _arrow(center: Vector2, dir: Vector2, size: float) -> PackedVector2Array:
	var side := dir.orthogonal()
	return PackedVector2Array([center + dir * size * 1.2, center - dir * size * 0.8 + side * size * 0.6,
			center - dir * size * 0.35, center - dir * size * 0.8 - side * size * 0.6])


func _draw_compass(font: Font, center: Vector2) -> void:
	_view.draw_colored_polygon(_arrow(center, Vector2.UP, 12.0), Color(1, 1, 1, 0.85))
	_draw_label(font, "N", center + Vector2(0, -22.0), 16)


## Centered text with a dark outline, readable over any zone color.
func _draw_label(font: Font, text: String, center: Vector2, font_size: int) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center + Vector2(-width / 2.0, font_size * 0.35)
	_view.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	_view.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
