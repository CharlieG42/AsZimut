class_name BlackjackAdvisor
extends RefCounted
## Stratégie de base du blackjack : sert de conseil pour les débutants et de cerveau aux bots.

enum Move { HIT, STAND, DOUBLE }


## Valeur de la carte visible du croupier (2..11, l'As vaut 11).
static func up_value(up_card: int) -> int:
	var shown: Array[int] = [up_card]
	return BlackjackEngine.bj_value(shown)


## Main « souple » : contient un As compté pour 11.
static func is_soft(hand: Array[int]) -> bool:
	var raw: int = 0
	var aces: int = 0
	for c: int in hand:
		var r: int = Cards.rank_of(c)
		if r == 14:
			aces += 1
			raw += 1
		else:
			raw += mini(r, 10)
	return aces > 0 and raw + 10 <= 21


static func recommend(hand: Array[int], up_card: int, can_double: bool) -> Move:
	var total: int = BlackjackEngine.bj_value(hand)
	var up: int = up_value(up_card)
	var move: Move = Move.STAND
	if total >= 21:
		return Move.STAND
	if is_soft(hand):
		if total <= 14:
			move = Move.DOUBLE if up >= 5 and up <= 6 else Move.HIT
		elif total <= 16:
			move = Move.DOUBLE if up >= 4 and up <= 6 else Move.HIT
		elif total == 17:
			move = Move.DOUBLE if up >= 3 and up <= 6 else Move.HIT
		elif total == 18:
			if up >= 3 and up <= 6:
				move = Move.DOUBLE
			elif up == 2 or up == 7 or up == 8:
				move = Move.STAND
			else:
				move = Move.HIT
		else:
			move = Move.STAND
	else:
		if total <= 8:
			move = Move.HIT
		elif total == 9:
			move = Move.DOUBLE if up >= 3 and up <= 6 else Move.HIT
		elif total == 10:
			move = Move.DOUBLE if up <= 9 else Move.HIT
		elif total == 11:
			move = Move.DOUBLE if up <= 10 else Move.HIT
		elif total == 12:
			move = Move.STAND if up >= 4 and up <= 6 else Move.HIT
		elif total <= 16:
			move = Move.STAND if up <= 6 else Move.HIT
		else:
			move = Move.STAND
	if move == Move.DOUBLE and not can_double:
		move = Move.STAND if (is_soft(hand) and total == 18) else Move.HIT
	return move


## Coup d'un bot : stratégie de base, avec des erreurs aux niveaux faibles.
static func bot_move(
	hand: Array[int], up_card: int, can_double: bool, error_rate: float, rng: RandomNumberGenerator
) -> Move:
	var move: Move = recommend(hand, up_card, can_double)
	if error_rate > 0.0 and rng.randf() < error_rate:
		var total: int = BlackjackEngine.bj_value(hand)
		if move == Move.HIT and total >= 12:
			return Move.STAND
		if move == Move.STAND and total <= 16:
			return Move.HIT
		if move == Move.DOUBLE:
			return Move.HIT
	return move


static func move_name(move: Move) -> String:
	match move:
		Move.HIT:
			return "Tirer une carte"
		Move.DOUBLE:
			return "Doubler"
	return "Rester"


static func _up_name(up: int) -> String:
	return "As" if up == 11 else str(up)


## Phrase de conseil, en français, avec la raison.
static func explain(hand: Array[int], up_card: int, can_double: bool) -> String:
	var move: Move = recommend(hand, up_card, can_double)
	var total: int = BlackjackEngine.bj_value(hand)
	var up: int = up_value(up_card)
	var soft: bool = is_soft(hand)
	var up_text: String = _up_name(up)
	match move:
		Move.DOUBLE:
			return (
				"Doublez : %d contre un %s du croupier, c'est le bon moment pour doubler votre mise "
				+ "(vous ne recevez alors qu'une seule carte)."
			) % [total, up_text]
		Move.STAND:
			if total >= 17:
				return "Restez : avec %d, tirer une carte risque de vous faire dépasser 21." % total
			if up <= 6:
				return (
					"Restez : le croupier montre un %s, il risque de dépasser 21. "
					+ "Inutile de prendre un risque."
				) % up_text
			return "Restez : %d est une bonne main contre un %s." % [total, up_text]
		_:
			if soft:
				return (
					"Tirez : votre As peut valoir 1, vous ne pouvez pas dépasser 21 "
					+ "avec une seule carte de plus."
				)
			if total <= 11:
				return "Tirez : avec %d, aucun risque de dépasser 21." % total
			return (
				"Tirez : le croupier montre un %s (carte forte). "
				+ "Avec %d, rester vous ferait perdre le plus souvent."
			) % [up_text, total]
