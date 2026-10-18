class_name DutchEngine
extends RefCounted
## Dutch (variante « Cabo ») pour 2 à 5 joueurs, humains ou ZIA.
##
## Chaque joueur a 4 cartes face cachées et ne connaît d'abord que 2 d'entre elles.
## À son tour : piocher (ou prendre la défausse) puis échanger avec l'une de ses cartes,
## ou défausser la carte piochée (ce qui peut déclencher un pouvoir). On peut annoncer
## « Dutch » : tous les autres jouent un dernier tour, puis les cartes sont révélées.
## Le plus petit total gagne la manche. La partie s'arrête quand un joueur atteint `target`.

signal changed

enum Phase { TURN, HELD, POWER, KING_DECIDE, ROUND_OVER, MATCH_OVER }
enum Power { NONE, PEEK_OWN, PEEK_OTHER, SWAP_BLIND, KING }

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 5
const HAND_SIZE: int = 4
const DEFAULT_TARGET: int = 50
const DUTCH_PENALTY: int = 10
const UNKNOWN_VALUE: float = 6.5
## Oubli de ZIA par niveau (probabilité d'oublier chaque carte connue, à chaque tour).
const MEMORY_LOSS: Array[float] = [0.18, 0.06, 0.0]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var difficulty: int = 1
var target: int = DEFAULT_TARGET

var n: int = 0
var names: Array[String] = []
var bots: Array[bool] = []
var hands: Array[Array] = []  # n x 4 cartes
var draw_pile: Array[int] = []
var discard_pile: Array[int] = []
## known[v] : "propriétaire*4+emplacement" -> carte que le joueur v connaît.
var known: Array[Dictionary] = []

var phase: int = Phase.TURN
var current: int = 0
var starter: int = 0
var round_number: int = 0
var held: int = -1
var held_from_discard: bool = false
var power: int = Power.NONE
var king_target: Vector2i = Vector2i(-1, -1)  # (propriétaire, emplacement) regardé par le roi
var dutch_caller: int = -1
var turns_left: int = 0
var turns_taken: Array[int] = []
var totals: Array[int] = []  # scores cumulés
var round_points: Array[int] = []  # points de la manche écoulée
var round_winners: Array[int] = []
var caller_failed: bool = false
var message: String = ""


func setup(player_names: Array[String], bot_flags: Array[bool], level: int = 1, seed_value: int = -1) -> void:
	n = clampi(player_names.size(), MIN_PLAYERS, MAX_PLAYERS)
	names = player_names.slice(0, n)
	bots = bot_flags.slice(0, n)
	difficulty = clampi(level, 0, MEMORY_LOSS.size() - 1)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	totals = []
	for _i: int in n:
		totals.append(0)
	round_number = 0
	starter = n - 1
	start_round()


## Instantané pris en début de manche (pour reprendre la partie à cette manche).
func snapshot() -> Dictionary:
	return {
		"totals": Array(totals), "round_number": round_number, "starter": starter, "target": target,
	}


## Restaure les scores et redistribue la manche sauvegardée.
func restore(snap: Dictionary) -> void:
	var saved: Array = snap.get("totals", [])
	for p: int in mini(n, saved.size()):
		totals[p] = int(saved[p])
	target = int(snap.get("target", target))
	round_number = int(snap.get("round_number", 1)) - 1
	starter = (int(snap.get("starter", 0)) - 1 + n) % n
	start_round()


# --- Valeurs -----------------------------------------------------------------


static func card_points(card: int) -> int:
	var rank: int = Cards.rank_of(card)
	if rank == 14:
		return 1
	if rank == 13:
		return 0 if Cards.is_red(card) else 13
	return rank


static func power_of(card: int) -> int:
	match Cards.rank_of(card):
		7, 8:
			return Power.PEEK_OWN
		9, 10:
			return Power.PEEK_OTHER
		11, 12:
			return Power.SWAP_BLIND
		13:
			return Power.KING if not Cards.is_red(card) else Power.NONE
	return Power.NONE


static func power_name(p: int) -> String:
	match p:
		Power.PEEK_OWN:
			return "Regarder une de vos cartes"
		Power.PEEK_OTHER:
			return "Regarder une carte d'un adversaire"
		Power.SWAP_BLIND:
			return "Échanger sans regarder"
		Power.KING:
			return "Regarder puis échanger"
	return ""


