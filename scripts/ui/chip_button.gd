class_name ChipButton
extends Button
## Jeton de casino cliquable (valeur de mise), dessiné en code.

var value: int = 10

var _disc: Control


func _init(chip_value: int = 10) -> void:
	value = chip_value
	text = str(chip_value)
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(78, 78)
	add_theme_font_size_override("font_size", 21)
	add_theme_font_override("font", UIKit.bold_font())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(key, Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	add_theme_constant_override("outline_size", 4)
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())

	# Le disque est dessiné derrière le texte du bouton.
	_disc = Control.new()
	_disc.show_behind_parent = true
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_disc.draw.connect(_draw_disc)
	add_child(_disc)

	resized.connect(func() -> void: pivot_offset = size / 2.0)
	button_down.connect(_press_feedback.bind(0.9))
	button_up.connect(_press_feedback.bind(1.0))
	pressed.connect(func() -> void: SfxPlayer.play("chip"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and _disc != null:
		_disc.queue_redraw()


func _press_feedback(target: float) -> void:
	if not is_inside_tree():
		return
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2(target, target), 0.08)


func _draw_disc() -> void:
	var c: Vector2 = _disc.size / 2.0
	var r: float = minf(_disc.size.x, _disc.size.y) / 2.0 - 3.0
	var alpha: float = 0.35 if disabled else 1.0
	var col: Color = ChipPile.chip_color(value)
	col.a = alpha
	_disc.draw_circle(c + Vector2(0, 2.5), r, Color(0, 0, 0, 0.35 * alpha))
	_disc.draw_circle(c, r, col)
	# Encoches blanches sur le pourtour.
	for i: int in 8:
		var a: float = TAU * i / 8.0
		_disc.draw_arc(c, r - 4.0, a - 0.17, a + 0.17, 6, Color(1, 1, 1, 0.9 * alpha), 6.0, true)
	_disc.draw_arc(c, r * 0.68, 0.0, TAU, 32, Color(1, 1, 1, 0.55 * alpha), 2.0, true)
	_disc.draw_circle(c, r * 0.6, Color(0, 0, 0, 0.22 * alpha))
