class_name PokerLobby
extends Control
## Choix de la table de poker solo : face-à-face ou table à plusieurs ZIA.

const HEADS_UP_SCENE: String = "res://scenes/poker.tscn"
const TABLE_MIN_BANK: int = 100
const MAX_BUY_IN: int = 1000


static func open(host: Control) -> PokerLobby:
	var lobby: PokerLobby = PokerLobby.new()
	lobby.name = "PokerLobby"
	host.add_child(lobby)
	return lobby


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = UIKit.panel(
		Color(0.03, 0.14, 0.09, 0.98), 20, 18, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.4)
	)
	panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	col.add_child(UIKit.label("Poker Hold'em", 24, UIKit.GOLD, true))
	var bank: int = _bank()
	var buy_in: int = mini(bank, MAX_BUY_IN)

	var heads: Button = UIKit.button("Face-à-face contre ZIA", UIKit.GOLD, UIKit.INK, 18)
	heads.pressed.connect(_heads_up)
	col.add_child(heads)
	var heads_note: Label = UIKit.label("Toute votre banque est en jeu, blinds 10/20.", 12, UIKit.TEXT_SOFT)
	col.add_child(heads_note)

	col.add_child(UIKit.spacer(4))
	for players: int in [4, 6]:
		var b: Button = UIKit.button(
			"Table à %d · %d ZIA" % [players, players - 1], Color(0.16, 0.36, 0.28), Color.WHITE, 18
		)
		b.disabled = bank < TABLE_MIN_BANK
		b.pressed.connect(_table.bind(players, buy_in))
		col.add_child(b)
	var note: Label = UIKit.label(
		(
			"Cave de %d prise sur votre banque, blinds croissantes, jusqu'à ce qu'il ne reste qu'un joueur." % buy_in
			if bank >= TABLE_MIN_BANK
			else "Il faut au moins %d jetons pour une table à plusieurs." % TABLE_MIN_BANK
		),
		12,
		UIKit.TEXT_SOFT if bank >= TABLE_MIN_BANK else UIKit.WARNING_TEXT
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)

	var cancel: Button = UIKit.outline_button("Annuler", UIKit.TEXT_SOFT, 16)
	cancel.pressed.connect(close)
	col.add_child(cancel)
	UIKit.fade_in(self, 0.15)


func _bank() -> int:
	var b: Node = get_node_or_null("/root/Bankroll")
	return int(b.get("value")) if b != null else 0


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()


func _heads_up() -> void:
	get_tree().change_scene_to_file(HEADS_UP_SCENE)


func _table(players: int, buy_in: int) -> void:
	GameSave.clear()
	LocalSession.start_solo_poker(players, buy_in)
	get_tree().change_scene_to_file(LocalSession.scene(LocalSession.Game.POKER))


func close() -> void:
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()
