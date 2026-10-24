class_name RouletteEngine
extends RefCounted
## Roulette européenne (une seule case 0, 37 cases) contre la banque.
## Mises : plein (35 contre 1), douzaine / colonne (2 contre 1), chances simples (1 contre 1).
## Clés de mise : "n:17", "red", "black", "even", "odd", "low" (1-18), "high" (19-36),
## "dozen:1..3", "col:1..3".

signal changed
signal round_finished(net: int)

enum Phase { BET, DONE }

const MIN_BET: int = 5
const REDS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const HISTORY_MAX: int = 12

var phase: Phase = Phase.BET
## Mises posées : clé -> montant.
var bets: Dictionary = {}
var result: int = -1
var net: int = 0
var payout: int = 0
var message: String = ""
var history: Array[int] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bankroll: BankrollState


func _init(bankroll: BankrollState) -> void:
	_bankroll = bankroll
	rng.randomize()


# --- Règles (statiques, testables) -----------------------------------------------


static func is_red(n: int) -> bool:
	return REDS.has(n)


static func color_of(n: int) -> String:
	if n == 0:
		return "green"
	return "red" if is_red(n) else "black"


## Gain en multiple de la mise si la clé `key` gagne avec le numéro `n` (0 = perdu).
static func odds(key: String, n: int) -> int:
	if key.begins_with("n:"):
		return 35 if int(key.substr(2)) == n else 0
	if n == 0:
		return 0
	match key:
		"red":
			return 1 if is_red(n) else 0
		"black":
			return 1 if not is_red(n) else 0
		"even":
			return 1 if n % 2 == 0 else 0
		"odd":
			return 1 if n % 2 == 1 else 0
		"low":
			return 1 if n <= 18 else 0
		"high":
			return 1 if n >= 19 else 0
	if key.begins_with("dozen:"):
		return 2 if (n - 1) / 12 + 1 == int(key.substr(6)) else 0
	if key.begins_with("col:"):
		return 2 if (n - 1) % 3 + 1 == int(key.substr(4)) else 0
	return 0


static func bet_label(key: String) -> String:
	if key.begins_with("n:"):
		return "Plein %s" % key.substr(2)
	if key.begins_with("dozen:"):
		return ["1re douzaine", "2e douzaine", "3e douzaine"][int(key.substr(6)) - 1]
	if key.begins_with("col:"):
		return "Colonne %s" % key.substr(4)
	match key:
		"red":
			return "Rouge"
		"black":
			return "Noir"
		"even":
			return "Pair"
		"odd":
			return "Impair"
		"low":
			return "Manque (1-18)"
		"high":
			return "Passe (19-36)"
	return key


# --- Mises ----------------------------------------------------------------------


func total_bet() -> int:
	var total: int = 0
	for key: Variant in bets.keys():
		total += int(bets[key])
	return total


func bet_on(key: String) -> int:
	return int(bets.get(key, 0))


func can_add(v: int) -> bool:
	return phase == Phase.BET and total_bet() + v <= _bankroll.value


func add_bet(key: String, v: int) -> void:
	if can_add(v):
		bets[key] = bet_on(key) + v
		changed.emit()


func clear_bets() -> void:
	if phase == Phase.BET and not bets.is_empty():
		bets = {}
		changed.emit()


func can_spin() -> bool:
	return phase == Phase.BET and total_bet() >= MIN_BET and total_bet() <= _bankroll.value


## Lance la bille. `forced` (0-36) impose le numéro (tests).
func spin(forced: int = -1) -> void:
	if not can_spin():
		return
	var staked: int = total_bet()
	_bankroll.add(-staked)
	_bankroll.set_pending(staked)
	result = forced if forced >= 0 else rng.randi_range(0, 36)
	payout = 0
	for key: Variant in bets.keys():
		var o: int = odds(str(key), result)
		if o > 0:
			payout += int(bets[key]) * (o + 1)
	net = payout - staked
	history.append(result)
	while history.size() > HISTORY_MAX:
		history.remove_at(0)
	var name: String = {"red": "rouge", "black": "noir", "green": "vert"}[color_of(result)]
	message = "Le %d (%s) sort. " % [result, name]
	if net > 0:
		message += "Vous gagnez %d." % net
	elif net < 0:
		message += "Vous perdez %d." % -net
	else:
		message += "Mises récupérées."
	_bankroll.pending = 0
	if payout > 0:
		_bankroll.add(payout)
	else:
		_bankroll.set_pending(0)
	phase = Phase.DONE
	changed.emit()
	round_finished.emit(net)


## Nouvelle manche : les mises sont conservées si la banque le permet.
func replay() -> void:
	result = -1
	net = 0
	payout = 0
	message = ""
	if total_bet() > _bankroll.value:
		bets = {}
	phase = Phase.BET
	changed.emit()
