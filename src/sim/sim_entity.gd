class_name SimEntity
extends RefCounted
## Base for everything the simulation tracks. Views and targets refer to units by id,
## so a dead unit can never be hit twice through a stale reference.

enum Kind { HERO, MINION, STRUCTURE, RELAY }

var id := 0
var kind: Kind = Kind.HERO
## MatchSim.BLUE, MatchSim.RED, or -1 for neutral.
var team := -1
var pos := Vector2.ZERO
## Position at the start of the current tick, for smooth rendering between ticks.
var prev_pos := Vector2.ZERO
var radius := 0.5
var max_hp := 1.0
var hp := 1.0
var alive := true
## True for things other units must walk around (structures).
var blocks_movement := false

## Basic attack. Every unit uses the same contract: wind up, then a guaranteed hit.
var attack_range := 0.0
var attack_damage := 0.0
var attack_windup := 0.25
var attack_interval := 1.0
## Id of the unit being wound up on (0 = none).
var attack_target := 0
## Seconds left in the current windup, or -1 when not winding up.
var windup_left := -1.0
## Seconds before the next windup may start.
var cooldown_left := 0.0


func is_winding_up() -> bool:
	return windup_left >= 0.0


## 0..1 progress of the current windup, for visuals.
func windup_progress() -> float:
	if windup_left < 0.0 or attack_windup <= 0.0:
		return 0.0
	return clampf(1.0 - windup_left / attack_windup, 0.0, 1.0)
