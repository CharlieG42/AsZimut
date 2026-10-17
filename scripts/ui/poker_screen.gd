extends Control
## Écran Poker Texas Hold'em heads-up contre ZIA.

const HOME_SCENE: String = "res://scenes/home.tscn"
const AI_DELAY: float = 1.0
const RUNOUT_DELAY: float = 1.3

var engine: PokerEngine

var _stack_label: CoinLabel
var _ai_stack: CoinLabel
var _ai_bet_chip: PanelContainer
var _ai_dealer_badge: Control
var _ai_row: CardRow
var _board_row: CardRow
var _pot_chip: CoinLabel
var _street_chip: PanelContainer
var _result_panel: PanelContainer
var _result_label: Label
var _player_row: CardRow
var _player_bet_chip: PanelContainer
var _player_dealer_badge: Control
var _log_box: VBoxContainer
var _log_panel: PanelContainer
var _actions: VBoxContainer
var _ai_timer: Timer
var _runout_timer: Timer


func _ready() -> void:
	engine = PokerEngine.new(Bankroll.value)

	_ai_timer = _make_timer(AI_DELAY, _on_ai_timer)
	_runout_timer = _make_timer(RUNOUT_DELAY, _on_runout_timer)

	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_ai_section())
	col.add_child(_build_table())
	col.add_child(_build_player_section())

	_log_panel = UIKit.panel(Color(0, 0, 0, 0.2), 12, 10, Color(1, 1, 1, 0.06))
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 2)
	_log_panel.add_child(_log_box)
	col.add_child(_log_panel)

	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	col.add_child(_actions)

	engine.changed.connect(_refresh)
	_refresh()


func _make_timer(wait: float, handler: Callable) -> Timer:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = wait
	t.timeout.connect(handler)
	add_child(t)
	return t


# --- Construction -----------------------------------------------------------


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_leave)
	bar.add_child(back)

	var title: Label = UIKit.label("Poker Hold'em", 21, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	_stack_label = CoinLabel.new(17, UIKit.GOLD)
	_stack_label.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_stack_label)
	return bar


func _dealer_badge() -> Control:
	var badge: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UIKit.box(Color.WHITE, 12)
	style.content_margin_left = 6
	style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(UIKit.label("D", 12, Color(0.06, 0.09, 0.16), true))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


func _build_ai_section() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var head: HBoxContainer = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	head.add_child(UIKit.label("ZIA", 18, Color.WHITE, true))
	_ai_stack = CoinLabel.new(14, UIKit.TEXT_SOFT)
	head.add_child(_ai_stack)
	_ai_bet_chip = UIKit.chip("")
	head.add_child(_ai_bet_chip)
	_ai_dealer_badge = _dealer_badge()
	head.add_child(_ai_dealer_badge)
	col.add_child(head)

	_ai_row = CardRow.new(1.0, 2)
	col.add_child(_ai_row)
	return col


func _build_table() -> Control:
	var felt: PanelContainer = UIKit.panel(UIKit.FELT_GREEN, 24, 14, Color(0.024, 0.306, 0.231, 1.0))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	felt.add_child(col)

	_board_row = CardRow.new(0.9, 5)
	col.add_child(_board_row)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	var pot_pill: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.4), 14, 5, Color(1, 1, 1, 0.15))
	_pot_chip = CoinLabel.new(14, Color(0.82, 0.98, 0.9), "Pot :")
	pot_pill.add_child(_pot_chip)
	chips.add_child(pot_pill)
	_street_chip = UIKit.chip("")
	chips.add_child(_street_chip)
	col.add_child(chips)

	_result_panel = UIKit.panel(Color(0, 0, 0, 0.5), 12, 10)
	_result_label = UIKit.label("", 14, UIKit.GOLD, true)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(_result_label)
	col.add_child(_result_panel)
	return felt


func _build_player_section() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	_player_row = CardRow.new(1.0, 2)
	col.add_child(_player_row)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 10)
	foot.add_child(UIKit.label("Vous", 18, Color.WHITE, true))
	_player_bet_chip = UIKit.chip("")
	foot.add_child(_player_bet_chip)
	_player_dealer_badge = _dealer_badge()
	foot.add_child(_player_dealer_badge)
	col.add_child(foot)
	return col


# --- Mise à jour ------------------------------------------------------------


