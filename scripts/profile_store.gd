class_name ProfileStore
extends RefCounted
## Carnet de joueurs enregistrés sur l'appareil (nombre illimité) : nom, banque personnelle,
## statistiques par jeu, et groupes récents (« la famille », « les amis ») à rappeler en un geste.

const START_BANK: int = 1000
const MIN_BANK: int = 100
const MAX_GROUPS: int = 6
const GAME_KEYS: Array[String] = ["bj", "pk", "du"]
## Nombre maximal de points conservés dans l'historique des gains cumulés d'un joueur.
const HISTORY_MAX: int = 300

static var path: String = "user://aszimut_profiles.json"
static var _data: Dictionary = {}
static var _loaded_from: String = ""


static func _ensure() -> void:
	if _loaded_from == path:
		return
	_loaded_from = path
	_data = {"profiles": [], "groups": [], "next_id": 1, "active": ""}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var d: Dictionary = parsed
			_data["profiles"] = d.get("profiles", [])
			_data["groups"] = d.get("groups", [])
			_data["next_id"] = int(d.get("next_id", 1))
			_data["active"] = str(d.get("active", ""))


static func _save() -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_data, "\t"))


## Recharge depuis le disque (tests, ou après un changement de fichier).
static func reload() -> void:
	_loaded_from = ""
	_ensure()


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func _empty_stats() -> Dictionary:
	return {
		"bj": {"games": 0, "wins": 0, "losses": 0, "pushes": 0, "blackjacks": 0, "net": 0},
		"pk": {"games": 0, "wins": 0, "losses": 0, "pushes": 0, "splits": 0, "biggest_pot": 0, "net": 0},
		"du": {"games": 0, "wins": 0, "best": -1},
	}


# --- Profils -----------------------------------------------------------------


## Tous les profils, le plus récemment joué en premier.
static func profiles() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for p: Variant in _data["profiles"]:
		out.append(p as Dictionary)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var la: int = int(a.get("last_played", 0))
			var lb: int = int(b.get("last_played", 0))
			if la != lb:
				return la > lb
			return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
	)
	return out


static func count() -> int:
	_ensure()
	return (_data["profiles"] as Array).size()


static func get_profile(id: String) -> Dictionary:
	_ensure()
	for p: Variant in _data["profiles"]:
		if str((p as Dictionary)["id"]) == id:
			return p as Dictionary
	return {}


static func exists(id: String) -> bool:
	return id != "" and not get_profile(id).is_empty()


static func name_of(id: String) -> String:
	var p: Dictionary = get_profile(id)
	return str(p.get("name", ""))


static func find_by_name(name: String) -> String:
	_ensure()
	var key: String = name.strip_edges().to_lower()
	if key == "":
		return ""
	for p: Variant in _data["profiles"]:
		if str((p as Dictionary)["name"]).to_lower() == key:
			return str((p as Dictionary)["id"])
	return ""


## Crée un profil (ou renvoie celui qui porte déjà ce nom). "" si le nom est vide.
static func create(name: String) -> String:
	_ensure()
	var clean: String = name.strip_edges().left(12)
	if clean == "":
		return ""
	var existing: String = find_by_name(clean)
	if existing != "":
		return existing
	var id: String = "p%d" % int(_data["next_id"])
	_data["next_id"] = int(_data["next_id"]) + 1
	(_data["profiles"] as Array).append({
		"id": id,
		"name": clean,
		"created": _now(),
		"last_played": 0,
		"bank": START_BANK,
		"best_bank": START_BANK,
		"stats": _empty_stats(),
	})
	_save()
	return id


## Renomme ; refuse un nom vide ou déjà pris par un autre profil.
static func rename(id: String, name: String) -> bool:
	var clean: String = name.strip_edges().left(12)
	var other: String = find_by_name(clean)
	if clean == "" or (other != "" and other != id):
		return false
	var p: Dictionary = get_profile(id)
	if p.is_empty():
		return false
	p["name"] = clean
	_save()
	return true


static func remove(id: String) -> void:
	_ensure()
	if str(_data.get("active", "")) == id:
		_data["active"] = ""
	var kept: Array = []
	for p: Variant in _data["profiles"]:
		if str((p as Dictionary)["id"]) != id:
			kept.append(p)
	_data["profiles"] = kept
	var groups: Array = []
	for g: Variant in _data["groups"]:
		var ids: Array = (g as Array).filter(func(x: Variant) -> bool: return str(x) != id)
		if not ids.is_empty():
			groups.append(ids)
	_data["groups"] = groups
	_save()


static func bank_of(id: String) -> int:
	return int(get_profile(id).get("bank", START_BANK))


static func set_bank(id: String, value: int) -> void:
	var p: Dictionary = get_profile(id)
	if p.is_empty():
		return
	p["bank"] = maxi(0, value)
	p["best_bank"] = maxi(int(p.get("best_bank", START_BANK)), int(p["bank"]))
	_save()


## Banque utilisable pour commencer une partie : rechargée à 1000 si elle est presque vide.
static func playable_bank(id: String) -> int:
	var b: int = bank_of(id)
	return START_BANK if b < MIN_BANK else b


