extends CanvasLayer

# =============================================================
#  BRIDGE HUD  —  Cargo Ship
#  Panels: TopBar · CompassPanel · TelegraphPanel · BottomBar
# =============================================================

# ── External node refs ──────────────────────────────────────
var wheel  : Node = null
var radar  : Node = null
var ship   : Node = null
var telegraph : Node = null

# ── Top-bar metric labels ────────────────────────────────────
var lbl_heading  : Label
var lbl_speed    : Label
var lbl_rot      : Label
var lbl_depth    : Label
var lbl_wind     : Label
var lbl_pos      : Label
var lbl_clock    : Label
var sys_dot      : Panel          # status indicator

# ── Compass panel ────────────────────────────────────────────
var compass_rose      : Control   # custom-drawn ring
var lbl_hdg_big       : Label     # large heading readout inside rose
var lbl_compass_card  : Label     # cardinal letter
var rot_bar           : Control   # custom ROT bar
var lbl_rot_bar       : Label     # centre readout on ROT bar

# ── Bottom bar ───────────────────────────────────────────────
var port_arrow    : Control
var stbd_arrow    : Control
var lbl_rudder    : Label         # below wheel
var rudder_bar    : Control       # graphical rudder gauge

# ── Left panel ───────────────────────────────────────────────
var depth_bars    : Array[Control] = []   # [fwd, mid, aft]
var depth_labels  : Array[Label]   = []

# ── Right panel ─────────────────────────────────────────────
var telegraph_panel : Control     # built below

# ── Smoothed display values ──────────────────────────────────
var disp_heading_rad : float = 0.0
var disp_speed       : float = 0.0
var disp_rot         : float = 0.0
var disp_rudder      : float = 0.0

# ── Constants ────────────────────────────────────────────────
const ROT_CLAMP        := 30.0
const BOTTOM_H         := 130
const LEFT_W           := 200
const RIGHT_W          := 160
const TOP_H            := 40
const TICK_INTERVAL    := 1.0   # seconds between clock update
var   _clock_timer     := 0.0

# ── Cursor ───────────────────────────────────────────────────
var _cursor_point := load("res://assets/pointer/hand_point.png")
var _cursor_drag  := load("res://assets/pointer/hand_open.png")
var _cur_cursor   := ""


# =============================================================
#  READY
# =============================================================
func _ready() -> void:
	ship  = get_node_or_null("/root/water-scene/boat")
	wheel = get_node_or_null("/root/water-scene/hud/SteeringWheel")
	radar = get_node_or_null("/root/water-scene/bridge_hud/Root/LeftPanel/RadarContainer/Radar")
	telegraph = get_node_or_null("/root/water-scene/EngineTelegraph")
	if not telegraph:
		telegraph = get_node_or_null("/root/water-scene/boat/EngineTelegraph")

	if ship:
		disp_heading_rad = ship.rotation.y

	_build_root()
	_build_top_bar()
	_build_left_panel()
	_build_center_panel()
	_build_right_panel()
	_build_bottom_bar()
	_setup_telegraph()


# =============================================================
#  ROOT CONTAINER
# =============================================================
func _build_root() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)


