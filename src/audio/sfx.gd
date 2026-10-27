class_name Sfx
extends Node
## Plays SoundBank sounds from a small pool of players, and owns the volume and mute
## settings (saved to user://settings.cfg, applied to the Master bus). Call
## Sfx.play(&"click") from anywhere; the pool is created on first use.
## While idle it renders one not-yet-built sound per frame, so first plays don't hitch.

const VOICES := 14
const SETTINGS := "user://settings.cfg"

static var volume := 0.8
static var muted := false
static var _pool: Sfx
static var _loaded := false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _warm: Array = []


## volume_db: extra gain (negative = quieter). pitch: playback speed. gap: skip if the
## same sound played less than this many seconds ago (keeps spammy sounds tidy).
static func play(name: StringName, volume_db := 0.0, pitch := 1.0, gap := 0.0) -> void:
	if not SoundBank.has(name):
		return
	var pool := _get_pool()
	if pool == null:
		return
	pool._play(name, volume_db, pitch, gap)


## Creates the player pool now, so it starts rendering sounds in the background.
static func warm_up() -> void:
	_get_pool()


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


static func set_muted(on: bool) -> void:
	muted = on
	_apply()
	_save()


static func toggle_mute() -> void:
	set_muted(not muted)


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", muted))
	_apply()


static func _apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, muted or volume <= 0.001)


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS)


static func _get_pool() -> Sfx:
	if is_instance_valid(_pool):
		return _pool
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	load_settings()
	_pool = Sfx.new()
	_pool.name = "Sfx"
	tree.root.add_child.call_deferred(_pool)
	return _pool


func _init() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		_players.append(p)
		add_child(p)
	_warm = SoundBank.RECIPES.keys()


func _play(name: StringName, volume_db: float, pitch: float, gap: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if gap > 0.0 and now - float(_last_played.get(name, -10.0)) < gap:
		return
	_last_played[name] = now
	# Prefer a free voice; otherwise steal the oldest.
	var p: AudioStreamPlayer = null
	for i in VOICES:
		var cand := _players[(_next + i) % VOICES]
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _players[_next % VOICES]
	_next = (_players.find(p) + 1) % VOICES
	p.stream = SoundBank.get_stream(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if p.is_inside_tree():
		p.play()


func _process(_delta: float) -> void:
	while not _warm.is_empty():
		var name: StringName = _warm.pop_back()
		if not SoundBank.is_cached(name):
			SoundBank.get_stream(name)
			return
