class_name CameraRig
extends Node3D
## Orthographic, tilted, follow-the-hero camera. Orthographic keeps both halves of the
## lane the same size on screen, which perspective would not in a tall portrait view.

const PITCH_DEG := 52.0
## World metres visible across the screen width.
const VIEW_WIDTH := 14.0
## Look this far ahead of the hero so it sits about 40% up the screen, clear of thumbs.
const LEAD := 3.3
const DISTANCE := 40.0
const FOLLOW_SHARPNESS := 8.0
## The view stops this far (metres) past the end walls, so it never shows the void
## beyond the map. Screen bands covered by the HUD don't count as visible.
const EDGE_MARGIN := 0.8
## Your hero always stays at least this far (metres) inside the left and right screen edges.
const HERO_SIDE_MARGIN := 1.4

var camera: Camera3D
var seat := MatchSim.BLUE
var half_length := 30.0
## Widest point of the map (side pockets and their walls), metres from the centre line.
var half_width := 12.0
var _focus := Vector3.ZERO


func _init() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = VIEW_WIDTH
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)


func _ready() -> void:
	camera.make_current()
	_apply()


func set_seat(new_seat: int) -> void:
	seat = new_seat
	_apply()


func follow(hero_world: Vector3, delta: float, snap := false) -> void:
	var forward := Vector3(0, 0, -1) if seat == MatchSim.BLUE else Vector3(0, 0, 1)
	var target := hero_world + forward * LEAD
	target.x = _clamp_side(hero_world.x)
	target.y = 0.0
	target.z = _clamp_to_map(target.z, forward.z)
	if snap:
		_focus = target
	else:
		_focus = _focus.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	_apply()


## Across the lane: drift toward the hero's side, keep the view inside the map's sides
## when it is narrower than the map, and never let the hero leave the screen.
func _clamp_side(hero_x: float) -> float:
	var hw := half_view_width()
	var x := hero_x * 0.75
	var room := half_width + EDGE_MARGIN - hw
	x = clampf(x, -room, room) if room > 0.0 else 0.0
	var keep := maxf(0.0, hw - HERO_SIDE_MARGIN)
	return clampf(x, hero_x - keep, hero_x + keep)


## Half the ground width on screen, in metres.
func half_view_width() -> float:
	var vp := get_viewport()
	if vp == null:
		return VIEW_WIDTH / 2.0
	var s := vp.get_visible_rect().size
	if s.x <= 0.0 or s.y <= 0.0:
		return VIEW_WIDTH / 2.0
	var w := camera.size if camera.keep_aspect == Camera3D.KEEP_WIDTH else camera.size * s.x / s.y
	return w / 2.0


## Keeps the visible stretch of ground (between the HUD bands) inside the map. Along the
## lane the ground visible above and below the focus is fixed for a given screen, so
## the focus just gets a range; if the map is shorter than the view, it centres.
func _clamp_to_map(z: float, fwd_z: float) -> float:
	var vp := get_viewport()
	if vp == null:
		return z
	var s := vp.get_visible_rect().size
	if s.x <= 0.0 or s.y <= 0.0:
		return z
	var h := camera.size if camera.keep_aspect == Camera3D.KEEP_HEIGHT else camera.size * s.y / s.x
	var per_px := h / s.y
	var sin_p := sin(deg_to_rad(PITCH_DEG))
	var ahead := (h / 2.0 - Hud.TOP_BAND * per_px) / sin_p
	var behind := (h / 2.0 - Hud.BOTTOM_BAND * per_px) / sin_p
	var edge := half_length + EDGE_MARGIN
	var along := z * fwd_z  # Position along the view direction (fwd_z is +-1).
	var lo := -edge + behind
	var hi := edge - ahead
	along = (lo + hi) / 2.0 if lo > hi else clampf(along, lo, hi)
	return along * fwd_z


## Portrait screens show VIEW_WIDTH metres across. Wider screens (a desktop browser) keep
## the same vertical view a 9:16 phone gets and simply see more to the sides.
func _fit_to_screen() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var s := vp.get_visible_rect().size
	if s.y <= 0.0:
		return
	if s.x / s.y > 9.0 / 16.0:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = VIEW_WIDTH * 16.0 / 9.0
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = VIEW_WIDTH


func _apply() -> void:
	_fit_to_screen()
	var yaw := 0.0 if seat == MatchSim.BLUE else PI
	rotation = Vector3(deg_to_rad(-PITCH_DEG), yaw, 0.0)
	position = _focus + transform.basis.z * DISTANCE
