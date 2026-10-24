class_name CameraRig
extends Node3D
## Orthographic, tilted, follow-the-hero camera. Orthographic keeps both halves of the
## lane the same size on screen, which perspective would not in a tall portrait view.

const PITCH_DEG := 52.0
## World metres visible across the screen width.
const VIEW_WIDTH := 16.0
## Look this far ahead of the hero so it sits about 40% up the screen, clear of thumbs.
const LEAD := 3.3
const DISTANCE := 40.0
const FOLLOW_SHARPNESS := 8.0

var camera: Camera3D
var seat := MatchSim.BLUE
var half_length := 30.0
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
	target.x = clampf(target.x * 0.6, -2.5, 2.5)
	target.y = 0.0
	target.z = clampf(target.z, -(half_length - 8.0), half_length - 8.0)
	if snap:
		_focus = target
	else:
		_focus = _focus.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	_apply()


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
