class_name UITheme
extends Node

static func build(font_path: String = "res://ui/fonts/Inter.ttf") -> Theme:
	var theme := Theme.new()

	# ----- Font (optional)
	if ResourceLoader.exists(font_path):
		var font: Font = load(font_path)
		theme.default_font = font
		theme.default_font_size = 20
	else:
		theme.default_font_size = 20

	# ===== Panel (menu card) =====
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.10, 0.12, 0.16, 0.92) # dark translucent
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_left = 16
	panel.corner_radius_bottom_right = 16
	panel.shadow_size = 12
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_width_left = 1
	panel.border_color = Color(1,1,1,0.06)
	panel.set_content_margin_all(24)
	theme.set_stylebox("panel", "Panel", panel)


	var c_norm = Color8(44,130,201) 
	var c_hover = c_norm.lerp(Color.WHITE, 0.12)
	var c_press = c_norm.lerp(Color.BLACK, 0.20)
	var c_border = Color(1,1,1,0.08)

	theme.set_stylebox("normal", "Button", make_btn(c_norm, c_border, Color.WHITE))
	theme.set_stylebox("hover",  "Button", make_btn(c_hover, c_border, Color.WHITE))
	theme.set_stylebox("pressed","Button", make_btn(c_press, c_border, Color.WHITE))
	theme.set_stylebox("disabled","Button", make_btn(Color(0.25,0.25,0.28), c_border, Color(1,1,1,0.5)))

	theme.set_color("font_color", "Button", Color(1,1,1))
	theme.set_color("font_hover_color", "Button", Color(1,1,1))
	theme.set_color("font_pressed_color", "Button", Color(1,1,1))
	theme.set_color("font_disabled_color", "Button", Color(1,1,1,0.55))

	theme.set_constant("h_separation", "VBoxContainer", 12)
	theme.set_constant("v_separation", "VBoxContainer", 12)

	return theme

static func make_btn(bg: Color, border: Color, text: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.shadow_size = 6
		sb.shadow_color = Color(0,0,0,0.25)
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_width_left = 1
		sb.border_color = border
		sb.set_content_margin_all(12)
		return sb
