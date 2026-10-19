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
	_test_blackjack_advisor()
	_test_poker_advisor()
	_test_bots()
	_test_dutch()
	_test_blackjack_split_insurance()
	_test_snapshots()
	_test_pending_refund()
	_test_profiles()
	_test_active_player()
	_test_three_card()
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
	for _round: int in 3000:
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
		if engine.phase == BlackjackEngine.Phase.INSURANCE:
			if rng.randf() < 0.5 and engine.can_insure():
				engine.take_insurance()
			else:
				engine.decline_insurance()
		var guard: int = 0
		while engine.phase == BlackjackEngine.Phase.PLAYER and guard < 30:
			guard += 1
			if engine.can_split() and rng.randf() < 0.7:
				engine.split()
				continue
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
			printerr("  phase=%d msg=%s" % [engine.phase, engine.message])
			break
		# Le gain net annoncé est exactement la variation de la banque.
		var delta: int = bank.value - before
		if delta != engine.net or engine.outcome == BlackjackEngine.Outcome.NONE:
			ok = false
			printerr("  delta=%d net=%d mise=%d msg=%s" % [delta, engine.net, engine.bet, engine.message])
			break
		engine.replay()
	_check(ok, "simulation blackjack (3000 tours, split et assurance) cohérente")
	_check(int(counters["finished"]) == 3000, "un signal round_finished par manche (%d)" % int(counters["finished"]))
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


# --- Conseillers et bots --------------------------------------------------------


func _bj_move(hand: Array, up_rank: int, can_double: bool = true) -> BlackjackAdvisor.Move:
	return BlackjackAdvisor.recommend(_hand(hand), _c(up_rank, 2), can_double)


func _test_blackjack_advisor() -> void:
	var H: BlackjackAdvisor.Move = BlackjackAdvisor.Move.HIT
	var S: BlackjackAdvisor.Move = BlackjackAdvisor.Move.STAND
	var D: BlackjackAdvisor.Move = BlackjackAdvisor.Move.DOUBLE
	_check(_bj_move([[10, 0], [6, 1]], 10) == H, "16 contre 10 : tirer")
	_check(_bj_move([[10, 0], [6, 1]], 6) == S, "16 contre 6 : rester")
	_check(_bj_move([[7, 0], [4, 1]], 6) == D, "11 contre 6 : doubler")
	_check(_bj_move([[7, 0], [4, 1]], 14) == H, "11 contre As : tirer")
	_check(_bj_move([[7, 0], [4, 1]], 6, false) == H, "11 sans double : tirer")
	_check(_bj_move([[5, 0], [4, 1]], 5) == D, "9 contre 5 : doubler")
	_check(_bj_move([[5, 0], [4, 1]], 9) == H, "9 contre 9 : tirer")
	_check(_bj_move([[10, 0], [2, 1]], 3) == H, "12 contre 3 : tirer")
	_check(_bj_move([[10, 0], [2, 1]], 5) == S, "12 contre 5 : rester")
	_check(_bj_move([[10, 0], [8, 1]], 14) == S, "18 dur : rester")
	_check(_bj_move([[3, 0], [4, 1]], 10) == H, "7 : tirer")
	_check(_bj_move([[14, 0], [7, 1]], 9) == H, "A+7 (18 souple) contre 9 : tirer")
	_check(_bj_move([[14, 0], [7, 1]], 6) == D, "A+7 contre 6 : doubler")
	_check(_bj_move([[14, 0], [7, 1]], 6, false) == S, "A+7 contre 6 sans double : rester")
	_check(_bj_move([[14, 0], [7, 1]], 7) == S, "A+7 contre 7 : rester")
	_check(_bj_move([[14, 0], [9, 1]], 6) == S, "A+9 : rester")
	_check(_bj_move([[14, 0], [6, 1]], 3) == D, "A+6 contre 3 : doubler")
	_check(_bj_move([[14, 0], [6, 1]], 10) == H, "A+6 contre 10 : tirer")
	_check(BlackjackAdvisor.is_soft(_hand([[14, 0], [6, 1]])), "A+6 est souple")
	_check(not BlackjackAdvisor.is_soft(_hand([[14, 0], [6, 1], [10, 2]])), "A+6+10 est dur")
	_check(BlackjackAdvisor.explain(_hand([[7, 0], [4, 1]]), _c(6, 2), true).begins_with("Doublez"), "explication doubler")
	_check(BlackjackAdvisor.explain(_hand([[10, 0], [8, 1]]), _c(6, 2), true).begins_with("Restez"), "explication rester")
	_check(BlackjackAdvisor.explain(_hand([[10, 0], [6, 1]]), _c(10, 2), true).begins_with("Tirez"), "explication tirer")

	# Les erreurs des bots ne produisent jamais de coup illégal.
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 5
	var legal: bool = true
	for _i: int in 300:
		var hand: Array[int] = [r.randi_range(0, 51), r.randi_range(0, 51)]
		var m: BlackjackAdvisor.Move = BlackjackAdvisor.bot_move(hand, r.randi_range(0, 51), true, 0.5, r)
		if m < 0 or m > 2:
			legal = false
	_check(legal, "coups de bot valides")


func _test_poker_advisor() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 77
	var aces: Dictionary = PokerAdvisor.advise(_hand([[14, 0], [14, 1]]), [] as Array[int], 30, 0, 1, true, r)
	_check(aces["move"] == PokerAdvisor.Move.RAISE, "AA sans mise à payer : miser")
	var trash: Dictionary = PokerAdvisor.advise(_hand([[7, 0], [2, 1]]), [] as Array[int], 100, 80, 1, true, r)
	_check(trash["move"] == PokerAdvisor.Move.FOLD, "72 face à une grosse mise : se coucher")
	var check: Dictionary = PokerAdvisor.advise(_hand([[7, 0], [2, 1]]), [] as Array[int], 30, 0, 1, true, r)
	_check(check["move"] == PokerAdvisor.Move.CHECK, "main faible gratuite : checker")
	var board: Array[int] = _hand([[14, 2], [9, 3], [4, 0]])
	var top: Dictionary = PokerAdvisor.advise(_hand([[14, 0], [14, 1]]), board, 100, 40, 1, true, r)
	_check(top["move"] == PokerAdvisor.Move.RAISE, "brelan d'As : relancer")
	var multi: Dictionary = PokerAdvisor.advise(_hand([[14, 0], [14, 1]]), [] as Array[int], 30, 0, 4, true, r)
	_check(float(multi["equity"]) < float(aces["equity"]), "plus d'adversaires : moins de chances")
	_check(str(aces["text"]).contains("%"), "le conseil indique les chances de gagner")


