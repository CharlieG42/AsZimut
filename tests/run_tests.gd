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
	_test_describe()
	_test_chen()
	_test_blackjack_values()
	_test_blackjack_simulation()
	_test_poker_simulation()
	_test_poker_difficulty()
	_test_raise_bounds()
	_test_table_side_pots()
	_test_table_flow()
	_test_table_simulation()
	_test_multi_blackjack()
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
	var counters: Dictionary = {"finished": 0, "net": 0}
	engine.round_finished.connect(
		func(_o: BlackjackEngine.Outcome, n: int) -> void:
			counters["finished"] = int(counters["finished"]) + 1
			counters["net"] = int(counters["net"]) + n
	)
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
		# Le gain net annoncé est exactement la variation de la banque.
		var delta: int = bank.value - before
		if delta != engine.net or engine.outcome == BlackjackEngine.Outcome.NONE:
			ok = false
			printerr("  delta=%d net=%d mise=%d msg=%s" % [delta, engine.net, engine.bet, engine.message])
			break
		engine.replay()
	_check(ok, "simulation blackjack (400 tours) cohérente")
	_check(int(counters["finished"]) == 400, "un signal round_finished par manche (%d)" % int(counters["finished"]))
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
	var sig: Dictionary = {"n": 0}
	engine.hand_finished.connect(
		func(_o: PokerEngine.HandOutcome, _n: int, _p: int) -> void: sig["n"] = int(sig["n"]) + 1
	)
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
			if engine.last_net != engine.p_stack - engine.hand_start_stack:
				violations += 1
				printerr("  gain net incohérent : %d vs %d" % [engine.last_net, engine.p_stack - engine.hand_start_stack])
			if engine.pot != 0:
				violations += 1
				printerr("  pot non vidé en fin de main : %d" % engine.pot)
	_check(violations == 0, "simulation poker : jetons conservés, aucun blocage (%d violations)" % violations)
	_check(finished == hands, "toutes les mains se terminent (%d/%d)" % [finished, hands])
	_check(int(sig["n"]) == hands, "un signal hand_finished par main (%d/%d)" % [int(sig["n"]), hands])


# --- Nouveautés ------------------------------------------------------------------


func _test_describe() -> void:
	var S: int = Cards.Suit.SPADES
	var H: int = Cards.Suit.HEARTS
	var D: int = Cards.Suit.DIAMONDS
	var C: int = Cards.Suit.CLUBS
	var cases: Array = [
		[[[13, S], [13, H], [9, D], [5, C], [2, S]], "Paire de Rois"],
		[[[14, S], [14, H], [9, D], [5, C], [2, S]], "Paire d'As"],
		[[[7, S], [7, H], [7, D], [5, C], [2, S]], "Brelan de 7"],
		[[[12, S], [11, H], [10, D], [9, C], [8, S]], "Quinte à la Dame"],
		[[[14, S], [13, S], [9, S], [5, S], [2, S]], "Couleur à l'As"],
		[[[9, S], [9, H], [9, D], [4, C], [4, S]], "Full 9 par 4"],
		[[[14, S], [14, H], [14, D], [14, C], [2, S]], "Carré d'As"],
		[[[14, S], [13, S], [12, S], [11, S], [10, S]], "Quinte flush royale"],
		[[[14, S], [9, H], [7, D], [4, C], [2, S]], "Hauteur As"],
		[[[13, S], [13, H], [4, D], [4, C], [2, S]], "Double paire Rois et 4"],
	]
	for case: Array in cases:
		var got: String = HandEvaluator.describe(HandEvaluator.evaluate5(_hand(case[0])))
		_check(got == String(case[1]), "describe : « %s » attendu, obtenu « %s »" % [case[1], got])
	# Avec moins de 5 cartes (pré-flop), l'évaluation reste utilisable.
	var preflop: Array[int] = HandEvaluator.evaluate7(_hand([[13, S], [13, H]]))
	_check(HandEvaluator.describe(preflop) == "Paire de Rois", "describe pré-flop : paire de Rois")