# =============================================================
#  TOP BAR
# =============================================================
func _build_top_bar() -> void:
	var root := $Root

	var bar := Panel.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_H
	bar.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.02, 0.05, 0.10, 0.95), Color(0.12, 0.35, 0.63, 0.55), 0, 0, 0, 2))
	root.add_child(bar)

	var badge := Label.new()
	badge.text = "MV IRONCLAD"
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 0.75))
	badge.set_anchor(SIDE_LEFT, 0.0); badge.set_anchor(SIDE_RIGHT, 0.0)
	badge.set_anchor(SIDE_TOP, 0.0);  badge.set_anchor(SIDE_BOTTOM, 1.0)
	badge.offset_left = 10; badge.offset_right = 110
	bar.add_child(badge)

	var cells_box := HBoxContainer.new()
	cells_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	cells_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cells_box.add_theme_constant_override("separation", 0)
	bar.add_child(cells_box)

	lbl_heading = _add_metric_cell(cells_box, "HEADING", "---° N")
	lbl_speed   = _add_metric_cell(cells_box, "SPEED",   "--- kn")
	lbl_rot     = _add_metric_cell(cells_box, "ROT",     "0°/min")
	lbl_depth   = _add_metric_cell(cells_box, "DEPTH",   "--- m")
	lbl_wind    = _add_metric_cell(cells_box, "WIND",    "---° / --- kn")
	lbl_pos     = _add_metric_cell(cells_box, "POSITION","---, ---", false)

	var right_hbox := HBoxContainer.new()
	right_hbox.set_anchor(SIDE_LEFT,  1.0); right_hbox.set_anchor(SIDE_RIGHT, 1.0)
	right_hbox.set_anchor(SIDE_TOP,   0.0); right_hbox.set_anchor(SIDE_BOTTOM, 1.0)
	right_hbox.offset_left = -130; right_hbox.offset_right = -8
	right_hbox.alignment = BoxContainer.ALIGNMENT_END
	right_hbox.add_theme_constant_override("separation", 8)
	bar.add_child(right_hbox)

	sys_dot = Panel.new()
	sys_dot.custom_minimum_size = Vector2(8, 8)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0.18, 1.0, 0.6)
	dot_style.set_corner_radius_all(4)
	sys_dot.add_theme_stylebox_override("panel", dot_style)
	right_hbox.add_child(sys_dot)

	lbl_clock = Label.new()
	lbl_clock.text = "--:--:-- UTC"
	lbl_clock.add_theme_font_size_override("font_size", 11)
	lbl_clock.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.55))
	right_hbox.add_child(lbl_clock)


func _add_metric_cell(parent: HBoxContainer, key: String, default_val: String,
		add_sep: bool = true) -> Label:
	if add_sep:
		var sep := VSeparator.new()
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = Color(0.12, 0.35, 0.63, 0.3)
		sep_style.content_margin_left = 0; sep_style.content_margin_right = 0
		sep.add_theme_stylebox_override("separator", sep_style)
		sep.custom_minimum_size = Vector2(1, 20)
		parent.add_child(sep)

	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 1)

	var lbl_key := Label.new()
	lbl_key.text = key
	lbl_key.add_theme_font_size_override("font_size", 8)
	lbl_key.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.45))
	lbl_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(lbl_key)

	var lbl_val := Label.new()
	lbl_val.text = default_val
	lbl_val.add_theme_font_size_override("font_size", 12)
	lbl_val.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(lbl_val)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(14, 0)
	parent.add_child(pad)
	parent.add_child(cell)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(14, 0)
	parent.add_child(pad2)

	return lbl_val


# =============================================================
#  LEFT PANEL  (Radar + Under-Keel Clearance)
# =============================================================
func _build_left_panel() -> void:
	var root := $Root

	var panel := Panel.new()
	panel.name = "LeftPanel"
	panel.set_anchor(SIDE_TOP,    0.0); panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_left   = 0;    panel.offset_right  = LEFT_W
	panel.offset_top    = TOP_H; panel.offset_bottom = -BOTTOM_H
	panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.02, 0.05, 0.10, 0.88), Color(0.12, 0.35, 0.63, 0.3), 0, 2, 0, 0))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	var mc := StyleBoxEmpty.new()
	mc.content_margin_left = 8; mc.content_margin_right = 8
	mc.content_margin_top  = 8; mc.content_margin_bottom = 8
	vbox.add_theme_stylebox_override("panel", mc)
	panel.add_child(vbox)

	vbox.add_child(_make_section_label("RADAR"))

	var radar_center := CenterContainer.new()
	radar_center.custom_minimum_size = Vector2(0, 150)
	radar_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(radar_center)

	var existing_radar := get_node_or_null("Root/LeftPanel/RadarContainer/Radar")
	if existing_radar:
		existing_radar.get_parent().remove_child(existing_radar)
		radar_center.add_child(existing_radar)


