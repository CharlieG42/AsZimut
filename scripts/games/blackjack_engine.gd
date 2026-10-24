class_name BlackjackEngine
extends RefCounted
## Moteur Blackjack : règles + croupier IA (tire jusqu'à 17).
## Options : double, split (une fois, As séparés = une carte chacun) et assurance quand le croupier montre un As.

signal changed
## Émis après `changed` quand la manche se termine (`net` = gain/perte sur la manche).
signal round_finished(outcome: Outcome, net: int)

enum Phase { BET, PLAYER, DEALER, DONE, INSURANCE }
enum Outcome { NONE, WIN, LOSE, PUSH, BLACKJACK }

const MIN_BET: int = 10

var deck: Array[int] = []
var player: Array[int] = []
## Seconde main après un split (vide sinon), sa mise, et la main en cours (0 ou 1).
var split_hand: Array[int] = []
var split_bet: int = 0
var active_hand: int = 0
var has_split: bool = false
## Mise d'assurance (moitié de la mise) prise contre un As du croupier.
var insurance: int = 0
var _hand_done: Array[bool] = [false, false]
var dealer: Array[int] = []
var phase: Phase = Phase.BET
var bet: int = 0
## Mise de départ de la manche (avant un éventuel doublement) : c'est elle qui est reprise en rejouant.
var base_bet: int = 0
var message: String = ""
var revealed: bool = false
var outcome: Outcome = Outcome.NONE
var net: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bankroll: BankrollState


func _init(bankroll: BankrollState) -> void:
	_bankroll = bankroll
	rng.randomize()
	deck = Cards.shuffled_deck(rng)


## Valeur d'une main de blackjack (As = 1 ou 11).
static func bj_value(cards: Array[int]) -> int:
	var total: int = 0
	var aces: int = 0
	for c: int in cards:
		var r: int = Cards.rank_of(c)
		if r == 14:
			aces += 1
			total += 11
		elif r > 10:
			total += 10
		else:
			total += r
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func add_to_bet(v: int) -> void:
	if phase == Phase.BET and v <= _bankroll.value - bet:
		bet += v
		changed.emit()


func clear_bet() -> void:
	if phase == Phase.BET and bet > 0:
		bet = 0
		changed.emit()


func deal() -> void:
	if phase != Phase.BET or bet < MIN_BET or bet > _bankroll.value:
		return
	_bankroll.add(-bet)
	_bankroll.set_pending(bet)
	base_bet = bet
	if deck.size() < 15:
		deck = Cards.shuffled_deck(rng)
	player = [deck.pop_back(), deck.pop_back()]
	dealer = [deck.pop_back(), deck.pop_back()]
	split_hand = []
	split_bet = 0
	active_hand = 0
	has_split = false
	insurance = 0
	_hand_done = [false, false]
	revealed = false
	message = ""
	outcome = Outcome.NONE
	net = 0
	if bj_value(player) == 21:
		phase = Phase.DEALER
	elif Cards.rank_of(dealer[0]) == 14:
		phase = Phase.INSURANCE
		message = "Le croupier montre un As : assurance ?"
	else:
		phase = Phase.PLAYER
	changed.emit()


## Mise totale engagée sur la manche (mains + assurance).
func total_staked() -> int:
	return bet + split_bet + insurance


func insurance_cost() -> int:
	return bet / 2


func can_insure() -> bool:
	return phase == Phase.INSURANCE and insurance_cost() > 0 and insurance_cost() <= _bankroll.value


## Assurance : paie 2 contre 1 si le croupier a blackjack.
func take_insurance() -> void:
	if not can_insure():
		return
	insurance = insurance_cost()
	_bankroll.add(-insurance)
	_bankroll.set_pending(total_staked())
	_after_insurance()


func decline_insurance() -> void:
	if phase != Phase.INSURANCE:
		return
	_after_insurance()


