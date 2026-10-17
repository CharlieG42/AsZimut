class_name PokerTableEngine
extends RefCounted
## Texas Hold'em à 2–6 joueurs humains sur un même appareil (sans IA).
## Gère les blinds croissantes, les relances, les tapis et les pots annexes.

signal changed
## Émis après `changed` quand la main est entièrement réglée.
signal hand_finished

enum Street { PREFLOP, FLOP, TURN, RIVER, ENDED }

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 6
## Petite blind par niveau ; la grosse blind vaut le double.
const BLIND_LEVELS: Array[int] = [10, 15, 25, 40, 60, 100, 150, 250, 400, 600, 1000]
const HANDS_PER_LEVEL: int = 8


class Seat extends RefCounted:
	var name: String
	var stack: int
	var hole: Array[int] = []
	var bet: int = 0  # mise sur le tour d'enchères en cours
	var total: int = 0  # total engagé dans la main
	var folded: bool = false
	var all_in: bool = false
	var acted: bool = false  # a agi depuis la dernière relance complète
	var out: bool = false  # éliminé de la partie
	var out_rank: int = 0  # ordre d'élimination (plus grand = parti plus tard)
	var start_stack: int = 0
	var net: int = 0
	var won: int = 0
	var label: String = ""  # « D », « PB », « GB »

	func _init(player_name: String, chips: int) -> void:
		name = player_name
		stack = chips


var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seats: Array[Seat] = []
var deck: Array[int] = []
var board: Array[int] = []
var button: int = -1
var street: Street = Street.PREFLOP
var to_act: int = -1
var current_bet: int = 0
var min_raise: int = 0
var hand_number: int = 0
var runout: bool = false
var reveal: bool = false
var hand_over: bool = false
var aborted: bool = false
var result_lines: Array[String] = []
var log_lines: Array[String] = []
var last_pot: int = 0
var total_chips: int = 0

var _eliminated: int = 0


func _init(names: Array[String], chips: int) -> void:
	for n: String in names:
		seats.append(Seat.new(n, chips))
	total_chips = chips * names.size()
	rng.randomize()


# --- Accesseurs -------------------------------------------------------------


func small_blind() -> int:
	@warning_ignore("integer_division")
	var level: int = maxi(hand_number - 1, 0) / HANDS_PER_LEVEL
	return BLIND_LEVELS[mini(level, BLIND_LEVELS.size() - 1)]


func big_blind() -> int:
	return small_blind() * 2


func pot() -> int:
	var sum: int = 0
	for s: Seat in seats:
		sum += s.total
	return sum


func alive_count() -> int:
	var n: int = 0
	for s: Seat in seats:
		if not s.out and s.stack > 0:
			n += 1
	return n


func is_game_over() -> bool:
	return aborted or (hand_over and alive_count() <= 1)


func can_act() -> bool:
	return to_act >= 0 and not hand_over


func to_call(i: int) -> int:
	return mini(current_bet - seats[i].bet, seats[i].stack)


func can_check(i: int) -> bool:
	return current_bet - seats[i].bet <= 0


func can_raise(i: int) -> bool:
	var s: Seat = seats[i]
	return not s.acted and s.stack > current_bet - s.bet and _others_able(i) > 0


func min_raise_to(i: int) -> int:
	return mini(current_bet + min_raise, max_raise_to(i))


func max_raise_to(i: int) -> int:
	return seats[i].bet + seats[i].stack


## Relance « taille du pot » : appel + pot après appel.
func pot_raise_to(i: int) -> int:
	var call_amount: int = current_bet - seats[i].bet
	return current_bet + pot() + call_amount


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
	return "Abattage" if reveal else "Terminé"


## Meilleure main actuelle de `i` avec le board (chaîne vide s'il n'y a pas de board).
func describe_hand(i: int) -> String:
	if board.is_empty() or seats[i].hole.is_empty():
		return ""
	return HandEvaluator.describe(_score(i))


## Classement final : survivants par jetons, puis éliminés du dernier au premier.
func standings() -> Array[int]:
	var order: Array[int] = []
	for i: int in seats.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var sa: Seat = seats[a]
			var sb: Seat = seats[b]
			var a_alive: bool = not sa.out
			var b_alive: bool = not sb.out
			if a_alive != b_alive:
				return a_alive
			if a_alive:
				return sa.stack > sb.stack
			return sa.out_rank > sb.out_rank
	)
	return order


# --- Déroulement ------------------------------------------------------------


