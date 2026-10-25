class_name AimButton
extends Button
## An ability button you can drag to aim, like a second thumbstick: press, drag the way
## you want the shot to go, let go to cast. A tap without a drag casts straight away.
## Drags past the button's edge keep aiming (the stick follows the thumb).
## use_mouse: desktop mouse drives it instead of touches (mouse-as-touch playtests).

signal cast(screen_dir: Vector2)

## Drag this far (px) before it counts as aiming rather than a tap.
const DEADZONE := 18.0
const STICK_RADIUS := 90.0

var use_mouse := true
## True while a drag is aiming; aim_dir is the drag in screen space (y up, length 0..1).
var aiming := false
var aim_dir := Vector2.ZERO
var _held := false
var _start := Vector2.ZERO
var _touch_index := -1


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	# Pressing is handled by hand so a drag can steer before the cast.
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button_mask = 0


func _gui_input(event: InputEvent) -> void:
	if disabled:
		if not event is InputEventMouseMotion and not event is InputEventScreenDrag:
			_reset()
		return
	if event is InputEventScreenTouch and not use_mouse:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_begin(event.position)
		elif not event.pressed and event.index == _touch_index:
			_finish()
		accept_event()
	elif event is InputEventScreenDrag and not use_mouse:
		if event.index == _touch_index:
			_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and use_mouse and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		elif _held:
			_finish()
		accept_event()
	elif event is InputEventMouseMotion and use_mouse and _held:
		_drag(event.position)
		accept_event()


func cancel() -> void:
	_reset()


func _begin(at: Vector2) -> void:
	_held = true
	_start = at
	aiming = false
	aim_dir = Vector2.ZERO
	queue_redraw()


func _drag(at: Vector2) -> void:
	var d := at - _start
	if not aiming and d.length() < DEADZONE:
		return
	aiming = true
	aim_dir = Vector2(d.x, -d.y).limit_length(STICK_RADIUS) / STICK_RADIUS
	queue_redraw()


func _finish() -> void:
	var dir := aim_dir.normalized() if aiming and aim_dir.length() > 0.05 else Vector2.ZERO
	_reset()
	cast.emit(dir)


func _reset() -> void:
	_held = false
	aiming = false
	aim_dir = Vector2.ZERO
	_touch_index = -1
	queue_redraw()


func _draw() -> void:
	if not aiming:
		return
	var c := _start
	draw_circle(c, STICK_RADIUS, Color(1, 1, 1, 0.10))
	draw_arc(c, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(c + Vector2(aim_dir.x, -aim_dir.y) * STICK_RADIUS, 26.0, Color(1, 1, 1, 0.6))
