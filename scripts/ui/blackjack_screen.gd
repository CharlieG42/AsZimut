extends Control
## Écran Blackjack.

const HOME_SCENE: String = "res://scenes/home.tscn"
const CHIP_VALUES: Array[int] = [10, 25, 50, 100]

var engine: BlackjackEngine

var _bank: CoinLabel
var _dealer_row: CardRow
var _player_row: CardRow
var _dealer_total: PanelContainer
var _player_total: PanelContainer
var _message_panel: PanelContainer
var _message_label: Label
var _controls: VBoxContainer
var _dealer_timer: Timer


func _ready() -> void:
	engine = BlackjackEngine.new(Bankroll)
	engine.changed.connect(_refresh)

	_dealer_timer = Timer.new()
	_dealer_timer.one_shot = true
	_dealer_timer.wait_time = 0.9
	_dealer_timer.timeout.connect(engine.dealer_plays)
	add_child(_dealer_timer)

	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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

	_refresh()


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)

	var title: Label = UIKit.label("Blackjack", 22, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	_bank = CoinLabel.new(17, UIKit.GOLD)
	_bank.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_bank)
	return bar


func _build_felt() -> Control:
	var felt: PanelContainer = UIKit.panel(UIKit.FELT_GREEN, 24, 16, Color(0.024, 0.306, 0.231, 1.0))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	felt.add_child(col)

	col.add_child(UIKit.label("CROUPIER", 12, UIKit.TEXT_SOFT, true))
	_dealer_row = CardRow.new(1.0, 2)
	col.add_child(_dealer_row)
	_dealer_total = UIKit.chip("0")
	col.add_child(_centered(_dealer_total))

	col.add_child(HSeparator.new())

	_player_row = CardRow.new(1.0, 2)
	col.add_child(_player_row)
	col.add_child(UIKit.label("VOUS", 12, UIKit.TEXT_SOFT, true))
	_player_total = UIKit.chip("0")
	col.add_child(_centered(_player_total))

	_message_panel = UIKit.panel(Color(0, 0, 0, 0.4), 12, 10)
	_message_label = UIKit.label("", 14, UIKit.GOLD, true)
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
	_bank.set_amount(Bankroll.value)

	var hide_flags: Array[bool] = [false, not engine.revealed]
	_dealer_row.set_cards(engine.dealer, hide_flags)
	_player_row.set_cards(engine.player)

	_dealer_total.get_parent().visible = not engine.dealer.is_empty()
	if not engine.dealer.is_empty():
		var shown: Array[int] = engine.dealer
		if not engine.revealed:
			shown = [engine.dealer[0]]
		UIKit.chip_label(_dealer_total).text = str(BlackjackEngine.bj_value(shown))
	_player_total.get_parent().visible = not engine.player.is_empty()
	if not engine.player.is_empty():
		UIKit.chip_label(_player_total).text = str(BlackjackEngine.bj_value(engine.player))

	_message_panel.visible = engine.message != ""
	_message_label.text = engine.message

	_rebuild_controls()
	if engine.phase == BlackjackEngine.Phase.DEALER and _dealer_timer.is_stopped():
		_dealer_timer.start()


func _rebuild_controls() -> void:
	for child: Node in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	match engine.phase:
		BlackjackEngine.Phase.BET:
			_controls.add_child(_build_bet_panel())
		BlackjackEngine.Phase.PLAYER:
			_controls.add_child(_build_action_buttons())
		BlackjackEngine.Phase.DEALER:
			var wait: Label = UIKit.label("Le croupier joue…", 16, UIKit.TEXT_SOFT)
			wait.custom_minimum_size = Vector2(0, 56)
			_controls.add_child(wait)
		BlackjackEngine.Phase.DONE:
			var again: Button = UIKit.button("Rejouer", UIKit.GOLD, UIKit.INK, 20)
			again.pressed.connect(engine.replay)
			_controls.add_child(again)


func _build_bet_panel() -> Control:
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(UIKit.label("Mise :", 16, Color.WHITE, true))
	var amount: CoinLabel = CoinLabel.new(18, UIKit.GOLD)
	amount.set_amount(engine.bet)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(amount)
	if engine.bet > 0:
		var clear: Button = UIKit.outline_button("Effacer", UIKit.TEXT_SOFT, 14)
		clear.custom_minimum_size = Vector2(90, 40)
		clear.pressed.connect(engine.clear_bet)
		head.add_child(clear)
	col.add_child(head)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	for v: int in CHIP_VALUES:
		var chip_btn: Button = UIKit.outline_button("+%d" % v, Color.WHITE, 17)
		chip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_btn.disabled = engine.bet + v > Bankroll.value
		chip_btn.pressed.connect(engine.add_to_bet.bind(v))
		chips.add_child(chip_btn)
	col.add_child(chips)

	var deal: Button = UIKit.button("Distribuer", UIKit.GOLD, UIKit.INK, 20)
	deal.disabled = not (engine.bet >= BlackjackEngine.MIN_BET and engine.bet <= Bankroll.value)
	deal.pressed.connect(engine.deal)
	col.add_child(deal)

	if Bankroll.value < BlackjackEngine.MIN_BET:
		var warn: Label = UIKit.label(
			"Banque insuffisante — rechargez-la depuis l'accueil.", 12, UIKit.WARNING_TEXT
		)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	return panel


func _build_action_buttons() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var hit: Button = UIKit.button("Carte", UIKit.GREEN_ACTION)
	hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit.pressed.connect(engine.hit)
	row.add_child(hit)

	var stand: Button = UIKit.button("Rester", UIKit.GOLD, UIKit.INK)
	stand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stand.pressed.connect(engine.stand)
	row.add_child(stand)

	var dbl: Button = UIKit.button("Doubler", Color(0.2, 0.33, 0.28))
	dbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbl.disabled = not engine.can_double()
	dbl.pressed.connect(engine.double_down)
	row.add_child(dbl)
	return row


func _go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
