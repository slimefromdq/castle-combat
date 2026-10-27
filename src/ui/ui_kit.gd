class_name UiKit
## The in-match HUD look (noir black slabs, see Noir). Sizes assume the 720x1280
## design resolution.


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.default_font = HeroLettering.hud_font()
	# Panels: black slabs with a yellow edge.
	var panel := NoirBox.make(Color(Noir.INK, 0.9), 12, 14)
	panel.border_color = Noir.YELLOW
	panel.shadow = Vector2.ZERO
	panel.set_margins(12)
	t.set_stylebox("panel", "PanelContainer", panel)
	# Buttons: black slabs, white edge, yellow shadow; pressed they turn yellow.
	var normal := NoirBox.make(Color(Noir.INK, 0.92), 8, 10)
	normal.border_color = Noir.WHITE
	normal.shadow = Vector2(4, 4)
	normal.shadow_color = Noir.YELLOW
	normal.set_margins(8)
	var hover := normal.copy()
	hover.fill = Color("1f1f1f")
	var pressed := normal.copy()
	pressed.pressed = true
	pressed.fill = Noir.YELLOW
	pressed.border_color = Noir.INK
	var disabled := normal.copy()
	disabled.fill = Color(Noir.INK, 0.6)
	disabled.border_color = Color(Noir.WHITE, 0.4)
	disabled.shadow = Vector2.ZERO
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", HeroLettering.hud_bold())
	t.set_color("font_color", "Button", Noir.WHITE)
	t.set_color("font_hover_color", "Button", Noir.WHITE)
	t.set_color("font_pressed_color", "Button", Noir.INK)
	t.set_color("font_hover_pressed_color", "Button", Noir.INK)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	t.set_color("default_color", "RichTextLabel", Noir.WHITE)
	return t


## A slanted bar: a smoke track with a white edge, filled in `color`.
static func bar(color: Color, height := 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.max_value = 1.0
	b.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Noir.SMOKE
	bg.skew = Vector2(0.45, 0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.skew = Vector2(0.45, 0)
	if height >= 12.0:
		bg.border_color = Noir.WHITE
		bg.set_border_width_all(2)
		bg.expand_margin_left = 2
		bg.expand_margin_right = 2
		bg.expand_margin_top = 2
		bg.expand_margin_bottom = 2
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
