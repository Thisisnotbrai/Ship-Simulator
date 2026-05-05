extends CanvasLayer

@onready var wheel = $MainLayout/RightPanel/VBoxContainer/SteeringWheel
@onready var ship = $"../boat"
@onready var rudder_label = $MainLayout/RightPanel/VBoxContainer/RudderLabel

func _physics_process(delta):
	var steering = wheel.get_steering_value()

	# Smooth steering
	ship.steering_input = lerp(ship.steering_input, steering, 2 * delta)

	# UPDATE UI (NEW)
	rudder_label.text = "Rudder: " + str(round(steering * 30)) + "°"
