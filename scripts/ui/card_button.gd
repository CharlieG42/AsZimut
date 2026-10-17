class_name CardButton
extends Button
## Carte tapable (Dutch) : face cachée, visible, ou emplacement mis en évidence.

var view: CardView
var _dot: Panel


func _init(scale_factor: float, card: int, face_down: bool, highlight: bool, remembered: bool) -> void:
	custom_minimum_size = CardView.BASE_SIZE * scale_factor + Vector2(6, 6)
	focus_mode = Control.FOCUS_NONE
	flat = false
	var border: Color = UIKit.GOLD if highlight else Color(0, 0, 0, 0)
	var width: int = 3 if highlight else 0
	var normal: StyleBoxFlat = UIKit.box(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.16 if highlight else 0.0), 10, border, width)
	var pressed_style: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.18), 10, border, width)
	for state: String in ["normal", "hover", "disabled", "focus"]:
		add_theme_stylebox_override(state, normal)
	add_theme_stylebox_override("pressed", pressed_style)

	view = CardView.new(scale_factor)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	if card >= 0:
		view.show_card(card, face_down)
	else:
		view.show_empty()
	add_child(view)

	if remembered:
		_dot = Panel.new()
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot.custom_minimum_size = Vector2(9, 9)
		_dot.size = Vector2(9, 9)
		_dot.add_theme_stylebox_override("panel", UIKit.box(UIKit.GOLD, 5, Color(0.1, 0.1, 0.1, 0.8), 1))
		_dot.position = Vector2(custom_minimum_size.x - 12, 3)
		add_child(_dot)
