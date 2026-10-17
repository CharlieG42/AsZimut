extends Control
## Préparation d'une partie multijoueur locale : jeu, nombre de joueurs, noms, jetons.

var _content: VBoxContainer


func _ready() -> void:
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_rebuild()
	UIKit.fade_in(self)


func _rebuild() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)
	var title: Label = UIKit.label("Multijoueur local", 21, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	_content.add_child(bar)

	var intro: Label = UIKit.label(
		"Un seul appareil, hors ligne : on se passe le téléphone à chaque tour.", 13, UIKit.TEXT_SOFT
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	# Jeu
	var game_box: VBoxContainer = _section("Jeu")
	var games: Array[String] = ["Blackjack", "Poker"]
	game_box.add_child(_segment(games, LocalSession.game, _on_game))
	var desc: Label = UIKit.label(
		(
			"Chacun joue contre le croupier avec sa propre pile."
			if LocalSession.game == LocalSession.Game.BLACKJACK
			else "Texas Hold'em entre joueurs, avec pots annexes. Blinds croissantes."
		),
		12,
		UIKit.TEXT_SOFT
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_box.add_child(desc)

	# Joueurs
	var players_box: VBoxContainer = _section("Joueurs")
	players_box.add_child(_stepper())
	for i: int in LocalSession.count:
		var edit: LineEdit = LineEdit.new()
		edit.placeholder_text = "Joueur %d" % (i + 1)
		edit.text = LocalSession.names[i]
		edit.max_length = 12
		edit.custom_minimum_size = Vector2(0, 46)
		edit.add_theme_font_size_override("font_size", 17)
		edit.text_changed.connect(_on_name.bind(i))
		players_box.add_child(edit)

	# Jetons
	var chips_box: VBoxContainer = _section("Jetons de départ par joueur")
	var labels: Array[String] = []
	var selected: int = 0
	for k: int in LocalSession.CHIP_CHOICES.size():
		labels.append(str(LocalSession.CHIP_CHOICES[k]))
		if LocalSession.CHIP_CHOICES[k] == LocalSession.chips:
			selected = k
	chips_box.add_child(_segment(labels, selected, _on_chips))
	var note: Label = UIKit.label(
		"Cette partie est indépendante de votre banque et de vos statistiques.", 12, UIKit.TEXT_SOFT
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chips_box.add_child(note)

	_content.add_child(UIKit.spacer(4))
	var start: Button = UIKit.button("Lancer la partie", UIKit.GOLD, UIKit.INK, 20)
	start.pressed.connect(_start)
	_content.add_child(start)


func _section(title: String) -> VBoxContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var head: Label = UIKit.label(title.to_upper(), 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	_content.add_child(p)
	return box


func _segment(labels: Array[String], selected: int, on_select: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i: int in labels.size():
		var b: Button = (
			UIKit.button(labels[i], UIKit.GOLD, UIKit.INK, 16)
			if i == selected
			else UIKit.outline_button(labels[i], Color.WHITE, 16)
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(on_select.bind(i))
		row.add_child(b)
	return row


func _stepper() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var minus: Button = UIKit.outline_button("−", Color.WHITE, 24)
	minus.custom_minimum_size = Vector2(64, 52)
	minus.disabled = LocalSession.count <= LocalSession.min_players(LocalSession.game)
	minus.pressed.connect(_on_count.bind(-1))
	row.add_child(minus)
	var value: Label = UIKit.label("%d joueurs" % LocalSession.count, 20, Color.WHITE, true)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	var plus: Button = UIKit.outline_button("+", Color.WHITE, 24)
	plus.custom_minimum_size = Vector2(64, 52)
	plus.disabled = LocalSession.count >= LocalSession.max_players(LocalSession.game)
	plus.pressed.connect(_on_count.bind(1))
	row.add_child(plus)
	return row


func _on_game(index: int) -> void:
	LocalSession.set_game(index)
	_rebuild()


func _on_count(delta: int) -> void:
	LocalSession.set_count(LocalSession.count + delta)
	_rebuild()


func _on_chips(index: int) -> void:
	LocalSession.chips = LocalSession.CHIP_CHOICES[index]
	_rebuild()


func _on_name(text: String, index: int) -> void:
	LocalSession.names[index] = text


func _start() -> void:
	get_tree().change_scene_to_file(LocalSession.scene(LocalSession.game))


func _go_home() -> void:
	get_tree().change_scene_to_file(LocalSession.HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
