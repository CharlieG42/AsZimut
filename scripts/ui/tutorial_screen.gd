class_name TutorialScreen
extends Control
## Tutoriel : quelques pages pour découvrir les règles. Affiché au démarrage tant que
## l'option « Ne plus afficher » n'est pas cochée ; relançable depuis Options.

const HOME_SCENE: String = "res://scenes/home.tscn"
const TUTORIAL_SCENE: String = "res://scenes/tutorial.tscn"

## Écran vers lequel revenir à la fin (accueil par défaut, Options si relancé de là).
static var return_scene: String = HOME_SCENE

var _pages: Array[Dictionary] = []
var _index: int = 0
var _dots: HBoxContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _prev: Button
var _next: Button


func _ready() -> void:
	_pages = HelpContent.tutorial_pages()
	add_child(UIKit.background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_dots)
	var skip: Button = UIKit.outline_button("Passer", UIKit.TEXT_SOFT, 14)
	skip.custom_minimum_size = Vector2(90, 40)
	skip.pressed.connect(_finish)
	top.add_child(skip)
	col.add_child(top)

	_title = UIKit.label("", 28, UIKit.GOLD, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)

	var hide_check: CheckBox = UIKit.check("Ne plus afficher au démarrage", not _stats().show_tutorial)
	hide_check.toggled.connect(func(on: bool) -> void: _stats().set_show_tutorial(not on))
	col.add_child(hide_check)

	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	_prev = UIKit.outline_button("Précédent", Color.WHITE, 17)
	_prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prev.pressed.connect(_go.bind(-1))
	nav.add_child(_prev)
	_next = UIKit.button("Suivant", UIKit.GOLD, UIKit.INK, 18)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_go.bind(1))
	nav.add_child(_next)
	col.add_child(nav)

	_render()
	UIKit.fade_in(self)


func _render() -> void:
	var page: Dictionary = _pages[_index]
	_title.text = str(page["title"])
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var sections: Array[Dictionary] = []
	for section: Dictionary in page["sections"]:
		sections.append(section)
	HelpView.build(_body, sections, bool(page["hands"]))
	if bool(page["beginner"]):
		var beginner: CheckBox = UIKit.check(
			"Activer le mode débutant (conseils pendant la partie)", _stats().beginner
		)
		beginner.toggled.connect(_stats().set_beginner)
		_body.add_child(beginner)
	_scroll.scroll_vertical = 0

	for child: Node in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for i: int in _pages.size():
		var dot: PanelContainer = PanelContainer.new()
		dot.custom_minimum_size = Vector2(10, 10)
		var active: Color = UIKit.GOLD if i == _index else Color(1, 1, 1, 0.22)
		dot.add_theme_stylebox_override("panel", UIKit.box(active, 5))
		_dots.add_child(dot)

	_prev.visible = _index > 0
	_next.text = "Commencer" if _index == _pages.size() - 1 else "Suivant"


func _stats() -> StatsState:
	return get_node("/root/Stats") as StatsState


func _go(delta: int) -> void:
	var target: int = _index + delta
	if target >= _pages.size():
		_finish()
		return
	_index = clampi(target, 0, _pages.size() - 1)
	_render()


func _finish() -> void:
	var target: String = return_scene
	return_scene = HOME_SCENE
	get_tree().change_scene_to_file(target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _index > 0:
			_go(-1)
		else:
			_finish()
