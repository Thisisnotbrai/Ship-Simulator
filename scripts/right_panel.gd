extends Control

@onready var speed_label = $VBoxContainer/SpeedLabel
@onready var throttle = $VBoxContainer/ThrottleBar
@onready var rudder_label = $VBoxContainer/RudderLabel
@onready var ship = get_tree().get_first_node_in_group("player")

var displayed_speed := 0.0   # smoothed speed
var displayed_rudder := 0.0  # smoothed rudder

func _process(delta):
	if not ship:
		return

	# =========================
	# 🚢 REAL SPEED (knots)
	# =========================
	var velocity = ship.linear_velocity.length()  # m/s
	var speed_knots = velocity * 1.94384

	# smooth it (prevents jitter)
	displayed_speed = lerp(displayed_speed, speed_knots, 2.0 * delta)

	speed_label.text = "Speed: " + str(round(displayed_speed)) + " knots"

	# throttle bar (0–100%)
	throttle.value = clamp(displayed_speed * 3, 0, 100)


	# =========================
	# ⚓ REAL RUDDER ANGLE
	# =========================
	var rudder_angle = ship.steering_input * 30.0  # max 30 degrees

	# smooth it
	displayed_rudder = lerp(displayed_rudder, rudder_angle, 5.0 * delta)

	rudder_label.text = "Rudder: " + str(round(displayed_rudder)) + "°"	
