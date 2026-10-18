class_name TouchScroll
extends ScrollContainer
## Défilement vertical pensé pour le doigt :
## - on peut faire glisser la page en partant de n'importe où (bouton, case, cadre, texte) ;
## - un glisser n'active jamais le bouton sur lequel il a commencé ;
## - la page continue sur son élan après un lancer (inertie), un appui l'arrête ;
## - un simple appui reste un clic normal (rejoué sur l'élément touché).
## La molette de la souris fonctionne comme avant.

## Distance (px) au-delà de laquelle un appui devient un glisser.
const DEADZONE: float = 10.0
## Freinage de l'inertie (par seconde, exponentiel).
const FRICTION: float = 3.5
const MIN_SPEED: float = 40.0
const MAX_SPEED: float = 5000.0
## Fenêtre (s) servant à mesurer la vitesse du doigt au lâcher.
const SAMPLE_WINDOW: float = 0.1

var _tracking: bool = false
var _dragging: bool = false
var _stopped_fling: bool = false
var _start: Vector2 = Vector2.ZERO
var _start_scroll: float = 0.0
var _scroll_f: float = 0.0
var _velocity: float = 0.0
var _samples: Array[Vector2] = []  # (temps, y)
var _replaying: bool = false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_process(false)


func _ready() -> void:
	# Barre de défilement fine, simple indicateur de position (pas une poignée à attraper).
	var bar: VScrollBar = get_v_scroll_bar()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track: StyleBoxEmpty = StyleBoxEmpty.new()
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab: StyleBoxFlat = StyleBoxFlat.new()
	grab.bg_color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.45)
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)


## Revient en haut (ou à `value`) en arrêtant l'élan.
func jump_to(value: int = 0) -> void:
	_velocity = 0.0
	set_process(false)
	scroll_vertical = value


func is_dragging() -> bool:
	return _dragging


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _inside(pos: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(pos)


func _input(event: InputEvent) -> void:
	if _replaying or not is_visible_in_tree():
		return
	# Événements tactiles bruts : la souris émulée (générée par Godot à partir du toucher) suffit.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var touch_pos: Vector2 = event.get("position")
		if _tracking or _inside(touch_pos):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if not _inside(mb.position):
				return
			_stopped_fling = absf(_velocity) >= MIN_SPEED and is_processing()
			_velocity = 0.0
			set_process(false)
			_tracking = true
			_dragging = false
			_start = mb.position
			_start_scroll = float(scroll_vertical)
			_samples = [Vector2(_now(), mb.position.y)]
			get_viewport().set_input_as_handled()
		elif _tracking:
			_tracking = false
			get_viewport().set_input_as_handled()
			if _dragging:
				_dragging = false
				_launch()
			elif not _stopped_fling:
				_replay_click.call_deferred(mb.position)
		return
	if event is InputEventMouseMotion and _tracking:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		get_viewport().set_input_as_handled()
		if not _dragging and absf(mm.position.y - _start.y) > DEADZONE:
			_dragging = true
			_start = mm.position
			_start_scroll = float(scroll_vertical)
		if _dragging:
			_scroll_f = _start_scroll - (mm.position.y - _start.y)
			scroll_vertical = roundi(_scroll_f)
			var t: float = _now()
			_samples.append(Vector2(t, mm.position.y))
			while _samples.size() > 2 and t - _samples[0].x > SAMPLE_WINDOW:
				_samples.pop_front()


## Vitesse du doigt sur les derniers instants → élan de la page.
func _launch() -> void:
	if _samples.size() < 2:
		return
	var first: Vector2 = _samples[0]
	var last: Vector2 = _samples[_samples.size() - 1]
	var dt: float = last.x - first.x
	if dt <= 0.0 or _now() - last.x > 0.08:
		return
	_velocity = clampf(-(last.y - first.y) / dt, -MAX_SPEED, MAX_SPEED)
	_scroll_f = float(scroll_vertical)
	if absf(_velocity) >= MIN_SPEED:
		set_process(true)


func _process(delta: float) -> void:
	if absf(_velocity) < MIN_SPEED:
		_velocity = 0.0
		set_process(false)
		return
	_scroll_f += _velocity * delta
	var before: int = scroll_vertical
	scroll_vertical = roundi(_scroll_f)
	if scroll_vertical == before and absf(_velocity * delta) >= 1.0:
		# Butée haute ou basse atteinte.
		_velocity = 0.0
		set_process(false)
		return
	_velocity *= exp(-FRICTION * delta)


## Un appui sans glisser : on rejoue le clic pour l'élément situé sous le doigt.
func _replay_click(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	_replaying = true
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = pos
	press.global_position = pos
	get_viewport().push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	get_viewport().push_input(release, true)
	_replaying = false
