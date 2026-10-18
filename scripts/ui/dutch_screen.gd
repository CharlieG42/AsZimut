extends Control
## Dutch : seul contre ZIA ou à plusieurs sur le même appareil (avec passage d'appareil).
## Les cartes que le joueur connaît sont affichées face visible (pastille dorée).

const BOT_DELAY: float = 1.0
const MAX_NAME: int = 12

var engine: DutchEngine

var _scroll: ScrollContainer
var _body: VBoxContainer
var _quit_button: Button
var _quit_armed: bool = false
var _title: Label
var _cover: Control
var _cover_name: Label
var _cover_info: Label
var _cover_button: Button
var _bot_timer: Timer
var _unlocked_for: int = -1
## Carte à soi choisie pour l'échange aveugle (-1 si aucune).
var _selected_own: int = -1
var _last_phase_key: String = ""


func _ready() -> void:
	_bot_timer = Timer.new()
	_bot_timer.one_shot = true
	_bot_timer.wait_time = BOT_DELAY
	_bot_timer.timeout.connect(_on_bot_timer)
	add_child(_bot_timer)

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
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	col.add_child(_body)
	_build_cover()

	var names: Array[String] = []
	var flags: Array[bool] = []
	if LocalSession.solo:
		names = ["Vous", "ZIA"]
		flags = [false, true]
	else:
		names = LocalSession.player_names()
		flags = LocalSession.bot_flags()
	engine = DutchEngine.new()
	engine.target = LocalSession.dutch_target
	engine.changed.connect(_refresh)
	engine.setup(names, flags, Stats.difficulty)


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_quit_button = UIKit.outline_button("‹ Terminer", UIKit.TEXT_SOFT, 15)
	_quit_button.custom_minimum_size = Vector2(110, 44)
	_quit_button.pressed.connect(_on_quit_pressed)
	bar.add_child(_quit_button)
	_title = UIKit.label("Dutch", 18, UIKit.GOLD, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	var help: Button = UIKit.help_button()
	help.pressed.connect(_open_help)
	bar.add_child(help)
	return bar


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
	_cover_info = UIKit.label("", 14, Color(0.9, 0.97, 0.93))
	_cover_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_cover_info)
	var warn: Label = UIKit.label("Les autres joueurs ne doivent pas voir l'écran.", 13, UIKit.TEXT_SOFT)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(warn)
	col.add_child(UIKit.spacer(10))
	_cover_button = UIKit.button("", UIKit.GOLD, UIKit.INK, 20)
	_cover_button.pressed.connect(_on_cover_pressed)
	col.add_child(_cover_button)
	_cover.visible = false


# --- Affichage ---------------------------------------------------------------


func _humans() -> Array[int]:
	var out: Array[int] = []
	for p: int in engine.n:
		if not engine.bots[p]:
			out.append(p)
	return out


func _interactive_phase() -> bool:
	return engine.phase in [
		DutchEngine.Phase.TURN, DutchEngine.Phase.HELD, DutchEngine.Phase.POWER, DutchEngine.Phase.KING_DECIDE
	]


## Joueur dont on montre les cartes connues ; -1 si personne ne doit les voir.
func _viewer() -> int:
	if engine.round_is_over():
		return -1
	var humans: Array[int] = _humans()
	if humans.size() == 1:
		return humans[0]
	if not engine.current_is_bot() and _unlocked_for == engine.current:
		return engine.current
	return -1


func _acting_human() -> bool:
	return _interactive_phase() and not engine.current_is_bot() and _viewer() == engine.current


func _refresh() -> void:
	_quit_armed = false
	_quit_button.text = "‹ Terminer"
	var key: String = "%d/%d/%d" % [engine.round_number, engine.current, engine.phase]
	if key != _last_phase_key:
		_selected_own = -1
		_last_phase_key = key
		_phase_sound()
	if not _interactive_phase() or engine.current_is_bot():
		_unlocked_for = -1
	_title.text = "Dutch · manche %d · jusqu'à %d" % [engine.round_number, engine.target]

	var needs_cover: bool = (
		_humans().size() > 1
		and _interactive_phase()
		and not engine.current_is_bot()
		and _unlocked_for != engine.current
	)
	if needs_cover:
		if not _cover.visible:
			UIKit.haptic(Stats.haptics, 45)
			SfxPlayer.play("alert", -6.0)
		_cover_name.text = engine.names[engine.current]
		_cover_info.text = engine.message
		_cover_button.text = "Je suis %s" % engine.names[engine.current]
	_cover.visible = needs_cover

	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if engine.round_is_over():
		_build_round_over()
	else:
		_build_table()
	if engine.awaiting_bot() and _bot_timer.is_stopped():
		_bot_timer.start()


