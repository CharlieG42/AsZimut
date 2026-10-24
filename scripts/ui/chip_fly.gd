class_name ChipFly
extends RefCounted
## Petits jetons qui volent d'un point de l'écran à un autre (mise vers la pile, pot vers le gagnant…).
## Purement visuel : rien ne dépend de l'animation, et elle se désactive (tests, réglage).

## Durée du vol d'un jeton (s) et décalage entre deux jetons.
const FLIGHT: float = 0.45
const STAGGER: float = 0.07
const SIZE: float = 28.0

static var enabled: bool = true


## Fait voler `count` jetons (couleur selon `value`) du centre de `from` au centre de `to`.
static func fly(from: Control, to: Control, value: int, count: int = 3) -> void:
	if not _ok(from) or not _ok(to):
		return
	_launch(from, _center(from), _center(to), value, count)


## Les jetons quittent l'écran par le haut (mise perdue, ramassée par la banque).
static func fly_away(from: Control, value: int, count: int = 3) -> void:
	if not _ok(from):
		return
	var start: Vector2 = _center(from)
	_launch(from, start, Vector2(start.x, -SIZE * 2.0), value, count)


static func _ok(node: Control) -> bool:
	return enabled and node != null and is_instance_valid(node) and node.is_inside_tree()


static func _center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()


static func _launch(owner_node: Control, start: Vector2, end: Vector2, value: int, count: int) -> void:
	var root: Node = owner_node.get_tree().root
	for i: int in clampi(count, 1, 6):
		var sprite: Sprite = Sprite.new()
		sprite.color = ChipPile.chip_color(_denom(value))
		sprite.position = start - Vector2(SIZE, SIZE) / 2.0
		sprite.modulate.a = 0.0
		root.add_child(sprite)
		var target: Vector2 = end - Vector2(SIZE, SIZE) / 2.0 + Vector2((i - count / 2.0) * 3.0, -i * 2.0)
		var tw: Tween = sprite.create_tween()
		tw.tween_interval(i * STAGGER)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.05)
		tw.tween_property(sprite, "position", target, FLIGHT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(sprite, "scale", Vector2(0.75, 0.75), FLIGHT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.08)
		tw.tween_callback(sprite.queue_free)


## Plus grosse valeur de jeton qui entre dans le montant (pour choisir la couleur).
static func _denom(value: int) -> int:
	for d: int in ChipPile.DENOMS:
		if value >= d:
			return d
	return 5


class Sprite:
	extends Control
	var color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(ChipFly.SIZE, ChipFly.SIZE)
		size = Vector2(ChipFly.SIZE, ChipFly.SIZE)
		pivot_offset = size / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 100

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		draw_circle(c + Vector2(0, 2), size.x / 2.0, Color(0, 0, 0, 0.35))
		draw_circle(c, size.x / 2.0, color)
		draw_arc(c, size.x / 2.0 - 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 2.0)
