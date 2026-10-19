class_name HelpContent
extends RefCounted
## Textes d'aide (règles, conseils) partagés par le tutoriel et le bouton « ? ».

enum Topic { BLACKJACK, POKER, DUTCH, THREE_CARD }

## Exemples de mains pour le classement : [nom, description, cartes [rang, couleur]].
const HANDS: Array[Array] = [
	["Quinte flush royale", "10 à As, même couleur", [[14, 0], [13, 0], [12, 0], [11, 0], [10, 0]]],
	["Quinte flush", "5 cartes qui se suivent, même couleur", [[9, 1], [8, 1], [7, 1], [6, 1], [5, 1]]],
	["Carré", "4 cartes identiques", [[8, 0], [8, 1], [8, 2], [8, 3], [13, 1]]],
	["Full", "Un brelan et une paire", [[10, 0], [10, 1], [10, 2], [4, 3], [4, 0]]],
	["Couleur", "5 cartes de la même couleur", [[14, 2], [11, 2], [8, 2], [6, 2], [3, 2]]],
	["Quinte", "5 cartes qui se suivent", [[9, 0], [8, 1], [7, 2], [6, 3], [5, 0]]],
	["Brelan", "3 cartes identiques", [[7, 0], [7, 1], [7, 2], [13, 3], [2, 0]]],
	["Double paire", "Deux paires", [[11, 0], [11, 1], [4, 2], [4, 3], [14, 0]]],
	["Paire", "2 cartes identiques", [[12, 0], [12, 1], [9, 2], [6, 3], [3, 0]]],
	["Hauteur", "Aucune combinaison : la plus haute carte compte", [[14, 0], [13, 1], [9, 2], [6, 3], [3, 0]]],
]


static func title(topic: int) -> String:
	if topic == Topic.DUTCH:
		return "Dutch"
	if topic == Topic.THREE_CARD:
		return "Three Card Poker"
	return "Blackjack" if topic == Topic.BLACKJACK else "Poker Hold'em"


static func sections(topic: int) -> Array[Dictionary]:
	if topic == Topic.BLACKJACK:
		return blackjack_sections()
	if topic == Topic.DUTCH:
		return dutch_sections()
	if topic == Topic.THREE_CARD:
		return three_card_sections()
	return poker_sections()


static func blackjack_sections() -> Array[Dictionary]:
	return [
		{
			"title": "But du jeu",
			"text":
			"Battre le croupier : approchez-vous de 21 sans le dépasser. Les figures valent 10, l'As vaut 1 ou 11, les autres cartes valent leur numéro.",
		},
		{
			"title": "Une manche",
			"text":
			"1. Misez avec les jetons puis validez.\n2. Vous recevez 2 cartes, le croupier en montre une.\n3. À vous : « Carte » pour tirer, « Rester » pour garder votre main, « Doubler » pour doubler la mise et recevoir une seule carte.\n   Avec une paire, « Séparer » en fait deux mains (même mise sur chacune ; As séparés : une carte chacun).\n   Si le croupier montre un As, il propose une assurance (moitié de la mise, payée 2 contre 1 s'il a blackjack).\n4. Le croupier tire jusqu'à 17, puis on compare.",
		},
		{
			"title": "Gains",
			"text":
			"Vous battez le croupier : vous gagnez votre mise.\nBlackjack (As + figure) : payé 3 pour 2.\nÉgalité : votre mise vous est rendue.\nVous dépassez 21 : mise perdue.",
		},
		{
			"title": "Astuces",
			"text":
			"Avec 11 ou moins, vous ne pouvez pas dépasser : tirez sans crainte.\nContre un 2 à 6 du croupier, il dépasse souvent : restez dès 12 ou 13.\nContre un 7 ou plus, il faut aller chercher plus de points.\nDoublez surtout avec 10 ou 11.",
		},
	]


