class_name CardView
extends Control
## Rendu d'une carte (face, dos bleu « Z » ou emplacement vide), dessiné en code :
## aucune police d'emoji ni image n'est nécessaire.

const BASE_SIZE: Vector2 = Vector2(60, 86)
const RED: Color = Color(0.863, 0.149, 0.149)
const BLACK: Color = Color(0.059, 0.09, 0.165)

var card: int = -1
var face_down: bool = false
var empty: bool = true

var _face_style: StyleBoxFlat
var _back_style: StyleBoxFlat
var _back_inner: StyleBoxFlat
var _empty_style: StyleBoxFlat
var _tween: Tween


func _init(scale_factor: float = 1.0) -> void:
	custom_minimum_size = BASE_SIZE * scale_factor
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radius: int = roundi(8.0 * scale_factor)

	_face_style = UIKit.box(Color.WHITE, radius, Color(0.8, 0.84, 0.88), 1)
	_face_style.shadow_size = 5
	_face_style.shadow_color = Color(0, 0, 0, 0.4)
	_face_style.shadow_offset = Vector2(0, 2)

	_back_style = UIKit.box(Color(0.118, 0.227, 0.541), radius, Color(0.961, 0.773, 0.259, 0.35), 1)
	_back_style.shadow_size = 5
	_back_style.shadow_color = Color(0, 0, 0, 0.4)
	_back_style.shadow_offset = Vector2(0, 2)
	_back_inner = UIKit.box(Color(0, 0, 0, 0), maxi(radius - 3, 2), Color(0.961, 0.773, 0.259, 0.22), 1)

	_empty_style = UIKit.box(Color(1, 1, 1, 0.03), radius, Color(1, 1, 1, 0.15), 1)
	resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = size / 2.0


func show_card(value: int, is_hidden: bool) -> void:
	var was_hidden: bool = face_down and not empty
	var is_new: bool = empty or value != card
	empty = false
	card = value
	if was_hidden and not is_hidden and not is_new and is_inside_tree():
		_flip()
		return
	face_down = is_hidden
	queue_redraw()
	if is_new and is_inside_tree():
		_pop_in()


func show_empty() -> void:
	if empty:
		return
	empty = true
	card = -1
	face_down = false
	scale = Vector2.ONE
	modulate.a = 1.0
	queue_redraw()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _pop_in() -> void:
	_kill_tween()
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _flip() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "scale:x", 0.0, 0.12)
	_tween.tween_callback(_reveal)
	_tween.tween_property(self, "scale:x", 1.0, 0.12)


func _reveal() -> void:
	face_down = false
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if empty:
		draw_style_box(_empty_style, rect)
	elif face_down:
		_draw_back(rect)
	else:
		_draw_face(rect)


func _draw_back(rect: Rect2) -> void:
	draw_style_box(_back_style, rect)
	draw_style_box(_back_inner, rect.grow(-5.0))
	var fs: int = roundi(size.y * 0.34)
	var color: Color = Color(0.961, 0.773, 0.259, 0.75)
	var base_y: float = size.y * 0.5 + fs * 0.35
	draw_string(UIKit.bold_font(), Vector2(0, base_y), "Z", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color)


func _draw_face(rect: Rect2) -> void:
	draw_style_box(_face_style, rect)
	var suit: int = Cards.suit_of(card)
	var color: Color = RED if Cards.is_red(card) else BLACK
	var label: String = Cards.rank_label(card)
	var fs: int = roundi(size.y * 0.24)
	var font: Font = UIKit.bold_font()
	var pad: float = size.x * 0.1

	_draw_corner(font, label, fs, pad, suit, color)
	# Coin opposé : même index retourné de 180°.
	draw_set_transform(size, PI, Vector2.ONE)
	_draw_corner(font, label, fs, pad, suit, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_suit(self, Vector2(size.x * 0.5, size.y * 0.54), size.x * 0.27, suit, color)


func _draw_corner(font: Font, label: String, fs: int, pad: float, suit: int, color: Color) -> void:
	draw_string(font, Vector2(pad, pad + fs * 0.85), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	var small: float = size.x * 0.09
	var label_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_suit(self, Vector2(pad + label_w * 0.5, pad + fs + small * 1.25), small, suit, color)


## Dessine une couleur (pique, cœur, carreau, trèfle) centrée en `c`, de demi-taille `s`.
static func draw_suit(ci: CanvasItem, c: Vector2, s: float, suit: int, color: Color) -> void:
	match suit:
		Cards.Suit.HEARTS:
			ci.draw_circle(c + Vector2(-0.26, -0.18) * s, 0.31 * s, color)
			ci.draw_circle(c + Vector2(0.26, -0.18) * s, 0.31 * s, color)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[c + Vector2(-0.55, -0.06) * s, c + Vector2(0.55, -0.06) * s, c + Vector2(0, 0.66) * s]
				),
				color
			)
		Cards.Suit.DIAMONDS:
			ci.draw_colored_polygon(
				PackedVector2Array(
					[
						c + Vector2(0, -0.68) * s,
						c + Vector2(0.48, 0) * s,
						c + Vector2(0, 0.68) * s,
						c + Vector2(-0.48, 0) * s
					]
				),
				color
			)
		Cards.Suit.SPADES:
			ci.draw_circle(c + Vector2(-0.26, 0.1) * s, 0.31 * s, color)
			ci.draw_circle(c + Vector2(0.26, 0.1) * s, 0.31 * s, color)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[c + Vector2(-0.55, 0.0) * s, c + Vector2(0.55, 0.0) * s, c + Vector2(0, -0.68) * s]
				),
				color
			)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[c + Vector2(0, 0.15) * s, c + Vector2(-0.24, 0.66) * s, c + Vector2(0.24, 0.66) * s]
				),
				color
			)
		_:
			ci.draw_circle(c + Vector2(0, -0.3) * s, 0.28 * s, color)
			ci.draw_circle(c + Vector2(-0.32, 0.08) * s, 0.28 * s, color)
			ci.draw_circle(c + Vector2(0.32, 0.08) * s, 0.28 * s, color)
			ci.draw_circle(c + Vector2(0, -0.04) * s, 0.2 * s, color)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[c + Vector2(0, 0.0) * s, c + Vector2(-0.22, 0.68) * s, c + Vector2(0.22, 0.68) * s]
				),
				color
			)
