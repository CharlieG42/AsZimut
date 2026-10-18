class_name BankChart
extends Control
## Courbe de l'évolution de la banque (dernières manches), dessinée en code.

var values: Array[int] = []
## Valeur repérée par un pointillé (la banque de départ, ou 0 pour des gains cumulés).
var baseline: int = BankrollState.START_VALUE
var empty_text: String = "Jouez quelques manches pour voir la courbe."


func _init(data: Array[int]) -> void:
	values = data.duplicate()
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.25), 10), rect)
	var font: Font = UIKit.bold_font()
	if values.size() < 2:
		draw_string(
			font, Vector2(0, size.y * 0.5 + 5), empty_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UIKit.TEXT_SOFT
		)
		return
	var lo: int = values[0]
	var hi: int = values[0]
	for v: int in values:
		lo = mini(lo, v)
		hi = maxi(hi, v)
	if hi == lo:
		hi = lo + 1
	var left: float = 46.0
	var right: float = size.x - 10.0
	var top: float = 12.0
	var bottom: float = size.y - 14.0
	# Repères : maximum, minimum, et la banque de départ si elle est dans l'intervalle.
	var grid: Color = Color(1, 1, 1, 0.08)
	for v: int in [hi, lo]:
		var y: float = _y(v, lo, hi, top, bottom)
		draw_line(Vector2(left, y), Vector2(right, y), grid, 1.0)
		draw_string(font, Vector2(4, y + 4), _short(v), HORIZONTAL_ALIGNMENT_LEFT, left - 8, 11, UIKit.TEXT_SOFT)
	if baseline > lo and baseline < hi:
		var ys: float = _y(baseline, lo, hi, top, bottom)
		draw_dashed_line(Vector2(left, ys), Vector2(right, ys), Color(1, 1, 1, 0.18), 1.0, 4.0)

	var pts: PackedVector2Array = PackedVector2Array()
	var step: float = (right - left) / float(values.size() - 1)
	for i: int in values.size():
		pts.append(Vector2(left + step * i, _y(values[i], lo, hi, top, bottom)))
	# Aire sous la courbe puis la courbe.
	var area: PackedVector2Array = pts.duplicate()
	area.append(Vector2(right, bottom))
	area.append(Vector2(left, bottom))
	draw_colored_polygon(area, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.12))
	draw_polyline(pts, UIKit.GOLD, 2.0, true)
	draw_circle(pts[pts.size() - 1], 4.0, UIKit.GOLD)


func _y(v: int, lo: int, hi: int, top: float, bottom: float) -> float:
	return bottom - (bottom - top) * float(v - lo) / float(hi - lo)


func _short(v: int) -> String:
	if absi(v) >= 10000:
		return "%dk" % (v / 1000)
	return str(v)