func _test_bots() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 3
	var bad: int = 0
	var stuck: int = 0
	var finished: int = 0
	for game: int in 24:
		var n: int = 2 + game % 5
		var bots: Array[bool] = []
		for _i: int in n:
			bots.append(true)
		var e: PokerTableEngine = PokerTableEngine.new(_names(n), 300, bots, game % 3)
		e.rng.seed = 900 + game
		var hands: int = 0
		while not e.is_game_over() and hands < 300:
			hands += 1
			e.start_hand()
			var steps: int = 0
			while not e.hand_over and steps < 300:
				steps += 1
				if e.can_act():
					e.bot_act()
				else:
					e.advance_street()
				var sum: int = e.pot()
				for s: PokerTableEngine.Seat in e.seats:
					sum += s.stack
				if sum != e.total_chips:
					bad += 1
			if not e.hand_over:
				stuck += 1
				break
		if e.is_game_over():
			finished += 1
	_check(bad == 0, "bots poker : jetons conservés (%d anomalies)" % bad)
	_check(stuck == 0, "bots poker : aucune main bloquée (%d)" % stuck)
	_check(finished >= 18, "bots poker : les parties se terminent (%d/24)" % finished)

	# Humain + bots : la partie s'arrête quand l'humain n'a plus de jetons.
	var mixed: PokerTableEngine = PokerTableEngine.new(_names(3), 200, [false, true, true] as Array[bool], 0)
	mixed.rng.seed = 12
	_check(mixed.has_humans and mixed.seats[1].is_bot and not mixed.seats[0].is_bot, "sièges humain/bot")
	mixed.seats[0].stack = 0
	mixed.seats[0].out = true
	mixed.hand_over = true
	_check(mixed.is_game_over(), "plus d'humain : fin de partie")

	# Blackjack avec bots seuls.
	var anomalies: int = 0
	for game: int in 15:
		var n2: int = 2 + game % 4
		var bots2: Array[bool] = []
		for _i: int in n2:
			bots2.append(true)
		var b: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(n2), 400, bots2, game % 3)
		b.rng.seed = 40 + game
		var rounds: int = 0
		while not b.is_game_over() and rounds < 40:
			rounds += 1
			var guard: int = 0
			while b.phase == MultiBlackjackEngine.Phase.BET and guard < 20:
				guard += 1
				b.bot_bet()
			guard = 0
			while b.phase == MultiBlackjackEngine.Phase.PLAY and guard < 100:
				guard += 1
				b.bot_play()
			if b.phase != MultiBlackjackEngine.Phase.DEALER:
				anomalies += 1
				break
			b.dealer_plays()
			for s: MultiBlackjackEngine.Seat in b.seats:
				if s.stack < 0:
					anomalies += 1
			b.next_round()
	_check(anomalies == 0, "bots blackjack : manches cohérentes (%d)" % anomalies)
	_check(r.randf() >= 0.0, "fin des tests bots")


func _dutch(n: int, seed_value: int = 1) -> DutchEngine:
	var names: Array[String] = []
	var flags: Array[bool] = []
	for i: int in n:
		names.append("J%d" % i)
		flags.append(false)
	var e: DutchEngine = DutchEngine.new()
	e.setup(names, flags, 1, seed_value)
	return e


