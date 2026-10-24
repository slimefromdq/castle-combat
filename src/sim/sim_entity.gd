class_name SimEntity
extends RefCounted
## Base for everything the simulation tracks. Views and targets refer to units by id.

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
