extends Control
## Options : réglages, statistiques et succès, répartis en onglets sous un en-tête fixe.

const HOME_SCENE: String = "res://scenes/home.tscn"
const TABS: Array[String] = ["Réglages", "Statistiques", "Succès"]
enum Tab { SETTINGS, STATS, ACHIEVEMENTS }

## Onglet affiché (mémorisé pendant la session).
static var tab: int = Tab.SETTINGS

var _content: VBoxContainer
var _scroll: TouchScroll
var _tabs: HBoxContainer
var _confirm_reset: bool = false


func _ready() -> void:
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top"]:
		margin.add_theme_constant_override(side, 16)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var frame: VBoxContainer = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)

	# En-tête fixe : retour, titre, onglets.
	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)
	var title: Label = UIKit.label("Options", 22, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	frame.add_child(bar)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	frame.add_child(_tabs)

	_scroll = TouchScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_scroll)

	# Petite marge à droite : la barre de défilement ne chevauche pas les cadres.
	var inner: MarginContainer = MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_right", 8)
	_scroll.add_child(inner)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	inner.add_child(_content)

	Stats.changed.connect(_rebuild)
	Bankroll.changed.connect(_rebuild)
	_build_tabs()
	_rebuild()
	UIKit.fade_in(self)


func _build_tabs() -> void:
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for i: int in TABS.size():
		var b: Button = (
			UIKit.button(TABS[i], UIKit.GOLD, UIKit.INK, 15)
			if i == tab
			else UIKit.outline_button(TABS[i], Color.WHITE, 15)
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_select_tab.bind(i))
		_tabs.add_child(b)


func _select_tab(i: int) -> void:
	if i == tab:
		_scroll.jump_to(0)
		return
	tab = i
	_confirm_reset = false
	_build_tabs()
	_rebuild()
	_scroll.jump_to(0)


## Reconstruit le contenu de l'onglet. Les nouveaux éléments sont ajoutés avant de retirer les anciens :
## la page garde sa hauteur pendant l'échange et la position de défilement ne saute pas.
func _rebuild() -> void:
	var old: Array[Node] = _content.get_children()
	match tab:
		Tab.STATS:
			_build_stats()
		Tab.ACHIEVEMENTS:
			_build_achievements()
		_:
			_build_settings()
	_content.add_child(UIKit.spacer(12))
	for child: Node in old:
		_content.remove_child(child)
		child.queue_free()


