extends Control
## Poker multijoueur local : 2 à 6 joueurs sur le même appareil.
## Entre deux joueurs, un écran « passez l'appareil » masque les cartes.

const RUNOUT_DELAY: float = 1.2

var engine: PokerTableEngine

var _scroll: ScrollContainer
var _quit_button: Button
var _quit_armed: bool = false
var _blinds_label: Label
var _turn_panel: PanelContainer
var _turn_label: Label
var _seat_nodes: Array[Dictionary] = []
var _board_row: CardRow
var _pot_pile: ChipPile
var _street_chip: PanelContainer
var _result_panel: PanelContainer
var _result_label: Label
var _hole_box: VBoxContainer
var _hole_title: Label
var _hole_row: CardRow
var _hint: Label
var _log_panel: PanelContainer
var _log_box: VBoxContainer
var _actions: VBoxContainer
var _cover: Control
var _cover_name: Label
var _cover_button: Button
var _runout_timer: Timer

## Joueur qui a confirmé tenir l'appareil (ses cartes sont visibles) ; -1 si personne.
var _unlocked_for: int = -1
var _raise_to: int = 0
var _result_key: String = ""


func _ready() -> void:
	engine = PokerTableEngine.new(LocalSession.player_names(), LocalSession.chips)
	engine.changed.connect(_refresh)

	_runout_timer = Timer.new()
	_runout_timer.one_shot = true
	_runout_timer.wait_time = RUNOUT_DELAY
	_runout_timer.timeout.connect(_on_runout)
	add_child(_runout_timer)

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
	_turn_panel = PanelContainer.new()
	_turn_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
	_turn_label = UIKit.label("", 17, UIKit.GOLD, true)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_panel.add_child(_turn_label)
	col.add_child(_turn_panel)
	col.add_child(_build_table())
	col.add_child(_build_hole_section())

	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	col.add_child(_actions)

	col.add_child(_build_seats())

	_log_panel = UIKit.panel(Color(0, 0, 0, 0.2), 12, 10, Color(1, 1, 1, 0.06))
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 2)
	_log_panel.add_child(_log_box)
	col.add_child(_log_panel)

	_build_cover()
	engine.start_hand()
	UIKit.fade_in(self)


# --- Construction -----------------------------------------------------------


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	_quit_button = UIKit.outline_button("‹ Terminer", UIKit.TEXT_SOFT, 15)
	_quit_button.custom_minimum_size = Vector2(120, 44)
	_quit_button.pressed.connect(_on_quit_pressed)
	bar.add_child(_quit_button)

	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("Poker · local", 20, UIKit.GOLD, true))
	_blinds_label = UIKit.label("", 12, UIKit.TEXT_SOFT)
	mid.add_child(_blinds_label)
	bar.add_child(mid)

	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(60, 0)
	bar.add_child(pad)
	return bar


func _build_seats() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i: int in engine.seats.size():
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		panel.add_child(col)

		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var name_label: Label = UIKit.label(engine.seats[i].name, 15, Color.WHITE, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		head.add_child(name_label)
		var tag: Label = UIKit.label("", 11, UIKit.INK, true)
		var tag_box: PanelContainer = PanelContainer.new()
		tag_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.GOLD, 8))
		tag_box.add_child(tag)
		head.add_child(tag_box)
		col.add_child(head)

		var stack: CoinLabel = CoinLabel.new(13, UIKit.GOLD)
		stack.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_child(stack)

		var foot: HBoxContainer = HBoxContainer.new()
		foot.add_theme_constant_override("separation", 6)
		var cards: CardRow = CardRow.new(0.55, 2)
		cards.alignment = BoxContainer.ALIGNMENT_BEGIN
		foot.add_child(cards)
		var status: Label = UIKit.label("", 13, UIKit.TEXT_SOFT, true)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.add_child(status)
		col.add_child(foot)

		grid.add_child(panel)
		_seat_nodes.append(
			{"panel": panel, "stack": stack, "cards": cards, "status": status, "tag": tag, "tag_box": tag_box}
		)
	return grid


