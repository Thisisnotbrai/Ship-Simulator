extends Node3D

@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment

var time_of_day: float = 0.5
var cycle_speed: float = 0.05

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta * cycle_speed, 1.0)
	_update_environment()

func _update_environment() -> void:
	var sun_angle = (time_of_day * 360.0) - 90.0
	sun.rotation_degrees.x = sun_angle

	sun.light_energy = clamp(sin(time_of_day * PI), 0.0, 1.0)

	world_env.environment.ambient_light_energy = clamp(sin(time_of_day * PI) * 0.5, 0.05, 0.5)
