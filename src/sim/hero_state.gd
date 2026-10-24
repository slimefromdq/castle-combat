class_name HeroState
extends SimEntity
## A hero's live state. Rules about what it may do live in the sim systems.

var data: HeroData
var spawn_pos := Vector2.ZERO
## Unit vector the hero faces, in sim space.
var facing := MatchSim.BLUE_FORWARD
## True on ticks where the hero moved. Basic attacks only wind up while false.
var moving := false
## Tap-to-target override (entity id, 0 = none) and how long it has been out of reach.
var preferred_target := 0
var preferred_lost_time := 0.0
## Sim time when a knocked-out hero comes back.
var respawn_at := 0.0
## True while this hero carries the Relay (set by RelayController).
var carrying_relay := false
## Speed multiplier while carrying (copied from the config by RelayController).
var carry_speed_mult := 1.0


func setup(hero_data: HeroData, hero_team: int, at: Vector2) -> void:
	kind = Kind.HERO
	data = hero_data
	team = hero_team
	radius = hero_data.radius
	max_hp = hero_data.max_hp
	hp = max_hp
	spawn_pos = at
	pos = at
	prev_pos = at
	facing = MatchSim.forward(hero_team)
	attack_range = hero_data.attack_range
	attack_damage = hero_data.attack_damage
	attack_windup = hero_data.attack_windup
	attack_interval = hero_data.attack_interval


func move_speed() -> float:
	return data.move_speed * (carry_speed_mult if carrying_relay else 1.0)
