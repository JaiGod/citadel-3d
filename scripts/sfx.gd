extends Node
## Autoload "Sfx": every sound is synthesized into an AudioStreamWAV at startup (no audio files).

const RATE := 22050
var sounds := {}
var players: Array = []
var idx := 0
var last := {}

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		add_child(p)
		players.append(p)
	sounds["click"] = _tone([[880, 0.03]], "sq", 0.2)
	sounds["place"] = _mix(_noise(0.12, 600.0, 0.5), _tone([[262, 0.05], [392, 0.08]], "tri", 0.4))
	sounds["upgrade"] = _tone([[523, 0.06], [659, 0.06], [784, 0.06], [1047, 0.12]], "sq", 0.22)
	sounds["sell"] = _tone([[784, 0.05], [523, 0.08]], "tri", 0.35)
	sounds["error"] = _tone([[180, 0.08], [140, 0.12]], "sq", 0.25)
	sounds["rifle"] = _noise(0.05, 3500.0, 0.25)
	sounds["cannon"] = _mix(_noise(0.22, 500.0, 0.6), _tone([[90, 0.18]], "sin", 0.5))
	sounds["mortar"] = _mix(_noise(0.15, 300.0, 0.5), _tone([[70, 0.15]], "sin", 0.5))
	sounds["boom"] = _mix(_noise(0.45, 350.0, 0.7), _tone([[60, 0.35]], "sin", 0.6))
	sounds["zap"] = _tone([[1400, 0.02], [700, 0.02], [1800, 0.02], [900, 0.04]], "saw", 0.18)
	sounds["frost"] = _tone([[1600, 0.04], [2100, 0.06]], "tri", 0.15)
	sounds["missile"] = _noise(0.25, 1200.0, 0.3)
	sounds["flame"] = _noise(0.2, 800.0, 0.22)
	sounds["rail"] = _mix(_tone([[220, 0.04], [1760, 0.12]], "saw", 0.22), _noise(0.15, 2500.0, 0.3))
	sounds["pop"] = _tone([[620, 0.03], [420, 0.05]], "sq", 0.15)
	sounds["coin"] = _tone([[988, 0.05], [1319, 0.1]], "sq", 0.18)
	sounds["leak"] = _tone([[330, 0.1], [220, 0.18]], "saw", 0.3)
	sounds["wave"] = _tone([[392, 0.1], [523, 0.1], [659, 0.18]], "sq", 0.2)
	sounds["boss"] = _mix(_tone([[110, 0.3], [82, 0.5]], "saw", 0.4), _noise(0.6, 200.0, 0.4))
	sounds["emp"] = _tone([[1200, 0.05], [600, 0.05], [300, 0.1], [150, 0.25]], "saw", 0.3)
	sounds["win"] = _tone([[523, 0.14], [659, 0.14], [784, 0.14], [1047, 0.5]], "tri", 0.45)
	sounds["lose"] = _tone([[392, 0.2], [330, 0.2], [262, 0.6]], "tri", 0.45)

func play(name: String, min_gap := 0.045) -> void:
	if not G.sound_on or not sounds.has(name) or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -1.0)) < min_gap:
		return
	last[name] = now
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = sounds[name]
	p.play()

func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _tone(notes: Array, wave: String, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n in notes:
		var f: float = n[0]
		var count := int(RATE * float(n[1]))
		for i in count:
			var t := float(i) / RATE
			var ph := fmod(t * f, 1.0)
			var s := 0.0
			match wave:
				"sq": s = 1.0 if ph < 0.5 else -1.0
				"saw": s = ph * 2.0 - 1.0
				"tri": s = 4.0 * absf(ph - 0.5) - 1.0
				_: s = sin(TAU * ph)
			var env: float = minf(1.0, i / 120.0) * (1.0 - float(i) / count)
			out.append(s * env * vol)
	return _wav(out)

func _noise(dur: float, cutoff: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(RATE * dur)
	var y := 0.0
	var a: float = clampf(cutoff / RATE * 6.0, 0.01, 1.0)
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	for i in count:
		y += (r.randf_range(-1, 1) - y) * a
		var env := pow(1.0 - float(i) / count, 2.0)
		out.append(y * env * vol * 2.5)
	return _wav(out)

func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var n: int = maxi(a.data.size(), b.data.size()) / 2
	var out := PackedFloat32Array()
	for i in n:
		var s := 0.0
		if i * 2 < a.data.size():
			s += a.data.decode_s16(i * 2) / 32000.0
		if i * 2 < b.data.size():
			s += b.data.decode_s16(i * 2) / 32000.0
		out.append(s * 0.7)
	return _wav(out)
