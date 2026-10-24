class_name BaccaratEngine
extends RefCounted
## Baccarat « punto banco » contre la banque.
## Mises : Joueur (1 contre 1), Banquier (1 contre 1 moins 5 % de commission), Égalité (8 contre 1).
## En cas d'égalité, les mises Joueur et Banquier sont rendues.

signal changed
signal round_finished(net: int)

enum Phase { BET, DONE }
enum Spot { PLAYER, BANKER, TIE }

const MIN_BET: int = 10
const TIE_ODDS: int = 8
const HISTORY_MAX: int = 14

var phase: Phase = Phase.BET
var deck: Array[int] = []
var player: Array[int] = []
var banker: Array[int] = []
var bets: Array[int] = [0, 0, 0]
var winner: Spot = Spot.PLAYER
var net: int = 0
var payout: int = 0
var message: String = ""
var history: Array[int] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bankroll: BankrollState


func _init(bankroll: BankrollState) -> void:
	_bankroll = bankroll
	rng.randomize()
	deck = Cards.shuffled_deck(rng)


# --- Règles (statiques, testables) -----------------------------------------------


## Valeur d'une carte : As 1, 2 à 9 leur numéro, 10 et figures 0.
static func card_value(card: int) -> int:
	var r: int = Cards.rank_of(card)
	if r == 14:
		return 1
	return 0 if r >= 10 else r


static func total(cards: Array[int]) -> int:
	var t: int = 0
	for c: int in cards:
		t += card_value(c)
	return t % 10


## Le Joueur tire une 3e carte avec 0 à 5.
static func player_draws(player_total: int) -> bool:
	return player_total <= 5


## Le Banquier tire-t-il ? `player_third` = valeur de la 3e carte du Joueur, -1 s'il est resté.
static func banker_draws(banker_total: int, player_third: int) -> bool:
	if player_third < 0:
		return banker_total <= 5
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third != 8
		4:
			return player_third >= 2 and player_third <= 7
		5:
			return player_third >= 4 and player_third <= 7
		6:
			return player_third == 6 or player_third == 7
	return false


static func side_name(side: int) -> String:
	return ["Joueur", "Banquier", "Égalité"][side]


# --- Mises ----------------------------------------------------------------------


func total_bet() -> int:
	return bets[0] + bets[1] + bets[2]


func can_add(v: int) -> bool:
	return phase == Phase.BET and total_bet() + v <= _bankroll.value


func add_bet(side: int, v: int) -> void:
	if can_add(v):
		bets[side] += v
		changed.emit()


func clear_bets() -> void:
	if phase == Phase.BET and total_bet() > 0:
		bets = [0, 0, 0]
		changed.emit()


func can_deal() -> bool:
	return phase == Phase.BET and total_bet() >= MIN_BET and total_bet() <= _bankroll.value


func deal() -> void:
	if not can_deal():
		return
	var staked: int = total_bet()
	_bankroll.add(-staked)
	_bankroll.set_pending(staked)
	if deck.size() < 20:
		deck = Cards.shuffled_deck(rng)
	player = [deck.pop_back()]
	banker = [deck.pop_back()]
	player.append(deck.pop_back())
	banker.append(deck.pop_back())
	_play_out(staked)


func _play_out(staked: int) -> void:
	var pt: int = total(player)
	var bt: int = total(banker)
	if pt < 8 and bt < 8:
		var third: int = -1
		if player_draws(pt):
			player.append(deck.pop_back())
			third = card_value(player[2])
		if banker_draws(total(banker), third):
			banker.append(deck.pop_back())
	pt = total(player)
	bt = total(banker)
	if pt > bt:
		winner = Spot.PLAYER
	elif bt > pt:
		winner = Spot.BANKER
	else:
		winner = Spot.TIE
	payout = 0
	match winner:
		Spot.PLAYER:
			payout = bets[0] * 2
		Spot.BANKER:
			payout = roundi(bets[1] * 1.95)
		Spot.TIE:
			payout = bets[0] + bets[1] + bets[2] * (TIE_ODDS + 1)
	net = payout - staked
	history.append(winner)
	while history.size() > HISTORY_MAX:
		history.remove_at(0)
	message = "%s %d — Banquier %d. " % ["Joueur", pt, bt]
	message += "Égalité." if winner == Spot.TIE else "%s gagne." % side_name(winner)
	if net > 0:
		message += " Vous gagnez %d." % net
	elif net < 0:
		message += " Vous perdez %d." % -net
	else:
		message += " Mises récupérées."
	_bankroll.pending = 0
	if payout > 0:
		_bankroll.add(payout)
	else:
		_bankroll.set_pending(0)
	phase = Phase.DONE
	changed.emit()
	round_finished.emit(net)


func replay() -> void:
	player = []
	banker = []
	net = 0
	payout = 0
	message = ""
	if total_bet() > _bankroll.value:
		bets = [0, 0, 0]
	phase = Phase.BET
	changed.emit()
