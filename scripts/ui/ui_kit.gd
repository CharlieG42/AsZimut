class_name UIKit
extends RefCounted
## Palette « feutre vert / or » et fabriques de widgets partagées.

const FELT_DARK: Color = Color(0.016, 0.078, 0.047)
const FELT_GREEN: Color = Color(0.078, 0.325, 0.176)
const FELT_LIGHT: Color = Color(0.086, 0.396, 0.204)
const FELT_EDGE: Color = Color(0.024, 0.306, 0.231)
const GOLD: Color = Color(0.961, 0.773, 0.259)
const TEXT_SOFT: Color = Color(0.655, 0.843, 0.722)
const DANGER: Color = Color(0.863, 0.149, 0.149)
const GREEN_ACTION: Color = Color(0.063, 0.725, 0.506)
const INK: Color = Color(0.02, 0.18, 0.09)
const WARNING_TEXT: Color = Color(0.988, 0.647, 0.647)

static var _bold_font: FontVariation


static func bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.7
	return _bold_font


## Fond « tapis de jeu » : dégradé radial vert sombre.
static func background() -> Control:
	var holder: Control = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base: ColorRect = ColorRect.new()
	base.color = FELT_DARK
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(base)

	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([Color(0.07, 0.30, 0.18, 1.0), Color(0.016, 0.078, 0.047, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.3)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	var glow: TextureRect = TextureRect.new()
	glow.texture = tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	return holder


static func box(
	bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if border_w > 0:
		style.border_color = border
		style.set_border_width_all(border_w)
	return style


static func label(
	text: String, size: int = 16, color: Color = Color.WHITE, bold: bool = false
) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


## Bouton plein (fond `bg`, texte `fg`).
static func button(text: String, bg: Color, fg: Color = Color.WHITE, size: int = 18) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
	b.add_theme_stylebox_override("normal", box(bg, 14))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.08), 14))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.18), 14))
	b.add_theme_stylebox_override("disabled", box(Color(bg.r, bg.g, bg.b, 0.3), 14))
	return b


## Bouton contour (fond transparent, bordure `color`).
static func outline_button(text: String, color: Color = Color.WHITE, size: int = 17) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, color)
	b.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, 0.35))
	var edge: Color = Color(color.r, color.g, color.b, 0.55)
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0.15), 14, edge, 2))
	b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.06), 14, edge, 2))
	b.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.14), 14, edge, 2))
	b.add_theme_stylebox_override(
		"disabled", box(Color(0, 0, 0, 0.1), 14, Color(color.r, color.g, color.b, 0.2), 2)
	)
	return b


## Pastille de texte (PanelContainer contenant un Label, accessible via chip_label()).
static func chip(text: String, size: int = 13) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = box(Color(0, 0, 0, 0.4), 14, Color(1, 1, 1, 0.15), 1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = label(text, size, Color(0.82, 0.98, 0.9))
	panel.add_child(l)
	return panel


static func chip_label(chip_node: PanelContainer) -> Label:
	return chip_node.get_child(0) as Label


## Panneau arrondi avec marges internes.
static func panel(bg: Color, radius: int = 16, margin: int = 14, border: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = box(bg, radius, border, 1 if border.a > 0.0 else 0)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", style)
	return p


static func spacer(height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