func _test_dutch() -> void:
	# Valeurs et pouvoirs
	_check(DutchEngine.card_points(Cards.make(14, 0)) == 1, "dutch : As = 1")
	_check(DutchEngine.card_points(Cards.make(13, Cards.Suit.HEARTS)) == 0, "dutch : roi rouge = 0")
	_check(DutchEngine.card_points(Cards.make(13, Cards.Suit.SPADES)) == 13, "dutch : roi noir = 13")
	_check(DutchEngine.card_points(Cards.make(12, 0)) == 12, "dutch : dame = 12")
	_check(DutchEngine.power_of(Cards.make(7, 0)) == DutchEngine.Power.PEEK_OWN, "dutch : 7 regarde")
	_check(DutchEngine.power_of(Cards.make(10, 0)) == DutchEngine.Power.PEEK_OTHER, "dutch : 10 espionne")
	_check(DutchEngine.power_of(Cards.make(11, 0)) == DutchEngine.Power.SWAP_BLIND, "dutch : valet échange")
	_check(DutchEngine.power_of(Cards.make(13, 0)) == DutchEngine.Power.KING, "dutch : roi noir")
	_check(DutchEngine.power_of(Cards.make(13, Cards.Suit.DIAMONDS)) == DutchEngine.Power.NONE, "dutch : roi rouge sans pouvoir")

	# Distribution
	var e: DutchEngine = _dutch(3)
	_check(e.hands.size() == 3 and e.hands[0].size() == 4, "dutch : 4 cartes par joueur")
	_check(e.draw_pile.size() == 52 - 12 - 1 and e.discard_pile.size() == 1, "dutch : pioche et défausse")
	_check(e.knows(0, 0, 2) and e.knows(0, 0, 3) and not e.knows(0, 0, 0), "dutch : 2 cartes connues au départ")
	_check(not e.knows(0, 1, 2), "dutch : les cartes des autres restent secrètes")
	_check(not e.can_call_dutch(), "dutch : pas d'annonce au 1er tour")

	# Échange depuis la pioche : la carte tirée reste secrète
	var first: int = e.current
	var old: int = e.hands[first][0]
	_check(e.draw_from_deck() and e.phase == DutchEngine.Phase.HELD, "dutch : pioche")
	var drawn: int = e.held
	_check(e.swap_held(0), "dutch : échange")
	_check(e.hands[first][0] == drawn and e.top_discard() == old, "dutch : carte échangée et défaussée")
	_check(e.knows(first, first, 0) and not e.knows((first + 1) % 3, first, 0), "dutch : seul l'acteur connaît la carte piochée")
	_check(e.current == (first + 1) % 3, "dutch : tour suivant")

	# Prise de la défausse : visible par tous, et pas de défausse directe
	var p2: int = e.current
	var top: int = e.top_discard()
	_check(e.take_discard() and not e.discard_held(), "dutch : défausse reprise, pas de défausse directe")
	e.swap_held(1)
	_check(e.knows((p2 + 1) % 3, p2, 1) and e.known_card((p2 + 1) % 3, p2, 1) == top, "dutch : carte prise dans la défausse connue de tous")

	# Pouvoirs sur mains rigées
	var r: DutchEngine = _dutch(2)
	r.current = 0
	r.phase = DutchEngine.Phase.TURN
	r.hands[0] = [Cards.make(5, 0), Cards.make(9, 0), Cards.make(3, 0), Cards.make(4, 0)]
	r.hands[1] = [Cards.make(2, 1), Cards.make(6, 1), Cards.make(8, 1), Cards.make(10, 1)]
	r.draw_pile.append(Cards.make(11, 2))  # valet : échange à l'aveugle
	r.draw_from_deck()
	_check(r.discard_held() and r.phase == DutchEngine.Phase.POWER and r.power == DutchEngine.Power.SWAP_BLIND, "dutch : valet déclenche l'échange")
	_check(not r.use_swap_blind(1, 0, 0), "dutch : pas d'échange avec soi-même")
	r.known[0][DutchEngine.key(0, 1)] = r.hands[0][1]
	_check(r.use_swap_blind(1, 1, 3), "dutch : échange aveugle")
	_check(r.hands[0][1] == Cards.make(10, 1) and r.hands[1][3] == Cards.make(9, 0), "dutch : cartes échangées")
	_check(r.known_card(0, 1, 3) == Cards.make(9, 0), "dutch : la connaissance suit la carte échangée")
	_check(not r.knows(0, 0, 1), "dutch : la nouvelle carte est inconnue")
	_check(r.current == 1, "dutch : tour passé après le pouvoir")

	# Roi noir : regarder puis échanger
	r.draw_pile.append(Cards.make(13, 0))
	r.draw_from_deck()
	r.discard_held()
	_check(r.power == DutchEngine.Power.KING, "dutch : roi noir")
	_check(r.use_king_look(0, 2) and r.phase == DutchEngine.Phase.KING_DECIDE, "dutch : regard du roi")
	_check(r.known_card(1, 0, 2) == r.hands[0][2], "dutch : le roi révèle la carte à son acteur")
	var seen: int = r.hands[0][2]
	_check(r.king_swap(0) and r.hands[1][0] == seen, "dutch : échange du roi")

	# Annonce Dutch et scoring
	var d: DutchEngine = _dutch(3, 5)
	d.turns_taken = [1, 1, 1]
	d.current = 0
	d.phase = DutchEngine.Phase.TURN
	d.hands[0] = [Cards.make(14, 0), Cards.make(2, 0), Cards.make(3, 0), Cards.make(14, 1)]  # 1+2+3+1 = 7
	d.hands[1] = [Cards.make(10, 0), Cards.make(9, 1), Cards.make(8, 0), Cards.make(7, 0)]
	d.hands[2] = [Cards.make(5, 0), Cards.make(5, 1), Cards.make(6, 2), Cards.make(4, 3)]
	_check(d.call_dutch() and d.dutch_caller == 0, "dutch : annonce")
	_check(not d.can_call_dutch(), "dutch : une seule annonce")
	for _i: int in 2:
		d.draw_from_deck()
		d.swap_held(0)
	_check(d.round_is_over(), "dutch : manche finie après le dernier tour")
	_check(d.round_points[0] == 0 or d.caller_failed, "dutch : points du preneur cohérents")

	# Preneur battu : pénalité
	var f: DutchEngine = _dutch(2, 6)
	f.turns_taken = [1, 1]
	f.current = 0
	f.phase = DutchEngine.Phase.TURN
	f.hands[0] = [Cards.make(10, 0), Cards.make(10, 1), Cards.make(9, 0), Cards.make(9, 1)]
	f.hands[1] = [Cards.make(2, 0), Cards.make(2, 1), Cards.make(3, 0), Cards.make(3, 1)]
	f.call_dutch()
	f.hands[1] = [Cards.make(2, 0), Cards.make(2, 1), Cards.make(3, 0), Cards.make(3, 1)]
	f.draw_pile.append(Cards.make(14, 2))
	f.draw_from_deck()
	f.swap_held(0)
	_check(f.caller_failed and f.totals[0] == 38 + DutchEngine.DUTCH_PENALTY, "dutch : pénalité du preneur battu")
	_check(f.round_winners == [1] and f.totals[1] == 0, "dutch : le plus bas marque 0")

	# Fin de partie et classement
	var m: DutchEngine = _dutch(2, 7)
	m.target = 20
	m.turns_taken = [1, 1]
	m.current = 0
	m.phase = DutchEngine.Phase.TURN
	m.hands[0] = [Cards.make(10, 0), Cards.make(10, 1), Cards.make(9, 0), Cards.make(9, 1)]
	m.hands[1] = [Cards.make(2, 0), Cards.make(2, 1), Cards.make(3, 0), Cards.make(3, 1)]
	m.call_dutch()
	m.draw_from_deck()
	m.discard_held()
	if m.phase == DutchEngine.Phase.POWER:
		m.skip_power()
	if m.phase == DutchEngine.Phase.KING_DECIDE:
		m.keep_king()
	_check(m.phase == DutchEngine.Phase.MATCH_OVER, "dutch : fin de partie au score cible")
	_check(str(m.ranking()[0]["name"]) == "J1", "dutch : classement, le plus bas gagne")

	# Simulations 100 % ZIA : toujours terminées, 52 cartes conservées
	var anomalies: int = 0
	for game: int in 24:
		var count: int = 2 + game % 4
		var names: Array[String] = []
		var flags: Array[bool] = []
		for i: int in count:
			names.append("Z%d" % i)
			flags.append(true)
		var b: DutchEngine = DutchEngine.new()
		b.setup(names, flags, game % 3, 900 + game)
		var steps: int = 0
		while b.phase != DutchEngine.Phase.MATCH_OVER and steps < 20000:
			steps += 1
			if b.phase == DutchEngine.Phase.ROUND_OVER:
				b.start_round()
				continue
			b.bot_step()
			var total: int = b.draw_pile.size() + b.discard_pile.size() + (1 if b.held >= 0 else 0)
			for h: Array in b.hands:
				total += h.size()
			if total != 52:
				anomalies += 1
				break
		if steps >= 20000:
			anomalies += 1
	_check(anomalies == 0, "dutch : parties 100 %% ZIA terminées et cohérentes (%d)" % anomalies)


