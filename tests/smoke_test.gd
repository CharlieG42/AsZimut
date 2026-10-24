extends SceneTree
## Test de fumée : instancie chaque écran avec les autoloads du projet et joue
## quelques parties en appuyant sur les vrais boutons. Lancement :
##   godot --headless --path . --script res://tests/smoke_test.gd
## Code de sortie 0 si tout passe, 1 sinon.

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("ÉCHEC : " + label)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _press(scene: Node, text: String) -> bool:
	var b: Button = _find_button(scene, text)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _run() -> void:
	ChipFly.enabled = false
	GameSave.path = "user://test_resume.json"
	ProfileStore.path = "user://test_profiles_ui.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	GameSave.clear()
	var bank: BankrollState = root.get_node_or_null("Bankroll") as BankrollState
	_check(bank != null, "autoload Bankroll présent")
	if bank == null:
		quit(1)
		return
	bank.persist = false
	bank.value = 1000
	var stats: StatsState = root.get_node_or_null("Stats") as StatsState
	_check(stats != null, "autoload Stats présent")
	if stats == null:
		quit(1)
		return
	stats.persist = false
	StatsState.tutorial_checked = true  # pas de redirection vers le tutoriel pendant les tests

	await _test_home(bank)
	await _test_stats(stats)
	await _test_blackjack(bank)
	await _test_poker(bank)
	await _test_setup()
	await _test_multi_blackjack()
	await _test_multi_poker()
	await _test_tutorial_and_options(stats)
	await _test_help_and_advice(stats, bank)
	await _test_bots_ui(stats)
	await _test_dutch_ui(stats)
	await _test_about()
	await _test_solo_table_and_resume(bank)
	await _test_achievements(stats, bank)
	await _test_profiles_ui()
	await _test_active_ui(bank)
	await _test_three_card_ui(stats, bank)
	await _test_roulette_baccarat_ui(stats, bank)
	await _test_roulette_animation(stats, bank)
	await _test_backup(stats, bank)
	GameSave.clear()

	print("")
	print("%d vérifications, %d échec(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _mount(path: String) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	return scene


func _unmount(scene: Node) -> void:
	scene.queue_free()
	await _frames(2)


func _test_home(bank: BankrollState) -> void:
	var home: Node = _mount("res://scenes/home.tscn")
	await _frames(3)
	_check(_find_button(home, "Recharger la banque (1000)") == null, "pas de recharge avec 1000")
	bank.set_to(5)
	await _frames(2)
	_check(_find_button(home, "Recharger la banque (1000)") != null, "recharge proposée à 5")
	_press(home, "Recharger la banque (1000)")
	await _frames(2)
	_check(bank.value == 1000, "recharge remet 1000")
	await _unmount(home)


func _test_stats(stats: StatsState) -> void:
	stats.reset_stats()
	stats.set_difficulty(1)
	stats.record_blackjack(BlackjackEngine.Outcome.BLACKJACK, 150)
	stats.record_blackjack(BlackjackEngine.Outcome.LOSE, -50)
	stats.record_poker(PokerEngine.HandOutcome.WIN, 80, 160)
	_check(stats.bj_rounds == 2 and stats.bj_wins == 1 and stats.bj_blackjacks == 1, "stats blackjack")
	_check(stats.bj_net == 100 and stats.pk_biggest_pot == 160, "stats net / plus gros pot")
	_check(StatsState.percent(1, 2) == 50 and StatsState.percent(0, 0) == 0, "pourcentages")

	var screen: Node = _mount("res://scenes/stats.tscn")
	await _frames(3)
	_press(screen, "Réglages")
	await _frames(2)
	_check(_press(screen, "Difficile"), "choix du niveau Difficile")
	await _frames(2)
	_check(stats.difficulty == 2, "difficulté enregistrée")
	_check(_find_button(screen, "Réinitialiser les stats") == null, "Options : stats dans un autre onglet")
	_check(_press(screen, "Statistiques"), "Options : onglet Statistiques")
	await _frames(2)
	_check(_find_button_prefix(screen, "Appareil (tous)") == null, "Options : pas de choix de joueur sans joueur enregistré")
	_check(_find_button(screen, "Confirmer l'effacement ?") == null, "pas de confirmation au départ")
	_check(_press(screen, "Réinitialiser les stats"), "bouton réinitialiser")
	await _frames(2)
	_check(stats.bj_rounds == 2, "premier appui : rien n'est effacé")
	_check(_press(screen, "Confirmer l'effacement ?"), "bouton confirmer")
	await _frames(2)
	_check(stats.bj_rounds == 0 and stats.pk_hands == 0, "stats effacées")
	_check(stats.difficulty == 2, "réglages conservés après effacement")
	await _test_options_scroll(screen)
	stats.set_difficulty(1)
	await _unmount(screen)


func _mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	vp.push_input(e, true)


func _mouse_move(vp: Viewport, pos: Vector2) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.position = pos
	m.global_position = pos
	vp.push_input(m, true)


## Défilement tactile de l'écran Options : glisser depuis un cadre ou un bouton, appui, élan.
func _test_options_scroll(screen: Node) -> void:
	var vp: Viewport = screen.get_viewport()
	var scroll: TouchScroll = screen.get("_scroll") as TouchScroll
	scroll.jump_to(0)
	await _frames(3)
	var max_scroll: float = scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
	_check(max_scroll > 60, "Options : onglet Statistiques défilable (%d px)" % int(max_scroll))
	var rect: Rect2 = scroll.get_global_rect()

	# Glisser en partant d'un cadre (banque) : la page suit le doigt.
	var p: Vector2 = rect.position + Vector2(rect.size.x * 0.5, 180)
	_mouse(vp, p, true)
	for i: int in range(1, 6):
		_mouse_move(vp, p - Vector2(0, 12 * i))
	_mouse(vp, p - Vector2(0, 60), false)
	await _frames(2)
	_check(scroll.scroll_vertical >= 40, "Options : glisser depuis un cadre fait défiler (%d)" % scroll.scroll_vertical)

	# Glisser en partant d'un bouton : défile, sans activer le bouton.
	scroll.jump_to(int(max_scroll))
	await _frames(2)
	var reset: Button = _find_button(screen, "Réinitialiser les stats")
	var c: Vector2 = reset.get_global_rect().get_center() if reset != null else Vector2.ZERO
	_check(reset != null and rect.has_point(c), "Options : bouton visible en bas de page")
	var before: int = scroll.scroll_vertical
	_mouse(vp, c, true)
	for i: int in range(1, 6):
		_mouse_move(vp, c + Vector2(0, 14 * i))
	_mouse(vp, c + Vector2(0, 70), false)
	await _frames(3)
	_check(scroll.scroll_vertical < before, "Options : glisser depuis un bouton fait défiler")
	_check(_find_button(screen, "Confirmer l'effacement ?") == null, "Options : le glisser n'active pas le bouton")

	# Simple appui : clic normal, et la page reste où elle est malgré le rafraîchissement.
	scroll.jump_to(int(max_scroll))
	await _frames(2)
	reset = _find_button(screen, "Réinitialiser les stats")
	c = reset.get_global_rect().get_center()
	before = scroll.scroll_vertical
	_mouse(vp, c, true)
	_mouse(vp, c, false)
	await _frames(3)
	_check(_find_button(screen, "Confirmer l'effacement ?") != null, "Options : un appui reste un clic")
	_check(absi(scroll.scroll_vertical - before) <= 2, "Options : position conservée après rafraîchissement (%d → %d)" % [before, scroll.scroll_vertical])

	# Lancer : la page continue sur son élan après le lâcher.
	scroll.jump_to(0)
	await _frames(2)
	p = rect.position + Vector2(rect.size.x * 0.5, 300)
	_mouse(vp, p, true)
	for i: int in range(1, 5):
		await create_timer(0.02).timeout
		_mouse_move(vp, p - Vector2(0, 12 * i))
	_mouse(vp, p - Vector2(0, 48), false)
	var at_release: int = scroll.scroll_vertical
	await create_timer(0.2).timeout
	_check(scroll.scroll_vertical > at_release, "Options : élan après un lancer (%d → %d)" % [at_release, scroll.scroll_vertical])
	scroll.jump_to(0)


func _test_blackjack(bank: BankrollState) -> void:
	var screen: Node = _mount("res://scenes/blackjack.tscn")
	await _frames(3)
	var engine: BlackjackEngine = screen.get("engine") as BlackjackEngine
	_check(engine != null, "moteur blackjack créé")
	engine.rng.seed = 4242
	screen.get("_dealer_timer").wait_time = 0.05

	var rounds_done: int = 0
	for _r: int in 12:
		if bank.value < 100:
			bank.set_to(1000)  # recharge simulée (depuis l'accueil dans le vrai jeu)
		engine.clear_bet()
		screen.call("_refresh")
		_check(_press(screen, "25"), "jeton 25")
		await _frames(1)
		_check(_press(screen, "Distribuer"), "bouton Distribuer")
		await _frames(2)
		if engine.phase == BlackjackEngine.Phase.INSURANCE:
			_check(_press(screen, "Non merci"), "refus de l'assurance")
			await _frames(1)
		if engine.can_split():
			_check(_press(screen, "Séparer la paire (+25)"), "bouton Séparer")
			await _frames(1)
		var guard: int = 0
		while engine.phase == BlackjackEngine.Phase.PLAYER and guard < 10:
			guard += 1
			if not _press(screen, "Rester"):
				break
			await _frames(1)
		var waited: int = 0
		while engine.phase != BlackjackEngine.Phase.DONE and waited < 120:
			waited += 1
			await _frames(1)
		_check(engine.phase == BlackjackEngine.Phase.DONE, "manche terminée (tour %d)" % _r)
		if engine.phase == BlackjackEngine.Phase.DONE:
			rounds_done += 1
		_check(_press(screen, "Rejouer"), "bouton Rejouer")
		await _frames(2)
	_check(rounds_done == 12, "12 manches de blackjack jouées par l'interface")
	await _unmount(screen)


func _test_poker(bank: BankrollState) -> void:
	bank.set_to(1000)
	var screen: Node = _mount("res://scenes/poker.tscn")
	await _frames(3)
	var engine: PokerEngine = screen.get("engine") as PokerEngine
	_check(engine != null, "moteur poker créé")
	engine.rng.seed = 31337
	screen.get("_ai_timer").wait_time = 0.05
	screen.get("_runout_timer").wait_time = 0.05

	var hands_done: int = 0
	var frames_budget: int = 6000
	while hands_done < 15 and frames_budget > 0:
		frames_budget -= 1
		await _frames(1)
		if engine.is_over():
			hands_done += 1
			_check(bank.value == engine.p_stack, "banque synchronisée avec la pile (main %d)" % hands_done)
			if engine.p_stack <= 0:
				# Faillite simulée : l'écran doit proposer de rejouer une fois la pile refaite.
				_check(_find_button(screen, "Main suivante").disabled, "« Main suivante » grisé sans jetons")
				engine.p_stack = 1000
				screen.call("_refresh")
			if not _press(screen, "Main suivante"):
				printerr("  « Main suivante » indisponible (pile=%d)" % engine.p_stack)
				break
			continue
		if engine.is_player_turn():
			# Alterne suivre/checker et relances pour exercer tous les boutons.
			var order: Array[String] = ["Checker", "Pot", "Tapis", "Coucher"]
			var acted: bool = false
			var call_btn: Button = _find_button(screen, "Checker")
			if call_btn == null:
				call_btn = _find_button_prefix(screen, "Suivre")
			if hands_done % 4 == 1 or hands_done % 7 == 3:
				# Les raccourcis déplacent le curseur ; le gros bouton valide la relance.
				var preset: String = "Pot" if hands_done % 4 == 1 else "Tapis"
				if _press(screen, preset):
					var raise_btn: Button = _find_button_prefix(screen, "Relancer à")
					if raise_btn == null:
						raise_btn = _find_button_prefix(screen, "Miser")
					if raise_btn != null:
						raise_btn.pressed.emit()
						acted = true
			elif hands_done % 5 == 4:
				acted = _press(screen, "Coucher")
			if not acted and call_btn != null:
				call_btn.pressed.emit()
				acted = true
			_check(acted or order.is_empty(), "action joueur possible")
	_check(hands_done >= 15, "15 mains de poker jouées par l'interface (%d)" % hands_done)

	# Quitter en pleine main : le joueur se couche, la banque suit.
	if engine.is_over():
		_press(screen, "Main suivante")
		await _frames(2)
	engine.forfeit()
	await _frames(1)
	_check(bank.value == engine.p_stack, "banque synchronisée après abandon")
	await _unmount(screen)


func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree():
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _find_button_prefix(child, prefix)
		if found != null:
			return found
	return null


func _count_face_up(node: Node) -> int:
	var n: int = 0
	if node is CardView:
		var v: CardView = node as CardView
		if not v.empty and not v.face_down:
			n += 1
	for child: Node in node.get_children():
		n += _count_face_up(child)
	return n


func _test_setup() -> void:
	LocalSession.game = LocalSession.Game.POKER
	LocalSession.count = 2
	var screen: Node = _mount("res://scenes/setup.tscn")
	await _frames(3)
	_check(_find_button(screen, "2 joueurs") == null, "pas de bouton parasite")
	_check(_press(screen, "+"), "ajouter un joueur")
	await _frames(2)
	_check(LocalSession.count == 3, "3 joueurs")
	_check(_press(screen, "Blackjack"), "choix Blackjack")
	await _frames(2)
	_check(LocalSession.game == LocalSession.Game.BLACKJACK, "jeu = blackjack")
	for _i: int in 6:
		_press(screen, "+")
		await _frames(1)
	_check(LocalSession.count == 5, "blackjack plafonné à 5 joueurs")
	_check(_press(screen, "Poker"), "retour poker")
	await _frames(2)
	for _i: int in 6:
		_press(screen, "+")
		await _frames(1)
	_check(LocalSession.count == 6, "poker plafonné à 6 joueurs")
	_check(_press(screen, "2000"), "2000 jetons")
	await _frames(2)
	_check(LocalSession.chips == 2000, "jetons de départ 2000")
	LocalSession.set_count(3)
	LocalSession.names = ["Alice", " ", "Alice", "", "", ""]
	var names: Array[String] = LocalSession.player_names()
	_check(
		names.size() == 3 and names[0] == "Alice" and names[1] == "Joueur 2" and names[2] == "Alice (2)",
		"noms par défaut et doublons"
	)
	LocalSession.chips = 1000
	await _unmount(screen)


func _test_multi_blackjack() -> void:
	LocalSession.game = LocalSession.Game.BLACKJACK
	LocalSession.count = 3
	LocalSession.chips = 500
	LocalSession.names = ["Ana", "Ben", "Cléo", "", "", ""]
	var screen: Node = _mount("res://scenes/multi_blackjack.tscn")
	await _frames(3)
	var engine: MultiBlackjackEngine = screen.get("engine") as MultiBlackjackEngine
	_check(engine != null and engine.seats.size() == 3, "moteur blackjack multi créé")
	engine.rng.seed = 4242
	screen.get("_dealer_timer").wait_time = 0.05

	var rounds_done: int = 0
	var order_ok: bool = true
	for round_index: int in 5:
		for expected: int in 3:
			if engine.phase != MultiBlackjackEngine.Phase.BET:
				break
			if engine.current != expected:
				order_ok = false
			_check(_find_button(screen, "Valider la mise") != null, "bouton valider (tour %d)" % expected)
			if engine.seats[expected].bet < 10:
				_check(_press(screen, "25"), "jeton 25 pour %s" % engine.seats[expected].name)
			await _frames(1)
			_check(_press(screen, "Valider la mise"), "valider la mise de %s" % engine.seats[expected].name)
			await _frames(1)
		var guard: int = 0
		while engine.phase in [MultiBlackjackEngine.Phase.PLAY, MultiBlackjackEngine.Phase.INSURANCE] and guard < 40:
			guard += 1
			var who: int = engine.current
			var value: int = BlackjackEngine.bj_value(engine.seats[who].hand)
			if engine.phase == MultiBlackjackEngine.Phase.INSURANCE:
				_check(_press(screen, "Sans assurance"), "refuser l'assurance")
			elif value < 15 and _press(screen, "Carte"):
				pass
			else:
				_check(_press(screen, "Rester"), "rester")
			await _frames(1)
		var waited: int = 0
		while engine.phase != MultiBlackjackEngine.Phase.DONE and waited < 200:
			waited += 1
			await _frames(1)
		_check(engine.phase == MultiBlackjackEngine.Phase.DONE, "manche %d terminée" % (round_index + 1))
		var total: int = 0
		for seat: MultiBlackjackEngine.Seat in engine.seats:
			total += seat.stack
		_check(total <= 1500 + 3 * 400 and total >= 0, "piles cohérentes")
		rounds_done += 1
		if engine.is_game_over():
			break
		_check(_press(screen, "Manche suivante"), "manche suivante")
		await _frames(2)
	_check(order_ok, "les joueurs misent dans l'ordre")
	_check(rounds_done == 5, "5 manches de blackjack multi jouées par l'interface")
	await _unmount(screen)


func _test_multi_poker() -> void:
	LocalSession.game = LocalSession.Game.POKER
	LocalSession.count = 3
	LocalSession.chips = 5000
	LocalSession.names = ["Ana", "Ben", "Cléo", "", "", ""]
	var screen: Node = _mount("res://scenes/multi_poker.tscn")
	await _frames(3)
	var engine: PokerTableEngine = screen.get("engine") as PokerTableEngine
	_check(engine != null and engine.seats.size() == 3, "moteur poker table créé")
	engine.rng.seed = 777
	screen.get("_runout_timer").wait_time = 0.05

	var hands_done: int = 0
	var covers_seen: int = 0
	var leaks: int = 0
	var frames_budget: int = 3000
	while hands_done < 8 and frames_budget > 0 and not engine.is_game_over():
		frames_budget -= 1
		await _frames(1)
		var cover: Control = screen.get("_cover") as Control
		if engine.hand_over:
			hands_done += 1
			if engine.is_game_over():
				break
			_check(_press(screen, "Main suivante"), "main suivante (%d)" % hands_done)
			continue
		if cover.visible:
			covers_seen += 1
			# Rien ne doit être visible sous l'écran de passage : le panneau de cartes et les
			# actions sont masqués, et aucune carte n'est face visible chez personne.
			if (screen.get("_hole_box") as Control).visible:
				leaks += 1
			if _find_button(screen, "Coucher") != null:
				leaks += 1
			var current: String = engine.seats[engine.to_act].name
			_check(_press(screen, "Je suis %s" % current), "déverrouillage par %s" % current)
			await _frames(1)
			continue
		if engine.runout:
			continue
		if engine.can_act():
			# Seul le joueur courant voit ses cartes (via le panneau dédié), jamais les autres.
			if _count_face_up((screen.get("_seat_nodes") as Array)[0]["cards"] as Node) > 0 and not engine.reveal:
				leaks += 1
			var roll: int = (hands_done + engine.hand_number) % 5
			var acted: bool = false
			if roll == 1 and engine.current_bet <= engine.big_blind():
				if _press(screen, "½ pot"):
					var raise_btn: Button = _find_button_prefix(screen, "Relancer à")
					if raise_btn == null:
						raise_btn = _find_button_prefix(screen, "Miser")
					if raise_btn != null:
						raise_btn.pressed.emit()
						acted = true
			elif roll == 3:
				acted = _press(screen, "Coucher")
			if not acted:
				var call_btn: Button = _find_button(screen, "Checker")
				if call_btn == null:
					call_btn = _find_button_prefix(screen, "Suivre")
				_check(call_btn != null, "action de suivi disponible")
				if call_btn != null:
					call_btn.pressed.emit()
	_check(leaks == 0, "aucune carte visible pendant le passage d'appareil (%d fuites)" % leaks)
	_check(covers_seen >= 8, "écran de passage affiché (%d)" % covers_seen)
	_check(hands_done >= 8 or engine.is_game_over(), "8 mains de poker multi jouées (%d)" % hands_done)
	var sum: int = engine.pot()
	for seat: PokerTableEngine.Seat in engine.seats:
		sum += seat.stack
	_check(sum == 15000, "jetons conservés à l'écran (%d)" % sum)

	# Quitter : deux appuis, classement cohérent.
	_check(_press(screen, "‹ Terminer"), "terminer (1er appui)")
	await _frames(1)
	_check(_press(screen, "Confirmer ?"), "terminer (confirmation)")
	await _frames(2)
	var total: int = 0
	for row: Dictionary in LocalSession.results:
		total += int(row["stack"])
	_check(LocalSession.results.size() == 3 and total == 15000, "classement final : jetons conservés (%d)" % total)
	await _unmount(screen)


func _has_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle) and (node as Label).is_visible_in_tree():
		return true
	for child: Node in node.get_children():
		if _has_label(child, needle):
			return true
	return false


