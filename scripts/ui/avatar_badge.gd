class_name AvatarBadge
extends Control
## Petit visage de robot pour ZIA.


func _init(diameter: float = 48.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 1.5
	draw_circle(c, r, Color(0.04, 0.1, 0.16))
	draw_arc(c, r - 1.0, 0.0, TAU, 40, UIKit.GOLD, 2.5, true)
	# antenne
	draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, -r * 0.95), UIKit.GOLD, 2.0, true)
	draw_circle(c + Vector2(0, -r * 0.95), 2.6, UIKit.GOLD)
	# yeux et bouche
	draw_circle(c + Vector2(-r * 0.3, -r * 0.1), r * 0.14, UIKit.GOLD)
	draw_circle(c + Vector2(r * 0.3, -r * 0.1), r * 0.14, UIKit.GOLD)
	draw_line(c + Vector2(-r * 0.32, r * 0.34), c + Vector2(r * 0.32, r * 0.34), UIKit.GOLD, 3.0, true)
