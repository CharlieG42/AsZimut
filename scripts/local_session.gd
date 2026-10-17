class_name LocalSession
extends RefCounted
## Paramètres de la partie multijoueur locale en cours (partagés entre les écrans).

enum Game { BLACKJACK, POKER }

const HOME_SCENE: String = "res://scenes/home.tscn"
const SETUP_SCENE: String = "res://scenes/setup.tscn"
const RESULTS_SCENE: String = "res://scenes/results.tscn"
const CHIP_CHOICES: Array[int] = [500, 1000, 2000]

static var game: int = Game.POKER
static var count: int = 2
static var chips: int = 1000
static var names: Array[String] = ["", "", "", "", "", ""]
## Classement de la dernière partie : [{name, stack, start}] du premier au dernier.
static var results: Array[Dictionary] = []


static func min_players(_g: int) -> int:
	return 2


static func max_players(g: int) -> int:
	return MultiBlackjackEngine.MAX_PLAYERS if g == Game.BLACKJACK else PokerTableEngine.MAX_PLAYERS


static func title(g: int) -> String:
	return "Blackjack" if g == Game.BLACKJACK else "Poker Hold'em"


static func scene(g: int) -> String:
	if g == Game.BLACKJACK:
		return "res://scenes/multi_blackjack.tscn"
	return "res://scenes/multi_poker.tscn"


static func set_game(g: int) -> void:
	game = g
	count = clampi(count, min_players(g), max_players(g))


static func set_count(n: int) -> void:
	count = clampi(n, min_players(game), max_players(game))


## Noms nettoyés : « Joueur N » par défaut, doublons départagés.
static func player_names() -> Array[String]:
	var out: Array[String] = []
	for i: int in count:
		var n: String = names[i].strip_edges()
		if n == "":
			n = "Joueur %d" % (i + 1)
		var candidate: String = n
		var k: int = 2
		while out.has(candidate):
			candidate = "%s (%d)" % [n, k]
			k += 1
		out.append(candidate)
	return out


static func store_results(rows: Array[Dictionary]) -> void:
	results = rows
