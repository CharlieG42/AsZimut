class_name ProfilesScreen
extends Control
## Carnet des joueurs enregistrés : progression, banque, renommer, supprimer, créer.

const SCENE: String = "res://scenes/profiles.tscn"

static var return_scene: String = "res://scenes/home.tscn"

var _content: VBoxContainer
var _editing: String = ""
var _confirm_delete: String = ""
var _confirm_bank: String = ""
var _new_name: String = ""
var _error: String = ""


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
	_rebuild()
	UIKit.fade_in(self)


func _rebuild() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Retour", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_back)
	bar.add_child(back)
	var title: Label = UIKit.label("Joueurs", 22, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	_content.add_child(bar)

	var intro: Label = UIKit.label(
		"Les joueurs enregistrés gardent leur progression d'une partie locale à l'autre : statistiques et banque personnelle.",
		13, UIKit.TEXT_SOFT
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	# Nouveau joueur
	var add_panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 12, Color(1, 1, 1, 0.08))
	var add_row: HBoxContainer = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	add_panel.add_child(add_row)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = "Nouveau joueur"
	edit.max_length = 12
	edit.text = _new_name
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 46)
	edit.add_theme_font_size_override("font_size", 17)
	edit.text_changed.connect(func(t: String) -> void: _new_name = t)
	edit.text_submitted.connect(func(_t: String) -> void: _add())
	add_row.add_child(edit)
	var add: Button = UIKit.button("Ajouter", UIKit.GOLD, UIKit.INK, 16)
	add.custom_minimum_size = Vector2(110, 46)
	add.pressed.connect(_add)
	add_row.add_child(add)
	_content.add_child(add_panel)
	if _error != "":
		_content.add_child(UIKit.label(_error, 13, UIKit.WARNING_TEXT))

	var all: Array[Dictionary] = ProfileStore.profiles()
	if all.is_empty():
		var empty: Label = UIKit.label(
			"Aucun joueur pour l'instant. Ajoutez-en ici, ou laissez cochée « Enregistrer les nouveaux joueurs » en préparant une partie locale.",
			13, UIKit.TEXT_SOFT
		)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(empty)
	for p: Dictionary in all:
		_content.add_child(_card(p))


func _card(p: Dictionary) -> Control:
	var id: String = str(p["id"])
	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 12, Color(1, 1, 1, 0.1))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	if _editing == id:
		var edit: LineEdit = LineEdit.new()
		edit.text = str(p["name"])
		edit.max_length = 12
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size = Vector2(0, 44)
		edit.add_theme_font_size_override("font_size", 17)
		edit.text_submitted.connect(_rename.bind(id))
		head.add_child(edit)
		var ok: Button = UIKit.button("OK", UIKit.GOLD, UIKit.INK, 15)
		ok.custom_minimum_size = Vector2(70, 44)
		ok.pressed.connect(func() -> void: _rename(edit.text, id))
		head.add_child(ok)
	else:
		var name_label: Label = UIKit.label("★ " + str(p["name"]), 19, Color.WHITE, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var bank: CoinLabel = CoinLabel.new(16, UIKit.GOLD)
		bank.set_amount(int(p.get("bank", ProfileStore.START_BANK)))
		head.add_child(bank)
	col.add_child(head)

	for line: String in ProfileStore.summary(id):
		var l: Label = UIKit.label(line, 13, UIKit.TEXT_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var last: int = int(p.get("last_played", 0))
	var meta: String = "Record de banque : %d" % int(p.get("best_bank", ProfileStore.START_BANK))
	if last > 0:
		var d: Dictionary = Time.get_date_dict_from_unix_time(last)
		meta += " · dernière partie le %02d/%02d/%d" % [int(d["day"]), int(d["month"]), int(d["year"])]
	var m: Label = UIKit.label(meta, 11, UIKit.TEXT_SOFT)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(m)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var rename_btn: Button = UIKit.outline_button("Renommer", Color.WHITE, 13)
	rename_btn.custom_minimum_size = Vector2(0, 40)
	rename_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_btn.pressed.connect(func() -> void:
		_editing = "" if _editing == id else id
		_error = ""
		_rebuild()
	)
	actions.add_child(rename_btn)
	var bank_btn: Button = UIKit.outline_button(
		"Confirmer ?" if _confirm_bank == id else "Banque à %d" % ProfileStore.START_BANK, UIKit.GOLD, 13
	)
	bank_btn.custom_minimum_size = Vector2(0, 40)
	bank_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_btn.pressed.connect(_reset_bank.bind(id))
	actions.add_child(bank_btn)
	var del: Button = UIKit.outline_button(
		"Confirmer ?" if _confirm_delete == id else "Supprimer",
		UIKit.DANGER if _confirm_delete == id else UIKit.WARNING_TEXT, 13
	)
	del.custom_minimum_size = Vector2(0, 40)
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del.pressed.connect(_delete.bind(id))
	actions.add_child(del)
	col.add_child(actions)
	return panel


func _add() -> void:
	var name: String = _new_name.strip_edges()
	if name == "":
		return
	if ProfileStore.find_by_name(name) != "":
		_error = "« %s » existe déjà." % name
	else:
		ProfileStore.create(name)
		_new_name = ""
		_error = ""
	_rebuild()


func _rename(text: String, id: String) -> void:
	if ProfileStore.rename(id, text):
		_editing = ""
		_error = ""
	else:
		_error = "Nom vide ou déjà utilisé."
	_rebuild()


func _reset_bank(id: String) -> void:
	if _confirm_bank == id:
		ProfileStore.set_bank(id, ProfileStore.START_BANK)
		_confirm_bank = ""
	else:
		_confirm_bank = id
		_confirm_delete = ""
	_rebuild()


func _delete(id: String) -> void:
	if _confirm_delete == id:
		ProfileStore.remove(id)
		for i: int in LocalSession.profile_ids.size():
			if LocalSession.profile_ids[i] == id:
				LocalSession.profile_ids[i] = ""
				LocalSession.names[i] = ""
		_confirm_delete = ""
	else:
		_confirm_delete = id
		_confirm_bank = ""
	_rebuild()


func _go_back() -> void:
	get_tree().change_scene_to_file(return_scene)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
