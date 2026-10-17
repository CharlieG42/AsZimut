extends Control
## Accueil : choix du jeu et état de la banque.

const BLACKJACK_SCENE: String = "res://scenes/blackjack.tscn"
const POKER_SCENE: String = "res://scenes/poker.tscn"
const POKER_MIN_BANK: int = 20

var _bank: CoinLabel
var _reload_button: Button
var _poker_card: GameCard
var _poker_hint: Label
var _logo: Control
var _logo_cards: Array[CardView] = []


func _ready() -> void:
	add_child(UIKit.background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(UIKit.spacer(24))

	_logo = Control.new()
	_logo.custom_minimum_size = Vector2(0, 150)
	_logo.resized.connect(_layout_logo)
	col.add_child(_logo)
	var logo_specs: Array[Array] = [
		[14, Cards.Suit.SPADES],
		[14, Cards.Suit.HEARTS],
	]
	for spec: Array in logo_specs:
		var view: CardView = CardView.new(1.4)
		_logo.add_child(view)
		view.show_card(Cards.make(int(spec[0]), int(spec[1])), false)
		_logo_cards.append(view)

	col.add_child(UIKit.label("AsZimut", 46, UIKit.GOLD, true))
	col.add_child(UIKit.label("Blackjack & Poker contre l'IA — WildZimut", 14, UIKit.TEXT_SOFT))
	col.add_child(UIKit.spacer(4))

	var bank_row: HBoxContainer = HBoxContainer.new()
	bank_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bank_row)
	var pill: PanelContainer = UIKit.panel(
		Color(0.043, 0.231, 0.133), 22, 10, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.3)
	)
	bank_row.add_child(pill)
	_bank = CoinLabel.new(18, UIKit.GOLD, "Banque :")
	pill.add_child(_bank)

	_reload_button = UIKit.outline_button("Recharger la banque (1000)", UIKit.GOLD, 16)
	_reload_button.pressed.connect(func() -> void: Bankroll.reset())
	col.add_child(_reload_button)

	col.add_child(UIKit.spacer(10))

	var bj_icons: Array[int] = [Cards.make(14, Cards.Suit.SPADES), Cards.make(13, Cards.Suit.HEARTS)]
	var blackjack_card: GameCard = GameCard.new(
		"Blackjack", "Battez le croupier — blackjack payé 3:2, double autorisé.", bj_icons
	)
	blackjack_card.pressed.connect(_open.bind(BLACKJACK_SCENE))
	col.add_child(blackjack_card)

	var poker_icons: Array[int] = [Cards.make(14, Cards.Suit.HEARTS), Cards.make(14, Cards.Suit.DIAMONDS)]
	_poker_card = GameCard.new(
		"Poker Hold'em", "Heads-up contre ZIA (Monte-Carlo + Chen), blinds 10/20.", poker_icons
	)
	_poker_card.pressed.connect(_open.bind(POKER_SCENE))
	col.add_child(_poker_card)

	_poker_hint = UIKit.label(
		"Cave minimum : %d — rechargez la banque pour jouer au poker." % POKER_MIN_BANK,
		12,
		UIKit.WARNING_TEXT
	)
	_poker_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_poker_hint)

	Bankroll.changed.connect(_refresh)
	_refresh()


func _layout_logo() -> void:
	if _logo_cards.size() < 2:
		return
	var cx: float = _logo.size.x / 2.0
	var card_size: Vector2 = CardView.BASE_SIZE * 1.4
	_logo_cards[0].position = Vector2(cx - card_size.x * 0.95, 14)
	_logo_cards[0].rotation = -0.17
	_logo_cards[1].position = Vector2(cx - card_size.x * 0.05, 14)
	_logo_cards[1].rotation = 0.14


func _refresh() -> void:
	_bank.set_amount(Bankroll.value)
	_reload_button.visible = Bankroll.value < BlackjackEngine.MIN_BET
	var can_poker: bool = Bankroll.value >= POKER_MIN_BANK
	_poker_card.set_enabled(can_poker)
	_poker_hint.visible = not can_poker


func _open(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