func _build_table() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	_board_row = CardRow.new(0.9, 5)
	col.add_child(_board_row)

	var info: HBoxContainer = HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 12)
	info.add_child(UIKit.label("Pot", 14, Color(0.82, 0.98, 0.9), true))
	_pot_pile = ChipPile.new(130)
	_pot_pile.custom_minimum_size = Vector2(130, 56)
	info.add_child(_pot_pile)
	_street_chip = UIKit.chip("")
	info.add_child(_street_chip)
	col.add_child(info)

	_result_panel = PanelContainer.new()
	_result_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
	_result_label = UIKit.label("", 15, Color.WHITE, true)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(_result_label)
	col.add_child(_result_panel)
	return UIKit.table(col, 12)


func _build_hole_section() -> Control:
	_hole_box = VBoxContainer.new()
	_hole_box.add_theme_constant_override("separation", 6)
	_hole_title = UIKit.label("", 16, Color.WHITE, true)
	_hole_box.add_child(_hole_title)
	_hole_row = CardRow.new(1.0, 2)
	_hole_box.add_child(_hole_row)
	_hint = UIKit.label("", 13, UIKit.TEXT_SOFT)
	_hole_box.add_child(_hint)
	return _hole_box


func _build_cover() -> void:
	_cover = Control.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.016, 0.06, 0.04, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(center)

	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var backs: CardRow = CardRow.new(1.3, 2)
	var back_cards: Array[int] = [0, 1]
	var back_flags: Array[bool] = [true, true]
	backs.set_cards(back_cards, back_flags)
	col.add_child(backs)
	col.add_child(UIKit.spacer(8))
	col.add_child(UIKit.label("Passez l'appareil à", 17, UIKit.TEXT_SOFT))
	_cover_name = UIKit.label("", 38, UIKit.GOLD, true)
	_cover_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_cover_name)
	var warn: Label = UIKit.label("Les autres joueurs ne doivent pas voir l'écran.", 13, UIKit.TEXT_SOFT)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(warn)
	col.add_child(UIKit.spacer(10))
	_cover_button = UIKit.button("", UIKit.GOLD, UIKit.INK, 20)
	_cover_button.pressed.connect(_on_cover_pressed)
	col.add_child(_cover_button)
	_cover.visible = false


# --- Mise à jour ------------------------------------------------------------


func _refresh() -> void:
	var e: PokerTableEngine = engine
	_quit_armed = false
	_quit_button.text = "‹ Terminer"

	if e.hand_over or e.runout or not e.can_act():
		_unlocked_for = -1
	var needs_cover: bool = e.can_act() and not e.runout and _unlocked_for != e.to_act
	if needs_cover and not _cover.visible:
		_cover_name.text = e.seats[e.to_act].name
		_cover_button.text = "Je suis %s" % e.seats[e.to_act].name
		UIKit.haptic(Stats.haptics, 45)
	elif needs_cover:
		_cover_name.text = e.seats[e.to_act].name
		_cover_button.text = "Je suis %s" % e.seats[e.to_act].name
	_cover.visible = needs_cover

	var blinds: String = "Main %d · blinds %d/%d" % [e.hand_number, e.small_blind(), e.big_blind()]
	var left: int = PokerTableEngine.HANDS_PER_LEVEL - (e.hand_number - 1) % PokerTableEngine.HANDS_PER_LEVEL
	if e.small_blind() < PokerTableEngine.BLIND_LEVELS[PokerTableEngine.BLIND_LEVELS.size() - 1]:
		blinds += " (hausse dans %d)" % left
	_blinds_label.text = blinds

	_refresh_turn()
	for i: int in e.seats.size():
		_refresh_seat(i)

	_board_row.set_cards(e.board)
	_pot_pile.set_amount(e.last_pot if e.hand_over else e.pot())
	UIKit.chip_label(_street_chip).text = e.street_label()
	_refresh_result()
	_refresh_hole()
	_refresh_log()
	_rebuild_actions()

	if e.runout and _runout_timer.is_stopped():
		_runout_timer.start()


