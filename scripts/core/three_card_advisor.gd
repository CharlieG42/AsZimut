class_name ThreeCardAdvisor
extends RefCounted
## Conseil du mode débutant au Three Card Poker : jouer dès Dame-6-4 ou mieux, sinon se coucher.


## Vrai s'il faut jouer cette main (stratégie optimale : Dame-6-4 minimum).
static func should_play(cards: Array[int]) -> bool:
	var e: Array[int] = ThreeCardEngine.evaluate(cards)
	if e[0] >= ThreeCardEngine.Hand.PAIR:
		return true
	for i: int in 3:
		if e[1 + i] != ThreeCardEngine.PLAY_THRESHOLD[i]:
			return e[1 + i] > ThreeCardEngine.PLAY_THRESHOLD[i]
	return true


static func explain(cards: Array[int]) -> String:
	var hand: String = ThreeCardEngine.hand_name(cards)
	if should_play(cards):
		if ThreeCardEngine.evaluate(cards)[0] >= ThreeCardEngine.Hand.PAIR:
			return "Vous avez %s : une combinaison. Jouez." % hand
		return "Vous avez %s, au moins Dame-6-4 : jouez, c'est rentable à long terme." % hand
	return "Vous avez %s, moins que Dame-6-4 : couchez-vous et ne perdez que l'Ante." % hand


static func pair_plus_advice() -> String:
	return "Le Pair Plus est facultatif : il paie selon votre main, que le croupier gagne ou non. Misez peu dessus."
