extends RigidBody3D

# =========================
# CONFIG
# =========================
@export var move_speed: float = 20.0
@export var damage_on_hit: float = 20.0
@export var water_y: float = 0.0

@export var tail_frequency: float = 10.0
@export var tail_strength: float = 3.0
@export var patrol_distance: float = 10000.0

@export var rise_height: float = 3.0
@export var rise_speed: float = 2.0
@export var surface_time: float = 3.0
@export var disappear_time: float = 1.0
@export var hidden_y: float = -20.0

@export var resurface_interval_min: float = 5.0
@export var resurface_interval_max: float = 12.0

@export var spawn_radius: float = 50.0

@export var shadow_scene: PackedScene
@export var warning_time: float = 1.5

@export var relocate_speed: float = 15.0  # underwater swim speed toward target

# =========================
# INTERNAL
# =========================
var swim_time: float = 0.0
var start_position: Vector3

var is_turning: bool = false
var turn_timer: float = 0.0
var turn_target_angle: float = 0.0
const TURN_DURATION: float = 1.0

var resurface_timer: float = 0.0
var resurface_interval: float = 0.0

var shadow_instance: Node3D = null
var target_surface_position: Vector3

enum {
	PATROL,
	RELOCATE,   # swim invisibly underwater toward target before surfacing
	WARNING,
	ASCEND,
	SURFACE_SWIM,
	DESCEND,
	HIDDEN
}

var state = PATROL
var state_timer: float = 0.0
var target_y: float


# =========================
# READY
# =========================
func _ready():
	linear_damp = 0.8
	angular_damp = 6.0
	lock_rotation = true
	gravity_scale = 0

	start_position = global_position
	target_y = water_y

	visible = false
	global_position.y = hidden_y

	_schedule_next_resurface()
	add_to_group("enemies")


# =========================
# MAIN LOOP
# =========================
func _physics_process(delta):
	swim_time += delta
	state_timer += delta

	match state:

		PATROL:
			_update_patrol(delta)
			resurface_timer -= delta
			if resurface_timer <= 0.0 and not is_turning:
				_start_relocate()

		# Shark swims invisibly at hidden_y toward target_surface_position.
		# No teleport — position changes gradually so the radar never blinks.
		RELOCATE:
			visible = false
			global_position.y = hidden_y
			linear_velocity.y = 0.0

			var flat_target = Vector3(target_surface_position.x, hidden_y, target_surface_position.z)
			var flat_self   = Vector3(global_position.x,        hidden_y, global_position.z)
			var to_target   = flat_target - flat_self

			if to_target.length() > 1.0:
				# Face and swim toward the target
				var desired_angle = atan2(-to_target.x, -to_target.z)
				rotation.y = lerp_angle(rotation.y, desired_angle, 5.0 * delta)
				apply_central_force(-transform.basis.z * relocate_speed * move_speed * delta)
			else:
				# Close enough — lock position and start warning
				global_position.x = target_surface_position.x
				global_position.z = target_surface_position.z
				linear_velocity = Vector3.ZERO
				_start_warning()

		WARNING:
			global_position.y = hidden_y
			linear_velocity = Vector3.ZERO
			if state_timer >= warning_time:
				_start_ascend()

		ASCEND:
			visible = true
			linear_velocity.y = 0.0
			global_position.y = move_toward(global_position.y, target_y, rise_speed * delta)
			_update_forward_motion()
			if abs(global_position.y - target_y) < 0.1:
				global_position.y = target_y
				state = SURFACE_SWIM
				state_timer = 0.0

		SURFACE_SWIM:
			visible = true
			global_position.y = target_y
			linear_velocity.y = 0.0
			_update_forward_motion()
			if state_timer >= surface_time:
				state = DESCEND
				state_timer = 0.0

		DESCEND:
			visible = true
			linear_velocity.y = 0.0
			global_position.y = move_toward(global_position.y, hidden_y, rise_speed * delta)
			_update_forward_motion()
			if abs(global_position.y - hidden_y) < 0.1:
				global_position.y = hidden_y
				visible = false
				state = HIDDEN
				state_timer = 0.0
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO

		HIDDEN:
			global_position.y = hidden_y
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			if state_timer >= disappear_time:
				_respawn()


# =========================
# RELOCATE START
# =========================
func _start_relocate():
	# Pick the target now, but don't jump there — let RELOCATE swim to it.
	var angle  = randf() * TAU
	var radius = randf() * spawn_radius
	target_surface_position = start_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

	state = RELOCATE
	state_timer = 0.0


# =========================
# WARNING START
# =========================
func _start_warning():
	state = WARNING
	state_timer = 0.0

	if shadow_scene:
		shadow_instance = shadow_scene.instantiate()
		get_tree().current_scene.add_child(shadow_instance)
		shadow_instance.global_position = Vector3(
			target_surface_position.x,
			water_y + 0.05,
			target_surface_position.z
		)


# =========================
# ASCEND START
# =========================
func _start_ascend():
	# Shark is already AT target_surface_position (swam there in RELOCATE).
	# No teleport needed.
	state = ASCEND
	state_timer = 0.0

	target_y = water_y + rise_height
	visible = true

	if shadow_instance:
		shadow_instance.queue_free()
		shadow_instance = null


# =========================
# SCHEDULE RESURFACE
# =========================
func _schedule_next_resurface():
	resurface_interval = randf_range(resurface_interval_min, resurface_interval_max)
	resurface_timer = resurface_interval


# =========================
# PATROL
# =========================
func _update_patrol(delta):
	var pos = global_position
	pos.y = hidden_y
	global_position = pos

	linear_velocity.y = 0.0

	var travel = global_position.distance_to(start_position)

	if not is_turning and travel >= patrol_distance:
		_begin_turn()

	if is_turning:
		turn_timer += delta
		var t = clamp(turn_timer / TURN_DURATION, 0.0, 1.0)
		rotation.y = lerp_angle(rotation.y, turn_target_angle, t)
		angular_velocity = Vector3.ZERO
		if turn_timer >= TURN_DURATION:
			rotation.y = turn_target_angle
			is_turning = false
			turn_timer = 0.0
			start_position = global_position
		return

	_update_forward_motion()


# =========================
# MOVEMENT
# =========================
func _update_forward_motion():
	var thrust = (sin(swim_time * tail_frequency * TAU) - 1.6) * move_speed
	apply_central_force(-transform.basis.z * thrust)

	var wiggle = cos(swim_time * tail_frequency * TAU) * tail_strength * get_physics_process_delta_time()
	angular_velocity.y = clamp(angular_velocity.y + wiggle, -1.2, 1.2)


# =========================
# TURN
# =========================
func _begin_turn():
	is_turning = true
	turn_timer = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	turn_target_angle = rotation.y + PI


# =========================
# RESPAWN
# =========================
func _respawn():
	# No random position jump here either — just reset to current hidden spot
	# and go back to PATROL. The next resurface will use RELOCATE to swim
	# smoothly to wherever it needs to be.
	global_position.y = hidden_y
	target_y = water_y + rise_height

	visible = false
	state = PATROL
	state_timer = 0.0

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	_schedule_next_resurface()


# =========================
# DAMAGE
# =========================
func _on_body_entered(body):
	if body == null:
		return

	if body.is_in_group("player"):
		body.health -= damage_on_hit
		if body.health <= 0:
			body.trigger_game_over()
