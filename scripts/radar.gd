extends Node2D

# =============================================================
#  CONFIG & EXPORTS
# =============================================================
@export_category("Radar Settings")
@export var radar_radius    : float = 65.0
@export var expanded_radius : float = 280.0
@export var radar_range     : float = 1000.0

@export_group("Sweep & Visuals")
@export var sweep_speed     : float = TAU / 3.0
@export var sweep_buckets   : int   = 72
@export var ring_count      : int   = 3
@export var trail_length    : int   = 20
@export var player_trail_length : int = 30
@export var trail_interval  : float = 0.5

@export_category("ARPA Settings")
## Minimum closing distance (in world units) that triggers a warning.
@export var arpa_safe_distance : float = 120.0
## How far ahead (seconds) TCPA must be to count as a real threat.
@export var arpa_max_tcpa      : float = 30.0

# =============================================================
#  DATA STRUCTURES
# =============================================================
enum RadarMode { NORMAL, EXPANDED }

class TargetData extends RefCounted:
	var node: Node3D
	var trails: Array[Vector3] = []

	var prev_pos: Vector3
	var prev_time: float = 0.0

	# Smoothed velocity (EMA) — never raw frame delta
	var vel_ema: Vector3 = Vector3.ZERO
	# How many valid samples collected since last reset
	var sample_count: int = 0

	# ARPA State
	var dcpa: float = 0.0
	var tcpa: float = 0.0
	var cpa_radar: Vector2 = Vector2.ZERO
	var warning: bool = false

# =============================================================
#  CONSTANTS
# =============================================================

# Maximum distance (world units) a target may move in one frame
# before we treat it as a teleport and reset its ARPA data.
# At move_speed≈20 and 60 fps that's ~0.5 u/frame; 8.0 gives plenty of headroom.
const JUMP_THRESHOLD : float = 8.0

# Smoothing factor for EMA (0 = no smoothing, 1 = never updates).
# 0.85 keeps the line very stable; lower it if you want faster response.
const EMA_ALPHA      : float = 0.85

# Minimum valid samples before ARPA lines are drawn for a target.
const MIN_SAMPLES    : int   = 5

# =============================================================
#  STATE
# =============================================================
var mode : RadarMode = RadarMode.NORMAL
var ship : Node3D

var overlay     : ColorRect
var default_pos : Vector2

var _sweep_angle : float = 0.0
var _sweep_fade  : Array[float] = []

var player_trail : Array[Vector3] = []
var trail_timer  : float = 0.0
var _warning_pulse : float = 0.0

# Maps instance_id (int) -> TargetData
var _targets : Dictionary = {}

# Ship ARPA tracking
var _ship_prev_pos  : Vector3
var _ship_prev_time : float = 0.0
var _ship_vel_ema   : Vector3 = Vector3.ZERO


# =============================================================
#  READY
# =============================================================
func _ready() -> void:
	await get_tree().process_frame
	ship = get_tree().get_first_node_in_group("player")
	if ship:
		_ship_prev_pos  = ship.global_position
		_ship_prev_time = Time.get_ticks_msec() / 1000.0

	default_pos = global_position
	_init_sweep()
	_init_overlay()


func _init_sweep() -> void:
	_sweep_fade.resize(sweep_buckets)
	_sweep_fade.fill(0.0)


