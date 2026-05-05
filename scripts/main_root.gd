extends Node3D

var cursor_point = load ("res://assets/pointer/hand_point.png")
var cursor_drag = load ("res://assets/pointer/hand_open.png")

var current_cursor = "point"

func set_cursor(state: String):
	if state == current_cursor:
		return
	
	current_cursor = state
	
	match state:
		"point":
			Input.set_custom_mouse_cursor(cursor_point, Input.CURSOR_ARROW, Vector2(0, 0))
		"drag":
			Input.set_custom_mouse_cursor(cursor_drag, Input.CURSOR_ARROW, Vector2(0, 0))
