class_name Fruits
extends RefCounted
## Honey fruit (Lucy: like League's honeyfruit or Dota's tangos): small heals out on the
## diamond, near the Relay spots where fights happen, never near your base. Stand on a
## ripe fruit for fruit_eat_time without taking damage to eat it; it heals fruit_heal of
## max HP over fruit_heal_time, and any damage ends the heal. Either hero may eat any
## fruit (ArenaData.fruits, mirrored).

class Fruit:
	var index := 0
	var pos := Vector2.ZERO
	var ripe := false
	var ripe_at := 0.0
	var progress: Array[float] = [0.0, 0.0]

var fruits: Array[Fruit] = []


func setup(sim: MatchSim) -> void:
	fruits.clear()
	var spots := ArenaData.mirrored(sim.arena.fruits)
	for i in spots.size():
		var f := Fruit.new()
		f.index = i
		f.pos = spots[i]
		f.ripe_at = sim.config.fruit_first_time
		fruits.append(f)


func tick(sim: MatchSim) -> void:
	var cfg := sim.config
	for h in sim.heroes:
		if sim.time < h.fruit_until:
			if not h.alive or sim.time - h.last_damaged_time < sim.dt * 1.5:
				h.fruit_until = 0.0
			else:
				sim.heal(h, h.fruit_rate * sim.dt)
	for f in fruits:
		if not f.ripe:
			if sim.time + 0.0001 >= f.ripe_at:
				f.ripe = true
				f.progress = [0.0, 0.0]
				sim.emit_event(&"fruit_ripe", {"fruit": f.index, "pos": f.pos})
			continue
		for h in sim.heroes:
			var hurt := sim.time - h.last_damaged_time < sim.dt * 1.5
			if not h.alive or hurt or h.pos.distance_to(f.pos) > cfg.fruit_radius + h.radius:
				f.progress[h.team] = 0.0
				continue
			f.progress[h.team] += sim.dt
			if f.progress[h.team] + 0.0001 >= cfg.fruit_eat_time:
				_eat(sim, f, h)
				break


func _eat(sim: MatchSim, f: Fruit, h: HeroState) -> void:
	var cfg := sim.config
	f.ripe = false
	f.ripe_at = sim.time + cfg.fruit_respawn_time
	f.progress = [0.0, 0.0]
	h.fruit_rate = h.max_hp * cfg.fruit_heal / maxf(0.1, cfg.fruit_heal_time)
	h.fruit_until = sim.time + cfg.fruit_heal_time
	sim.emit_event(&"fruit_eaten", {"fruit": f.index, "pos": f.pos, "hero": h.id, "team": h.team, "back_at": f.ripe_at})


func ripe() -> Array[Fruit]:
	var out: Array[Fruit] = []
	for f in fruits:
		if f.ripe:
			out.append(f)
	return out