func _init_overlay() -> void:
	overlay              = ColorRect.new()
	overlay.color        = Color(0.0, 0.02, 0.06, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible      = false
	overlay.z_index      = 9
	get_parent().add_child(overlay)


# =============================================================
#  INPUT MODULE
# =============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse := get_viewport().get_mouse_position()
			if mode == RadarMode.NORMAL:
				if to_local(mouse).length() <= radar_radius:
					_set_expanded(true)
			else:
				_set_expanded(false)


func _set_expanded(state: bool) -> void:
	mode            = RadarMode.EXPANDED if state else RadarMode.NORMAL
	global_position = get_viewport_rect().size * 0.5 if state else default_pos
	z_index         = 10 if state else 0
	if overlay:
		overlay.visible = state


# =============================================================
#  PROCESS MODULE
# =============================================================
func _process(delta: float) -> void:
	_update_targets()
	_update_sweep(delta)
	_update_trails(delta)
	_update_arpa(delta)
	queue_redraw()


func _update_targets() -> void:
	var current_enemies := get_tree().get_nodes_in_group("enemies")
	var valid_ids := {}

	for node in current_enemies:
		if is_instance_valid(node) and node is Node3D:
			var id := node.get_instance_id()
			valid_ids[id] = true

			if not _targets.has(id):
				var data        := TargetData.new()
				data.node       = node
				data.prev_pos   = node.global_position
				data.prev_time  = Time.get_ticks_msec() / 1000.0
				_targets[id]    = data

	# Remove dead/invalid targets
	for id in _targets.keys():
		if not valid_ids.has(id):
			_targets.erase(id)


func _update_sweep(delta: float) -> void:
	_sweep_angle = fmod(_sweep_angle + sweep_speed * delta, TAU)
	var bucket := int(_sweep_angle / TAU * sweep_buckets)

	for i in sweep_buckets:
		_sweep_fade[i] = maxf(_sweep_fade[i] - delta * 0.9, 0.0)

	if not _sweep_fade.is_empty():
		_sweep_fade[bucket % sweep_buckets] = 1.0


func _update_trails(delta: float) -> void:
	trail_timer += delta
	if trail_timer < trail_interval:
		return
	trail_timer = 0.0

	if is_instance_valid(ship):
		player_trail.append(ship.global_position)
		if player_trail.size() > player_trail_length:
			player_trail.pop_front()

	var limit := trail_length * (3 if mode == RadarMode.EXPANDED else 1)

	for data: TargetData in _targets.values():
		if is_instance_valid(data.node):
			data.trails.append(data.node.global_position)
			if data.trails.size() > limit:
				data.trails.pop_front()


# =============================================================
#  ARPA MODULE
# =============================================================
func _update_arpa(delta: float) -> void:
	if not is_instance_valid(ship): return

	_warning_pulse += delta
	var current_time := Time.get_ticks_msec() / 1000.0

	# ── Ship velocity (EMA smoothed) ─────────────────────────
	var dt_ship := current_time - _ship_prev_time
	if dt_ship > 0.0:
		var raw_ship_vel := (ship.global_position - _ship_prev_pos) / dt_ship
		_ship_vel_ema = _ship_vel_ema.lerp(raw_ship_vel, 1.0 - EMA_ALPHA)

	_ship_prev_pos  = ship.global_position
	_ship_prev_time = current_time

	var any_warning := false

	# ── Per-target velocity (EMA + jump detection) ───────────
	for data: TargetData in _targets.values():
		if not is_instance_valid(data.node):
			continue

		var dt_tgt := current_time - data.prev_time

		if dt_tgt > 0.0:
			var displacement := data.node.global_position - data.prev_pos

			# Jump detected (teleport / relocate) — wipe state, skip sample
			if displacement.length() > JUMP_THRESHOLD:
				data.vel_ema      = Vector3.ZERO
				data.sample_count = 0
				data.warning      = false
				data.cpa_radar    = Vector2.ZERO
			else:
				var raw_vel := displacement / dt_tgt
				data.vel_ema = data.vel_ema.lerp(raw_vel, 1.0 - EMA_ALPHA)
				data.sample_count += 1

		data.prev_pos  = data.node.global_position
		data.prev_time = current_time

		# Need at least MIN_SAMPLES stable frames before drawing anything
		if data.sample_count >= MIN_SAMPLES:
			_compute_arpa(data,
				ship.global_position, _ship_vel_ema,
				data.node.global_position, data.vel_ema)
		else:
			data.warning   = false
			data.cpa_radar = Vector2.ZERO

		if data.warning:
			any_warning = true

	if any_warning:
		pass # Hook up your own alert here (emit_signal, play audio, etc.)


func _compute_arpa(data: TargetData,
		own_pos: Vector3, own_vel: Vector3,
		tgt_pos: Vector3, tgt_vel: Vector3) -> void:

	var rel_pos  := Vector2(tgt_pos.x - own_pos.x, -(tgt_pos.z - own_pos.z))
	var rel_vel  := Vector2(tgt_vel.x - own_vel.x, -(tgt_vel.z - own_vel.z))
	var speed_sq := rel_vel.length_squared()

	if speed_sq < 0.001:
		data.tcpa      = 0.0
		data.dcpa      = rel_pos.length()
		data.cpa_radar = rel_pos
	else:
		data.tcpa      = -rel_pos.dot(rel_vel) / speed_sq
		var cpa_rel   := rel_pos + rel_vel * data.tcpa
		data.dcpa      = cpa_rel.length()
		data.cpa_radar = cpa_rel

	data.warning = (data.dcpa < arpa_safe_distance
				and data.tcpa > 0.0
				and data.tcpa < arpa_max_tcpa)


# =============================================================
#  DRAW ROOT
# =============================================================
func _draw() -> void:
	var r := expanded_radius if mode == RadarMode.EXPANDED else radar_radius

	_draw_background(r)
	_draw_sweep(r)
	_draw_heading_cone(r)
	_draw_player_trail(r)
	_draw_enemies(r)
	_draw_player_dot()
	_draw_arpa_legend(r)


# =============================================================
#  RENDER MODULES
# =============================================================
func _draw_background(r: float) -> void:
	draw_circle(Vector2.ZERO, r, Color(0.01, 0.04, 0.10, 0.90))
	for i in ring_count:
		var ring_r := r * float(i + 1) / float(ring_count + 1)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 64, Color(0.12, 0.35, 0.63, 0.25), 0.8)


