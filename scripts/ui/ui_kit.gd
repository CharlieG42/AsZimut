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
	b.button_down.connect(_tap_sound)
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
	b.button_down.connect(_tap_sound)
	return b


static func _tap_sound() -> void:
	SfxPlayer.play("tap", -3.0)


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


# --- Décor et animations --------------------------------------------------------

enum Banner { NEUTRAL, WIN, LOSE }


## Table de jeu : cadre en bois autour d'un feutre vert qui contient `content`.
static func table(content: Control, margin: int = 14) -> PanelContainer:
	var rail: PanelContainer = PanelContainer.new()
	var rail_style: StyleBoxFlat = box(Color(0.22, 0.12, 0.06), 30, Color(0.47, 0.3, 0.15), 2)
	rail_style.set_content_margin_all(7)
	rail_style.shadow_size = 12
	rail_style.shadow_color = Color(0, 0, 0, 0.5)
	rail_style.shadow_offset = Vector2(0, 5)
	rail.add_theme_stylebox_override("panel", rail_style)
	var felt: PanelContainer = panel(Color(0.067, 0.345, 0.19), 24, margin, Color(0.02, 0.2, 0.12, 1.0))
	rail.add_child(felt)
	felt.add_child(content)
	return rail


## Style d'une bannière de résultat (victoire, défaite, égalité).
static func banner_style(kind: int) -> StyleBoxFlat:
	var style: StyleBoxFlat
	match kind:
		Banner.WIN:
			style = box(Color(0.05, 0.36, 0.18, 0.96), 14, GOLD, 2)
		Banner.LOSE:
			style = box(Color(0.42, 0.07, 0.07, 0.96), 14, Color(0.9, 0.35, 0.35, 0.8), 2)
		_:
			style = box(Color(0.1, 0.16, 0.26, 0.96), 14, Color(1, 1, 1, 0.25), 2)
	style.set_content_margin_all(10)
	return style


## Fait « apparaître » un contrôle avec un petit rebond.
static func pop(node: Control) -> void:
	if not node.is_inside_tree():
		return
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.85, 0.85)
	var t: Tween = node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fondu d'entrée d'un écran.
static func fade_in(node: Control, duration: float = 0.25) -> void:
	if not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, duration)


## Texte « +120 » / « -45 » / « 0 ».
static func signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else str(value)


## Vibration courte (Android), si activée dans les réglages.
static func haptic(enabled: bool, duration_ms: int) -> void:
	if enabled:
		Input.vibrate_handheld(duration_ms)


# --- Aide et conseils -----------------------------------------------------------


## Petit bouton rond « ? » pour ouvrir l'aide.
static func help_button() -> Button:
	var b: Button = outline_button("?", GOLD, 20)
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Bandeau de conseil du mode débutant.
static func advice_panel(text: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = box(Color(0.1, 0.16, 0.26, 0.96), 14, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 1)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	p.add_child(col)
	var head: Label = label("CONSEIL", 11, GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	var body: Label = label(text, 14, Color(0.9, 0.97, 0.93))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	return p


static var _check_off: ImageTexture
static var _check_on: ImageTexture


## Distance signée à un carré arrondi centré (négatif à l'intérieur).
static func _round_box_distance(px: float, py: float, half: float, radius: float, center: float) -> float:
	var qx: float = absf(px - center) - (half - radius)
	var qy: float = absf(py - center) - (half - radius)
	return Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - radius


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _check_texture(checked: bool) -> ImageTexture:
	var size: int = 28
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = size / 2.0 - 0.5
	for y: int in size:
		for x: int in size:
			var d: float = _round_box_distance(x, y, size / 2.0 - 2.0, 7.0, center)
			var color: Color = Color(0, 0, 0, 0)
			if d <= 0.0:
				if checked:
					color = GOLD
				elif d > -2.2:
					color = Color(0.82, 0.93, 0.87, 0.9)
				else:
					color = Color(0, 0, 0, 0.3)
				if checked:
					var p: Vector2 = Vector2(x, y)
					var line: float = minf(
						_segment_distance(p, Vector2(7, 14.5), Vector2(12, 19.5)),
						_segment_distance(p, Vector2(12, 19.5), Vector2(21, 8.5))
					)
					if line < 1.9:
						color = INK
			elif d < 1.0:
				color = Color(color.r, color.g, color.b, 0.0)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


## Case à cocher au style de l'application (visible sur fond sombre).
static func check(text: String, pressed: bool) -> CheckBox:
	if _check_off == null:
		_check_off = _check_texture(false)
		_check_on = _check_texture(true)
	var c: CheckBox = CheckBox.new()
	c.text = text
	c.button_pressed = pressed
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_constant_override("h_separation", 10)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		c.add_theme_color_override(key, Color.WHITE)
	c.add_theme_icon_override("unchecked", _check_off)
	c.add_theme_icon_override("checked", _check_on)
	c.add_theme_icon_override("unchecked_disabled", _check_off)
	c.add_theme_icon_override("checked_disabled", _check_on)
	return c
