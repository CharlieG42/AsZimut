extends Control
## Blackjack multijoueur local : chacun mise puis joue à son tour contre le croupier.

const HOME_SCENE: String = "res://scenes/home.tscn"
const CHIP_VALUES: Array[int] = [10, 25, 50, 100]

var engine: MultiBlackjackEngine

var _scroll: ScrollContainer
var _round_label: Label
var _quit_button: Button
var _quit_armed: bool = false
var _dealer_row: CardRow
var _dealer_total: PanelContainer
var _turn_panel: PanelContainer
var _turn_label: Label
var _seat_nodes: Array[Dictionary] = []
var _controls: VBoxContainer
var _dealer_timer: Timer
var _turn_key: int = -999


func _ready() -> void:
	engine = MultiBlackjackEngine.new(LocalSession.player_names(), LocalSession.chips)
	engine.changed.connect(_refresh)
	engine.round_finished.connect(_on_round_finished)

	_dealer_timer = Timer.new()
	_dealer_timer.one_shot = true
	_dealer_timer.wait_time = 0.9
	_dealer_timer.timeout.connect(engine.dealer_plays)
	add_child(_dealer_timer)

	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	_scroll.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_dealer())
	_turn_panel = PanelContainer.new()
	_turn_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
	_turn_label = UIKit.label("", 17, UIKit.GOLD, true)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_panel.add_child(_turn_label)
	col.add_child(_turn_panel)
	for i: int in engine.seats.size():
		col.add_child(_build_seat(i))

	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	col.add_child(_controls)

	_refresh()
	UIKit.fade_in(self)


# --- Construction -----------------------------------------------------------


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	_quit_button = UIKit.outline_button("‹ Terminer", UIKit.TEXT_SOFT, 15)
	_quit_button.custom_minimum_size = Vector2(120, 44)
	_quit_button.pressed.connect(_on_quit_pressed)
	bar.add_child(_quit_button)

	var title: Label = UIKit.label("Blackjack · local", 20, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	_round_label = UIKit.label("", 14, UIKit.TEXT_SOFT)
	_round_label.custom_minimum_size = Vector2(100, 0)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_round_label)
	return bar


func _build_dealer() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIKit.label("CROUPIER", 12, UIKit.TEXT_SOFT, true))
	_dealer_row = CardRow.new(0.9, 2)
	col.add_child(_dealer_row)
	_dealer_total = UIKit.chip("0")
	var wrap: HBoxContainer = HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_dealer_total)
	col.add_child(wrap)
	return UIKit.table(col, 12)


func _build_seat(i: int) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.custom_minimum_size = Vector2(112, 0)
	info.add_theme_constant_override("separation", 2)
	var name_label: Label = UIKit.label(engine.seats[i].name, 16, Color.WHITE, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.clip_text = true
	info.add_child(name_label)
	var stack: CoinLabel = CoinLabel.new(14, UIKit.GOLD)
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	info.add_child(stack)
	var bet: Label = UIKit.label("", 12, UIKit.TEXT_SOFT)
	bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(bet)
	row.add_child(info)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	var cards: CardRow = CardRow.new(0.7, 2)
	right.add_child(cards)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 8)
	var total: PanelContainer = UIKit.chip("0", 12)
	foot.add_child(total)
	var status: Label = UIKit.label("", 14, Color.WHITE, true)
	foot.add_child(status)
	right.add_child(foot)
	row.add_child(right)

	_seat_nodes.append(
		{"panel": panel, "stack": stack, "bet": bet, "cards": cards, "total": total, "status": status}
	)
	return panel


# --- Mise à jour ------------------------------------------------------------