func start_hand() -> void:
	if is_game_over() or alive_count() < MIN_PLAYERS:
		return
	hand_number += 1
	deck = Cards.shuffled_deck(rng)
	board = []
	result_lines = []
	log_lines = []
	hand_over = false
	runout = false
	reveal = false
	street = Street.PREFLOP
	for s: Seat in seats:
		s.hole = []
		s.bet = 0
		s.total = 0
		s.acted = false
		s.all_in = false
		s.folded = s.out
		s.net = 0
		s.won = 0
		s.label = ""
		s.start_stack = s.stack

	button = _next_alive(button)
	var sb_idx: int
	var bb_idx: int
	if alive_count() == 2:
		sb_idx = button  # heads-up : le donneur est petite blind
		bb_idx = _next_alive(button)
		seats[button].label = "D · PB"
		seats[bb_idx].label = "GB"
	else:
		sb_idx = _next_alive(button)
		bb_idx = _next_alive(sb_idx)
		seats[button].label = "D"
		seats[sb_idx].label = "PB"
		seats[bb_idx].label = "GB"
	_post(sb_idx, small_blind())
	_post(bb_idx, big_blind())
	current_bet = 0
	for s: Seat in seats:
		current_bet = maxi(current_bet, s.bet)
	min_raise = big_blind()

	for _round: int in 2:
		for s: Seat in seats:
			if not s.out:
				s.hole.append(deck.pop_back())
	_log("Main %d — blinds %d/%d." % [hand_number, small_blind(), big_blind()])

	to_act = _next_actor(bb_idx)
	if to_act < 0:
		_end_betting_round()
	else:
		changed.emit()


func fold() -> void:
	if not can_act():
		return
	var s: Seat = seats[to_act]
	s.folded = true
	_log("%s se couche." % s.name)
	_after_action()


func check_call() -> void:
	if not can_act():
		return
	var i: int = to_act
	var s: Seat = seats[i]
	var amount: int = to_call(i)
	_put(i, amount)
	s.acted = true
	if amount == 0:
		_log("%s checke." % s.name)
	else:
		_log("%s suit %d%s." % [s.name, amount, " (tapis)" if s.all_in else ""])
	_after_action()


func raise_to(target: int) -> void:
	if not can_act():
		return
	var i: int = to_act
	if not can_raise(i):
		check_call()
		return
	var s: Seat = seats[i]
	var t: int = clampi(target, min_raise_to(i), max_raise_to(i))
	var increment: int = t - current_bet
	var opening: bool = current_bet == 0
	_put(i, t - s.bet)
	if increment >= min_raise:
		min_raise = increment
		for other: Seat in seats:
			if other != s:
				other.acted = false
	current_bet = maxi(current_bet, t)
	s.acted = true
	var verb: String = "mise" if opening else "relance à"
	_log("%s %s %d%s." % [s.name, verb, t, " (tapis)" if s.all_in else ""])
	_after_action()


## Passe au tour d'enchères suivant (ou à l'abattage). Aussi appelé par l'interface
## pour dérouler le board pas à pas quand plus personne ne peut miser.
func advance_street() -> void:
	if hand_over:
		return
	match street:
		Street.PREFLOP:
			_deal_board(3)
			street = Street.FLOP
		Street.FLOP:
			_deal_board(1)
			street = Street.TURN
		Street.TURN:
			_deal_board(1)
			street = Street.RIVER
		Street.RIVER:
			showdown()
			return
	for s: Seat in seats:
		s.bet = 0
		s.acted = false
	current_bet = 0
	min_raise = big_blind()
	if _able_count() >= 2:
		runout = false
		to_act = _next_actor(button)
	else:
		runout = true
		reveal = true
		to_act = -1
	changed.emit()


## Abattage : répartit chaque pot (principal et annexes) entre les meilleures mains.
func showdown() -> void:
	reveal = true
	var scores: Dictionary = {}
	for i: int in seats.size():
		if not seats[i].folded:
			scores[i] = _score(i)
	var pots: Array[Dictionary] = _build_pots()
	for p: Dictionary in pots:
		var eligible: Array[int] = []
		for i: int in (p["eligible"] as Array[int]):
			eligible.append(i)
		var best: Array[int] = []
		var winners: Array[int] = []
		for i: int in eligible:
			var sc: Array[int] = scores[i]
			if best.is_empty() or HandEvaluator.cmp_score(sc, best) > 0:
				best = sc
				winners = [i]
			elif HandEvaluator.cmp_score(sc, best) == 0:
				winners.append(i)
		_pay(winners, int(p["amount"]))
	last_pot = pot()
	for i: int in scores:
		var s: Seat = seats[i]
		if s.won > 0:
			result_lines.append("%s gagne %d — %s" % [s.name, s.won, HandEvaluator.describe(scores[i])])
	_close_hand()


## Abandonne la partie : les mises en cours sont rendues à leurs propriétaires.
func abort() -> void:
	for s: Seat in seats:
		s.stack += s.total
		s.total = 0
		s.bet = 0
	aborted = true
	hand_over = true
	to_act = -1
	runout = false
	changed.emit()


