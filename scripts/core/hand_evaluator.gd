class_name HandEvaluator
extends RefCounted
## Évaluation des mains de poker.
## Un score est une liste comparable lexicographiquement :
## [catégorie, départage...] avec 8 = quinte flush ... 0 = hauteur.

const HAND_NAMES: Array[String] = [
	"Hauteur",
	"Paire",
	"Double paire",
	"Brelan",
	"Quinte",
	"Couleur",
	"Full",
	"Carré",
	"Quinte flush",
]


static func _score(category: int, values: Array[int]) -> Array[int]:
	var out: Array[int] = [category]
	out.append_array(values)
	return out


static func _group_before(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	return a[1] > b[1]


## Évalue exactement 5 cartes (référence lente, utilisée par les tests).
static func evaluate5(cs: Array[int]) -> Array[int]:
	var ranks: Array[int] = []
	for c: int in cs:
		ranks.append(Cards.rank_of(c))
	ranks.sort()
	ranks.reverse()

	var first_suit: int = Cards.suit_of(cs[0])
	var is_flush: bool = true
	for c: int in cs:
		if Cards.suit_of(c) != first_suit:
			is_flush = false

	var uniq: Array[int] = []
	for r: int in ranks:
		if not uniq.has(r):
			uniq.append(r)
	var is_straight: bool = false
	var straight_high: int = 0
	if uniq.size() == 5:
		if uniq[0] - uniq[4] == 4:
			is_straight = true
			straight_high = uniq[0]
		elif uniq[0] == 14 and uniq[1] == 5:
			# Quinte « wheel » : A-2-3-4-5
			is_straight = true
			straight_high = 5

	var counts: Dictionary = {}
	for r: int in ranks:
		counts[r] = int(counts.get(r, 0)) + 1
	var groups: Array = []
	for r: int in counts.keys():
		groups.append([int(counts[r]), r])
	groups.sort_custom(_group_before)

	var g0: Array = groups[0]
	if is_straight and is_flush:
		return _score(8, [straight_high])
	if g0[0] == 4:
		return _score(7, [int(g0[1]), int(groups[1][1])])
	if g0[0] == 3 and groups[1][0] == 2:
		return _score(6, [int(g0[1]), int(groups[1][1])])
	if is_flush:
		return _score(5, ranks)
	if is_straight:
		return _score(4, [straight_high])
	if g0[0] == 3:
		return _score(3, [int(g0[1]), int(groups[1][1]), int(groups[2][1])])
	if g0[0] == 2 and groups[1][0] == 2:
		return _score(2, [int(g0[1]), int(groups[1][1]), int(groups[2][1])])
	if g0[0] == 2:
		return _score(1, [int(g0[1]), int(groups[1][1]), int(groups[2][1]), int(groups[3][1])])
	return _score(0, ranks)


## Comparaison lexicographique de deux scores (>0 si a gagne, <0 si b gagne).
static func cmp_score(a: Array[int], b: Array[int]) -> int:
	var n: int = maxi(a.size(), b.size())
	for i: int in n:
		var x: int = a[i] if i < a.size() else -1
		var y: int = b[i] if i < b.size() else -1
		if x != y:
			return x - y
	return 0


## Plus haute carte d'une quinte dans un masque de rangs (0 si aucune).
static func _straight_high(mask: int) -> int:
	var m: int = mask
	if (m & (1 << 14)) != 0:
		m |= 1 << 1  # l'As compte aussi comme 1
	for high: int in range(14, 4, -1):
		var need: int = 0x1F << (high - 4)
		if (m & need) == need:
			return high
	return 0


## Meilleure main de 5 cartes parmi 5 à 7 cartes (rapide : par comptage).
static func evaluate7(cs: Array[int]) -> Array[int]:
	var rc: Array[int] = []
	rc.resize(15)
	rc.fill(0)
	var sc: Array[int] = [0, 0, 0, 0]
	var smask: Array[int] = [0, 0, 0, 0]
	var all_mask: int = 0
	for c: int in cs:
		var r: int = Cards.rank_of(c)
		var s: int = Cards.suit_of(c)
		rc[r] += 1
		sc[s] += 1
		smask[s] |= 1 << r
		all_mask |= 1 << r

	var flush_suit: int = -1
	for s: int in 4:
		if sc[s] >= 5:
			flush_suit = s
	if flush_suit >= 0:
		var sf: int = _straight_high(smask[flush_suit])
		if sf > 0:
			return _score(8, [sf])

	var quads: Array[int] = []
	var trips: Array[int] = []
	var pairs: Array[int] = []
	for r: int in range(14, 1, -1):
		match rc[r]:
			4:
				quads.append(r)
			3:
				trips.append(r)
			2:
				pairs.append(r)

	if not quads.is_empty():
		return _score(7, [quads[0], _best_kickers(rc, [quads[0]], 1)[0]])

	if not trips.is_empty() and (trips.size() >= 2 or not pairs.is_empty()):
		var pair_rank: int = 0
		if trips.size() >= 2:
			pair_rank = trips[1]
		if not pairs.is_empty():
			pair_rank = maxi(pair_rank, pairs[0])
		return _score(6, [trips[0], pair_rank])

	if flush_suit >= 0:
		var fr: Array[int] = []
		for r: int in range(14, 1, -1):
			if (smask[flush_suit] & (1 << r)) != 0:
				fr.append(r)
				if fr.size() == 5:
					break
		return _score(5, fr)

	var st: int = _straight_high(all_mask)
	if st > 0:
		return _score(4, [st])

	if not trips.is_empty():
		var k3: Array[int] = _best_kickers(rc, [trips[0]], 2)
		return _score(3, [trips[0], k3[0], k3[1]])

	if pairs.size() >= 2:
		var k2: Array[int] = _best_kickers(rc, [pairs[0], pairs[1]], 1)
		return _score(2, [pairs[0], pairs[1], k2[0]])

	if pairs.size() == 1:
		var k1: Array[int] = _best_kickers(rc, [pairs[0]], 3)
		return _score(1, [pairs[0], k1[0], k1[1], k1[2]])

	var high: Array[int] = _best_kickers(rc, [], 5)
	return _score(0, high)


## Les `count` plus hauts rangs présents, hors rangs exclus.
static func _best_kickers(rc: Array[int], excluded: Array[int], count: int) -> Array[int]:
	var out: Array[int] = []
	for r: int in range(14, 1, -1):
		if rc[r] > 0 and not excluded.has(r):
			out.append(r)
			if out.size() == count:
				break
	while out.size() < count:
		out.append(0)
	return out


static func hand_name(score: Array[int]) -> String:
	if score[0] == 8 and score[1] == 14:
		return "Quinte flush royale"
	return HAND_NAMES[score[0]]


# --- Descriptions en français -------------------------------------------------


## Nom d'un rang : « As », « Roi », « 7 »… (pluriel : « Rois », « Dames »…).
static func rank_name(rank: int, plural: bool = false) -> String:
	match rank:
		14:
			return "As"
		13:
			return "Rois" if plural else "Roi"
		12:
			return "Dames" if plural else "Dame"
		11:
			return "Valets" if plural else "Valet"
		_:
			return str(rank)


## « d'As » / « de Rois » / « de 7 » (élision devant l'As).
static func _de(rank: int) -> String:
	if rank == 14:
		return "d'As"
	return "de " + rank_name(rank, true)


## « à l'As » / « à la Dame » / « au Roi » / « au 9 ».
static func _a(rank: int) -> String:
	match rank:
		14:
			return "à l'As"
		12:
			return "à la Dame"
		_:
			return "au " + rank_name(rank)


## Description lisible d'une main : « Paire de Rois », « Quinte à la Dame »…
static func describe(score: Array[int]) -> String:
	match score[0]:
		8:
			if score[1] == 14:
				return "Quinte flush royale"
			return "Quinte flush " + _a(score[1])
		7:
			return "Carré " + _de(score[1])
		6:
			return "Full %s par %s" % [rank_name(score[1], true), rank_name(score[2], true)]
		5:
			return "Couleur " + _a(score[1])
		4:
			return "Quinte " + _a(score[1])
		3:
			return "Brelan " + _de(score[1])
		2:
			return "Double paire %s et %s" % [rank_name(score[1], true), rank_name(score[2], true)]
		1:
			return "Paire " + _de(score[1])
		_:
			return "Hauteur " + rank_name(score[1])
