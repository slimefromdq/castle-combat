class_name HeroLettering
## Each hero's name has its own lettering (all SIL Open Font License, see
## assets/fonts/heroes/licenses). Gameplay numbers and labels use Barlow Condensed so
## they stay crisp. Every hero font falls back to Barlow Condensed for any glyph it
## lacks, so odd characters never show as boxes.

const DIR := "res://assets/fonts/heroes/"
## Hero id -> [font file, weight for variable fonts (0 = static), size scale, accent].
## Size scale evens out fonts that run small or large at the same point size.
const STYLES := {
	&"avery": ["Cinzel-VF.ttf", 800, 0.92, Color("ffe08a")],
	&"jose": ["Rye-Regular.ttf", 0, 0.9, Color("ffb35c")],
	&"jack": ["Limelight-Regular.ttf", 0, 0.95, Color("c9a6ff")],
	&"ahab": ["PirataOne-Regular.ttf", 0, 1.1, Color("8fd3ff")],
	&"slayer": ["MetalMania-Regular.ttf", 0, 1.05, Color("ff6b6b")],
	&"huddle": ["Sniglet-ExtraBold.ttf", 0, 1.0, Color("ffe36b")],
	&"poppet": ["MysteryQuest-Regular.ttf", 0, 1.05, Color("ff9ccf")],
	&"tot": ["UnifrakturCook-Bold.ttf", 0, 1.05, Color("f5d76e")],
	&"serpent": ["PlayfairDisplay-Italic-VF.ttf", 900, 1.0, Color("7be35a")],
	&"fermata": ["BodoniModa-Italic-VF.ttf", 700, 1.0, Color("f3c6ff")],
	&"kosmonaut": ["Orbitron-VF.ttf", 800, 0.82, Color("9ff0ff")],
}

static var _fonts := {}
static var _hud: FontFile
static var _hud_bold: FontFile


## Barlow Condensed SemiBold: the gameplay HUD's type.
static func hud_font() -> FontFile:
	if _hud == null:
		_hud = load(DIR + "BarlowCondensed-SemiBold.ttf")
	return _hud


static func hud_bold() -> FontFile:
	if _hud_bold == null:
		_hud_bold = load(DIR + "BarlowCondensed-Bold.ttf")
	return _hud_bold


## The hero's name lettering. Unknown ids get the bold HUD font.
static func font(hero_id: StringName) -> Font:
	if _fonts.has(hero_id):
		return _fonts[hero_id]
	var f: Font = hud_bold()
	if STYLES.has(hero_id):
		var st: Array = STYLES[hero_id]
		var file: FontFile = load(DIR + st[0])
		if file != null:
			var v := FontVariation.new()
			v.base_font = file
			if st[1] > 0:
				v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): st[1]}
			v.fallbacks = [hud_bold()]
			f = v
	_fonts[hero_id] = f
	return f


static func size_scale(hero_id: StringName) -> float:
	return STYLES[hero_id][2] if STYLES.has(hero_id) else 1.0


static func accent(hero_id: StringName) -> Color:
	return STYLES[hero_id][3] if STYLES.has(hero_id) else Color.WHITE


## Applies the hero's lettering to a label at roughly `size` points.
static func apply(l: Label, hero_id: StringName, size: int) -> void:
	l.add_theme_font_override("font", font(hero_id))
	l.add_theme_font_size_override("font_size", int(round(size * size_scale(hero_id))))
