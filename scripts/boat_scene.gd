extends RigidBody3D

# =========================
#  BOAT SETTINGS
# =========================
@export var engine_power: float = 25.0
@export var turn_power: float = 18.0
@export var max_speed: float = 20.0
@export var water_drag: float = 4.0
@export var angular_damp_value: float = 1.5
@export var max_health: float = 100
@export var steering_wheel: Node
@export var min_turn_factor: float = 0.05
@export var turn_response: float = 2.5
@export var throttle_ramp_up: float = 0.6
@export var throttle_ramp_down: float = 1.2

# =========================
#  BUOYANCY SETTINGS
# =========================
@export var water: MeshInstance3D           # Drag your Water node here
@export var float_force: float = 120.0       # Tune this: higher = bouncier
@export var water_base_y: float = 11.057    # Your water mesh Y position

# Hull sample points (add 4 Marker3D children to your boat)
@export var hull_points: Array[Node3D] = []

# Wave parameters — must match your shader's WaveParameters uniforms exactly!
@export var wave_count: int = 0
@export var wave_steepnesses: Array[float] = []
@export var wave_amplitudes: Array[float] = []
@export var wave_directions: Array[float] = []
@export var wave_frequencies: Array[float] = []
@export var wave_speeds: Array[float] = []
@export var wave_phases: Array[float] = []

# =========================
#  CAMERA SETTINGS
# =========================
@export var cameras: Array[Camera3D] = []
@export var cam_labels: Array[String] = ["Bridge", "Stern", "Bow"]

# =========================
#  BOAT STATE
# =========================
var steering_input: float = 0.0
var steering_smoothed: float = 0.0
var telegraph_power: float = 0.0
var health: float = 100
var throttle_smoothed: float = 0.0

# =========================
#  RATE OF TURN
# =========================
var rate_of_turn: float = 0.0
var _rot_heading_samples : Array = []
var _rot_time_samples    : Array = []
var _rot_elapsed         : float = 0.0
const ROT_WINDOW : float = 6.0
const ROT_SMOOTH : float = 3.0

# =========================
#  HORN STATE
# =========================
var has_honked: bool = false
@onready var horn_sound: AudioStreamPlayer = $AudioStreamPlayer

# =========================
#  CAMERA STATE
# =========================
var current_cam_index: int = 0
var cam_canvas: CanvasLayer
var button_container: HBoxContainer

func _ready():
	linear_damp = 0.8
	angular_damp = angular_damp_value
	add_to_group("player")
	_build_cam_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	await _activate_camera(0)

# =========================
#  WAVE MATH (ported from shader)
# =========================
func P_DEG(x: float, z: float, t: float, steepness: float, amplitude: float,
		direction_deg: float, frequency: float, speed: float, phase_deg: float) -> Vector3:
	var dir = Vector2(sin(direction_deg * TAU / 360.0), cos(direction_deg * TAU / 360.0))
	var p = phase_deg * TAU / 360.0
	var dot = frequency * (dir.x * x + dir.y * z)
	var result = Vector3()
	result.x = steepness * amplitude * dir.x * cos(TAU * dot + speed * (t + p))
	result.y = steepness * sin(TAU * dot + speed * (t + p))
	result.z = steepness * amplitude * dir.y * cos(TAU * dot + speed * (t + p))
	return result

func get_water_height(world_pos: Vector3) -> float:
	if wave_count == 0:
		return water_base_y

	var t = Time.get_ticks_msec() / 1000.0
	var wave_sum = Vector3.ZERO

	for i in wave_count:
		wave_sum += P_DEG(
			world_pos.x, world_pos.z, t,
			wave_steepnesses[i],
			wave_amplitudes[i],
			wave_directions[i],
			wave_frequencies[i],
			wave_speeds[i],
			wave_phases[i]
		)

	wave_sum /= float(wave_count)  # shader averages all waves
	return water_base_y + wave_sum.y

# =========================
#  BUOYANCY
# =========================
func _apply_buoyancy():
	if hull_points.is_empty():
		# Fallback: single point at boat center if no hull points set
		var water_y = get_water_height(global_position)
		var depth = water_y - global_position.y
		if depth > 0:
			apply_central_force(Vector3.UP * float_force * depth)
		return

	for point in hull_points:
		var water_y = get_water_height(point.global_position)
		var depth = water_y - point.global_position.y
		if depth > 0:
			# Apply force AT the hull point so the boat tilts naturally
			apply_force(
				Vector3.UP * float_force * depth,
				point.global_position - global_position
			)

