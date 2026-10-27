class_name SoundBank
## Every sound in the game, as SfxSynth recipes. Rendered on first use and cached.
## Keep them short and bright: the street is colourful, so is the sound.

static var _cache := {}

const RECIPES := {
	# --- UI ---------------------------------------------------------------------
	&"click": [{"wave": "tri", "f": 1400.0, "f1": 900.0, "dur": 0.05, "vol": 0.35, "curve": 3.0}],
	&"coin": [{"wave": "square", "f": 1318.0, "dur": 0.06, "vol": 0.18, "duty": 0.25}, {"wave": "square", "f": 1760.0, "delay": 0.05, "dur": 0.12, "vol": 0.18, "duty": 0.25, "curve": 2.5}],
	&"buy": [{"wave": "square", "f": 988.0, "dur": 0.07, "vol": 0.2, "duty": 0.25}, {"wave": "square", "f": 1318.0, "delay": 0.06, "dur": 0.07, "vol": 0.2, "duty": 0.25}, {"wave": "tri", "f": 1976.0, "delay": 0.12, "dur": 0.25, "vol": 0.3, "curve": 2.0}],
	&"sell": [{"wave": "square", "f": 1318.0, "f1": 660.0, "dur": 0.16, "vol": 0.18, "duty": 0.25}],
	&"perk": [{"wave": "sine", "f": 660.0, "f1": 990.0, "dur": 0.18, "vol": 0.4}, {"wave": "tri", "f": 1320.0, "delay": 0.08, "dur": 0.25, "vol": 0.2}],
	&"level_up": [{"wave": "tri", "f": 523.0, "notes": [0, 4, 7, 12], "step": 0.07, "dur": 0.42, "vol": 0.45, "curve": 1.2}, {"wave": "square", "f": 1046.0, "notes": [0, 4, 7, 12], "step": 0.07, "dur": 0.42, "vol": 0.08, "duty": 0.25, "curve": 1.2}],
	&"denied": [{"wave": "square", "f": 220.0, "f1": 180.0, "dur": 0.12, "vol": 0.15, "lp": 0.3}],
	# --- Basic attacks ------------------------------------------------------------
	&"swing": [{"wave": "noise", "f": 9000.0, "dur": 0.16, "vol": 0.35, "attack": 0.04, "lp": 0.08, "lp1": 0.35, "curve": 2.0}],
	&"heavy_swing": [{"wave": "noise", "f": 7000.0, "dur": 0.22, "vol": 0.45, "attack": 0.06, "lp": 0.05, "lp1": 0.25}, {"wave": "sine", "f": 120.0, "f1": 70.0, "delay": 0.12, "dur": 0.12, "vol": 0.4}],
	&"gunshot": [{"wave": "noise", "f": 12000.0, "dur": 0.12, "vol": 0.55, "lp": 0.6, "lp1": 0.1, "curve": 4.0}, {"wave": "square", "f": 260.0, "f1": 80.0, "dur": 0.1, "vol": 0.25, "lp": 0.3}],
	&"dart": [{"wave": "noise", "f": 11000.0, "dur": 0.08, "vol": 0.3, "lp": 0.5, "curve": 3.0}, {"wave": "sine", "f": 1800.0, "f1": 1200.0, "dur": 0.07, "vol": 0.15}],
	&"zap": [{"wave": "saw", "f": 880.0, "f1": 1760.0, "dur": 0.1, "vol": 0.22, "lp": 0.4, "vib": 0.08, "vib_rate": 60.0}],
	&"baton": [{"wave": "tri", "f": 1568.0, "f1": 1480.0, "dur": 0.16, "vol": 0.3, "curve": 3.0}, {"wave": "noise", "f": 9000.0, "dur": 0.05, "vol": 0.1, "lp": 0.4}],
	&"buzz": [{"wave": "saw", "f": 180.0, "dur": 0.18, "vol": 0.18, "lp": 0.3, "vib": 0.15, "vib_rate": 35.0}],
	&"trooper_hit": [{"wave": "noise", "f": 5000.0, "dur": 0.05, "vol": 0.12, "lp": 0.25, "curve": 3.0}],
	&"tower_shot": [{"wave": "sine", "f": 600.0, "f1": 220.0, "dur": 0.14, "vol": 0.25}, {"wave": "noise", "f": 8000.0, "dur": 0.06, "vol": 0.12, "lp": 0.3}],
	&"crit": [{"wave": "tri", "f": 2093.0, "dur": 0.2, "vol": 0.3, "curve": 2.5}, {"wave": "noise", "f": 12000.0, "dur": 0.06, "vol": 0.2, "lp": 0.7}],
	&"hurt": [{"wave": "sine", "f": 160.0, "f1": 70.0, "dur": 0.16, "vol": 0.45}, {"wave": "noise", "f": 4000.0, "dur": 0.08, "vol": 0.2, "lp": 0.2}],
	# --- Casts --------------------------------------------------------------------
	&"cast_q": [{"wave": "noise", "f": 10000.0, "dur": 0.2, "vol": 0.3, "attack": 0.05, "lp": 0.05, "lp1": 0.5}, {"wave": "tri", "f": 440.0, "f1": 880.0, "dur": 0.16, "vol": 0.2}],
	&"cast_e": [{"wave": "sine", "f": 660.0, "notes": [0, 7, 12], "step": 0.05, "dur": 0.22, "vol": 0.25}, {"wave": "noise", "f": 10000.0, "dur": 0.2, "vol": 0.15, "lp": 0.15}],
	&"ult": [{"wave": "sine", "f": 90.0, "f1": 45.0, "dur": 0.7, "vol": 0.6, "curve": 1.5}, {"wave": "saw", "f": 220.0, "f1": 440.0, "dur": 0.55, "vol": 0.18, "lp": 0.08, "lp1": 0.4, "attack": 0.1}, {"wave": "saw", "f": 277.0, "f1": 554.0, "dur": 0.55, "vol": 0.14, "lp": 0.08, "lp1": 0.4, "attack": 0.1}, {"wave": "noise", "f": 6000.0, "dur": 0.4, "vol": 0.2, "lp": 0.1, "attack": 0.02}],
	&"hook": [{"wave": "square", "f": 300.0, "f1": 900.0, "dur": 0.2, "vol": 0.12, "duty": 0.2, "vib": 0.3, "vib_rate": 40.0}, {"wave": "noise", "f": 3000.0, "dur": 0.2, "vol": 0.2, "lp": 0.4}],
	&"thud": [{"wave": "sine", "f": 110.0, "f1": 50.0, "dur": 0.25, "vol": 0.55}, {"wave": "noise", "f": 2500.0, "dur": 0.12, "vol": 0.25, "lp": 0.15}],
	&"snap": [{"wave": "noise", "f": 14000.0, "dur": 0.06, "vol": 0.5, "lp": 0.9, "curve": 5.0}, {"wave": "square", "f": 1200.0, "f1": 400.0, "dur": 0.08, "vol": 0.15}],
	&"teleport": [{"wave": "sine", "f": 300.0, "f1": 1600.0, "dur": 0.22, "vol": 0.3, "vib": 0.05, "vib_rate": 20.0}],
	&"shield": [{"wave": "tri", "f": 1046.0, "dur": 0.3, "vol": 0.25, "vib": 0.02, "vib_rate": 9.0}, {"wave": "tri", "f": 1568.0, "dur": 0.3, "vol": 0.15}],
	&"shatter": [{"wave": "noise", "f": 15000.0, "dur": 0.3, "vol": 0.4, "lp": 0.8, "lp1": 0.2}, {"wave": "tri", "f": 2637.0, "f1": 1760.0, "dur": 0.25, "vol": 0.15}],
	&"heal": [{"wave": "sine", "f": 784.0, "notes": [0, 4, 7], "step": 0.06, "dur": 0.25, "vol": 0.2}],
	&"judgment": [{"wave": "sine", "f": 523.0, "dur": 0.9, "vol": 0.35, "curve": 2.0}, {"wave": "sine", "f": 1046.0, "dur": 0.7, "vol": 0.2}, {"wave": "sine", "f": 1568.0, "dur": 0.5, "vol": 0.12}],
	&"vanish": [{"wave": "noise", "f": 9000.0, "dur": 0.3, "vol": 0.3, "attack": 0.25, "lp": 0.4, "lp1": 0.05, "curve": 4.0}, {"wave": "sine", "f": 1200.0, "f1": 300.0, "dur": 0.3, "vol": 0.15}],
	&"whale": [{"wave": "sine", "f": 70.0, "f1": 40.0, "dur": 0.9, "vol": 0.6, "attack": 0.2}, {"wave": "noise", "f": 4000.0, "delay": 0.25, "dur": 0.6, "vol": 0.35, "lp": 0.3, "lp1": 0.05}],
	&"debt": [{"wave": "square", "f": 98.0, "dur": 0.5, "vol": 0.15, "lp": 0.15, "duty": 0.3}, {"wave": "square", "f": 147.0, "dur": 0.5, "vol": 0.1, "lp": 0.15}],
	&"swarm": [{"wave": "saw", "f": 220.0, "dur": 0.5, "vol": 0.15, "lp": 0.2, "vib": 0.2, "vib_rate": 28.0, "attack": 0.1}, {"wave": "saw", "f": 233.0, "dur": 0.5, "vol": 0.12, "lp": 0.2, "vib": 0.2, "vib_rate": 31.0, "attack": 0.1}],
	&"snip": [{"wave": "noise", "f": 14000.0, "dur": 0.04, "vol": 0.35, "lp": 0.9}, {"wave": "noise", "f": 14000.0, "delay": 0.07, "dur": 0.04, "vol": 0.35, "lp": 0.9}],
	&"thread": [{"wave": "tri", "f": 1760.0, "f1": 2093.0, "dur": 0.25, "vol": 0.2, "vib": 0.01, "vib_rate": 12.0}],
	# --- Serpent ----------------------------------------------------------------
	&"venom_pop": [{"wave": "sine", "f": 250.0, "f1": 900.0, "dur": 0.1, "vol": 0.45}, {"wave": "noise", "f": 8000.0, "delay": 0.05, "dur": 0.25, "vol": 0.3, "lp": 0.3, "lp1": 0.05}],
	&"hiss": [{"wave": "noise", "f": 14000.0, "dur": 0.35, "vol": 0.25, "attack": 0.05, "lp": 0.6, "lp1": 0.2}],
	&"viper": [{"wave": "noise", "f": 12000.0, "dur": 0.08, "vol": 0.25, "lp": 0.7}, {"wave": "sine", "f": 900.0, "f1": 500.0, "dur": 0.06, "vol": 0.15}],
	# --- Fermata's instruments ------------------------------------------------------
	&"brass": [{"wave": "saw", "f": 233.0, "dur": 0.55, "vol": 0.3, "attack": 0.04, "lp": 0.08, "lp1": 0.3, "vib": 0.012, "vib_rate": 5.5, "curve": 1.2}, {"wave": "saw", "f": 349.0, "dur": 0.55, "vol": 0.2, "attack": 0.05, "lp": 0.08, "lp1": 0.3, "curve": 1.2}, {"wave": "sine", "f": 116.5, "dur": 0.55, "vol": 0.3, "curve": 1.2}],
	&"brass_blast": [{"wave": "saw", "f": 175.0, "f1": 233.0, "dur": 0.4, "vol": 0.4, "lp": 0.15, "lp1": 0.45, "curve": 1.5}, {"wave": "noise", "f": 3000.0, "dur": 0.25, "vol": 0.25, "lp": 0.2}],
	&"strings": [{"wave": "saw", "f": 659.0, "dur": 0.8, "vol": 0.18, "attack": 0.15, "lp": 0.15, "vib": 0.01, "vib_rate": 6.0, "curve": 1.0}, {"wave": "saw", "f": 784.0, "dur": 0.8, "vol": 0.13, "attack": 0.18, "lp": 0.15, "vib": 0.012, "vib_rate": 5.6, "curve": 1.0}],
	&"pizz": [{"wave": "tri", "f": 784.0, "dur": 0.14, "vol": 0.3, "curve": 4.0}],
	&"drum": [{"wave": "sine", "f": 140.0, "f1": 55.0, "dur": 0.3, "vol": 0.6}, {"wave": "noise", "f": 6000.0, "dur": 0.12, "vol": 0.3, "lp": 0.3}],
	&"finale": [{"wave": "sine", "f": 140.0, "f1": 55.0, "dur": 0.35, "vol": 0.55}, {"wave": "saw", "f": 349.0, "dur": 0.9, "vol": 0.2, "lp": 0.1, "lp1": 0.4, "attack": 0.08}, {"wave": "saw", "f": 440.0, "dur": 0.9, "vol": 0.16, "lp": 0.1, "lp1": 0.4, "attack": 0.08}, {"wave": "saw", "f": 523.0, "dur": 0.9, "vol": 0.14, "lp": 0.1, "lp1": 0.4, "attack": 0.08}],
	&"final_note": [{"wave": "sine", "f": 880.0, "dur": 0.7, "vol": 0.3, "curve": 2.5}, {"wave": "sine", "f": 1320.0, "dur": 0.5, "vol": 0.15, "curve": 2.5}],
	# --- KOSMONAUT --------------------------------------------------------------
	&"drone_launch": [{"wave": "saw", "f": 300.0, "f1": 1200.0, "dur": 0.3, "vol": 0.2, "lp": 0.25, "vib": 0.05, "vib_rate": 30.0}],
	&"drone_recall": [{"wave": "saw", "f": 1000.0, "f1": 350.0, "dur": 0.25, "vol": 0.16, "lp": 0.25, "vib": 0.05, "vib_rate": 30.0}],
	&"drone_zap": [{"wave": "square", "f": 1500.0, "f1": 600.0, "dur": 0.08, "vol": 0.15, "duty": 0.15}, {"wave": "noise", "f": 15000.0, "dur": 0.05, "vol": 0.15, "lp": 0.8}],
	&"drone_pulse": [{"wave": "sine", "f": 200.0, "f1": 80.0, "dur": 0.35, "vol": 0.5, "vib": 0.2, "vib_rate": 14.0}],
	&"reentry_whistle": [{"wave": "sine", "f": 2400.0, "f1": 500.0, "dur": 1.0, "vol": 0.2, "attack": 0.1, "curve": 0.6}],
	&"boom": [{"wave": "sine", "f": 90.0, "f1": 35.0, "dur": 0.8, "vol": 0.7, "curve": 1.6}, {"wave": "noise", "f": 3000.0, "dur": 0.7, "vol": 0.45, "lp": 0.4, "lp1": 0.03}],
	# --- Map ----------------------------------------------------------------------
	&"candle_lit": [{"wave": "sine", "f": 1046.0, "dur": 0.5, "vol": 0.2, "curve": 2.5}, {"wave": "noise", "f": 6000.0, "dur": 0.2, "vol": 0.08, "lp": 0.2, "attack": 0.05}],
	&"candle_taken": [{"wave": "tri", "f": 1046.0, "notes": [0, 4, 7, 11, 12], "step": 0.05, "dur": 0.4, "vol": 0.3, "curve": 1.3}],
	&"phase_two": [{"wave": "sine", "f": 392.0, "notes": [0, 4, 7, 12], "step": 0.14, "dur": 1.4, "vol": 0.3, "curve": 1.8}, {"wave": "tri", "f": 196.0, "dur": 1.6, "vol": 0.25, "attack": 0.3, "curve": 1.5}, {"wave": "noise", "f": 8000.0, "dur": 0.8, "vol": 0.06, "lp": 0.15, "attack": 0.3}],
	&"moon": [{"wave": "sine", "f": 1318.0, "notes": [0, 7, 12, 19], "step": 0.08, "dur": 0.9, "vol": 0.18, "curve": 2.0, "vib": 0.01, "vib_rate": 6.0}, {"wave": "sine", "f": 659.0, "dur": 1.0, "vol": 0.15, "attack": 0.2, "curve": 2.0}],
	&"relay_spawn": [{"wave": "sine", "f": 784.0, "dur": 0.6, "vol": 0.35, "curve": 2.0}, {"wave": "sine", "f": 1046.0, "delay": 0.18, "dur": 0.7, "vol": 0.3, "curve": 2.0}],
	&"relay_warn": [{"wave": "square", "f": 523.0, "dur": 0.1, "vol": 0.12, "duty": 0.3}, {"wave": "square", "f": 523.0, "delay": 0.2, "dur": 0.1, "vol": 0.12, "duty": 0.3}],
	&"relay_pick": [{"wave": "tri", "f": 523.0, "f1": 1046.0, "dur": 0.2, "vol": 0.35}],
	&"relay_drop": [{"wave": "tri", "f": 784.0, "f1": 330.0, "dur": 0.25, "vol": 0.35}],
	&"relay_deliver": [{"wave": "square", "f": 523.0, "notes": [0, 4, 7, 12, 7, 12], "step": 0.09, "dur": 0.6, "vol": 0.14, "duty": 0.3, "curve": 0.8}, {"wave": "tri", "f": 261.0, "notes": [0, 0, 7, 7, 12, 12], "step": 0.09, "dur": 0.6, "vol": 0.3, "curve": 0.8}],
	&"slam_windup": [{"wave": "sine", "f": 60.0, "f1": 110.0, "dur": 0.6, "vol": 0.3, "attack": 0.5, "curve": 0.5}],
	&"slam": [{"wave": "sine", "f": 75.0, "f1": 35.0, "dur": 0.6, "vol": 0.7}, {"wave": "noise", "f": 2000.0, "dur": 0.4, "vol": 0.4, "lp": 0.2, "lp1": 0.02}],
	&"crumble": [{"wave": "noise", "f": 1800.0, "dur": 1.2, "vol": 0.5, "lp": 0.3, "lp1": 0.02, "curve": 1.2}, {"wave": "sine", "f": 70.0, "f1": 30.0, "dur": 1.0, "vol": 0.55}],
	&"immune": [{"wave": "tri", "f": 1318.0, "dur": 0.6, "vol": 0.2, "vib": 0.03, "vib_rate": 8.0}],
	&"kill": [{"wave": "square", "f": 659.0, "notes": [0, 7, 12], "step": 0.07, "dur": 0.32, "vol": 0.16, "duty": 0.3}, {"wave": "noise", "f": 9000.0, "dur": 0.15, "vol": 0.2, "lp": 0.4}],
	&"death": [{"wave": "tri", "f": 523.0, "notes": [0, -3, -7, -12], "step": 0.12, "dur": 0.6, "vol": 0.35, "curve": 1.0}],
	&"respawn": [{"wave": "sine", "f": 392.0, "f1": 784.0, "dur": 0.4, "vol": 0.3, "attack": 0.2, "curve": 1.0}],
	&"overtime": [{"wave": "sine", "f": 110.0, "dur": 2.0, "vol": 0.4, "curve": 1.5, "vib": 0.004, "vib_rate": 3.0}, {"wave": "sine", "f": 233.0, "dur": 1.5, "vol": 0.2, "curve": 2.0}, {"wave": "sine", "f": 349.0, "dur": 1.2, "vol": 0.12, "curve": 2.0}],
	&"wave": [{"wave": "tri", "f": 392.0, "dur": 0.12, "vol": 0.12}, {"wave": "tri", "f": 523.0, "delay": 0.1, "dur": 0.15, "vol": 0.12}],
	# --- Intro and victory ------------------------------------------------------
	&"slap": [{"wave": "noise", "f": 9000.0, "dur": 0.12, "vol": 0.55, "lp": 0.5, "lp1": 0.1, "curve": 3.0}, {"wave": "sine", "f": 180.0, "f1": 90.0, "dur": 0.1, "vol": 0.3}],
	&"vs": [{"wave": "sine", "f": 110.0, "f1": 45.0, "dur": 0.6, "vol": 0.6}, {"wave": "noise", "f": 5000.0, "dur": 0.3, "vol": 0.3, "lp": 0.3, "lp1": 0.05}, {"wave": "square", "f": 880.0, "dur": 0.5, "vol": 0.08, "duty": 0.25, "curve": 2.0}],
	&"victory": [{"wave": "square", "f": 523.0, "notes": [0, 4, 7, 12, 12, 16], "step": 0.12, "dur": 1.2, "vol": 0.14, "duty": 0.3, "curve": 0.9}, {"wave": "tri", "f": 261.0, "notes": [0, 4, 7, 12, 12, 16], "step": 0.12, "dur": 1.2, "vol": 0.35, "curve": 0.9}, {"wave": "sine", "f": 65.0, "dur": 1.2, "vol": 0.35, "curve": 1.2}],
	&"defeat": [{"wave": "tri", "f": 392.0, "notes": [0, -1, -3, -5, -8], "step": 0.2, "dur": 1.2, "vol": 0.35, "curve": 0.8}, {"wave": "saw", "f": 98.0, "dur": 1.2, "vol": 0.12, "lp": 0.1, "curve": 1.0}],
}


static func has(name: StringName) -> bool:
	return RECIPES.has(name)


static func get_stream(name: StringName) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = SfxSynth.render(RECIPES[name])
	return _cache[name]


static func is_cached(name: StringName) -> bool:
	return _cache.has(name)