func _test_poker_difficulty() -> void:
	_check(PokerEngine.PROFILES.size() == 3, "trois niveaux de ZIA")
	_check(PokerEngine.difficulty_name(0) == "Facile", "nom du niveau 0")
	_check(PokerEngine.difficulty_name(2) == "Difficile", "nom du niveau 2")
	# Chaque niveau joue des mains complètes sans blocage.
	for level: int in 3:
		var engine: PokerEngine = PokerEngine.new(1000, level)
		engine.rng.seed = 500 + level
		_check(engine.difficulty == level, "niveau %d appliqué" % level)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 900 + level
		var done: int = 0
		for h: int in 25:
			if engine.p_stack <= 0:
				engine.p_stack = 1000
			if h > 0:
				engine.start_hand(false)
			var steps: int = 0
			while not engine.is_over() and steps < 120:
				steps += 1
				if engine.is_player_turn():
					if rng.randf() < 0.7:
						engine.check_call(PokerEngine.Actor.PLAYER)
					else:
						engine.bet_raise(PokerEngine.Actor.PLAYER, engine.pot_size_bet())
				elif engine.to_act == PokerEngine.Actor.AI:
					engine.ai_act()
				elif engine.runout:
					engine.advance_street()
				else:
					break
			if engine.is_over():
				done += 1
		_check(done == 25, "niveau %d : 25 mains terminées (%d)" % [level, done])
	# Un niveau hors bornes est ramené dans la plage.
	_check(PokerEngine.new(1000, 99).difficulty == 2, "niveau borné à 2")


func _test_raise_bounds() -> void:
	var engine: PokerEngine = PokerEngine.new(1000)
	engine.rng.seed = 11
	# Après les blinds, le joueur doit au moins doubler la grosse blinde.
	var mn: int = engine.min_raise_to(PokerEngine.Actor.PLAYER)
	var mx: int = engine.max_raise_to(PokerEngine.Actor.PLAYER)
	_check(mn >= PokerEngine.BB, "relance minimale ≥ grosse blinde (%d)" % mn)
	_check(mx == engine.p_bet + engine.p_stack, "relance maximale = tapis (%d)" % mx)
	_check(mn <= mx, "min ≤ max")
	# Relancer à une valeur trop faible est ramené au minimum ; trop forte, au tapis.
	if engine.is_player_turn():
		var before: int = engine.p_bet
		engine.bet_raise(PokerEngine.Actor.PLAYER, 1)
		_check(engine.p_bet >= mn or engine.p_bet == mx, "relance trop faible relevée au minimum")
		_check(engine.p_bet > before, "la relance augmente la mise")


# --- Poker à table (multijoueur local) -----------------------------------------


