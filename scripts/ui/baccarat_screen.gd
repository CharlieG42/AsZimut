extends Control
## Écran Baccarat (punto banco).

const HOME_SCENE: String = "res://scenes/home.tscn"
const CHIP_VALUES: Array[int] = [10, 25, 50, 100]

var engine: BaccaratEngine

var _bank: CoinLabel
var _player_row: CardRow
var _banker_row: CardRow
var _player_chip: PanelContainer
var _banker_chip: PanelContainer
var _felt_node: Control
var _piles: Dictionary = {}
var _history_row: HBoxContainer
var _message_panel: PanelContainer
var _message_label: Label
var _controls: VBoxContainer
var _last_message: String = ""
## Zone de mise ciblée par les jetons (Spot).
var target: int = BaccaratEngine.Spot.PLAYER


func _ready() -> void:
	engine = BaccaratEngine.new(Bankroll)
	engine.changed.connect(_refresh)
	engine.round_finished.connect(_on_round_finished)

	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top"]:
		margin.add_theme_constant_override(side, 16)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var scroll: TouchScroll = TouchScroll.new()
	margin.add_child(scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_felt())

	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	col.add_child(_controls)
	col.add_child(UIKit.spacer(16))

	_refresh()
	UIKit.fade_in(self)


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)

	var title: Label = UIKit.label("Baccarat", 20, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	var help: Button = UIKit.help_button()
	help.pressed.connect(_open_help)
	bar.add_child(help)

	_bank = CoinLabel.new(17, UIKit.GOLD)
	_bank.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_bank)
	return bar


func _build_felt() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var felt: PanelContainer = UIKit.table(col, 16)
	_felt_node = felt

	col.add_child(UIKit.label("BANQUIER", 12, UIKit.TEXT_SOFT, true))
	_banker_row = CardRow.new(0.9, 3)
	col.add_child(_banker_row)
	_banker_chip = UIKit.chip("")
	col.add_child(_centered(_banker_chip))

	col.add_child(HSeparator.new())

	_player_row = CardRow.new(0.9, 3)
	col.add_child(_player_row)
	col.add_child(UIKit.label("JOUEUR", 12, UIKit.TEXT_SOFT, true))
	_player_chip = UIKit.chip("")
	col.add_child(_centered(_player_chip))

	_history_row = HBoxContainer.new()
	_history_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_history_row.add_theme_constant_override("separation", 4)
	col.add_child(_history_row)

	_message_panel = PanelContainer.new()
	_message_label = UIKit.label("", 15, Color.WHITE, true)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_panel.add_child(_message_label)
	col.add_child(_message_panel)
	return felt


