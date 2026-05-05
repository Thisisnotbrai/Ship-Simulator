extends GPUParticles3D

@onready var rain_sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Wind settings
const WIND_BASE_DIRECTION := Vector3(1.0, 0.0, 0.3)   # Primary wind bearing (X/Z)
const WIND_BASE_STRENGTH := 12.0                        # Base horizontal speed (m/s)
const WIND_GUST_STRENGTH := 8.0                         # Extra speed added during gusts
const WIND_GUST_FREQUENCY := 0.18                       # How fast gusts cycle
const WIND_SHIFT_FREQUENCY := 0.05                      # How fast direction drifts

var rain_material: ParticleProcessMaterial
var time: float = 0.0

func _ready() -> void:
	emitting = true
	amount = 500000
	lifetime = 2.0
	custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))

	rain_material = process_material as ParticleProcessMaterial
	rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Widen the spawn box upwind so blown drops stay visible longer
	rain_material.emission_box_extents = Vector3(120, 1, 120)

	# Tilt the fall direction into the wind (~25° lean)
	var wind_dir := WIND_BASE_DIRECTION.normalized()
	rain_material.direction = (Vector3(wind_dir.x * 0.45, -1.0, wind_dir.z * 0.45)).normalized()
	rain_material.spread = 2.0                          # Tiny spread for natural variation

	rain_material.initial_velocity_min = 22.0
	rain_material.initial_velocity_max = 32.0
	rain_material.gravity = Vector3(
		wind_dir.x * WIND_BASE_STRENGTH,               # Horizontal gravity = wind push
		-9.8,
		wind_dir.z * WIND_BASE_STRENGTH
	)

	rain_material.turbulence_enabled = true
	rain_material.turbulence_noise_strength = 1.8       # Ripple / micro-gusts
	rain_material.turbulence_noise_scale = 0.4
	rain_material.turbulence_noise_speed_random = 0.3
	rain_material.turbulence_influence_min = 0.04
	rain_material.turbulence_influence_max = 0.10

	rain_sound.play()

func _process(delta: float) -> void:
	time += delta

	# --- Gust simulation ---
	# Combine two sine waves at different frequencies for irregular gusts
	var gust: float = (
		sin(time * WIND_GUST_FREQUENCY * TAU) * 0.6 +
		sin(time * WIND_GUST_FREQUENCY * TAU * 2.3 + 1.1) * 0.4
	) * 0.5 + 0.5                                       # Remap to 0–1

	var current_strength: float = WIND_BASE_STRENGTH + gust * WIND_GUST_STRENGTH

	# --- Slow directional drift (wind "veering") ---
	var angle_drift: float = sin(time * WIND_SHIFT_FREQUENCY * TAU) * 0.25  # ±~14°
	var drifted_dir := Vector3(
		cos(angle_drift) * WIND_BASE_DIRECTION.x - sin(angle_drift) * WIND_BASE_DIRECTION.z,
		0.0,
		sin(angle_drift) * WIND_BASE_DIRECTION.x + cos(angle_drift) * WIND_BASE_DIRECTION.z
	).normalized()

	# Apply wind to gravity so particles accelerate sideways mid-flight
	rain_material.gravity = Vector3(
		drifted_dir.x * current_strength,
		-9.8,
		drifted_dir.z * current_strength
	)

	# Tilt emission direction to match current wind lean
	rain_material.direction = Vector3(
		drifted_dir.x * 0.45, -1.0, drifted_dir.z * 0.45
	).normalized()

	# Emitting cycle (60 s on / 30 s off)
	emitting = fmod(time, 90.0) < 60.0
