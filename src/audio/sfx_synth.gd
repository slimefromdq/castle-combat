class_name SfxSynth
## Builds sound effects in code: no audio files ship with the game. A recipe is a list
## of layers; each layer is one oscillator with a pitch slide, an envelope, an optional
## arpeggio, vibrato and a simple low-pass filter. Layers are mixed, soft-limited and
## turned into a 16-bit AudioStreamWAV.
##
## Layer keys (all optional except wave and f):
##   wave: "sine" | "tri" | "square" | "saw" | "noise"
##   f: start frequency (Hz); f1: end frequency (exponential slide)
##   dur: seconds; delay: start offset; vol: 0..1
##   attack: seconds; curve: decay exponent (higher = snappier)
##   notes: semitone offsets played in turn, step: seconds per note
##   vib: vibrato depth (fraction of pitch), vib_rate: Hz
##   lp: low-pass amount 0..1 (1 = open); lp1: end value (filter sweep)
##   duty: square pulse width

const RATE := 22050


static func render(layers: Array) -> AudioStreamWAV:
	var length := 0.0
	for l: Dictionary in layers:
		length = maxf(length, l.get("delay", 0.0) + l.get("dur", 0.3))
	var n := int(length * RATE) + 1
	var mix := PackedFloat32Array()
	mix.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for l: Dictionary in layers:
		_layer(mix, l, rng)
	# Soft limiter so stacked layers never clip.
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := tanh(mix[i] * 1.2) * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _layer(mix: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var wave: String = l.get("wave", "sine")
	var f0: float = l.get("f", 440.0)
	var f1: float = l.get("f1", f0)
	var dur: float = l.get("dur", 0.3)
	var start := int(l.get("delay", 0.0) * RATE)
	var vol: float = l.get("vol", 0.5)
	var attack: float = maxf(l.get("attack", 0.005), 0.001)
	var curve: float = l.get("curve", 2.0)
	var notes: Array = l.get("notes", [])
	var step: float = l.get("step", 0.08)
	var vib: float = l.get("vib", 0.0)
	var vib_rate: float = l.get("vib_rate", 6.0)
	var lp0: float = l.get("lp", 1.0)
	var lp1: float = l.get("lp1", lp0)
	var duty: float = l.get("duty", 0.5)
	var count := int(dur * RATE)
	var phase := 0.0
	var y := 0.0
	var held := 0.0
	var hold_phase := 1.0
	for i in count:
		var idx := start + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		if not notes.is_empty():
			f *= pow(2.0, float(notes[mini(int(t / step), notes.size() - 1)]) / 12.0)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * vib_rate * t)
		phase = fmod(phase + f / RATE, 1.0)
		var x := 0.0
		match wave:
			"sine":
				x = sin(TAU * phase)
			"tri":
				x = 4.0 * absf(phase - 0.5) - 1.0
			"square":
				x = 1.0 if phase < duty else -1.0
			"saw":
				x = 2.0 * phase - 1.0
			"noise":
				# Sample-and-hold noise: f sets how "grainy" it is.
				hold_phase += f / RATE
				if hold_phase >= 1.0:
					hold_phase = fmod(hold_phase, 1.0)
					held = rng.randf_range(-1.0, 1.0)
				x = held
		var env := t / attack if t < attack else pow(maxf(0.0, 1.0 - (t - attack) / maxf(dur - attack, 0.001)), curve)
		var lp := lerpf(lp0, lp1, k)
		y += clampf(lp, 0.001, 1.0) * (x - y)
		mix[idx] += y * env * vol
