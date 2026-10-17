class_name PokerEngine
extends RefCounted
## Moteur Poker Texas Hold'em heads-up contre l'IA « ZIA ».

signal changed

enum Street { PREFLOP, FLOP, TURN, RIVER, ENDED }
enum Actor { PLAYER, AI, NONE }

const SB: int = 10
const BB: int = 20
const AI_BUY_IN: int = 500
const MC_ITERATIONS: int = 200

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var deck: Array[int] = []
var board: Array[int] = []
var player_hole: Array[int] = []
var ai_hole: Array[int] = []
var pot: int = 0
var p_bet: int = 0
var a_bet: int = 0
var p_stack: int = 0
var a_stack: int = AI_BUY_IN
var dealer_is_player: bool = true
var street: Street = Street.PREFLOP
var to_act: Actor = Actor.NONE
var acted_p: bool = false
var acted_a: bool = false
var raises: int = 0
var runout: bool = false
var reveal_ai: bool = false
## Texte du résultat de la main ; vide tant que la main est en cours.
var result: String = ""
var log_lines: Array[String] = []


func _init(buy_in: int) -> void:
	rng.randomize()
	p_stack = buy_in
	start_hand(true)


# --- Accesseurs -------------------------------------------------------------


func is_over() -> bool:
	return result != ""


func is_player_turn() -> bool:
	return to_act == Actor.PLAYER and result == ""


func to_call() -> int:
	return a_bet - p_bet


func open_bet_size() -> int:
	return maxi(roundi(pot * 0.5), BB)


func raise_half_size() -> int:
	var base: int = maxi(roundi(pot * 0.5), BB)
	return maxi(a_bet + base, a_bet + BB)


func pot_size_bet() -> int:
	return a_bet + pot


func street_label() -> String:
	match street:
		Street.PREFLOP:
			return "Pré-flop"
		Street.FLOP:
			return "Flop"
		Street.TURN:
			return "Turn"
		Street.RIVER:
			return "River"
		_:
			return "Fin de main"


func _log(msg: String) -> void:
	log_lines.push_front(msg)
	if log_lines.size() > 4:
		log_lines.pop_back()


# --- Déroulement d'une main -------------------------------------------------


func start_hand(first: bool = false) -> void:
	dealer_is_player = rng.randi() % 2 == 0 if first else not dealer_is_player
	deck = Cards.shuffled_deck(rng)
	board = []
	player_hole = [deck.pop_back(), deck.pop_back()]
	ai_hole = [deck.pop_back(), deck.pop_back()]
	pot = 0
	p_bet = 0
	a_bet = 0
	acted_p = false
	acted_a = false
	raises = 0
	runout = false
	reveal_ai = false
	result = ""
	street = Street.PREFLOP
	log_lines.clear()
	if a_stack <= 0:
		a_stack = AI_BUY_IN
		_log("ZIA se recave (%d)." % AI_BUY_IN)

	# Blinds (cave insuffisante → tapis pour moins). Le donneur poste la petite blinde.
	var sb_who: Actor = Actor.PLAYER if dealer_is_player else Actor.AI
	var bb_who: Actor = Actor.AI if dealer_is_player else Actor.PLAYER
	var sb_amt: int = mini(p_stack, SB) if sb_who == Actor.PLAYER else mini(a_stack, SB)
	var bb_amt: int = mini(p_stack, BB) if bb_who == Actor.PLAYER else mini(a_stack, BB)
	pot = sb_amt + bb_amt
	if sb_who == Actor.PLAYER:
		p_stack -= sb_amt
		p_bet = sb_amt
	else:
		a_stack -= sb_amt
		a_bet = sb_amt
	if bb_who == Actor.PLAYER:
		p_stack -= bb_amt
		p_bet = bb_amt
	else:
		a_stack -= bb_amt
		a_bet = bb_amt
	to_act = Actor.PLAYER if dealer_is_player else Actor.AI
	_log("Nouvelle main — blinds %d/%d." % [SB, BB])
	if p_stack == 0 or a_stack == 0:
		_normalize_all_in()
		runout = true
		to_act = Actor.NONE
		reveal_ai = true
	changed.emit()


