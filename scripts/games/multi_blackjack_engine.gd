class_name MultiBlackjackEngine
extends RefCounted
## Blackjack à 1–5 joueurs sur un même appareil, contre le croupier.
## Chaque joueur a sa propre pile ; ils misent puis jouent chacun leur tour.

signal changed
signal round_finished

enum Phase { BET, PLAY, DEALER, DONE, INSURANCE }

const MIN_BET: int = 10
const MIN_PLAYERS: int = 1
const MAX_PLAYERS: int = 5


class Seat extends RefCounted:
	var name: String
	var stack: int
	var bet: int = 0
	## Mise de départ de la manche (avant un éventuel doublement), reprise à la manche suivante.
	var base_bet: int = 0
	var ready: bool = false  # mise validée
	var is_bot: bool = false
	var hand: Array[int] = []
	var done: bool = false  # a fini de jouer (reste, 21 ou dépasse)
	## Seconde main après un split (vide sinon), sa mise, et la main en cours (0 ou 1).
	var split_hand: Array[int] = []
	var split_bet: int = 0
	var has_split: bool = false
	var active_hand: int = 0
	## Assurance prise contre un As du croupier (0 = non) et décision déjà rendue ou non.
	var insurance: int = 0
	var insurance_decided: bool = false
	var out: bool = false  # n'a plus de quoi miser
	var result: BlackjackEngine.Outcome = BlackjackEngine.Outcome.NONE
	var net: int = 0

	func _init(player_name: String, chips: int) -> void:
		name = player_name
		stack = chips

	## Mise totale engagée sur la manche (mains + assurance).
	func staked() -> int:
		return bet + split_bet + insurance

	func current_hand() -> Array[int]:
		return split_hand if active_hand == 1 else hand

	func current_bet() -> int:
		return split_bet if active_hand == 1 else bet

	## Efface tout ce qui est propre à une manche (la mise de départ est conservée à part).
	func clear_round() -> void:
		hand = []
		split_hand = []
		split_bet = 0
		has_split = false
		active_hand = 0
		insurance = 0
		insurance_decided = false
		done = false
		ready = false
		result = BlackjackEngine.Outcome.NONE
		net = 0


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
	return current >= 0 and seats[current].is_bot and phase in [Phase.BET, Phase.PLAY, Phase.INSURANCE]


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
	if phase == Phase.INSURANCE and current_is_bot():
		decline_insurance()  # la stratégie de base ne prend jamais l'assurance
		return
	if phase != Phase.PLAY or not current_is_bot():
		return
	var errors: Array[float] = [0.25, 0.08, 0.0]
	var s: Seat = seats[current]
	if can_split() and BlackjackAdvisor.should_split(s.hand, dealer[0]) and rng.randf() >= errors[level]:
		split()
		return
	var move: BlackjackAdvisor.Move = BlackjackAdvisor.bot_move(
		s.current_hand(), dealer[0], can_double(), errors[level], rng
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
	return s.current_hand().size() == 2 and not s.done and s.stack >= s.current_bet()


## Paire jouable en deux mains (même valeur ; les As seulement entre eux), une seule fois par manche.
func can_split() -> bool:
	if phase != Phase.PLAY or current < 0:
		return false
	var s: Seat = seats[current]
	if s.done or s.has_split or s.hand.size() != 2 or s.stack < s.bet:
		return false
	var a: int = Cards.rank_of(s.hand[0])
	var b: int = Cards.rank_of(s.hand[1])
	if a != 14 and b != 14:
		a = mini(a, 10)
		b = mini(b, 10)
	return a == b


## Assurance : la moitié de la mise, payée 2 contre 1 si le croupier a blackjack.
func insurance_cost() -> int:
	return seats[current].bet / 2 if current >= 0 else 0


func can_insure() -> bool:
	if phase != Phase.INSURANCE or current < 0:
		return false
	var cost: int = insurance_cost()
	return cost > 0 and cost <= seats[current].stack


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
	s.base_bet = s.bet
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
	var h: Array[int] = s.current_hand()
	h.append(deck.pop_back())
	if BlackjackEngine.bj_value(h) >= 21:
		_finish_hand(s)
	else:
		changed.emit()


func stand() -> void:
	if phase != Phase.PLAY or current < 0:
		return
	_finish_hand(seats[current])


func double_down() -> void:
	if not can_double():
		return
	var s: Seat = seats[current]
	s.stack -= s.current_bet()
	if s.active_hand == 1:
		s.split_bet *= 2
	else:
		s.bet *= 2
	s.current_hand().append(deck.pop_back())
	_finish_hand(s)


## Sépare une paire : seconde main avec la même mise, une carte de plus à chacune.
func split() -> void:
	if not can_split():
		return
	var s: Seat = seats[current]
	s.stack -= s.bet
	s.split_bet = s.bet
	s.has_split = true
	s.active_hand = 0
	s.split_hand = [s.hand.pop_back()]
	s.hand.append(deck.pop_back())
	s.split_hand.append(deck.pop_back())
	if Cards.rank_of(s.split_hand[0]) == 14:
		# As séparés : une seule carte par main.
		s.done = true
		_advance()
	elif BlackjackEngine.bj_value(s.hand) == 21:
		_finish_hand(s)
	else:
		changed.emit()


## Termine la main en cours : passe à la seconde main d'un split, ou au joueur suivant.
func _finish_hand(s: Seat) -> void:
	if s.has_split and s.active_hand == 0 and BlackjackEngine.bj_value(s.split_hand) < 21:
		s.active_hand = 1
		changed.emit()
		return
	if s.has_split:
		s.active_hand = 1
	s.done = true
	_advance()


## Assurance du joueur courant.
func take_insurance() -> void:
	if not can_insure():
		return
	var s: Seat = seats[current]
	s.insurance = insurance_cost()
	s.stack -= s.insurance
	_next_insurer()


func decline_insurance() -> void:
	if phase != Phase.INSURANCE or current < 0:
		return
	_next_insurer()


## Joueur suivant à qui proposer l'assurance ; après le dernier, le croupier regarde sa carte cachée.
func _next_insurer() -> void:
	seats[current].insurance_decided = true
	for i: int in range(current + 1, seats.size()):
		var s: Seat = seats[i]
		if s.ready and not s.insurance_decided:
			current = i
			if s.is_bot or insurance_cost() <= s.stack:
				changed.emit()
				return
			s.insurance_decided = true  # pas assez de jetons : rien à proposer
	_end_insurance()


func _end_insurance() -> void:
	current = -1
	if BlackjackEngine.bj_value(dealer) == 21:
		# Blackjack du croupier : toutes les mains sont réglées tout de suite.
		phase = Phase.DEALER
		changed.emit()
		return
	phase = Phase.PLAY
	_advance()


## Le croupier tire jusqu'à 17, puis chaque main est réglée.
func dealer_plays() -> void:
	if phase != Phase.DEALER:
		return
	revealed = true
	var contested: bool = false
	for s: Seat in seats:
		if s.ready and (BlackjackEngine.bj_value(s.hand) <= 21 or (s.has_split and BlackjackEngine.bj_value(s.split_hand) <= 21)):
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
		s.clear_round()
		s.bet = mini(s.base_bet if s.base_bet > 0 else s.bet, s.stack)
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
	current = -1
	if Cards.rank_of(dealer[0]) == 14 and _first_insurer() >= 0:
		phase = Phase.INSURANCE
		current = _first_insurer()
		changed.emit()
		return
	phase = Phase.PLAY
	_advance()


## Premier joueur à qui proposer l'assurance (un As du croupier est visible).
func _first_insurer() -> int:
	for i: int in seats.size():
		var s: Seat = seats[i]
		if s.ready:
			if s.is_bot or s.bet / 2 <= s.stack and s.bet / 2 > 0:
				return i
			s.insurance_decided = true
	return -1


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
	var payout: int = 0
	if s.has_split:
		var p1: int = _hand_payout(s.hand, s.bet, dv, d_nat)
		var p2: int = _hand_payout(s.split_hand, s.split_bet, dv, d_nat)
		payout = p1 + p2
		var staked_hands: int = s.bet + s.split_bet
		if payout > staked_hands:
			s.result = BlackjackEngine.Outcome.WIN
		elif payout < staked_hands:
			s.result = BlackjackEngine.Outcome.LOSE
		else:
			s.result = BlackjackEngine.Outcome.PUSH
	else:
		var pv: int = BlackjackEngine.bj_value(s.hand)
		var p_nat: bool = s.hand.size() == 2 and pv == 21
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
	if d_nat and s.insurance > 0:
		payout += s.insurance * 3
	s.stack += payout
	s.net = payout - s.staked()


## Gain (mise rendue comprise) d'une main jouée après un split : pas de blackjack possible.
func _hand_payout(hand: Array[int], stake: int, dv: int, d_nat: bool) -> int:
	var pv: int = BlackjackEngine.bj_value(hand)
	if pv > 21 or d_nat:
		return 0
	if dv > 21 or pv > dv:
		return stake * 2
	if pv == dv:
		return stake
	return 0


## Instantané pris au début des mises (aucune mise encore prélevée).
func snapshot() -> Dictionary:
	var stacks: Array = []
	for s: Seat in seats:
		stacks.append(s.stack + (s.staked() if s.ready else 0))
	return {"stacks": stacks, "rounds": rounds}


func restore(snap: Dictionary) -> void:
	var stacks: Array = snap.get("stacks", [])
	for i: int in mini(seats.size(), stacks.size()):
		var s: Seat = seats[i]
		s.stack = int(stacks[i])
		s.bet = 0
		s.clear_round()
		s.out = s.stack < MIN_BET
		s.result = BlackjackEngine.Outcome.NONE
	rounds = int(snap.get("rounds", 0))
	dealer = []
	revealed = false
	phase = Phase.BET
	current = _next_bettor(-1)
	changed.emit()


## Piles de départ propres à chaque siège (banques personnelles des joueurs enregistrés).
func set_stacks(stacks: Array[int]) -> void:
	for i: int in mini(seats.size(), stacks.size()):
		seats[i].stack = stacks[i]
