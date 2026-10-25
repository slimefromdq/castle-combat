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
## Knockouts so far (respawn timers grow with them).
var deaths := 0
## True while this hero carries the Relay (set by RelayController).
var carrying_relay := false
## Speed multiplier while carrying (copied from the config by RelayController).
var carry_speed_mult := 1.0

## Economy: gold on hand, the six-card pre-match deck, and the items bought from it.
var gold := 0.0
var deck: Array[ItemData] = []
var items: Array[ItemData] = []
## Sim time of the last damage from the enemy hero (regen items wait on it).
var last_hero_damage_time := -1000.0
## Sim time of the last hero damage dealt or taken ("out of hero combat" checks).
var last_hero_combat_time := -1000.0
## Item effects on this hero: Wounds (less healing), shred (more damage taken from the
## enemy hero), an armed Spark Band, a running storm, Reaper's Rhythm, Aegis recharge.
var wounds_until := 0.0
var wounds_amount := 0.0
var shred_until := 0.0
var shred_amount := 0.0
var spark_until := 0.0
var storm_left := 0
var storm_next := 0.0
var storm_item: ItemData
var rhythm_count := 0
var frenzy_left := 0
var crest_count := 0
var aegis_ready_at := 0.0
## Masterwork items (by id) and their boosted copies, which item_with and item_total use.
var masterworks: Dictionary = {}
## Siege scrolls bought this match (each one costs more).
var scrolls_bought := 0
## Level-up surge: extra attack speed until this sim time.
var surge_until := 0.0
var surge_bonus := 0.0
var _move_speed_mult := 1.0

## Levels and abilities. cooldowns[i] is seconds until ability i is ready.
var level := 1
var xp := 0.0
var cooldowns: Array[float] = [0.0, 0.0, 0.0]
var stun_until := 0.0
var slow_until := 0.0
var slow_amount := 0.0
var shield_hp := 0.0
var shield_until := 0.0
## Perk picks per tier (levels 2, 4, 6): 0 or 1 into the pair, -1 = not picked yet, and
## when each choice was offered (for the auto-pick).
var perk_picks: Array[int] = [-1, -1, -1]
var perk_offered_at: Array[float] = [0.0, 0.0, 0.0]
## Last sim time this hero moved (Avery's Steadfast).
var still_since := 0.0
## Follow-up casts: sim time until which ability i may be cast again (second dash,
## cloak teleport, vanish burst, charged-shot release).
var recast_until: Array[float] = [0.0, 0.0, 0.0]
## Timed buffs and marks. Haste = Oath's move speed; crit = Smooth Operator's next basic;
## charge = Charge's knockback on the next basic; mark = Lady Killer; judged = Judgment;
## blind = Smoke and Mirrors (basic attacks miss); decoy = Misdirection (troopers and
## towers lose you); power = Stage Presence ability damage.
var haste_until := 0.0
var haste_bonus := 0.0
var crit_until := 0.0
var charge_ready := false
var shatter_armed := false
var mark_until := 0.0
var marked_by := 0
var judged_until := 0.0
var judged_by := 0
var blind_until := 0.0
var decoy_until := 0.0
var decoy_pos := Vector2.ZERO
var power_until := 0.0
var power_bonus := 0.0
## Jose's charged shot: sim time the charge started, or -1.
var charging_since := -1.0
## Jack: vanished until this sim time (immune, slow, no attacks); his cloak's position
## and the id of the skillshot carrying it (0 once it has landed).
var vanish_until := 0.0
var cloak_pos := Vector2.ZERO
var cloak_shot_id := 0
## Forced movement (dashes and knockbacks): velocity for forced_ticks more ticks, then
## a dash that ends in a volley fires it (data, not a Callable, so a match that ends
## mid-dash leaves no reference cycle behind).
var forced_vel := Vector2.ZERO
var forced_ticks := 0
var forced_volley: AbilityData
var forced_key := 0
var forced_recast := false
## Sprint: build-up seconds, running direction, and the speed multiplier while sprinting.
var sprint_build := 0.0
var sprint_dir := Vector2.ZERO
var sprinting := false
var sprint_mult := 1.0
## Bushes: attacking, casting or hero damage reveals a hidden hero until this sim time.
var revealed_until := 0.0
## Last time this hero took damage from anything (towers and minions too).
var last_damaged_time := -1000.0
## A channelled ability (Last Tango): pulses left, time of the next one, where it lands
## (it follows the hero).
var channel: AbilityData
var channel_point := Vector2.ZERO
var channel_pulses_left := 0
var channel_next := 0.0
var channel_key := 0


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
	var slowed := 1.0 - (slow_amount if _now < slow_until else 0.0)
	var mult := _move_speed_mult
	if _now - last_hero_combat_time >= OUT_OF_COMBAT_DELAY:
		mult += item_total(&"out_of_combat_speed_bonus")
	if _now < haste_until:
		mult += haste_bonus
	var ability_mult := 1.0
	if is_vanished():
		ability_mult = data.abilities[1].move_mult
	elif channel != null:
		ability_mult = channel.move_mult
	elif is_charging():
		ability_mult = data.abilities[1].move_mult
	return data.move_speed * mult * sprint_mult * (carry_speed_mult if carrying_relay else 1.0) * slowed * ability_mult


## Seconds without dealing or taking hero damage before you count as out of combat.
const OUT_OF_COMBAT_DELAY := 5.0