func _build_settings() -> void:
	var game: VBoxContainer = _section("Jeu")
	game.add_child(_small("Niveau de ZIA"))
	var levels: HBoxContainer = HBoxContainer.new()
	levels.add_theme_constant_override("separation", 8)
	for i: int in PokerEngine.PROFILES.size():
		var selected: bool = i == Stats.difficulty
		var b: Button = (
			UIKit.button(PokerEngine.difficulty_name(i), UIKit.GOLD, UIKit.INK, 16)
			if selected
			else UIKit.outline_button(PokerEngine.difficulty_name(i), Color.WHITE, 16)
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(Stats.set_difficulty.bind(i))
		levels.add_child(b)
	game.add_child(levels)
	game.add_child(_small("Appliqué à la prochaine partie de poker."))
	game.add_child(_switch("Vibrations", Stats.haptics, Stats.set_haptics))
	game.add_child(_switch("Sons", Stats.sound, Stats.set_sound))

	var help: VBoxContainer = _section("Aide")
	var beginner_box: CheckBox = UIKit.check("Mode débutant (conseils pendant la partie)", Stats.beginner)
	beginner_box.toggled.connect(Stats.set_beginner)
	help.add_child(beginner_box)
	var tuto_box: CheckBox = UIKit.check("Afficher le tutoriel au démarrage", Stats.show_tutorial)
	tuto_box.toggled.connect(Stats.set_show_tutorial)
	help.add_child(tuto_box)
	var replay: Button = UIKit.outline_button("Revoir le tutoriel", UIKit.GOLD, 16)
	replay.custom_minimum_size = Vector2(0, 48)
	replay.pressed.connect(_replay_tutorial)
	help.add_child(replay)

	var who: String = ProfileStore.active_name()
	var players: VBoxContainer = _section("Joueurs enregistrés · %d" % ProfileStore.count())
	players.add_child(_small("Joueur actif en solo : %s" % (who if who != "" else "invité")))
	var pl: Button = UIKit.outline_button("Voir la progression des joueurs", UIKit.GOLD, 16)
	pl.custom_minimum_size = Vector2(0, 48)
	pl.pressed.connect(func() -> void:
		ProfilesScreen.return_scene = "res://scenes/stats.tscn"
		get_tree().change_scene_to_file(ProfilesScreen.SCENE)
	)
	players.add_child(pl)

	var backup: VBoxContainer = _section("Sauvegarde des données")
	var bk: Button = UIKit.outline_button("Exporter / importer", UIKit.GOLD, 16)
	bk.custom_minimum_size = Vector2(0, 48)
	bk.pressed.connect(func() -> void: get_tree().change_scene_to_file(BackupScreen.SCENE))
	backup.add_child(bk)

	_content.add_child(UIKit.label("AsZimut v%s" % AppInfo.version(), 12, UIKit.TEXT_SOFT))


func _build_stats() -> void:
	var bank_box: VBoxContainer = _section("Banque")
	_row(bank_box, "Actuelle", str(Bankroll.value))
	_row(bank_box, "Record", str(Bankroll.best))
	bank_box.add_child(_small("Évolution (dernières manches en solo)"))
	bank_box.add_child(BankChart.new(Stats.bank_history))

	var bj: VBoxContainer = _section("Blackjack")
	_row(bj, "Parties", str(Stats.bj_rounds))
	_row(bj, "Victoires", "%d  (%d %%)" % [Stats.bj_wins, StatsState.percent(Stats.bj_wins, Stats.bj_rounds)])
	_row(bj, "Défaites", str(Stats.bj_losses))
	_row(bj, "Égalités", str(Stats.bj_pushes))
	_row(bj, "Blackjacks", str(Stats.bj_blackjacks))
	_row(bj, "Gain net", UIKit.signed(Stats.bj_net), _net_color(Stats.bj_net))

	var pk: VBoxContainer = _section("Poker")
	_row(pk, "Mains", str(Stats.pk_hands))
	_row(pk, "Victoires", "%d  (%d %%)" % [Stats.pk_wins, StatsState.percent(Stats.pk_wins, Stats.pk_hands)])
	_row(pk, "Défaites", str(Stats.pk_losses))
	_row(pk, "Parts égales", str(Stats.pk_splits))
	_row(pk, "Plus gros pot gagné", str(Stats.pk_biggest_pot))
	_row(pk, "Gain net", UIKit.signed(Stats.pk_net), _net_color(Stats.pk_net))

	var du: VBoxContainer = _section("Dutch (contre ZIA)")
	_row(du, "Parties", str(Stats.du_games))
	_row(du, "Victoires", "%d  (%d %%)" % [Stats.du_wins, StatsState.percent(Stats.du_wins, Stats.du_games)])
	_row(du, "Manches gagnées", "%d / %d" % [Stats.du_round_wins, Stats.du_rounds])
	_row(du, "Annonces DUTCH réussies", "%d / %d" % [Stats.du_call_wins, Stats.du_calls])
	_row(du, "Meilleure main", "—" if Stats.du_best_hand >= 99 else "%d pts" % Stats.du_best_hand)

	var reset_text: String = "Confirmer l'effacement ?" if _confirm_reset else "Réinitialiser les stats"
	var reset: Button = UIKit.outline_button(
		reset_text, UIKit.DANGER if _confirm_reset else UIKit.WARNING_TEXT, 15
	)
	reset.custom_minimum_size = Vector2(0, 48)
	reset.pressed.connect(_on_reset)
	_content.add_child(reset)


func _build_achievements() -> void:
	var ach: VBoxContainer = _section("Succès · %d / %d" % [Stats.achievements.size(), StatsState.ACHIEVEMENTS.size()])
	# Débloqués d'abord, puis ceux qui restent à obtenir.
	for done: bool in [true, false]:
		for a: Array in StatsState.ACHIEVEMENTS:
			if Stats.has_achievement(str(a[0])) == done:
				ach.add_child(_achievement_row(a, done))


func _small(text: String) -> Label:
	var l: Label = UIKit.label(text, 13, UIKit.TEXT_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _switch(text: String, on: bool, setter: Callable) -> CheckButton:
	var box: CheckButton = CheckButton.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.custom_minimum_size = Vector2(0, 44)
	box.add_theme_font_size_override("font_size", 16)
	box.toggled.connect(setter)
	return box


func _section(title: String) -> VBoxContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	var head: Label = UIKit.label(title.to_upper(), 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	_content.add_child(p)
	return box


func _row(parent: VBoxContainer, name_text: String, value_text: String, color: Color = Color.WHITE) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var n: Label = UIKit.label(name_text, 15, UIKit.TEXT_SOFT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v: Label = UIKit.label(value_text, 15, color, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	parent.add_child(row)


func _achievement_row(a: Array, done: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(30, 30)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(
		"panel", UIKit.box(UIKit.GOLD if done else Color(1, 1, 1, 0.06), 15, Color(1, 1, 1, 0.15), 1)
	)
	badge.add_child(UIKit.label("★" if done else "?", 15, UIKit.INK if done else UIKit.TEXT_SOFT, true))
	row.add_child(badge)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var t: Label = UIKit.label(str(a[1]), 15, Color.WHITE if done else UIKit.TEXT_SOFT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(t)
	var d: Label = UIKit.label(str(a[2]), 12, UIKit.TEXT_SOFT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	row.add_child(col)
	if not done:
		row.modulate.a = 0.6
	return row


func _net_color(net: int) -> Color:
	if net > 0:
		return UIKit.GREEN_ACTION
	if net < 0:
		return UIKit.WARNING_TEXT
	return Color.WHITE


func _replay_tutorial() -> void:
	TutorialScreen.return_scene = "res://scenes/stats.tscn"
	get_tree().change_scene_to_file(TutorialScreen.TUTORIAL_SCENE)


func _on_reset() -> void:
	if _confirm_reset:
		_confirm_reset = false
		Stats.reset_stats()
	else:
		_confirm_reset = true
		_rebuild()


func _go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
