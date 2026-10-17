class_name CardRow
extends HBoxContainer
## Rangée de cartes qui réutilise ses CardView : seules les nouvelles cartes
## s'animent (apparition), et un dos qui se découvre se retourne.

var _slots: int = 2
var _card_scale: float = 1.0


func _init(scale_factor: float = 1.0, min_slots: int = 2) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", roundi(6.0 * scale_factor))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_scale = scale_factor
	_slots = min_slots
	custom_minimum_size = Vector2(0, CardView.BASE_SIZE.y * scale_factor)
	for _i: int in _slots:
		add_child(CardView.new(_card_scale))


## `hide_flags[i]` = true → la carte i est affichée face cachée.
func set_cards(cards: Array[int], hide_flags: Array[bool] = []) -> void:
	var needed: int = maxi(_slots, cards.size())
	while get_child_count() < needed:
		add_child(CardView.new(_card_scale))
	while get_child_count() > needed:
		var extra: Node = get_child(get_child_count() - 1)
		remove_child(extra)
		extra.queue_free()
	for i: int in needed:
		var view: CardView = get_child(i) as CardView
		if i < cards.size():
			var is_hidden: bool = i < hide_flags.size() and hide_flags[i]
			view.show_card(cards[i], is_hidden)
		else:
			view.show_empty()