func _centered(node: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(node)
	return row


func _side_color(side: int) -> Color:
	match side:
		BaccaratEngine.Spot.PLAYER:
			return Color(0.15, 0.35, 0.75)
		BaccaratEngine.Spot.BANKER:
			return Color(0.72, 0.1, 0.12)
	return Color(0.05, 0.45, 0.22)


func _refresh() -> void:
	_bank.set_amount(Bankroll.value, true)
	_player_row.set_cards(engine.player)
	_banker_row.set_cards(engine.banker)
	_banker_chip.get_parent().visible = not engine.banker.is_empty()
	_player_chip.get_parent().visible = not engine.player.is_empty()
	if not engine.player.is_empty():
		UIKit.chip_label(_player_chip).text = str(BaccaratEngine.total(engine.player))
		UIKit.chip_label(_banker_chip).text = str(BaccaratEngine.total(engine.banker))

	for child: Node in _history_row.get_children():
		_history_row.remove_child(child)
		child.queue_free()
	for side: int in engine.history:
		var dot: PanelContainer = PanelContainer.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.add_theme_stylebox_override("panel", UIKit.box(_side_color(side), 13))
		dot.add_child(UIKit.label(["J", "B", "É"][side], 12, Color.WHITE, true))
		_history_row.add_child(dot)

	_message_panel.visible = engine.message != ""
	_message_label.text = engine.message
	var kind: int = UIKit.Banner.NEUTRAL
	if engine.phase == BaccaratEngine.Phase.DONE:
		kind = UIKit.Banner.WIN if engine.net > 0 else (UIKit.Banner.LOSE if engine.net < 0 else UIKit.Banner.NEUTRAL)
	_message_panel.add_theme_stylebox_override("panel", UIKit.banner_style(kind))
	if engine.message != _last_message:
		_last_message = engine.message
		if engine.message != "":
			UIKit.pop(_message_panel)

	_rebuild_controls()


func _on_round_finished(net: int) -> void:
	if net > 0:
		ChipFly.fly(_felt_node, _bank, net)
	elif net < 0:
		ChipFly.fly_away(_felt_node, -net)
	Stats.record_baccarat(net, engine.winner == BaccaratEngine.Spot.TIE)
	ProfileStore.record_active("ba", net > 0, net)
	Stats.note_bank(Bankroll.value)
	if net > 0:
		UIKit.haptic(Stats.haptics, 60)
		SfxPlayer.play("win")
	elif net < 0:
		UIKit.haptic(Stats.haptics, 140)
		SfxPlayer.play("lose")


func _rebuild_controls() -> void:
	for node: Node in _controls.get_children():
		_controls.remove_child(node)
		node.queue_free()
	if engine.phase == BaccaratEngine.Phase.BET:
		_controls.add_child(_build_bet_panel())
	else:
		var again: Button = UIKit.button("Rejouer", UIKit.GOLD, UIKit.INK, 20)
		again.pressed.connect(engine.replay)
		_controls.add_child(again)


func _build_bet_panel() -> Control:
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var boxes: HBoxContainer = HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 8)
	boxes.add_child(_bet_box("Joueur (1:1)", BaccaratEngine.Spot.PLAYER))
	boxes.add_child(_bet_box("Banquier (0,95:1)", BaccaratEngine.Spot.BANKER))
	boxes.add_child(_bet_box("Égalité (8:1)", BaccaratEngine.Spot.TIE))
	col.add_child(boxes)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	for v: int in CHIP_VALUES:
		var chip_btn: ChipButton = ChipButton.new(v)
		chip_btn.disabled = not engine.can_add(v)
		chip_btn.pressed.connect(_add_chip.bind(v, chip_btn))
		chips.add_child(chip_btn)
	col.add_child(chips)

	var clear: Button = UIKit.outline_button("Effacer les mises", UIKit.TEXT_SOFT, 14)
	clear.custom_minimum_size = Vector2(0, 40)
	clear.visible = engine.total_bet() > 0
	clear.pressed.connect(engine.clear_bets)
	col.add_child(clear)

	if Stats.beginner:
		col.add_child(UIKit.advice_panel(
			"Le Banquier gagne un peu plus souvent que le Joueur, d'où sa commission de 5 %. L'Égalité paie gros mais sort rarement : évitez-la. Les cartes se tirent selon des règles fixes, vous ne décidez de rien."
		))

	var deal: Button = UIKit.button("Distribuer", UIKit.GOLD, UIKit.INK, 20)
	deal.disabled = not engine.can_deal()
	deal.pressed.connect(engine.deal)
	col.add_child(deal)
	if Bankroll.value < BaccaratEngine.MIN_BET:
		var warn: Label = UIKit.label("Banque insuffisante — rechargez-la depuis l'accueil.", 12, UIKit.WARNING_TEXT)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	return panel


func _bet_box(title: String, side: int) -> Control:
	var selected: bool = target == side
	var box: PanelContainer = UIKit.panel(
		Color(1, 1, 1, 0.07) if selected else Color(0, 0, 0, 0.2), 14, 6,
		UIKit.GOLD if selected else Color(1, 1, 1, 0.1)
	)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var head: Label = UIKit.label(title, 11, UIKit.GOLD if selected else UIKit.TEXT_SOFT, true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	var pile: ChipPile = ChipPile.new(80)
	pile.set_amount(engine.bets[side])
	_piles[side] = pile
	col.add_child(pile)
	var pick: Button = Button.new()
	pick.flat = true
	pick.focus_mode = Control.FOCUS_NONE
	pick.pressed.connect(_select_target.bind(side))
	box.add_child(pick)
	return box


func _select_target(side: int) -> void:
	target = side
	_rebuild_controls()


func _add_chip(v: int, from: Control = null) -> void:
	ChipFly.fly(from, _piles.get(target) as Control, v, 2)
	engine.add_bet(target, v)


func _open_help() -> void:
	var overlay: HelpOverlay = HelpOverlay.open(self, HelpContent.Topic.BACCARAT)
	overlay.closed.connect(_refresh)


func _go_home() -> void:
	Bankroll.set_pending(0)
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if HelpOverlay.is_open(self):
			HelpOverlay.close_in(self)
		else:
			_go_home()
