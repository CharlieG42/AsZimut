class_name BankrollState
extends Node
## Banque commune au Blackjack et au Poker (jetons).
## Chargée comme autoload sous le nom « Bankroll » et sauvegardée sur l'appareil.

signal changed

const START_VALUE: int = 1000
var save_path: String = "user://aszimut.cfg"

var value: int = START_VALUE
## Plus haute banque atteinte.
var best: int = START_VALUE
## Désactivé dans les tests pour ne pas écrire sur le disque.
var persist: bool = true
## Mise d'une manche de blackjack en cours : rendue au prochain lancement si l'appli a été fermée.
var pending: int = 0
## Montant rendu au démarrage (pour l'afficher une fois), 0 sinon.
var refunded: int = 0


func _ready() -> void:
	_load()


func add(amount: int) -> void:
	value += amount
	_commit()


func set_to(amount: int) -> void:
	if amount == value:
		return
	value = amount
	_commit()


func set_pending(amount: int) -> void:
	if amount == pending:
		return
	pending = maxi(0, amount)
	_save()


func reset() -> void:
	set_to(START_VALUE)


func _commit() -> void:
	best = maxi(best, value)
	_save()
	changed.emit()


func _load() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(save_path) == OK:
		value = maxi(0, int(cfg.get_value("bank", "value", START_VALUE)))
		best = maxi(value, int(cfg.get_value("bank", "best", START_VALUE)))
		var lost: int = int(cfg.get_value("bank", "pending", 0))
		if lost > 0:
			refunded = lost
			value += lost
			pending = 0
			_save()
		changed.emit()


func _save() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("bank", "value", value)
	cfg.set_value("bank", "best", best)
	cfg.set_value("bank", "pending", pending)
	cfg.save(save_path)
