class_name CoinLabel
extends HBoxContainer
## « Préfixe  (jeton)  montant » — le jeton est dessiné, sans police d'emoji.

var _prefix: Label
var _icon: Control
var _amount: Label
var _shown: int = 0
var _tween: Tween


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


## Affiche `value` ; avec `animate`, le compteur défile jusqu'à la nouvelle valeur.
func set_amount(value: int, animate: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree() or value == _shown:
		_show_value(value)
		return
	_tween = create_tween()
	_tween.tween_method(_show_tween, float(_shown), float(value), 0.45).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_show_value.bind(value))


func _show_tween(v: float) -> void:
	_show_value(roundi(v))


func _show_value(v: int) -> void:
	_shown = v
	_amount.text = str(v)


func _draw_coin() -> void:
	var c: Vector2 = _icon.size / 2.0
	var r: float = minf(_icon.size.x, _icon.size.y) / 2.0 - 1.0
	_icon.draw_circle(c, r, UIKit.GOLD)
	_icon.draw_arc(c, r * 0.68, 0.0, TAU, 28, Color(0.55, 0.38, 0.05, 0.85), 1.6, true)