# --- Joueur actif (parties solo) ---------------------------------------------------


## Profil qui joue en solo (blackjack, poker, Dutch contre ZIA), "" = invité sans profil.
static func active_id() -> String:
	_ensure()
	var id: String = str(_data.get("active", ""))
	return id if exists(id) else ""


static func active_name() -> String:
	return name_of(active_id())


static func set_active(id: String) -> void:
	_ensure()
	_data["active"] = id if exists(id) else ""
	_save()


## Nom affiché pour le joueur humain d'une partie solo.
static func solo_name() -> String:
	var n: String = active_name()
	return n if n != "" else "Vous"


## Enregistre le résultat d'une partie (ou manche) solo pour le joueur actif.
## `delta` : gain net en jetons ; `points` : total Dutch (-1 si sans objet).
## `extra` : compteurs détaillés (« blackjacks », « splits » : +1 ; « biggest_pot » : plus gros pot).
static func record_active(game_key: String, won: bool, delta: int, points: int = -1, extra: Dictionary = {}) -> void:
	var id: String = active_id()
	if id == "":
		return
	var e: Dictionary = {"id": id, "rank": 0 if won else 1, "start": 0, "final": delta}
	if points >= 0:
		e["points"] = points
	if not extra.is_empty():
		e["extra"] = extra
	record_game(game_key, [e] as Array[Dictionary], false)


# --- Groupes récents -----------------------------------------------------------


## Mémorise un groupe de joueurs enregistrés (le plus récent en tête, sans doublon).
static func note_group(ids: Array[String]) -> void:
	_ensure()
	var clean: Array = []
	for id: String in ids:
		if exists(id) and not clean.has(id):
			clean.append(id)
	if clean.size() < 2:
		return
	var key: Array = clean.duplicate()
	key.sort()
	var groups: Array = [clean]
	for g: Variant in _data["groups"]:
		var other: Array = (g as Array).duplicate()
		other.sort()
		if other != key:
			groups.append(g)
	_data["groups"] = groups.slice(0, MAX_GROUPS)
	_save()


## Groupes récents (identifiants de profils existants).
static func recent_groups() -> Array[Array]:
	_ensure()
	var out: Array[Array] = []
	for g: Variant in _data["groups"]:
		var ids: Array = []
		for id: Variant in g:
			if exists(str(id)):
				ids.append(str(id))
		if ids.size() >= 2:
			out.append(ids)
	return out


static func group_label(ids: Array) -> String:
	var parts: Array[String] = []
	for id: Variant in ids:
		parts.append(name_of(str(id)))
	return " · ".join(parts)


# --- Résultats -------------------------------------------------------------------


## Enregistre une partie terminée pour chaque joueur enregistré.
## `entries` : [{id, rank (0 = premier), start, final (piles) ou points (Dutch)}].
static func record_game(game_key: String, entries: Array[Dictionary], update_banks: bool) -> void:
	_ensure()
	if not GAME_KEYS.has(game_key):
		return
	var now: int = _now()
	for e: Dictionary in entries:
		var p: Dictionary = get_profile(str(e.get("id", "")))
		if p.is_empty():
			continue
		var stats: Dictionary = p.get("stats", _empty_stats())
		if not stats.has(game_key):
			stats[game_key] = _empty_stats()[game_key]
		var s: Dictionary = stats[game_key]
		s["games"] = int(s.get("games", 0)) + 1
		if int(e.get("rank", 99)) == 0:
			s["wins"] = int(s.get("wins", 0)) + 1
		if game_key == "du":
			var pts: int = int(e.get("points", 0))
			var best: int = int(s.get("best", -1))
			s["best"] = pts if best < 0 else mini(best, pts)
		else:
			var gain: int = int(e.get("final", 0)) - int(e.get("start", 0))
			# Cumul avant cette partie (les parties d'avant l'historique sont reprises des compteurs).
			var before: int = total_net_of(p)
			s["net"] = int(s.get("net", 0)) + gain
			if gain < 0:
				s["losses"] = int(s.get("losses", 0)) + 1
			elif gain == 0:
				s["pushes"] = int(s.get("pushes", 0)) + 1
			var extra: Dictionary = e.get("extra", {})
			for k: Variant in extra.keys():
				if str(k) == "biggest_pot":
					s["biggest_pot"] = maxi(int(s.get("biggest_pot", 0)), int(extra[k]))
				else:
					s[str(k)] = int(s.get(str(k), 0)) + int(extra[k])
			var hist: Array = p.get("history", [])
			hist.append([now, before + gain])
			while hist.size() > HISTORY_MAX:
				hist.pop_front()
			p["history"] = hist
			if update_banks:
				p["bank"] = maxi(0, int(e.get("final", 0)))
				p["best_bank"] = maxi(int(p.get("best_bank", START_BANK)), int(p["bank"]))
		p["stats"] = stats
		p["last_played"] = now
	_save()


## Gains cumulés (blackjack + poker) d'un profil, tous temps confondus.
static func total_net_of(p: Dictionary) -> int:
	var hist: Array = p.get("history", [])
	if not hist.is_empty():
		return int((hist[hist.size() - 1] as Array)[1])
	var stats: Dictionary = p.get("stats", {})
	return int((stats.get("bj", {}) as Dictionary).get("net", 0)) + int((stats.get("pk", {}) as Dictionary).get("net", 0))