func _draw_sweep(r: float) -> void:
	if _sweep_fade.is_empty(): return
	var bucket_angle := TAU / float(sweep_buckets)

	for i in _sweep_fade.size():
		var fade := _sweep_fade[i]
		if fade <= 0.01: continue
		var start := float(i) * bucket_angle - PI * 0.5
		var end   := start + bucket_angle
		draw_arc(Vector2.ZERO, r * 0.97, start, end, 6, Color(0.1, 0.55, 0.35, fade * 0.18), 1.0)

	var sx := cos(_sweep_angle - PI * 0.5) * r
	var sy := sin(_sweep_angle - PI * 0.5) * r
	draw_line(Vector2.ZERO, Vector2(sx, sy), Color(0.2, 0.9, 0.55, 0.7), 1.5)


func _draw_heading_cone(r: float) -> void:
	if not is_instance_valid(ship): return

	var cone_len := r * 0.72
	var half_a   := deg_to_rad(18.0)

	var tip   := Vector2(0, -cone_len)
	var left  := Vector2(-sin(half_a), -cos(half_a)) * cone_len * 0.55
	var right := Vector2( sin(half_a), -cos(half_a)) * cone_len * 0.55

	draw_polygon(
		PackedVector2Array([Vector2.ZERO, left, tip, right]),
		PackedColorArray([
			Color(0.15, 0.55, 1.0, 0.15), Color(0.15, 0.55, 1.0, 0.06),
			Color(0.15, 0.55, 1.0, 0.40), Color(0.15, 0.55, 1.0, 0.06)
		])
	)
	draw_line(Vector2.ZERO, tip, Color(0.25, 0.65, 1.0, 0.85), 1.5)


func _draw_player_trail(r: float) -> void:
	if not is_instance_valid(ship) or player_trail.size() < 2: return

	var rot          := Basis(Vector3.UP, -ship.rotation.y)
	var scale_factor := r / radar_range
	var ship_pos     := ship.global_position

	for i in range(player_trail.size() - 1):
		var a_rel := rot * (player_trail[i]     - ship_pos)
		var b_rel := rot * (player_trail[i + 1] - ship_pos)

		var a2 := Vector2(a_rel.x, -a_rel.z) * scale_factor
		var b2 := Vector2(b_rel.x, -b_rel.z) * scale_factor

		draw_line(a2, b2, Color(0.3, 0.7, 1.0, float(i) / player_trail.size()), 1.5)


