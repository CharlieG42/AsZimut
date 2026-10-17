class_name CoinLabel
extends HBoxContainer
## « Préfixe  (jeton)  montant » — le jeton est dessiné, sans police d'emoji.

var _prefix: Label
var _icon: Control
var _amount: Label


func _init(font_size: int = 16, color: Color = UIKit.GOLD, prefix: String = "") -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prefix = UIKit.label(prefix, font_size, color)
	_prefix.visible = prefix != ""
	add_child(_prefix)

	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(font_size, font_size)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_coin)
	add_child(_icon)

	_amount = UIKit.label("0", font_size, color)
	add_child(_amount)


func set_amount(value: int) -> void:
	_amount.text = str(value)


func _draw_coin() -> void:
	var c: Vector2 = _icon.size / 2.0
	var r: float = minf(_icon.size.x, _icon.size.y) / 2.0 - 1.0
	_icon.draw_circle(c, r, UIKit.GOLD)
	_icon.draw_arc(c, r * 0.68, 0.0, TAU, 28, Color(0.55, 0.38, 0.05, 0.85), 1.6, true)