func _names(n: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in n:
		out.append("J%d" % (i + 1))
	return out


## Prépare une main figée : mains/board donnés, `totals` déjà engagés, `folded` couchés.
func _rig(totals: Array, holes: Array, folded: Array = []) -> PokerTableEngine:
	var e: PokerTableEngine = PokerTableEngine.new(_names(totals.size()), 1000)
	e.start_hand()
	e.button = 0
	e.board = _hand([[2, 0], [7, 1], [9, 2], [11, 3], [4, 0]])
	for i: int in totals.size():
		var s: PokerTableEngine.Seat = e.seats[i]
		s.hole = _hand(holes[i])
		s.stack = 1000 - int(totals[i])
		s.total = int(totals[i])
		s.bet = 0
		s.folded = folded.has(i)
		s.start_stack = 1000
	return e


func _test_table_side_pots() -> void:
	# A (AA) tapis 100, B (KK) et C (QQ) 300 : A prend le principal (300), B le pot annexe (400).
	var e: PokerTableEngine = _rig(
		[100, 300, 300],
		[[[14, 1], [14, 2]], [[13, 1], [13, 2]], [[12, 1], [12, 2]]]
	)
	e.showdown()
	_check(e.seats[0].stack == 900 + 300, "pot principal à A")
	_check(e.seats[1].stack == 700 + 400, "pot annexe à B")
	_check(e.seats[2].stack == 700, "C ne gagne rien")
	_check(e.seats[0].stack + e.seats[1].stack + e.seats[2].stack == 3000, "jetons conservés (pots annexes)")

	# Mise non suivie : A mise 200, B tapis 50, C couché → A récupère l'excédent.
	e = _rig(
		[200, 50, 30],
		[[[14, 1], [14, 2]], [[13, 1], [13, 2]], [[12, 1], [12, 2]]],
		[2]
	)
	e.showdown()
	_check(e.seats[0].stack == 800 + 280, "A gagne tout (mise non suivie rendue)")
	_check(e.seats[1].stack == 950, "B perd son tapis")

	# Égalité parfaite à deux + 1 jeton mort d'un joueur couché : le jeton impair va au
	# premier gagnant après le donneur (J2, le donneur étant J1).
	e = _rig(
		[100, 100, 1],
		[[[13, 1], [12, 1]], [[13, 2], [12, 2]], [[3, 0], [5, 3]]],
		[2]
	)
	e.showdown()
	_check(e.seats[0].stack + e.seats[1].stack + e.seats[2].stack == 3000, "égalité : jetons conservés")
	_check(e.seats[1].stack == 1001, "jeton impair au premier après le donneur")
	_check(e.seats[0].stack == 1000, "l'autre reçoit la moitié")

	# Pot disputé entre deux mains égales et une meilleure couchée : le couché ne gagne pas.
	e = _rig(
		[100, 100, 100],
		[[[14, 1], [14, 2]], [[13, 1], [13, 2]], [[12, 1], [12, 2]]],
		[0]
	)
	e.showdown()
	_check(e.seats[0].stack == 900, "un joueur couché ne gagne jamais")
	_check(e.seats[1].stack == 900 + 300, "meilleure main restante gagne")


func _test_table_flow() -> void:
	var e: PokerTableEngine = PokerTableEngine.new(_names(3), 1000)
	e.rng.seed = 7
	e.start_hand()
	_check(e.seats[e.button].label == "D", "donneur identifié")
	_check(e.pot() == 30, "blinds 10/20 postées")
	_check(e.to_act == (e.button + 3) % 3, "premier à parler : après la grosse blind")
	e.fold()
	e.fold()
	_check(e.hand_over, "main finie quand tous sauf un se couchent")
	var total: int = 0
	for s: PokerTableEngine.Seat in e.seats:
		total += s.stack
	_check(total == 3000 and e.pot() == 0, "jetons conservés après abandon des autres")

	# Heads-up : le donneur est petite blind et parle en premier pré-flop.
	var h: PokerTableEngine = PokerTableEngine.new(_names(2), 1000)
	h.rng.seed = 3
	h.start_hand()
	_check(h.to_act == h.button, "heads-up : le donneur parle en premier")
	h.check_call()
	_check(h.to_act != h.button and not h.hand_over, "la grosse blind a l'option")
	h.check_call()
	_check(h.street == PokerTableEngine.Street.FLOP and h.board.size() == 3, "flop après les enchères")
	_check(h.to_act != h.button, "heads-up : le non-donneur parle en premier après le flop")

	# Tapis contre tapis : le board se déroule seul.
	var a: PokerTableEngine = PokerTableEngine.new(_names(2), 500)
	a.rng.seed = 11
	a.start_hand()
	a.raise_to(500)
	a.check_call()
	_check(a.runout or a.hand_over, "all-in : déroulé automatique")
	var guard: int = 0
	while not a.hand_over and guard < 10:
		guard += 1
		a.advance_street()
	_check(a.hand_over and a.board.size() == 5, "all-in : 5 cartes au board et main terminée")
	_check(a.seats[0].stack + a.seats[1].stack == 1000, "all-in : jetons conservés")

	# Relance minimale
	var r: PokerTableEngine = PokerTableEngine.new(_names(3), 1000)
	r.rng.seed = 5
	r.start_hand()
	_check(r.min_raise_to(r.to_act) == 40, "relance minimale pré-flop = 2 grosses blinds")
	r.raise_to(100)
	_check(r.current_bet == 100 and r.min_raise == 80, "relance à 100 : incrément 80")
	_check(r.min_raise_to(r.to_act) == 180, "contre-relance minimale")


func _random_action(e: PokerTableEngine, r: RandomNumberGenerator) -> void:
	var i: int = e.to_act
	var roll: float = r.randf()
	if roll < 0.12 and not e.can_check(i):
		e.fold()
	elif roll < 0.35 and e.can_raise(i):
		var lo: int = e.min_raise_to(i)
		var hi: int = e.max_raise_to(i)
		e.raise_to(r.randi_range(lo, hi) if r.randf() < 0.7 else hi)
	else:
		e.check_call()


func _test_table_simulation() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 2024
	var games_finished: int = 0
	var bad_total: int = 0
	var stuck: int = 0
	for game: int in 40:
		var n: int = 2 + game % 5
		var e: PokerTableEngine = PokerTableEngine.new(_names(n), 400)
		e.rng.seed = 100 + game
		var hands: int = 0
		while not e.is_game_over() and hands < 400:
			hands += 1
			e.start_hand()
			var steps: int = 0
			while not e.hand_over and steps < 300:
				steps += 1
				if e.to_act >= 0:
					_random_action(e, r)
				else:
					e.advance_street()
				var sum: int = e.pot()
				for s: PokerTableEngine.Seat in e.seats:
					sum += s.stack
					if s.stack < 0:
						bad_total += 1
				if sum != e.total_chips:
					bad_total += 1
			if not e.hand_over:
				stuck += 1
				break
		if e.is_game_over():
			games_finished += 1
			var order: Array[int] = e.standings()
			_check(order.size() == n and e.seats[order[0]].stack == e.total_chips, "vainqueur unique avec tous les jetons (partie %d)" % game)
	_check(bad_total == 0, "jetons conservés à chaque étape (%d anomalies)" % bad_total)
	_check(stuck == 0, "aucune main bloquée (%d)" % stuck)
	_check(games_finished >= 30, "les parties se terminent (%d/40)" % games_finished)

	# Abandon en pleine main : mises rendues.
	var e2: PokerTableEngine = PokerTableEngine.new(_names(3), 1000)
	e2.start_hand()
	e2.raise_to(200)
	e2.abort()
	var total: int = 0
	for s: PokerTableEngine.Seat in e2.seats:
		total += s.stack
	_check(total == 3000 and e2.is_game_over(), "abandon : mises rendues")


# --- Blackjack multijoueur ------------------------------------------------------


func _test_multi_blackjack() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 99
	var anomalies: int = 0
	for game: int in 30:
		var n: int = 1 + game % 5
		var e: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(n), 300)
		e.rng.seed = 500 + game
		var rounds: int = 0
		while not e.is_game_over() and rounds < 60:
			rounds += 1
			var guard: int = 0
			while e.phase == MultiBlackjackEngine.Phase.BET and guard < 20:
				guard += 1
				var s: MultiBlackjackEngine.Seat = e.seats[e.current]
				if s.bet < MultiBlackjackEngine.MIN_BET:
					e.add_to_bet(mini(10 * r.randi_range(1, 5), s.stack))
				e.confirm_bet()
			guard = 0
			while e.phase == MultiBlackjackEngine.Phase.PLAY and guard < 100:
				guard += 1
				var roll: float = r.randf()
				if roll < 0.15 and e.can_double():
					e.double_down()
				elif roll < 0.6 and BlackjackEngine.bj_value(e.seats[e.current].hand) < 17:
					e.hit()
				else:
					e.stand()
			if e.phase != MultiBlackjackEngine.Phase.DEALER:
				anomalies += 1
				break
			e.dealer_plays()
			for s: MultiBlackjackEngine.Seat in e.seats:
				if s.ready:
					var delta: int = s.net
					var v: int = BlackjackEngine.bj_value(s.hand)
					if s.result == BlackjackEngine.Outcome.NONE or (s.result == BlackjackEngine.Outcome.LOSE and delta != -s.bet) or v < 0:
						anomalies += 1
				if s.stack < 0:
					anomalies += 1
			e.next_round()
	_check(anomalies == 0, "blackjack multi : manches cohérentes (%d anomalies)" % anomalies)

	# Règles chiffrées : joueur 1 blackjack, joueur 2 bat le croupier, joueur 3 perd.
	var e: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(3), 1000)
	for seat: MultiBlackjackEngine.Seat in e.seats:
		seat.bet = 100
		seat.ready = true
		seat.stack -= 100
	e.seats[0].hand = _hand([[14, 0], [13, 1]])
	e.seats[1].hand = _hand([[10, 0], [9, 1]])
	e.seats[2].hand = _hand([[10, 0], [6, 1]])
	for seat: MultiBlackjackEngine.Seat in e.seats:
		seat.done = true
	e.dealer = _hand([[10, 2], [8, 3]])
	e.phase = MultiBlackjackEngine.Phase.DEALER
	e.dealer_plays()
	_check(e.seats[0].stack == 900 + 250 and e.seats[0].result == BlackjackEngine.Outcome.BLACKJACK, "blackjack payé 3:2")
	_check(e.seats[1].stack == 900 + 200 and e.seats[1].result == BlackjackEngine.Outcome.WIN, "19 bat 18")
	_check(e.seats[2].stack == 900 and e.seats[2].result == BlackjackEngine.Outcome.LOSE, "16 perd contre 18")

	# Ordre des tours : les mises puis le jeu passent d'un joueur au suivant.
	var t: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(3), 500)
	t.rng.seed = 1
	_check(t.current == 0, "J1 mise en premier")
	t.add_to_bet(50)
	t.confirm_bet()
	_check(t.current == 1 and t.seats[0].stack == 450, "mise validée puis J2")
	t.add_to_bet(25)
	t.confirm_bet()
	t.add_to_bet(10)
	t.confirm_bet()
	_check(t.phase != MultiBlackjackEngine.Phase.BET and t.seats[2].hand.size() == 2, "cartes distribuées après la dernière mise")
