extends Node3D

@export var move_speed := 5.0
@export var player: Node3D

func _ready():
	add_to_group("enemies")
	print("DummyEnemy added to group at: ", global_position)
	print("Player assigned: ", player)

func _process(delta):
	if player:
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * move_speed * delta
