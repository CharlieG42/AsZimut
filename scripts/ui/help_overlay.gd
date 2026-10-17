class_name HelpOverlay
extends Control
## Fenêtre d'aide en jeu (bouton « ? ») : règles, classement des mains, mode débutant.

signal closed

const NODE_NAME: String = "HelpOverlay"

var topic: int = HelpContent.Topic.BLACKJACK


static func open(host: Control, help_topic: int) -> HelpOverlay:
	var existing: Node = host.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing as HelpOverlay
	var overlay: HelpOverlay = HelpOverlay.new()
	overlay.name = NODE_NAME
	overlay.topic = help_topic
	host.add_child(overlay)
	return overlay


static func is_open(host: Control) -> bool:
	return host.get_node_or_null(NODE_NAME) != null


static func close_in(host: Control) -> void:
	var existing: Node = host.get_node_or_null(NODE_NAME)
	if existing != null:
		(existing as HelpOverlay).close()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.8)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var panel: PanelContainer = UIKit.panel(Color(0.03, 0.14, 0.09, 0.98), 20, 14, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.35))
	margin.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = UIKit.label("Aide · %s" % HelpContent.title(topic), 20, UIKit.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	var x: Button = UIKit.outline_button("Fermer", UIKit.TEXT_SOFT, 14)
	x.custom_minimum_size = Vector2(90, 40)
	x.pressed.connect(close)
	head.add_child(x)
	col.add_child(head)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	HelpView.build(body, HelpContent.sections(topic), topic == HelpContent.Topic.POKER)

	# Accès à l'autoload par chemin : une classe nommée ne doit pas dépendre du global « Stats ».
	var stats: StatsState = get_node("/root/Stats") as StatsState
	var beginner: CheckBox = UIKit.check("Mode débutant (conseils pendant la partie)", stats.beginner)
	beginner.toggled.connect(stats.set_beginner)
	col.add_child(beginner)
	var done: Button = UIKit.button("Fermer l'aide", UIKit.GOLD, UIKit.INK, 18)
	done.pressed.connect(close)
	col.add_child(done)
	UIKit.fade_in(self, 0.15)


func close() -> void:
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	closed.emit()
	queue_free()
