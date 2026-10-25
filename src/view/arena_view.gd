class_name ArenaView
extends Node3D
## The static map: meadow, sandstone lane, violet Relay pockets, low walls and scenery.
## Each half of the lane carries its owner's color on the lane edges and a soft wash
## near its base, so "whose side is this" reads at a glance. Rebuilt when seats swap,
## because ally/enemy is relative to the viewer.

## Scenery never sits closer than this to the lane, so it can't hide anything.
const SCENERY_SEED := 7


func build(arena: ArenaData, local_seat: int) -> void:
	for child in get_children():
		child.queue_free()
	var half := arena.half_length
	var lane_w := arena.lane_half_width * 2.0
	# Meadow all around, with a few darker patches for texture.
	UnitFactory.part(self, UnitFactory.box(Vector3(70, 0.1, half * 2.0 + 50)), Palette.MEADOW, Vector3(0, -0.12, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED
	for i in 14:
		var p := Vector2(rng.randf_range(7.0, 22.0), rng.randf_range(-half - 6.0, half + 6.0))
		for q in [p, -p]:
			UnitFactory.part(self, UnitFactory.cylinder(rng.randf_range(1.5, 3.5), rng.randf_range(1.5, 3.5), 0.02, 10), Palette.MEADOW_DARK, MatchView.to_world(q, -0.06), Vector3.ZERO, true)
	# Lane and pockets.
	for i in arena.floors.size():
		var r := arena.floors[i]
		var color := Palette.LANE if i == 0 else Palette.POCKET
		UnitFactory.part(self, UnitFactory.box(Vector3(r.size.x, 0.1, r.size.y)), color, MatchView.to_world(r.get_center(), -0.05))
	_tiles(arena.floors[0], Palette.LANE_TILE, 2.5, 1.9)
	for pocket in arena.pockets:
		_tiles(pocket, Palette.POCKET_TILE, 1.5, 0.9)
	# Team halves: colored lane edges plus a soft wash toward each base.
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var c := Palette.team_color(team == local_seat)
		var end_sign := -1.0 if team == MatchSim.BLUE else 1.0
		for side in [-1.0, 1.0]:
			var x: float = side * (arena.lane_half_width - 0.2)
			UnitFactory.part(self, UnitFactory.box(Vector3(0.22, 0.02, half - 6.0)), c, MatchView.to_world(Vector2(x, end_sign * (half + 6.0) / 2.0), 0.01), Vector3.ZERO, true)
		UnitFactory.part(self, UnitFactory.box(Vector3(lane_w, 0.02, 16.0)), Color(c, 0.18), MatchView.to_world(Vector2(0, end_sign * (half - 8.0)), 0.008), Vector3.ZERO, true)
	# Healing pads behind each Core.
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var at := MatchView.to_world(MatchSim.to_team_space(team, arena.heal_pad), 0.015)
		var pad_c := Palette.team_color(team == local_seat).lightened(0.5)
		UnitFactory.part(self, UnitFactory.cylinder(arena.heal_pad_radius, arena.heal_pad_radius, 0.02, 32), Color(0.55, 1.0, 0.65, 0.35), at, Vector3.ZERO, true)
		UnitFactory.part(self, UnitFactory.cylinder(arena.heal_pad_radius * 0.35, arena.heal_pad_radius * 0.35, 0.03, 4), Color(pad_c, 0.8), at + Vector3(0, 0.01, 0), Vector3(0, 45, 0), true)
	# Gold centre line between the pockets.
	UnitFactory.part(self, UnitFactory.box(Vector3(lane_w, 0.02, 0.3)), Palette.CENTER_LINE, MatchView.to_world(Vector2.ZERO, 0.012), Vector3.ZERO, true)
	# Walls: sandstone with a lighter cap, below hero height so the camera never loses a unit.
	for w in arena.walls:
		UnitFactory.part(self, UnitFactory.box(Vector3(w.size.x, 0.7, w.size.y)), Palette.WALL, MatchView.to_world(w.get_center(), 0.35))
		UnitFactory.part(self, UnitFactory.box(Vector3(w.size.x + 0.08, 0.08, w.size.y + 0.08)), Palette.WALL_CAP, MatchView.to_world(w.get_center(), 0.74))
	_scenery(arena)


## Small tiles on a grid inside a rect.
func _tiles(r: Rect2, color: Color, step: float, size: float) -> void:
	var tx := r.position.x + step / 2.0
	while tx < r.end.x:
		var ty := r.position.y + step / 2.0
		while ty < r.end.y:
			UnitFactory.part(self, UnitFactory.box(Vector3(size, 0.02, size)), color, MatchView.to_world(Vector2(tx, ty), 0.004), Vector3.ZERO, true)
			ty += step
		tx += step


## Trees, rocks and flowers outside the walls. Placed for one half and mirrored, so both
## seats see the same scenery.
func _scenery(arena: ArenaData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED
	var half := arena.half_length
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(6.4, 16.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-half - 4.0, 0.0))
		if _too_close_to_play(arena, p):
			continue
		placed += 1
		var kind := rng.randi_range(0, 9)
		var scale := rng.randf_range(0.8, 1.3)
		for q in [p, -p]:
			var at := MatchView.to_world(q)
			if kind < 5:
				UnitFactory.part(self, UnitFactory.cylinder(0.12, 0.16, 0.5, 8), Palette.TRUNK, at + Vector3(0, 0.25, 0))
				UnitFactory.part(self, UnitFactory.cylinder(0.0, 0.75 * scale, 1.6 * scale, 8), Palette.TREE if kind % 2 == 0 else Palette.TREE_LIGHT, at + Vector3(0, 0.5 + 0.8 * scale, 0))
			elif kind < 8:
				var rock := SphereMesh.new()
				rock.radius = 0.45 * scale
				rock.height = 0.6 * scale
				rock.radial_segments = 6
				rock.rings = 3
				UnitFactory.part(self, rock, Palette.ROCK, at + Vector3(0, 0.15, 0))
			else:
				for f in 5:
					var off := Vector3(rng.randf_range(-0.6, 0.6), 0.06, rng.randf_range(-0.6, 0.6))
					var bloom := SphereMesh.new()
					bloom.radius = 0.1
					bloom.height = 0.2
					bloom.radial_segments = 6
					bloom.rings = 3
					UnitFactory.part(self, bloom, Palette.FLOWER_A if f % 2 == 0 else Palette.FLOWER_B, at + off, Vector3.ZERO, true)


func _too_close_to_play(arena: ArenaData, p: Vector2) -> bool:
	for r in arena.floors + arena.walls:
		if r.grow(0.9).has_point(p):
			return true
	return false
