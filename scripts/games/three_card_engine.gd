class_name ThreeCardEngine
extends RefCounted
## Moteur Three Card Poker (contre le croupier).
## Mises : Ante (obligatoire) + Pair Plus (facultatif). Après avoir vu ses 3 cartes, le joueur
## « Joue » (mise égale à l'Ante) ou se couche (Ante perdue).
## Le croupier se qualifie avec Dame haute ou mieux. Mains : quinte flush > brelan > quinte > couleur > paire > hauteur.

signal changed
## Émis après `changed` quand la manche se termine (`net` = gain/perte sur la manche).
signal round_finished(net: int)

enum Phase { BET, DECIDE, DONE }
enum Hand { HIGH_CARD, PAIR, FLUSH, STRAIGHT, THREE_KIND, STRAIGHT_FLUSH }

const MIN_BET: int = 10
## Dame, 6, 4 : la plus petite main qu'il faut jouer (stratégie optimale).
const PLAY_THRESHOLD: Array[int] = [12, 6, 4]

var deck: Array[int] = []
var player: Array[int] = []
var dealer: Array[int] = []
var phase: Phase = Phase.BET
var ante: int = 0
var pair_plus: int = 0
## Mise « Jeu » posée après avoir vu ses cartes (0 si couché).
var play_bet: int = 0
var folded: bool = false
var revealed: bool = false
var message: String = ""
var net: int = 0
## Détail du résultat (pour l'affichage et les statistiques).
var pair_plus_won: bool = false
var dealer_qualified: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bankroll: BankrollState


func _init(bankroll: BankrollState) -> void:
	_bankroll = bankroll
	rng.randomize()
	deck = Cards.shuffled_deck(rng)


# --- Évaluation (statique, testable) -----------------------------------------


## Évalue 3 cartes : [catégorie, départage 1, 2, 3]. A-2-3 est la plus petite quinte.
static func evaluate(cards: Array[int]) -> Array[int]:
	var ranks: Array[int] = []
	for c: int in cards:
		ranks.append(Cards.rank_of(c))
	ranks.sort()
	ranks.reverse()
	var flush: bool = (
		Cards.suit_of(cards[0]) == Cards.suit_of(cards[1])
		and Cards.suit_of(cards[1]) == Cards.suit_of(cards[2])
	)
	var straight: bool = ranks[0] - 1 == ranks[1] and ranks[1] - 1 == ranks[2]
	var high: int = ranks[0]
	if not straight and ranks[0] == 14 and ranks[1] == 3 and ranks[2] == 2:
		straight = true
		high = 3
	if straight and flush:
		return [Hand.STRAIGHT_FLUSH, high, 0, 0]
	if ranks[0] == ranks[1] and ranks[1] == ranks[2]:
		return [Hand.THREE_KIND, ranks[0], 0, 0]
	if straight:
		return [Hand.STRAIGHT, high, 0, 0]
	if flush:
		return [Hand.FLUSH, ranks[0], ranks[1], ranks[2]]
	if ranks[0] == ranks[1]:
		return [Hand.PAIR, ranks[0], ranks[2], 0]
	if ranks[1] == ranks[2]:
		return [Hand.PAIR, ranks[1], ranks[0], 0]
	return [Hand.HIGH_CARD, ranks[0], ranks[1], ranks[2]]


## 1 si `a` bat `b`, -1 si elle perd, 0 si égalité parfaite.
static func compare(a: Array[int], b: Array[int]) -> int:
	for i: int in a.size():
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


static func hand_name(cards: Array[int]) -> String:
	var e: Array[int] = evaluate(cards)
	match e[0]:
		Hand.STRAIGHT_FLUSH:
			return "quinte flush"
		Hand.THREE_KIND:
			return "brelan de %s" % _rank_plural(e[1])
		Hand.STRAIGHT:
			return "quinte (%s haute)" % _rank_name(e[1])
		Hand.FLUSH:
			return "couleur (%s haute)" % _rank_name(e[1])
		Hand.PAIR:
			return "paire de %s" % _rank_plural(e[1])
	return "%s haute" % _rank_name(e[1])


static func _rank_name(rank: int) -> String:
	match rank:
		11:
			return "valet"
		12:
			return "dame"
		13:
			return "roi"
		14:
			return "as"
	return str(rank)


static func _rank_plural(rank: int) -> String:
	match rank:
		11:
			return "valets"
		12:
			return "dames"
		13:
			return "rois"
		14:
			return "as"
	return str(rank)


## Le croupier se qualifie avec une paire ou mieux, ou Dame haute au minimum.
static func dealer_qualifies(cards: Array[int]) -> bool:
	var e: Array[int] = evaluate(cards)
	return e[0] >= Hand.PAIR or e[1] >= 12


## Gain (en multiple de la mise) du Pair Plus selon la main du joueur ; 0 = perdu.
static func pair_plus_odds(category: int) -> int:
	match category:
		Hand.PAIR:
			return 1
		Hand.FLUSH:
			return 4
		Hand.STRAIGHT:
			return 6
		Hand.THREE_KIND:
			return 30
		Hand.STRAIGHT_FLUSH:
			return 40
	return 0