static func poker_sections() -> Array[Dictionary]:
	return [
		{
			"title": "But du jeu",
			"text":
			"Gagner le pot : avec la meilleure main de 5 cartes, composée de vos 2 cartes privées et des 5 cartes communes, ou en faisant coucher tous les autres.",
		},
		{
			"title": "Une main",
			"text":
			"1. Les blinds : deux joueurs posent une mise forcée (10 et 20).\n2. Vous recevez 2 cartes privées, puis un tour d'enchères.\n3. Le flop : 3 cartes communes. Enchères.\n4. Le turn : une 4e carte. Enchères.\n5. La river : la 5e carte. Dernières enchères.\n6. L'abattage : les mains restantes se comparent.",
		},
		{
			"title": "Vos actions",
			"text":
			"Coucher : abandonner la main.\nChecker : passer sans payer (si personne n'a misé).\nSuivre : payer la mise pour rester.\nMiser / Relancer : augmenter la mise avec le curseur.\nTapis : miser tous ses jetons.",
		},
		{
			"title": "Conseils de débutant",
			"text":
			"Jouez peu de mains au début : paires, As, grosses cartes assorties.\nCouchez les mains faibles quand la mise est grosse.\nRegardez le board : une paire sur la table peut aussi servir à vos adversaires.",
		},
	]


static func dutch_sections() -> Array[Dictionary]:
	return [
		{
			"title": "But du jeu",
			"text":
			"Avoir le moins de points possible. Chaque joueur a 4 cartes face cachées et ne connaît que 2 d'entre elles au départ (pastille dorée = carte que vous connaissez). La partie s'arrête quand un joueur atteint le score cible : le plus bas gagne.",
		},
		{
			"title": "Valeur des cartes",
			"text":
			"As = 1 · 2 à 10 = leur numéro · Valet = 11 · Dame = 12\nRoi noir = 13 · Roi rouge = 0 (la meilleure carte).",
		},
		{
			"title": "Votre tour",
			"text":
			"1. Piochez, ou prenez la carte visible de la défausse.\n2. Échangez-la avec l'une de vos 4 cartes (l'ancienne part à la défausse)…\n3. …ou, si vous avez pioché, défaussez-la.\nOu bien annoncez DUTCH au lieu de jouer (à partir de votre 2e tour).",
		},
		{
			"title": "Pouvoirs (carte piochée puis défaussée)",
			"text":
			"7 ou 8 : regardez une de vos cartes.\n9 ou 10 : regardez une carte d'un adversaire.\nValet ou Dame : échangez, sans regarder, une de vos cartes avec une carte adverse.\nRoi noir : regardez une carte, puis échangez-la ou non.\nUne carte prise dans la défausse n'a pas de pouvoir.",
		},
		{
			"title": "Annoncer DUTCH",
			"text":
			"Quand vous pensez avoir la main la plus faible, annoncez DUTCH : chacun joue un dernier tour, puis toutes les cartes sont révélées. Si vous avez strictement le plus petit total, vous marquez 0 ; sinon vous marquez votre total + 10. Les autres marquent leur total (0 pour le meilleur).",
		},
		{
			"title": "Astuces",
			"text":
			"Retenez bien vos cartes connues. Remplacez d'abord vos plus hautes cartes, et testez les inconnues avec une carte basse. Ne criez DUTCH que si vous êtes presque sûr de votre coup : ZIA le fait seulement quand sa main est très basse.",
		},
	]


