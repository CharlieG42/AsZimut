class_name BankrollState
extends Node
## Banque commune au Blackjack et au Poker (jetons).
## Chargée comme autoload sous le nom « Bankroll » et sauvegardée sur l'appareil.

signal changed

const START_VALUE: int = 1000
const SAVE_PATH: String = "user://aszimut.cfg"

var value: int = START_VALUE
## Désactivé dans les tests pour ne pas écrire sur le disque.
var persist: bool = true


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


func reset() -> void:
	set_to(START_VALUE)


func _commit() -> void:
	_save()
	changed.emit()


func _load() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		value = maxi(0, int(cfg.get_value("bank", "value", START_VALUE)))
		changed.emit()


func _save() -> void:
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("bank", "value", value)
	cfg.save(SAVE_PATH)
