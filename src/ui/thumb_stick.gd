class_name ThumbStick
extends Control
## Floating joystick for the left thumb: it appears wherever the thumb lands in its zone.
## output is in screen space, y up, length 0..1.
## use_mouse lets desktop playtests drive it with the mouse ("mouse as touch").

const RADIUS := 110.0
const KNOB_RADIUS := 44.0

var output := Vector2.ZERO
var use_mouse := true
var _active := false
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not use_mouse:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_begin(event.position)
		elif not event.pressed and event.index == _touch_index:
			_end()
		accept_event()
	elif event is InputEventScreenDrag and not use_mouse:
		if event.index == _touch_index:
			_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and use_mouse and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		else:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and use_mouse and _active:
		_drag(event.position)
		accept_event()


func release() -> void:
	_end()


func _begin(at: Vector2) -> void:
	_active = true
	_center = at
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _drag(at: Vector2) -> void:
	_knob = (at - _center).limit_length(RADIUS)
	output = Vector2(_knob.x, -_knob.y) / RADIUS
	queue_redraw()


func _end() -> void:
	_active = false
	_touch_index = -1
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _active:
		draw_circle(_center, RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(_center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(_center + _knob, KNOB_RADIUS, Color(1, 1, 1, 0.55))
	else:
		# Ghost hint where a thumb usually rests.
		var hint := Vector2(size.x * 0.45, size.y * 0.55)
		draw_arc(hint, RADIUS * 0.8, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		draw_circle(hint, KNOB_RADIUS * 0.8, Color(1, 1, 1, 0.08))
