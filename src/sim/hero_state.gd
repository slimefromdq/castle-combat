class_name HeroState
extends SimEntity
## A hero's live state. Rules about what it may do live in the sim systems.

var data: HeroData
var spawn_pos := Vector2.ZERO
## Unit vector the hero faces, in sim space.
var facing := Vector2.UP
## True on ticks where the hero moved. Basic attacks (M1) only wind up while false.
var moving := false


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
	facing = Vector2.UP if hero_team == MatchSim.BLUE else Vector2.DOWN


func move_speed() -> float:
	return data.move_speed
