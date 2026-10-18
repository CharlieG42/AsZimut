extends Control
## Écran Poker Texas Hold'em heads-up contre ZIA.

const HOME_SCENE: String = "res://scenes/home.tscn"
const AI_DELAY: float = 1.0
const RUNOUT_DELAY: float = 1.3

var engine: PokerEngine

var _stack_label: CoinLabel
var _ai_stack: CoinLabel
var _ai_bet_pile: ChipPile
var _ai_dealer_badge: Control
var _ai_row: CardRow
var _board_row: CardRow
var _pot_chip: CoinLabel
var _street_chip: PanelContainer
var _result_panel: PanelContainer
var _result_label: Label
var _player_row: CardRow
var _player_bet_pile: ChipPile
var _hand_hint: Label
var _raise_to: int = 0
var _last_result: String = ""
var _advice_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _advice_key: String = ""
var _advice_text: String = ""
var _player_dealer_badge: Control
var _log_box: VBoxContainer
var _log_panel: PanelContainer
var _actions: VBoxContainer
var _ai_timer: Timer
var _runout_timer: Timer


func _ready() -> void:
	engine = PokerEngine.new(Bankroll.value, Stats.difficulty)

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
	engine.hand_finished.connect(_on_hand_finished)
	_refresh()
	UIKit.fade_in(self)


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

	var help: Button = UIKit.help_button()
	help.pressed.connect(_open_help.bind(HelpContent.Topic.POKER))
	bar.add_child(help)

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
	head.add_child(AvatarBadge.new(44))
	var who: VBoxContainer = VBoxContainer.new()
	who.add_child(UIKit.label("ZIA", 18, Color.WHITE, true))
	who.add_child(UIKit.label("niveau " + PokerEngine.difficulty_name(engine.difficulty), 11, UIKit.TEXT_SOFT))
	head.add_child(who)
	_ai_stack = CoinLabel.new(14, UIKit.TEXT_SOFT)
	head.add_child(_ai_stack)
	_ai_dealer_badge = _dealer_badge()
	head.add_child(_ai_dealer_badge)
	col.add_child(head)

	_ai_row = CardRow.new(1.0, 2)
	col.add_child(_ai_row)
	_ai_bet_pile = ChipPile.new(120)
	_ai_bet_pile.custom_minimum_size = Vector2(120, 50)
	col.add_child(_ai_bet_pile)
	return col


func _build_table() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var felt: PanelContainer = UIKit.table(col, 14)

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

	_result_panel = PanelContainer.new()
	_result_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
	_result_label = UIKit.label("", 15, Color.WHITE, true)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(_result_label)
	col.add_child(_result_panel)
	return felt


func _build_player_section() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	_player_row = CardRow.new(1.0, 2)
	col.add_child(_player_row)

	_player_bet_pile = ChipPile.new(120)
	_player_bet_pile.custom_minimum_size = Vector2(120, 50)
	col.add_child(_player_bet_pile)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 10)
	foot.add_child(UIKit.label(ProfileStore.solo_name(), 18, Color.WHITE, true))
	_player_dealer_badge = _dealer_badge()
	foot.add_child(_player_dealer_badge)
	col.add_child(foot)

	_hand_hint = UIKit.label("", 13, UIKit.TEXT_SOFT)
	col.add_child(_hand_hint)
	return col


# --- Mise à jour ------------------------------------------------------------


func _refresh() -> void:
	# Les jetons engagés dans la main ne sont plus dans la banque.
	Bankroll.set_to(engine.p_stack)
	_stack_label.set_amount(engine.p_stack, true)
	_ai_stack.set_amount(engine.a_stack, true)

	_ai_bet_pile.set_amount(engine.a_bet)
	_ai_dealer_badge.visible = not engine.dealer_is_player
	_player_bet_pile.set_amount(engine.p_bet)
	_player_dealer_badge.visible = engine.dealer_is_player

	var ai_hidden: Array[bool] = [not engine.reveal_ai, not engine.reveal_ai]
	_ai_row.set_cards(engine.ai_hole, ai_hidden)
	_board_row.set_cards(engine.board)
	_player_row.set_cards(engine.player_hole)

	_pot_chip.set_amount(engine.pot)
	UIKit.chip_label(_street_chip).text = engine.street_label()
	_result_panel.visible = engine.is_over()
	_result_label.text = engine.result
	_result_panel.add_theme_stylebox_override("panel", UIKit.banner_style(_banner_kind()))
	if engine.result != _last_result:
		_last_result = engine.result
		if engine.result != "":
			UIKit.pop(_result_panel)

	var hint_ok: bool = not engine.player_hole.is_empty() and not engine.board.is_empty()
	_hand_hint.visible = hint_ok
	if hint_ok:
		_hand_hint.text = "Votre main : " + engine.describe_hand(engine.player_hole)

	_refresh_log()
	_rebuild_actions()
	_schedule_ai()


