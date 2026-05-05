extends Camera3D

# =========================
#  BINOCULAR SETTINGS
# =========================
@export var normal_fov: float = 70.0
@export var binocular_fov: float = 15.0
@export var zoom_speed: float = 8.0

# =========================
#  MOUSE LOOK SETTINGS
# =========================
@export var mouse_sensitivity: float = 0.15
@export var max_pitch: float = 30.0
@export var max_yaw: float = 60.0

const BASE_ROTATION := Vector3(-12.5, 0.0, 0.0)

var is_binocular: bool = false
var is_dragging: bool = false
var target_fov: float = normal_fov
var overlay: ColorRect = null
var bino_button: Button = null
var previous_camera: Camera3D = null
var previous_camera_rotation: Vector3 = Vector3.ZERO
var is_ready: bool = false

var pitch: float = 0.0
var yaw: float = 0.0
var base_rotation: Vector3 = BASE_ROTATION

const CORNER_RADIUS       := 12
const BORDER_WIDTH        := 2
const COLOR_ACTIVE_BG     := Color(0.10, 0.40, 0.80, 0.95)
const COLOR_ACTIVE_BORDER := Color(0.50, 0.80, 1.00, 1.00)
const COLOR_IDLE_BG       := Color(0.10, 0.10, 0.10, 0.75)
const COLOR_IDLE_BORDER   := Color(0.40, 0.60, 1.00, 0.80)

func _ready():
	fov = normal_fov
	base_rotation = BASE_ROTATION
	rotation_degrees = BASE_ROTATION
	_setup_overlay()
	_setup_button()
	await get_tree().process_frame
	await get_tree().process_frame
	is_ready = true

func _setup_button():
	var canvas = CanvasLayer.new()
	canvas.layer = 11
	get_tree().root.call_deferred("add_child", canvas)

	bino_button = Button.new()
	bino_button.text = "🔭"
	bino_button.flat = false
	bino_button.tooltip_text = "Toggle Binoculars"
	bino_button.custom_minimum_size = Vector2(60, 60)
	bino_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bino_button.position = Vector2(-80, -80)
	bino_button.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.75)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_border_width_all(BORDER_WIDTH)
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	bino_button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
	bino_button.add_theme_stylebox_override("hover", hover_style)

	var active_style = style.duplicate()
	active_style.bg_color = Color(0.1, 0.4, 0.8, 0.95)
	active_style.border_color = Color(0.5, 0.8, 1.0, 1.0)
	bino_button.add_theme_stylebox_override("pressed", active_style)

	bino_button.add_theme_font_size_override("font_size", 28)
	bino_button.pressed.connect(_toggle_binocular)
	canvas.call_deferred("add_child", bino_button)

func _setup_overlay():
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	get_tree().root.call_deferred("add_child", canvas)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = _create_binocular_shader()
	overlay.material = shader_mat

	canvas.call_deferred("add_child", overlay)

func _create_binocular_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform bool active = false;
void fragment() {
	vec2 uv = UV;
	vec2 left_center = vec2(0.3, 0.5);
	vec2 right_center = vec2(0.7, 0.5);
	float aspect = 16.0 / 9.0;
	vec2 left_diff = (uv - left_center) * vec2(aspect, 1.0);
	vec2 right_diff = (uv - right_center) * vec2(aspect, 1.0);
	float left_dist = length(left_diff);
	float right_dist = length(right_diff);
	float lens_radius = 0.28;
	float edge_softness = 0.02;
	bool in_left = left_dist < lens_radius;
	bool in_right = right_dist < lens_radius;
	if (active) {
		if (!in_left && !in_right) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			float dist = min(left_dist, right_dist);
			float edge = smoothstep(lens_radius, lens_radius - edge_softness, dist);
			COLOR = vec4(0.0, 0.0, 0.0, 1.0 - edge);
		}
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
"""
	return shader

func _input(event: InputEvent) -> void:
	if not is_binocular:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and is_dragging:
		yaw   = clamp(yaw   - event.relative.x * mouse_sensitivity, -max_yaw,   max_yaw)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -max_pitch, max_pitch)
		_apply_rotation()

func _apply_rotation() -> void:
	rotation_degrees = Vector3(base_rotation.x + pitch, base_rotation.y + yaw, base_rotation.z)

func _make_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_border_width_all(BORDER_WIDTH)
	style.bg_color     = COLOR_ACTIVE_BG     if active else COLOR_IDLE_BG
	style.border_color = COLOR_ACTIVE_BORDER if active else COLOR_IDLE_BORDER
	return style

func _toggle_binocular() -> void:
	if not is_ready:
		return
	is_binocular = !is_binocular
	is_dragging  = false
	target_fov   = binocular_fov if is_binocular else normal_fov

	if is_binocular:
		previous_camera          = get_viewport().get_camera_3d()
		previous_camera_rotation = BASE_ROTATION
		base_rotation            = BASE_ROTATION
		_apply_rotation()
		make_current()
	else:
		pitch = 0.0
		yaw   = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if previous_camera:
			previous_camera.rotation_degrees = previous_camera_rotation
			previous_camera.make_current()
			previous_camera = null

	if overlay and overlay.material:
		overlay.material.set_shader_parameter("active", is_binocular)
	if bino_button:
		bino_button.add_theme_stylebox_override("normal", _make_button_style(is_binocular))

func activate():
	pitch = 0.0
	yaw   = 0.0
	base_rotation    = BASE_ROTATION
	rotation_degrees = BASE_ROTATION
	if bino_button:
		bino_button.visible = true

func deactivate():
	is_binocular = false
	is_dragging  = false
	target_fov   = normal_fov
	fov          = normal_fov
	pitch        = 0.0
	yaw          = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rotation_degrees = BASE_ROTATION
	if overlay and overlay.material:
		overlay.material.set_shader_parameter("active", false)
	if bino_button:
		bino_button.visible = false

func _process(delta):
	fov = lerp(fov, target_fov, zoom_speed * delta)