# =============================================================
#  CENTER PANEL  (Compass Rose + ROT bar)
# =============================================================
func _build_center_panel() -> void:
	var root := $Root

	var panel := Control.new()
	panel.name = "CenterPanel"
	panel.set_anchor(SIDE_LEFT,   -0.01); panel.set_anchor(SIDE_RIGHT,  -0.09)
	panel.set_anchor(SIDE_TOP,    -0.0); panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_left   = LEFT_W;  panel.offset_right  = -RIGHT_W
	panel.offset_top    = TOP_H;   panel.offset_bottom = -BOTTOM_H
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var sec_lbl := _make_section_label("COURSE & HEADING")
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sec_lbl)

	compass_rose = CompassRose.new()
	compass_rose.custom_minimum_size = Vector2(200, 200)
	compass_rose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(compass_rose)

	var rot_section := VBoxContainer.new()
	rot_section.add_theme_constant_override("separation", 3)
	rot_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rot_section.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(rot_section)

	var rot_title := _make_section_label("RATE OF TURN")
	rot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot_section.add_child(rot_title)

	rot_bar = ROTBar.new()
	rot_bar.custom_minimum_size = Vector2(200, 14)
	rot_section.add_child(rot_bar)

	var rot_legend := HBoxContainer.new()
	rot_legend.add_theme_constant_override("separation", 0)
	rot_section.add_child(rot_legend)

	var lbl_p := Label.new(); lbl_p.text = "P 30°/m"
	lbl_p.add_theme_font_size_override("font_size", 9)
	lbl_p.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 0.5))
	rot_legend.add_child(lbl_p)

	var spacer2 := Control.new(); spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_legend.add_child(spacer2)

	lbl_rot_bar = Label.new(); lbl_rot_bar.text = "0"
	lbl_rot_bar.add_theme_font_size_override("font_size", 10)
	lbl_rot_bar.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))
	lbl_rot_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot_legend.add_child(lbl_rot_bar)

	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_legend.add_child(spacer)

	var lbl_s := Label.new(); lbl_s.text = "S 30°/m"
	lbl_s.add_theme_font_size_override("font_size", 9)
	lbl_s.add_theme_color_override("font_color",  Color(1.0, 0.3, 0.3, 0.5))
	rot_legend.add_child(lbl_s)