func _refresh() -> void:
	_quit_armed = false
	_quit_button.text = "‹ Terminer"
	var round_number: int = engine.rounds + (0 if engine.phase == MultiBlackjackEngine.Phase.DONE else 1)
	_round_label.text = "Manche %d" % round_number

	var hide_flags: Array[bool] = [false, not engine.revealed]
	_dealer_row.set_cards(engine.dealer, hide_flags)
	_dealer_total.get_parent().visible = not engine.dealer.is_empty()
	if not engine.dealer.is_empty():
		var shown: Array[int] = engine.dealer
		if not engine.revealed:
			shown = [engine.dealer[0]]
		UIKit.chip_label(_dealer_total).text = str(BlackjackEngine.bj_value(shown))

	for i: int in engine.seats.size():
		_refresh_seat(i)

	_refresh_turn()
	_rebuild_controls()
	if engine.phase == MultiBlackjackEngine.Phase.DEALER and _dealer_timer.is_stopped():
		_dealer_timer.start()

	var key: int = engine.phase * 100 + engine.current
	if key != _turn_key:
		_turn_key = key
		if engine.current >= 0:
			UIKit.haptic(Stats.haptics, 35)
			_focus_current.call_deferred()


func _focus_current() -> void:
	if not is_inside_tree() or engine.current < 0:
		return
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.ensure_control_visible(_seat_nodes[engine.current]["panel"] as Control)


func _refresh_seat(i: int) -> void:
	var s: MultiBlackjackEngine.Seat = engine.seats[i]
	var n: Dictionary = _seat_nodes[i]
	var is_current: bool = i == engine.current and engine.phase != MultiBlackjackEngine.Phase.DONE
	var panel: PanelContainer = n["panel"] as PanelContainer
	var bg: Color = Color(0.06, 0.3, 0.17, 0.9) if is_current else Color(0, 0, 0, 0.3)
	var border: Color = UIKit.GOLD if is_current else Color(1, 1, 1, 0.08)
	var style: StyleBoxFlat = UIKit.box(bg, 16, border, 2 if is_current else 1)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.45 if s.out else 1.0

	(n["stack"] as CoinLabel).set_amount(s.stack, true)
	var bet_text: String = ""
	if s.bet > 0 and not s.out:
		bet_text = "Mise %d" % s.bet
	(n["bet"] as Label).text = bet_text

	(n["cards"] as CardRow).set_cards(s.hand)
	var total: PanelContainer = n["total"] as PanelContainer
	total.visible = not s.hand.is_empty()
	if not s.hand.is_empty():
		UIKit.chip_label(total).text = str(BlackjackEngine.bj_value(s.hand))

	var status: Label = n["status"] as Label
	var text: String = ""
	var color: Color = Color.WHITE
	if s.out:
		text = "Éliminé"
		color = UIKit.TEXT_SOFT
	elif s.result != BlackjackEngine.Outcome.NONE:
		match s.result:
			BlackjackEngine.Outcome.BLACKJACK:
				text = "Blackjack ! %s" % UIKit.signed(s.net)
				color = UIKit.GOLD
			BlackjackEngine.Outcome.WIN:
				text = "Gagne %s" % UIKit.signed(s.net)
				color = UIKit.GREEN_ACTION
			BlackjackEngine.Outcome.LOSE:
				text = "Perd %d" % -s.net
				color = UIKit.WARNING_TEXT
			BlackjackEngine.Outcome.PUSH:
				text = "Égalité"
				color = UIKit.TEXT_SOFT
	elif is_current and engine.phase == MultiBlackjackEngine.Phase.PLAY:
		text = "À vous"
		color = UIKit.GOLD
	elif s.ready and s.done:
		var value: int = BlackjackEngine.bj_value(s.hand)
		if value > 21:
			text = "Dépasse"
			color = UIKit.WARNING_TEXT
		elif value == 21 and s.hand.size() == 2:
			text = "Blackjack !"
			color = UIKit.GOLD
		else:
			text = "Reste"
			color = UIKit.TEXT_SOFT
	elif is_current and engine.phase == MultiBlackjackEngine.Phase.BET:
		text = "Mise en cours"
		color = UIKit.GOLD
	elif s.ready and engine.phase == MultiBlackjackEngine.Phase.BET:
		text = "Prêt"
		color = UIKit.TEXT_SOFT
	status.text = text
	status.add_theme_color_override("font_color", color)