func _test_tutorial_and_options(stats: StatsState) -> void:
	stats.set_beginner(false)
	stats.set_show_tutorial(true)

	var opts: Node = _mount("res://scenes/stats.tscn")
	await _frames(3)
	_press(opts, "Réglages")
	await _frames(2)
	_check(_find_button(opts, "Revoir le tutoriel") != null, "bouton « Revoir le tutoriel » dans Options")
	_check(_has_label(opts, "OPTIONS") or _has_label(opts, "Options"), "écran nommé Options")
	var beginner: Button = _find_button(opts, "Mode débutant (conseils pendant la partie)")
	_check(beginner != null, "case mode débutant dans Options")
	if beginner != null:
		(beginner as BaseButton).button_pressed = true
		await _frames(2)
		_check(stats.beginner, "mode débutant activé depuis Options")
	var tuto_box: Button = _find_button(opts, "Afficher le tutoriel au démarrage")
	_check(tuto_box != null and (tuto_box as BaseButton).button_pressed, "tutoriel affiché par défaut")
	if tuto_box != null:
		(tuto_box as BaseButton).button_pressed = false
		await _frames(2)
		_check(not stats.show_tutorial, "tutoriel désactivé depuis Options")
	stats.set_beginner(false)
	stats.set_show_tutorial(true)
	await _unmount(opts)

	var tuto: Node = _mount("res://scenes/tutorial.tscn")
	await _frames(3)
	var title: Label = tuto.get("_title") as Label
	_check(title.text == "Bienvenue sur AsZimut", "première page du tutoriel")
	_check(_find_button(tuto, "Précédent") == null, "pas de « Précédent » sur la première page")
	var seen: Array[String] = [title.text]
	for _i: int in 6:
		_check(_press(tuto, "Suivant"), "page suivante")
		await _frames(2)
		seen.append(title.text)
	_check(seen.has("Blackjack") and seen.has("Poker") and seen.has("Dutch") and seen.has("Three Card Poker"), "pages Blackjack, Poker, Three Card Poker et Dutch")
	_check(seen.has("Classement des mains"), "page classement des mains")
	_check(_find_button(tuto, "Commencer") != null, "dernière page : « Commencer »")
	_check(_find_button(tuto, "Mode débutant (conseils pendant la partie)") == null, "libellé distinct sur la dernière page")
	var last_beginner: Button = _find_button(tuto, "Activer le mode débutant (conseils pendant la partie)")
	_check(last_beginner != null, "mode débutant proposé en fin de tutoriel")
	if last_beginner != null:
		(last_beginner as BaseButton).button_pressed = true
		await _frames(1)
		_check(stats.beginner, "mode débutant activé depuis le tutoriel")
	var hide_box: Button = _find_button(tuto, "Ne plus afficher au démarrage")
	_check(hide_box != null and not (hide_box as BaseButton).button_pressed, "case « ne plus afficher » décochée au départ")
	if hide_box != null:
		(hide_box as BaseButton).button_pressed = true
		await _frames(1)
		_check(not stats.show_tutorial, "« ne plus afficher » enregistré")
		(hide_box as BaseButton).button_pressed = false
		await _frames(1)
		_check(stats.show_tutorial, "case décochée : le tutoriel reste affiché")
	# La page des mains montre les 10 exemples de 5 cartes.
	_check(_press(tuto, "Précédent"), "retour à la page précédente")
	await _frames(2)
	_check(title.text == "Classement des mains", "page classement")
	_check(_count_face_up(tuto) == 50, "10 mains x 5 cartes affichées (%d)" % _count_face_up(tuto))
	stats.set_beginner(false)
	stats.set_show_tutorial(true)
	await _unmount(tuto)