# =============================================================
#  RIGHT PANEL  (Engine Telegraph + Rudder Gauge)
# =============================================================
func _build_right_panel() -> void:
	var root := $Root

	var panel := Panel.new()
	panel.name = "RightPanel"
	panel.set_anchor(SIDE_LEFT,   1.0); panel.set_anchor(SIDE_RIGHT,  1.0)
	panel.set_anchor(SIDE_TOP,    0.0); panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_left   = -RIGHT_W; panel.offset_right  = 0
	panel.offset_top    = TOP_H;    panel.offset_bottom = -BOTTOM_H
	panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.02, 0.05, 0.10, 0.88), Color(0.12, 0.35, 0.63, 0.3), 2, 0, 0, 0))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 8; vbox.offset_right = -8
	vbox.offset_top  = 8; vbox.offset_bottom = -8
	panel.add_child(vbox)

	vbox.add_child(_make_section_label("ENGINE TELEGRAPH"))

	var notches := [
		{"label": "Full Ahead",  "pct":  -1.00, "dir":  -1},
		{"label": "Half Ahead",  "pct":  -0.66, "dir":  -1},
		{"label": "Slow Ahead",  "pct":  -0.33, "dir":  -1},
		{"label": "Stop",        "pct":  0.00,  "dir":   0},
		{"label": "Slow Astern", "pct":  0.33,  "dir":   1},
		{"label": "Half Astern", "pct":  0.66,  "dir":   1},
		{"label": "Full Astern", "pct":  1.00,  "dir":   1},
	]

	var notch_group : Array[Button] = []

	for n in notches:
		var btn := Button.new()
		btn.text = n["label"]
		btn.flat = false
		btn.add_theme_font_size_override("font_size", 10)

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.04, 0.08, 0.16, 0.7)
		normal_style.set_border_width_all(1)
		normal_style.border_color = Color(0.12, 0.35, 0.63, 0.25)
		normal_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))

		var dir : int   = n["dir"]
		var pct : float = n["pct"]
		notch_group.append(btn)

		btn.pressed.connect(func():
			for b in notch_group:
				b.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))
				var ns := StyleBoxFlat.new()
				ns.bg_color = Color(0.04, 0.08, 0.16, 0.7)
				ns.set_border_width_all(1)
				ns.border_color = Color(0.12, 0.35, 0.63, 0.25)
				ns.set_corner_radius_all(3)
				b.add_theme_stylebox_override("normal", ns)
			var active_style := StyleBoxFlat.new()
			active_style.set_corner_radius_all(3)
			active_style.set_border_width_all(1)
			if dir > 0:
				active_style.bg_color = Color(0.04, 0.18, 0.10, 0.85)
				active_style.border_color = Color(0.18, 1.0, 0.55, 0.45)
				btn.add_theme_color_override("font_color", Color(0.18, 1.0, 0.55))
			elif dir < 0:
				active_style.bg_color = Color(0.18, 0.04, 0.04, 0.85)
				active_style.border_color = Color(1.0, 0.3, 0.3, 0.45)
				btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			else:
				active_style.bg_color = Color(0.16, 0.12, 0.02, 0.85)
				active_style.border_color = Color(1.0, 0.67, 0.0, 0.45)
				btn.add_theme_color_override("font_color", Color(1.0, 0.67, 0.0))
			btn.add_theme_stylebox_override("normal", active_style)
			if ship:
				ship.telegraph_power = pct
			if telegraph:
				telegraph.set_notch_by_power(pct)
		)
		vbox.add_child(btn)

	vbox.add_child(_make_section_label("RUDDER ANGLE"))

	rudder_bar = RudderGauge.new()
	rudder_bar.custom_minimum_size = Vector2(0, 14)
	rudder_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(rudder_bar)

	var rud_legend := HBoxContainer.new()
	rud_legend.add_theme_constant_override("separation", 0)
	vbox.add_child(rud_legend)

	var lbl_p_rud := Label.new(); lbl_p_rud.text = "35P"
	lbl_p_rud.add_theme_font_size_override("font_size", 8)
	lbl_p_rud.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.4))
	rud_legend.add_child(lbl_p_rud)
	var s := Control.new(); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rud_legend.add_child(s)
	var s2 := Control.new(); s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rud_legend.add_child(s2)
	var lbl_s_rud := Label.new(); lbl_s_rud.text = "35S"
	lbl_s_rud.add_theme_font_size_override("font_size", 8)
	lbl_s_rud.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 0.4))
	rud_legend.add_child(lbl_s_rud)

	lbl_rudder = Label.new()
	lbl_rudder.text = "AMID"
	lbl_rudder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_rudder.add_theme_font_size_override("font_size", 12)
	lbl_rudder.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))
	vbox.add_child(lbl_rudder)