func _phase_sound() -> void:
	match engine.phase:
		DutchEngine.Phase.ROUND_OVER, DutchEngine.Phase.MATCH_OVER:
			var human_won: bool = false
			for w: int in engine.round_winners:
				if not engine.bots[w]:
					human_won = true
			SfxPlayer.play("win" if human_won or _humans().size() > 1 else "lose")
		_:
			if engine.dutch_caller >= 0 and engine.turns_left == engine.n - 1 and engine.phase == DutchEngine.Phase.TURN:
				SfxPlayer.play("alert")
			else:
				SfxPlayer.play("card", -4.0)


func _build_table() -> void:
	var viewer: int = _viewer()
	_body.add_child(_build_scores())

	var banner: PanelContainer = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.NEUTRAL))
	var text: Label = UIKit.label(_status_text(), 16, UIKit.GOLD, true)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(text)
	_body.add_child(banner)

	var others: Array[int] = []
	for p: int in engine.n:
		if p != viewer:
			others.append(p)
	_body.add_child(_build_others(others, viewer))
	_body.add_child(_build_center(viewer))

	if viewer >= 0:
		var mine: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.28), 16, 10, Color(1, 1, 1, 0.1))
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		mine.add_child(box)
		var label_text: String = "Vos cartes · %s" % engine.names[viewer] if _humans().size() > 1 else "Vos cartes"
		box.add_child(UIKit.label(label_text, 13, UIKit.TEXT_SOFT))
		box.add_child(_hand_row(viewer, viewer, 1.1))
		_body.add_child(mine)

	if Stats.beginner and _acting_human():
		_body.add_child(UIKit.advice_panel(engine.advice()))
	_body.add_child(_build_actions())


func _status_text() -> String:
	if engine.current_is_bot():
		return "%s réfléchit… %s" % [engine.names[engine.current], engine.message if engine.message != "" else ""]
	if _acting_human():
		match engine.phase:
			DutchEngine.Phase.TURN:
				return "À vous, %s : piochez ou prenez la défausse." % engine.names[engine.current] if _humans().size() > 1 else "À vous : piochez ou prenez la défausse."
			DutchEngine.Phase.HELD:
				return "Touchez la carte à remplacer, ou défaussez."
			DutchEngine.Phase.POWER:
				return _power_instruction()
			DutchEngine.Phase.KING_DECIDE:
				return "Roi : touchez l'une de vos cartes pour échanger, ou gardez."
	return engine.message


func _power_instruction() -> String:
	match engine.power:
		DutchEngine.Power.PEEK_OWN:
			return "Pouvoir : touchez l'une de vos cartes pour la regarder."
		DutchEngine.Power.PEEK_OTHER:
			return "Pouvoir : touchez une carte d'un adversaire pour la regarder."
		DutchEngine.Power.SWAP_BLIND:
			if _selected_own < 0:
				return "Échange : touchez d'abord l'une de vos cartes."
			return "Échange : touchez maintenant la carte d'un adversaire."
		DutchEngine.Power.KING:
			return "Roi noir : touchez n'importe quelle carte pour la regarder."
	return ""


func _build_scores() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for p: int in engine.n:
		var active: bool = p == engine.current and _interactive_phase()
		var chip: PanelContainer = UIKit.chip("%s  %d" % [_short(engine.names[p]), engine.totals[p]], 12)
		var style: StyleBoxFlat = UIKit.box(
			Color(0.3, 0.22, 0.04, 0.9) if active else Color(0, 0, 0, 0.35), 12,
			UIKit.GOLD if active else Color(1, 1, 1, 0.12), 2 if active else 1
		)
		style.set_content_margin_all(5)
		chip.add_theme_stylebox_override("panel", style)
		row.add_child(chip)
	return row


func _short(name: String) -> String:
	return name if name.length() <= 9 else name.substr(0, 8) + "…"