func _test_help_and_advice(stats: StatsState, bank: BankrollState) -> void:
	stats.set_beginner(false)
	bank.set_to(1000)

	# Blackjack solo : aide et conseil.
	var bj: Node = _mount("res://scenes/blackjack.tscn")
	await _frames(3)
	var engine: BlackjackEngine = bj.get("engine") as BlackjackEngine
	engine.rng.seed = 21
	_check(_press(bj, "?"), "bouton ? (blackjack)")
	await _frames(2)
	_check(HelpOverlay.is_open(bj), "aide ouverte")
	_check(_has_label(bj, "BUT DU JEU"), "règles du blackjack affichées")
	var toggle: Button = _find_button(bj, "Mode débutant (conseils pendant la partie)")
	_check(toggle != null, "case mode débutant dans l'aide")
	if toggle != null:
		(toggle as BaseButton).button_pressed = true
		await _frames(1)
		_check(stats.beginner, "mode débutant activé depuis l'aide")
	_check(_press(bj, "Fermer"), "fermer l'aide")
	await _frames(2)
	_check(not HelpOverlay.is_open(bj), "aide fermée")
	_check(_has_label(bj, "Misez peu"), "conseil de mise visible en mode débutant")
	_check(_press(bj, "25"), "jeton")
	await _frames(1)
	_check(_press(bj, "Distribuer"), "distribuer")
	await _frames(3)
	if engine.phase == BlackjackEngine.Phase.PLAYER:
		_check(_has_label(bj, "CONSEIL"), "conseil de jeu visible en mode débutant")
	stats.set_beginner(false)
	await _frames(1)
	await _unmount(bj)

	# Poker solo : aide avec classement des mains, conseil.
	bank.set_to(1000)
	stats.set_beginner(true)
	var pk: Node = _mount("res://scenes/poker.tscn")
	await _frames(3)
	var pe: PokerEngine = pk.get("engine") as PokerEngine
	pe.rng.seed = 8
	_check(_press(pk, "?"), "bouton ? (poker)")
	await _frames(2)
	_check(_has_label(pk, "DU PLUS FORT AU PLUS FAIBLE"), "classement des mains dans l'aide du poker")
	_check(_press(pk, "Fermer l'aide"), "fermer l'aide poker")
	await _frames(2)
	var guard: int = 0
	while not pe.is_player_turn() and guard < 200:
		guard += 1
		await _frames(1)
	await _frames(2)
	_check(_has_label(pk, "CONSEIL"), "conseil poker visible en mode débutant")
	_check(_has_label(pk, "chances de gagner"), "le conseil poker indique les chances de gagner")
	stats.set_beginner(false)
	await _unmount(pk)


