class_name PickupController
extends RefCounted
## Walk-over pickups (Lucy's replacement for the votive candles): small coins (gold) and
## sparks (XP) scattered over the map (ArenaData.pickups, mirrored). Walk over one and
## it's yours, no waiting. Each spawn is a coin or a spark, decided when it appears and
## shown on the ground, so you can pick which to go for. Mirrored pairs always match.

const COIN := &"coin"
const SPARK := &"spark"

class Pickup:
	var index := 0
	var pos := Vector2.ZERO
	var kind := COIN
	var up := false
	var up_at := 0.0
	var spawns := 0

var pickups: Array[Pickup] = []


func setup(sim: MatchSim) -> void:
	pickups.clear()
	var spots := ArenaData.mirrored(sim.arena.pickups)
	for i in spots.size():
		var p := Pickup.new()
		p.index = i
		p.pos = spots[i]
		p.up_at = sim.config.pickup_first_time
		pickups.append(p)


func tick(sim: MatchSim) -> void:
	var cfg := sim.config
	var half := sim.arena.pickups.size()
	for p in pickups:
		if not p.up:
			if sim.time + 0.0001 >= p.up_at:
				p.up = true
				p.kind = kind_for(p.index % maxi(1, half), p.spawns, cfg.pickup_spark_chance)
				p.spawns += 1
				sim.emit_event(&"pickup_spawned", {"pickup": p.index, "pos": p.pos, "kind": p.kind})
			continue
		for h in sim.heroes:
			if h.alive and h.pos.distance_to(p.pos) <= cfg.pickup_radius + h.radius:
				_take(sim, p, h)
				break


func _take(sim: MatchSim, p: Pickup, h: HeroState) -> void:
	var cfg := sim.config
	p.up = false
	p.up_at = sim.time + cfg.pickup_respawn_time
	if p.kind == SPARK:
		Leveling.gain(sim, h, cfg.pickup_xp)
	else:
		Economy.award(sim, h, cfg.pickup_gold, &"pickup")
	sim.emit_event(&"pickup_taken", {"pickup": p.index, "pos": p.pos, "kind": p.kind, "hero": h.id, "team": h.team, "back_at": p.up_at})


## Coin or spark for a spot's nth spawn. A fixed hash instead of a random roll, so
## matches replay the same and both halves of the map always match.
static func kind_for(base_index: int, spawn: int, spark_chance: float) -> StringName:
	var h := (base_index * 73856093) ^ (spawn * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return SPARK if float(absi(h) % 1000) / 1000.0 < spark_chance else COIN


## Pickups on the ground right now, for bots, the minimap and the HUD.
func active() -> Array[Pickup]:
	var out: Array[Pickup] = []
	for p in pickups:
		if p.up:
			out.append(p)
	return out