static func key(owner: int, slot: int) -> int:
	return owner * HAND_SIZE + slot


# --- Manche ------------------------------------------------------------------


func start_round() -> void:
	round_number += 1
	draw_pile = Cards.shuffled_deck(rng)
	discard_pile = []
	hands = []
	known = []
	turns_taken = []
	for p: int in n:
		var h: Array[int] = []
		for _s: int in HAND_SIZE:
			h.append(draw_pile.pop_back())
		hands.append(h)
		turns_taken.append(0)
		known.append({})
	for p: int in n:
		known[p][key(p, 2)] = hands[p][2]
		known[p][key(p, 3)] = hands[p][3]
	discard_pile.append(draw_pile.pop_back())
	starter = (starter + 1) % n
	current = starter
	phase = Phase.TURN
	held = -1
	held_from_discard = false
	power = Power.NONE
	king_target = Vector2i(-1, -1)
	dutch_caller = -1
	turns_left = 0
	round_points = []
	round_winners = []
	caller_failed = false
	message = "Manche %d : %s commence." % [round_number, names[current]]
	changed.emit()


func is_bot(p: int) -> bool:
	return p >= 0 and p < n and bots[p]


func current_is_bot() -> bool:
	return is_bot(current)


func awaiting_bot() -> bool:
	return current_is_bot() and phase in [Phase.TURN, Phase.HELD, Phase.POWER, Phase.KING_DECIDE]


func top_discard() -> int:
	return discard_pile[discard_pile.size() - 1] if not discard_pile.is_empty() else -1


func knows(viewer: int, owner: int, slot: int) -> bool:
	return known[viewer].has(key(owner, slot))


func known_card(viewer: int, owner: int, slot: int) -> int:
	return int(known[viewer].get(key(owner, slot), -1))


func can_call_dutch() -> bool:
	return phase == Phase.TURN and dutch_caller < 0 and turns_taken[current] >= 1


func round_is_over() -> bool:
	return phase == Phase.ROUND_OVER or phase == Phase.MATCH_OVER


func _refill_if_needed() -> void:
	if not draw_pile.is_empty():
		return
	if discard_pile.size() <= 1:
		return
	var top: int = discard_pile.pop_back()
	draw_pile = discard_pile.duplicate()
	discard_pile = [top]
	Cards.shuffle(draw_pile, rng)


# --- Actions du tour ---------------------------------------------------------


func call_dutch() -> bool:
	if not can_call_dutch():
		return false
	dutch_caller = current
	turns_left = n - 1
	message = "%s annonce DUTCH ! Dernier tour pour les autres." % names[current]
	_end_turn()
	return true


func draw_from_deck() -> bool:
	if phase != Phase.TURN:
		return false
	_refill_if_needed()
	if draw_pile.is_empty():
		return false
	held = draw_pile.pop_back()
	held_from_discard = false
	phase = Phase.HELD
	message = "%s pioche." % names[current]
	changed.emit()
	return true


func take_discard() -> bool:
	if phase != Phase.TURN or discard_pile.is_empty():
		return false
	held = discard_pile.pop_back()
	held_from_discard = true
	phase = Phase.HELD
	message = "%s prend la défausse." % names[current]
	changed.emit()
	return true


## Place la carte en main à l'emplacement `slot` ; l'ancienne carte part à la défausse.
func swap_held(slot: int) -> bool:
	if phase != Phase.HELD or slot < 0 or slot >= HAND_SIZE:
		return false
	var old: int = hands[current][slot]
	hands[current][slot] = held
	discard_pile.append(old)
	# Les autres voient la défausse (et la carte prise dans la défausse) ; la carte tirée reste secrète.
	for v: int in n:
		known[v].erase(key(current, slot))
	known[current][key(current, slot)] = held
	if held_from_discard:
		for v: int in n:
			known[v][key(current, slot)] = held
	message = "%s échange une carte (défausse : %s)." % [names[current], Cards.rank_label(old)]
	held = -1
	_end_turn()
	return true


## Défausse la carte piochée (impossible si elle vient de la défausse). Un pouvoir peut suivre.
func discard_held() -> bool:
	if phase != Phase.HELD or held_from_discard:
		return false
	var card: int = held
	discard_pile.append(card)
	held = -1
	power = power_of(card)
	if power == Power.NONE:
		message = "%s défausse %s." % [names[current], Cards.rank_label(card)]
		_end_turn()
	else:
		phase = Phase.POWER
		message = "%s défausse %s : %s." % [names[current], Cards.rank_label(card), power_name(power).to_lower()]
		changed.emit()
	return true


