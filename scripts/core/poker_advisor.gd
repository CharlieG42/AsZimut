class_name PokerAdvisor
extends RefCounted
## Conseil de poker pour les débutants : force de la main et action recommandée.

enum Move { FOLD, CHECK, CALL, RAISE }


## Chances de gagner contre un adversaire pris au hasard (pré-flop : formule de Chen).
static func heads_up_equity(
	hole: Array[int], board: Array[int], iters: int, rng: RandomNumberGenerator
) -> float:
	if board.is_empty():
		return 0.33 + (PokerAI.chen(hole[0], hole[1]) / 20.0) * 0.42
	return PokerAI.win_prob(hole, board, iters, rng)


## Estimation contre `opponents` adversaires (approximation : p^n).
static func equity(
	hole: Array[int], board: Array[int], opponents: int, iters: int, rng: RandomNumberGenerator
) -> float:
	return pow(heads_up_equity(hole, board, iters, rng), maxi(opponents, 1))


static func strength_label(equity_value: float, opponents: int) -> String:
	var fair: float = 1.0 / float(maxi(opponents, 1) + 1)
	var ratio: float = equity_value / fair
	if ratio >= 1.75:
		return "très forte"
	if ratio >= 1.25:
		return "forte"
	if ratio >= 0.9:
		return "moyenne"
	return "faible"


## Retourne {move, equity, strength, text}.
static func advise(
	hole: Array[int],
	board: Array[int],
	pot: int,
	to_call: int,
	opponents: int,
	can_raise: bool,
	rng: RandomNumberGenerator = null,
	iters: int = 160
) -> Dictionary:
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var opp: int = maxi(opponents, 1)
	var eq: float = equity(hole, board, opp, iters, r)
	var fair: float = 1.0 / float(opp + 1)
	var ratio: float = eq / fair
	var label: String = strength_label(eq, opp)
	var head: String = "Main %s (≈ %d %% de chances de gagner). " % [label, roundi(eq * 100.0)]
	var move: Move
	var text: String
	if to_call <= 0:
		if can_raise and ratio >= 1.25:
			move = Move.RAISE
			text = head + "Misez : vous avez l'avantage, faites payer vos adversaires."
		else:
			move = Move.CHECK
			text = head + "Checkez : rien ne vous oblige à payer, voyez la carte suivante gratuitement."
	else:
		var odds: float = float(to_call) / float(pot + to_call)
		if can_raise and ratio >= 1.75:
			move = Move.RAISE
			text = head + "Relancez : votre main est très au-dessus de la moyenne."
		elif eq >= odds + 0.03:
			move = Move.CALL
			text = head + "Suivez : payer %d %% du pot final vaut le coup avec cette main." % roundi(odds * 100.0)
		else:
			move = Move.FOLD
			text = head + "Couchez-vous : suivre coûte trop cher pour vos chances (%d %% du pot final)." % roundi(odds * 100.0)
	return {"move": move, "equity": eq, "strength": label, "text": text}
