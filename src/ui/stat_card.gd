class_name StatCard
## The hero stat card as BBCode, shared by the Heroes menu and the in-match details
## panel. Attack Power (orange) and Ability Power (violet) always keep their colours,
## so players learn which items and abilities feed which number.

const HP_COLOR := Color("e04f5f")
const ATK_COLOR := Color("f08a24")
const AP_COLOR := Color("9b5de5")
const DEF_COLOR := Color("5f7f99")
const WARD_COLOR := Color("7a6ff0")
const HASTE_COLOR := Color("3e9bd6")
const RATING_NAMES: Array[String] = ["Toughness", "Damage", "Mobility", "Control", "Difficulty"]


static func tag(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]


static func atk(v: float) -> String:
	return tag("%d ATK" % roundi(v), ATK_COLOR)


static func ap(v: float) -> String:
	return tag("%d AP" % roundi(v), AP_COLOR)


## "●●●○○"-style pips for a 1-5 rating.
static func pips(n: int) -> String:
	n = clampi(n, 0, 5)
	return "●".repeat(n) + "○".repeat(5 - n)


## Menu card: lean, rating pips and base stats at Lv1 -> max level (before passives).
static func for_hero(data: HeroData) -> String:
	var lo := HeroStats.at_level(data, 1)
	var hi := HeroStats.at_level(data, Leveling.CROWN_LEVEL)
	var t := "[b]%s hero[/b]   " % data.lean
	var parts: Array[String] = []
	for i in RATING_NAMES.size():
		var r: int = data.ratings[i] if i < data.ratings.size() else 3
		parts.append("%s %s" % [RATING_NAMES[i], pips(r)])
	t += "  ".join(parts.slice(0, 3)) + "\n" + "  ".join(parts.slice(3)) + "\n"
	t += "%s  %d → %d\n" % [tag("Health", HP_COLOR), roundi(lo.hp), roundi(hi.hp)]
	t += "%s  %d → %d   (one basic attack)\n" % [tag("Attack Power", ATK_COLOR), roundi(lo.atk), roundi(hi.atk)]
	t += "%s  %d → %d   (added to abilities)\n" % [tag("Ability Power", AP_COLOR), roundi(lo.ap), roundi(hi.ap)]
	t += "Attack speed %.2f/s · Range %.1f m %s" % [1.0 / data.attack_interval, data.attack_range, "melee" if data.attack_range < 3.0 else "ranged"]
	if data.armor > 0.0 or data.ward > 0.0:
		t += "\n%s %d · %s %d" % [tag("Armor", DEF_COLOR), roundi(data.armor), tag("Ward", WARD_COLOR), roundi(data.ward)]
	return t


## In-match line: the live numbers with items, perks and level.
static func live(h: HeroState) -> String:
	var parts: Array[String] = [
		tag("%d HP" % roundi(h.max_hp), HP_COLOR),
		atk(h.attack_damage),
		ap(h.ability_power),
		"%.2f atk/s" % (1.0 / maxf(0.01, h.attack_interval)),
	]
	if h.armor > 0.0:
		parts.append(tag("Armor %d (-%d%%)" % [roundi(h.armor), roundi(100.0 * HeroStats.cut(h.armor))], DEF_COLOR))
	if h.ward > 0.0:
		parts.append(tag("Ward %d (-%d%%)" % [roundi(h.ward), roundi(100.0 * HeroStats.cut(h.ward))], WARD_COLOR))
	if h.cooldown_haste > 0.0:
		parts.append(tag("Haste %d%%" % roundi(100.0 * h.cooldown_haste), HASTE_COLOR))
	return "  ·  ".join(parts)


## How an ability scales, for tooltips: "+80% AP".
static func scaling(a: AbilityData) -> String:
	var parts: Array[String] = []
	if a.ap_ratio > 0.0:
		parts.append(tag("+%d%% AP" % roundi(a.ap_ratio * 100.0), AP_COLOR))
	if a.atk_ratio > 0.0:
		parts.append(tag("+%d%% ATK" % roundi(a.atk_ratio * 100.0), ATK_COLOR))
	if a.hp_ratio > 0.0:
		parts.append(tag("+%d%% max HP" % roundi(a.hp_ratio * 100.0), HP_COLOR))
	if a.heal_ap_ratio > 0.0:
		parts.append(tag("shield/heal +%d%% AP" % roundi(a.heal_ap_ratio * 100.0), AP_COLOR))
	return " ".join(parts)