# =========================
#  CAMERA UI
# =========================
func _build_cam_ui():
	cam_canvas = CanvasLayer.new()
	cam_canvas.layer = 12
	add_child(cam_canvas)

	button_container = HBoxContainer.new()
	button_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button_container.position = Vector2(16, -80)
	button_container.add_theme_constant_override("separation", 8)
	cam_canvas.add_child(button_container)

	for i in cam_labels.size():
		var btn = Button.new()
		btn.text = cam_labels[i]
		btn.custom_minimum_size = Vector2(90, 48)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.75)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color(0.4, 0.6, 1.0, 0.8)
		btn.add_theme_stylebox_override("normal", style)

		var hover = style.duplicate()
		hover.bg_color = Color(0.2, 0.3, 0.5, 0.9)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_font_size_override("font_size", 15)

		var idx = i
		btn.pressed.connect(func(): _activate_camera(idx))
		button_container.add_child(btn)

func _activate_camera(index: int):
	var old_cam = cameras[current_cam_index]
	if old_cam.has_method("deactivate"):
		old_cam.deactivate()
	old_cam.current = false

	current_cam_index = index
	var new_cam = cameras[current_cam_index]
	new_cam.make_current()
	if new_cam.has_method("activate"):
		await new_cam.activate()

	_update_button_styles()

func _update_button_styles():
	for i in button_container.get_child_count():
		var btn = button_container.get_child(i) as Button
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)

		if i == current_cam_index:
			style.bg_color = Color(0.1, 0.4, 0.8, 0.95)
			style.border_color = Color(0.5, 0.8, 1.0, 1.0)
		else:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.75)
			style.border_color = Color(0.4, 0.6, 1.0, 0.8)

		btn.add_theme_stylebox_override("normal", style)

# =========================
#  GAME OVER
# =========================
func trigger_game_over():
	var game_over_ui = get_node("/root/water-scene/GameOverUI")
	game_over_ui.show_game_over()

# =========================
#  PHYSICS
# =========================
func _physics_process(delta: float):
	# ── Buoyancy ──
	_apply_buoyancy()

	var keyboard_input = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var controller_input = Input.get_action_strength("ctrl_forward") - Input.get_action_strength("ctrl_backward")
	var kb_input = controller_input if abs(controller_input) > 0.10 else keyboard_input
	var forward_input = kb_input if abs(kb_input) > 0.10 else telegraph_power

	if steering_wheel:
		steering_input = steering_wheel.get_steering_value()

	steering_smoothed = lerp(steering_smoothed, steering_input, turn_response * delta)

	var ramp_speed = throttle_ramp_up if abs(forward_input) > abs(throttle_smoothed) \
					 else throttle_ramp_down
	throttle_smoothed = lerp(throttle_smoothed, forward_input, ramp_speed * delta)

	if global_position.y < -5:
		trigger_game_over()
		return

	var forward_dir = -transform.basis.z
	var forward_speed = linear_velocity.dot(forward_dir)

	if not has_honked and abs(throttle_smoothed) > 0.01:
		has_honked = true
		horn_sound.play()

	if abs(throttle_smoothed) > 0.01:
		if abs(forward_speed) < max_speed:
			apply_central_force(forward_dir * throttle_smoothed * engine_power)

	var right_dir = transform.basis.x
	var sideways_speed = linear_velocity.dot(right_dir)
	apply_central_force(-right_dir * sideways_speed * water_drag)

	if abs(steering_smoothed) > 0.01:
		var speed_factor = clamp(abs(forward_speed) / max_speed, min_turn_factor, 1.0)
		var torque = -steering_smoothed * turn_power * speed_factor
		apply_torque(Vector3(0, torque, 0))

	var spin_drag = -angular_velocity.y * 8.0
	apply_torque(Vector3(0, spin_drag, 0))

	# ── Rate of Turn ──
	_rot_elapsed += delta
	var current_heading: float = fmod(rad_to_deg(rotation.y) + 360.0, 360.0)

	_rot_heading_samples.append(current_heading)
	_rot_time_samples.append(_rot_elapsed)

	while _rot_time_samples.size() > 1 and (float(_rot_time_samples[0]) < _rot_elapsed - ROT_WINDOW):
		_rot_time_samples.pop_front()
		_rot_heading_samples.pop_front()

	var instant_rot: float = 0.0
	if _rot_time_samples.size() >= 2:
		var dt: float = float(_rot_time_samples[_rot_time_samples.size() - 1]) - float(_rot_time_samples[0])
		if dt > 0.01:
			var dh: float = float(_rot_heading_samples[_rot_heading_samples.size() - 1]) - float(_rot_heading_samples[0])
			while dh >  180.0: dh -= 360.0
			while dh < -180.0: dh += 360.0
			instant_rot = clamp((dh / dt) * 60.0, -32.0, 32.0)

	rate_of_turn = lerp(rate_of_turn, instant_rot, ROT_SMOOTH * delta)