func _bj_rigged(player_cards: Array, dealer_cards: Array, draws: Array) -> BlackjackEngine:
	var bank: BankrollState = BankrollState.new()
	bank.persist = false
	bank.value = 1000
	var e: BlackjackEngine = BlackjackEngine.new(bank)
	# deal() dépile par la fin : joueur, joueur, croupier, croupier, puis les tirages.
	var deck: Array[int] = []
	for _i: int in 20:
		deck.append(Cards.make(2, 3))
	for i: int in range(draws.size() - 1, -1, -1):
		deck.append(int(draws[i]))
	deck.append(int(dealer_cards[1]))
	deck.append(int(dealer_cards[0]))
	deck.append(int(player_cards[1]))
	deck.append(int(player_cards[0]))
	e.deck = deck
	e.add_to_bet(100)
	e.deal()
	return e


func _test_blackjack_split_insurance() -> void:
	var C: int = Cards.Suit.CLUBS
	var H: int = Cards.Suit.HEARTS
	# Paire de 8 contre un 6 : split, puis les deux mains gagnent contre un croupier qui crève.
	var e: BlackjackEngine = _bj_rigged(
		[Cards.make(8, C), Cards.make(8, H)], [Cards.make(6, C), Cards.make(10, H)],
		[Cards.make(3, C), Cards.make(2, H), Cards.make(9, C)]
	)
	_check(e.phase == BlackjackEngine.Phase.PLAYER and e.can_split(), "split proposé sur une paire")
	_check(BlackjackAdvisor.should_split(e.player, e.dealer[0]), "conseil : séparer les 8")
	var bank_before: int = e._bankroll.value
	e.split()
	_check(e.has_split and e.player.size() == 2 and e.split_hand.size() == 2, "split : deux mains de deux cartes")
	_check(e._bankroll.value == bank_before - 100 and e.split_bet == 100, "split : seconde mise prélevée")
	_check(e.active_hand == 0 and e.can_double(), "split : double possible sur la main 1")
	e.stand()
	_check(e.active_hand == 1 and e.phase == BlackjackEngine.Phase.PLAYER, "split : main 2 en jeu")
	e.stand()
	_check(e.phase == BlackjackEngine.Phase.DEALER, "split : au croupier")
	e.dealer_plays()
	_check(e.phase == BlackjackEngine.Phase.DONE and e.outcome == BlackjackEngine.Outcome.WIN and e.net == 200, "split : deux mains gagnées (+200) — %s" % e.message)

	# As séparés : une carte chacun, puis le croupier.
	var a: BlackjackEngine = _bj_rigged(
		[Cards.make(14, C), Cards.make(14, H)], [Cards.make(9, C), Cards.make(10, H)],
		[Cards.make(13, C), Cards.make(5, H)]
	)
	a.split()
	_check(a.phase == BlackjackEngine.Phase.DEALER and a.player.size() == 2 and a.split_hand.size() == 2, "As séparés : une carte chacun")
	a.dealer_plays()
	_check(a.outcome == BlackjackEngine.Outcome.PUSH and a.net == 0, "As séparés : 21 (non blackjack) gagne, 16 perd → 0 — %s" % a.message)

	# Pas de split sur deux cartes différentes
	var n: BlackjackEngine = _bj_rigged([Cards.make(8, C), Cards.make(9, H)], [Cards.make(6, C), Cards.make(10, H)], [])
	_check(not n.can_split(), "pas de split sans paire")
	var t: BlackjackEngine = _bj_rigged([Cards.make(13, C), Cards.make(12, H)], [Cards.make(6, C), Cards.make(10, H)], [])
	_check(t.can_split() and not BlackjackAdvisor.should_split(t.player, t.dealer[0]), "roi + dame séparables mais déconseillé")

	# Assurance gagnante : le croupier a blackjack.
	var i1: BlackjackEngine = _bj_rigged([Cards.make(10, C), Cards.make(9, H)], [Cards.make(14, C), Cards.make(13, H)], [])
	_check(i1.phase == BlackjackEngine.Phase.INSURANCE and i1.insurance_cost() == 50, "assurance proposée contre un As")
	i1.take_insurance()
	_check(i1.phase == BlackjackEngine.Phase.DONE and i1.revealed and i1.net == 0, "assurance : blackjack du croupier, opération blanche")
	_check(i1._bankroll.value == 1000, "assurance : banque intacte")

	# Assurance perdue : le croupier n'a pas blackjack, la partie continue.
	var i2: BlackjackEngine = _bj_rigged([Cards.make(10, C), Cards.make(9, H)], [Cards.make(14, C), Cards.make(5, H)], [Cards.make(10, C)])
	i2.take_insurance()
	_check(i2.phase == BlackjackEngine.Phase.PLAYER and i2.insurance == 50, "assurance perdue : on continue")
	i2.stand()
	i2.dealer_plays()
	# Croupier : A+5+10 = 16 → tire encore (2 de remplissage) = 18 ; joueur 19 gagne 100, assurance -50.
	_check(i2.net == 50, "assurance perdue déduite du gain (net %d) — %s" % [i2.net, i2.message])

	# Refus de l'assurance avec blackjack du croupier : mise perdue
	var i3: BlackjackEngine = _bj_rigged([Cards.make(10, C), Cards.make(9, H)], [Cards.make(14, C), Cards.make(12, H)], [])
	i3.decline_insurance()
	_check(i3.outcome == BlackjackEngine.Outcome.LOSE and i3.net == -100, "sans assurance : blackjack du croupier, mise perdue")