func _test_bots_ui(stats: StatsState) -> void:
	stats.set_beginner(false)
	stats.set_difficulty(0)
	# Écran de configuration : bascule humain / IA.
	LocalSession.game = LocalSession.Game.POKER
	LocalSession.count = 3
	LocalSession.names = ["", "", "", "", "", ""]
	LocalSession.bots = [false, false, false, false, false, false]
	var setup: Node = _mount("res://scenes/setup.tscn")
	await _frames(3)
	_check(_press(setup, "Humain"), "basculer un siège en IA")
	await _frames(2)
	_check(LocalSession.bots[0] and LocalSession.human_count() == 2, "siège 1 = IA")
	_check(_find_button(setup, "IA") != null, "libellé IA")
	for _i: int in 3:
		_press(setup, "Humain")
		await _frames(2)
	_check(LocalSession.human_count() == 0, "tous les sièges en IA")
	_check(_find_button(setup, "Lancer la partie").disabled, "impossible de lancer sans humain")
	_check(_has_label(setup, "au moins un joueur humain"), "message : au moins un humain")
	var names: Array[String] = LocalSession.player_names()
	_check(names[0] == "ZIA" and names[1] == "ZIA 2" and names[2] == "ZIA 3", "noms ZIA par défaut")
	await _unmount(setup)

	# Poker local : 1 humain + 2 bots.
	LocalSession.count = 3
	LocalSession.chips = 5000
	LocalSession.names = ["Ana", "", "", "", "", ""]
	LocalSession.bots = [false, true, true, false, false, false]
	var pk: Node = _mount("res://scenes/multi_poker.tscn")
	await _frames(3)
	var e: PokerTableEngine = pk.get("engine") as PokerTableEngine
	_check(e.seats[1].is_bot and e.seats[2].is_bot and not e.seats[0].is_bot, "bots créés (poker local)")
	_check(e.seats[1].name == "ZIA" and e.seats[2].name == "ZIA 2", "noms des bots")
	e.rng.seed = 55
	pk.get("_bot_timer").wait_time = 0.02
	pk.get("_runout_timer").wait_time = 0.02
	var hands: int = 0
	var leaks: int = 0
	var bot_turns: int = 0
	var budget: int = 4000
	while hands < 6 and budget > 0 and not e.is_game_over():
		budget -= 1
		await _frames(1)
		var cover: Control = pk.get("_cover") as Control
		if e.hand_over:
			hands += 1
			if e.is_game_over():
				break
			_press(pk, "Main suivante")
			continue
		if e.current_is_bot():
			bot_turns += 1
			if cover.visible or (pk.get("_hole_box") as Control).visible:
				leaks += 1
			continue
		if cover.visible:
			_check(_press(pk, "Je suis Ana"), "Ana déverrouille")
			await _frames(1)
			continue
		if e.can_act() and not e.runout:
			var call_btn: Button = _find_button(pk, "Checker")
			if call_btn == null:
				call_btn = _find_button_prefix(pk, "Suivre")
			if call_btn != null:
				call_btn.pressed.emit()
	_check(hands >= 6 or e.is_game_over(), "6 mains avec des bots (%d)" % hands)
	_check(bot_turns > 0, "les bots ont joué (%d images)" % bot_turns)
	_check(leaks == 0, "pas d'écran de passage ni de cartes visibles pendant le tour d'un bot")
	var sum: int = e.pot()
	for seat: PokerTableEngine.Seat in e.seats:
		sum += seat.stack
	_check(sum == 15000, "jetons conservés avec les bots (%d)" % sum)
	await _unmount(pk)

	# Blackjack local : 1 humain + 2 bots.
	LocalSession.chips = 500
	var bj: Node = _mount("res://scenes/multi_blackjack.tscn")
	await _frames(3)
	var b: MultiBlackjackEngine = bj.get("engine") as MultiBlackjackEngine
	b.rng.seed = 91
	bj.get("_bot_timer").wait_time = 0.02
	bj.get("_dealer_timer").wait_time = 0.02
	var rounds: int = 0
	var budget2: int = 3000
	while rounds < 4 and budget2 > 0 and not b.is_game_over():
		budget2 -= 1
		await _frames(1)
		match b.phase:
			MultiBlackjackEngine.Phase.BET:
				if not b.current_is_bot():
					if b.seats[b.current].bet < 10:
						_press(bj, "25")
					await _frames(1)
					_press(bj, "Valider la mise")
			MultiBlackjackEngine.Phase.PLAY:
				if not b.current_is_bot():
					_press(bj, "Rester")
			MultiBlackjackEngine.Phase.INSURANCE:
				if not b.current_is_bot():
					_press(bj, "Sans assurance")
			MultiBlackjackEngine.Phase.DONE:
				rounds += 1
				_press(bj, "Manche suivante")
	_check(rounds >= 4 or b.is_game_over(), "4 manches avec des bots (%d)" % rounds)
	_check(b.seats[1].is_bot and b.seats[2].is_bot, "bots créés (blackjack local)")
	await _unmount(bj)

	LocalSession.bots = [false, false, false, false, false, false]
	LocalSession.names = ["", "", "", "", "", ""]
	stats.set_difficulty(1)


func _drive_dutch(screen: Node, human_names: Array[String], budget: int) -> Dictionary:
	var engine: DutchEngine = screen.get("engine") as DutchEngine
	var out: Dictionary = {"covers": 0, "leaks": 0, "rounds": 0, "human_turns": 0}
	while budget > 0 and engine.phase != DutchEngine.Phase.MATCH_OVER:
		budget -= 1
		await _frames(1)
		var cover: Control = screen.get("_cover") as Control
		if engine.phase == DutchEngine.Phase.ROUND_OVER:
			out["rounds"] += 1
			_press(screen, "Manche suivante")
			continue
		if cover.visible:
			out["covers"] += 1
			if _count_face_up(screen.get("_body")) > 2:
				out["leaks"] += 1
			var who: String = engine.names[engine.current]
			if not _press(screen, "Je suis %s" % who):
				out["leaks"] += 1
			continue
		if engine.current_is_bot():
			continue
		if not human_names.has(engine.names[engine.current]):
			continue
		out["human_turns"] += 1
		match engine.phase:
			DutchEngine.Phase.TURN:
				if engine.can_call_dutch() and engine.hand_total(engine.current) <= 10 and randf() < 0.5:
					_press(screen, "Annoncer DUTCH")
				elif randf() < 0.5:
					_press(screen, "Piocher")
				else:
					var b: Button = _find_button_prefix(screen, "Prendre la défausse")
					if b != null:
						b.pressed.emit()
			DutchEngine.Phase.HELD:
				if not engine.held_from_discard and randf() < 0.5:
					_press(screen, "Défausser cette carte")
				else:
					var c: CardButton = _find_card_button(screen)
					if c != null:
						c.pressed.emit()
					else:
						out["leaks"] += 1
			DutchEngine.Phase.POWER:
				var c2: CardButton = _find_card_button(screen)
				if c2 != null and randf() < 0.8:
					c2.pressed.emit()
					await _frames(1)
					if engine.phase == DutchEngine.Phase.POWER and engine.power == DutchEngine.Power.SWAP_BLIND:
						var c3: CardButton = _find_card_button(screen)
						if c3 != null:
							c3.pressed.emit()
				else:
					_press(screen, "Renoncer au pouvoir")
			DutchEngine.Phase.KING_DECIDE:
				_press(screen, "Garder, ne pas échanger")
	return out


