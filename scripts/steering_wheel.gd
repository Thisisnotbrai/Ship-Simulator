extends TextureRect

@export var max_rotation: float = 90.0
@export var sensitivity: float = 4.0
@export var response_speed: float = 8.0
@export var auto_center_speed: float = 2.5

var dragging: bool = false
var current_rotation: float = 0.0
var target_rotation: float = 0.0


func _ready():
	pivot_offset = size / 2


func _notification(what):
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_PARENTED:
		pivot_offset = size / 2


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed

	elif event is InputEventMouseMotion and dragging:
		target_rotation += event.relative.x * sensitivity
		target_rotation = clamp(target_rotation, -max_rotation, max_rotation)


func _process(delta):
	# smooth steering
	current_rotation = lerp(current_rotation, target_rotation, response_speed * delta)

	# auto center when not dragging
	if not dragging:
		target_rotation = lerp(target_rotation, 0.0, auto_center_speed * delta)

	# apply rotation (visual)
	rotation_degrees = current_rotation


func get_steering_value() -> float:
	var value = current_rotation / max_rotation

	# deadzone
	if abs(value) < 0.05:
		return 0.0

	return clamp(value, -1.0, 1.0)