func _test_snapshots() -> void:
	# Dutch : scores et manche restaurés
	var d: DutchEngine = _dutch(3, 11)
	d.totals = [12, 30, 7]
	d.round_number = 4
	d.start_round()
	var snap: Dictionary = d.snapshot()
	var d2: DutchEngine = _dutch(3, 12)
	d2.restore(JSON.parse_string(JSON.stringify(snap)))
	_check(d2.totals == [12, 30, 7] and d2.round_number == 5 and d2.starter == d.starter, "reprise Dutch : scores, manche et premier joueur")
	_check(d2.phase == DutchEngine.Phase.TURN and d2.hands[0].size() == 4, "reprise Dutch : nouvelle donne")

	# Poker à la table : piles du début de main, main et donneur
	var names: Array[String] = _names(4)
	var t: PokerTableEngine = PokerTableEngine.new(names, 500)
	t.rng.seed = 3
	t.start_hand()
	t.seats[2].stack = 0
	t.seats[2].out = true
	var total_before: int = 0
	for s: PokerTableEngine.Seat in t.seats:
		total_before += s.stack + s.total
	t.start_hand()
	var ps: Dictionary = JSON.parse_string(JSON.stringify(t.snapshot()))
	var button: int = t.button
	var t2: PokerTableEngine = PokerTableEngine.new(names, 500)
	t2.restore(ps)
	_check(t2.hand_number == t.hand_number and t2.button == button, "reprise poker : même main et même donneur")
	var same: bool = true
	for i: int in 4:
		if t2.seats[i].start_stack != t.seats[i].start_stack or t2.seats[i].out != t.seats[i].out:
			same = false
	_check(same, "reprise poker : piles d'avant les blinds et éliminés")

	# Blackjack local
	var b: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(3), 800)
	b.seats[1].stack = 350
	b.rounds = 6
	var b2: MultiBlackjackEngine = MultiBlackjackEngine.new(_names(3), 800)
	b2.restore(JSON.parse_string(JSON.stringify(b.snapshot())))
	_check(b2.seats[1].stack == 350 and b2.rounds == 6 and b2.phase == MultiBlackjackEngine.Phase.BET, "reprise blackjack local")


func _test_pending_refund() -> void:
	var path: String = "user://test_bank.cfg"
	var bank: BankrollState = BankrollState.new()
	bank.persist = false
	bank.value = 1000
	var e: BlackjackEngine = BlackjackEngine.new(bank)
	e.add_to_bet(100)
	e.deal()
	if e.phase == BlackjackEngine.Phase.INSURANCE:
		e.decline_insurance()
	if e.phase == BlackjackEngine.Phase.DONE:
		_check(bank.pending == 0, "mise en cours : effacée en fin de manche immédiate")
	else:
		_check(bank.pending == 100, "mise en cours mémorisée (%d)" % bank.pending)
		if e.can_double():
			e.double_down()
			if e.phase != BlackjackEngine.Phase.DONE:
				_check(bank.pending == 200, "mise en cours après double")
		if e.phase == BlackjackEngine.Phase.DEALER:
			e.dealer_plays()
		e.stand()
		if e.phase == BlackjackEngine.Phase.DEALER:
			e.dealer_plays()
		_check(bank.pending == 0, "mise en cours effacée après la manche")
	# Rechargement : une mise en suspens est rendue.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("bank", "value", 400)
	cfg.set_value("bank", "best", 1000)
	cfg.set_value("bank", "pending", 150)
	cfg.save(path)
	var reloaded: BankrollState = BankrollState.new()
	reloaded.save_path = path
	reloaded._load()
	_check(reloaded.value == 550 and reloaded.refunded == 150 and reloaded.pending == 0, "mise en suspens rendue au lancement (%d)" % reloaded.value)
	var again: BankrollState = BankrollState.new()
	again.save_path = path
	again._load()
	_check(again.value == 550 and again.refunded == 0, "remboursement une seule fois")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	reloaded.free()
	again.free()


func _test_profiles() -> void:
	ProfileStore.path = "user://test_profiles.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	var ana: String = ProfileStore.create("Ana")
	var ben: String = ProfileStore.create(" Ben ")
	var leo: String = ProfileStore.create("Léo")
	_check(ana != "" and ben != "" and ProfileStore.count() == 3, "profils créés")
	_check(ProfileStore.create("ana") == ana, "même nom (casse ignorée) : même profil")
	_check(ProfileStore.name_of(ben) == "Ben", "nom nettoyé")
	_check(not ProfileStore.rename(ben, "Ana") and ProfileStore.rename(ben, "Benji"), "renommer : refuse un doublon")
	_check(ProfileStore.bank_of(ana) == ProfileStore.START_BANK, "banque perso de départ")

	# Groupes récents
	var g1: Array[String] = [ana, ben]
	var g2: Array[String] = [ana, leo]
	ProfileStore.note_group(g1)
	ProfileStore.note_group(g2)
	ProfileStore.note_group([ben, ana] as Array[String])
	var groups: Array[Array] = ProfileStore.recent_groups()
	_check(groups.size() == 2 and groups[0].has(ana) and groups[0].has(ben), "groupes récents : sans doublon, le plus récent en tête")

	# Résultats enregistrés
	var entries: Array[Dictionary] = [
		{"id": ana, "rank": 0, "start": 1000, "final": 1600},
		{"id": ben, "rank": 1, "start": 1000, "final": 400},
	]
	ProfileStore.record_game("pk", entries, true)
	_check(ProfileStore.bank_of(ana) == 1600 and ProfileStore.bank_of(ben) == 400, "banques perso mises à jour")
	var pk: Dictionary = ProfileStore.get_profile(ana)["stats"]["pk"]
	_check(int(pk["games"]) == 1 and int(pk["wins"]) == 1 and int(pk["net"]) == 600, "stats poker du profil")
	ProfileStore.record_game("du", [{"id": leo, "rank": 0, "points": 12}] as Array[Dictionary], false)
	ProfileStore.record_game("du", [{"id": leo, "rank": 2, "points": 30}] as Array[Dictionary], false)
	var du: Dictionary = ProfileStore.get_profile(leo)["stats"]["du"]
	_check(int(du["games"]) == 2 and int(du["wins"]) == 1 and int(du["best"]) == 12, "stats Dutch du profil")
	_check(ProfileStore.profiles()[0]["id"] in [ana, ben, leo], "profils triés par date")

	# Persistance
	ProfileStore.reload()
	_check(ProfileStore.count() == 3 and ProfileStore.bank_of(ana) == 1600, "profils relus depuis le disque")
	ProfileStore.set_bank(ben, 40)
	_check(ProfileStore.playable_bank(ben) == ProfileStore.START_BANK, "banque presque vide : rechargée pour jouer")

	# Session locale : liaison, piles de départ, enregistrement des résultats
	LocalSession.game = LocalSession.Game.POKER
	LocalSession.solo = false
	LocalSession.solo_poker = false
	LocalSession.count = 4
	LocalSession.names = ["", "Zoé", "", "", "", ""]
	LocalSession.bots = [false, false, true, false, false, false]
	LocalSession.profile_ids = [ana, "", "", "", "", ""]
	LocalSession.use_banks = true
	LocalSession.chips = 500
	LocalSession.save_new_profiles = true
	LocalSession.prepare_start()
	var zoe: String = ProfileStore.find_by_name("Zoé")
	_check(zoe != "" and LocalSession.profile_ids[1] == zoe, "nouveau nom enregistré au lancement")
	_check(LocalSession.start_stacks == [1600, 1000, 500, 500], "piles de départ : banques perso, invités et ZIA (%s)" % str(LocalSession.start_stacks))
	var names: Array[String] = LocalSession.player_names()
	var rows: Array[Dictionary] = [
		{"name": names[1], "stack": 2500, "start": 1000},
		{"name": names[0], "stack": 1100, "start": 1600},
		{"name": names[2], "stack": 0, "start": 500},
		{"name": names[3], "stack": 0, "start": 500},
	]
	LocalSession.store_results(rows)
	_check(ProfileStore.bank_of(zoe) == 2500 and ProfileStore.bank_of(ana) == 1100, "fin de partie : banques perso enregistrées")
	_check(int(ProfileStore.get_profile(zoe)["stats"]["pk"]["wins"]) == 1, "fin de partie : victoire comptée")
	ProfileStore.remove(ben)
	_check(not ProfileStore.exists(ben) and ProfileStore.recent_groups().size() >= 1, "suppression d'un profil")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	LocalSession.use_banks = false
	LocalSession.profile_ids = ["", "", "", "", "", ""]


