class_name StatsState
extends Node
## Statistiques de jeu et réglages, sauvegardés sur l'appareil.
## Chargé comme autoload sous le nom « Stats ».

signal changed
## Émis quand un succès est débloqué (titre et description).
signal achievement_unlocked(title: String, description: String)

const SAVE_PATH: String = "user://aszimut_stats.cfg"

## Désactivé dans les tests pour ne pas écrire sur le disque.
var persist: bool = true

# Réglages
var difficulty: int = 1  # niveau de ZIA : 0 facile, 1 normal, 2 difficile
var haptics: bool = true
var sound: bool = true
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

# Dutch (parties solo contre ZIA)
var du_games: int = 0
var du_wins: int = 0
var du_rounds: int = 0
var du_round_wins: int = 0
var du_calls: int = 0
var du_call_wins: int = 0
var du_best_hand: int = 99

## Succès débloqués (identifiants) et événements ponctuels comptés.
var achievements: Array[String] = []
var bj_split_wins: int = 0
var pk_table_wins: int = 0

var _toasts: int = 0

## Historique de la banque (une valeur par manche jouée), pour la courbe des Options.
var bank_history: Array[int] = []
const HISTORY_MAX: int = 80

## Succès : [identifiant, titre, description].
const ACHIEVEMENTS: Array[Array] = [
	["bj_first", "Premier blackjack", "Obtenir un blackjack (As + figure)."],
	["bj_ten", "Collectionneur", "Obtenir 10 blackjacks."],
	["bj_fifty", "Habitué du casino", "Gagner 50 manches de blackjack."],
	["bj_split", "Double tranchant", "Gagner une manche après avoir séparé une paire."],
	["pk_first", "Premier pot", "Remporter une main de poker."],
	["pk_big", "Gros pot", "Remporter un pot d'au moins 1000 jetons."],
	["pk_hundred", "Cent mains", "Jouer 100 mains de poker en face-à-face."],
	["pk_table", "Dernier debout", "Gagner une table de poker solo à plusieurs."],
	["du_first", "Premier Dutch", "Gagner une partie de Dutch contre ZIA."],
	["du_call", "Annonce gagnante", "Annoncer DUTCH et avoir la main la plus faible."],
	["du_low", "Main parfaite", "Finir une manche de Dutch avec 3 points ou moins."],
	["bank_5000", "Flambeur", "Atteindre une banque de 5000 jetons."],
]

const _STAT_KEYS: Array[String] = [
	"bj_rounds", "bj_wins", "bj_losses", "bj_pushes", "bj_blackjacks", "bj_net",
	"pk_hands", "pk_wins", "pk_losses", "pk_splits", "pk_net", "pk_biggest_pot",
	"du_games", "du_wins", "du_rounds", "du_round_wins", "du_calls", "du_call_wins",
	"bj_split_wins", "pk_table_wins",
]


func _ready() -> void:
	_load()
	# Succès déjà mérités avant cette version : débloqués sans notification.
	for a: Array in ACHIEVEMENTS:
		if not achievements.has(str(a[0])) and _achieved(str(a[0])):
			achievements.append(str(a[0]))
	achievement_unlocked.connect(_show_toast)


