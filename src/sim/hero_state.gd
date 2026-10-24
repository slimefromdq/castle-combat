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

## Economy: gold on hand, the six-card pre-match deck, and the items bought from it.
var gold := 0.0
var deck: Array[ItemData] = []
var items: Array[ItemData] = []
## Sim time of the last damage from the enemy hero (Recovery Sigil waits on it).
var last_hero_damage_time := -1000.0
var _move_speed_mult := 1.0


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
	return data.move_speed * _move_speed_mult * (carry_speed_mult if carrying_relay else 1.0)


func owns(item: ItemData) -> bool:
	return items.has(item)


func item_total(property: StringName) -> float:
	var sum := 0.0
	for item in items:
		sum += float(item.get(property))
	return sum


## Base stats from HeroData plus every owned item. Extra max HP is added to current HP.
func recompute_stats() -> void:
	var old_max := max_hp
	max_hp = data.max_hp * (1.0 + item_total(&"max_hp_bonus"))
	if alive:
		hp = minf(max_hp, hp + max_hp - old_max)
	attack_damage = data.attack_damage * (1.0 + item_total(&"damage_bonus"))
	attack_interval = data.attack_interval / (1.0 + item_total(&"attack_speed_bonus"))
	attack_range = data.attack_range * (1.0 + item_total(&"range_bonus"))
	_move_speed_mult = 1.0 + item_total(&"move_speed_bonus")