func skip_power() -> void:
	if phase == Phase.POWER:
		power = Power.NONE
		message = "%s renonce à son pouvoir." % names[current]
		_end_turn()
	elif phase == Phase.KING_DECIDE:
		keep_king()


func use_peek_own(slot: int) -> bool:
	if phase != Phase.POWER or power != Power.PEEK_OWN or slot < 0 or slot >= HAND_SIZE:
		return false
	known[current][key(current, slot)] = hands[current][slot]
	message = "%s regarde l'une de ses cartes." % names[current]
	power = Power.NONE
	_end_turn()
	return true


func use_peek_other(owner: int, slot: int) -> bool:
	if phase != Phase.POWER or power != Power.PEEK_OTHER or owner == current:
		return false
	if owner < 0 or owner >= n or slot < 0 or slot >= HAND_SIZE:
		return false
	known[current][key(owner, slot)] = hands[owner][slot]
	message = "%s regarde une carte de %s." % [names[current], names[owner]]
	power = Power.NONE
	_end_turn()
	return true


## Échange à l'aveugle une carte de `current` avec une carte d'un adversaire.
func use_swap_blind(my_slot: int, owner: int, slot: int) -> bool:
	if phase != Phase.POWER or power != Power.SWAP_BLIND or owner == current:
		return false
	if owner < 0 or owner >= n or slot < 0 or slot >= HAND_SIZE or my_slot < 0 or my_slot >= HAND_SIZE:
		return false
	_swap_cards(current, my_slot, owner, slot)
	message = "%s échange une carte avec %s." % [names[current], names[owner]]
	power = Power.NONE
	_end_turn()
	return true


## Roi noir : regarde une carte (la sienne ou celle d'un adversaire).
func use_king_look(owner: int, slot: int) -> bool:
	if phase != Phase.POWER or power != Power.KING:
		return false
	if owner < 0 or owner >= n or slot < 0 or slot >= HAND_SIZE:
		return false
	known[current][key(owner, slot)] = hands[owner][slot]
	power = Power.NONE
	if owner == current:
		message = "%s regarde l'une de ses cartes." % names[current]
		_end_turn()
	else:
		king_target = Vector2i(owner, slot)
		phase = Phase.KING_DECIDE
		message = "%s regarde une carte de %s." % [names[current], names[owner]]
		changed.emit()
	return true


## Après le regard du roi : échange la carte vue avec l'une des siennes.
func king_swap(my_slot: int) -> bool:
	if phase != Phase.KING_DECIDE or my_slot < 0 or my_slot >= HAND_SIZE:
		return false
	_swap_cards(current, my_slot, king_target.x, king_target.y)
	message = "%s échange avec %s." % [names[current], names[king_target.x]]
	king_target = Vector2i(-1, -1)
	_end_turn()
	return true


func keep_king() -> void:
	if phase != Phase.KING_DECIDE:
		return
	king_target = Vector2i(-1, -1)
	message = "%s garde les cartes en place." % names[current]
	_end_turn()


## La connaissance suit les cartes (tout le monde voit quels emplacements sont échangés).
func _swap_cards(a_owner: int, a_slot: int, b_owner: int, b_slot: int) -> void:
	var tmp: int = hands[a_owner][a_slot]
	hands[a_owner][a_slot] = hands[b_owner][b_slot]
	hands[b_owner][b_slot] = tmp
	var ka: int = key(a_owner, a_slot)
	var kb: int = key(b_owner, b_slot)
	for v: int in n:
		var had_a: bool = known[v].has(ka)
		var had_b: bool = known[v].has(kb)
		var ca: int = int(known[v].get(ka, -1))
		var cb: int = int(known[v].get(kb, -1))
		known[v].erase(ka)
		known[v].erase(kb)
		if had_a:
			known[v][kb] = ca
		if had_b:
			known[v][ka] = cb


func _end_turn() -> void:
	turns_taken[current] += 1
	power = Power.NONE
	held = -1
	if dutch_caller >= 0:
		if current != dutch_caller:
			turns_left -= 1
		if turns_left <= 0:
			_finish_round()
			return
	current = (current + 1) % n
	phase = Phase.TURN
	_forget(current)
	changed.emit()


