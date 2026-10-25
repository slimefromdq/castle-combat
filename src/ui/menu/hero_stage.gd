class_name HeroStage
extends Control
## A little 3D stage for the menu: the hero's match model (your blue) on a paper
## pedestal, inked with a cel outline, slowly turning. Transparent, so the paper
## collage behind it shows through.

const OUTLINE := 0.045

var spin_speed := 0.55
var _viewport: SubViewport
var _turntable: Node3D
var _hero: Node3D
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	# Shown through a TextureRect (not a SubViewportContainer) so the 3D view never
	# props its container open: the viewport just follows this control's size.
	var tex := TextureRect.new()
	tex.texture = _viewport.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex)
	resized.connect(_fit_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.96, 0.9)
	env.environment.ambient_light_energy = 0.75
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 2.7, -5.4)
	world.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.45, 0))
	_turntable = Node3D.new()
	world.add_child(_turntable)
	# Pedestal: a kraft-paper drum with an inked rim.
	var ped := Node3D.new()
	world.add_child(ped)
	UnitFactory.part(ped, UnitFactory.cylinder(1.08, 1.12, 0.26, 40), Zine.INK, Vector3(0, -0.14, 0))
	UnitFactory.part(ped, UnitFactory.cylinder(1.0, 1.0, 0.28, 40), Zine.KRAFT, Vector3(0, -0.12, 0))
	UnitFactory.part(ped, UnitFactory.cylinder(0.78, 0.78, 0.02, 40), Color(Palette.ALLY, 0.75), Vector3(0, 0.025, 0), Vector3.ZERO, true)


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit_viewport)


## Render at screen resolution (the canvas may be scaled up on big phones and monitors).
func _fit_viewport() -> void:
	var k := 1.0
	if is_inside_tree():
		k = clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 2.0)
	_viewport.size = Vector2i(maxi(int(size.x * k), 8), maxi(int(size.y * k), 8))


func show_hero(data: HeroData) -> void:
	if _hero:
		_hero.queue_free()
	_hero = Node3D.new()
	_turntable.add_child(_hero)
	UnitFactory.hero_body(_hero, data.shape, Palette.ALLY)
	_ink(_hero)
	_hero.scale = Vector3.ONE * (1.0 if data.shape != "cone" else 1.15)


## Inverted-hull outline: a slightly grown, front-culled black copy of every part.
func _ink(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var hull := MeshInstance3D.new()
			hull.mesh = mi.mesh
			var m := StandardMaterial3D.new()
			m.albedo_color = Zine.INK
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_FRONT
			m.grow = true
			m.grow_amount = OUTLINE
			hull.material_override = m
			hull.position = mi.position
			hull.rotation = mi.rotation
			root.add_child(hull)


func _process(delta: float) -> void:
	_t += delta
	_turntable.rotation.y = sin(_t * spin_speed) * 0.75
	_turntable.position.y = absf(sin(_t * 2.2)) * 0.06
