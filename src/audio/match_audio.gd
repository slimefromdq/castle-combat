class_name MatchAudio
extends Node
## Turns sim events into sounds. Your own hero's sounds play at full volume; everything
## else fades with distance from your hero and goes silent off-screen, so a busy lane
## never turns into noise. Spammy sounds (trooper hits, coins, zaps) are rate-limited.

const HEARING := 18.0
const FALLOFF_DB := 1.1

## Basic-attack sound per hero shape.
const ATTACK := {
	"paladin": &"heavy_swing", "gunslinger": &"gunshot", "thief": &"swing", "sailor": &"heavy_swing",
	"hunter": &"swing", "swarm": &"buzz", "doll": &"swing", "emperor": &"zap",
	"serpent": &"dart", "conductor": &"baton", "kosmonaut": &"zap",
}
## One-off sounds for events that need no special handling: event -> [sound, gap].
const SIMPLE := {
	&"basic_crit": [&"crit", 0.0], &"hooked": [&"hook", 0.0], &"reeled": [&"hook", 0.0],
	&"flung": [&"thud", 0.0], &"trap_set": [&"click", 0.0], &"trap_sprung": [&"snap", 0.0],
	&"teleported": [&"teleport", 0.0], &"scattered": [&"teleport", 0.0],
	&"shield_blocked": [&"shield", 0.1], &"shield_shattered": [&"shatter", 0.0],
	&"judgment_struck": [&"judgment", 0.0], &"vanish_burst": [&"vanish", 0.0],
	&"whale_breach": [&"whale", 0.0], &"rule_started": [&"debt", 0.0], &"rule_landed": [&"slam", 0.0],
	&"latched": [&"swarm", 0.0], &"engulfed": [&"swarm", 0.0], &"buzz": [&"buzz", 0.25],
	&"snip": [&"snip", 0.1], &"threaded": [&"thread", 0.0], &"ribbons": [&"thread", 0.0],
	&"thread_snapped": [&"snap", 0.0], &"storm_strike": [&"zap", 0.05], &"volley": [&"gunshot", 0.0],
	&"head_spin": [&"heavy_swing", 0.0], &"overwhelm": [&"thud", 0.0],
	&"venom_pop": [&"venom_pop", 0.0], &"venom_fizzled": [&"hiss", 0.0], &"skin_shed": [&"hiss", 0.0],
	&"snake_pit": [&"hiss", 0.0], &"viper_bite": [&"viper", 0.12],
	&"brass_blast": [&"brass_blast", 0.0], &"strings_pulse": [&"pizz", 0.0], &"finale_wave": [&"drum", 0.0],
	&"final_note": [&"final_note", 0.0],
	&"drone_launched": [&"drone_launch", 0.0], &"drone_recalled": [&"drone_recall", 0.0],
	&"drone_zap": [&"drone_zap", 0.1], &"drone_pulse": [&"drone_pulse", 0.0],
	&"reentry_started": [&"reentry_whistle", 0.0], &"reentry_landed": [&"boom", 0.0],
	&"pickup_taken": [&"candle_taken", 0.08],
	&"guardian_slam_windup": [&"slam_windup", 0.0], &"guardian_slam": [&"slam", 0.0],
	&"core_stun_windup": [&"slam_windup", 0.0], &"core_stun": [&"immune", 0.0],
	&"core_immune": [&"immune", 0.0], &"siege_spawned": [&"wave", 0.0],
}

var sim: MatchSim
var seat := MatchSim.BLUE
var _last_hp := -1.0


func setup(match_sim: MatchSim, local_seat: int) -> void:
	sim = match_sim
	seat = local_seat
	sim.sim_event.connect(on_sim_event)


