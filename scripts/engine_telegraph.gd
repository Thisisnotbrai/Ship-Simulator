extends Control

# =============================================================
#  ENGINE TELEGRAPH  (polish pass)
# =============================================================

const NOTCHES := [
	"Full Sea",
	"Full",
	"Half",
	"Slow",
	"D.Slow",
	"STOP",
	"D.Slow",
	"Slow",
	"Half",
	"Full",
]

const NOTCH_POWER := [
	-1.50,
	-0.85,
	-0.35,
	-0.15,
	-0.06,
	 0.00,
	 0.06,
	 0.15,
	 0.35,
	 0.85,
]

const HANDLE_HEIGHT : int = 30
const NOTCH_COUNT   : int = 10
const FONT_SIZE_BASE   : int = 10
const FONT_SIZE_ACTIVE : int = 12

# Zone boundary: indices 0-4 = ahead, 5 = stop, 6-9 = astern
# (reversed: lower index = full sea ahead in original list, but visually index 0 is top)

var current_notch : int   = 5
var dragging      : bool  = false
var drag_start_y  : float = 0.0
var drag_start_notch : int = 5

var lever_panel  : Panel
var lever_handle : Panel

var notch_labels  : Array = []
var notch_markers : Array = []

signal notch_changed(notch_index: int, power: float)


# =============================================================
#  READY
# =============================================================
func _ready() -> void:
	_build_telegraph()


# =============================================================
#  COLOR HELPER
# =============================================================
func _get_notch_color(i: int) -> Color:
	if   i < 5:  return Color(0.28, 0.88, 1.00)   # ahead  — cyan-blue
	elif i == 5: return Color(1.00, 0.88, 0.10)   # stop   — amber
	else:        return Color(1.00, 0.48, 0.12)   # astern — orange-red


# =============================================================
#  BUILD UI
# =============================================================
func _build_telegraph() -> void:
	# ── Outer container ──────────────────────────────────────
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color    = Color(0.055, 0.065, 0.095, 0.97)
	bg_style.border_color = Color(0.28, 0.42, 0.65, 0.80)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(10)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# ── Title ─────────────────────────────────────────────────
	var title := Label.new()
	title.text = "ENGINE TELEGRAPH"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 6
	title.offset_bottom = 24
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	add_child(title)

	# ── Main layout ───────────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_top    = 28
	hbox.offset_left   = 6
	hbox.offset_right  = -6
	hbox.offset_bottom = -6
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	# Power bar (far left, narrow vertical strip)
	_build_power_bar(hbox)

	# Notch label column
	var label_vbox := VBoxContainer.new()
	label_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(label_vbox)

	# Zone backgrounds behind labels
	_build_zone_backgrounds(label_vbox)

	# Lever track
	lever_panel = Panel.new()
	lever_panel.custom_minimum_size = Vector2(28, 0)
	lever_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var track_style := StyleBoxFlat.new()
	track_style.bg_color    = Color(0.025, 0.035, 0.055, 1.0)
	track_style.border_color = Color(0.22, 0.32, 0.52, 0.55)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(5)
	lever_panel.add_theme_stylebox_override("panel", track_style)
	hbox.add_child(lever_panel)

	# Build notch labels and track markers
	for i in range(NOTCH_COUNT):
		var color := _get_notch_color(i)

		# Label
		var lbl := Label.new()
		lbl.text = NOTCHES[i]
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_BASE)
		lbl.add_theme_color_override("font_color", color)
		label_vbox.add_child(lbl)
		notch_labels.append(lbl)

		# Track marker dash
		var marker := ColorRect.new()
		var ratio  := float(i) / float(NOTCH_COUNT - 1)
		marker.anchor_top    = ratio; marker.anchor_bottom = ratio
		marker.anchor_left   = 0;     marker.anchor_right  = 1
		marker.offset_top    = -1;    marker.offset_bottom = 1
		marker.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		lever_panel.add_child(marker)
		notch_markers.append(marker)

	# Handle
	lever_handle = Panel.new()
	lever_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	lever_handle.gui_input.connect(_on_handle_input)
	lever_handle.custom_minimum_size = Vector2(0, HANDLE_HEIGHT)

	var handle_style := StyleBoxFlat.new()
	handle_style.bg_color    = Color(0.68, 0.52, 0.18)
	handle_style.border_color = Color(1.00, 0.82, 0.38)
	handle_style.set_border_width_all(2)
	handle_style.set_corner_radius_all(5)
	lever_handle.add_theme_stylebox_override("panel", handle_style)
	lever_panel.add_child(lever_handle)

	# Grip lines drawn over handle
	var grip_canvas := Control.new()
	grip_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	grip_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_canvas.draw.connect(_draw_grip_lines.bind(grip_canvas))
	lever_handle.add_child(grip_canvas)

	_update_handle_position()
	_highlight_active_notch()


