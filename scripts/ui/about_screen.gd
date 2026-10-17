extends Control
## Écran « À propos » : version de l'appli (0.0.01.PR.PUSH, injectée par la CI) et crédits.

const HOME_SCENE: String = "res://scenes/home.tscn"


func _ready() -> void:
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var bar: HBoxContainer = HBoxContainer.new()
	var back: Button = UIKit.outline_button("‹ Accueil", UIKit.TEXT_SOFT, 15)
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(_go_home)
	bar.add_child(back)
	var title: Label = UIKit.label("À propos", 21, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	bar.add_child(pad)
	col.add_child(bar)

	col.add_child(UIKit.spacer(24))
	col.add_child(UIKit.label("AsZimut", 38, UIKit.GOLD, true))
	col.add_child(UIKit.label("Jeux de cartes hors ligne", 14, UIKit.TEXT_SOFT))
	col.add_child(UIKit.spacer(16))

	var panel: PanelContainer = UIKit.panel(Color(0, 0, 0, 0.3), 16, 16, Color(1, 1, 1, 0.08))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UIKit.label("VERSION", 12, UIKit.GOLD, true))
	box.add_child(UIKit.label(AppInfo.version(), 26, Color.WHITE, true))
	var detail: Label = UIKit.label(
		"Dernière PR fusionnée : %s\nNuméro de push : %s" % [AppInfo.pr_text(), AppInfo.push_text()],
		13,
		UIKit.TEXT_SOFT
	)
	box.add_child(detail)
	col.add_child(panel)

	var games: Label = UIKit.label(
		"Blackjack · Poker Hold'em · Dutch\nMultijoueur local sur un seul appareil, avec ZIA.", 13, UIKit.TEXT_SOFT
	)
	games.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(games)
	UIKit.fade_in(self)


func _go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
