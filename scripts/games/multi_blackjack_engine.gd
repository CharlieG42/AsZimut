class_name MultiBlackjackEngine
extends RefCounted
## Blackjack à 1–5 joueurs sur un même appareil, contre le croupier.
## Chaque joueur a sa propre pile ; ils misent puis jouent chacun leur tour.

signal changed
signal round_finished

enum Phase { BET, PLAY, DEALER, DONE }

const MIN_BET: int = 10
const MIN_PLAYERS: int = 1
const MAX_PLAYERS: int = 5


class Seat extends RefCounted:
	var name: String
	var stack: int
	var bet: int = 0
	var ready: bool = false  # mise validée
	var is_bot: bool = false
	var hand: Array[int] = []
	var done: bool = false  # a fini de jouer (reste, 21 ou dépasse)
	var out: bool = false  # n'a plus de quoi miser
	var result: BlackjackEngine.Outcome = BlackjackEngine.Outcome.NONE
	var net: int = 0

	func _init(player_name: String, chips: int) -> void:
		name = player_name
		stack = chips


var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seats: Array[Seat] = []
var dealer: Array[int] = []
var deck: Array[int] = []
var phase: Phase = Phase.BET
var current: int = -1
var revealed: bool = false
var rounds: int = 0
var aborted: bool = false
var level: int = 1
var has_humans: bool = false


func _init(names: Array[String], chips: int, bots: Array[bool] = [], bot_level: int = 1) -> void:
	level = clampi(bot_level, 0, 2)
	for i: int in names.size():
		var seat: Seat = Seat.new(names[i], chips)
		seat.is_bot = i < bots.size() and bots[i]
		if not seat.is_bot:
			has_humans = true
		seats.append(seat)
	rng.randomize()
	deck = Cards.shuffled_deck(rng)
	current = _next_bettor(-1)


# --- Accesseurs -------------------------------------------------------------


func alive_count() -> int:
	var n: int = 0
	for s: Seat in seats:
		if not s.out:
			n += 1
	return n


func humans_alive() -> int:
	var n: int = 0
	for s: Seat in seats:
		if not s.is_bot and not s.out:
			n += 1
	return n


func is_game_over() -> bool:
	return aborted or alive_count() == 0 or (has_humans and humans_alive() == 0)


func current_is_bot() -> bool:
	return current >= 0 and seats[current].is_bot and phase in [Phase.BET, Phase.PLAY]


## Mise d'un bot : environ 6 % de sa pile, arrondie à 10, entre 10 et 100.
func bot_bet() -> void:
	if phase != Phase.BET or not current_is_bot():
		return
	var s: Seat = seats[current]
	var amount: int = clampi(snappedi(roundi(s.stack * 0.06), 10), MIN_BET, 100)
	s.bet = mini(amount, s.stack)
	confirm_bet()


## Un coup du bot courant (stratégie de base, avec des erreurs aux niveaux faibles).
func bot_play() -> void:
	if phase != Phase.PLAY or not current_is_bot():
		return
	var errors: Array[float] = [0.25, 0.08, 0.0]
	var s: Seat = seats[current]
	var move: BlackjackAdvisor.Move = BlackjackAdvisor.bot_move(
		s.hand, dealer[0], can_double(), errors[level], rng
	)
	match move:
		BlackjackAdvisor.Move.HIT:
			hit()
		BlackjackAdvisor.Move.DOUBLE:
			double_down()
		_:
			stand()


func can_double() -> bool:
	if phase != Phase.PLAY or current < 0:
		return false
	var s: Seat = seats[current]
	return s.hand.size() == 2 and not s.done and s.stack >= s.bet


## Joueurs triés par pile décroissante.
func standings() -> Array[int]:
	var order: Array[int] = []
	for i: int in seats.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return seats[a].stack > seats[b].stack)
	return order


# --- Mises ------------------------------------------------------------------


func add_to_bet(value: int) -> void:
	if phase != Phase.BET or current < 0:
		return
	var s: Seat = seats[current]
	if value <= s.stack - s.bet:
		s.bet += value
		changed.emit()


func clear_bet() -> void:
	if phase == Phase.BET and current >= 0 and seats[current].bet > 0:
		seats[current].bet = 0
		changed.emit()


