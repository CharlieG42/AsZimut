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

	await _test_home(bank)
	await _test_blackjack(bank)
	await _test_poker(bank)

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
		_check(_press(screen, "+25"), "bouton +25")
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
			if hands_done % 4 == 1:
				acted = _press(screen, "Pot")
			elif hands_done % 7 == 3:
				acted = _press(screen, "Tapis")
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