## Rembourse la part non couverte quand un tapis ne peut pas être suivi.
func _normalize_all_in() -> void:
	var min_bet: int = mini(p_bet, a_bet)
	if p_bet > min_bet:
		var r: int = p_bet - min_bet
		p_stack += r
		pot -= r
		p_bet = min_bet
	if a_bet > min_bet:
		var r2: int = a_bet - min_bet
		a_stack += r2
		pot -= r2
		a_bet = min_bet


func showdown() -> void:
	var p_score: Array[int] = _best_hand(player_hole)
	var a_score: Array[int] = _best_hand(ai_hole)
	var c: int = HandEvaluator.cmp_score(p_score, a_score)
	var won: int = pot
	pot = 0
	reveal_ai = true
	to_act = Actor.NONE
	street = Street.ENDED
	if c > 0:
		p_stack += won
		result = "Vous gagnez %d avec %s !" % [won, HandEvaluator.hand_name(p_score)]
	elif c < 0:
		a_stack += won
		result = "ZIA gagne %d avec %s." % [won, HandEvaluator.hand_name(a_score)]
	else:
		var half: int = won / 2
		p_stack += half + won % 2
		a_stack += half
		result = "Égalité — pot partagé (%s)." % HandEvaluator.hand_name(p_score)
	_log("Abattage : " + result)


func _best_hand(hole: Array[int]) -> Array[int]:
	var cards: Array[int] = hole.duplicate()
	cards.append_array(board)
	return HandEvaluator.evaluate7(cards)


func advance_street() -> void:
	if street == Street.ENDED or result != "":
		return
	if street == Street.RIVER:
		showdown()
		changed.emit()
		return
	if street == Street.PREFLOP:
		board.append(deck.pop_back())
		board.append(deck.pop_back())
		board.append(deck.pop_back())
		street = Street.FLOP
	elif street == Street.FLOP:
		board.append(deck.pop_back())
		street = Street.TURN
	else:
		board.append(deck.pop_back())
		street = Street.RIVER
	p_bet = 0
	a_bet = 0
	acted_p = false
	acted_a = false
	raises = 0
	if p_stack == 0 or a_stack == 0:
		runout = true
		reveal_ai = true
		to_act = Actor.NONE
	else:
		# Après le flop, la grosse blinde (non-donneur) parle en premier.
		to_act = Actor.AI if dealer_is_player else Actor.PLAYER
	_log(street_label() + ".")
	changed.emit()


func fold(who: Actor) -> void:
	var won: int = pot
	pot = 0
	if who == Actor.PLAYER:
		a_stack += won
		result = "Vous vous couchez — ZIA remporte %d." % won
		_log("Vous vous couchez.")
	else:
		p_stack += won
		result = "ZIA se couche — vous remportez %d !" % won
		_log("ZIA se couche.")
	street = Street.ENDED
	to_act = Actor.NONE
	changed.emit()


## Le joueur quitte la table en pleine main : il abandonne le pot.
func forfeit() -> void:
	if result == "":
		fold(Actor.PLAYER)


func _mark_acted(who: Actor) -> void:
	if who == Actor.PLAYER:
		acted_p = true
	else:
		acted_a = true