## ZIA oublie parfois une carte connue, selon son niveau.
func _forget(p: int) -> void:
	if not bots[p]:
		return
	var loss: float = MEMORY_LOSS[difficulty]
	if loss <= 0.0:
		return
	for k: int in known[p].keys():
		if k >= p * HAND_SIZE and k < (p + 1) * HAND_SIZE:
			continue  # elle ne perd pas ses propres cartes de départ trop vite
		if rng.randf() < loss:
			known[p].erase(k)
	for k: int in known[p].keys():
		if k >= p * HAND_SIZE and k < (p + 1) * HAND_SIZE and rng.randf() < loss * 0.5:
			known[p].erase(k)


func hand_total(p: int) -> int:
	var t: int = 0
	for c: int in hands[p]:
		t += card_points(c)
	return t


func _finish_round() -> void:
	round_points = []
	var best: int = 1000
	for p: int in n:
		best = mini(best, hand_total(p))
	round_winners = []
	for p: int in n:
		if hand_total(p) == best:
			round_winners.append(p)
	caller_failed = false
	if dutch_caller >= 0:
		# Le preneur doit être seul au plus bas, sinon il paie une pénalité.
		if not (round_winners.size() == 1 and round_winners[0] == dutch_caller):
			caller_failed = true
			round_winners.erase(dutch_caller)
	for p: int in n:
		var pts: int = 0 if round_winners.has(p) else hand_total(p)
		if caller_failed and p == dutch_caller:
			pts = hand_total(p) + DUTCH_PENALTY
		round_points.append(pts)
		totals[p] += pts
	var over: bool = false
	for p: int in n:
		if totals[p] >= target:
			over = true
	phase = Phase.MATCH_OVER if over else Phase.ROUND_OVER
	var winner_names: Array[String] = []
	for w: int in round_winners:
		winner_names.append(names[w])
	message = "Manche à %s." % " et ".join(winner_names) if not winner_names.is_empty() else "Manche terminée."
	if caller_failed:
		message += " %s s'est trompé : +%d." % [names[dutch_caller], DUTCH_PENALTY]
	changed.emit()


## Classement final : [{name, score}] du plus petit total au plus grand.
func ranking() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for p: int in n:
		rows.append({"name": names[p], "score": totals[p]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) < int(b["score"]))
	return rows


# --- IA (ZIA) ----------------------------------------------------------------


func _est(p: int, owner: int, slot: int) -> float:
	var k: int = key(owner, slot)
	if known[p].has(k):
		return float(card_points(int(known[p][k])))
	return UNKNOWN_VALUE


func _worst_slot(p: int) -> int:
	var worst: int = 0
	for s: int in HAND_SIZE:
		if _est(p, p, s) > _est(p, p, worst):
			worst = s
	return worst


func _unknown_own_slots(p: int) -> Array[int]:
	var out: Array[int] = []
	for s: int in HAND_SIZE:
		if not knows(p, p, s):
			out.append(s)
	return out


func _random_opponent_slot(p: int, prefer_unknown: bool) -> Vector2i:
	var pool: Array[Vector2i] = []
	for o: int in n:
		if o == p:
			continue
		for s: int in HAND_SIZE:
			if not prefer_unknown or not knows(p, o, s):
				pool.append(Vector2i(o, s))
	if pool.is_empty():
		for o: int in n:
			if o != p:
				pool.append(Vector2i(o, rng.randi_range(0, HAND_SIZE - 1)))
	return pool[rng.randi_range(0, pool.size() - 1)]


func _bot_estimated_total(p: int) -> float:
	var t: float = 0.0
	for s: int in HAND_SIZE:
		t += _est(p, p, s)
	return t


## ZIA annonce Dutch quand sa main estimée est faible (et d'autant plus qu'elle la connaît bien).
func bot_wants_dutch(p: int) -> bool:
	if turns_taken[p] < 1:
		return false
	var known_own: int = HAND_SIZE - _unknown_own_slots(p).size()
	var limit: float = 4.0 + 1.5 * known_own + (1.0 if difficulty == 2 else 0.0)
	if known_own < 3:
		limit = minf(limit, 7.0)
	return _bot_estimated_total(p) <= limit


