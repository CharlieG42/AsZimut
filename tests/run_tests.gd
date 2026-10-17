extends SceneTree
## Tests logiques (sans interface). Lancement :
##   godot --headless --path . --script res://tests/run_tests.gd
## Code de sortie 0 si tout passe, 1 sinon.

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_test_cards()
	_test_evaluator_known_hands()
	_test_evaluator_matches_reference()
	_test_chen()
	_test_blackjack_values()
	_test_blackjack_simulation()
	_test_poker_simulation()
	print("")
	print("%d vérifications, %d échec(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("ÉCHEC : " + label)


func _c(rank: int, suit: int) -> int:
	return Cards.make(rank, suit)


func _ai(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in values:
		out.append(int(v))
	return out


func _hand(spec: Array) -> Array[int]:
	var out: Array[int] = []
	for pair: Array in spec:
		out.append(Cards.make(int(pair[0]), int(pair[1])))
	return out


# --- Cartes -------------------------------------------------------------------


func _test_cards() -> void:
	var deck: Array[int] = Cards.full_deck()
	_check(deck.size() == 52, "deck de 52 cartes")
	var seen: Dictionary = {}
	for c: int in deck:
		seen[Cards.make(Cards.rank_of(c), Cards.suit_of(c))] = true
	_check(seen.size() == 52, "make/rank_of/suit_of cohérents")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var shuffled: Array[int] = Cards.shuffled_deck(rng)
	var sorted_copy: Array[int] = shuffled.duplicate()
	sorted_copy.sort()
	_check(sorted_copy == deck, "le mélange conserve les 52 cartes")
	_check(Cards.rank_label(_c(14, Cards.Suit.SPADES)) == "A", "libellé As")
	_check(Cards.rank_label(_c(10, Cards.Suit.HEARTS)) == "10", "libellé 10")
	_check(Cards.is_red(_c(2, Cards.Suit.DIAMONDS)), "carreau est rouge")
	_check(not Cards.is_red(_c(2, Cards.Suit.CLUBS)), "trèfle est noir")


# --- Évaluateur ---------------------------------------------------------------


func _test_evaluator_known_hands() -> void:
	var S: int = Cards.Suit.SPADES
	var H: int = Cards.Suit.HEARTS
	var D: int = Cards.Suit.DIAMONDS
	var C: int = Cards.Suit.CLUBS
	var royal: Array[int] = HandEvaluator.evaluate5(
		_hand([[14, S], [13, S], [12, S], [11, S], [10, S]])
	)
	_check(royal == _ai([8, 14]), "quinte flush royale")
	_check(HandEvaluator.hand_name(royal) == "Quinte flush royale", "nom quinte flush royale")
	var wheel: Array[int] = HandEvaluator.evaluate5(_hand([[14, S], [2, H], [3, D], [4, C], [5, S]]))
	_check(wheel == _ai([4, 5]), "quinte roue A-5")
	var quads: Array[int] = HandEvaluator.evaluate5(_hand([[9, S], [9, H], [9, D], [9, C], [4, S]]))
	_check(quads == _ai([7, 9, 4]), "carré")
	var full: Array[int] = HandEvaluator.evaluate5(_hand([[9, S], [9, H], [9, D], [4, C], [4, S]]))
	_check(full == _ai([6, 9, 4]), "full")
	var pair: Array[int] = HandEvaluator.evaluate5(_hand([[9, S], [9, H], [13, D], [4, C], [2, S]]))
	_check(pair == _ai([1, 9, 13, 4, 2]), "paire")
	var high: Array[int] = HandEvaluator.evaluate5(_hand([[14, S], [9, H], [7, D], [4, C], [2, S]]))
	_check(high[0] == 0, "hauteur")
	_check(HandEvaluator.cmp_score(royal, quads) > 0, "quinte flush > carré")
	_check(HandEvaluator.cmp_score(pair, pair) == 0, "égalité")
	# 7 cartes : full house caché parmi sept cartes
	var seven: Array[int] = HandEvaluator.evaluate7(
		_hand([[9, S], [9, H], [9, D], [4, C], [4, S], [13, H], [2, D]])
	)
	_check(seven == _ai([6, 9, 4]), "full parmi 7 cartes")
	# Deux brelans → full avec le plus petit brelan en paire
	var two_trips: Array[int] = HandEvaluator.evaluate7(
		_hand([[9, S], [9, H], [9, D], [5, C], [5, S], [5, H], [2, D]])
	)
	_check(two_trips == _ai([6, 9, 5]), "deux brelans → full")


func _test_evaluator_matches_reference() -> void:
	# La version rapide doit donner le même résultat que le meilleur des 21 sous-mains.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var combos: Array = []
	for a: int in 7:
		for b: int in range(a + 1, 7):
			for c: int in range(b + 1, 7):
				for d: int in range(c + 1, 7):
					for e: int in range(d + 1, 7):
						combos.append([a, b, c, d, e])
	var mismatches: int = 0
	var categories: Dictionary = {}
	for _i: int in 6000:
		var deck: Array[int] = Cards.shuffled_deck(rng)
		var seven: Array[int] = []
		for k: int in 7:
			seven.append(deck[k])
		var best: Array[int] = []
		for idx: Array in combos:
			var five: Array[int] = []
			for k: int in idx:
				five.append(seven[int(k)])
			var sc: Array[int] = HandEvaluator.evaluate5(five)
			if best.is_empty() or HandEvaluator.cmp_score(sc, best) > 0:
				best = sc
		var fast: Array[int] = HandEvaluator.evaluate7(seven)
		categories[fast[0]] = int(categories.get(fast[0], 0)) + 1
		if fast != best:
			mismatches += 1
			if mismatches <= 3:
				printerr("  écart : mains=%s rapide=%s ref=%s" % [str(seven), str(fast), str(best)])
	_check(mismatches == 0, "evaluate7 identique à la référence (6000 mains, écarts : %d)" % mismatches)
	_check(categories.size() >= 6, "toutes les grandes catégories rencontrées (%d)" % categories.size())


func _test_chen() -> void:
	var S: int = Cards.Suit.SPADES
	var H: int = Cards.Suit.HEARTS
	_check(PokerAI.chen(_c(14, S), _c(14, H)) == 20, "Chen AA = 20")
	_check(PokerAI.chen(_c(14, S), _c(13, S)) == 12, "Chen AKs = 12")
	_check(PokerAI.chen(_c(7, S), _c(2, H)) == 0, "Chen 72o = 0")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var aces: Array[int] = [_c(14, S), _c(14, H)]
	var empty_board: Array[int] = []
	var p_aa: float = PokerAI.win_prob(aces, empty_board, 300, rng)
	_check(p_aa > 0.75, "AA gagne souvent (%.2f)" % p_aa)
	var trash: Array[int] = [_c(7, S), _c(2, H)]
	var p_72: float = PokerAI.win_prob(trash, empty_board, 300, rng)
	_check(p_72 < 0.45, "72o gagne rarement (%.2f)" % p_72)


# --- Blackjack ----------------------------------------------------------------


func _test_blackjack_values() -> void:
	var S: int = Cards.Suit.SPADES
	var H: int = Cards.Suit.HEARTS
	_check(BlackjackEngine.bj_value(_hand([[14, S], [13, H]])) == 21, "A+K = 21")
	_check(BlackjackEngine.bj_value(_hand([[14, S], [14, H]])) == 12, "A+A = 12")
	_check(BlackjackEngine.bj_value(_hand([[14, S], [9, H], [5, S]])) == 15, "A+9+5 = 15")
	_check(BlackjackEngine.bj_value(_hand([[10, S], [9, H], [5, S]])) == 24, "10+9+5 = 24")


func _test_blackjack_simulation() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var bank: BankrollState = BankrollState.new()
	bank.persist = false
	bank.value = 1000
	var engine: BlackjackEngine = BlackjackEngine.new(bank)
	engine.rng.seed = 5
	var ok: bool = true
	for _round: int in 400:
		if bank.value < 10:
			bank.set_to(1000)
		engine.bet = 0
		engine.add_to_bet(10 * (1 + rng.randi() % 5))
		if engine.bet < 10:
			engine.add_to_bet(10)
		var before: int = bank.value
		engine.deal()
		if engine.phase == BlackjackEngine.Phase.BET:
			ok = false
			break
		var guard: int = 0
		while engine.phase == BlackjackEngine.Phase.PLAYER and guard < 30:
			guard += 1
			var pick: int = rng.randi() % 3
			if pick == 0:
				engine.hit()
			elif pick == 1:
				engine.stand()
			else:
				engine.double_down()
		if engine.phase == BlackjackEngine.Phase.DEALER:
			engine.dealer_plays()
		if engine.phase != BlackjackEngine.Phase.DONE or engine.message == "":
			ok = false
			break
		# La banque ne peut varier que dans [-2*mise, +1.5*mise] autour de l'état initial.
		var delta: int = bank.value - before
		if delta < -engine.bet or delta > roundi(engine.bet * 1.5):
			ok = false
			printerr("  delta=%d mise=%d msg=%s" % [delta, engine.bet, engine.message])
			break
		engine.replay()
	_check(ok, "simulation blackjack (400 tours) cohérente")
	_check(bank.value >= 0, "banque jamais négative")
	bank.free()


# --- Poker --------------------------------------------------------------------


func _test_poker_simulation() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2024
	var engine: PokerEngine = PokerEngine.new(1000)
	engine.rng.seed = 77
	var violations: int = 0
	var hands: int = 150
	var finished: int = 0
	for h: int in hands:
		if engine.p_stack <= 0:
			engine.p_stack = 1000
		if h > 0:
			engine.start_hand(false)
		var total: int = engine.p_stack + engine.a_stack + engine.pot
		var steps: int = 0
		while not engine.is_over() and steps < 120:
			steps += 1
			if engine.is_player_turn():
				var pick: int = rng.randi() % 10
				if pick < 5:
					engine.check_call(PokerEngine.Actor.PLAYER)
				elif pick < 8:
					engine.bet_raise(PokerEngine.Actor.PLAYER, engine.pot_size_bet())
				elif pick == 8:
					engine.bet_raise(PokerEngine.Actor.PLAYER, engine.p_bet + engine.p_stack)
				else:
					engine.fold(PokerEngine.Actor.PLAYER)
			elif engine.to_act == PokerEngine.Actor.AI:
				engine.ai_act()
			elif engine.runout:
				engine.advance_street()
			else:
				violations += 1
				printerr("  état bloqué : street=%d to_act=%d" % [engine.street, engine.to_act])
				break
			var now: int = engine.p_stack + engine.a_stack + engine.pot
			if now != total or engine.p_stack < 0 or engine.a_stack < 0 or engine.pot < 0:
				violations += 1
				printerr("  conservation violée : %d -> %d (street=%d)" % [total, now, engine.street])
				break
		if engine.is_over():
			finished += 1
			if engine.pot != 0:
				violations += 1
				printerr("  pot non vidé en fin de main : %d" % engine.pot)
	_check(violations == 0, "simulation poker : jetons conservés, aucun blocage (%d violations)" % violations)
	_check(finished == hands, "toutes les mains se terminent (%d/%d)" % [finished, hands])
