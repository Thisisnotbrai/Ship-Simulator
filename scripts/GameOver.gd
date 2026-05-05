extends CanvasLayer

@onready var retry_button = $Retry
@onready var quit_button = $Quit

func _ready():
	visible = false
	
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_game_over():
	visible = true
	get_tree().paused = true   # pause the game

func _on_retry_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().quit()


func _on_terrain_3d_tree_entered() -> void:
	pass # Replace with function body.