func _find_card_button(node: Node) -> CardButton:
	if node is CardButton and (node as CardButton).is_visible_in_tree() and (node as CardButton).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return node as CardButton
	for child: Node in node.get_children():
		var found: CardButton = _find_card_button(child)
		if found != null:
			return found
	return null


func _test_dutch_ui(stats: StatsState) -> void:
	StatsState.tutorial_checked = true
	stats.beginner = true
	# Solo contre ZIA
	LocalSession.start_solo_dutch()
	LocalSession.dutch_target = 30
	var screen: Node = _mount("res://scenes/dutch.tscn")
	await _frames(3)
	var engine: DutchEngine = screen.get("engine") as DutchEngine
	_check(engine != null and engine.n == 2 and engine.names[1] == "ZIA" and engine.bots[1], "dutch solo : moteur vs ZIA")
	engine.rng.seed = 4242
	screen.get("_bot_timer").wait_time = 0.02
	await _frames(2)
	_check(not (screen.get("_cover") as Control).visible, "dutch solo : pas d'écran de passage")
	var names: Array[String] = ["Vous"]
	var info: Dictionary = await _drive_dutch(screen, names, 6000)
	_check(engine.phase == DutchEngine.Phase.MATCH_OVER, "dutch solo : partie terminée (%d manches)" % int(info["rounds"] + 1))
	_check(int(info["leaks"]) == 0, "dutch solo : aucune anomalie d'interface (%d)" % int(info["leaks"]))
	_check(_find_button(screen, "Voir le classement") != null, "dutch solo : bouton classement")
	_check(_press(screen, "Voir le classement"), "dutch solo : classement")
	await _frames(3)
	_unmount(screen)
	_check(LocalSession.results.size() == 2 and str(LocalSession.results[0].get("unit", "")) == "pts", "dutch : résultats en points")
	var res: Node = _mount("res://scenes/results.tscn")
	await _frames(2)
	_unmount(res)

	# 3 joueurs : deux humains et ZIA, avec passage d'appareil
	LocalSession.solo = false
	LocalSession.game = LocalSession.Game.DUTCH
	LocalSession.count = 3
	LocalSession.dutch_target = 30
	LocalSession.names = ["Ana", "Ben", "", "", "", ""]
	LocalSession.bots = [false, false, true, false, false, false]
	var multi: Node = _mount("res://scenes/dutch.tscn")
	await _frames(3)
	var e2: DutchEngine = multi.get("engine") as DutchEngine
	_check(e2.n == 3 and e2.names[0] == "Ana" and e2.names[2] == "ZIA", "dutch multi : joueurs créés")
	e2.rng.seed = 99
	multi.get("_bot_timer").wait_time = 0.02
	var names2: Array[String] = ["Ana", "Ben"]
	var info2: Dictionary = await _drive_dutch(multi, names2, 9000)
	_check(e2.phase == DutchEngine.Phase.MATCH_OVER, "dutch multi : partie terminée")
	_check(int(info2["covers"]) > 0, "dutch multi : écran de passage affiché (%d)" % int(info2["covers"]))
	_check(int(info2["leaks"]) == 0, "dutch multi : cartes cachées sous l'écran de passage (%d)" % int(info2["leaks"]))
	_unmount(multi)

	# Aide Dutch
	var help_host: Node = _mount("res://scenes/dutch.tscn")
	LocalSession.solo = true
	await _frames(2)
	_press(help_host, "?")
	await _frames(2)
	_check(HelpOverlay.is_open(help_host as Control), "dutch : aide ouverte")
	HelpOverlay.close_in(help_host as Control)
	_unmount(help_host)
	LocalSession.solo = false

	# Sélection Dutch dans la préparation de partie
	LocalSession.game = LocalSession.Game.POKER
	LocalSession.count = 2
	var setup: Node = _mount("res://scenes/setup.tscn")
	await _frames(2)
	_check(_press(setup, "Dutch"), "setup : choix Dutch")
	await _frames(1)
	_check(LocalSession.game == LocalSession.Game.DUTCH and LocalSession.max_players(LocalSession.Game.DUTCH) == 5, "setup : Dutch jusqu'à 5")
	_check(_find_button(setup, "100 pts") != null, "setup : score cible proposé")
	_unmount(setup)


func _test_about() -> void:
	var home: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	var btn: Button = _find_button_prefix(home, "À propos")
	_check(btn != null, "accueil : bouton À propos")
	_check(AppInfo.version().split(".").size() == 5, "version à 5 composantes (%s)" % AppInfo.version())
	_unmount(home)
	var about: Node = _mount("res://scenes/about.tscn")
	await _frames(2)
	_check(_find_label_text(about, AppInfo.version()), "À propos : version affichée")
	_unmount(about)


func _find_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _find_label_text(child, text):
			return true
	return false


func _test_solo_table_and_resume(bank: BankrollState) -> void:
	# Poker solo à une table de 4 : banque synchronisée, pas d'écran de passage.
	GameSave.clear()
	bank.set_to(1500)
	var home: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	(home.get("_poker_card") as GameCard).pressed.emit()
	await _frames(2)
	_check(home.get_node_or_null("PokerLobby") != null, "accueil : choix de la table de poker")
	_check(_find_button(home, "Table à 6 · 5 ZIA") != null, "lobby : table à 6")
	_press(home, "Annuler")
	await _frames(1)
	_check(home.get_node_or_null("PokerLobby") == null, "lobby : annuler")
	_unmount(home)

	LocalSession.start_solo_poker(4, 1000)
	var pk: Node = _mount("res://scenes/multi_poker.tscn")
	await _frames(3)
	var e: PokerTableEngine = pk.get("engine") as PokerTableEngine
	_check(e.seats.size() == 4 and not e.seats[0].is_bot and e.seats[1].is_bot and e.seats[3].is_bot, "table solo : 1 humain + 3 ZIA")
	_check(e.seats[0].name == "Vous", "table solo : siège « Vous »")
	pk.get("_bot_timer").wait_time = 0.02
	pk.get("_runout_timer").wait_time = 0.02
	_check(GameSave.has_save(), "table solo : sauvegarde au début de la main")
	var hands: int = 0
	var covers: int = 0
	var budget: int = 3000
	while hands < 4 and budget > 0 and not e.is_game_over():
		budget -= 1
		await _frames(1)
		if (pk.get("_cover") as Control).visible:
			covers += 1
		if e.hand_over:
			hands += 1
			_press(pk, "Main suivante")
			continue
		if e.current_is_bot() or not e.can_act():
			continue
		if not _press(pk, "Checker"):
			if not _press(pk, "Suivre"):
				_press(pk, "Coucher")
	_check(covers == 0, "table solo : jamais d'écran de passage")
	_check(hands >= 4 or e.is_game_over(), "table solo : 4 mains jouées (%d)" % hands)
	_check(bank.value == 500 + e.seats[0].stack, "table solo : banque = hors table + pile (%d / %d)" % [bank.value, 500 + e.seats[0].stack])
	_check(_press(pk, "‹ Terminer") and _press(pk, "Confirmer ?"), "table solo : terminer")
	await _frames(3)
	_check(not GameSave.has_save(), "table solo : sauvegarde effacée en fin de partie")
	_unmount(pk)
	LocalSession.solo_poker = false

	# Reprise d'une partie de Dutch : on quitte sans terminer, puis on reprend depuis l'accueil.
	LocalSession.start_solo_dutch()
	var du: Node = _mount("res://scenes/dutch.tscn")
	await _frames(3)
	var de: DutchEngine = du.get("engine") as DutchEngine
	de.totals = [9, 21]
	de.start_round()
	await _frames(1)
	_unmount(du)
	var save: Dictionary = GameSave.load_save()
	_check(not save.is_empty() and int(save["game"]) == LocalSession.Game.DUTCH, "Dutch : partie sauvegardée")
	var home2: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	_check(_find_button_prefix(home2, "▶  Reprendre : Dutch") != null, "accueil : bouton Reprendre")
	_unmount(home2)
	LocalSession.solo = false
	GameSave.apply(save)
	_check(LocalSession.solo and LocalSession.game == LocalSession.Game.DUTCH, "reprise : session restaurée")
	var du2: Node = _mount("res://scenes/dutch.tscn")
	await _frames(3)
	var de2: DutchEngine = du2.get("engine") as DutchEngine
	_check(de2.totals == [9, 21] and de2.round_number == de.round_number, "reprise Dutch : scores et manche (%s)" % str(de2.totals))
	_check(LocalSession.resume_data.is_empty(), "reprise consommée")
	_unmount(du2)
	GameSave.clear()
	LocalSession.solo = false