## Petit bandeau « Succès débloqué » en haut de l'écran, quel que soit l'écran affiché.
func _show_toast(title: String, description: String) -> void:
	if not is_inside_tree():
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var holder: MarginContainer = MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		holder.add_theme_constant_override(side, 14)
	# Plusieurs succès d'un coup : les bandeaux s'empilent.
	holder.add_theme_constant_override("margin_top", 14 + 104 * _toasts)
	_toasts += 1
	layer.tree_exited.connect(func() -> void: _toasts = maxi(0, _toasts - 1))
	layer.add_child(holder)
	var panel: PanelContainer = UIKit.panel(Color(0.08, 0.12, 0.2, 0.97), 14, 12, UIKit.GOLD)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	col.add_child(UIKit.label("SUCCÈS DÉBLOQUÉ", 11, UIKit.GOLD, true))
	col.add_child(UIKit.label(title, 18, Color.WHITE, true))
	var d: Label = UIKit.label(description, 13, UIKit.TEXT_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	SfxPlayer.play("win", -4.0)
	holder.modulate.a = 0.0
	var t: Tween = holder.create_tween()
	t.tween_property(holder, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.6)
	t.tween_property(holder, "modulate:a", 0.0, 0.3)
	t.tween_callback(layer.queue_free)


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


## Fin d'une manche de Dutch solo : points de la main du joueur, manche gagnée, annonce.
func record_dutch_round(hand_points: int, won: bool, called: bool) -> void:
	du_rounds += 1
	if won:
		du_round_wins += 1
	if called:
		du_calls += 1
		if won:
			du_call_wins += 1
	du_best_hand = mini(du_best_hand, hand_points)
	_commit()


func record_dutch_match(won: bool) -> void:
	du_games += 1
	if won:
		du_wins += 1
	_commit()


func record_split_win() -> void:
	bj_split_wins += 1
	_commit()


func record_table_win() -> void:
	pk_table_wins += 1
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


func set_sound(enabled: bool) -> void:
	sound = enabled
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
	du_best_hand = 99
	bank_history = []
	_commit()


## Pourcentage de victoires (0 si aucune partie).
static func percent(wins: int, total: int) -> int:
	if total <= 0:
		return 0
	return roundi(100.0 * wins / total)


## Ajoute la valeur actuelle de la banque à l'historique (appelé après chaque manche solo).
func note_bank(value: int) -> void:
	bank_history.append(value)
	while bank_history.size() > HISTORY_MAX:
		bank_history.remove_at(0)
	_commit()


func has_achievement(id: String) -> bool:
	return achievements.has(id)


func _achieved(id: String) -> bool:
	match id:
		"bj_first":
			return bj_blackjacks >= 1
		"bj_ten":
			return bj_blackjacks >= 10
		"bj_fifty":
			return bj_wins >= 50
		"bj_split":
			return bj_split_wins >= 1
		"pk_first":
			return pk_wins >= 1
		"pk_big":
			return pk_biggest_pot >= 1000
		"pk_hundred":
			return pk_hands >= 100
		"pk_table":
			return pk_table_wins >= 1
		"du_first":
			return du_wins >= 1
		"du_call":
			return du_call_wins >= 1
		"du_low":
			return du_best_hand <= 3
		"bank_5000":
			var bank: Node = get_node_or_null("/root/Bankroll")
			return bank != null and int(bank.get("best")) >= 5000
	return false


## Débloque les succès atteints ; renvoie les nouveaux.
func check_achievements() -> Array[String]:
	var fresh: Array[String] = []
	for a: Array in ACHIEVEMENTS:
		var id: String = str(a[0])
		if not achievements.has(id) and _achieved(id):
			achievements.append(id)
			fresh.append(id)
			achievement_unlocked.emit(str(a[1]), str(a[2]))
	return fresh


func _commit() -> void:
	check_achievements()
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
	sound = bool(cfg.get_value("settings", "sound", true))
	beginner = bool(cfg.get_value("settings", "beginner", false))
	show_tutorial = bool(cfg.get_value("settings", "show_tutorial", true))
	for key: String in _STAT_KEYS:
		set(key, int(cfg.get_value("stats", key, 0)))
	du_best_hand = int(cfg.get_value("stats", "du_best_hand", 99))
	achievements = []
	for id: Variant in cfg.get_value("stats", "achievements", []):
		achievements.append(str(id))
	bank_history = []
	for v: Variant in cfg.get_value("stats", "bank_history", []):
		bank_history.append(int(v))
	changed.emit()


func _save() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "haptics", haptics)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "beginner", beginner)
	cfg.set_value("settings", "show_tutorial", show_tutorial)
	for key: String in _STAT_KEYS:
		cfg.set_value("stats", key, get(key))
	cfg.set_value("stats", "du_best_hand", du_best_hand)
	cfg.set_value("stats", "achievements", Array(achievements))
	cfg.set_value("stats", "bank_history", Array(bank_history))
	cfg.save(SAVE_PATH)