# =============================================================
#  BOTTOM BAR  (Nav summary · Wheel · Horn)
# =============================================================
func _build_bottom_bar() -> void:
	var root := $Root

	var bar := Panel.new()
	bar.name = "BottomBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BOTTOM_H
	bar.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.02, 0.04, 0.08, 0.96), Color(0.12, 0.35, 0.63, 0.55), 0, 0, 2, 0))
	root.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	bar.add_child(hbox)

	# ── Column 1: Nav summary ──
	var nav_pad := MarginContainer.new()
	nav_pad.add_theme_constant_override("margin_left",   10)
	nav_pad.add_theme_constant_override("margin_right",  6)
	nav_pad.add_theme_constant_override("margin_top",    8)
	nav_pad.add_theme_constant_override("margin_bottom", 8)
	nav_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(nav_pad)

	var nav_panel := VBoxContainer.new()
	nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_panel.add_theme_constant_override("separation", 3)
	nav_pad.add_child(nav_panel)

	var sep := VSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.12, 0.35, 0.63, 0.3)
	sep.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(sep)

	# ── Column 2: Port arrow + Wheel + Stbd arrow ──
	var wheel_hbox := HBoxContainer.new()
	wheel_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wheel_hbox.add_theme_constant_override("separation", 16)
	hbox.add_child(wheel_hbox)

	port_arrow = ArrowIndicator.new()
	(port_arrow as ArrowIndicator).direction = -1
	(port_arrow as ArrowIndicator).arrow_color = Color(0.5, 0.1, 0.1)
	port_arrow.custom_minimum_size = Vector2(56, 56)
	wheel_hbox.add_child(port_arrow)

	var wheel_col := VBoxContainer.new()
	wheel_col.alignment = BoxContainer.ALIGNMENT_CENTER
	wheel_col.add_theme_constant_override("separation", 4)
	wheel_hbox.add_child(wheel_col)

	var wheel_center := CenterContainer.new()
	wheel_center.custom_minimum_size = Vector2(110, 110)
	wheel_col.add_child(wheel_center)

	var existing_wheel := get_node_or_null("Root/hud/SteeringWheel")
	if existing_wheel:
		existing_wheel.get_parent().remove_child(existing_wheel)
		existing_wheel.custom_minimum_size = Vector2(100, 100)
		wheel_center.add_child(existing_wheel)
		wheel = existing_wheel

	stbd_arrow = ArrowIndicator.new()
	(stbd_arrow as ArrowIndicator).direction = 1
	(stbd_arrow as ArrowIndicator).arrow_color = Color(0.1, 0.35, 0.1)
	stbd_arrow.custom_minimum_size = Vector2(56, 56)
	wheel_hbox.add_child(stbd_arrow)

	var sep2 := VSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(sep2)

	# ── Column 3: Horn ──
	var horn_col := VBoxContainer.new()
	horn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	horn_col.add_theme_constant_override("separation", 4)
	var horn_margin := MarginContainer.new()
	horn_margin.add_theme_constant_override("margin_left",   10)
	horn_margin.add_theme_constant_override("margin_right",  10)
	horn_margin.add_theme_constant_override("margin_top",    8)
	horn_margin.add_theme_constant_override("margin_bottom", 8)
	horn_margin.add_child(horn_col)
	hbox.add_child(horn_margin)

	var horn_btn := Button.new()
	horn_btn.text = "📣"
	horn_btn.custom_minimum_size = Vector2(58, 40)
	horn_btn.add_theme_font_size_override("font_size", 18)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.06, 0.16, 0.06, 0.88)
	hs.set_border_width_all(1)
	hs.border_color = Color(0.3, 0.7, 0.25, 0.5)
	hs.set_corner_radius_all(4)
	horn_btn.add_theme_stylebox_override("normal", hs)
	var hs_h := hs.duplicate(); hs_h.bg_color = Color(0.12, 0.30, 0.12, 0.95)
	horn_btn.add_theme_stylebox_override("hover", hs_h)
	var hs_p := hs.duplicate(); hs_p.bg_color = Color(0.22, 0.50, 0.22, 1.0)
	horn_btn.add_theme_stylebox_override("pressed", hs_p)
	horn_btn.pressed.connect(_on_horn_pressed)
	horn_col.add_child(horn_btn)

	var horn_lbl := Label.new(); horn_lbl.text = "HORN"
	horn_lbl.add_theme_font_size_override("font_size", 8)
	horn_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.35))
	horn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	horn_col.add_child(horn_lbl)


# =============================================================
#  TELEGRAPH SETUP
# =============================================================
func _setup_telegraph() -> void:
	if not telegraph:
		return
	telegraph.mouse_filter = Control.MOUSE_FILTER_STOP
	telegraph.notch_changed.connect(_on_telegraph_notch_changed)


# =============================================================
#  HORN
# =============================================================
func _on_horn_pressed() -> void:
	if ship and ship.has_node("AudioStreamPlayer"):
		ship.get_node("AudioStreamPlayer").play()


# =============================================================
#  TELEGRAPH SIGNAL
# =============================================================
func _on_telegraph_notch_changed(_i: int, power: float) -> void:
	if ship:
		ship.telegraph_power = power


# =============================================================
#  CURSOR
# =============================================================
func _set_cursor(state: String) -> void:
	if state == _cur_cursor:
		return
	_cur_cursor = state
	match state:
		"point": Input.set_custom_mouse_cursor(_cursor_point, Input.CURSOR_ARROW, Vector2.ZERO)
		"drag":  Input.set_custom_mouse_cursor(_cursor_drag,  Input.CURSOR_ARROW, Vector2.ZERO)