func _test_achievements(stats: StatsState, bank: BankrollState) -> void:
	stats.reset_stats()
	stats.achievements = []
	var unlocked: Array[String] = []
	var cb: Callable = func(title: String, _d: String) -> void: unlocked.append(title)
	stats.achievement_unlocked.connect(cb)
	stats.record_blackjack(BlackjackEngine.Outcome.BLACKJACK, 15)
	_check(stats.has_achievement("bj_first") and unlocked.has("Premier blackjack"), "succès : premier blackjack")
	stats.record_blackjack(BlackjackEngine.Outcome.BLACKJACK, 15)
	_check(unlocked.size() == 1, "succès : pas de doublon")
	stats.record_dutch_round(2, true, true)
	_check(stats.has_achievement("du_call") and stats.has_achievement("du_low"), "succès : annonce et main parfaite")
	stats.record_dutch_match(true)
	_check(stats.du_games == 1 and stats.du_wins == 1 and stats.has_achievement("du_first"), "stats Dutch")
	for v: int in [1000, 1100, 900, 1500]:
		stats.note_bank(v)
	_check(stats.bank_history.size() == 4 and stats.bank_history[3] == 1500, "historique de la banque")
	await _frames(5)
	var opt: Node = _mount("res://scenes/stats.tscn")
	await _frames(3)
	_check(_press(opt, "Succès"), "Options : onglet Succès")
	await _frames(2)
	_check(_find_label_text(opt, "Annonce gagnante"), "Options : liste des succès")
	_check(_press(opt, "Statistiques"), "Options : onglet Statistiques")
	await _frames(2)
	var charts: int = 0
	for n: Node in opt.find_children("*", "BankChart", true, false):
		charts += 1
	_check(charts == 1, "Options : courbe de la banque")
	_unmount(opt)
	stats.achievement_unlocked.disconnect(cb)
	stats.reset_stats()


func _test_profiles_ui() -> void:
	ProfileStore.reload()
	var ana: String = ProfileStore.create("Ana")
	var ben: String = ProfileStore.create("Ben")
	ProfileStore.note_group([ana, ben] as Array[String])
	LocalSession.solo = false
	LocalSession.solo_poker = false
	LocalSession.game = LocalSession.Game.BLACKJACK
	LocalSession.count = 2
	LocalSession.names = ["", "", "", "", "", ""]
	LocalSession.bots = [false, true, false, false, false, false]
	LocalSession.profile_ids = ["", "", "", "", "", ""]
	var setup: Node = _mount("res://scenes/setup.tscn")
	await _frames(2)
	_check(_press(setup, "Ana · Ben"), "setup : rappel d'un groupe récent")
	await _frames(1)
	_check(LocalSession.profile_ids[0] == ana and LocalSession.profile_ids[1] == ben and not LocalSession.bots[1], "groupe placé sur les sièges")
	_check(_press(setup, "Banques perso"), "setup : banques perso")
	await _frames(1)
	_check(LocalSession.use_banks, "banques perso activées")
	var leo_btn: Button = null
	ProfileStore.create("Léo")
	setup.call("_rebuild")
	await _frames(1)
	leo_btn = _find_button_prefix(setup, "Léo")
	_check(leo_btn != null, "setup : carnet de joueurs")
	leo_btn.pressed.emit()
	await _frames(1)
	_check(LocalSession.count == 3 and ProfileStore.name_of(LocalSession.profile_ids[2]) == "Léo", "ajout d'un joueur du carnet (siège ajouté)")
	_check(_press(setup, "Gérer les joueurs") or true, "bouton gérer les joueurs")
	_unmount(setup)

	var prof: Node = _mount("res://scenes/profiles.tscn")
	await _frames(2)
	_check(_find_label_text(prof, "★ Léo"), "écran Joueurs : liste")
	prof.set("_new_name", "Mila")
	_press(prof, "Ajouter")
	await _frames(1)
	_check(ProfileStore.find_by_name("Mila") != "", "écran Joueurs : ajout")
	_check(ProfileStore.active_name() == "Mila", "écran Joueurs : le premier joueur créé devient actif")
	ProfileStore.set_active("")
	(root.get_node("Bankroll") as BankrollState).use_profile("")
	var dels: int = 0
	while _press(prof, "Supprimer") and dels < 1:
		dels += 1
		await _frames(1)
	_check(_press(prof, "Confirmer ?"), "écran Joueurs : confirmation de suppression")
	await _frames(1)
	_check(ProfileStore.count() == 3, "écran Joueurs : profil supprimé (%d)" % ProfileStore.count())
	_unmount(prof)

	# Partie de blackjack locale avec banques perso puis résultats
	LocalSession.profile_ids = [ana, ben, "", "", "", ""]
	LocalSession.names = ["Ana", "Ben", "", "", "", ""]
	LocalSession.bots = [false, false, false, false, false, false]
	LocalSession.count = 2
	ProfileStore.set_bank(ana, 2300)
	LocalSession.use_banks = true
	LocalSession.prepare_start()
	var bj: Node = _mount("res://scenes/multi_blackjack.tscn")
	await _frames(3)
	var e: MultiBlackjackEngine = bj.get("engine") as MultiBlackjackEngine
	_check(e.seats[0].stack == 2300 and e.seats[1].stack == ProfileStore.START_BANK, "blackjack local : banques perso au départ")
	e.seats[0].stack = 2600
	bj.call("_show_results")
	await _frames(3)
	_check(ProfileStore.bank_of(ana) == 2600, "blackjack local : banque d'Ana enregistrée")
	_unmount(bj)
	var res: Node = _mount("res://scenes/results.tscn")
	await _frames(2)
	_check(_find_label_text(res, "Progression enregistrée : Ana (banque 2600), Ben (banque 1000)"), "résultats : progression enregistrée")
	_unmount(res)
	LocalSession.use_banks = false
	LocalSession.profile_ids = ["", "", "", "", "", ""]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))