func _build_others(others: Array[int], viewer: int) -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 1 if others.size() == 1 else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var card_scale: float = 0.85 if others.size() == 1 else (0.7 if others.size() == 2 else 0.58)
	for p: int in others:
		var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.28), 14, 8, Color(1, 1, 1, 0.1))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		var tag: String = "  (ZIA)" if engine.bots[p] and not engine.names[p].begins_with("ZIA") else ""
		box.add_child(UIKit.label(_short(engine.names[p]) + tag, 13, UIKit.GOLD if p == engine.current else Color.WHITE, true))
		box.add_child(_hand_row(p, viewer, card_scale))
		grid.add_child(panel)
	return grid


## Rangée de 4 cartes de `owner`, vues par `viewer` (-1 : personne).
func _hand_row(owner: int, viewer: int, card_scale: float) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	for s: int in DutchEngine.HAND_SIZE:
		var is_known: bool = viewer >= 0 and engine.knows(viewer, owner, s)
		var card: int = engine.hands[owner][s]
		var tappable: bool = _tappable(owner, s, viewer)
		var highlight: bool = tappable or (owner == viewer and _selected_own == s)
		if engine.phase == DutchEngine.Phase.KING_DECIDE and engine.king_target == Vector2i(owner, s):
			highlight = true
		var btn: CardButton = CardButton.new(card_scale, card, not is_known, highlight, is_known)
		if tappable:
			btn.pressed.connect(_on_card.bind(owner, s))
		else:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(btn)
	return row


func _tappable(owner: int, slot: int, viewer: int) -> bool:
	if not _acting_human() or viewer != engine.current:
		return false
	var me: bool = owner == engine.current
	match engine.phase:
		DutchEngine.Phase.HELD:
			return me
		DutchEngine.Phase.KING_DECIDE:
			return me
		DutchEngine.Phase.POWER:
			match engine.power:
				DutchEngine.Power.PEEK_OWN:
					return me
				DutchEngine.Power.PEEK_OTHER:
					return not me
				DutchEngine.Power.SWAP_BLIND:
					return me if _selected_own < 0 else (not me or slot == _selected_own)
				DutchEngine.Power.KING:
					return true
	return false