static func total_net(id: String) -> int:
	return total_net_of(get_profile(id))


## Valeurs de l'historique des gains cumulés (une par partie, la plus ancienne d'abord).
static func history_values(id: String) -> Array[int]:
	var out: Array[int] = []
	for pt: Variant in get_profile(id).get("history", []):
		out.append(int((pt as Array)[1]))
	return out


## Compteurs d'un jeu ("bj", "pk" ou "du") avec toutes les clés présentes (0 par défaut).
static func game_stats(id: String, game_key: String) -> Dictionary:
	var out: Dictionary = (_empty_stats()[game_key] as Dictionary).duplicate()
	var stats: Dictionary = get_profile(id).get("stats", {})
	var have: Dictionary = stats.get(game_key, {})
	for k: Variant in have.keys():
		out[k] = int(have[k])
	return out


## Résumé lisible des statistiques d'un profil.
static func summary(id: String) -> Array[String]:
	var p: Dictionary = get_profile(id)
	var stats: Dictionary = p.get("stats", _empty_stats())
	var lines: Array[String] = []
	var bj: Dictionary = stats.get("bj", {})
	if int(bj.get("games", 0)) > 0:
		lines.append("Blackjack : %d partie(s), %d gagnée(s), %s jetons" % [int(bj["games"]), int(bj["wins"]), UIKit.signed(int(bj["net"]))])
	var pk: Dictionary = stats.get("pk", {})
	if int(pk.get("games", 0)) > 0:
		lines.append("Poker : %d partie(s), %d gagnée(s), %s jetons" % [int(pk["games"]), int(pk["wins"]), UIKit.signed(int(pk["net"]))])
	var du: Dictionary = stats.get("du", {})
	if int(du.get("games", 0)) > 0:
		lines.append("Dutch : %d partie(s), %d gagnée(s), meilleur total %d" % [int(du["games"]), int(du["wins"]), int(du["best"])])
	if lines.is_empty():
		lines.append("Pas encore de partie terminée.")
	return lines


# --- Export / import -----------------------------------------------------------


static func export_data() -> Dictionary:
	_ensure()
	return _data.duplicate(true)


static func _valid_profile(p: Variant) -> bool:
	return p is Dictionary and (p as Dictionary).has("id") and str((p as Dictionary).get("name", "")).strip_edges() != ""


## Remplace tout le carnet par celui importé.
static func import_replace(d: Dictionary) -> void:
	_ensure()
	var profiles: Array = []
	var max_id: int = 0
	for p: Variant in d.get("profiles", []):
		if _valid_profile(p):
			profiles.append((p as Dictionary).duplicate(true))
			max_id = maxi(max_id, str((p as Dictionary)["id"]).trim_prefix("p").to_int())
	_data = {
		"profiles": profiles,
		"groups": (d.get("groups", []) as Array).duplicate(true),
		"next_id": maxi(int(d.get("next_id", 1)), max_id + 1),
		"active": str(d.get("active", "")),
	}
	if not exists(str(_data["active"])):
		_data["active"] = ""
	_save()


## Ajoute les joueurs importés : un joueur déjà présent (même nom) garde la version jouée le plus récemment.
## Renvoie [ajoutés, mis à jour].
static func import_merge(d: Dictionary) -> Array[int]:
	_ensure()
	var added: int = 0
	var updated: int = 0
	var id_map: Dictionary = {}
	for p: Variant in d.get("profiles", []):
		if not _valid_profile(p):
			continue
		var incoming: Dictionary = (p as Dictionary).duplicate(true)
		var old_id: String = str(incoming["id"])
		var mine: String = find_by_name(str(incoming["name"]))
		if mine == "":
			var new_id: String = "p%d" % int(_data["next_id"])
			_data["next_id"] = int(_data["next_id"]) + 1
			incoming["id"] = new_id
			(_data["profiles"] as Array).append(incoming)
			id_map[old_id] = new_id
			added += 1
		else:
			id_map[old_id] = mine
			var current: Dictionary = get_profile(mine)
			if int(incoming.get("last_played", 0)) > int(current.get("last_played", 0)):
				for k: Variant in incoming.keys():
					if str(k) != "id" and str(k) != "name":
						current[k] = incoming[k]
				updated += 1
	# Groupes : on reprend ceux de l'autre appareil, avec les identifiants d'ici.
	for g: Variant in d.get("groups", []):
		var ids: Array[String] = []
		for id: Variant in g:
			if id_map.has(str(id)):
				ids.append(str(id_map[str(id)]))
		if ids.size() >= 2:
			var groups: Array = _data["groups"]
			var key: Array = ids.duplicate()
			key.sort()
			var dup: bool = false
			for other: Variant in groups:
				var o: Array = (other as Array).duplicate()
				o.sort()
				if o == key:
					dup = true
			if not dup and groups.size() < MAX_GROUPS:
				groups.append(ids)
	_save()
	return [added, updated]