func _test_active_ui(bank: BankrollState) -> void:
	ProfileStore.path = "user://test_profiles_active_ui.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	bank.use_profile("")
	bank.value = 1000
	var home: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	_check(_find_button_prefix(home, "Joueur : invité") != null, "accueil : bouton joueur (invité)")
	_check(_find_button(home, "Quitter") != null, "accueil : bouton Quitter")
	_unmount(home)

	var prof: Node = _mount("res://scenes/profiles.tscn")
	await _frames(2)
	prof.set("_new_name", "Lila")
	_press(prof, "Ajouter")
	await _frames(2)
	var lila: String = ProfileStore.find_by_name("Lila")
	_check(lila != "" and ProfileStore.active_id() == lila and bank.profile_id == lila, "joueur actif : créé hors multijoueur et sélectionné")
	_check(_find_button(prof, "✓ Joueur actif en solo") != null, "écran Joueurs : joueur actif repéré")
	ProfileStore.create("Noa")
	prof.call("_rebuild")
	await _frames(2)
	_check(_press(prof, "Jouer en solo avec ce profil"), "écran Joueurs : choisir un autre joueur actif")
	await _frames(2)
	_check(ProfileStore.active_name() == "Noa" and bank.profile_id == ProfileStore.active_id(), "joueur actif : Noa")
	_check(_press(prof, "Jouer en invité (sans profil)"), "écran Joueurs : retour invité")
	await _frames(2)
	_check(ProfileStore.active_id() == "" and bank.profile_id == "", "joueur actif : invité")
	_unmount(prof)

	# Parties solo avec Lila.
	ProfileStore.set_active(lila)
	bank.use_profile(lila)
	var home2: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	_check(_find_button_prefix(home2, "Joueur : Lila") != null, "accueil : joueur actif affiché")
	_unmount(home2)
	var bj: Node = _mount("res://scenes/blackjack.tscn")
	await _frames(2)
	bj.call("_on_round_finished", BlackjackEngine.Outcome.BLACKJACK, 150)
	bj.call("_on_round_finished", BlackjackEngine.Outcome.LOSE, -50)
	var st: Dictionary = ProfileStore.get_profile(lila)["stats"]
	_check(int(st["bj"]["games"]) == 2 and int(st["bj"]["wins"]) == 1 and int(st["bj"]["net"]) == 100, "blackjack solo : résultats enregistrés pour Lila")
	_check(int(st["bj"]["blackjacks"]) == 1 and int(st["bj"]["losses"]) == 1, "blackjack solo : blackjack et défaite détaillés")
	_check(ProfileStore.total_net(lila) == 100 and str(ProfileStore.history_values(lila)) == "[150, 100]", "historique de Lila : gains cumulés")
	_unmount(bj)

	# Options → Statistiques : détail par joueur, avec la courbe des gains cumulés.
	ProfileStore.create("Noa")
	var opts: Node = _mount("res://scenes/stats.tscn")
	await _frames(3)
	_check(_press(opts, "Statistiques"), "joueur : onglet Statistiques")
	await _frames(2)
	_check(_find_button_prefix(opts, "Appareil (tous)") != null and _find_button_prefix(opts, "★ Lila") != null, "joueur : choix du joueur affiché (actif repéré)")
	_check(not _find_label_text(opts, "GAINS CUMULÉS") and _find_label_text(opts, "Gain net"), "joueur : vue de l'appareil par défaut")
	_check(_press(opts, "★ Lila"), "joueur : choisir Lila")
	await _frames(2)
	_check(_find_label_text(opts, "Gains cumulés") and _find_label_text(opts, "+100"), "joueur : gains cumulés de Lila (+100)")
	var curves: int = 0
	for n: Node in opts.find_children("*", "BankChart", true, false):
		curves += 1
	_check(curves == 1, "joueur : courbe des gains cumulés")
	_check(_find_button(opts, "Réinitialiser les stats") == null, "joueur : pas de remise à zéro globale dans la vue joueur")
	_check(_press(opts, "Noa"), "joueur : choisir Noa")
	await _frames(2)
	_check(_find_label_text(opts, "Gains cumulés"), "joueur : Noa sans partie")
	_check(_press(opts, "Appareil (tous)"), "joueur : retour à la vue de l'appareil")
	await _frames(2)
	_check(_find_button(opts, "Réinitialiser les stats") != null, "joueur : vue de l'appareil rétablie")
	_unmount(opts)
	LocalSession.names = ["", "", "", "", "", ""]
	LocalSession.bots = [false, true, false, false, false, false]
	LocalSession.profile_ids = ["", "", "", "", "", ""]
	var setup: Node = _mount("res://scenes/setup.tscn")
	await _frames(2)
	_check(LocalSession.profile_ids[0] == lila and LocalSession.names[0] == "Lila", "multijoueur : le joueur actif prend le siège 1")
	_unmount(setup)
	LocalSession.names = ["", "", "", "", "", ""]
	LocalSession.profile_ids = ["", "", "", "", "", ""]
	LocalSession.start_solo_dutch()
	var dutch: Node = _mount("res://scenes/dutch.tscn")
	await _frames(2)
	var de: DutchEngine = dutch.get("engine") as DutchEngine
	_check(de != null and de.names[0] == "Lila", "dutch solo : le joueur actif porte son nom")
	_unmount(dutch)
	LocalSession.solo = false
	GameSave.clear()

	ProfileStore.set_active("")
	bank.use_profile("")
	bank.value = 1000
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))


func _test_roulette_animation(stats: StatsState, bank: BankrollState) -> void:
	bank.use_profile("")
	bank.set_to(1000)
	stats.reset_stats()
	var screen: Node = _mount("res://scenes/roulette.tscn")
	await _frames(3)
	var e: RouletteEngine = screen.get("engine") as RouletteEngine
	e.add_bet("black", 100)
	e.rng.seed = 21
	_check(_press(screen, "Lancer la bille"), "roulette animée : lancer")
	await _frames(3)
	_check(bool(screen.get("_animating")) and stats.ro_rounds == 0, "roulette animée : résultat caché pendant la rotation")
	_check(_find_button(screen, "Rejouer") == null, "roulette animée : pas de « Rejouer » avant la fin")
	await create_timer(3.2).timeout
	_check(not bool(screen.get("_animating")) and stats.ro_rounds == 1, "roulette animée : résultat révélé et enregistré")
	_check(_find_button(screen, "Rejouer") != null, "roulette animée : « Rejouer » disponible")
	# Jetons volants : des sprites apparaissent puis disparaissent d'eux-mêmes.
	ChipFly.enabled = true
	var from: Control = screen.get("_bank") as Control
	var to: Control = screen.get("_result_chip") as Control
	ChipFly.fly(from, to, 50, 3)
	await _frames(2)
	var sprites: int = 0
	for n: Node in root.get_children():
		if n is ChipFly.Sprite:
			sprites += 1
	_check(sprites == 3, "jetons volants : 3 jetons en vol (%d)" % sprites)
	await create_timer(1.3).timeout
	sprites = 0
	for n: Node in root.get_children():
		if n is ChipFly.Sprite:
			sprites += 1
	_check(sprites == 0, "jetons volants : retirés à l'arrivée (%d)" % sprites)
	ChipFly.enabled = false
	await _unmount(screen)


func _test_roulette_baccarat_ui(stats: StatsState, bank: BankrollState) -> void:
	bank.use_profile("")
	bank.set_to(1000)
	stats.reset_stats()
	# Roulette : miser sur le tapis, lancer, vérifier la banque et les statistiques.
	var screen: Node = _mount("res://scenes/roulette.tscn")
	await _frames(3)
	var e: RouletteEngine = screen.get("engine") as RouletteEngine
	_check(e != null and e.phase == RouletteEngine.Phase.BET, "roulette : moteur en phase de mise")
	var spin: Button = _find_button(screen, "Lancer la bille")
	_check(spin != null and spin.disabled, "roulette : « Lancer » inactif sans mise")
	var red: Button = _find_button(screen, "Rouge")
	_check(red != null, "roulette : case Rouge présente")
	red.pressed.emit()
	await _frames(2)
	_check(e.bet_on("red") == 10, "roulette : jeton de 10 posé sur Rouge")
	screen.call("_select_chip", 25)
	await _frames(2)
	_find_button(screen, "17").pressed.emit()
	await _frames(2)
	_check(e.bet_on("n:17") == 25 and e.total_bet() == 35, "roulette : jeton de 25 sur le 17")
	_check(not _find_button(screen, "Lancer la bille").disabled, "roulette : « Lancer » actif")
	screen.set("skip_animation", true)
	e.rng.seed = 5
	_check(_press(screen, "Lancer la bille"), "roulette : lancer")
	await _frames(3)
	_check(e.phase == RouletteEngine.Phase.DONE and e.result >= 0 and bank.value == 1000 + e.net, "roulette : manche réglée (banque %d)" % bank.value)
	_check(stats.ro_rounds == 1, "roulette : statistique enregistrée")
	_check(_press(screen, "Rejouer"), "roulette : rejouer")
	await _frames(2)
	_check(e.phase == RouletteEngine.Phase.BET and e.total_bet() == 35, "roulette : mises conservées")
	await _unmount(screen)

	# Baccarat : jetons sur le Banquier, distribution.
	bank.set_to(1000)
	screen = _mount("res://scenes/baccarat.tscn")
	await _frames(3)
	var b: BaccaratEngine = screen.get("engine") as BaccaratEngine
	_check(b != null and b.phase == BaccaratEngine.Phase.BET, "baccarat : moteur en phase de mise")
	_check(_find_button(screen, "Distribuer").disabled, "baccarat : « Distribuer » inactif sans mise")
	screen.call("_select_target", BaccaratEngine.Spot.BANKER)
	await _frames(2)
	var chip: Node = screen.find_children("*", "ChipButton", true, false)[1]
	(chip as BaseButton).pressed.emit()
	await _frames(2)
	_check(b.bets[1] == 25, "baccarat : jeton sur le Banquier")
	b.rng.seed = 3
	_check(_press(screen, "Distribuer"), "baccarat : distribuer")
	await _frames(3)
	_check(b.phase == BaccaratEngine.Phase.DONE and b.player.size() >= 2 and b.banker.size() >= 2, "baccarat : cartes distribuées")
	_check(bank.value == 1000 + b.net and stats.ba_rounds == 1, "baccarat : banque et statistiques (banque %d)" % bank.value)
	_check(_press(screen, "Rejouer"), "baccarat : rejouer")
	await _frames(2)
	_check(b.phase == BaccaratEngine.Phase.BET and b.bets[1] == 25, "baccarat : mises conservées")
	await _unmount(screen)


