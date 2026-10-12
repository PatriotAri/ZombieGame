extends CanvasLayer
## The map (M, or Back/View on a controller): the town from above, each zone
## colored by how safe it is and outlined (see world/zones.gd), the streets
## named, the places you've found named (world/discoveries.gd), and you. North is up. Zoomed all the way out it shows exactly the area
## the grid covers. The grid itself isn't drawn; the square under the pointer (or
## the middle, on a controller) is named below the map.
## Zoom: mouse wheel, or the right stick. Pan: drag, WASD, or the left stick.
## Space / A puts you back in the middle. It opens centered on you, at the zoom
## you left it at.
## Like the inventory, it doesn't pause the game: your hands are busy and the
## world keeps going. Esc closes it (so does dying).

const Zones := preload("res://world/zones.gd")
const Controls := preload("res://core/controls.gd")
const Discoveries := preload("res://world/discoveries.gd")

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
const ZONE_OUTLINE := Color(1.0, 0.95, 0.75, 0.9)
const REDRAW_INTERVAL := 0.2
const MAX_ZOOM := 8.0 # 1 = the whole grid fits
const WHEEL_ZOOM := 1.25 # per wheel notch
const STICK_ZOOM := 2.0 # doublings per second, stick all the way
const PAN_SPEED := 0.8 # map widths per second, key held or stick all the way
const HELP_KEYBOARD := "Wheel zoom  ·  Drag / WASD pan  ·  Space center  ·  %s close"
const HELP_GAMEPAD := "R stick zoom  ·  L stick pan  ·  A center  ·  %s close"

var _player: Node3D
var _zones: Zones
var _roads: Array[Rect2] = []
var _buildings: Array[PackedVector2Array] = []
var _fences: Array[Rect2] = []
var _streets: Array = [] # [name, (x, z) position]
var _discoveries: Discoveries
var _view: Control # the frame, title and legend
var _canvas: Control # the map itself, clipped to its square
var _redraw_timer := 0.0
var _zoom := 1.0
var _center := Vector2.ZERO # world (x, z) in the middle of the map
var _dragging := false


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE # mouse input goes to _unhandled_input
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_frame)
	_canvas = Control.new()
	_canvas.clip_contents = true # zoomed in, nothing spills past the edge
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_canvas)
	_canvas.draw.connect(_draw_map)


## main.gd hands over what to draw. Roads and fences are rectangles in world
## (x, z); buildings are their four ground corners; streets are [name, (x, z)].
func setup(player: Node3D, zones: Zones, discoveries: Discoveries, roads: Array[Rect2],
		buildings: Array[PackedVector2Array], fences: Array[Rect2], streets: Array) -> void:
	_player = player
	_zones = zones
	_discoveries = discoveries
	_roads = roads
	_buildings = buildings
	_fences = fences
	_streets = streets


func open() -> void:
	if visible or _player.get("is_dead") or _player.get("menu_open"):
		return
	_player.set("menu_open", true)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dragging = false
	_fit_canvas()
	_center_on_player()
	_redraw()


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
	elif not visible:
		return
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		_center_on_player()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := WHEEL_ZOOM if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_ZOOM
			_zoom_at(_zoom * step, _canvas.get_local_mouse_position())
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = button.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			_pan(-(event as InputEventMouseMotion).relative / _canvas.size * _visible_world_size())
		_redraw() # the square under the pointer
		get_viewport().set_input_as_handled()


## Keys and sticks, plus a regular redraw: zombies move and zones change color
## while it's open.
func _process(delta: float) -> void:
	if not visible:
		return
	_fit_canvas()
	var pan := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if pan != Vector2.ZERO:
		_pan(pan * PAN_SPEED * delta * _visible_world_size().x)
	var zoom := Input.get_axis("look_down", "look_up")
	if zoom != 0.0:
		_zoom_at(_zoom * pow(2.0, zoom * STICK_ZOOM * delta), _canvas.size / 2.0)
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		_redraw()


