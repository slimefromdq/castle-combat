class_name PortraitMood
extends RefCounted
## Which face a HUD portrait shows: neutral, ahead, behind or low HP.
## Low HP wins over everything: it comes on below 30% HP and clears above 40%.
## Ahead/behind come from the level gap plus the gold gap (gold on hand plus items
## owned; 400 gold counts like a level). Both have hysteresis, and a face is held at
## least 2 s before ahead/behind/neutral can change again, so it never flickers.

enum Mood { NEUTRAL, AHEAD, BEHIND, LOW_HP }

const LOW_ENTER := 0.3
const LOW_EXIT := 0.4
const LEAD_ENTER := 1.0
const LEAD_EXIT := 0.4
const GOLD_PER_LEVEL := 400.0
const HOLD := 2.0

var mood := Mood.NEUTRAL
var _low := false
var _lead_mood := Mood.NEUTRAL
var _changed_at := -100.0


static func worth(h: HeroState) -> float:
	var w := h.gold
	for it in h.items:
		w += it.cost
	return w


## Positive when `me` is ahead, in levels.
static func lead(me: HeroState, them: HeroState) -> float:
	return float(me.level - them.level) + (worth(me) - worth(them)) / GOLD_PER_LEVEL


func update(me: HeroState, them: HeroState, time: float) -> Mood:
	var hp := me.hp / maxf(me.max_hp, 1.0)
	if _low:
		_low = me.alive and hp < LOW_EXIT
	else:
		_low = me.alive and hp < LOW_ENTER
	var l := lead(me, them)
	var want := _lead_mood
	match _lead_mood:
		Mood.AHEAD:
			if l < LEAD_EXIT:
				want = Mood.NEUTRAL
		Mood.BEHIND:
			if l > -LEAD_EXIT:
				want = Mood.NEUTRAL
		_:
			if l >= LEAD_ENTER:
				want = Mood.AHEAD
			elif l <= -LEAD_ENTER:
				want = Mood.BEHIND
	if want != _lead_mood and time - _changed_at >= HOLD:
		_lead_mood = want
		_changed_at = time
	mood = Mood.LOW_HP if _low else _lead_mood
	return mood