func _test_active_player() -> void:
	ProfileStore.path = "user://test_profiles_active.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	_check(ProfileStore.active_id() == "" and ProfileStore.solo_name() == "Vous", "joueur actif : invité par défaut")
	var mia: String = ProfileStore.create("Mia")
	var tom: String = ProfileStore.create("Tom")
	ProfileStore.set_active(mia)
	_check(ProfileStore.active_id() == mia and ProfileStore.solo_name() == "Mia", "joueur actif : choisi")
	ProfileStore.reload()
	_check(ProfileStore.active_id() == mia, "joueur actif : mémorisé sur disque")

	# Banque solo liée au joueur actif ; la banque d'invité est préservée.
	var bank: BankrollState = BankrollState.new()
	bank.persist = false
	bank.value = 700
	bank.best = 900
	bank.use_profile(mia)
	_check(bank.value == ProfileStore.START_BANK and bank.profile_id == mia, "banque solo : celle du joueur actif")
	bank.add(250)
	_check(ProfileStore.bank_of(mia) == 1250, "banque solo : gain écrit dans le profil")
	bank.use_profile(tom)
	_check(bank.value == 1000 and ProfileStore.bank_of(mia) == 1250, "banque solo : changement de joueur")
	bank.use_profile("")
	_check(bank.value == 700 and bank.best == 900, "banque solo : l'invité retrouve sa banque")
	_check(int(bank.to_dict()["value"]) == 700, "sauvegarde : banque d'invité exportée")
	# Une partie locale a modifié la banque du profil : relue au retour à l'accueil.
	bank.use_profile(mia)
	ProfileStore.set_bank(mia, 3000)
	bank.refresh_profile()
	_check(bank.value == 3000, "banque solo : relue après une partie locale")

	# Statistiques solo du joueur actif.
	ProfileStore.record_active("bj", true, 120)
	ProfileStore.record_active("bj", false, -50)
	ProfileStore.record_active("du", true, 0, 14)
	var st: Dictionary = ProfileStore.get_profile(mia)["stats"]
	_check(int(st["bj"]["games"]) == 2 and int(st["bj"]["wins"]) == 1 and int(st["bj"]["net"]) == 70, "stats solo : blackjack")
	_check(int(st["du"]["games"]) == 1 and int(st["du"]["best"]) == 14, "stats solo : Dutch")
	_check(str(ProfileStore.history_values(mia)) == "[120, 70]" and ProfileStore.total_net(mia) == 70, "historique : gains cumulés après 2 manches (%s)" % str(ProfileStore.history_values(mia)))
	var bjs: Dictionary = ProfileStore.game_stats(mia, "bj")
	_check(int(bjs["wins"]) == 1 and int(bjs["losses"]) == 1 and int(bjs["pushes"]) == 0, "stats joueur : victoires / défaites / égalités")
	ProfileStore.record_active("bj", false, 0)
	ProfileStore.record_active("bj", true, 150, -1, {"blackjacks": 1})
	ProfileStore.record_active("pk", true, 300, -1, {"biggest_pot": 600})
	ProfileStore.record_active("pk", true, 100, -1, {"biggest_pot": 200})
	ProfileStore.record_active("pk", false, 0, -1, {"splits": 1})
	bjs = ProfileStore.game_stats(mia, "bj")
	var pks: Dictionary = ProfileStore.game_stats(mia, "pk")
	_check(int(bjs["pushes"]) == 1 and int(bjs["blackjacks"]) == 1 and int(bjs["net"]) == 220, "stats joueur : égalité et blackjack")
	_check(int(pks["biggest_pot"]) == 600 and int(pks["splits"]) == 1 and int(pks["pushes"]) == 1, "stats joueur : plus gros pot et parts égales")
	_check(ProfileStore.total_net(mia) == 620 and ProfileStore.history_values(mia).size() == 7, "historique : cumul blackjack + poker (%d)" % ProfileStore.total_net(mia))
	# Un profil ancien (sans historique) reprend ses gains passés comme point de départ.
	var old: String = ProfileStore.create("Vieux")
	var old_p: Dictionary = ProfileStore.get_profile(old)
	old_p["stats"] = {"bj": {"games": 3, "wins": 1, "net": 500}, "pk": {"games": 1, "wins": 0, "net": -100}, "du": {"games": 0, "wins": 0, "best": -1}}
	ProfileStore.set_active(old)
	ProfileStore.record_active("bj", true, 50)
	_check(str(ProfileStore.history_values(old)) == "[450]", "historique : repart des gains déjà comptés")
	_check(int(ProfileStore.game_stats(old, "pk")["biggest_pot"]) == 0, "stats joueur : clés manquantes à 0")
	# Plafond de l'historique.
	for i: int in ProfileStore.HISTORY_MAX + 20:
		ProfileStore.record_active("bj", true, 1)
	var capped: Array[int] = ProfileStore.history_values(old)
	_check(capped.size() == ProfileStore.HISTORY_MAX and capped[capped.size() - 1] == 450 + ProfileStore.HISTORY_MAX + 20, "historique : plafonné et cumul exact")
	ProfileStore.set_active("")
	ProfileStore.record_active("bj", true, 999)
	_check(int(ProfileStore.get_profile(mia)["stats"]["bj"]["games"]) == int(bjs["games"]), "stats solo : invité non enregistré")

	# Suppression du joueur actif et import.
	ProfileStore.set_active(tom)
	var snapshot: Dictionary = ProfileStore.export_data()
	ProfileStore.remove(tom)
	_check(ProfileStore.active_id() == "", "suppression du joueur actif : retour à l'invité")
	bank.use_profile(ProfileStore.active_id())
	_check(bank.profile_id == "", "banque solo : retour à l'invité après suppression")
	ProfileStore.import_replace(snapshot)
	_check(ProfileStore.active_id() == tom, "import : joueur actif restauré")
	bank.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))


