class_name PokerAI
extends RefCounted
## IA de poker : formule de Chen (pré-flop) + Monte-Carlo (post-flop).


## Formule de Chen : force d'une main de départ (0 à 20, AA = 20).
static func chen(c1: int, c2: int) -> int:
	var r1: int = Cards.rank_of(c1)
	var r2: int = Cards.rank_of(c2)
	var hi: int = maxi(r1, r2)
	var lo: int = mini(r1, r2)
	var base: float
	match hi:
		14:
			base = 10.0
		13:
			base = 8.0
		12:
			base = 7.0
		11:
			base = 6.0
		10:
			base = 5.0
		_:
			base = hi / 2.0
	var pts: float = base
	if r1 == r2:
		pts = maxf(base * 2.0, 5.0)
	if Cards.suit_of(c1) == Cards.suit_of(c2):
		pts += 2.0
	var gap: int = hi - lo - 1
	if r1 != r2:
		if gap == 1:
			pts -= 1.0
		elif gap == 2:
			pts -= 2.0
		elif gap == 3:
			pts -= 4.0
		elif gap >= 4:
			pts -= 5.0
		if gap <= 1 and hi < 12:
			pts += 1.0
	return maxi(0, ceili(pts))


## Probabilité de gain par Monte-Carlo contre une main adverse aléatoire.
static func win_prob(
	hole: Array[int], board: Array[int], iters: int, rng: RandomNumberGenerator
) -> float:
	var used: Dictionary = {}
	for c: int in hole:
		used[c] = true
	for c: int in board:
		used[c] = true
	var deck: Array[int] = []
	for c: int in Cards.DECK_SIZE:
		if not used.has(c):
			deck.append(c)

	var need: int = 5 - board.size()
	var draw: int = 2 + need
	var n: int = deck.size()
	var score: float = 0.0
	for _i: int in iters:
		# Mélange partiel : seules les `draw` premières cartes comptent.
		for k: int in draw:
			var j: int = rng.randi_range(k, n - 1)
			var tmp: int = deck[k]
			deck[k] = deck[j]
			deck[j] = tmp
		var full_board: Array[int] = board.duplicate()
		for k: int in range(2, draw):
			full_board.append(deck[k])
		var mine: Array[int] = hole.duplicate()
		mine.append_array(full_board)
		var theirs: Array[int] = [deck[0], deck[1]]
		theirs.append_array(full_board)
		var cmp: int = HandEvaluator.cmp_score(
			HandEvaluator.evaluate7(mine), HandEvaluator.evaluate7(theirs)
		)
		if cmp > 0:
			score += 1.0
		elif cmp == 0:
			score += 0.5
	return score / float(iters)