func _build_center(viewer: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	row.add_child(_pile("Pioche · %d" % engine.draw_pile.size(), CardView.new(1.0), -1, true))
	var top: int = engine.top_discard()
	row.add_child(_pile("Défausse", null, top, false))
	if engine.phase == DutchEngine.Phase.HELD:
		var visible_held: bool = viewer == engine.current or engine.held_from_discard
		row.add_child(_pile("En main", null, engine.held, not visible_held))
	return UIKit.table(row, 12)


func _pile(title: String, _unused: CardView, card: int, face_down: bool) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var view: CardView = CardView.new(1.0)
	if card >= 0:
		view.show_card(card, face_down)
	elif face_down:
		view.show_card(0, true)
	else:
		view.show_empty()
	box.add_child(view)
	box.add_child(UIKit.label(title, 12, Color(0.85, 0.95, 0.9)))
	return box


func _build_actions() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	if not _acting_human():
		return col
	match engine.phase:
		DutchEngine.Phase.TURN:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var draw: Button = UIKit.button("Piocher", UIKit.GOLD, UIKit.INK, 18)
			draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			draw.pressed.connect(engine.draw_from_deck)
			row.add_child(draw)
			var take: Button = UIKit.button(
				"Prendre la défausse (%s = %d)" % [Cards.rank_label(engine.top_discard()), DutchEngine.card_points(engine.top_discard())],
				Color(0.16, 0.36, 0.28), Color.WHITE, 15
			)
			take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			take.pressed.connect(engine.take_discard)
			row.add_child(take)
			col.add_child(row)
			if engine.can_call_dutch():
				var dutch: Button = UIKit.outline_button("Annoncer DUTCH", UIKit.GREEN_ACTION, 17)
				dutch.pressed.connect(engine.call_dutch)
				col.add_child(dutch)
		DutchEngine.Phase.HELD:
			if not engine.held_from_discard:
				var discard: Button = UIKit.button("Défausser cette carte", Color(0.16, 0.36, 0.28), Color.WHITE, 17)
				discard.pressed.connect(engine.discard_held)
				col.add_child(discard)
		DutchEngine.Phase.POWER:
			var skip: Button = UIKit.outline_button("Renoncer au pouvoir", UIKit.TEXT_SOFT, 16)
			skip.pressed.connect(engine.skip_power)
			col.add_child(skip)
		DutchEngine.Phase.KING_DECIDE:
			var keep: Button = UIKit.button("Garder, ne pas échanger", Color(0.16, 0.36, 0.28), Color.WHITE, 17)
			keep.pressed.connect(engine.keep_king)
			col.add_child(keep)
	return col


func _build_round_over() -> void:
	var final: bool = engine.phase == DutchEngine.Phase.MATCH_OVER
	var banner: PanelContainer = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UIKit.banner_style(UIKit.Banner.WIN if final else UIKit.Banner.NEUTRAL))
	var text: Label = UIKit.label(
		("Partie terminée ! " if final else "") + engine.message, 16, UIKit.GOLD, true
	)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(text)
	_body.add_child(banner)

	for p: int in engine.n:
		var winner: bool = engine.round_winners.has(p)
		var panel: PanelContainer = UIKit.panel(
			Color(0.06, 0.3, 0.17, 0.9) if winner else Color(0, 0, 0, 0.3), 14, 10,
			Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.8) if winner else Color(1, 1, 1, 0.1)
		)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		var head: HBoxContainer = HBoxContainer.new()
		var name_label: Label = UIKit.label(
			"%s%s" % [engine.names[p], "  · DUTCH" if p == engine.dutch_caller else ""], 15, Color.WHITE, true
		)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(
			UIKit.label(
				"%d pts  →  total %d" % [engine.hand_total(p), engine.totals[p]], 13,
				UIKit.GOLD if winner else UIKit.TEXT_SOFT
			)
		)
		box.add_child(head)
		var cards: Array[int] = []
		for c: int in engine.hands[p]:
			cards.append(c)
		var cr: CardRow = CardRow.new(0.62, 4)
		cr.set_cards(cards)
		box.add_child(cr)
		var gained: int = engine.round_points[p]
		box.add_child(UIKit.label("Manche : +%d" % gained, 12, UIKit.GREEN_ACTION if gained == 0 else UIKit.WARNING_TEXT))
		_body.add_child(panel)

	var next: Button = UIKit.button(
		"Voir le classement" if final else "Manche suivante", UIKit.GOLD, UIKit.INK, 20
	)
	next.pressed.connect(_show_results if final else engine.start_round)
	_body.add_child(next)


# --- Événements --------------------------------------------------------------


func _on_card(owner: int, slot: int) -> void:
	if not _acting_human():
		return
	match engine.phase:
		DutchEngine.Phase.HELD:
			engine.swap_held(slot)
		DutchEngine.Phase.KING_DECIDE:
			engine.king_swap(slot)
		DutchEngine.Phase.POWER:
			match engine.power:
				DutchEngine.Power.PEEK_OWN:
					engine.use_peek_own(slot)
				DutchEngine.Power.PEEK_OTHER:
					engine.use_peek_other(owner, slot)
				DutchEngine.Power.SWAP_BLIND:
					if _selected_own < 0:
						_selected_own = slot
						_refresh()
					elif owner == engine.current:
						_selected_own = slot
						_refresh()
					else:
						engine.use_swap_blind(_selected_own, owner, slot)
				DutchEngine.Power.KING:
					engine.use_king_look(owner, slot)


func _on_bot_timer() -> void:
	if engine.awaiting_bot():
		engine.bot_step()


func _on_cover_pressed() -> void:
	if not _interactive_phase() or engine.current_is_bot():
		return
	_unlocked_for = engine.current
	_refresh()


func _open_help() -> void:
	var overlay: HelpOverlay = HelpOverlay.open(self, HelpContent.Topic.DUTCH)
	overlay.closed.connect(_refresh)


func _on_quit_pressed() -> void:
	if _quit_armed or engine.phase == DutchEngine.Phase.MATCH_OVER:
		_show_results()
	else:
		_quit_armed = true
		_quit_button.text = "Confirmer ?"


func _show_results() -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in engine.ranking():
		rows.append({"name": r["name"], "stack": r["score"], "start": 0, "unit": "pts"})
	LocalSession.store_results(rows)
	get_tree().change_scene_to_file(LocalSession.RESULTS_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if HelpOverlay.is_open(self):
			HelpOverlay.close_in(self)
		else:
			_on_quit_pressed()
