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
	GameSave.path = "user://test_resume.json"
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
	_check(_press(screen, "Difficile"), "choix du niveau Difficile")
	await _frames(2)
	_check(stats.difficulty == 2, "difficulté enregistrée")
	_check(_find_button(screen, "Confirmer l'effacement ?") == null, "pas de confirmation au départ")
	_check(_press(screen, "Réinitialiser les stats"), "bouton réinitialiser")
	await _frames(2)
	_check(stats.bj_rounds == 2, "premier appui : rien n'est effacé")
	_check(_press(screen, "Confirmer l'effacement ?"), "bouton confirmer")
	await _frames(2)
	_check(stats.bj_rounds == 0 and stats.pk_hands == 0, "stats effacées")
	_check(stats.difficulty == 2, "réglages conservés après effacement")
	stats.set_difficulty(1)
	await _unmount(screen)


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
		while engine.phase == MultiBlackjackEngine.Phase.PLAY and guard < 40:
			guard += 1
			var who: int = engine.current
			var value: int = BlackjackEngine.bj_value(engine.seats[who].hand)
			if value < 15 and _press(screen, "Carte"):
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
	for _i: int in 5:
		_check(_press(tuto, "Suivant"), "page suivante")
		await _frames(2)
		seen.append(title.text)
	_check(seen.has("Blackjack") and seen.has("Poker") and seen.has("Dutch"), "pages Blackjack, Poker et Dutch")
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
	_check(_find_label_text(opt, "Annonce gagnante"), "Options : liste des succès")
	var charts: int = 0
	for n: Node in opt.find_children("*", "BankChart", true, false):
		charts += 1
	_check(charts == 1, "Options : courbe de la banque")
	_unmount(opt)
	stats.achievement_unlocked.disconnect(cb)
	stats.reset_stats()
