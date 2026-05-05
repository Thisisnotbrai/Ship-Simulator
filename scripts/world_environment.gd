extends WorldEnvironment

var time_of_day: float = 0.0

func _process(_delta: float) -> void:
	var t := Time.get_datetime_dict_from_system()
	# Map 0–24h → 0.0–1.0
	time_of_day = (t.hour + t.minute / 60.0 + t.second / 3600.0) / 24.0
	_update_environment()

func _update_environment() -> void:
	self.environment.ambient_light_energy = clamp(sin(time_of_day * TAU) * 0.5, 0.05, 0.5)
	var sky_mat = self.environment.sky.sky_material as PanoramaSkyMaterial
	sky_mat.energy_multiplier = clamp(sin(time_of_day * TAU), 0.05, 1.0)
