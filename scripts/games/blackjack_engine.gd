class_name BlackjackEngine
extends RefCounted
## Moteur Blackjack : règles + croupier IA (tire jusqu'à 17).

signal changed

enum Phase { BET, PLAYER, DEALER, DONE }

const MIN_BET: int = 10

var deck: Array[int] = []
var player: Array[int] = []
var dealer: Array[int] = []
var phase: Phase = Phase.BET
var bet: int = 0
var message: String = ""
var revealed: bool = false
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
	if deck.size() < 15:
		deck = Cards.shuffled_deck(rng)
	player = [deck.pop_back(), deck.pop_back()]
	dealer = [deck.pop_back(), deck.pop_back()]
	revealed = false
	message = ""
	phase = Phase.DEALER if bj_value(player) == 21 else Phase.PLAYER
	changed.emit()


func hit() -> void:
	if phase != Phase.PLAYER:
		return
	player.append(deck.pop_back())
	var v: int = bj_value(player)
	if v > 21:
		revealed = true
		message = "Vous dépassez (%d). Mise perdue." % v
		phase = Phase.DONE
	elif v == 21:
		phase = Phase.DEALER
	changed.emit()


func stand() -> void:
	if phase != Phase.PLAYER:
		return
	phase = Phase.DEALER
	changed.emit()


func can_double() -> bool:
	return phase == Phase.PLAYER and player.size() == 2 and bet <= _bankroll.value


func double_down() -> void:
	if not can_double():
		return
	_bankroll.add(-bet)
	bet *= 2
	player.append(deck.pop_back())
	var v: int = bj_value(player)
	if v > 21:
		revealed = true
		message = "Vous dépassez (%d). Mise perdue." % v
		phase = Phase.DONE
	else:
		phase = Phase.DEALER
	changed.emit()


## Le croupier tire jusqu'à 17 (s'arrête sur un soft 17), puis résolution.
func dealer_plays() -> void:
	if phase != Phase.DEALER:
		return
	while bj_value(dealer) < 17 and not deck.is_empty():
		dealer.append(deck.pop_back())
	revealed = true
	_resolve()
	phase = Phase.DONE
	changed.emit()


func _resolve() -> void:
	var pv: int = bj_value(player)
	var dv: int = bj_value(dealer)
	var p_nat: bool = player.size() == 2 and pv == 21
	var d_nat: bool = dealer.size() == 2 and dv == 21
	var payout: int = 0
	if p_nat and d_nat:
		payout = bet
		message = "Double blackjack — égalité, mise remboursée."
	elif p_nat:
		payout = roundi(bet * 2.5)
		message = "Blackjack ! Vous gagnez %d." % roundi(bet * 1.5)
	elif d_nat:
		message = "Blackjack du croupier — mise perdue."
	elif pv > 21:
		message = "Vous dépassez (%d). Mise perdue." % pv
	elif dv > 21:
		payout = bet * 2
		message = "Le croupier crève (%d) ! Vous gagnez %d." % [dv, bet]
	elif pv > dv:
		payout = bet * 2
		message = "%d contre %d — vous gagnez %d !" % [pv, dv, bet]
	elif pv < dv:
		message = "%d contre %d — le croupier gagne." % [pv, dv]
	else:
		payout = bet
		message = "Égalité — mise remboursée."
	if payout > 0:
		_bankroll.add(payout)


func replay() -> void:
	var next_bet: int = mini(bet, _bankroll.value)
	player = []
	dealer = []
	message = ""
	revealed = false
	bet = next_bet
	phase = Phase.BET
	changed.emit()
