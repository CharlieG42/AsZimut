extends Control
## Écran Three Card Poker (contre le croupier).

const HOME_SCENE: String = "res://scenes/home.tscn"
const CHIP_VALUES: Array[int] = [10, 25, 50, 100]

var engine: ThreeCardEngine

var _bank: CoinLabel
var _dealer_row: CardRow
var _player_row: CardRow
var _dealer_chip: PanelContainer
var _player_chip: PanelContainer
var _message_panel: PanelContainer
var _message_label: Label
var _controls: VBoxContainer
var _last_message: String = ""
var _ante_pile: ChipPile
var _pair_pile: ChipPile
## Cible des jetons pendant la mise : 0 = Ante, 1 = Pair Plus.
var _target: int = 0


func _ready() -> void:
	engine = ThreeCardEngine.new(Bankroll)
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

	var title: Label = UIKit.label("Three Card Poker", 20, UIKit.GOLD, true)
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

	col.add_child(UIKit.label("CROUPIER", 12, UIKit.TEXT_SOFT, true))
	_dealer_row = CardRow.new(1.0, 3)
	col.add_child(_dealer_row)
	_dealer_chip = UIKit.chip("")
	col.add_child(_centered(_dealer_chip))

	col.add_child(HSeparator.new())

	_player_row = CardRow.new(1.0, 3)
	col.add_child(_player_row)
	col.add_child(UIKit.label("VOUS", 12, UIKit.TEXT_SOFT, true))
	_player_chip = UIKit.chip("")
	col.add_child(_centered(_player_chip))

	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
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


func _refresh() -> void:
	_bank.set_amount(Bankroll.value, true)

	var hide_flags: Array[bool] = [not engine.revealed, not engine.revealed, not engine.revealed]
	_dealer_row.set_cards(engine.dealer, hide_flags)
	_player_row.set_cards(engine.player)

	_dealer_chip.get_parent().visible = engine.revealed and not engine.dealer.is_empty()
	if engine.revealed and not engine.dealer.is_empty():
		var q: String = "" if engine.dealer_qualified or engine.folded else " · non qualifié"
		UIKit.chip_label(_dealer_chip).text = _upper_first(ThreeCardEngine.hand_name(engine.dealer)) + q
	_player_chip.get_parent().visible = not engine.player.is_empty()
	if not engine.player.is_empty():
		UIKit.chip_label(_player_chip).text = _upper_first(ThreeCardEngine.hand_name(engine.player))

	_message_panel.visible = engine.message != ""
	_message_label.text = engine.message
	_message_panel.add_theme_stylebox_override("panel", UIKit.banner_style(_banner_kind()))
	if engine.message != _last_message:
		_last_message = engine.message
		if engine.message != "":
			UIKit.pop(_message_panel)

	_rebuild_controls()