## Returns [sound, volume_db] for an event, or [] for silence. Pure, so tests can call it.
func sound_for(type: StringName, data: Dictionary) -> Array:
	var me := sim.heroes[seat]
	match type:
		&"attack_fired":
			var a = sim.get_entity(data.attacker)
			if a is HeroState:
				return [ATTACK.get(a.data.shape, &"swing"), _db_at(a.pos, a == me or data.target == me.id), 0.0]
			if a is StructureState:
				return [&"tower_shot", _db_at(a.pos, data.target == me.id) - 3.0, 0.05]
			if a != null:
				return [&"trooper_hit", _db_at(a.pos, false) - 6.0, 0.07]
		&"ability_cast":
			var h := sim.get_entity(data.hero) as HeroState
			if h == null:
				return []
			var name: StringName = [&"cast_q", &"cast_e", &"ult"][clampi(data.slot, 0, 2)]
			if data.get("ability", &"") == &"grand_finale":
				name = &"finale"  # Fermata's ult is a chord, not the generic boom.
			return [name, _db_at(h.pos, h == me), 0.0]
		&"instrument":
			var kind: StringName = data.get("kind", &"")
			return [&"brass" if kind == &"brass" else (&"strings" if kind == &"strings" else &"drum"), _db_at(data.pos, data.hero == me.id), 0.0]
		&"unit_killed":
			var victim = sim.get_entity(data.id)
			if victim is StructureState:
				return [&"crumble", _db_at(victim.pos, false) + 3.0, 0.0]
			if victim is HeroState:
				if victim == me:
					return [&"death", 0.0, 0.0]
				if data.killer_team == seat:
					return [&"kill", 0.0, 0.0]
		&"level_up":
			if data.team == seat:
				return [&"level_up", 0.0, 0.0]
		&"perk_picked":
			if data.team == seat:
				return [&"perk", 0.0, 0.0]
		&"item_bought", &"masterwork", &"siege_scroll":
			if data.team == seat:
				return [&"buy", 0.0, 0.0]
		&"item_sold":
			if data.team == seat:
				return [&"sell", 0.0, 0.0]
		&"gold_awarded":
			if data.team == seat:
				return [&"coin", -4.0, 0.06]
		&"minion_denied":
			if data.team == seat:
				return [&"denied", -2.0, 0.1]
		&"hero_healed":
			if data.team == seat:
				return [&"heal", -6.0, 0.6]
		&"hero_respawned":
			if data.team == seat:
				return [&"respawn", 0.0, 0.0]
		&"relay_spawned":
			return [&"relay_spawn", -2.0, 0.0]
		&"relay_warning":
			return [&"relay_warn", -4.0, 0.0]
		&"relay_picked_up":
			return [&"relay_pick", 0.0 if data.team == seat else -3.0, 0.0]
		&"relay_dropped", &"relay_returned":
			return [&"relay_drop", -2.0, 0.0]
		&"relay_delivered":
			return [&"relay_deliver" if data.team == seat else &"relay_drop", 0.0, 0.0]
		&"overtime_started":
			return [&"overtime", 0.0, 0.0]
		_:
			if SIMPLE.has(type):
				var s: Array = SIMPLE[type]
				var mine: bool = data.get("hero", -1) == me.id or data.get("target", -1) == me.id
				return [s[0], _db_at(_where(data), mine), s[1]]
	return []


func on_sim_event(type: StringName, data: Dictionary) -> void:
	var s := sound_for(type, data)
	if s.is_empty() or s[1] <= -80.0:
		return
	Sfx.play(s[0], s[1], randf_range(0.96, 1.04), s[2])


## Your hero getting hit by the enemy hero gets its own thump.
func _process(_delta: float) -> void:
	if sim == null:
		return
	var me := sim.heroes[seat]
	if _last_hp >= 0.0 and me.alive and me.hp < _last_hp - 1.0 and sim.time - me.last_hero_damage_time < 0.1:
		Sfx.play(&"hurt", -2.0, randf_range(0.95, 1.05), 0.25)
	_last_hp = me.hp


## Where an event happened: its position, or the hero/target it names.
func _where(data: Dictionary) -> Variant:
	for key in ["pos", "to", "from"]:
		if data.has(key) and data[key] is Vector2:
			return data[key]
	for key in ["hero", "target", "id", "attacker"]:
		if data.has(key):
			var e := sim.get_entity(data[key])
			if e != null:
				return e.pos
	return null


## Full volume for your own fights; otherwise quieter with distance, silent far away.
func _db_at(where: Variant, mine: bool) -> float:
	if mine or where == null:
		return 0.0
	var d: float = (where as Vector2).distance_to(sim.heroes[seat].pos)
	if d > HEARING:
		return -100.0
	return -d * FALLOFF_DB
