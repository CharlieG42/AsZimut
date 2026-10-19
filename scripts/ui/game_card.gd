class_name GameCard
extends PanelContainer
## Grande tuile cliquable de l'accueil (titre, sous-titre, carte-icône).

signal pressed

var _button: Button


func _init(title: String, subtitle: String, icon_cards: Array[int]) -> void:
	custom_minimum_size = Vector2(0, 88)
	var style: StyleBoxFlat = UIKit.box(Color(0.06, 0.3, 0.17, 0.85), 20, UIKit.FELT_EDGE, 2)
	add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icons: CardRow = CardRow.new(0.6, 0)
	icons.set_cards(icon_cards)
	icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icons)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var title_label: Label = UIKit.label(title, 20, UIKit.GOLD, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(title_label)

	var sub_label: Label = UIKit.label(subtitle, 12, UIKit.TEXT_SOFT)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sub_label)

	var chevron: Label = UIKit.label("›", 34, Color(0.655, 0.843, 0.722, 0.5))
	row.add_child(chevron)

	# Bouton transparent posé par-dessus pour capter les appuis.
	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.05), 20))
	_button.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.12), 20))
	_button.pressed.connect(func() -> void: pressed.emit())
	add_child(_button)


func set_enabled(enabled: bool) -> void:
	_button.disabled = not enabled
	modulate.a = 1.0 if enabled else 0.45
