extends VBoxContainer
## The Controls page (pause menu and main menu): every action with its keyboard /
## mouse key and its controller button, from Controls.TABLE. Emits `back` when
## you press Back.

signal back

const Controls := preload("res://core/controls.gd")
const MenuStyle := preload("res://ui/menu_style.gd")

var _back_button: Button


func _init() -> void:
	add_theme_constant_override("separation", 10)
	MenuStyle.add_title(self, "CONTROLS")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for heading in ["", "Keyboard / mouse", "Controller"]:
		MenuStyle.add_heading(grid, heading)
	for row: Array in Controls.TABLE:
		for cell: String in row:
			var label := Label.new()
			label.text = cell
			label.add_theme_font_size_override("font_size", 17)
			grid.add_child(label)
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(back_row)
	_back_button = MenuStyle.add_button(back_row, "Back", leave)


func focus_first() -> void:
	_back_button.grab_focus()


func leave() -> void:
	back.emit()