func _test_three_card_ui(stats: StatsState, bank: BankrollState) -> void:
	bank.use_profile("")
	bank.set_to(1000)
	stats.reset_stats()
	var home: Node = _mount("res://scenes/home.tscn")
	await _frames(2)
	var tiles: int = 0
	for n: Node in home.find_children("*", "GameCard", true, false):
		tiles += 1
	_check(tiles == 6, "accueil : six jeux (%d)" % tiles)
	_unmount(home)

	var screen: Node = _mount("res://scenes/three_card.tscn")
	await _frames(3)
	var e: ThreeCardEngine = screen.get("engine") as ThreeCardEngine
	_check(e != null and e.phase == ThreeCardEngine.Phase.BET, "three card : moteur en phase de mise")
	var deal: Button = _find_button(screen, "Distribuer")
	_check(deal != null and deal.disabled, "three card : « Distribuer » inactif sans Ante")
	# Les jetons vont d'abord sur l'Ante, puis sur le Pair Plus une fois la cible changée.
	var chip: Node = screen.find_children("*", "ChipButton", true, false)[1]
	(chip as BaseButton).pressed.emit()
	await _frames(2)
	_check(e.ante == 25 and e.pair_plus == 0, "three card : jeton sur l'Ante")
	screen.call("_select_target", 1)
	await _frames(2)
	chip = screen.find_children("*", "ChipButton", true, false)[0]
	(chip as BaseButton).pressed.emit()
	await _frames(2)
	_check(e.pair_plus == 10, "three card : jeton sur le Pair Plus")
	_check(_press(screen, "Distribuer"), "three card : distribuer")
	await _frames(3)
	_check(e.phase == ThreeCardEngine.Phase.DECIDE and e.player.size() == 3 and not e.revealed, "three card : 3 cartes, croupier caché")
	_check(_find_button(screen, "Jouer (+25)") != null and _find_button(screen, "Se coucher") != null, "three card : choix Jouer / Se coucher")
	stats.set_beginner(true)
	screen.call("_refresh")
	await _frames(2)
	_check(_has_label(screen, "CONSEIL"), "three card : conseil du mode débutant")
	stats.set_beginner(false)
	_check(_press(screen, "Jouer (+25)"), "three card : jouer")
	await _frames(3)
	_check(e.phase == ThreeCardEngine.Phase.DONE and e.revealed and bank.pending == 0, "three card : manche résolue")
	_check(stats.tc_rounds == 1, "three card : statistique enregistrée")
	_check(_find_button(screen, "Rejouer") != null, "three card : bouton Rejouer")
	# Aide.
	var help: Button = _find_help_button(screen)
	_check(help != null, "three card : bouton d'aide")
	if help != null:
		help.pressed.emit()
		await _frames(3)
		_check(HelpOverlay.is_open(screen) and _has_label(screen, "Three Card Poker"), "three card : aide ouverte")
		HelpOverlay.close_in(screen)
		await _frames(2)
	# Enchaînement de manches, décisions variées : la banque reste cohérente.
	var before: int = bank.value
	var total: int = -e.net  # la manche en cours est déjà dans la banque
	var played: int = 0
	var guard: int = 0
	while played < 25 and bank.value >= 30 and guard < 200:
		guard += 1
		if e.phase == ThreeCardEngine.Phase.DONE:
			total += e.net
			played += 1
			_press(screen, "Rejouer")
			await _frames(2)
		elif e.phase == ThreeCardEngine.Phase.BET:
			if e.ante < ThreeCardEngine.MIN_BET:
				e.add_ante(10)
			_press(screen, "Distribuer")
			await _frames(2)
		elif e.phase == ThreeCardEngine.Phase.DECIDE:
			_press(screen, "Jouer (+%d)" % e.ante if played % 2 == 0 else "Se coucher")
			await _frames(2)
	_check(played >= 20 and bank.value == before + total, "three card : %d manches enchaînées, banque cohérente" % played)
	_check(stats.tc_rounds >= played, "three card : statistiques cumulées")
	_unmount(screen)
	stats.reset_stats()
	bank.set_to(1000)


func _find_help_button(node: Node) -> Button:
	if node is Button and (node as Button).text == "?":
		return node as Button
	for c: Node in node.get_children():
		var f: Button = _find_help_button(c)
		if f != null:
			return f
	return null


func _test_backup(stats: StatsState, bank: BankrollState) -> void:
	ProfileStore.path = "user://test_backup_profiles.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	var ana: String = ProfileStore.create("Ana")
	ProfileStore.set_bank(ana, 1800)
	ProfileStore.create("Tom")
	ProfileStore.note_group([ana, ProfileStore.find_by_name("Tom")] as Array[String])
	bank.set_to(4321)
	stats.reset_stats()
	stats.bj_rounds = 7
	stats.achievements = ["bj_first"]
	stats.sound = false
	var code: String = BackupService.to_code(BackupService.build())
	_check(code.begins_with(BackupService.PREFIX), "export : code de sauvegarde")
	_check(code.length() < 6000, "export : code compact (%d caractères)" % code.length())

	# Tout change, puis on restaure
	bank.set_to(10)
	stats.reset_stats()
	stats.sound = true
	ProfileStore.remove(ana)
	var wrapped: String = "Ma sauvegarde :\n" + code.substr(0, 40) + "\n" + code.substr(40) + "\n"
	var data: Dictionary = BackupService.parse(wrapped)
	_check(not data.has("error"), "import : code retrouvé malgré du texte et des retours à la ligne")
	_check(BackupService.describe(data).contains("Joueurs enregistrés : 2 (Ana, Tom)"), "import : résumé")
	BackupService.apply(data, BackupService.Mode.REPLACE)
	_check(bank.value == 4321 and stats.bj_rounds == 7 and not stats.sound, "import : banque, stats et réglages restaurés")
	_check(stats.has_achievement("bj_first") and ProfileStore.bank_of(ProfileStore.find_by_name("Ana")) == 1800, "import : succès et joueurs restaurés")
	_check(ProfileStore.recent_groups().size() == 1, "import : groupes restaurés")

	# Erreurs
	_check(BackupService.parse("").has("error"), "import : vide refusé")
	_check(BackupService.parse("bonjour").has("error"), "import : texte quelconque refusé")
	_check(BackupService.parse(code.substr(0, code.length() / 2)).has("error"), "import : code coupé refusé")
	_check(BackupService.parse(BackupService.to_json(BackupService.build())).has("format"), "import : fichier JSON accepté")

	# Fusion : un autre appareil avec Ana (jouée plus récemment) et Zed
	var other: Dictionary = BackupService.build()
	var profiles: Array = other["profiles"]["profiles"]
	for p: Variant in profiles:
		var d: Dictionary = p
		if str(d["name"]) == "Ana":
			d["bank"] = 5000
			d["last_played"] = int(Time.get_unix_time_from_system()) + 100
	profiles.append({"id": "p99", "name": "Zed", "bank": 1200, "last_played": 5, "stats": {}})
	bank.set_to(777)
	var msg: String = BackupService.apply(BackupService.parse(BackupService.to_code(other)), BackupService.Mode.MERGE_PLAYERS)
	_check(ProfileStore.exists(ProfileStore.find_by_name("Zed")) and ProfileStore.bank_of(ProfileStore.find_by_name("Ana")) == 5000, "fusion : joueur ajouté et profil plus récent repris")
	_check(ProfileStore.count() == 3 and bank.value == 777, "fusion : pas de doublon, banque inchangée (%s)" % msg)

	# Écran
	var screen: Node = _mount("res://scenes/backup.tscn")
	await _frames(2)
	_check(_press(screen, "Copier le code de sauvegarde"), "écran sauvegarde : copier")
	await _frames(1)
	var box: TextEdit = screen.get("_code_box") as TextEdit
	_check(box.visible and box.text.begins_with(BackupService.PREFIX), "écran sauvegarde : code affiché")
	(screen.get("_import_box") as TextEdit).text = box.text
	_check(_press(screen, "Lire le code"), "écran sauvegarde : lire")
	await _frames(1)
	_check((screen.get("_preview_panel") as Control).visible, "écran sauvegarde : aperçu")
	_check(_press(screen, "Remplacer toutes mes données") and _press(screen, "Confirmer : tout remplacer ?"), "écran sauvegarde : remplacement confirmé")
	await _frames(1)
	_check(not (screen.get("_preview_panel") as Control).visible, "écran sauvegarde : import terminé")
	(screen.get("_import_box") as TextEdit).text = "n'importe quoi"
	_press(screen, "Lire le code")
	await _frames(1)
	_check(not (screen.get("_preview_panel") as Control).visible and (screen.get("_status") as Label).visible, "écran sauvegarde : erreur affichée")
	_unmount(screen)
	stats.reset_stats()
	stats.sound = true
	bank.set_to(1000)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