func _refresh_turn() -> void:
	var e: PokerTableEngine = engine
	var text: String = ""
	if e.is_game_over():
		text = "Partie terminée"
	elif e.hand_over:
		text = "Main %d terminée" % e.hand_number
	elif e.runout:
		text = "Tapis — le board se dévoile…"
	elif e.can_act():
		text = "Au tour de %s" % e.seats[e.to_act].name
	if text != _turn_label.text:
		_turn_label.text = text
		if text != "":
			UIKit.pop(_turn_panel)


func _refresh_seat(i: int) -> void:
	var e: PokerTableEngine = engine
	var s: PokerTableEngine.Seat = e.seats[i]
	var n: Dictionary = _seat_nodes[i]
	var is_current: bool = e.can_act() and e.to_act == i
	var panel: PanelContainer = n["panel"] as PanelContainer
	var style: StyleBoxFlat = UIKit.box(
		Color(0.06, 0.3, 0.17, 0.9) if is_current else Color(0, 0, 0, 0.3),
		14,
		UIKit.GOLD if is_current else Color(1, 1, 1, 0.08),
		2 if is_current else 1
	)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.4 if s.out else (0.6 if s.folded and not e.hand_over else 1.0)

	(n["stack"] as CoinLabel).set_amount(s.stack, true)
	(n["tag_box"] as Control).visible = s.label != "" and not s.out
	(n["tag"] as Label).text = s.label

	var in_hand: bool = not s.out and not s.hole.is_empty() and s.start_stack > 0
	var cards: CardRow = n["cards"] as CardRow
	cards.visible = in_hand and not s.folded
	if in_hand and not s.folded:
		var hidden: bool = not e.reveal
		cards.set_cards(s.hole, [hidden, hidden])

	var text: String = ""
	var color: Color = UIKit.TEXT_SOFT
	if s.out:
		text = "Éliminé"
	elif e.hand_over and in_hand:
		if s.net > 0:
			text = UIKit.signed(s.net)
			color = UIKit.GREEN_ACTION
		elif s.net < 0:
			text = str(s.net)
			color = UIKit.WARNING_TEXT
		else:
			text = "±0"
		if e.reveal and not s.folded:
			var d: String = e.describe_hand(i)
			if d != "":
				text += "\n" + d
	elif s.folded:
		text = "Couché"
	elif s.all_in:
		text = "Tapis"
		color = UIKit.GOLD
	elif s.bet > 0:
		text = "Mise %d" % s.bet
		color = Color.WHITE
	(n["status"] as Label).text = text
	(n["status"] as Label).add_theme_color_override("font_color", color)


func _refresh_result() -> void:
	var e: PokerTableEngine = engine
	_result_panel.visible = e.hand_over
	if not e.hand_over:
		_result_key = ""
		return
	var lines: Array[String] = e.result_lines.duplicate()
	for s: PokerTableEngine.Seat in e.seats:
		if s.out and s.start_stack > 0 and s.stack == 0:
			lines.append("%s est éliminé." % s.name)
	if e.is_game_over() and not e.aborted:
		var order: Array[int] = e.standings()
		lines.append("%s remporte la partie !" % e.seats[order[0]].name)
	_result_label.text = "\n".join(lines)
	_result_panel.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.WIN))
	var key: String = "%d/%s" % [e.hand_number, _result_label.text]
	if key != _result_key:
		_result_key = key
		UIKit.pop(_result_panel)


func _refresh_hole() -> void:
	var e: PokerTableEngine = engine
	var show: bool = e.can_act() and not e.runout and _unlocked_for == e.to_act
	_hole_box.visible = show
	if not show:
		return
	var s: PokerTableEngine.Seat = e.seats[e.to_act]
	_hole_title.text = "Vos cartes, %s" % s.name
	_hole_row.set_cards(s.hole)
	var d: String = e.describe_hand(e.to_act)
	_hint.visible = d != ""
	_hint.text = "Votre main : " + d


