class_name SfxPlayer
extends Node
## Effets sonores synthétisés au démarrage (aucun fichier audio). Autoload « Sfx ».
## Depuis n'importe quel script : SfxPlayer.play("card").

const RATE: int = 22050
const VOICES: int = 6
const MIN_GAP_MS: int = 45

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Joue un son si l'option « Sons » est active. Sans autoload (tests), ne fait rien.
static func play(id: String, volume_db: float = 0.0) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var node: Node = tree.root.get_node_or_null("Sfx")
	if node == null:
		return
	(node as SfxPlayer)._play(id, volume_db)


func _ready() -> void:
	_rng.seed = 1234
	_streams["card"] = _make(_card)
	_streams["chip"] = _make(_chip)
	_streams["tap"] = _make(_tap)
	_streams["win"] = _make(_notes.bind([523.25, 659.25, 783.99, 1046.5], 0.085, 0.28))
	_streams["lose"] = _make(_notes.bind([392.0, 311.13], 0.17, 0.24))
	_streams["alert"] = _make(_notes.bind([880.0, 1174.66], 0.07, 0.2))
	for i: int in VOICES:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func has_sound(id: String) -> bool:
	return _streams.has(id)


func _enabled() -> bool:
	var stats: Node = get_node_or_null("/root/Stats")
	return stats == null or bool(stats.get("sound"))


func _play(id: String, volume_db: float) -> void:
	if not _streams.has(id) or not _enabled():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000)) < MIN_GAP_MS:
		return
	_last_played[id] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-0.04, 0.04) if id in ["card", "chip"] else 1.0
	p.play()


# --- Synthèse ------------------------------------------------------------------


func _make(gen: Callable) -> AudioStreamWAV:
	var samples: PackedFloat32Array = gen.call()
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Carte posée : souffle de bruit filtré, très bref.
func _card() -> PackedFloat32Array:
	var n: int = int(RATE * 0.06)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var noise: float = _rng.randf_range(-1.0, 1.0)
		lp += 0.35 * (noise - lp)
		var hp: float = lp - prev
		prev = lp
		var env: float = minf(1.0, t / 0.003) * exp(-t / 0.014)
		out[i] = (hp * 1.6 + lp * 0.4) * env * 0.45
	return out


## Jeton : deux petits « clac » métalliques.
func _chip() -> PackedFloat32Array:
	var n: int = int(RATE * 0.09)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var v: float = _click(t, 0.0, 1.0) + _click(t, 0.034, 0.55)
		out[i] = v * 0.32
	return out


func _click(t: float, start: float, amp: float) -> float:
	var u: float = t - start
	if u < 0.0:
		return 0.0
	var env: float = exp(-u / 0.009)
	return amp * env * (sin(TAU * 3150.0 * u) * 0.6 + sin(TAU * 4730.0 * u) * 0.4 + _rng.randf_range(-0.3, 0.3) * exp(-u / 0.002))


## Appui sur un bouton : clic doux.
func _tap() -> PackedFloat32Array:
	var n: int = int(RATE * 0.03)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		out[i] = sin(TAU * 1250.0 * t) * exp(-t / 0.006) * 0.16
	return out


## Suite de notes (triangle adouci).
func _notes(freqs: Array, note_len: float, amp: float) -> PackedFloat32Array:
	var per: int = int(RATE * note_len)
	var tail: int = int(RATE * 0.12)
	var n: int = per * freqs.size() + tail
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for k: int in freqs.size():
		var f: float = float(freqs[k])
		var start: int = k * per
		var length: int = per + tail
		for j: int in length:
			if start + j >= n:
				break
			var t: float = float(j) / RATE
			var phase: float = fmod(t * f, 1.0)
			var tri: float = 4.0 * absf(phase - 0.5) - 1.0
			var env: float = minf(1.0, t / 0.006) * exp(-t / (note_len * 1.4))
			out[start + j] += (tri * 0.6 + sin(TAU * f * t) * 0.4) * env * amp
	return out