## Valide la mise du joueur courant ; distribue quand tout le monde a misé.
func confirm_bet() -> void:
	if phase != Phase.BET or current < 0:
		return
	var s: Seat = seats[current]
	if s.bet < MIN_BET or s.bet > s.stack:
		return
	s.stack -= s.bet
	s.ready = true
	var next: int = _next_bettor(current)
	if next < 0:
		_deal()
	else:
		current = next
		changed.emit()


# --- Jeu --------------------------------------------------------------------


func hit() -> void:
	if phase != Phase.PLAY or current < 0:
		return
	var s: Seat = seats[current]
	s.hand.append(deck.pop_back())
	if BlackjackEngine.bj_value(s.hand) >= 21:
		s.done = true
		_advance()
	else:
		changed.emit()


func stand() -> void:
	if phase != Phase.PLAY or current < 0:
		return
	seats[current].done = true
	_advance()


func double_down() -> void:
	if not can_double():
		return
	var s: Seat = seats[current]
	s.stack -= s.bet
	s.bet *= 2
	s.hand.append(deck.pop_back())
	s.done = true
	_advance()


## Le croupier tire jusqu'à 17, puis chaque main est réglée.
func dealer_plays() -> void:
	if phase != Phase.DEALER:
		return
	revealed = true
	var contested: bool = false
	for s: Seat in seats:
		if s.ready and BlackjackEngine.bj_value(s.hand) <= 21:
			contested = true
	while contested and BlackjackEngine.bj_value(dealer) < 17 and not deck.is_empty():
		dealer.append(deck.pop_back())
	var dv: int = BlackjackEngine.bj_value(dealer)
	var d_nat: bool = dealer.size() == 2 and dv == 21
	for s: Seat in seats:
		if s.ready:
			_settle(s, dv, d_nat)
	phase = Phase.DONE
	rounds += 1
	for s: Seat in seats:
		if s.stack < MIN_BET:
			s.out = true
	changed.emit()
	round_finished.emit()


## Prépare la manche suivante : chacun reprend sa dernière mise si possible.
func next_round() -> void:
	if phase != Phase.DONE:
		return
	for s: Seat in seats:
		s.hand = []
		s.done = false
		s.ready = false
		s.result = BlackjackEngine.Outcome.NONE
		s.net = 0
		s.bet = mini(s.bet, s.stack)
		if s.bet < MIN_BET:
			s.bet = 0
	dealer = []
	revealed = false
	phase = Phase.BET
	current = _next_bettor(-1)
	changed.emit()


func abort() -> void:
	aborted = true
	changed.emit()


# --- Interne ----------------------------------------------------------------


func _next_bettor(from: int) -> int:
	for i: int in range(from + 1, seats.size()):
		if not seats[i].out and not seats[i].ready:
			return i
	return -1


func _deal() -> void:
	if deck.size() < 12 + seats.size() * 6:
		deck = Cards.shuffled_deck(rng)
	for s: Seat in seats:
		if s.ready:
			s.hand = [deck.pop_back(), deck.pop_back()]
			s.done = BlackjackEngine.bj_value(s.hand) == 21
	dealer = [deck.pop_back(), deck.pop_back()]
	revealed = false
	phase = Phase.PLAY
	current = -1
	_advance()


## Passe au joueur suivant qui doit encore jouer, sinon au croupier.
func _advance() -> void:
	for i: int in range(current + 1, seats.size()):
		if seats[i].ready and not seats[i].done:
			current = i
			changed.emit()
			return
	current = -1
	phase = Phase.DEALER
	changed.emit()


func _settle(s: Seat, dv: int, d_nat: bool) -> void:
	var pv: int = BlackjackEngine.bj_value(s.hand)
	var p_nat: bool = s.hand.size() == 2 and pv == 21
	var payout: int = 0
	if p_nat and d_nat:
		s.result = BlackjackEngine.Outcome.PUSH
		payout = s.bet
	elif p_nat:
		s.result = BlackjackEngine.Outcome.BLACKJACK
		payout = roundi(s.bet * 2.5)
	elif d_nat or pv > 21:
		s.result = BlackjackEngine.Outcome.LOSE
	elif dv > 21 or pv > dv:
		s.result = BlackjackEngine.Outcome.WIN
		payout = s.bet * 2
	elif pv < dv:
		s.result = BlackjackEngine.Outcome.LOSE
	else:
		s.result = BlackjackEngine.Outcome.PUSH
		payout = s.bet
	s.stack += payout
	s.net = payout - s.bet