## Bonus d'Ante (payé quand on joue, même si le croupier gagne) ; 0 = aucun.
static func ante_bonus_odds(category: int) -> int:
	match category:
		Hand.STRAIGHT:
			return 1
		Hand.THREE_KIND:
			return 4
		Hand.STRAIGHT_FLUSH:
			return 5
	return 0


# --- Mises ----------------------------------------------------------------------


func can_add_ante(v: int) -> bool:
	return phase == Phase.BET and (ante + v) * 2 + pair_plus <= _bankroll.value


func can_add_pair_plus(v: int) -> bool:
	return phase == Phase.BET and ante * 2 + pair_plus + v <= _bankroll.value


func add_ante(v: int) -> void:
	if can_add_ante(v):
		ante += v
		changed.emit()


func add_pair_plus(v: int) -> void:
	if can_add_pair_plus(v):
		pair_plus += v
		changed.emit()


func clear_bets() -> void:
	if phase == Phase.BET and (ante > 0 or pair_plus > 0):
		ante = 0
		pair_plus = 0
		changed.emit()


func clear_pair_plus() -> void:
	if phase == Phase.BET and pair_plus > 0:
		pair_plus = 0
		changed.emit()


## Mise totale engagée sur la manche.
func total_staked() -> int:
	return ante + play_bet + pair_plus


func can_deal() -> bool:
	return phase == Phase.BET and ante >= MIN_BET and ante * 2 + pair_plus <= _bankroll.value


## Distribue : Ante (et Pair Plus) sont prélevés ; il faut pouvoir couvrir la mise « Jeu ».
func deal() -> void:
	if not can_deal():
		return
	_bankroll.add(-(ante + pair_plus))
	_bankroll.set_pending(ante + pair_plus)
	if deck.size() < 12:
		deck = Cards.shuffled_deck(rng)
	player = [deck.pop_back(), deck.pop_back(), deck.pop_back()]
	dealer = [deck.pop_back(), deck.pop_back(), deck.pop_back()]
	play_bet = 0
	folded = false
	revealed = false
	pair_plus_won = false
	dealer_qualified = false
	net = 0
	message = "Vous avez %s. Jouer ou vous coucher ?" % hand_name(player)
	phase = Phase.DECIDE
	changed.emit()


## « Jouer » : mise égale à l'Ante, puis le croupier dévoile sa main.
func play() -> void:
	if phase != Phase.DECIDE:
		return
	_bankroll.add(-ante)
	play_bet = ante
	_bankroll.set_pending(total_staked())
	_resolve()


## « Se coucher » : l'Ante est perdue (le Pair Plus reste joué).
func fold() -> void:
	if phase != Phase.DECIDE:
		return
	folded = true
	_resolve()


func _resolve() -> void:
	revealed = true
	var pe: Array[int] = evaluate(player)
	var de: Array[int] = evaluate(dealer)
	var payout: int = 0
	var parts: Array[String] = []

	if pair_plus > 0:
		var odds: int = pair_plus_odds(pe[0])
		if odds > 0:
			payout += pair_plus * (odds + 1)
			pair_plus_won = true
			parts.append("Pair Plus gagné (%s) : +%d" % [hand_name(player), pair_plus * odds])
		else:
			parts.append("Pair Plus perdu : -%d" % pair_plus)

	var main_text: String = ""
	if folded:
		main_text = "Vous vous couchez : Ante perdue (-%d)." % ante
	else:
		var bonus: int = ante_bonus_odds(pe[0])
		if bonus > 0:
			payout += ante * bonus
			parts.append("Bonus d'Ante (%s) : +%d" % [hand_name(player), ante * bonus])
		dealer_qualified = dealer_qualifies(dealer)
		if not dealer_qualified:
			payout += ante * 2 + play_bet
			main_text = "Le croupier ne se qualifie pas (%s) : Ante payée +%d, Jeu rendu." % [hand_name(dealer), ante]
		else:
			var cmp: int = compare(pe, de)
			if cmp > 0:
				payout += (ante + play_bet) * 2
				main_text = "Vous battez le croupier (%s contre %s) : +%d." % [hand_name(player), hand_name(dealer), ante + play_bet]
			elif cmp == 0:
				payout += ante + play_bet
				main_text = "Égalité (%s) : mises rendues." % hand_name(player)
			else:
				main_text = "Le croupier gagne (%s contre %s) : -%d." % [hand_name(dealer), hand_name(player), ante + play_bet]

	net = payout - total_staked()
	message = main_text
	if not parts.is_empty():
		message += "\n" + "\n".join(parts)
	_bankroll.pending = 0
	if payout > 0:
		_bankroll.add(payout)
	else:
		_bankroll.set_pending(0)
	phase = Phase.DONE
	changed.emit()
	round_finished.emit(net)


## Nouvelle manche : les mises sont conservées si la banque le permet.
func replay() -> void:
	player = []
	dealer = []
	play_bet = 0
	folded = false
	revealed = false
	message = ""
	net = 0
	pair_plus_won = false
	if ante * 2 + pair_plus > _bankroll.value:
		pair_plus = 0
	if ante * 2 > _bankroll.value:
		ante = (_bankroll.value / 2 / 5) * 5
	phase = Phase.BET
	changed.emit()