func _refresh_turn() -> void:
	var text: String = ""
	match engine.phase:
		MultiBlackjackEngine.Phase.BET:
			if engine.current >= 0:
				text = "%s, placez votre mise" % engine.seats[engine.current].name
		MultiBlackjackEngine.Phase.PLAY:
			text = "%s, à vous de jouer" % engine.seats[engine.current].name
		MultiBlackjackEngine.Phase.DEALER:
			text = "Le croupier joue…"
		MultiBlackjackEngine.Phase.DONE:
			text = "Partie terminée — plus personne ne peut miser." if engine.is_game_over() else "Manche terminée"
	_turn_label.text = text
	if _turn_panel.is_inside_tree() and text != "":
		UIKit.pop(_turn_panel)


func _rebuild_controls() -> void:
	for child: Node in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	match engine.phase:
		MultiBlackjackEngine.Phase.BET:
			if engine.current >= 0:
				_controls.add_child(_build_bet_panel())
		MultiBlackjackEngine.Phase.PLAY:
			_controls.add_child(_build_action_buttons())
		MultiBlackjackEngine.Phase.DEALER:
			var wait: Label = UIKit.label("Le croupier joue…", 16, UIKit.TEXT_SOFT)
			wait.custom_minimum_size = Vector2(0, 56)
			_controls.add_child(wait)
		MultiBlackjackEngine.Phase.DONE:
			if engine.is_game_over():
				var results: Button = UIKit.button("Voir le classement", UIKit.GOLD, UIKit.INK, 20)
				results.pressed.connect(_show_results)
				_controls.add_child(results)
			else:
				var next: Button = UIKit.button("Manche suivante", UIKit.GOLD, UIKit.INK, 20)
				next.pressed.connect(engine.next_round)
				_controls.add_child(next)


func _build_bet_panel() -> Control:
	var s: MultiBlackjackEngine.Seat = engine.seats[engine.current]
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(UIKit.label("Mise de %s" % s.name, 16, Color.WHITE, true))
	var pile: ChipPile = ChipPile.new(110)
	pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile.set_amount(s.bet)
	head.add_child(pile)
	if s.bet > 0:
		var clear: Button = UIKit.outline_button("Effacer", UIKit.TEXT_SOFT, 14)
		clear.custom_minimum_size = Vector2(90, 40)
		clear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clear.pressed.connect(engine.clear_bet)
		head.add_child(clear)
	col.add_child(head)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	for v: int in CHIP_VALUES:
		var chip_btn: ChipButton = ChipButton.new(v)
		chip_btn.disabled = s.bet + v > s.stack
		chip_btn.pressed.connect(engine.add_to_bet.bind(v))
		chips.add_child(chip_btn)
	col.add_child(chips)

	var confirm: Button = UIKit.button("Valider la mise", UIKit.GOLD, UIKit.INK, 20)
	confirm.disabled = not (s.bet >= MultiBlackjackEngine.MIN_BET and s.bet <= s.stack)
	confirm.pressed.connect(engine.confirm_bet)
	col.add_child(confirm)
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


# --- Événements et navigation -----------------------------------------------


func _on_round_finished() -> void:
	UIKit.haptic(Stats.haptics, 80)


func _on_quit_pressed() -> void:
	if _quit_armed:
		_show_results()
	else:
		_quit_armed = true
		_quit_button.text = "Confirmer ?"


func _show_results() -> void:
	var rows: Array[Dictionary] = []
	for i: int in engine.standings():
		var s: MultiBlackjackEngine.Seat = engine.seats[i]
		# Une mise déjà engagée mais non réglée est rendue au joueur.
		var stack: int = s.stack
		if s.ready and engine.phase != MultiBlackjackEngine.Phase.DONE:
			stack += s.bet
		rows.append({"name": s.name, "stack": stack, "start": LocalSession.chips})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["stack"]) > int(b["stack"]))
	LocalSession.store_results(rows)
	get_tree().change_scene_to_file(LocalSession.RESULTS_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_quit_pressed()
