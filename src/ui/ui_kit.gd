class_name UiKit
## Shared look for HUD and menus. Sizes assume the 720x1280 design resolution.


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.default_font = HeroLettering.hud_font()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.1, 0.72)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.23, 0.28, 0.92)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.27, 0.31, 0.37, 0.95)
	var pressed := normal.duplicate()
	pressed.bg_color = Palette.ALLY.darkened(0.2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.17, 0.2, 0.75)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))
	return t


static func bar(color: Color, height := 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.max_value = 1.0
	b.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func label(text: String, font_size := 24, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_size := Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## F11 or the HUD menu. On the web this must run from a key press or click, which it does.
static func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
