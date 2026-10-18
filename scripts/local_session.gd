class_name LocalSession
extends RefCounted
## Paramètres de la partie multijoueur locale en cours (partagés entre les écrans).

enum Game { BLACKJACK, POKER, DUTCH }

const HOME_SCENE: String = "res://scenes/home.tscn"
const SETUP_SCENE: String = "res://scenes/setup.tscn"
const RESULTS_SCENE: String = "res://scenes/results.tscn"
const CHIP_CHOICES: Array[int] = [500, 1000, 2000]
const DUTCH_TARGETS: Array[int] = [30, 50, 100]

static var game: int = Game.POKER
## Dutch : score qui met fin à la partie, et mode « 1 joueur contre ZIA » lancé depuis l'accueil.
static var dutch_target: int = 50
static var solo: bool = false
## Poker solo à la table : un humain (banque personnelle) contre plusieurs ZIA.
static var solo_poker: bool = false
static var solo_buy_in: int = 0
## Banque hors table pendant le poker solo (banque = hors table + pile du joueur).
static var solo_outside: int = 0
## Instantané à restaurer au lancement de l'écran de jeu (reprise de partie), vide sinon.
static var resume_data: Dictionary = {}
static var count: int = 2
static var chips: int = 1000
static var names: Array[String] = ["", "", "", "", "", ""]
## Siège contrôlé par l'IA (ZIA) plutôt que par un humain.
static var bots: Array[bool] = [false, false, false, false, false, false]
## Profil enregistré associé à chaque siège ("" = invité ou ZIA).
static var profile_ids: Array[String] = ["", "", "", "", "", ""]
## Chaque joueur enregistré joue avec sa banque personnelle (blackjack et poker locaux).
static var use_banks: bool = false
## Crée un profil pour les nouveaux noms au lancement de la partie.
static var save_new_profiles: bool = true
## Piles de départ par siège pour la partie en cours.
static var start_stacks: Array[int] = []
## Classement de la dernière partie : [{name, stack, start}] du premier au dernier.
static var results: Array[Dictionary] = []


static func min_players(_g: int) -> int:
	return 2


static func max_players(g: int) -> int:
	if g == Game.BLACKJACK:
		return MultiBlackjackEngine.MAX_PLAYERS
	if g == Game.DUTCH:
		return DutchEngine.MAX_PLAYERS
	return PokerTableEngine.MAX_PLAYERS


static func title(g: int) -> String:
	if g == Game.DUTCH:
		return "Dutch"
	return "Blackjack" if g == Game.BLACKJACK else "Poker Hold'em"


static func scene(g: int) -> String:
	if g == Game.BLACKJACK:
		return "res://scenes/multi_blackjack.tscn"
	if g == Game.DUTCH:
		return "res://scenes/dutch.tscn"
	return "res://scenes/multi_poker.tscn"


static func set_game(g: int) -> void:
	game = g
	count = clampi(count, min_players(g), max_players(g))


static func set_count(n: int) -> void:
	count = clampi(n, min_players(game), max_players(game))


## Noms nettoyés : « Joueur N » (ou « ZIA ») par défaut, doublons départagés.
static func player_names() -> Array[String]:
	var out: Array[String] = []
	var bot_index: int = 0
	for i: int in count:
		var n: String = names[i].strip_edges()
		if not bots[i] and ProfileStore.exists(profile_ids[i]):
			n = ProfileStore.name_of(profile_ids[i])
		if n == "":
			if bots[i]:
				bot_index += 1
				n = "ZIA" if bot_index == 1 else "ZIA %d" % bot_index
			else:
				n = "Joueur %d" % (i + 1)
		var candidate: String = n
		var k: int = 2
		while out.has(candidate):
			candidate = "%s (%d)" % [n, k]
			k += 1
		out.append(candidate)
	return out


static func bot_flags() -> Array[bool]:
	var out: Array[bool] = []
	for i: int in count:
		out.append(bots[i])
	return out


static func human_count() -> int:
	var n: int = 0
	for i: int in count:
		if not bots[i]:
			n += 1
	return n


## Avant de lancer une partie locale : crée/relie les profils, mémorise le groupe,
## calcule les piles de départ (banques personnelles si demandé).
static func prepare_start() -> void:
	var linked: Array[String] = []
	for i: int in count:
		if bots[i]:
			profile_ids[i] = ""
			continue
		if not ProfileStore.exists(profile_ids[i]):
			profile_ids[i] = ""
			var typed: String = names[i].strip_edges()
			if typed != "":
				var found: String = ProfileStore.find_by_name(typed)
				if found == "" and save_new_profiles:
					found = ProfileStore.create(typed)
				profile_ids[i] = found
		if profile_ids[i] != "":
			names[i] = ProfileStore.name_of(profile_ids[i])
			linked.append(profile_ids[i])
	ProfileStore.note_group(linked)
	compute_start_stacks()


static func compute_start_stacks() -> void:
	start_stacks = []
	for i: int in count:
		var stack: int = chips
		if uses_personal_banks() and not bots[i] and ProfileStore.exists(profile_ids[i]):
			stack = ProfileStore.playable_bank(profile_ids[i])
		start_stacks.append(stack)


static func start_of(index: int) -> int:
	return start_stacks[index] if index >= 0 and index < start_stacks.size() else chips


## Pile de départ d'un joueur par son nom affiché (pour les classements).
static func start_for_name(player_name: String) -> int:
	return start_of(player_names().find(player_name))


static func uses_personal_banks() -> bool:
	return use_banks and game != Game.DUTCH and not solo and not solo_poker


static func store_results(rows: Array[Dictionary]) -> void:
	results = rows
	if solo or solo_poker:
		return
	var shown: Array[String] = player_names()
	var entries: Array[Dictionary] = []
	for rank: int in rows.size():
		var row: Dictionary = rows[rank]
		var seat: int = shown.find(str(row.get("name", "")))
		if seat < 0 or bots[seat] or not ProfileStore.exists(profile_ids[seat]):
			continue
		var e: Dictionary = {"id": profile_ids[seat], "rank": rank}
		if game == Game.DUTCH:
			e["points"] = int(row.get("stack", 0))
		else:
			e["start"] = int(row.get("start", chips))
			e["final"] = int(row.get("stack", 0))
		entries.append(e)
	var key: String = ["bj", "pk", "du"][game]
	ProfileStore.record_game(key, entries, uses_personal_banks())


## Dutch en solo : un humain contre ZIA.
static func start_solo_dutch() -> void:
	game = Game.DUTCH
	count = 2
	solo = true
	profile_ids = ["", "", "", "", "", ""]
	solo_poker = false
	resume_data = {}


## Poker solo à la table : `players` sièges dont un seul humain (siège 0), cave prise sur la banque.
static func start_solo_poker(players: int, buy_in: int) -> void:
	game = Game.POKER
	count = clampi(players, 2, PokerTableEngine.MAX_PLAYERS)
	solo = false
	solo_poker = true
	profile_ids = ["", "", "", "", "", ""]
	solo_buy_in = buy_in
	chips = buy_in
	names[0] = "Vous"
	bots[0] = false
	for i: int in range(1, bots.size()):
		bots[i] = true
		names[i] = ""
	resume_data = {}