# =============================================================
#  INDICATORS
# =============================================================
func _update_turn_indicators(steering: float) -> void:
	const DEAD := 0.05
	var pa := port_arrow as ArrowIndicator
	var sa := stbd_arrow as ArrowIndicator
	pa.arrow_color = Color(0.3, 1.0, 0.4) if steering < -DEAD else Color(0.1, 0.35, 0.1)
	sa.arrow_color = Color(1.0, 0.2, 0.2) if steering >  DEAD else Color(0.5, 0.1, 0.1)
	pa.queue_redraw(); sa.queue_redraw()


# =============================================================
#  PROCESS
# =============================================================
func _process(delta: float) -> void:
	if wheel and wheel.dragging:
		_set_cursor("drag")
	else:
		_set_cursor("point")

	if not ship:
		return

	# Clock (throttled)
	_clock_timer += delta
	if _clock_timer >= TICK_INTERVAL:
		_clock_timer = 0.0
		var t := Time.get_datetime_dict_from_system()
		lbl_clock.text = "%02d:%02d:%02d UTC" % [t.hour, t.minute, t.second]

	# ── Heading ──────────────────────────────────────────────
	disp_heading_rad = lerp_angle(disp_heading_rad, ship.rotation.y, 5.0 * delta)
	var deg := fmod(rad_to_deg(disp_heading_rad), 360.0)
	if deg < 0.0: deg += 360.0
	var hdg_int := roundi(deg)
	var card    := _compass_card(deg)
	lbl_heading.text = "%d° %s" % [hdg_int, card]
	if compass_rose:
		(compass_rose as CompassRose).heading_deg = deg
		compass_rose.queue_redraw()

	# ── Speed ────────────────────────────────────────────────
	var spd_ms : float = ship.linear_velocity.length()
	var spd_kn : float = spd_ms * 1.94384
	disp_speed = lerp(disp_speed, spd_kn, 5.0 * delta)
	lbl_speed.text = "%.1f kn" % disp_speed

	# ── Position ─────────────────────────────────────────────
	var p : Vector3 = ship.global_position
	lbl_pos.text = "%d, %d" % [roundi(p.x), roundi(p.z)]

	# ── Rate of Turn ─────────────────────────────────────────
	disp_rot = lerp(disp_rot, float(ship.rate_of_turn), 4.0 * delta)
	# Negate so that starboard turn (positive wheel) fills the bar rightward toward "S"
	var rot_clamped := clampf(-disp_rot / ROT_CLAMP, -1.0, 1.0)  # <-- FIX: negated

	if abs(disp_rot) < 2.5:
		lbl_rot.text      = "0°/min"
		lbl_rot_bar.text  = "0"
		lbl_rot.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
		lbl_rot_bar.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))
	else:
		var dir_str   := "L" if disp_rot > 0 else "R"
		var rot_color := Color(1.0, 0.45, 0.45) if disp_rot > 0 else Color(0.3, 1.0, 0.5)
		var rot_snapped : float = snappedf(abs(disp_rot), 5.0)
		lbl_rot.text     = "%.0f°/m %s" % [rot_snapped, dir_str]
		lbl_rot_bar.text = "%+.0f %s" % [rot_snapped, dir_str]
		lbl_rot.add_theme_color_override("font_color", rot_color)
		lbl_rot_bar.add_theme_color_override("font_color", rot_color)

	if rot_bar:
		(rot_bar as ROTBar).rot_normalized = rot_clamped
		rot_bar.queue_redraw()

	# ── Rudder angle ─────────────────────────────────────────
	if wheel:
		var raw_rud : float = float(wheel.get_steering_value()) * 35.0
		disp_rudder = lerp(disp_rudder, raw_rud, 8.0 * delta)
		var snapped_rud := snappedf(disp_rudder, 1.0)

		if rudder_bar:
			(rudder_bar as RudderGauge).rudder_normalized = snapped_rud / 35.0
			rudder_bar.queue_redraw()

		if abs(snapped_rud) < 1.0:
			lbl_rudder.text = "AMID"
			lbl_rudder.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.5))
		else:
			var side := "STBD" if snapped_rud > 0 else "PORT"
			var rc   := Color(0.3, 1.0, 0.5) if snapped_rud > 0 else Color(1.0, 0.45, 0.45)
			lbl_rudder.text = "%d° %s" % [absi(int(snapped_rud)), side]
			lbl_rudder.add_theme_color_override("font_color", rc)

		_update_turn_indicators(float(wheel.get_steering_value()))


