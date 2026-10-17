class_name ChipPile
extends Control
## Piles de jetons de casino représentant un montant, avec le montant dessous.

const DENOMS: Array[int] = [100, 50, 25, 10, 5]
const MAX_STACKS: int = 5
const MAX_PER_STACK: int = 6

var amount: int = 0


func _init(min_width: float = 120.0) -> void:
	custom_minimum_size = Vector2(min_width, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_amount(value: int) -> void:
	if value == amount:
		return
	amount = value
	queue_redraw()


static func chip_color(value: int) -> Color:
	match value:
		100:
			return Color(0.13, 0.13, 0.18)
		50:
			return Color(0.78, 0.16, 0.16)
		25:
			return Color(0.1, 0.55, 0.28)
		10:
			return Color(0.2, 0.4, 0.85)
		_:
			return Color(0.82, 0.82, 0.86)


## Décompose un montant en piles [valeur, nombre], des plus grosses aux plus petites.
static func split(total: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rest: int = total
	for d: int in DENOMS:
		@warning_ignore("integer_division")
		var n: int = rest / d
		rest -= n * d
		if n > 0:
			out.append(Vector2i(d, n))
	return out


static func ellipse(center: Vector2, rx: float, ry: float, points: int = 22) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in points:
		var a: float = TAU * i / points
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	if amount <= 0:
		return
	var stacks: Array[Vector2i] = split(amount)
	if stacks.size() > MAX_STACKS:
		stacks.resize(MAX_STACKS)
	var spacing: float = 38.0
	var total_w: float = stacks.size() * spacing
	var x0: float = (size.x - total_w) / 2.0 + spacing / 2.0
	var base_y: float = size.y - 26.0

	for i: int in stacks.size():
		var denom: int = stacks[i].x
		var count: int = mini(stacks[i].y, MAX_PER_STACK)
		var col: Color = chip_color(denom)
		var cx: float = x0 + i * spacing
		for j: int in count:
			var y: float = base_y - j * 4.5
			# tranche (épaisseur) puis face supérieure
			draw_colored_polygon(ellipse(Vector2(cx, y + 3.5), 16.0, 7.0), col.darkened(0.45))
			draw_colored_polygon(ellipse(Vector2(cx, y), 16.0, 7.0), col)
			var rim: PackedVector2Array = ellipse(Vector2(cx, y), 12.5, 5.2)
			rim.append(rim[0])
			draw_polyline(rim, Color(1, 1, 1, 0.55), 1.2, true)

	var font: Font = get_theme_default_font()
	draw_string(
		font, Vector2(0, size.y - 3.0), str(amount), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UIKit.GOLD
	)