func _upper_first(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


func _banner_kind() -> int:
	if engine.phase != ThreeCardEngine.Phase.DONE:
		return UIKit.Banner.NEUTRAL
	if engine.net > 0:
		return UIKit.Banner.WIN
	if engine.net < 0:
		return UIKit.Banner.LOSE
	return UIKit.Banner.NEUTRAL


func _on_round_finished(net: int) -> void:
	var category: int = ThreeCardEngine.evaluate(engine.player)[0]
	Stats.record_three_card(net, category, engine.folded, engine.pair_plus_won)
	var extra: Dictionary = {}
	if engine.folded:
		extra["folds"] = 1
	if engine.pair_plus_won:
		extra["pair_plus_wins"] = 1
	ProfileStore.record_active("tc", net > 0, net, -1, extra)
	Stats.note_bank(Bankroll.value)
	if net > 0:
		UIKit.haptic(Stats.haptics, 60)
		SfxPlayer.play("win")
	elif net < 0:
		UIKit.haptic(Stats.haptics, 140)
		SfxPlayer.play("lose")


func _rebuild_controls() -> void:
	for child: Node in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	match engine.phase:
		ThreeCardEngine.Phase.BET:
			_controls.add_child(_build_bet_panel())
		ThreeCardEngine.Phase.DECIDE:
			if Stats.beginner:
				_controls.add_child(UIKit.advice_panel(ThreeCardAdvisor.explain(engine.player)))
			_controls.add_child(_build_decision())
		ThreeCardEngine.Phase.DONE:
			var again: Button = UIKit.button("Rejouer", UIKit.GOLD, UIKit.INK, 20)
			again.pressed.connect(engine.replay)
			_controls.add_child(again)


func _build_bet_panel() -> Control:
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	# Deux mises côte à côte : toucher l'une la choisit comme cible des jetons.
	var piles: HBoxContainer = HBoxContainer.new()
	piles.add_theme_constant_override("separation", 10)
	piles.add_child(_bet_box("Ante", engine.ante, 0))
	piles.add_child(_bet_box("Pair Plus (facultatif)", engine.pair_plus, 1))
	col.add_child(piles)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	for v: int in CHIP_VALUES:
		var chip_btn: ChipButton = ChipButton.new(v)
		chip_btn.disabled = not (engine.can_add_ante(v) if _target == 0 else engine.can_add_pair_plus(v))
		chip_btn.pressed.connect(_add_chip.bind(v))
		chips.add_child(chip_btn)
	col.add_child(chips)

	var clear: Button = UIKit.outline_button("Effacer les mises", UIKit.TEXT_SOFT, 14)
	clear.custom_minimum_size = Vector2(0, 40)
	clear.visible = engine.ante > 0 or engine.pair_plus > 0
	clear.pressed.connect(engine.clear_bets)
	col.add_child(clear)

	if Stats.beginner:
		col.add_child(UIKit.advice_panel(
			"Misez l'Ante, puis vous la doublerez si vous jouez. " + ThreeCardAdvisor.pair_plus_advice()
		))

	var deal: Button = UIKit.button("Distribuer", UIKit.GOLD, UIKit.INK, 20)
	deal.disabled = not engine.can_deal()
	deal.pressed.connect(engine.deal)
	col.add_child(deal)

	var note: Label = UIKit.label(
		"Si vous jouez, une seconde mise égale à l'Ante s'ajoute : gardez-la en réserve.", 12, UIKit.TEXT_SOFT
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	if Bankroll.value < ThreeCardEngine.MIN_BET * 2:
		var warn: Label = UIKit.label(
			"Banque insuffisante (il faut au moins %d) — rechargez-la depuis l'accueil." % (ThreeCardEngine.MIN_BET * 2),
			12, UIKit.WARNING_TEXT
		)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	return panel


func _bet_box(title: String, amount: int, target: int) -> Control:
	var selected: bool = _target == target
	var box: PanelContainer = UIKit.panel(
		Color(1, 1, 1, 0.07) if selected else Color(0, 0, 0, 0.2), 14, 8,
		UIKit.GOLD if selected else Color(1, 1, 1, 0.1)
	)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var head: Label = UIKit.label(title, 13, UIKit.GOLD if selected else UIKit.TEXT_SOFT, true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	var pile: ChipPile = ChipPile.new(110)
	pile.set_amount(amount)
	col.add_child(pile)
	if target == 0:
		_ante_pile = pile
	else:
		_pair_pile = pile
	# Bouton transparent : choisir cette mise comme cible des jetons.
	var pick: Button = Button.new()
	pick.flat = true
	pick.focus_mode = Control.FOCUS_NONE
	pick.pressed.connect(_select_target.bind(target))
	box.add_child(pick)
	return box


func _select_target(target: int) -> void:
	_target = target
	_rebuild_controls()


func _add_chip(v: int) -> void:
	if _target == 0:
		engine.add_ante(v)
	else:
		engine.add_pair_plus(v)


func _build_decision() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var play: Button = UIKit.button("Jouer (+%d)" % engine.ante, UIKit.GREEN_ACTION)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(engine.play)
	row.add_child(play)
	var fold: Button = UIKit.button("Se coucher", UIKit.GOLD, UIKit.INK)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold.pressed.connect(engine.fold)
	row.add_child(fold)
	return row


func _open_help() -> void:
	var overlay: HelpOverlay = HelpOverlay.open(self, HelpContent.Topic.THREE_CARD)
	overlay.closed.connect(_refresh)


func _go_home() -> void:
	# Quitter en pleine manche l'abandonne (les mises restent perdues).
	Bankroll.set_pending(0)
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if HelpOverlay.is_open(self):
			HelpOverlay.close_in(self)
		else:
			_go_home()