## Le croupier vérifie s'il a blackjack (As visible).
func _after_insurance() -> void:
	if bj_value(dealer) == 21:
		var payout: int = insurance * 3
		var text: String = "Blackjack du croupier."
		if insurance > 0:
			text += " L'assurance vous rend %d." % payout
		_finish(Outcome.LOSE if insurance == 0 else Outcome.PUSH, payout, text)
		_notify_finished()
		return
	message = "Pas de blackjack pour le croupier." + (" Assurance perdue." if insurance > 0 else "")
	phase = Phase.PLAYER
	changed.emit()


## Main en cours (la première, ou la seconde après un split).
func current_hand() -> Array[int]:
	return split_hand if active_hand == 1 else player


func current_bet() -> int:
	return split_bet if active_hand == 1 else bet


func can_split() -> bool:
	if phase != Phase.PLAYER or has_split or player.size() != 2:
		return false
	var a: int = mini(Cards.rank_of(player[0]), 10)
	var b: int = mini(Cards.rank_of(player[1]), 10)
	if Cards.rank_of(player[0]) == 14 or Cards.rank_of(player[1]) == 14:
		a = Cards.rank_of(player[0])
		b = Cards.rank_of(player[1])
	return a == b and bet <= _bankroll.value


## Sépare une paire en deux mains, chacune avec la même mise.
func split() -> void:
	if not can_split():
		return
	_bankroll.add(-bet)
	split_bet = bet
	has_split = true
	split_hand = [player.pop_back()]
	player.append(deck.pop_back())
	split_hand.append(deck.pop_back())
	_bankroll.set_pending(total_staked())
	active_hand = 0
	message = "Main 1 sur 2."
	if Cards.rank_of(split_hand[0]) == 14:
		# As séparés : une seule carte par main.
		_hand_done = [true, true]
		phase = Phase.DEALER
		message = "As séparés : une carte chacun."
	elif bj_value(player) == 21:
		_next_hand()
		return
	changed.emit()


func hit() -> void:
	if phase != Phase.PLAYER:
		return
	if has_split:
		var h: Array[int] = current_hand()
		h.append(deck.pop_back())
		if bj_value(h) >= 21:
			_next_hand()
		else:
			changed.emit()
		return
	player.append(deck.pop_back())
	var v: int = bj_value(player)
	if v > 21:
		_finish(Outcome.LOSE, 0, "Vous dépassez (%d). Mise perdue." % v)
		_notify_finished()
		return
	if v == 21:
		phase = Phase.DEALER
	changed.emit()


func stand() -> void:
	if phase != Phase.PLAYER:
		return
	if has_split:
		_next_hand()
		return
	phase = Phase.DEALER
	changed.emit()


func can_double() -> bool:
	return phase == Phase.PLAYER and current_hand().size() == 2 and current_bet() <= _bankroll.value


func double_down() -> void:
	if not can_double():
		return
	if has_split:
		_bankroll.add(-current_bet())
		if active_hand == 1:
			split_bet *= 2
		else:
			bet *= 2
		_bankroll.set_pending(total_staked())
		current_hand().append(deck.pop_back())
		_next_hand()
		return
	_bankroll.add(-bet)
	bet *= 2
	_bankroll.set_pending(total_staked())
	player.append(deck.pop_back())
	var v: int = bj_value(player)
	if v > 21:
		_finish(Outcome.LOSE, 0, "Vous dépassez (%d). Mise perdue." % v)
		_notify_finished()
		return
	phase = Phase.DEALER
	changed.emit()


## Passe à la main suivante du split, ou au croupier.
func _next_hand() -> void:
	_hand_done[active_hand] = true
	if active_hand == 0 and bj_value(split_hand) < 21:
		active_hand = 1
		message = "Main 2 sur 2."
		changed.emit()
		return
	active_hand = 1
	_hand_done = [true, true]
	if bj_value(player) > 21 and bj_value(split_hand) > 21:
		_resolve()
		_notify_finished()
		return
	phase = Phase.DEALER
	changed.emit()


