extends Node
## Tiny synthesized placeholder sounds, generated at startup. Autoloaded as `Sfx`.
## Replaced by real audio through the asset manifest in a later milestone.

const RATE := 22050
const VOICES := 12

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["tick"] = _make(0.05, 1.0, func(t: float, _n: float) -> float:
		return sin(t * TAU * 900.0) * exp(-t * 70.0))
	_streams["laser"] = _make(0.11, 1.0, func(t: float, _n: float) -> float:
		return sin(t * TAU * lerpf(1500.0, 420.0, t / 0.11)) * exp(-t * 28.0) * 0.6)
	_streams["gun"] = _make(0.06, 1.0, func(t: float, n: float) -> float:
		return (n * 0.7 + sin(t * TAU * 160.0) * 0.5) * exp(-t * 60.0) * 0.6)
	_streams["explosion"] = _make(0.45, 0.25, func(t: float, n: float) -> float:
		return (n + sin(t * TAU * 55.0)) * exp(-t * 9.0) * 0.7)
	_streams["shield"] = _make(0.14, 1.0, func(t: float, n: float) -> float:
		return (sin(t * TAU * 330.0) + sin(t * TAU * 495.0) * 0.5 + n * 0.2) * exp(-t * 26.0) * 0.5)
	_streams["hull"] = _make(0.2, 0.4, func(t: float, n: float) -> float:
		return (n + sin(t * TAU * 90.0)) * exp(-t * 20.0) * 0.8)
	_streams["particle"] = _make(0.09, 1.0, func(t: float, n: float) -> float:
		return (sin(t * TAU * lerpf(900.0, 1800.0, t / 0.09)) * 0.5 + n * 0.25) * exp(-t * 35.0))
	_streams["beam"] = _make(0.14, 1.0, func(t: float, n: float) -> float:
		return (sin(t * TAU * 220.0) * 0.5 + sin(t * TAU * 331.0) * 0.3 + n * 0.1) * sin(t / 0.14 * PI))
	_streams["rail"] = _make(0.35, 1.0, func(t: float, n: float) -> float:
		return (n * exp(-t * 40.0) + sin(t * TAU * lerpf(2400.0, 300.0, minf(t / 0.08, 1.0))) * exp(-t * 12.0)) * 0.7)
	_streams["cannon"] = _make(0.22, 0.3, func(t: float, n: float) -> float:
		return (n * 0.8 + sin(t * TAU * 70.0)) * exp(-t * 22.0))
	_streams["missile"] = _make(0.3, 0.5, func(t: float, n: float) -> float:
		return n * (1.0 - exp(-t * 60.0)) * exp(-t * 9.0) * 0.8)
	_streams["empty"] = _make(0.08, 1.0, func(t: float, _n: float) -> float:
		return signf(sin(t * TAU * 180.0)) * 0.3 * exp(-t * 30.0))
	_streams["shockwave"] = _make(0.9, 0.2, func(t: float, n: float) -> float:
		return (n + sin(t * TAU * lerpf(90.0, 30.0, t))) * exp(-t * 4.0) * 0.9)
	_streams["buy"] = _make(0.18, 1.0, func(t: float, _n: float) -> float:
		var f := 880.0 if t < 0.07 else 1320.0
		return sin(t * TAU * f) * exp(-fmod(t, 0.07) * 25.0) * 0.5)


## Builds a 16-bit mono sample from f(time, white_noise). `lowpass` < 1 smooths the result.
func _make(length: float, lowpass: float, f: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	var prev := 0.0
	for i in n:
		var s: float = f.call(float(i) / RATE, rng.randf_range(-1.0, 1.0))
		prev = lerpf(prev, s, lowpass)
		bytes.encode_s16(i * 2, int(clampf(prev, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


## Plays a sound. `min_gap` (seconds) throttles rapid repeats of the same sound.
func play(id: String, volume: float = 1.0, pitch: float = 1.0, min_gap: float = 0.0) -> void:
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last_play.get(id, -10.0)) < min_gap:
		return
	_last_play[id] = now
	var v: float = volume * float(Settings.values["volume_master"]) * float(Settings.values["volume_sfx"])
	if v <= 0.001:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[id]
	p.volume_db = linear_to_db(v)
	p.pitch_scale = pitch
	p.play()


## Plays a sound by asset id (see data/assets.json): a synthesized placeholder or a loaded file.
func play_asset(id: String, volume: float = 1.0, pitch: float = 1.0, min_gap: float = 0.0) -> void:
	if _players.is_empty():
		return
	var entry := Assets.sound(id)
	if entry[0] == null:
		return
	if entry[0] is String:
		play(entry[0], volume * float(entry[1]), pitch, min_gap)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last_play.get(id, -10.0)) < min_gap:
		return
	_last_play[id] = now
	var v: float = volume * float(entry[1]) * float(Settings.values["volume_master"]) * float(Settings.values["volume_sfx"])
	if v <= 0.001:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = entry[0]
	p.volume_db = linear_to_db(v)
	p.pitch_scale = pitch
	p.play()