func _tc(spec: Array) -> Array[int]:
	var out: Array[int] = []
	for pair: Variant in spec:
		out.append(Cards.make(int((pair as Array)[0]), int((pair as Array)[1])))
	return out


## Distribue des mains choisies : le joueur reçoit `p`, le croupier `d` (la pioche se prend par la fin).
func _tc_round(bank: BankrollState, p: Array, d: Array, ante: int, pair_plus: int, play: bool) -> ThreeCardEngine:
	var e: ThreeCardEngine = ThreeCardEngine.new(bank)
	var cards_p: Array[int] = _tc(p)
	var cards_d: Array[int] = _tc(d)
	var deck: Array[int] = []
	for i: int in 6:
		deck.append(i)
	for i: int in range(2, -1, -1):
		deck.append(cards_d[i])
	for i: int in range(2, -1, -1):
		deck.append(cards_p[i])
	e.deck = deck
	e.add_ante(ante)
	if pair_plus > 0:
		e.add_pair_plus(pair_plus)
	e.deal()
	if play:
		e.play()
	else:
		e.fold()
	return e


func _test_three_card() -> void:
	var H: Dictionary = {"sf": ThreeCardEngine.Hand.STRAIGHT_FLUSH, "tk": ThreeCardEngine.Hand.THREE_KIND, "st": ThreeCardEngine.Hand.STRAIGHT, "fl": ThreeCardEngine.Hand.FLUSH, "pr": ThreeCardEngine.Hand.PAIR, "hc": ThreeCardEngine.Hand.HIGH_CARD}
	var ev: Callable = func(spec: Array) -> Array[int]: return ThreeCardEngine.evaluate(_tc(spec))
	_check(ev.call([[10, 0], [11, 0], [12, 0]])[0] == H["sf"], "3 cartes : quinte flush")
	_check(ev.call([[7, 1], [7, 2], [7, 3]])[0] == H["tk"], "3 cartes : brelan")
	_check(ev.call([[4, 0], [5, 1], [6, 2]])[0] == H["st"], "3 cartes : quinte")
	_check(ev.call([[2, 3], [9, 3], [13, 3]])[0] == H["fl"], "3 cartes : couleur")
	_check(ev.call([[9, 0], [9, 1], [2, 2]])[0] == H["pr"] and ev.call([[2, 2], [9, 0], [9, 1]])[1] == 9, "3 cartes : paire (rang et ordre)")
	_check(ev.call([[14, 0], [9, 1], [2, 2]])[0] == H["hc"], "3 cartes : hauteur")
	var a23: Array[int] = ev.call([[14, 0], [2, 1], [3, 2]])
	var k_q_a: Array[int] = ev.call([[14, 0], [13, 1], [12, 2]])
	var s234: Array[int] = ev.call([[2, 0], [3, 1], [4, 2]])
	_check(a23[0] == H["st"] and a23[1] == 3, "A-2-3 : la plus petite quinte")
	_check(ThreeCardEngine.compare(s234, a23) > 0 and ThreeCardEngine.compare(k_q_a, s234) > 0, "quintes : A-K-Q > 2-3-4 > A-2-3")
	var flush: Array[int] = ev.call([[14, 3], [9, 3], [5, 3]])
	_check(ThreeCardEngine.compare(a23, flush) > 0, "ici la quinte bat la couleur")
	var pair_k: Array[int] = ev.call([[13, 0], [13, 1], [3, 2]])
	var pair_k_hi: Array[int] = ev.call([[13, 2], [13, 3], [9, 0]])
	_check(ThreeCardEngine.compare(pair_k_hi, pair_k) > 0 and ThreeCardEngine.compare(pair_k, pair_k) == 0, "paires : le kicker départage")
	_check(not ThreeCardEngine.dealer_qualifies(_tc([[11, 0], [9, 1], [5, 2]])), "croupier : valet haute ne se qualifie pas")
	_check(ThreeCardEngine.dealer_qualifies(_tc([[12, 0], [5, 1], [3, 2]])), "croupier : dame haute se qualifie")
	_check(ThreeCardEngine.dealer_qualifies(_tc([[2, 0], [2, 1], [5, 2]])), "croupier : une paire se qualifie")
	_check(ThreeCardEngine.hand_name(_tc([[12, 0], [12, 1], [5, 2]])) == "paire de dames", "nom de la main")

	var bank: BankrollState = BankrollState.new()
	bank.persist = false
	bank.value = 1000
	var pre: int = bank.value
	# Le joueur bat un croupier qualifié : Ante et Jeu payés 1 pour 1.
	var e: ThreeCardEngine = _tc_round(bank, [[13, 0], [9, 1], [4, 2]], [[12, 0], [8, 1], [3, 2]], 50, 0, true)
	_check(e.net == 100 and bank.value == pre + 100 and bank.pending == 0, "gain : victoire (+100, banque %d)" % bank.value)
	# Croupier non qualifié : Ante payée, Jeu rendu.
	pre = bank.value
	e = _tc_round(bank, [[9, 0], [6, 1], [4, 2]], [[11, 0], [8, 1], [3, 2]], 50, 0, true)
	_check(e.net == 50 and not e.dealer_qualified and bank.value == pre + 50, "gain : croupier non qualifié (+50)")
	# Croupier gagne.
	pre = bank.value
	e = _tc_round(bank, [[9, 0], [6, 1], [4, 2]], [[13, 0], [8, 1], [3, 2]], 50, 0, true)
	_check(e.net == -100 and bank.value == pre - 100, "perte : le croupier gagne (-100)")
	# Égalité parfaite : tout est rendu.
	pre = bank.value
	e = _tc_round(bank, [[12, 0], [9, 1], [8, 2]], [[12, 1], [9, 0], [8, 3]], 50, 0, true)
	_check(e.net == 0 and bank.value == pre, "égalité : mises rendues")
	# Se coucher : seule l'Ante est perdue.
	pre = bank.value
	e = _tc_round(bank, [[9, 0], [6, 1], [4, 2]], [[13, 0], [8, 1], [3, 2]], 50, 0, false)
	_check(e.net == -50 and e.folded and bank.value == pre - 50, "coucher : Ante perdue (-50)")
	# Pair Plus : payé même si on se couche.
	pre = bank.value
	e = _tc_round(bank, [[7, 0], [7, 1], [2, 2]], [[13, 0], [8, 1], [3, 2]], 50, 10, false)
	_check(e.net == -40 and e.pair_plus_won and bank.value == pre - 40, "Pair Plus : paire payée 1 pour 1 même couché (-40)")
	# Bonus d'Ante avec une quinte battue par un croupier meilleur : bonus payé, Ante et Jeu perdus.
	pre = bank.value
	e = _tc_round(bank, [[4, 0], [5, 1], [6, 2]], [[10, 3], [11, 3], [12, 3]], 50, 0, true)
	_check(e.net == -50 and bank.value == pre - 50, "bonus d'Ante : quinte payée 1 pour 1 malgré la défaite (-50)")
	# Brelan : bonus 4 pour 1 + victoire + Pair Plus 30 pour 1.
	pre = bank.value
	e = _tc_round(bank, [[8, 0], [8, 1], [8, 2]], [[13, 0], [8 + 1, 1], [3, 2]], 50, 10, true)
	# Ante 50 + Jeu 50 + Pair Plus 10 = 110 misés ; reçus : Pair Plus 310 + bonus 200 + (100+100) = 710.
	_check(e.net == 600 and bank.value == pre + 600, "brelan : bonus d'Ante et Pair Plus (+600, net %d)" % e.net)
	# Limites de mise : il faut pouvoir couvrir le Jeu.
	bank.value = 1000
	var lim: ThreeCardEngine = ThreeCardEngine.new(bank)
	lim.add_ante(500)
	lim.add_pair_plus(10)
	_check(lim.ante == 500 and lim.pair_plus == 0 and lim.can_deal(), "mises : l'Ante ne dépasse pas la moitié de la banque")
	lim.add_ante(10)
	_check(lim.ante == 500, "mises : Ante plafonnée")
	var poor: BankrollState = BankrollState.new()
	poor.persist = false
	poor.value = 15
	var pe: ThreeCardEngine = ThreeCardEngine.new(poor)
	pe.add_ante(10)
	_check(pe.ante == 0 and not pe.can_deal(), "mises : banque trop faible pour l'Ante minimale")
	poor.free()
	# Conservation de la banque sur de nombreuses manches (décisions au hasard).
	bank.value = 5000
	var sim: ThreeCardEngine = ThreeCardEngine.new(bank)
	sim.rng.seed = 99
	var sum_net: int = 0
	var start: int = bank.value
	var rounds: int = 0
	while rounds < 400 and bank.value >= 30:
		sim.add_ante(10)
		sim.add_pair_plus(10) if rounds % 3 == 0 else sim.clear_pair_plus()
		sim.deal()
		if sim.rng.randf() < 0.7:
			sim.play()
		else:
			sim.fold()
		sum_net += sim.net
		rounds += 1
		sim.replay()
	_check(bank.value == start + sum_net and bank.pending == 0, "400 manches : banque cohérente (%d manches, %+d)" % [rounds, sum_net])
	# Conseil du mode débutant.
	_check(ThreeCardAdvisor.should_play(_tc([[12, 0], [6, 1], [4, 2]])), "conseil : Dame-6-4 se joue")
	_check(not ThreeCardAdvisor.should_play(_tc([[12, 0], [6, 1], [3, 2]])), "conseil : Dame-6-3 se couche")
	_check(ThreeCardAdvisor.should_play(_tc([[13, 0], [3, 1], [2, 2]])), "conseil : Roi haute se joue")
	_check(not ThreeCardAdvisor.should_play(_tc([[11, 0], [10, 1], [8, 2]])), "conseil : Valet haute se couche")
	_check(ThreeCardAdvisor.should_play(_tc([[2, 0], [2, 1], [5, 2]])), "conseil : une paire se joue")
	# Statistiques globales et par joueur.
	var st: StatsState = StatsState.new()
	st.persist = false
	st.record_three_card(100, ThreeCardEngine.Hand.PAIR, false, true)
	st.record_three_card(-50, ThreeCardEngine.Hand.HIGH_CARD, true, false)
	st.record_three_card(0, ThreeCardEngine.Hand.STRAIGHT_FLUSH, false, false)
	_check(st.tc_rounds == 3 and st.tc_wins == 1 and st.tc_losses == 1 and st.tc_pushes == 1 and st.tc_net == 50, "stats Three Card : manches, victoires, net")
	_check(st.tc_folds == 1 and st.tc_pair_plus_wins == 1 and st.tc_straight_flushes == 1, "stats Three Card : couchés, Pair Plus, quinte flush")
	_check(st.has_achievement("tc_first") and st.has_achievement("tc_pair_plus") and st.has_achievement("tc_sf"), "succès Three Card")
	var back: StatsState = StatsState.new()
	back.persist = false
	back.load_dict(st.to_dict())
	_check(back.tc_rounds == 3 and back.tc_net == 50, "sauvegarde : stats Three Card exportées")
	st.free()
	back.free()
	ProfileStore.path = "user://test_profiles_tc.json"
	if FileAccess.file_exists(ProfileStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	ProfileStore.reload()
	var zoe: String = ProfileStore.create("Zoé")
	ProfileStore.set_active(zoe)
	ProfileStore.record_active("tc", true, 120, -1, {"pair_plus_wins": 1})
	ProfileStore.record_active("tc", false, -50, -1, {"folds": 1})
	var tcs: Dictionary = ProfileStore.game_stats(zoe, "tc")
	_check(int(tcs["games"]) == 2 and int(tcs["wins"]) == 1 and int(tcs["losses"]) == 1 and int(tcs["folds"]) == 1 and int(tcs["pair_plus_wins"]) == 1 and int(tcs["net"]) == 70, "joueur : stats Three Card")
	_check(ProfileStore.total_net(zoe) == 70, "joueur : gains cumulés incluent Three Card")
	_check(ProfileStore.summary(zoe)[0].begins_with("Three Card"), "joueur : résumé Three Card")
	ProfileStore.set_active("")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.path))
	bank.free()
