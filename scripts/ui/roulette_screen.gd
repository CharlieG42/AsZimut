extends Control
## Écran Roulette européenne.

const HOME_SCENE: String = "res://scenes/home.tscn"
const CHIP_VALUES: Array[int] = [5, 10, 25, 100]
const RED: Color = Color(0.72, 0.1, 0.12)
const BLACK: Color = Color(0.1, 0.1, 0.12)
const GREEN: Color = Color(0.05, 0.45, 0.22)

var engine: RouletteEngine

var _bank: CoinLabel
var _result_chip: PanelContainer
var _result_label: Label
var _history_row: HBoxContainer
var _message_panel: PanelContainer
var _message_label: Label
var _controls: VBoxContainer
var _last_message: String = ""
var _felt_node: Control
var _chip_buttons: Dictionary = {}
## Animation de la bille en cours (le moteur a déjà tiré le numéro, l'écran le cache).
var _animating: bool = false
var _shown: int = -1
## Sans animation (tests) : résultat immédiat.
var skip_animation: bool = false
## Valeur du jeton sélectionné.
var chip: int = 10


func _ready() -> void:
	engine = RouletteEngine.new(Bankroll)
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

	var title: Label = UIKit.label("Roulette", 20, UIKit.GOLD, true)
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

	_result_chip = PanelContainer.new()
	_result_chip.custom_minimum_size = Vector2(96, 96)
	_result_label = UIKit.label("", 44, Color.WHITE, true)
	_result_chip.add_child(_result_label)
	var center: HBoxContainer = HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_result_chip)
	col.add_child(center)

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


func _color_for(n: int) -> Color:
	match RouletteEngine.color_of(n):
		"red":
			return RED
		"black":
			return BLACK
	return GREEN


func _refresh() -> void:
	# Pendant la rotation, la banque n'affiche pas encore le gain.
	_bank.set_amount(Bankroll.value - (engine.payout if _animating else 0), true)
	_show_number(_shown if _animating else engine.result)

	for child: Node in _history_row.get_children():
		_history_row.remove_child(child)
		child.queue_free()
	var past: Array[int] = engine.history.duplicate()
	if _animating and not past.is_empty():
		past.pop_back()
	for n: int in past:
		var dot: PanelContainer = PanelContainer.new()
		dot.custom_minimum_size = Vector2(30, 26)
		dot.add_theme_stylebox_override("panel", UIKit.box(_color_for(n), 8))
		dot.add_child(UIKit.label(str(n), 12, Color.WHITE, true))
		_history_row.add_child(dot)

	_message_panel.visible = engine.message != "" and not _animating
	_message_label.text = engine.message
	var kind: int = UIKit.Banner.NEUTRAL
	if engine.phase == RouletteEngine.Phase.DONE and not _animating:
		kind = UIKit.Banner.WIN if engine.net > 0 else (UIKit.Banner.LOSE if engine.net < 0 else UIKit.Banner.NEUTRAL)
	_message_panel.add_theme_stylebox_override("panel", UIKit.banner_style(kind))
	if engine.message != _last_message and not _animating:
		_last_message = engine.message
		if engine.message != "":
			UIKit.pop(_message_panel)

	_rebuild_controls()


func _show_number(n: int) -> void:
	var has_result: bool = n >= 0
	_result_chip.add_theme_stylebox_override(
		"panel", UIKit.box(_color_for(n) if has_result else Color(0, 0, 0, 0.35), 48, UIKit.GOLD, 3)
	)
	_result_label.text = str(n) if has_result else "?"


func _spin() -> void:
	if not engine.can_spin():
		return
	_animating = not skip_animation
	_shown = engine.result
	engine.spin()


## La bille ralentit : les numéros défilent de plus en plus lentement jusqu'au résultat.
func _animate_spin() -> void:
	var ticks: int = 16
	var last: int = -1
	for i: int in ticks:
		var n: int = engine.rng.randi_range(0, 36)
		while n == last or n == engine.result:
			n = engine.rng.randi_range(0, 36)
		last = n
		_shown = n
		_show_number(n)
		SfxPlayer.play("chip", -14.0)
		await get_tree().create_timer(0.03 + i * 0.011).timeout
		if not is_inside_tree():
			return
	_shown = engine.result
	_show_number(engine.result)


func _on_round_finished(net: int) -> void:
	if _animating:
		await _animate_spin()
		if not is_inside_tree():
			return
		_animating = false
		_refresh()
		UIKit.pop(_result_chip)
	if net > 0:
		ChipFly.fly(_felt_node, _bank, net)
	elif net < 0:
		ChipFly.fly_away(_felt_node, -net)
	var straight_hit: bool = engine.bet_on("n:%d" % engine.result) > 0
	Stats.record_roulette(net, straight_hit)
	ProfileStore.record_active("ro", net > 0, net)
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
	if _animating:
		var wait: Label = UIKit.label("La bille tourne…", 18, UIKit.TEXT_SOFT)
		wait.custom_minimum_size = Vector2(0, 80)
		_controls.add_child(wait)
	elif engine.phase == RouletteEngine.Phase.BET:
		_controls.add_child(_build_bet_panel())
	else:
		_controls.add_child(_build_recap())
		var again: Button = UIKit.button("Rejouer", UIKit.GOLD, UIKit.INK, 20)
		again.pressed.connect(engine.replay)
		_controls.add_child(again)


