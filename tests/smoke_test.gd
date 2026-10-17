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

	await _test_home(bank)
	await _test_stats(stats)
	await _test_blackjack(bank)
	await _test_poker(bank)
	await _test_setup()
	await _test_multi_blackjack()
	await _test_multi_poker()

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