## Set by MatchSim each tick so speed and attack-rate queries can check timed effects.
var _now := 0.0


func current_interval(_time: float) -> float:
	var bonus := 0.0
	if hp < max_hp * 0.5:
		bonus += item_total(&"low_hp_attack_speed_bonus")
	if _now < surge_until:
		bonus += surge_bonus
	return attack_interval / (1.0 + bonus)


func is_stunned(time: float) -> bool:
	return time < stun_until


func is_forced() -> bool:
	return forced_ticks > 0


func is_channeling() -> bool:
	return channel != null


func is_vanished() -> bool:
	return _now < vanish_until


func is_charging() -> bool:
	return charging_since >= 0.0


## Busy with an ability that stops basic attacks (channel, charge or vanish).
func is_busy_casting() -> bool:
	return is_channeling() or is_charging() or is_vanished()


## Perks picked so far: one of each pair for levels 2, 4 and 6.
func owned_perks() -> Array[PerkData]:
	var out: Array[PerkData] = []
	for tier in 3:
		var pick := perk_picks[tier]
		if pick >= 0 and level >= 2 + tier * 2 and tier * 2 + pick < data.perks.size():
			out.append(data.perks[tier * 2 + pick])
	return out


## The two perks offered at a tier (0 = level 2, 1 = level 4, 2 = level 6).
func perk_options(tier: int) -> Array[PerkData]:
	var out: Array[PerkData] = []
	for k in 2:
		if tier * 2 + k < data.perks.size():
			out.append(data.perks[tier * 2 + k])
	return out


## The earliest tier this hero has reached but not picked yet, or -1.
func pending_perk_tier() -> int:
	for tier in 3:
		if level >= 2 + tier * 2 and perk_picks[tier] < 0 and tier * 2 < data.perks.size():
			return tier
	return -1


func has_special(special: StringName) -> float:
	var p := perk_with(special)
	return p.special_value if p != null else 0.0


## The owned perk with this special rule, or null.
func perk_with(special: StringName) -> PerkData:
	for p in owned_perks():
		if p.special == special:
			return p
	return null


## Ability i unlocks at level 1, 3, 5.
func ability_unlocked(i: int) -> bool:
	return i < data.abilities.size() and level >= 1 + i * 2


func ability_cooldown(i: int) -> float:
	var cd := data.abilities[i].cooldown
	for p in owned_perks():
		if p.ability_index == i:
			cd -= p.cooldown_cut
	if i == 2:
		cd *= 1.0 - item_total(&"ult_cooldown_cut") - has_special(&"quick_study")
	return maxf(1.0, cd)


func perk_total(property: StringName) -> float:
	var sum := 0.0
	for p in owned_perks():
		sum += float(p.get(property))
	return sum


## Ends every timed effect (knockouts and respawns).
func clear_effects() -> void:
	stun_until = 0.0
	slow_until = 0.0
	shield_hp = 0.0
	shield_until = 0.0
	haste_until = 0.0
	crit_until = 0.0
	charge_ready = false
	shatter_armed = false
	mark_until = 0.0
	judged_until = 0.0
	blind_until = 0.0
	decoy_until = 0.0
	power_until = 0.0
	charging_since = -1.0
	vanish_until = 0.0
	cloak_shot_id = 0
	recast_until = [0.0, 0.0, 0.0]
	forced_ticks = 0
	forced_vel = Vector2.ZERO
	forced_volley = null
	channel = null
	wounds_until = 0.0
	shred_until = 0.0
	spark_until = 0.0
	storm_left = 0
	frenzy_left = 0
	surge_until = 0.0


func owns(item: ItemData) -> bool:
	return items.has(item)


func is_masterwork(item: ItemData) -> bool:
	return masterworks.has(item.id)


## An owned item as it works for this hero: its Masterwork copy if it has one.
func effective(item: ItemData) -> ItemData:
	return masterworks.get(item.id, item)


## The first owned item with a non-zero value for property, or null (a Masterwork
## comes back as its boosted copy).
func item_with(property: StringName) -> ItemData:
	for item in items:
		var it := effective(item)
		if float(it.get(property)) != 0.0:
			return it
	return null


func item_total(property: StringName) -> float:
	var sum := 0.0
	for item in items:
		sum += float(effective(item).get(property))
	return sum


## The highest tier among owned items (-1 with none).
func top_item_tier() -> int:
	var top := -1
	for item in items:
		top = maxi(top, item.tier)
	return top


## Base stats from HeroData plus every owned item. Extra max HP is added to current HP;
## losing max HP (selling) only caps current HP.
func recompute_stats() -> void:
	var old_max := max_hp
	max_hp = data.max_hp * (1.0 + item_total(&"max_hp_bonus") + perk_total(&"max_hp_bonus"))
	if alive:
		hp = minf(max_hp, hp + maxf(0.0, max_hp - old_max))
	attack_damage = data.attack_damage * (1.0 + data.attack_damage_per_level * (level - 1) + item_total(&"damage_bonus") + perk_total(&"damage_bonus"))
	attack_interval = data.attack_interval / (1.0 + item_total(&"attack_speed_bonus") + perk_total(&"attack_speed_bonus"))
	attack_range = data.attack_range * (1.0 + item_total(&"range_bonus") + perk_total(&"range_bonus"))
	_move_speed_mult = 1.0 + item_total(&"move_speed_bonus") + perk_total(&"move_speed_bonus")
