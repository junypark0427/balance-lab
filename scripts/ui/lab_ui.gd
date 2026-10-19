extends RefCounted
## Native controls and a shared visual language. No raster UI assets.

const INK := Color("071321")
const CYAN := Color("61dfff")
const MUTED := Color("8ba9bf")
const WHITE := Color("eaf7ff")
const ORANGE := Color("ffa45b")

static func font(bold: bool = false) -> SystemFont:
	var result := SystemFont.new()
	result.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "DejaVu Sans", "Arial"])
	result.font_weight = 700 if bold else 400
	return result

static func label(text: String, size: int = 20, color: Color = WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func panel(fill: Color = Color("0b1e30e8"), border: Color = Color("34546a"), radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 76)
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("50687a"))
	var normal := panel(Color("10344de8") if primary else Color("0b1c2cde"), CYAN if primary else Color("496b83"))
	normal.shadow_color = Color(0.12, 0.65, 1, 0.24 if primary else 0.07)
	normal.shadow_size = 16 if primary else 8
	b.add_theme_stylebox_override("normal", normal)
	var hover := panel(Color("164c6a"), Color("a6efff"))
	hover.shadow_color = Color(0.2, 0.75, 1, 0.35)
	hover.shadow_size = 22
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", panel(Color(0, 0, 0, 0), ORANGE))
	b.add_theme_stylebox_override("pressed", panel(Color("216080"), Color.WHITE))
	b.add_theme_stylebox_override("disabled", panel(Color("0a1622e0"), Color("203647")))
	b.set_script(load("res://scripts/ui/menu_button.gd"))
	return b

static func full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func margin(parent: Node, amount: int = 48) -> MarginContainer:
	var m := MarginContainer.new()
	parent.add_child(m)
	full_rect(m)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, amount)
	return m

static func line(parent: Node, color: Color = Color("315369")) -> void:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)

static func veil(parent: Node, opacity: float = 0.4) -> ColorRect:
	var rect := ColorRect.new()
	parent.add_child(rect)
	full_rect(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float strength = 0.4; void fragment(){float edge=smoothstep(0.15,0.8,length(UV-vec2(0.5,0.4))); float top=1.0-smoothstep(0.0,0.8,UV.y); COLOR=vec4(0.005,0.02,0.045,clamp(strength*(1.0-smoothstep(0.45,0.95,UV.y))+edge*0.2+top*0.08,0.0,0.85));}"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", opacity)
	rect.material = material
	return rect