func _refresh() -> void:
	# Les jetons engagés dans la main ne sont plus dans la banque.
	Bankroll.set_to(engine.p_stack)
	_stack_label.set_amount(engine.p_stack)
	_ai_stack.set_amount(engine.a_stack)

	_ai_bet_chip.visible = engine.a_bet > 0
	UIKit.chip_label(_ai_bet_chip).text = "mise %d" % engine.a_bet
	_ai_dealer_badge.visible = not engine.dealer_is_player
	_player_bet_chip.visible = engine.p_bet > 0
	UIKit.chip_label(_player_bet_chip).text = "mise %d" % engine.p_bet
	_player_dealer_badge.visible = engine.dealer_is_player

	var ai_hidden: Array[bool] = [not engine.reveal_ai, not engine.reveal_ai]
	_ai_row.set_cards(engine.ai_hole, ai_hidden)
	_board_row.set_cards(engine.board)
	_player_row.set_cards(engine.player_hole)

	_pot_chip.set_amount(engine.pot)
	UIKit.chip_label(_street_chip).text = engine.street_label()
	_result_panel.visible = engine.is_over()
	_result_label.text = engine.result

	_refresh_log()
	_rebuild_actions()
	_schedule_ai()


func _refresh_log() -> void:
	_log_panel.visible = not engine.log_lines.is_empty()
	for child: Node in _log_box.get_children():
		_log_box.remove_child(child)
		child.queue_free()
	for i: int in engine.log_lines.size():
		var fade: float = clampf(1.0 - i * 0.2, 0.2, 1.0)
		var line: Label = UIKit.label(
			engine.log_lines[i], 12, Color(UIKit.TEXT_SOFT.r, UIKit.TEXT_SOFT.g, UIKit.TEXT_SOFT.b, fade)
		)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_log_box.add_child(line)


func _schedule_ai() -> void:
	if engine.is_over():
		return
	if engine.to_act == PokerEngine.Actor.AI and _ai_timer.is_stopped():
		_ai_timer.start()
	if engine.runout and _runout_timer.is_stopped():
		_runout_timer.start()


func _on_ai_timer() -> void:
	engine.ai_act()


func _on_runout_timer() -> void:
	engine.advance_street()


func _rebuild_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	if engine.is_over():
		_actions.add_child(_build_end_actions())
	elif engine.is_player_turn():
		_actions.add_child(_build_player_actions())
	else:
		var wait: Label = UIKit.label("ZIA réfléchit…", 16, UIKit.TEXT_SOFT)
		wait.custom_minimum_size = Vector2(0, 56)
		_actions.add_child(wait)


func _build_end_actions() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var next: Button = UIKit.button("Main suivante", UIKit.GOLD, UIKit.INK, 19)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.disabled = engine.p_stack <= 0
	next.pressed.connect(_next_hand)
	row.add_child(next)
	var quit: Button = UIKit.outline_button("Quitter", Color.WHITE, 17)
	quit.custom_minimum_size = Vector2(110, 56)
	quit.pressed.connect(_leave)
	row.add_child(quit)
	col.add_child(row)
	if engine.p_stack <= 0:
		var warn: Label = UIKit.label(
			"Plus de jetons — rechargez la banque depuis l'accueil.", 12, UIKit.WARNING_TEXT
		)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	return col


func _build_player_actions() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var fold: Button = UIKit.button("Coucher", UIKit.DANGER)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold.pressed.connect(engine.fold.bind(PokerEngine.Actor.PLAYER))
	row.add_child(fold)
	var call_text: String = "Suivre %d" % engine.to_call() if engine.to_call() > 0 else "Checker"
	var call_btn: Button = UIKit.button(call_text, UIKit.GREEN_ACTION)
	call_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_btn.pressed.connect(engine.check_call.bind(PokerEngine.Actor.PLAYER))
	row.add_child(call_btn)
	col.add_child(row)

	if engine.raises < 3 and engine.p_stack > 0:
		var raise_row: HBoxContainer = HBoxContainer.new()
		raise_row.add_theme_constant_override("separation", 8)
		var facing_bet: bool = engine.a_bet > 0
		var size_amount: int = engine.raise_half_size() if facing_bet else engine.open_bet_size()
		var size_text: String = ("Relancer à %d" if facing_bet else "Miser %d") % size_amount
		var size_btn: Button = UIKit.outline_button(size_text, Color.WHITE, 15)
		size_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_btn.pressed.connect(engine.bet_raise.bind(PokerEngine.Actor.PLAYER, size_amount))
		raise_row.add_child(size_btn)

		var pot_btn: Button = UIKit.outline_button("Pot", Color.WHITE, 15)
		pot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pot_btn.pressed.connect(
			engine.bet_raise.bind(PokerEngine.Actor.PLAYER, engine.pot_size_bet())
		)
		raise_row.add_child(pot_btn)

		var all_in: Button = UIKit.outline_button("Tapis", UIKit.GOLD, 15)
		all_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_in.pressed.connect(
			engine.bet_raise.bind(PokerEngine.Actor.PLAYER, engine.p_bet + engine.p_stack)
		)
		raise_row.add_child(all_in)
		col.add_child(raise_row)
	return col


# --- Navigation -------------------------------------------------------------


func _next_hand() -> void:
	engine.start_hand(false)


func _leave() -> void:
	# Quitter en pleine main revient à se coucher.
	engine.forfeit()
	Bankroll.set_to(engine.p_stack)
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_leave()