func _build_recap() -> Control:
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 12, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var keys: Array = engine.bets.keys()
	keys.sort()
	for key: Variant in keys:
		var k: String = str(key)
		var o: int = RouletteEngine.odds(k, engine.result)
		var amount: int = engine.bet_on(k)
		var line: Label = UIKit.label(
			"%s · %d  →  %s" % [RouletteEngine.bet_label(k), amount, ("+%d" % (amount * o)) if o > 0 else "-%d" % amount],
			14, UIKit.GREEN_ACTION if o > 0 else UIKit.TEXT_SOFT
		)
		col.add_child(line)
	return panel


func _build_bet_panel() -> Control:
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 12, Color(1, 1, 1, 0.08))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	for v: int in CHIP_VALUES:
		var b: ChipButton = ChipButton.new(v)
		b.modulate.a = 1.0 if v == chip else 0.4
		_chip_buttons[v] = b
		b.pressed.connect(_select_chip.bind(v))
		chips.add_child(b)
	col.add_child(chips)
	col.add_child(UIKit.label("Jeton choisi : %d — touchez le tapis pour miser" % chip, 12, UIKit.TEXT_SOFT))

	col.add_child(_cell("0", "n:0", GREEN, 40))

	var heads: GridContainer = GridContainer.new()
	heads.columns = 3
	heads.add_theme_constant_override("h_separation", 4)
	heads.add_theme_constant_override("v_separation", 4)
	for c: int in range(1, 4):
		heads.add_child(_cell("Colonne %d (2:1)" % c, "col:%d" % c, Color(0.2, 0.33, 0.28), 36, 11))
	col.add_child(heads)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for n: int in range(1, 37):
		var c: Color = RED if RouletteEngine.is_red(n) else BLACK
		grid.add_child(_cell(str(n), "n:%d" % n, c, 38))
	col.add_child(grid)

	var doz: HBoxContainer = HBoxContainer.new()
	doz.add_theme_constant_override("separation", 4)
	for d: int in range(1, 4):
		doz.add_child(_cell("Douzaine %d" % d, "dozen:%d" % d, Color(0.2, 0.33, 0.28), 40, 12))
	col.add_child(doz)

	for pair: Array in [[["Rouge", "red", RED], ["Noir", "black", BLACK]], [["Pair", "even", Color(0.2, 0.33, 0.28)], ["Impair", "odd", Color(0.2, 0.33, 0.28)]], [["1-18", "low", Color(0.2, 0.33, 0.28)], ["19-36", "high", Color(0.2, 0.33, 0.28)]]]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for item: Array in pair:
			row.add_child(_cell(str(item[0]), str(item[1]), item[2] as Color, 40, 14))
		col.add_child(row)

	var total: Label = UIKit.label("Mise totale : %d" % engine.total_bet(), 15, UIKit.GOLD, true)
	col.add_child(total)

	var clear: Button = UIKit.outline_button("Effacer les mises", UIKit.TEXT_SOFT, 14)
	clear.custom_minimum_size = Vector2(0, 40)
	clear.visible = not engine.bets.is_empty()
	clear.pressed.connect(engine.clear_bets)
	col.add_child(clear)

	if Stats.beginner:
		col.add_child(UIKit.advice_panel(
			"La roulette est un jeu de pur hasard : aucune stratégie ne bat la banque (la case 0 lui donne 2,7 % d'avantage). Les chances simples perdent le moins souvent, un plein paie 35 contre 1."
		))

	var spin: Button = UIKit.button("Lancer la bille", UIKit.GOLD, UIKit.INK, 20)
	spin.disabled = not engine.can_spin()
	spin.pressed.connect(_spin)
	col.add_child(spin)
	if Bankroll.value < RouletteEngine.MIN_BET:
		var warn: Label = UIKit.label("Banque insuffisante — rechargez-la depuis l'accueil.", 12, UIKit.WARNING_TEXT)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	return panel


## Case du tapis : touche pour miser le jeton choisi ; le montant déjà misé s'affiche.
func _cell(text: String, key: String, bg: Color, height: int, font: int = 15) -> Button:
	var amount: int = engine.bet_on(key)
	var b: Button = Button.new()
	b.text = text if amount == 0 else "%s\n● %d" % [text, amount]
	b.custom_minimum_size = Vector2(0, height + (14 if amount > 0 else 0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_font_override("font", UIKit.bold_font())
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, Color.WHITE if amount == 0 else UIKit.GOLD)
	var border: Color = UIKit.GOLD if amount > 0 else Color(1, 1, 1, 0.25)
	var style: StyleBoxFlat = UIKit.box(bg, 8, border, 2 if amount > 0 else 1)
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(style_name, style)
	b.pressed.connect(_on_cell.bind(b, key))
	return b


func _on_cell(cell: Control, key: String) -> void:
	ChipFly.fly(_chip_buttons.get(chip) as Control, cell, chip, 2)
	engine.add_bet(key, chip)


func _select_chip(v: int) -> void:
	chip = v
	_rebuild_controls()


func _open_help() -> void:
	var overlay: HelpOverlay = HelpOverlay.open(self, HelpContent.Topic.ROULETTE)
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