## Le croupier tire jusqu'à 17 (s'arrête sur un soft 17), puis résolution.
func dealer_plays() -> void:
	if phase != Phase.DEALER:
		return
	while bj_value(dealer) < 17 and not deck.is_empty():
		dealer.append(deck.pop_back())
	_resolve()
	_notify_finished()


func _notify_finished() -> void:
	changed.emit()
	round_finished.emit(outcome, net)


## Termine la manche : crédite `payout`, mémorise l'issue et le gain net.
func _finish(result: Outcome, payout: int, text: String) -> void:
	revealed = true
	outcome = result
	message = text
	net = payout - total_staked()
	_bankroll.pending = 0
	if payout > 0:
		_bankroll.add(payout)
	else:
		_bankroll.set_pending(0)
	phase = Phase.DONE


## Gain (mise rendue comprise) d'une main jouée après un split : pas de blackjack possible.
func _hand_payout(hand: Array[int], stake: int, dv: int, d_nat: bool) -> Array:
	var pv: int = bj_value(hand)
	if pv > 21:
		return [0, "perdue (%d)" % pv]
	if d_nat:
		return [0, "perdue (blackjack du croupier)"]
	if dv > 21 or pv > dv:
		return [stake * 2, "gagnée (%d)" % pv]
	if pv == dv:
		return [stake, "égalité (%d)" % pv]
	return [0, "perdue (%d)" % pv]


func _resolve() -> void:
	if has_split:
		var dvs: int = bj_value(dealer)
		var nat: bool = dealer.size() == 2 and dvs == 21
		var r1: Array = _hand_payout(player, bet, dvs, nat)
		var r2: Array = _hand_payout(split_hand, split_bet, dvs, nat)
		var payout: int = int(r1[0]) + int(r2[0])
		var staked: int = bet + split_bet
		var result: Outcome = Outcome.WIN if payout > staked else (Outcome.LOSE if payout < staked else Outcome.PUSH)
		var dealer_text: String = "croupier %d" % dvs if dvs <= 21 else "le croupier crève (%d)" % dvs
		_finish(result, payout, "Main 1 %s · Main 2 %s — %s." % [r1[1], r2[1], dealer_text])
		return
	var pv: int = bj_value(player)
	var dv: int = bj_value(dealer)
	var p_nat: bool = player.size() == 2 and pv == 21
	var d_nat: bool = dealer.size() == 2 and dv == 21
	if p_nat and d_nat:
		_finish(Outcome.PUSH, bet, "Double blackjack — égalité, mise remboursée.")
	elif p_nat:
		_finish(Outcome.BLACKJACK, roundi(bet * 2.5), "Blackjack ! Vous gagnez %d." % roundi(bet * 1.5))
	elif d_nat:
		_finish(Outcome.LOSE, 0, "Blackjack du croupier — mise perdue.")
	elif pv > 21:
		_finish(Outcome.LOSE, 0, "Vous dépassez (%d). Mise perdue." % pv)
	elif dv > 21:
		_finish(Outcome.WIN, bet * 2, "Le croupier crève (%d) ! Vous gagnez %d." % [dv, bet])
	elif pv > dv:
		_finish(Outcome.WIN, bet * 2, "%d contre %d — vous gagnez %d !" % [pv, dv, bet])
	elif pv < dv:
		_finish(Outcome.LOSE, 0, "%d contre %d — le croupier gagne." % [pv, dv])
	else:
		_finish(Outcome.PUSH, bet, "Égalité — mise remboursée.")


func replay() -> void:
	# On repart de la mise de départ, pas de la mise doublée.
	var next_bet: int = mini(base_bet if base_bet > 0 else bet, _bankroll.value)
	player = []
	dealer = []
	split_hand = []
	split_bet = 0
	has_split = false
	active_hand = 0
	insurance = 0
	message = ""
	revealed = false
	outcome = Outcome.NONE
	net = 0
	bet = next_bet
	phase = Phase.BET
	changed.emit()
