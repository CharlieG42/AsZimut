class_name ProfileStore
extends RefCounted
## Carnet de joueurs enregistrés sur l'appareil (nombre illimité) : nom, banque personnelle,
## statistiques par jeu, et groupes récents (« la famille », « les amis ») à rappeler en un geste.

const START_BANK: int = 1000
const MIN_BANK: int = 100
const MAX_GROUPS: int = 6
const GAME_KEYS: Array[String] = ["bj", "pk", "du"]

static var path: String = "user://aszimut_profiles.json"
static var _data: Dictionary = {}
static var _loaded_from: String = ""


static func _ensure() -> void:
	if _loaded_from == path:
		return
	_loaded_from = path
	_data = {"profiles": [], "groups": [], "next_id": 1}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var d: Dictionary = parsed
			_data["profiles"] = d.get("profiles", [])
			_data["groups"] = d.get("groups", [])
			_data["next_id"] = int(d.get("next_id", 1))


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
		"bj": {"games": 0, "wins": 0, "net": 0},
		"pk": {"games": 0, "wins": 0, "net": 0},
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
			s["net"] = int(s.get("net", 0)) + int(e.get("final", 0)) - int(e.get("start", 0))
			if update_banks:
				p["bank"] = maxi(0, int(e.get("final", 0)))
				p["best_bank"] = maxi(int(p.get("best_bank", START_BANK)), int(p["bank"]))
		p["stats"] = stats
		p["last_played"] = now
	_save()


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
