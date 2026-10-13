extends RefCounted
## The look shared by the pause menu, the main menu and their pages: big titles,
## gold headings, and wide buttons. Never instanced.

const HEADING_COLOR := Color(0.95, 0.82, 0.45) # matches the objective text


static func add_title(parent: Control, text: String, font_size := 40) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	parent.add_child(title)
	return title


static func add_heading(parent: Control, text: String) -> Label:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", HEADING_COLOR)
	parent.add_child(heading)
	return heading


static func add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