func _physics_process(delta: float) -> void:
	if not ship or not wheel:
		return
	var steering : float = wheel.get_steering_value()
	ship.steering_input = lerp(ship.steering_input, steering, 0.5 * delta)
	if telegraph:
		ship.telegraph_power = telegraph.get_telegraph_power()


# =============================================================
#  COMPASS CARD
# =============================================================
func _compass_card(h: float) -> String:
	var cards := ["N","NNE","NE","ENE","E","ESE","SE","SSE",
				  "S","SSW","SW","WSW","W","WNW","NW","NNW","N"]
	return cards[roundi(h / 22.5) % 16]


# =============================================================
#  HELPERS
# =============================================================
func _make_panel_style(bg: Color, border: Color,
		bl: int = 0, br: int = 0, bt: int = 0, bb: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = bl
	s.border_width_right  = br
	s.border_width_top    = bt
	s.border_width_bottom = bb
	return s

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 0.45))
	return lbl


# =============================================================
#  INNER CLASS — Arrow Indicator
# =============================================================
class ArrowIndicator extends Control:
	var direction  : int   = 1
	var arrow_color: Color = Color.WHITE

	func _draw() -> void:
		var w := size.x; var h := size.y
		var cx := w * 0.5; var cy := h * 0.5
		var r  := minf(cx, cy) - 4.0

		draw_circle(Vector2(cx, cy), r, Color(arrow_color, 0.12))
		draw_arc(Vector2(cx, cy), r, 0, TAU, 48,
			Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.25), 1.0)

		if direction == -1:
			draw_colored_polygon(PackedVector2Array([
				Vector2(w*0.70, h*0.20),
				Vector2(w*0.25, h*0.50),
				Vector2(w*0.70, h*0.80),
				Vector2(w*0.60, h*0.50),
			]), arrow_color)
		else:
			draw_colored_polygon(PackedVector2Array([
				Vector2(w*0.30, h*0.20),
				Vector2(w*0.75, h*0.50),
				Vector2(w*0.30, h*0.80),
				Vector2(w*0.40, h*0.50),
			]), arrow_color)

		var label_text := "PORT" if direction == -1 else "STBD"
		draw_string(ThemeDB.fallback_font, Vector2(cx - 12, h - 6),
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(arrow_color, 0.45))