# --- Interne ----------------------------------------------------------------


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 4:
		log_lines.remove_at(0)


func _score(i: int) -> Array[int]:
	var cards: Array[int] = seats[i].hole.duplicate()
	cards.append_array(board)
	return HandEvaluator.evaluate7(cards)


func _deal_board(count: int) -> void:
	deck.pop_back()  # carte brûlée
	for _n: int in count:
		board.append(deck.pop_back())


func _next_alive(from: int) -> int:
	var n: int = seats.size()
	for k: int in range(1, n + 1):
		var idx: int = (from + k) % n
		if not seats[idx].out and seats[idx].stack > 0:
			return idx
	return -1


func _put(i: int, amount: int) -> void:
	var s: Seat = seats[i]
	var a: int = mini(amount, s.stack)
	s.stack -= a
	s.bet += a
	s.total += a
	if s.stack == 0:
		s.all_in = true


func _post(i: int, amount: int) -> void:
	_put(i, amount)


func _live_count() -> int:
	var n: int = 0
	for s: Seat in seats:
		if not s.folded:
			n += 1
	return n


func _able_count() -> int:
	var n: int = 0
	for s: Seat in seats:
		if not s.folded and not s.all_in:
			n += 1
	return n


func _others_able(i: int) -> int:
	var n: int = 0
	for j: int in seats.size():
		if j != i and not seats[j].folded and not seats[j].all_in:
			n += 1
	return n


func _needs_action(i: int) -> bool:
	var s: Seat = seats[i]
	if s.folded or s.all_in:
		return false
	if s.bet < current_bet:
		return true
	return not s.acted and _others_able(i) > 0


func _next_actor(from: int) -> int:
	var n: int = seats.size()
	for k: int in range(1, n + 1):
		var idx: int = (from + k) % n
		if _needs_action(idx):
			return idx
	return -1


func _after_action() -> void:
	if _live_count() == 1:
		_award_uncontested()
		return
	var next: int = _next_actor(to_act)
	if next < 0:
		_end_betting_round()
	else:
		to_act = next
		changed.emit()


func _end_betting_round() -> void:
	to_act = -1
	advance_street()


func _award_uncontested() -> void:
	var winner: int = -1
	for i: int in seats.size():
		if not seats[i].folded:
			winner = i
	last_pot = pot()
	_pay([winner], last_pot)
	result_lines.append("%s remporte %d — tous les autres se couchent." % [seats[winner].name, seats[winner].won])
	_close_hand()


## Découpe les mises en pot principal + pots annexes.
func _build_pots() -> Array[Dictionary]:
	var levels: Array[int] = []
	for s: Seat in seats:
		if s.total > 0 and not levels.has(s.total):
			levels.append(s.total)
	levels.sort()
	var pots: Array[Dictionary] = []
	var previous: int = 0
	for level: int in levels:
		var amount: int = 0
		var eligible: Array[int] = []
		for i: int in seats.size():
			var s: Seat = seats[i]
			amount += maxi(mini(s.total, level) - previous, 0)
			if not s.folded and s.total >= level:
				eligible.append(i)
		previous = level
		if amount <= 0:
			continue
		if eligible.is_empty() and not pots.is_empty():
			pots[pots.size() - 1]["amount"] = int(pots[pots.size() - 1]["amount"]) + amount
		else:
			pots.append({"amount": amount, "eligible": eligible})
	return pots


## Partage `amount` entre `winners` ; les jetons impairs vont aux premiers après le donneur.
func _pay(winners: Array[int], amount: int) -> void:
	if winners.is_empty() or amount <= 0:
		return
	var ordered: Array[int] = []
	for k: int in range(1, seats.size() + 1):
		var idx: int = (button + k) % seats.size()
		if winners.has(idx):
			ordered.append(idx)
	@warning_ignore("integer_division")
	var share: int = amount / ordered.size()
	var extra: int = amount % ordered.size()
	for n: int in ordered.size():
		var gain: int = share + (1 if n < extra else 0)
		seats[ordered[n]].stack += gain
		seats[ordered[n]].won += gain


func _close_hand() -> void:
	for s: Seat in seats:
		s.total = 0
		s.bet = 0
		s.net = s.stack - s.start_stack
	var busted: Array[Seat] = []
	for s: Seat in seats:
		if not s.out and s.stack <= 0:
			busted.append(s)
	busted.sort_custom(func(a: Seat, b: Seat) -> bool: return a.start_stack < b.start_stack)
	for s: Seat in busted:
		s.out = true
		_eliminated += 1
		s.out_rank = _eliminated
	street = Street.ENDED
	to_act = -1
	runout = false
	hand_over = true
	changed.emit()
	hand_finished.emit()
