class_name HelpView
extends RefCounted
## Construit les blocs d'aide (sections de texte, classement des mains).


static func section(title: String, text: String) -> PanelContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 14, 12, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	var head: Label = UIKit.label(title.to_upper(), 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	var body: Label = UIKit.label(text, 15, Color(0.9, 0.97, 0.93))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	return p


## Les 10 mains, de la plus forte à la plus faible, avec un exemple de cartes.
static func hands_panel() -> PanelContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 14, 12, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	var head: Label = UIKit.label("DU PLUS FORT AU PLUS FAIBLE", 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	for i: int in HelpContent.HANDS.size():
		var data: Array = HelpContent.HANDS[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var rank: Label = UIKit.label(str(i + 1), 14, UIKit.GOLD, true)
		rank.custom_minimum_size = Vector2(22, 0)
		row.add_child(rank)
		var names: VBoxContainer = VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		var name_label: Label = UIKit.label(str(data[0]), 15, Color.WHITE, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		names.add_child(name_label)
		var desc: Label = UIKit.label(str(data[1]), 11, UIKit.TEXT_SOFT)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(desc)
		row.add_child(names)
		var cards: CardRow = CardRow.new(0.46, 0)
		var values: Array[int] = []
		for spec: Array in (data[2] as Array):
			values.append(Cards.make(int(spec[0]), int(spec[1])))
		cards.set_cards(values)
		cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cards)
		col.add_child(row)
	return p


static func build(parent: VBoxContainer, sections: Array[Dictionary], with_hands: bool = false) -> void:
	for s: Dictionary in sections:
		parent.add_child(section(str(s["title"]), str(s["text"])))
	if with_hands:
		parent.add_child(hands_panel())