func _refresh_log() -> void:
	var lines: Array[String] = engine.log_lines
	_log_panel.visible = not lines.is_empty()
	for child: Node in _log_box.get_children():
		_log_box.remove_child(child)
		child.queue_free()
	var count: int = lines.size()
	for i: int in count:
		var age: int = count - 1 - i
		var fade: float = clampf(1.0 - age * 0.22, 0.25, 1.0)
		var line: Label = UIKit.label(
			lines[i], 12, Color(UIKit.TEXT_SOFT.r, UIKit.TEXT_SOFT.g, UIKit.TEXT_SOFT.b, fade)
		)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_log_box.add_child(line)


func _rebuild_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var e: PokerTableEngine = engine
	if e.hand_over:
		if e.is_game_over():
			var results: Button = UIKit.button("Voir le classement", UIKit.GOLD, UIKit.INK, 20)
			results.pressed.connect(_show_results)
			_actions.add_child(results)
		else:
			var next: Button = UIKit.button("Main suivante", UIKit.GOLD, UIKit.INK, 20)
			next.pressed.connect(_next_hand)
			_actions.add_child(next)
	elif e.runout:
		var wait: Label = UIKit.label("Le board se dévoile…", 16, UIKit.TEXT_SOFT)
		wait.custom_minimum_size = Vector2(0, 56)
		_actions.add_child(wait)
	elif e.can_act() and _unlocked_for == e.to_act:
		_actions.add_child(_build_player_actions())


func _build_player_actions() -> Control:
	var e: PokerTableEngine = engine
	var i: int = e.to_act
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var fold: Button = UIKit.button("Coucher", UIKit.DANGER)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold.pressed.connect(e.fold)
	row.add_child(fold)
	var call_text: String = "Checker"
	if not e.can_check(i):
		call_text = "Suivre %d" % e.to_call(i)
		if e.to_call(i) >= e.seats[i].stack:
			call_text += " (tapis)"
	var call_btn: Button = UIKit.button(call_text, UIKit.GREEN_ACTION)
	call_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_btn.pressed.connect(e.check_call)
	row.add_child(call_btn)
	col.add_child(row)

	if e.can_raise(i):
		col.add_child(_build_raise_panel())
	return col


func _build_raise_panel() -> Control:
	var e: PokerTableEngine = engine
	var i: int = e.to_act
	var lo: int = e.min_raise_to(i)
	var hi: int = e.max_raise_to(i)
	var opening: bool = e.current_bet == 0
	_raise_to = clampi(_raise_to, lo, hi)

	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 14, 10, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var raise_btn: Button = UIKit.button("", UIKit.GOLD, UIKit.INK, 18)
	col.add_child(raise_btn)
	var set_text: Callable = func() -> void:
		var verb: String = "Miser" if opening else "Relancer à"
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
		var half: int = e.current_bet + int(ceil((e.pot() + e.current_bet - e.seats[i].bet) / 2.0))
		var presets: Array[Array] = [["½ pot", half], ["Pot", e.pot_raise_to(i)], ["Tapis", hi]]
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

	raise_btn.pressed.connect(func() -> void: e.raise_to(_raise_to))
	return panel


# --- Événements et navigation -----------------------------------------------


func _on_cover_pressed() -> void:
	if not engine.can_act():
		return
	_unlocked_for = engine.to_act
	_refresh()


func _on_runout() -> void:
	engine.advance_street()


func _next_hand() -> void:
	engine.start_hand()
	_scroll.scroll_vertical = 0


func _on_quit_pressed() -> void:
	if _quit_armed:
		_show_results()
	else:
		_quit_armed = true
		_quit_button.text = "Confirmer ?"


func _show_results() -> void:
	if not engine.hand_over or not engine.is_game_over():
		engine.abort()  # rend les mises en cours
	var rows: Array[Dictionary] = []
	for i: int in engine.standings():
		var s: PokerTableEngine.Seat = engine.seats[i]
		rows.append({"name": s.name, "stack": s.stack, "start": LocalSession.chips})
	if engine.aborted:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["stack"]) > int(b["stack"]))
	LocalSession.store_results(rows)
	get_tree().change_scene_to_file(LocalSession.RESULTS_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_quit_pressed()
