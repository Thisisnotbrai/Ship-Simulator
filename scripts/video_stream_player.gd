extends Node

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready():
	# Set window size
	DisplayServer.window_set_size(Vector2i(1280, 828))

	# Optional: center the window
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position((screen_size - window_size) / 2)

	# Video setup
	if video_player:
		video_player.autoplay = true
		video_player.expand = true  # makes it stretch to node size
