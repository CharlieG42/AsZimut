class_name Cards
extends RefCounted
## Utilitaires cartes.
## Une carte est un entier 0..51 : couleur * 13 + (rang - 2), rang 2..14 (14 = As).

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS }

const DECK_SIZE: int = 52


static func make(rank: int, suit: int) -> int:
	return suit * 13 + (rank - 2)


static func rank_of(card: int) -> int:
	return 2 + card % 13


@warning_ignore("integer_division")
static func suit_of(card: int) -> int:
	return card / 13


static func is_red(card: int) -> bool:
	var s: int = suit_of(card)
	return s == Suit.HEARTS or s == Suit.DIAMONDS


static func rank_label(card: int) -> String:
	match rank_of(card):
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		14:
			return "A"
		_:
			return str(rank_of(card))


## Les 52 cartes, couleur par couleur.
static func full_deck() -> Array[int]:
	var deck: Array[int] = []
	for c: int in DECK_SIZE:
		deck.append(c)
	return deck


## Mélange en place (Fisher-Yates).
static func shuffle(cards: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


static func shuffled_deck(rng: RandomNumberGenerator = null) -> Array[int]:
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var deck: Array[int] = full_deck()
	shuffle(deck, r)
	return deck