## Keeps the map's square where _map_rect says (the window can be resized).
func _fit_canvas() -> void:
	var area := _map_rect()
	if _canvas.position != area.position or _canvas.size != area.size:
		_canvas.position = area.position
		_canvas.size = area.size
		_clamp_center()


func _redraw() -> void:
	_view.queue_redraw()
	_canvas.queue_redraw()


# --- Zoom and pan ----------------------------------------------------------------

## How much of the world (x, z) the map shows at the current zoom.
func _visible_world_size() -> Vector2:
	return Zones.bounds().size / _zoom


func _center_on_player() -> void:
	_center = Vector2(_player.global_position.x, _player.global_position.z)
	_clamp_center()
	_redraw()


func _pan(world_offset: Vector2) -> void:
	_center += world_offset
	_clamp_center()
	_redraw()


## Zooms keeping the world point under `pivot` (a spot on the map, in its own
## coordinates) where it is: zooming with the wheel goes toward the pointer.
func _zoom_at(zoom: float, pivot: Vector2) -> void:
	var before := _to_world(pivot)
	_zoom = clampf(zoom, 1.0, MAX_ZOOM)
	_clamp_center()
	_center += before - _to_world(pivot)
	_clamp_center()
	_redraw()


## Never scrolls past the edge of the grid.
func _clamp_center() -> void:
	var bounds := Zones.bounds()
	var half := _visible_world_size() / 2.0
	_center = _center.clamp(bounds.position + half, bounds.end - half)


# --- Drawing -------------------------------------------------------------------

## Where the map sits on screen: a square as big as fits, with room for the
## title above and the legend below.
func _map_rect() -> Rect2:
	var screen := _view.size
	var side := minf(screen.x - 80.0, screen.y - 150.0)
	return Rect2((screen.x - side) / 2.0, 70.0, side, side)


## World (x, z) to a point on the map (the map's own coordinates, so (0, 0) is
## its top-left corner). North (-z) is up, east (+x) is right: the same way
## round as the world, so turning left on the map is turning left in the game.
func _to_map(world: Vector2) -> Vector2:
	var shown := _visible_world_size()
	return (world - (_center - shown / 2.0)) / shown * _canvas.size


func _to_world(point: Vector2) -> Vector2:
	var shown := _visible_world_size()
	return _center - shown / 2.0 + point / _canvas.size * shown


func _rect_to_map(rect: Rect2) -> Rect2:
	var a := _to_map(rect.position)
	return Rect2(a, _to_map(rect.end) - a)


## The map itself, drawn on _canvas (clipped to the map's square).
func _draw_map() -> void:
	if _player == null or _canvas.size == Vector2.ZERO:
		return
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), BACKGROUND)

	for road in _roads:
		_canvas.draw_rect(_rect_to_map(road), ROAD)
	for corners in _buildings:
		var points := PackedVector2Array()
		for corner in corners:
			points.append(_to_map(corner))
		_canvas.draw_colored_polygon(points, BUILDING)
	for fence in _fences:
		_canvas.draw_rect(_rect_to_map(fence), FENCE, false, 2.0)

	# Zones: filled by status, outlined around their edge, named in the middle.
	for zone: Dictionary in Zones.ZONES:
		var status := _zones.status_of(zone["name"])
		var rects := Zones.zone_rects(zone)
		var bounds := Rect2()
		for world_rect in rects:
			var rect := _rect_to_map(world_rect)
			if status != Zones.Status.SAFE:
				_canvas.draw_rect(rect, ZONE_COLORS[status])
			bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
		_draw_zone_outline(rects)
		_draw_label(_canvas, font, _zones.full_name(zone["name"]), bounds.get_center() + Vector2(0, -bounds.size.y / 2.0 - 10.0), 15)
	for street: Array in _streets:
		_draw_label(_canvas, font, street[0], _to_map(street[1]), 14)
	for place in _discoveries.places:
		if _discoveries.is_discovered(place["name"]):
			_draw_label(_canvas, font, place["name"], _to_map(place["label_at"]), 14)

	_draw_player()
	if Controls.using_gamepad: # what the square readout below refers to
		var mid := _canvas.size / 2.0
		_canvas.draw_line(mid - Vector2(8, 0), mid + Vector2(8, 0), Color(1, 1, 1, 0.8), 1.5)
		_canvas.draw_line(mid - Vector2(0, 8), mid + Vector2(0, 8), Color(1, 1, 1, 0.8), 1.5)
	_canvas.draw_rect(Rect2(Vector2.ONE, _canvas.size - Vector2(2, 2)), Color(1, 1, 1, 0.5), false, 2.0) # the border