static func three_card_sections() -> Array[Dictionary]:
	return [
		{
			"title": "But du jeu",
			"text":
			"Battre le croupier avec une main de 3 cartes. Contrairement au poker classique, il n'y a ni adversaires ni enchères : vous jouez seul contre la banque.",
		},
		{
			"title": "Une manche",
			"text":
			"1. Misez l'Ante (obligatoire) et, si vous le voulez, un Pair Plus (facultatif).\n2. Vous recevez 3 cartes, le croupier aussi (cachées).\n3. Vous décidez : « Jouer » (vous posez une seconde mise égale à l'Ante) ou « Se coucher » (vous perdez l'Ante).\n4. Le croupier dévoile sa main. Il se qualifie avec Dame haute ou mieux.",
		},
		{
			"title": "Classement des mains",
			"text":
			"Du plus fort au plus faible :\nQuinte flush (3 cartes qui se suivent, même couleur)\nBrelan (3 cartes identiques)\nQuinte (3 cartes qui se suivent ; A-2-3 est la plus petite)\nCouleur (3 cartes de la même couleur)\nPaire\nHauteur (la plus haute carte)\nAttention : ici, la quinte bat la couleur.",
		},
		{
			"title": "Gains",
			"text":
			"Le croupier ne se qualifie pas : l'Ante est payée 1 pour 1, le Jeu vous est rendu.\nLe croupier se qualifie et vous le battez : Ante et Jeu sont payés 1 pour 1.\nÉgalité : tout est rendu. Le croupier gagne : Ante et Jeu sont perdus.\nBonus d'Ante (si vous jouez, même si vous perdez) : quinte 1 pour 1, brelan 4 pour 1, quinte flush 5 pour 1.\nPair Plus (indépendant du croupier) : paire 1 pour 1, couleur 4, quinte 6, brelan 30, quinte flush 40.",
		},
		{
			"title": "Astuces",
			"text":
			"Jouez avec Dame-6-4 ou mieux, couchez-vous en dessous : c'est la stratégie qui perd le moins.\nLe Pair Plus paie gros mais rarement : misez-y peu.\nIl faut pouvoir couvrir le Jeu : l'Ante ne peut pas dépasser la moitié de votre banque (moins le Pair Plus).",
		},
	]


static func app_sections() -> Array[Dictionary]:
	return [
		{
			"title": "Multijoueur local",
			"text":
			"Jouez à 2 à 6 sur un seul appareil, hors ligne (Dutch : 2 à 5). Au poker et au Dutch, un écran « Passez l'appareil » cache les cartes entre deux tours. Chaque siège peut aussi être confié à l'IA (ZIA).",
		},
		{
			"title": "Reprendre une partie",
			"text":
			"Les parties locales, le Dutch et la table de poker solo sont sauvegardés à chaque main. Si l'appli se ferme, l'accueil propose « Reprendre ».",
		},
		{
			"title": "Aide et conseils",
			"text":
			"Le bouton « ? » en haut de chaque partie rappelle les règles. Le mode débutant affiche un conseil à chaque décision : action recommandée et raison.",
		},
	]


## Pages du tutoriel : {title, sections, hands (bool), beginner (bool)}.
static func tutorial_pages() -> Array[Dictionary]:
	var welcome: Array[Dictionary] = [
		{
			"title": "Quatre jeux",
			"text":
			"Blackjack et Three Card Poker contre le croupier, Poker Hold'em contre ZIA, notre IA, et Dutch, un jeu de mémoire sans mise. Votre banque de jetons est commune aux jeux d'argent ; elle se sauvegarde sur l'appareil.",
		},
		{
			"title": "Ce tutoriel",
			"text":
			"Quelques pages pour découvrir les règles. Vous pourrez le relancer à tout moment depuis Options.",
		},
	]
	var pages: Array[Dictionary] = []
	pages.append({"title": "Bienvenue sur AsZimut", "sections": welcome, "hands": false, "beginner": false})
	pages.append({"title": "Blackjack", "sections": blackjack_sections(), "hands": false, "beginner": false})
	pages.append({"title": "Poker", "sections": poker_sections(), "hands": false, "beginner": false})
	pages.append({"title": "Three Card Poker", "sections": three_card_sections(), "hands": false, "beginner": false})
	pages.append({"title": "Dutch", "sections": dutch_sections(), "hands": false, "beginner": false})
	pages.append({"title": "Classement des mains", "sections": [], "hands": true, "beginner": false})
	pages.append({"title": "Jouer à plusieurs, se faire aider", "sections": app_sections(), "hands": false, "beginner": true})
	return pages