func _draw_grip_lines(canvas: Control) -> void:
	var w := canvas.size.x; var h := canvas.size.y
	for i in 3:
		var y := h * 0.25 + i * h * 0.25
		canvas.draw_line(Vector2(4, y), Vector2(w - 4, y),
			Color(1.0, 0.85, 0.45, 0.55), 1.2)


func _build_power_bar(parent: HBoxContainer) -> void:
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(6, 0)
	bar_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.10, 0.18, 0.85)
	bs.set_border_width_all(1)
	bs.border_color = Color(0.22, 0.32, 0.52, 0.45)
	bs.set_corner_radius_all(3)
	bar_bg.add_theme_stylebox_override("panel", bs)
	parent.add_child(bar_bg)

func _build_zone_backgrounds(_parent: VBoxContainer) -> void:
	# This creates invisible spacers of appropriate height.
	# Real zone BG is painted in the lever_panel via draw callbacks if desired.
	# Here we keep it simple — just ensures the vbox has proper sizing.
	pass

# =============================================================
#  INPUT
# =============================================================
func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			dragging = true
			drag_start_y     = get_global_mouse_position().y
			drag_start_notch = current_notch
		else:
			dragging = false


func _input(event: InputEvent) -> void:
	if not dragging:
		return

	if event is InputEventMouseMotion:
		var delta_y := get_global_mouse_position().y - drag_start_y
		var track_h := lever_panel.size.y
		if track_h <= 0:
			return
		var step   := track_h / float(NOTCH_COUNT - 1)
		var offset := int(round(delta_y / step))
		_set_notch(clampi(drag_start_notch + offset, 0, NOTCH_COUNT - 1))
	elif event is InputEventMouseButton and not event.pressed:
		dragging = false


# =============================================================
#  SET NOTCH
# =============================================================
func _set_notch(index: int) -> void:
	if index == current_notch:
		return
	current_notch = index
	_update_handle_position()
	_highlight_active_notch()
	emit_signal("notch_changed", current_notch, NOTCH_POWER[current_notch])


# =============================================================
#  HANDLE POSITION
# =============================================================
func _update_handle_position() -> void:
	var h := lever_panel.size.y
	if h <= 0:
		return
	var t := float(current_notch) / float(NOTCH_COUNT - 1)
	lever_handle.position.y = t * h - HANDLE_HEIGHT * 0.5
	lever_handle.size.x = lever_panel.size.x


# =============================================================
#  VISUAL UPDATE
# =============================================================
func _highlight_active_notch() -> void:
	for i in range(NOTCH_COUNT):
		var lbl    : Label     = notch_labels[i]
		var marker : ColorRect = notch_markers[i]
		var col    := _get_notch_color(i)

		if i == current_notch:
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", FONT_SIZE_ACTIVE)
			marker.color = col
		else:
			lbl.add_theme_color_override("font_color", Color(col, 0.42))
			lbl.add_theme_font_size_override("font_size", FONT_SIZE_BASE)
			marker.color = Color(col.r, col.g, col.b, 0.20)

	# Update handle color to match zone
	var active_col := _get_notch_color(current_notch)
	if lever_handle:
		var hs := StyleBoxFlat.new()
		hs.bg_color    = Color(active_col.r * 0.55, active_col.g * 0.40, active_col.b * 0.15)
		hs.border_color = Color(active_col, 0.85)
		hs.set_border_width_all(2)
		hs.set_corner_radius_all(5)
		lever_handle.add_theme_stylebox_override("panel", hs)
	
	
	
	
# =============================================================
#  PUBLIC API
# =============================================================
func get_telegraph_power() -> float:
	return NOTCH_POWER[current_notch]


func get_current_notch_name() -> String:
	return NOTCHES[current_notch]


func set_notch_external(index: int) -> void:
	_set_notch(clampi(index, 0, NOTCH_COUNT - 1))


## Find the closest notch to the requested power and snap to it.
func set_notch_by_power(pct: float) -> void:
	var best_idx: int = 0
	var best_dist: float = INF
	
	for i in NOTCH_COUNT:
		var d: float = abs(NOTCH_POWER[i] - pct)
		if d < best_dist:
			best_dist = d
			best_idx = i
	
	_set_notch(best_idx)