## Around the map, drawn on _view: the border, title, help, compass, the square
## you're pointing at, and the legend.
func _draw_frame() -> void:
	if _player == null:
		return
	var font := ThemeDB.fallback_font
	var area := _map_rect()
	_view.draw_string(font, Vector2(area.position.x, area.position.y - 22.0), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	var help := (HELP_GAMEPAD if Controls.using_gamepad else HELP_KEYBOARD) % Controls.hint("map")
	_view.draw_string(font, Vector2(area.position.x, area.position.y - 22.0),
			help, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, 15, Color(1, 1, 1, 0.7))
	_draw_compass(font, area.position + Vector2(area.size.x - 28.0, 34.0))

	# The square being pointed at: under the mouse, or the middle on a controller.
	var point := _canvas.size / 2.0 if Controls.using_gamepad else _view.get_local_mouse_position() - area.position
	if Rect2(Vector2.ZERO, area.size).has_point(point):
		var world := _to_world(point)
		_view.draw_string(font, Vector2(area.position.x, area.end.y + 28.0), _zones.describe(Vector3(world.x, 0.0, world.y)),
				HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, 16, Color(1, 1, 1, 0.85))

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


## The outer edge of a zone: each square's sides that don't touch another square
## of the same zone.
func _draw_zone_outline(rects: Array[Rect2]) -> void:
	for r in rects:
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var neighbors := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)] # above, right, below, left
		for side in 4:
			var neighbor := Rect2(r.position + neighbors[side] * r.size, r.size)
			if not rects.any(func(other: Rect2) -> bool: return other.is_equal_approx(neighbor)):
				_canvas.draw_line(_to_map(corners[side]), _to_map(corners[(side + 1) % 4]), ZONE_OUTLINE, 2.5)


## You: an arrow pointing the way you're facing.
func _draw_player() -> void:
	var pos := _to_map(Vector2(_player.global_position.x, _player.global_position.z))
	var forward := -_player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var arrow := _arrow(pos, dir, 11.0)
	_canvas.draw_colored_polygon(arrow, PLAYER)
	_canvas.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color.BLACK, 1.5)


## A slim arrowhead pointing along dir. Kept narrow on purpose: a wide one
## reads as a triangle pointing the wrong way at most angles.
func _arrow(center: Vector2, dir: Vector2, size: float) -> PackedVector2Array:
	var side := dir.orthogonal()
	return PackedVector2Array([center + dir * size * 1.2, center - dir * size * 0.8 + side * size * 0.6,
			center - dir * size * 0.35, center - dir * size * 0.8 - side * size * 0.6])


func _draw_compass(font: Font, center: Vector2) -> void:
	_view.draw_colored_polygon(_arrow(center, Vector2.UP, 12.0), Color(1, 1, 1, 0.85))
	_draw_label(_view, font, "N", center + Vector2(0, -22.0), 16)


## Centered text with a dark outline, readable over any zone color.
func _draw_label(on: CanvasItem, font: Font, text: String, center: Vector2, font_size: int) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center + Vector2(-width / 2.0, font_size * 0.35)
	on.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	on.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
