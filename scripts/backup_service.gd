class_name BackupService
extends RefCounted
## Sauvegarde complète des données (banque, statistiques, succès, réglages, joueurs enregistrés)
## sous forme de code texte compact (« AZSAVE1:… ») ou de fichier JSON.

const FORMAT: String = "aszimut-backup"
const PREFIX: String = "AZSAVE1:"
const FILE_NAME: String = "aszimut-sauvegarde.json"

enum Mode { REPLACE, MERGE_PLAYERS }


static func _node(path: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(path) if tree != null else null


static func build() -> Dictionary:
	var bank: Node = _node("/root/Bankroll")
	var stats: Node = _node("/root/Stats")
	return {
		"format": FORMAT,
		"version": 1,
		"app_version": AppInfo.version(),
		"exported_at": int(Time.get_unix_time_from_system()),
		"bank": bank.call("to_dict") if bank != null else {},
		"stats": stats.call("to_dict") if stats != null else {},
		"profiles": ProfileStore.export_data(),
	}


static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")


## Code compact : JSON compressé (gzip) puis base64.
static func to_code(data: Dictionary) -> String:
	var raw: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	return PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## Lit un code ou un JSON. Renvoie les données, ou {"error": message}.
static func parse(text: String) -> Dictionary:
	var t: String = text.strip_edges()
	if t == "":
		return {"error": "Rien à importer : collez d'abord un code de sauvegarde."}
	var json_text: String = t
	if t.contains(PREFIX):
		var payload: String = t.substr(t.find(PREFIX) + PREFIX.length())
		var cleaned: String = ""
		for ch: String in payload:
			if ch not in [" ", "\n", "\r", "\t"]:
				cleaned += ch
		var bytes: PackedByteArray = Marshalls.base64_to_raw(cleaned)
		if bytes.is_empty():
			return {"error": "Code illisible : il a peut-être été coupé lors du copier-coller."}
		var unpacked: PackedByteArray = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		if unpacked.is_empty():
			return {"error": "Code incomplet ou abîmé : recopiez-le en entier."}
		json_text = unpacked.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary or str((parsed as Dictionary).get("format", "")) != FORMAT:
		return {"error": "Ce n'est pas une sauvegarde AsZimut."}
	return parsed as Dictionary


## Résumé lisible d'une sauvegarde, avant de l'importer.
static func describe(data: Dictionary) -> String:
	var lines: Array[String] = []
	var when: int = int(data.get("exported_at", 0))
	if when > 0:
		var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var d: Dictionary = Time.get_datetime_dict_from_unix_time(when + bias)
		lines.append("Sauvegarde du %02d/%02d/%d à %02dh%02d" % [int(d["day"]), int(d["month"]), int(d["year"]), int(d["hour"]), int(d["minute"])])
	lines.append("Version de l'appli : %s" % str(data.get("app_version", "?")))
	var bank: Dictionary = data.get("bank", {})
	lines.append("Banque : %d (record %d)" % [int(bank.get("value", 0)), int(bank.get("best", 0))])
	var profiles: Array = (data.get("profiles", {}) as Dictionary).get("profiles", [])
	var names: Array[String] = []
	for p: Variant in profiles:
		if p is Dictionary:
			names.append(str((p as Dictionary).get("name", "?")))
	lines.append("Joueurs enregistrés : %d%s" % [names.size(), (" (" + ", ".join(names) + ")") if not names.is_empty() else ""])
	var stats: Dictionary = data.get("stats", {})
	lines.append("Succès : %d" % (stats.get("achievements", []) as Array).size())
	return "\n".join(lines)


## Applique une sauvegarde. Renvoie un message de confirmation.
static func apply(data: Dictionary, mode: int) -> String:
	var profiles: Dictionary = data.get("profiles", {})
	if mode == Mode.MERGE_PLAYERS:
		var r: Array[int] = ProfileStore.import_merge(profiles)
		return "Joueurs ajoutés : %d, mis à jour : %d. Vos autres données n'ont pas changé." % [r[0], r[1]]
	ProfileStore.import_replace(profiles)
	var bank: Node = _node("/root/Bankroll")
	if bank != null and data.has("bank"):
		bank.call("load_dict", data["bank"])
	if bank != null:
		bank.call("use_profile", ProfileStore.active_id())
	var stats: Node = _node("/root/Stats")
	if stats != null and data.has("stats"):
		stats.call("load_dict", data["stats"])
	GameSave.clear()
	return "Données restaurées : banque, statistiques, succès, réglages et joueurs."
