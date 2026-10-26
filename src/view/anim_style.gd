class_name AnimStyle
extends Resource
## How one hero moves. HeroAnimator plays every hero from the same rules; a style only
## tunes them (how bouncy the walk is, how a basic attack lands, what a cast and the ult
## look like). Styles move the hero's "Pose" node as a whole, so a hand-made body that
## replaces today's primitives keeps all of this for free.

enum Strike { LUNGE, RECOIL, SWING, HOP }
enum Cast { RAISE, SPIN, STOMP, BOW, LEAP, GROW }

## Idle: breathing (scale) and a slow sway (roll degrees).
@export var breathe := 0.025
@export var breathe_rate := 2.2
@export var idle_sway_deg := 0.0
## Walk: bob height (m), steps per metre, side-to-side roll, forward lean.
@export var walk_bob := 0.07
@export var steps_per_m := 0.9
@export var walk_roll_deg := 3.0
@export var walk_lean_deg := 4.0
## Side-to-side slither (m), for Serpent.
@export var walk_slide := 0.0
## Basic attack: wind back during the windup, then strike.
@export var strike := Strike.LUNGE
@export var windup_pull_deg := 10.0
@export var strike_size := 1.0
@export var strike_time := 0.3
## Casts (Q/E) and the ultimate (R).
@export var cast := Cast.RAISE
@export var cast_time := 0.4
@export var ult := Cast.LEAP
@export var ult_time := 0.75
## Hit stagger: lean back this far for a moment.
@export var stagger_deg := 7.0


static func _make(props: Dictionary) -> AnimStyle:
	var s := AnimStyle.new()
	for k: String in props:
		s.set(k, props[k])
	return s


## One style per hero shape. Unknown shapes get the defaults.
static func for_shape(shape: String) -> AnimStyle:
	match shape:
		"paladin":  # Avery: heavy, steady, big overhead swings.
			return _make({"walk_bob": 0.05, "steps_per_m": 0.8, "walk_roll_deg": 2.0, "strike": Strike.SWING, "windup_pull_deg": 14.0, "strike_size": 1.2, "cast": Cast.RAISE, "ult": Cast.LEAP})
		"gunslinger":  # Jose: a swaggering walk, guns kick, twirls.
			return _make({"walk_roll_deg": 6.0, "idle_sway_deg": 2.5, "strike": Strike.RECOIL, "windup_pull_deg": 4.0, "strike_time": 0.22, "cast": Cast.SPIN, "cast_time": 0.35, "ult": Cast.SPIN, "ult_time": 0.6})
		"thief":  # Jack: low, quick and light on his feet.
			return _make({"breathe": 0.02, "walk_bob": 0.09, "steps_per_m": 1.2, "walk_lean_deg": 10.0, "strike": Strike.LUNGE, "strike_size": 1.2, "strike_time": 0.24, "cast": Cast.STOMP, "ult": Cast.SPIN})
		"sailor":  # Ahab: a rolling sea-legs gait, heavy harpoon thrusts.
			return _make({"walk_bob": 0.06, "steps_per_m": 0.7, "walk_roll_deg": 8.0, "idle_sway_deg": 3.0, "strike": Strike.LUNGE, "windup_pull_deg": 14.0, "strike_size": 1.3, "cast": Cast.STOMP, "ult": Cast.LEAP, "ult_time": 0.9})
		"hunter":  # Slayer: forward-leaning, aggressive stabs.
			return _make({"walk_lean_deg": 9.0, "steps_per_m": 1.0, "strike": Strike.LUNGE, "windup_pull_deg": 12.0, "strike_size": 1.4, "cast": Cast.STOMP, "ult": Cast.LEAP})
		"swarm":  # Huddle: a jittery, bouncing cloud.
			return _make({"breathe": 0.05, "breathe_rate": 5.0, "walk_bob": 0.14, "steps_per_m": 1.6, "walk_roll_deg": 5.0, "walk_lean_deg": 0.0, "strike": Strike.HOP, "cast": Cast.GROW, "ult": Cast.GROW, "stagger_deg": 4.0})
		"doll":  # Poppet: stiff little hops.
			return _make({"breathe": 0.0, "walk_bob": 0.16, "steps_per_m": 1.4, "walk_roll_deg": 7.0, "walk_lean_deg": 0.0, "strike": Strike.LUNGE, "strike_time": 0.25, "cast": Cast.SPIN, "ult": Cast.SPIN, "ult_time": 0.9})
		"emperor":  # Tot: pompous, upright, chest out.
			return _make({"walk_bob": 0.04, "steps_per_m": 0.8, "walk_roll_deg": 4.0, "walk_lean_deg": -3.0, "strike": Strike.RECOIL, "windup_pull_deg": 8.0, "cast": Cast.RAISE, "ult": Cast.GROW, "ult_time": 0.9})
		"serpent":  # Serpent: a slithering sway, snapping strikes.
			return _make({"walk_bob": 0.02, "walk_roll_deg": 9.0, "walk_slide": 0.12, "steps_per_m": 1.1, "idle_sway_deg": 4.0, "strike": Strike.LUNGE, "windup_pull_deg": 16.0, "strike_size": 1.3, "strike_time": 0.22, "cast": Cast.BOW, "ult": Cast.RAISE, "ult_time": 0.9})
		"conductor":  # Fermata: graceful sway, baton flicks, a grand bow.
			return _make({"walk_bob": 0.04, "walk_roll_deg": 5.0, "idle_sway_deg": 3.0, "breathe_rate": 1.6, "strike": Strike.SWING, "windup_pull_deg": 6.0, "strike_size": 0.7, "cast": Cast.RAISE, "ult": Cast.BOW, "ult_time": 1.0})
		"kosmonaut":  # KOSMONAUT: floaty low-gravity steps.
			return _make({"walk_bob": 0.12, "steps_per_m": 0.55, "walk_roll_deg": 2.0, "breathe_rate": 1.4, "strike": Strike.RECOIL, "cast": Cast.RAISE, "ult": Cast.LEAP, "ult_time": 1.0})
	return AnimStyle.new()