func _banner_kind() -> int:
	if not engine.is_over():
		return UIKit.Banner.NEUTRAL
	match engine.last_outcome:
		PokerEngine.HandOutcome.WIN:
			return UIKit.Banner.WIN
		PokerEngine.HandOutcome.LOSE:
			return UIKit.Banner.LOSE
	return UIKit.Banner.NEUTRAL


func _on_hand_finished(outcome: int, net: int, pot_won: int) -> void:
	Stats.record_poker(outcome, net, pot_won)
	ProfileStore.record_active("pk", net > 0, net)
	Stats.note_bank(Bankroll.value)
	match outcome:
		PokerEngine.HandOutcome.WIN:
			UIKit.haptic(Stats.haptics, 60)
			SfxPlayer.play("win")
		PokerEngine.HandOutcome.LOSE:
			UIKit.haptic(Stats.haptics, 140)
			SfxPlayer.play("lose")


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

	if Stats.beginner:
		col.add_child(UIKit.advice_panel(_advice()))

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
		col.add_child(_build_raise_panel())
	return col


## Conseil du mode débutant (mis en cache tant que la situation ne change pas).
func _advice() -> String:
	var raisable: bool = engine.raises < 3 and engine.p_stack > 0
	var key: String = "%s|%s|%d|%d|%s" % [engine.player_hole, engine.board, engine.pot, engine.to_call(), raisable]
	if key != _advice_key:
		_advice_key = key
		_advice_rng.randomize()
		var result: Dictionary = PokerAdvisor.advise(
			engine.player_hole, engine.board, engine.pot, engine.to_call(), 1, raisable, _advice_rng
		)
		_advice_text = str(result["text"])
	return _advice_text


func _build_raise_panel() -> Control:
	var lo: int = engine.min_raise_to()
	var hi: int = engine.max_raise_to()
	var facing_bet: bool = engine.a_bet > 0
	_raise_to = clampi(_raise_to, lo, hi)
	if _raise_to < lo or _raise_to == 0:
		_raise_to = lo

	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 14, 10, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var raise_btn: Button = UIKit.button("", UIKit.GOLD, UIKit.INK, 18)
	col.add_child(raise_btn)

	var set_text: Callable = func() -> void:
		var verb: String = "Relancer à" if facing_bet else "Miser"
		raise_btn.text = ("%s %d" % [verb, _raise_to]) + ("  (tapis)" if _raise_to >= hi else "")
	set_text.call()

	if hi > lo:
		var slider: HSlider = HSlider.new()
		slider.min_value = lo
		slider.max_value = hi
		slider.step = 1
		slider.value = _raise_to
		slider.custom_minimum_size = Vector2(0, 36)
		slider.focus_mode = Control.FOCUS_NONE
		col.add_child(slider)
		slider.value_changed.connect(
			func(v: float) -> void:
				_raise_to = int(v)
				set_text.call()
		)

		var quick: HBoxContainer = HBoxContainer.new()
		quick.add_theme_constant_override("separation", 8)
		var presets: Array[Array] = [
			["½ pot", engine.raise_half_size()],
			["Pot", engine.pot_size_bet()],
			["Tapis", hi],
		]
		for preset: Array in presets:
			var amount: int = clampi(int(preset[1]), lo, hi)
			var b: Button = UIKit.outline_button(str(preset[0]), Color.WHITE, 14)
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(
				func() -> void:
					slider.value = amount
			)
			quick.add_child(b)
		col.add_child(quick)

	raise_btn.pressed.connect(
		func() -> void: engine.bet_raise(PokerEngine.Actor.PLAYER, _raise_to)
	)
	return panel


# --- Navigation -------------------------------------------------------------


func _next_hand() -> void:
	engine.start_hand(false)


func _open_help(topic: int) -> void:
	var overlay: HelpOverlay = HelpOverlay.open(self, topic)
	overlay.closed.connect(_refresh)


func _leave() -> void:
	# Quitter en pleine main revient à se coucher.
	engine.forfeit()
	Bankroll.set_to(engine.p_stack)
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if HelpOverlay.is_open(self):
			HelpOverlay.close_in(self)
		else:
			_leave()