func _draw_player_dot() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(-4, 5), Vector2(4, 5)]), Color(0.3, 0.7, 1.0))
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 32, Color(0.3, 0.7, 1.0, 0.55), 1.0)


func _draw_enemies(r: float) -> void:
	if not is_instance_valid(ship): return

	for data: TargetData in _targets.values():
		var offset := data.node.global_position - ship.global_position
		var pos    := Vector2(offset.x, -offset.z) / radar_range * r

		if pos.length() > r: continue

		_draw_arpa_overlay(pos, data, r)

		var blip_col := Color(1.0, 0.9, 0.1) if data.warning else Color(1.0, 0.3, 0.2)
		draw_circle(pos, 4.0, blip_col)


func _draw_arpa_overlay(blip_pos: Vector2, data: TargetData, r: float) -> void:
	# Only draw if we have stable data
	if data.sample_count < MIN_SAMPLES: return

	var cpa_px := data.cpa_radar / radar_range * r

	if cpa_px.length() <= r:
		var cpa_col := Color(1.0, 0.85, 0.0, 0.8) if data.warning else Color(0.5, 0.85, 0.5, 0.55)
		draw_circle(cpa_px, 3.0, cpa_col)
		_draw_dashed_line(blip_pos, cpa_px, Color(cpa_col.r, cpa_col.g, cpa_col.b, 0.45), 1.0, 4.0)

	if data.warning:
		var pulse_t := fmod(_warning_pulse * 2.5, 1.0)
		var ring_a  := lerpf(0.9, 0.2, pulse_t)
		draw_arc(blip_pos, 10.0 + pulse_t * 4.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.1, ring_a), 1.5)

		if mode == RadarMode.EXPANDED:
			draw_string(ThemeDB.fallback_font, blip_pos + Vector2(8, -8),
						"%.0fs" % data.tcpa,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.85, 0.1, 0.9))


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float) -> void:
	var total := from.distance_to(to)
	if total < 1.0: return

	var dir    := (to - from).normalized()
	var cursor := 0.0
	var on     := true

	while cursor < total:
		var seg_end := minf(cursor + dash, total)
		if on:
			draw_line(from + dir * cursor, from + dir * seg_end, color, width)
		cursor = seg_end + dash * 0.5
		on = not on


func _draw_arpa_legend(r: float) -> void:
	if mode != RadarMode.EXPANDED: return

	var legend_x := r + 12.0
	var legend_y := -r + 16.0
	var font     := ThemeDB.fallback_font
	var sz       := 9

	draw_string(font, Vector2(legend_x, legend_y), "ARPA",
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.4, 0.8, 0.55, 0.9))
	legend_y += 14.0

	var safe_px := arpa_safe_distance / radar_range * r
	if safe_px < r:
		draw_arc(Vector2.ZERO, safe_px, 0, TAU, 64, Color(1.0, 0.8, 0.0, 0.12), 0.8)
		draw_string(font, Vector2(safe_px + 3.0, -4.0), "CPA",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.8, 0.0, 0.45))

	var idx := 0
	for data: TargetData in _targets.values():
		# Skip targets still warming up — no data to show yet
		if data.sample_count < MIN_SAMPLES:
			idx += 1
			continue

		var text_col := Color(1.0, 0.4, 0.2, 1.0) if data.warning else Color(0.6, 0.8, 0.6, 0.8)
		var line     := "T%d  DCPA %.0f  TCPA %.0fs" % [idx + 1, data.dcpa, data.tcpa]

		draw_string(font, Vector2(legend_x, legend_y), line,
					HORIZONTAL_ALIGNMENT_LEFT, -1, sz, text_col)
		legend_y += 12.0
		idx      += 1
