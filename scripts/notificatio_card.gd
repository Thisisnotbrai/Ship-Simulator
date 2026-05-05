extends Control

@export var auto_hide_time: float = 10.0  # seconds

var ok_button: Button
var message_label: Label
var timer: Timer

func _ready():
	# Get nodes
	ok_button = $OkButton
	message_label = $MessageLabel

	# Create timer dynamically
	timer = Timer.new()
	timer.wait_time = auto_hide_time
	timer.one_shot = true
	add_child(timer)

	# Connect signals
	ok_button.pressed.connect(_on_ok_pressed)
	timer.timeout.connect(_on_timer_timeout)

	# Start timer
	timer.start()

	# Show notification
	show_notification()

func set_message(text: String) -> void:
	message_label.text = text

func show_notification() -> void:
	visible = true

func hide_notification() -> void:
	queue_free()

func _on_ok_pressed() -> void:
	hide_notification()

func _on_timer_timeout() -> void:
	hide_notification()