# =============================================================
#  INNER CLASS — Compass Rose
# =============================================================
class CompassRose extends Control:
	var heading_deg : float = 0.0

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var r  := minf(cx, cy) - 4.0

		draw_arc(Vector2(cx, cy), r, 0, TAU, 128,
			Color(0.12, 0.35, 0.63, 0.35), 1.5)

		for i in 72:
			var angle := (i * 5.0 - 90.0) * PI / 180.0
			var major  := i % 9 == 0
			var medium := i % 3 == 0
			var r_inner := r - (8.0 if major else (5.0 if medium else 3.0))
			var p1 := Vector2(cx + r * cos(angle), cy + r * sin(angle))
			var p2 := Vector2(cx + r_inner * cos(angle), cy + r_inner * sin(angle))
			var col := Color(0.3, 0.6, 1.0, 0.5 if major else 0.25)
			draw_line(p1, p2, col, 1.5 if major else 0.8)

		var card_names   : Array[String] = ["N",   "E",   "S",    "W"]
		var card_degrees : Array[float]  = [0.0, 90.0, 180.0, 270.0]
		for i in 4:
			var a       : float   = (card_degrees[i] - 90.0) * PI / 180.0
			var label_r : float   = r - 16.0
			var pos     : Vector2 = Vector2(cx + label_r * cos(a) - 4.0, cy + label_r * sin(a) + 4.0)
			var col     : Color   = Color(1.0, 0.35, 0.35) if card_names[i] == "N" else Color(0.55, 0.75, 1.0, 0.65)
			draw_string(ThemeDB.fallback_font, pos, card_names[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		
		var cog_deg := heading_deg - 2.5
		var cog_rad := (cog_deg - 90.0) * PI / 180.0
		var cog_end := Vector2(cx + (r - 4) * cos(cog_rad), cy + (r - 4) * sin(cog_rad))
		draw_dashed_line(Vector2(cx, cy), cog_end, Color(1.0, 0.65, 0.0, 0.55), 1.5, 6.0)
		
		var hdg_rad := (heading_deg - 90.0) * PI / 180.0
		var hdg_end := Vector2(cx + (r - 2) * cos(hdg_rad), cy + (r - 2) * sin(hdg_rad))
		draw_line(Vector2(cx, cy), hdg_end, Color(0.3, 0.7, 1.0, 0.9), 2.5)

		var ship_pts := PackedVector2Array([
			Vector2(cx + 10 * cos(hdg_rad), cy + 10 * sin(hdg_rad)),
			Vector2(cx + 5  * cos(hdg_rad + 2.5), cy + 5  * sin(hdg_rad + 2.5)),
			Vector2(cx + 5  * cos(hdg_rad - 2.5), cy + 5  * sin(hdg_rad - 2.5)),
		])
		draw_colored_polygon(ship_pts, Color(0.3, 0.7, 1.0))

		draw_circle(Vector2(cx, cy), 32.0, Color(0.02, 0.05, 0.10, 0.92))
		draw_arc(Vector2(cx, cy), 32.0, 0, TAU, 64,
			Color(0.12, 0.35, 0.63, 0.3), 0.8)

		var hdg_int := roundi(heading_deg) % 360
		draw_string(ThemeDB.fallback_font,
			Vector2(cx - 18, cy + 7), "%03d°" % hdg_int,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.94, 1.0))


# =============================================================
#  INNER CLASS — ROT Bar
# =============================================================
class ROTBar extends Control:
	var rot_normalized : float = 0.0   # -1 = full port, +1 = full stbd

	func _draw() -> void:
		var w := size.x; var h := size.y
		var cx := w * 0.5

		draw_rect(Rect2(0, 2, w, h - 4), Color(0.1, 0.25, 0.5, 0.2), true)
		draw_rect(Rect2(0, 2, w, h - 4), Color(0.12, 0.35, 0.63, 0.25), false, 0.5)

		draw_line(Vector2(cx, 0), Vector2(cx, h), Color(0.3, 0.55, 1.0, 0.4), 1.0)

		if absf(rot_normalized) < 0.02:
			return

		var fill_w := absf(rot_normalized) * cx
		var col    := Color(1.0, 0.35, 0.35) if rot_normalized > 0 else Color(0.3, 1.0, 0.5)

		if rot_normalized > 0:
			draw_rect(Rect2(cx, 3, fill_w, h - 6), col, true)
		else:
			draw_rect(Rect2(cx - fill_w, 3, fill_w, h - 6), col, true)


# =============================================================
#  INNER CLASS — Rudder Gauge
# =============================================================
class RudderGauge extends Control:
	var rudder_normalized : float = 0.0   # -1 = 35P, +1 = 35S

	func _draw() -> void:
		var w := size.x; var h := size.y
		var cx := w * 0.5

		draw_rect(Rect2(0, 1, w, h - 2), Color(0.1, 0.25, 0.5, 0.2), true)
		draw_rect(Rect2(0, 1, w, h - 2), Color(0.12, 0.35, 0.63, 0.25), false, 0.5)

		draw_line(Vector2(cx, 0), Vector2(cx, h), Color(0.55, 0.75, 1.0, 0.35), 1.5)

		if absf(rudder_normalized) < 0.02:
			return

		var fill_w := absf(rudder_normalized) * cx
		var col    := Color(0.3, 1.0, 0.5) if rudder_normalized > 0 else Color(1.0, 0.35, 0.35)

		if rudder_normalized > 0:
			draw_rect(Rect2(cx + 1, 2, fill_w - 1, h - 4), col, true)
		else:
			draw_rect(Rect2(cx - fill_w, 2, fill_w - 1, h - 4), col, true)