## Joue une étape de ZIA (un choix par appel). À appeler tant que `awaiting_bot()`.
func bot_step() -> void:
	if not awaiting_bot():
		return
	var p: int = current
	match phase:
		Phase.TURN:
			if can_call_dutch() and bot_wants_dutch(p):
				call_dutch()
				return
			var top: int = top_discard()
			var worst: int = _worst_slot(p)
			var gain: float = _est(p, p, worst) - float(card_points(top))
			if top >= 0 and (gain >= 3.0 or (card_points(top) <= 2 and gain >= 1.0)):
				take_discard()
			else:
				draw_from_deck()
		Phase.HELD:
			var v: int = card_points(held)
			if held_from_discard:
				swap_held(_worst_slot(p))
				return
			var worst: int = _worst_slot(p)
			var unknown: Array[int] = _unknown_own_slots(p)
			if _est(p, p, worst) - float(v) >= 2.0:
				swap_held(worst)
			elif v <= 3 and not unknown.is_empty():
				swap_held(unknown[rng.randi_range(0, unknown.size() - 1)])
			else:
				discard_held()
		Phase.POWER:
			_bot_power(p)
		Phase.KING_DECIDE:
			var seen: float = float(card_points(int(known[p][key(king_target.x, king_target.y)])))
			var worst: int = _worst_slot(p)
			if seen + 2.0 <= _est(p, p, worst):
				king_swap(worst)
			else:
				keep_king()


func _bot_power(p: int) -> void:
	match power:
		Power.PEEK_OWN:
			var unknown: Array[int] = _unknown_own_slots(p)
			if unknown.is_empty():
				skip_power()
			else:
				use_peek_own(unknown[rng.randi_range(0, unknown.size() - 1)])
		Power.PEEK_OTHER:
			var t: Vector2i = _random_opponent_slot(p, true)
			use_peek_other(t.x, t.y)
		Power.SWAP_BLIND:
			var worst: int = _worst_slot(p)
			if _est(p, p, worst) < 8.0:
				skip_power()
				return
			# Une carte adverse connue et faible, sinon au hasard parmi les inconnues.
			var best_target: Vector2i = Vector2i(-1, -1)
			var best_value: float = 99.0
			for o: int in n:
				if o == p:
					continue
				for s: int in HAND_SIZE:
					if knows(p, o, s) and _est(p, o, s) < best_value:
						best_value = _est(p, o, s)
						best_target = Vector2i(o, s)
			if best_target.x < 0 or best_value > _est(p, p, worst) - 3.0:
				best_target = _random_opponent_slot(p, true)
			use_swap_blind(worst, best_target.x, best_target.y)
		Power.KING:
			var unknown: Array[int] = _unknown_own_slots(p)
			if not unknown.is_empty() and rng.randf() < 0.6:
				use_king_look(p, unknown[rng.randi_range(0, unknown.size() - 1)])
			else:
				var t: Vector2i = _random_opponent_slot(p, true)
				use_king_look(t.x, t.y)
		_:
			skip_power()


# --- Conseils du mode débutant -----------------------------------------------


## Phrase d'aide pour le joueur courant (humain).
func advice() -> String:
	var p: int = current
	match phase:
		Phase.TURN:
			var top: int = top_discard()
			if can_call_dutch() and _bot_estimated_total(p) <= 8.0 and HAND_SIZE - _unknown_own_slots(p).size() >= 3:
				return "Votre main semble très faible (≈ %d points) : vous pouvez annoncer DUTCH." % roundi(_bot_estimated_total(p))
			if top >= 0 and card_points(top) <= 3:
				return "La défausse (%s) vaut peu : prenez-la pour remplacer votre plus mauvaise carte." % Cards.rank_label(top)
			return "Piochez : la défausse est trop haute pour vous aider."
		Phase.HELD:
			var v: int = card_points(held)
			if held_from_discard:
				return "Choisissez la carte à remplacer : de préférence la plus haute que vous connaissez."
			if power_of(held) != Power.NONE and v >= 7:
				return "Valeur haute mais pouvoir intéressant (%s) : défaussez-la pour l'utiliser." % power_name(power_of(held)).to_lower()
			if v <= 4:
				return "Carte basse (%d) : échangez-la avec une carte inconnue ou haute." % v
			return "Carte haute (%d) : défaussez-la, ou remplacez une carte encore plus haute." % v
		Phase.POWER:
			return "Pouvoir : %s. Touchez la carte voulue, ou renoncez." % power_name(power).to_lower()
		Phase.KING_DECIDE:
			return "Échangez si la carte vue est plus basse que l'une des vôtres, sinon gardez."
	return ""
