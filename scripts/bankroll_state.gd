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
## Joueur actif dont la banque est utilisée en solo ("" = invité : banque de l'appareil).
var profile_id: String = ""
var _guest_value: int = START_VALUE
var _guest_best: int = START_VALUE


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


## Banque de l'invité (sauvegardée), même quand un joueur enregistré est actif.
func to_dict() -> Dictionary:
	_sync_guest()
	return {"value": _guest_value, "best": _guest_best}


func load_dict(d: Dictionary) -> void:
	var v: int = maxi(0, int(d.get("value", START_VALUE)))
	_guest_value = v
	_guest_best = maxi(v, int(d.get("best", v)))
	pending = 0
	if profile_id == "":
		value = _guest_value
		best = _guest_best
	_commit()


## Passe sur la banque d'un joueur enregistré (ou "" pour l'invité) ; relit sa banque si inchangé.
func use_profile(id: String) -> void:
	var target: String = id if ProfileStore.exists(id) else ""
	if target == profile_id:
		_pull_profile()
		return
	_sync_guest()
	profile_id = target
	pending = 0
	if target == "":
		value = _guest_value
		best = _guest_best
	else:
		_pull_profile()
	_save()
	changed.emit()


## Relit la banque du profil actif (elle a pu changer pendant une partie locale).
func refresh_profile() -> void:
	if profile_id != "":
		_pull_profile()
		changed.emit()


func _pull_profile() -> void:
	if profile_id == "":
		return
	value = ProfileStore.bank_of(profile_id)
	best = maxi(value, int(ProfileStore.get_profile(profile_id).get("best_bank", value)))


func _sync_guest() -> void:
	if profile_id == "":
		_guest_value = value
		_guest_best = best


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
	if cfg.load(save_path) != OK:
		profile_id = ProfileStore.active_id()
		_pull_profile()
		return
	value = maxi(0, int(cfg.get_value("bank", "value", START_VALUE)))
	best = maxi(value, int(cfg.get_value("bank", "best", START_VALUE)))
	var lost: int = int(cfg.get_value("bank", "pending", 0))
	_guest_value = value
	_guest_best = best
	profile_id = ProfileStore.active_id()
	_pull_profile()
	if lost > 0:
		refunded = lost
		value += lost
		pending = 0
		_save()
	changed.emit()


func _save() -> void:
	_sync_guest()
	if profile_id != "":
		ProfileStore.set_bank(profile_id, value)
	if not persist:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("bank", "value", _guest_value)
	cfg.set_value("bank", "best", _guest_best)
	cfg.set_value("bank", "pending", pending)
	cfg.save(save_path)
