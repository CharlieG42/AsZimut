extends Control
## Préparation d'une partie multijoueur locale : jeu, nombre de joueurs, noms, jetons.

var _content: VBoxContainer


func _ready() -> void:
	LocalSession.solo = false
	LocalSession.solo_poker = false
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_rebuild()
	UIKit.fade_in(self)


func _rebuild() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)
	var title: Label = UIKit.label("Multijoueur local", 21, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	_content.add_child(bar)

	var intro: Label = UIKit.label(
		"Un seul appareil, hors ligne : on se passe le téléphone à chaque tour.", 13, UIKit.TEXT_SOFT
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	# Jeu
	var game_box: VBoxContainer = _section("Jeu")
	var games: Array[String] = ["Blackjack", "Poker", "Dutch"]
	game_box.add_child(_segment(games, LocalSession.game, _on_game))
	var desc_text: String = "Texas Hold'em entre joueurs, avec pots annexes. Blinds croissantes."
	if LocalSession.game == LocalSession.Game.BLACKJACK:
		desc_text = "Chacun joue contre le croupier avec sa propre pile."
	elif LocalSession.game == LocalSession.Game.DUTCH:
		desc_text = "Jeu de mémoire : le moins de points gagne. Annoncez DUTCH au bon moment !"
	var desc: Label = UIKit.label(desc_text, 12, UIKit.TEXT_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_box.add_child(desc)

	# Joueurs enregistrés : groupes récents et carnet
	if ProfileStore.count() > 0:
		var saved_box: VBoxContainer = _section("Joueurs enregistrés")
		var groups: Array[Array] = ProfileStore.recent_groups()
		if not groups.is_empty():
			saved_box.add_child(_small("Rejouer avec un groupe récent :"))
			for g: Array in groups:
				var gb: Button = UIKit.outline_button(ProfileStore.group_label(g), UIKit.GOLD, 15)
				gb.custom_minimum_size = Vector2(0, 44)
				gb.clip_text = true
				gb.pressed.connect(_use_group.bind(g))
				saved_box.add_child(gb)
		saved_box.add_child(_small("Touchez un joueur pour l'ajouter ou le retirer :"))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for prof: Dictionary in ProfileStore.profiles():
			var pid: String = str(prof["id"])
			var seated: bool = _seat_of(pid) >= 0
			var chip_text: String = str(prof["name"])
			if LocalSession.use_banks and LocalSession.game != LocalSession.Game.DUTCH:
				chip_text += "  %d" % ProfileStore.playable_bank(pid)
			var pb: Button = (
				UIKit.button(chip_text, UIKit.GOLD, UIKit.INK, 15)
				if seated
				else UIKit.outline_button(chip_text, Color.WHITE, 15)
			)
			pb.custom_minimum_size = Vector2(0, 42)
			pb.pressed.connect(_toggle_profile.bind(pid))
			flow.add_child(pb)
		saved_box.add_child(flow)
		var manage: Button = UIKit.outline_button("Gérer les joueurs", UIKit.TEXT_SOFT, 14)
		manage.custom_minimum_size = Vector2(0, 40)
		manage.pressed.connect(_open_profiles)
		saved_box.add_child(manage)

	# Joueurs
	var players_box: VBoxContainer = _section("Joueurs")
	players_box.add_child(_stepper())
	for i: int in LocalSession.count:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var is_bot: bool = LocalSession.bots[i]
		var pid: String = LocalSession.profile_ids[i]
		if not is_bot and ProfileStore.exists(pid):
			var tag: PanelContainer = UIKit.panel(Color(0.3, 0.22, 0.04, 0.6), 12, 10, UIKit.GOLD)
			tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tag.custom_minimum_size = Vector2(0, 46)
			var tag_row: HBoxContainer = HBoxContainer.new()
			tag.add_child(tag_row)
			var nm: Label = UIKit.label("★ " + ProfileStore.name_of(pid), 17, Color.WHITE, true)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tag_row.add_child(nm)
			if LocalSession.use_banks and LocalSession.game != LocalSession.Game.DUTCH:
				tag_row.add_child(UIKit.label("%d" % ProfileStore.playable_bank(pid), 14, UIKit.GOLD, true))
			row.add_child(tag)
			var unlink: Button = UIKit.outline_button("Retirer", UIKit.TEXT_SOFT, 14)
			unlink.custom_minimum_size = Vector2(96, 46)
			unlink.pressed.connect(_unlink.bind(i))
			row.add_child(unlink)
			players_box.add_child(row)
			continue
		var edit: LineEdit = LineEdit.new()
		edit.placeholder_text = "ZIA" if is_bot else "Joueur %d" % (i + 1)
		edit.text = LocalSession.names[i]
		edit.max_length = 12
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size = Vector2(0, 46)
		edit.add_theme_font_size_override("font_size", 17)
		edit.text_changed.connect(_on_name.bind(i))
		row.add_child(edit)
		var kind: Button = UIKit.outline_button(
			"IA" if is_bot else "Humain", UIKit.GOLD if is_bot else Color.WHITE, 15
		)
		kind.custom_minimum_size = Vector2(96, 46)
		kind.pressed.connect(_on_kind.bind(i))
		row.add_child(kind)
		players_box.add_child(row)
	var save_box: CheckBox = UIKit.check("Enregistrer les nouveaux joueurs (progression conservée)", LocalSession.save_new_profiles)
	save_box.toggled.connect(func(on: bool) -> void: LocalSession.save_new_profiles = on)
	players_box.add_child(save_box)
	var bots_note: Label = UIKit.label(
		"« IA » confie ce siège à ZIA (niveau %s, réglable dans Options)." % PokerEngine.difficulty_name(Stats.difficulty),
		12,
		UIKit.TEXT_SOFT
	)
	bots_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	players_box.add_child(bots_note)

	# Jetons (blackjack, poker) ou score cible (Dutch)
	if LocalSession.game == LocalSession.Game.DUTCH:
		var target_box: VBoxContainer = _section("Score qui termine la partie")
		var tlabels: Array[String] = []
		var tsel: int = 1
		for k: int in LocalSession.DUTCH_TARGETS.size():
			tlabels.append("%d pts" % LocalSession.DUTCH_TARGETS[k])
			if LocalSession.DUTCH_TARGETS[k] == LocalSession.dutch_target:
				tsel = k
		target_box.add_child(_segment(tlabels, tsel, _on_target))
		var tnote: Label = UIKit.label(
			"Dès qu'un joueur atteint ce total, la partie s'arrête : le plus bas gagne.", 12, UIKit.TEXT_SOFT
		)
		tnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_box.add_child(tnote)
	else:
		var chips_box: VBoxContainer = _section("Jetons de départ par joueur")
		var labels: Array[String] = []
		var selected: int = 0
		for k: int in LocalSession.CHIP_CHOICES.size():
			labels.append(str(LocalSession.CHIP_CHOICES[k]))
			if LocalSession.CHIP_CHOICES[k] == LocalSession.chips:
				selected = k
		labels.append("Banques perso")
		if LocalSession.use_banks:
			selected = labels.size() - 1
		chips_box.add_child(_segment(labels, selected, _on_chips))
		var note: Label = UIKit.label(
			(
				"Chaque joueur enregistré reprend sa banque personnelle et la retrouve à la prochaine partie "
				+ "(recharge à %d si elle passe sous %d). Invités et ZIA partent avec %d."
			) % [ProfileStore.START_BANK, ProfileStore.MIN_BANK, LocalSession.chips]
			if LocalSession.use_banks
			else "Partie indépendante de votre banque solo. Les joueurs enregistrés gardent leurs statistiques.",
			12,
			UIKit.TEXT_SOFT
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chips_box.add_child(note)


	_content.add_child(UIKit.spacer(4))
	var start: Button = UIKit.button("Lancer la partie", UIKit.GOLD, UIKit.INK, 20)
	start.disabled = LocalSession.human_count() == 0
	start.pressed.connect(_start)
	_content.add_child(start)
	if LocalSession.human_count() == 0:
		var warn: Label = UIKit.label("Il faut au moins un joueur humain.", 13, UIKit.WARNING_TEXT)
		_content.add_child(warn)


func _section(title: String) -> VBoxContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var head: Label = UIKit.label(title.to_upper(), 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	_content.add_child(p)
	return box


func _segment(labels: Array[String], selected: int, on_select: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i: int in labels.size():
		var b: Button = (
			UIKit.button(labels[i], UIKit.GOLD, UIKit.INK, 16)
			if i == selected
			else UIKit.outline_button(labels[i], Color.WHITE, 16)
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(on_select.bind(i))
		row.add_child(b)
	return row


func _stepper() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var minus: Button = UIKit.outline_button("−", Color.WHITE, 24)
	minus.custom_minimum_size = Vector2(64, 52)
	minus.disabled = LocalSession.count <= LocalSession.min_players(LocalSession.game)
	minus.pressed.connect(_on_count.bind(-1))
	row.add_child(minus)
	var value: Label = UIKit.label("%d joueurs" % LocalSession.count, 20, Color.WHITE, true)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	var plus: Button = UIKit.outline_button("+", Color.WHITE, 24)
	plus.custom_minimum_size = Vector2(64, 52)
	plus.disabled = LocalSession.count >= LocalSession.max_players(LocalSession.game)
	plus.pressed.connect(_on_count.bind(1))
	row.add_child(plus)
	return row


func _on_game(index: int) -> void:
	LocalSession.set_game(index)
	_rebuild()


func _on_count(delta: int) -> void:
	LocalSession.set_count(LocalSession.count + delta)
	_rebuild()


func _on_chips(index: int) -> void:
	LocalSession.use_banks = index >= LocalSession.CHIP_CHOICES.size()
	if not LocalSession.use_banks:
		LocalSession.chips = LocalSession.CHIP_CHOICES[index]
	_rebuild()


func _on_target(index: int) -> void:
	LocalSession.dutch_target = LocalSession.DUTCH_TARGETS[index]
	_rebuild()


func _on_kind(index: int) -> void:
	LocalSession.bots[index] = not LocalSession.bots[index]
	LocalSession.profile_ids[index] = ""
	_rebuild()


func _small(text: String) -> Label:
	var l: Label = UIKit.label(text, 12, UIKit.TEXT_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _seat_of(pid: String) -> int:
	for i: int in LocalSession.count:
		if not LocalSession.bots[i] and LocalSession.profile_ids[i] == pid:
			return i
	return -1


## Ajoute un joueur enregistré au premier siège humain libre (ou retire-le s'il est assis).
func _toggle_profile(pid: String) -> void:
	var seat: int = _seat_of(pid)
	if seat >= 0:
		_unlink(seat)
		return
	var target: int = -1
	for i: int in LocalSession.count:
		if not LocalSession.bots[i] and LocalSession.profile_ids[i] == "" and LocalSession.names[i].strip_edges() == "":
			target = i
			break
	if target < 0 and LocalSession.count < LocalSession.max_players(LocalSession.game):
		LocalSession.set_count(LocalSession.count + 1)
		target = LocalSession.count - 1
		LocalSession.bots[target] = false
	if target < 0:
		# Table pleine : on remplace le dernier siège qui n'est pas un joueur enregistré.
		for i: int in range(LocalSession.count - 1, -1, -1):
			if LocalSession.profile_ids[i] == "":
				target = i
				break
	if target < 0:
		return
	LocalSession.bots[target] = false
	LocalSession.profile_ids[target] = pid
	LocalSession.names[target] = ProfileStore.name_of(pid)
	_rebuild()


func _unlink(index: int) -> void:
	LocalSession.profile_ids[index] = ""
	LocalSession.names[index] = ""
	_rebuild()


## Remplit la table avec un groupe récent (en gardant au moins 2 sièges).
func _use_group(ids: Array) -> void:
	var n: int = clampi(ids.size(), LocalSession.min_players(LocalSession.game), LocalSession.max_players(LocalSession.game))
	LocalSession.set_count(n)
	for i: int in LocalSession.count:
		if i < ids.size():
			LocalSession.bots[i] = false
			LocalSession.profile_ids[i] = str(ids[i])
			LocalSession.names[i] = ProfileStore.name_of(str(ids[i]))
		else:
			LocalSession.profile_ids[i] = ""
	_rebuild()


func _open_profiles() -> void:
	ProfilesScreen.return_scene = LocalSession.SETUP_SCENE
	get_tree().change_scene_to_file(ProfilesScreen.SCENE)


func _on_name(text: String, index: int) -> void:
	LocalSession.names[index] = text


func _start() -> void:
	LocalSession.prepare_start()
	GameSave.clear()
	get_tree().change_scene_to_file(LocalSession.scene(LocalSession.game))


func _go_home() -> void:
	get_tree().change_scene_to_file(LocalSession.HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
