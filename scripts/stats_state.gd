class_name StatsState
extends Node
## Statistiques de jeu et réglages, sauvegardés sur l'appareil.
## Chargé comme autoload sous le nom « Stats ».

signal changed

const SAVE_PATH: String = "user://aszimut_stats.cfg"

## Désactivé dans les tests pour ne pas écrire sur le disque.
var persist: bool = true

# Réglages
var difficulty: int = 1  # niveau de ZIA : 0 facile, 1 normal, 2 difficile
var haptics: bool = true
## Mode débutant : conseils pendant la partie.
var beginner: bool = false
## Affiche le tutoriel au démarrage de l'application.
var show_tutorial: bool = true

## Vrai une fois le tutoriel de démarrage traité pendant cette session (pas sauvegardé).
static var tutorial_checked: bool = false

# Blackjack
var bj_rounds: int = 0
var bj_wins: int = 0
var bj_losses: int = 0
var bj_pushes: int = 0
var bj_blackjacks: int = 0
var bj_net: int = 0

# Poker
var pk_hands: int = 0
var pk_wins: int = 0
var pk_losses: int = 0
var pk_splits: int = 0
var pk_net: int = 0
var pk_biggest_pot: int = 0

const _STAT_KEYS: Array[String] = [
	"bj_rounds", "bj_wins", "bj_losses", "bj_pushes", "bj_blackjacks", "bj_net",
	"pk_hands", "pk_wins", "pk_losses", "pk_splits", "pk_net", "pk_biggest_pot",
]


func _ready() -> void:
	_load()


func record_blackjack(outcome: int, net: int) -> void:
	bj_rounds += 1
	bj_net += net
	match outcome:
		BlackjackEngine.Outcome.WIN:
			bj_wins += 1
		BlackjackEngine.Outcome.BLACKJACK:
			bj_wins += 1
			bj_blackjacks += 1
		BlackjackEngine.Outcome.LOSE:
			bj_losses += 1
		BlackjackEngine.Outcome.PUSH:
			bj_pushes += 1
	_commit()


func record_poker(outcome: int, net: int, pot_won: int) -> void:
	pk_hands += 1
	pk_net += net
	match outcome:
		PokerEngine.HandOutcome.WIN:
			pk_wins += 1
			pk_biggest_pot = maxi(pk_biggest_pot, pot_won)
		PokerEngine.HandOutcome.LOSE:
			pk_losses += 1
		PokerEngine.HandOutcome.SPLIT:
			pk_splits += 1
	_commit()


func set_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, PokerEngine.PROFILES.size() - 1)
	_commit()


func set_haptics(enabled: bool) -> void:
	haptics = enabled
	_commit()


func set_beginner(enabled: bool) -> void:
	beginner = enabled
	_commit()


func set_show_tutorial(enabled: bool) -> void:
	show_tutorial = enabled
	_commit()


## Efface les statistiques (les réglages sont conservés).
func reset_stats() -> void:
	for key: String in _STAT_KEYS:
		set(key, 0)
	_commit()


## Pourcentage de victoires (0 si aucune partie).
static func percent(wins: int, total: int) -> int:
	if total <= 0:
		return 0
	return roundi(100.0 * wins / total)


func _commit() -> void:
	_save()
	changed.emit()


func _load() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	difficulty = clampi(int(cfg.get_value("settings", "difficulty", 1)), 0, PokerEngine.PROFILES.size() - 1)
	haptics = bool(cfg.get_value("settings", "haptics", true))
	beginner = bool(cfg.get_value("settings", "beginner", false))
	show_tutorial = bool(cfg.get_value("settings", "show_tutorial", true))
	for key: String in _STAT_KEYS:
		set(key, int(cfg.get_value("stats", key, 0)))
	changed.emit()


func _save() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "haptics", haptics)
	cfg.set_value("settings", "beginner", beginner)
	cfg.set_value("settings", "show_tutorial", show_tutorial)
	for key: String in _STAT_KEYS:
		cfg.set_value("stats", key, get(key))
	cfg.save(SAVE_PATH)
