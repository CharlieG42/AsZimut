extends Control
## Classement de fin de partie multijoueur locale.


func _ready() -> void:
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	col.add_child(UIKit.spacer(16))
	col.add_child(UIKit.label("Classement", 38, UIKit.GOLD, true))
	var subtitle: String = LocalSession.title(LocalSession.game)
	if LocalSession.solo_poker:
		subtitle += " · table solo"
	col.add_child(UIKit.label(subtitle, 15, UIKit.TEXT_SOFT))
	col.add_child(UIKit.spacer(8))

	var rows: Array[Dictionary] = LocalSession.results
	for i: int in rows.size():
		col.add_child(_row(i, rows[i]))

	var saved: Array[String] = []
	if not LocalSession.solo and not LocalSession.solo_poker:
		for i: int in LocalSession.count:
			if not LocalSession.bots[i] and ProfileStore.exists(LocalSession.profile_ids[i]):
				var pid: String = LocalSession.profile_ids[i]
				var text: String = ProfileStore.name_of(pid)
				if LocalSession.uses_personal_banks():
					text += " (banque %d)" % ProfileStore.bank_of(pid)
				saved.append(text)
	if not saved.is_empty():
		var note: Label = UIKit.label("Progression enregistrée : " + ", ".join(saved), 13, UIKit.GREEN_ACTION)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(note)

	col.add_child(UIKit.spacer(10))
	var again: Button = UIKit.button("Rejouer avec les mêmes joueurs", UIKit.GOLD, UIKit.INK, 18)
	again.pressed.connect(_change.bind(LocalSession.scene(LocalSession.game)))
	col.add_child(again)
	if LocalSession.solo_poker:
		again.text = "Rejouer une table (cave %d)" % mini(LocalSession.solo_buy_in, _bank())
		again.disabled = _bank() < PokerLobby.TABLE_MIN_BANK
	if not LocalSession.solo and not LocalSession.solo_poker:
		var edit: Button = UIKit.outline_button("Modifier la partie", Color.WHITE, 16)
		edit.pressed.connect(_change.bind(LocalSession.SETUP_SCENE))
		col.add_child(edit)
	var home: Button = UIKit.outline_button("Accueil", UIKit.TEXT_SOFT, 16)
	home.pressed.connect(_change.bind(LocalSession.HOME_SCENE))
	col.add_child(home)
	UIKit.fade_in(self)


func _row(index: int, data: Dictionary) -> Control:
	var first: bool = index == 0
	var border: Color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.8) if first else Color(1, 1, 1, 0.1)
	var panel: PanelContainer = UIKit.panel(
		Color(0.06, 0.3, 0.17, 0.9) if first else Color(0, 0, 0, 0.3), 16, 12, border
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var medal_color: Color = [UIKit.GOLD, Color(0.78, 0.8, 0.85), Color(0.8, 0.5, 0.25)][mini(index, 2)] if index < 3 else Color(1, 1, 1, 0.15)
	var medal: PanelContainer = PanelContainer.new()
	medal.custom_minimum_size = Vector2(38, 38)
	medal.add_theme_stylebox_override("panel", UIKit.box(medal_color, 19))
	var rank: Label = UIKit.label(str(index + 1), 18, UIKit.INK if index < 3 else Color.WHITE, true)
	medal.add_child(rank)
	row.add_child(medal)

	var name_label: Label = UIKit.label(str(data["name"]), 19, Color.WHITE, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var right: VBoxContainer = VBoxContainer.new()
	if str(data.get("unit", "")) == "pts":
		var pts: Label = UIKit.label("%d pts" % int(data["stack"]), 19, UIKit.GOLD, true)
		right.add_child(pts)
		row.add_child(right)
		return panel
	var coins: CoinLabel = CoinLabel.new(17, UIKit.GOLD)
	coins.set_amount(int(data["stack"]))
	right.add_child(coins)
	var delta: int = int(data["stack"]) - int(data["start"])
	var delta_color: Color = UIKit.GREEN_ACTION if delta > 0 else (UIKit.WARNING_TEXT if delta < 0 else UIKit.TEXT_SOFT)
	right.add_child(UIKit.label(UIKit.signed(delta), 13, delta_color))
	row.add_child(right)
	return panel


func _bank() -> int:
	var b: Node = get_node_or_null("/root/Bankroll")
	return int(b.get("value")) if b != null else 0


func _change(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_change(LocalSession.HOME_SCENE)
