class_name BackupScreen
extends Control
## Export / import des données : code à copier-coller (partout) ou fichier (sélecteur Android).

const SCENE: String = "res://scenes/backup.tscn"
const STATS_SCENE: String = "res://scenes/stats.tscn"

var _content: VBoxContainer
var _code_box: TextEdit
var _import_box: TextEdit
var _status: Label
var _preview_panel: PanelContainer
var _preview_label: Label
var _replace_button: Button
var _pending: Dictionary = {}
var _confirm_replace: bool = false


func _ready() -> void:
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_build()
	UIKit.fade_in(self)


func _build() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Options", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_back)
	bar.add_child(back)
	var title: Label = UIKit.label("Sauvegarde", 22, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	_content.add_child(bar)

	var intro: Label = UIKit.label(
		"Banque, statistiques, succès, réglages et joueurs enregistrés tiennent dans un code à garder où vous voulez "
		+ "(note, mail, message…). Pratique pour changer de téléphone ou avant de désinstaller l'appli.",
		13, UIKit.TEXT_SOFT
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	_status = UIKit.label("", 14, UIKit.GREEN_ACTION, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false

	# Export
	var ex: VBoxContainer = _section("Exporter")
	var copy: Button = UIKit.button("Copier le code de sauvegarde", UIKit.GOLD, UIKit.INK, 18)
	copy.pressed.connect(_export_code)
	ex.add_child(copy)
	_code_box = _text_box("Le code apparaîtra ici.", 110)
	_code_box.editable = false
	_code_box.visible = false
	ex.add_child(_code_box)
	if _files_available():
		var save: Button = UIKit.outline_button("Enregistrer dans un fichier…", Color.WHITE, 16)
		save.pressed.connect(_export_file)
		ex.add_child(save)

	_content.add_child(_status)

	# Import
	var im: VBoxContainer = _section("Importer")
	_import_box = _text_box("Collez ici un code de sauvegarde (AZSAVE1:…)", 110)
	im.add_child(_import_box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var paste: Button = UIKit.outline_button("Coller", Color.WHITE, 16)
	paste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste.pressed.connect(_paste)
	row.add_child(paste)
	var read: Button = UIKit.button("Lire le code", Color(0.16, 0.36, 0.28), Color.WHITE, 16)
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read.pressed.connect(_read_code)
	row.add_child(read)
	im.add_child(row)
	if _files_available():
		var open: Button = UIKit.outline_button("Ouvrir un fichier…", Color.WHITE, 16)
		open.pressed.connect(_import_file)
		im.add_child(open)

	_preview_panel = UIKit.panel(Color(0.1, 0.16, 0.26, 0.96), 14, 12, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.6))
	var pcol: VBoxContainer = VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 8)
	_preview_panel.add_child(pcol)
	pcol.add_child(UIKit.label("SAUVEGARDE TROUVÉE", 12, UIKit.GOLD, true))
	_preview_label = UIKit.label("", 14, Color.WHITE)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(_preview_label)
	_replace_button = UIKit.button("Remplacer toutes mes données", UIKit.GOLD, UIKit.INK, 16)
	_replace_button.pressed.connect(_apply_replace)
	pcol.add_child(_replace_button)
	var merge: Button = UIKit.outline_button("Ajouter seulement les joueurs", Color.WHITE, 16)
	merge.pressed.connect(_apply_merge)
	pcol.add_child(merge)
	var hint: Label = UIKit.label(
		"« Remplacer » : nouveau téléphone, tout est restauré. « Ajouter les joueurs » : rassemble les carnets "
		+ "de deux appareils sans toucher à votre banque ni à vos statistiques.",
		12, UIKit.TEXT_SOFT
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(hint)
	_preview_panel.visible = false
	im.add_child(_preview_panel)


func _section(title: String) -> VBoxContainer:
	var p: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 14, Color(1, 1, 1, 0.08))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var head: Label = UIKit.label(title.to_upper(), 12, UIKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	_content.add_child(p)
	return box


func _text_box(placeholder: String, height: float) -> TextEdit:
	var t: TextEdit = TextEdit.new()
	t.placeholder_text = placeholder
	t.custom_minimum_size = Vector2(0, height)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.add_theme_font_size_override("font_size", 12)
	return t


func _say(text: String, ok: bool = true) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UIKit.GREEN_ACTION if ok else UIKit.WARNING_TEXT)
	_status.visible = true


static func _files_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


# --- Export ----------------------------------------------------------------


func _export_code() -> void:
	var code: String = BackupService.to_code(BackupService.build())
	DisplayServer.clipboard_set(code)
	_code_box.text = code
	_code_box.visible = true
	_say("Code copié (%d caractères). Collez-le dans une note ou un message pour le garder." % code.length())


func _export_file() -> void:
	DisplayServer.file_dialog_show(
		"Enregistrer la sauvegarde", "", BackupService.FILE_NAME, false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json"]), _on_save_chosen
	)


func _on_save_chosen(ok: bool, paths: PackedStringArray, _filter: int) -> void:
	if not ok or paths.is_empty():
		return
	var f: FileAccess = FileAccess.open(paths[0], FileAccess.WRITE)
	if f == null:
		_say("Impossible d'écrire ce fichier ici. Utilisez plutôt « Copier le code ».", false)
		return
	f.store_string(BackupService.to_json(BackupService.build()))
	f.close()
	_say("Sauvegarde enregistrée.")


# --- Import ----------------------------------------------------------------


func _paste() -> void:
	_import_box.text = DisplayServer.clipboard_get()
	_read_code()


func _read_code() -> void:
	_check(_import_box.text)


func _import_file() -> void:
	DisplayServer.file_dialog_show(
		"Ouvrir une sauvegarde", "", "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json", "*.txt"]), _on_open_chosen
	)


func _on_open_chosen(ok: bool, paths: PackedStringArray, _filter: int) -> void:
	if not ok or paths.is_empty():
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(paths[0])
	if bytes.is_empty():
		_say("Impossible de lire ce fichier. Ouvrez-le ailleurs, copiez son contenu et collez-le ici.", false)
		return
	_check(bytes.get_string_from_utf8())


func _check(text: String) -> void:
	_confirm_replace = false
	_replace_button.text = "Remplacer toutes mes données"
	var data: Dictionary = BackupService.parse(text)
	if data.has("error"):
		_pending = {}
		_preview_panel.visible = false
		_say(str(data["error"]), false)
		return
	_pending = data
	_preview_label.text = BackupService.describe(data)
	_preview_panel.visible = true
	_status.visible = false


func _apply_replace() -> void:
	if _pending.is_empty():
		return
	if not _confirm_replace:
		_confirm_replace = true
		_replace_button.text = "Confirmer : tout remplacer ?"
		return
	_say(BackupService.apply(_pending, BackupService.Mode.REPLACE))
	_pending = {}
	_preview_panel.visible = false
	_import_box.text = ""


func _apply_merge() -> void:
	if _pending.is_empty():
		return
	_say(BackupService.apply(_pending, BackupService.Mode.MERGE_PLAYERS))
	_pending = {}
	_preview_panel.visible = false
	_import_box.text = ""


func _go_back() -> void:
	get_tree().change_scene_to_file(STATS_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
