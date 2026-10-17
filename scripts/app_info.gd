class_name AppInfo
extends RefCounted
## Version de l'appli : « 0.0.01.xxx.yyy » (xxx = dernière PR fusionnée, yyy = numéro de push).
## La CI réécrit `config/version` de project.godot à chaque build ; en local : 0.0.01.000.000.


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.01.000.000"))


static func _part(index: int) -> String:
	var parts: PackedStringArray = version().split(".")
	return parts[index] if parts.size() > index else "000"


static func pr_text() -> String:
	var v: String = _part(3)
	return "inconnue (build local)" if v.to_int() == 0 else "#%d" % v.to_int()


static func push_text() -> String:
	var v: String = _part(4)
	return "inconnu (build local)" if v.to_int() == 0 else "#%d" % v.to_int()