func check_call(who: Actor) -> void:
	var other: Actor = Actor.AI if who == Actor.PLAYER else Actor.PLAYER
	var my_bet: int = p_bet if who == Actor.PLAYER else a_bet
	var other_bet: int = a_bet if who == Actor.PLAYER else p_bet
	var to_call_amount: int = other_bet - my_bet

	if to_call_amount <= 0:
		_mark_acted(who)
		_log("Vous checkez." if who == Actor.PLAYER else "ZIA checke.")
		var other_acted_chk: bool = acted_a if who == Actor.PLAYER else acted_p
		if other_acted_chk:
			advance_street()
			return
		to_act = other
		changed.emit()
		return

	var my_stack: int = p_stack if who == Actor.PLAYER else a_stack
	var add: int = mini(to_call_amount, my_stack)
	my_stack -= add
	pot += add
	var new_p_bet: int = my_bet + add if who == Actor.PLAYER else other_bet
	var new_a_bet: int = my_bet + add if who == Actor.AI else other_bet
	var other_stack: int = p_stack if other == Actor.PLAYER else a_stack
	# Tapis non couvert → remboursement du trop-versé à l'adversaire.
	if add < to_call_amount:
		var refund: int = to_call_amount - add
		other_stack += refund
		pot -= refund
		if other == Actor.PLAYER:
			new_p_bet -= refund
		else:
			new_a_bet -= refund
	p_bet = new_p_bet
	a_bet = new_a_bet
	p_stack = my_stack if who == Actor.PLAYER else other_stack
	a_stack = my_stack if who == Actor.AI else other_stack
	_mark_acted(who)
	_log(("Vous suivez %d." if who == Actor.PLAYER else "ZIA suit %d.") % add)
	if p_stack == 0 or a_stack == 0:
		_normalize_all_in()
		runout = true
		reveal_ai = true
		to_act = Actor.NONE
		changed.emit()
		return
	var other_acted: bool = acted_a if who == Actor.PLAYER else acted_p
	if other_acted:
		advance_street()
		return
	to_act = other
	changed.emit()


func bet_raise(who: Actor, raise_to_raw: int) -> void:
	var other: Actor = Actor.AI if who == Actor.PLAYER else Actor.PLAYER
	var my_bet: int = p_bet if who == Actor.PLAYER else a_bet
	var other_bet: int = a_bet if who == Actor.PLAYER else p_bet
	var my_stack: int = p_stack if who == Actor.PLAYER else a_stack
	var diff: int = other_bet - my_bet
	var min_raise_to: int = other_bet + maxi(BB, diff) if other_bet > 0 else BB
	var raise_to: int = maxi(raise_to_raw, min_raise_to)
	var max_raise_to: int = my_bet + my_stack
	if raise_to > max_raise_to:
		raise_to = max_raise_to  # tapis
	if raise_to <= other_bet:
		check_call(who)
		return
	var add: int = raise_to - my_bet
	pot += add
	if who == Actor.PLAYER:
		p_bet = raise_to
		p_stack -= add
		acted_p = true
		_log(("Vous relancez à %d." if other_bet > 0 else "Vous misez %d.") % raise_to)
	else:
		a_bet = raise_to
		a_stack -= add
		acted_a = true
		_log(("ZIA relance à %d." if other_bet > 0 else "ZIA mise %d.") % raise_to)
	raises += 1
	to_act = other
	if (p_stack if who == Actor.PLAYER else a_stack) == 0:
		reveal_ai = true
	changed.emit()


## Tour de l'IA : Chen pré-flop, Monte-Carlo ensuite, cote du pot + bluff.
func ai_act() -> void:
	if to_act != Actor.AI or result != "":
		return
	var to_call_amount: int = p_bet - a_bet
	var p: float
	if street == Street.PREFLOP:
		var c: int = PokerAI.chen(ai_hole[0], ai_hole[1])
		p = 0.33 + (c / 20.0) * 0.42
	else:
		p = PokerAI.win_prob(ai_hole, board, MC_ITERATIONS, rng)

	if to_call_amount <= 0:
		var bet_size: int = maxi(roundi(pot * 0.5), BB)
		if raises < 3 and p > 0.62 and rng.randf() < 0.85 and bet_size <= a_stack:
			bet_raise(Actor.AI, a_bet + bet_size)
			return
		if raises < 3 and p < 0.38 and rng.randf() < 0.13 and bet_size <= a_stack:
			bet_raise(Actor.AI, a_bet + bet_size)  # bluff occasionnel
			return
		check_call(Actor.AI)
		return

	var pot_odds: float = float(to_call_amount) / float(pot + to_call_amount)
	var half: int = roundi(pot * 0.6)
	var raise_to: int = p_bet + maxi(half, BB)
	if raises < 3 and p > 0.8 and rng.randf() < 0.75 and raise_to <= a_bet + a_stack:
		bet_raise(Actor.AI, raise_to)
		return
	if p >= pot_odds + 0.02:
		check_call(Actor.AI)
		return
	if rng.randf() < 0.1 and p > pot_odds * 0.7:
		check_call(Actor.AI)  # call flottant
		return
	fold(Actor.AI)
