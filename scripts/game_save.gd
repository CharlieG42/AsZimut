class_name GameSave
extends RefCounted
## Sauvegarde de la partie en cours (multijoueur local, Dutch, poker solo à la table),
## pour la reprendre si Android ferme l'appli. On sauvegarde au début de chaque main / manche :
## la reprise redémarre cette main avec les piles (ou scores) qu'avaient les joueurs.

static var path: String = "user://aszimut_resume.json"


## `data` : instantané du moteur ; la configuration de LocalSession est enregistrée avec.
static func save(data: Dictionary) -> void:
	var payload: Dictionary = {
		"game": LocalSession.game,
		"solo": LocalSession.solo,
		"solo_poker": LocalSession.solo_poker,
		"solo_outside": LocalSession.solo_outside,
		"count": LocalSession.count,
		"chips": LocalSession.chips,
		"dutch_target": LocalSession.dutch_target,
		"names": Array(LocalSession.names),
		"bots": Array(LocalSession.bots),
		"profile_ids": Array(LocalSession.profile_ids),
		"use_banks": LocalSession.use_banks,
		"start_stacks": Array(LocalSession.start_stacks),
		"data": data,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload))


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func load_save() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).has("data"):
		return parsed as Dictionary
	return {}


static func has_save() -> bool:
	return not load_save().is_empty()


## Remet LocalSession dans l'état de la partie sauvegardée et prépare la reprise.
static func apply(payload: Dictionary) -> void:
	LocalSession.game = int(payload.get("game", LocalSession.Game.POKER))
	LocalSession.solo = bool(payload.get("solo", false))
	LocalSession.solo_poker = bool(payload.get("solo_poker", false))
	LocalSession.solo_outside = int(payload.get("solo_outside", 0))
	LocalSession.count = int(payload.get("count", 2))
	LocalSession.chips = int(payload.get("chips", 1000))
	LocalSession.dutch_target = int(payload.get("dutch_target", 50))
	var names: Array = payload.get("names", [])
	var bots: Array = payload.get("bots", [])
	for i: int in mini(names.size(), LocalSession.names.size()):
		LocalSession.names[i] = str(names[i])
	for i: int in mini(bots.size(), LocalSession.bots.size()):
		LocalSession.bots[i] = bool(bots[i])
	var pids: Array = payload.get("profile_ids", [])
	for i: int in LocalSession.profile_ids.size():
		LocalSession.profile_ids[i] = str(pids[i]) if i < pids.size() else ""
	LocalSession.use_banks = bool(payload.get("use_banks", false))
	LocalSession.start_stacks = []
	for v: Variant in payload.get("start_stacks", []):
		LocalSession.start_stacks.append(int(v))
	if LocalSession.start_stacks.size() != LocalSession.count:
		LocalSession.compute_start_stacks()
	LocalSession.resume_data = payload.get("data", {})


## Libellé du bouton « Reprendre » de l'accueil.
static func describe(payload: Dictionary) -> String:
	var g: int = int(payload.get("game", 0))
	var data: Dictionary = payload.get("data", {})
	var title: String = LocalSession.title(g)
	match g:
		LocalSession.Game.DUTCH:
			return "Reprendre : Dutch · manche %d" % int(data.get("round_number", 1))
		LocalSession.Game.POKER:
			var label: String = "table solo" if bool(payload.get("solo_poker", false)) else "%d joueurs" % int(payload.get("count", 2))
			return "Reprendre : Poker · main %d · %s" % [int(data.get("hand_number", 1)), label]
	return "Reprendre : %s · %d joueurs" % [title, int(payload.get("count", 2))]
