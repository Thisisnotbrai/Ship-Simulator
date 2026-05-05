extends Node

const ASSETS_PATH   := "res://assets/kenney_ui_pack/"
const PANEL_MARGIN  := 12
const BUTTON_MARGIN := 5

var kenney_theme : Theme

func _ready() -> void:
	kenney_theme = _build_theme()


func _build_theme() -> Theme:
	var theme := Theme.new()

	# ── Panel ─────────────────────────────────────────────────────────────────
	var panel_tex := _try_load("grey_panel.png")
	if panel_tex:
		theme.set_stylebox("panel", "PanelContainer",
			_make_ninepatch(panel_tex, PANEL_MARGIN))
	
	# ── Buttons ───────────────────────────────────────────────────────────────
	var btn_normal  := _try_load("blue_button00.png")
	var btn_pressed := _try_load("blue_button01.png")
	if btn_normal:
		var normal  := _make_ninepatch(btn_normal, BUTTON_MARGIN)
		var pressed := _make_ninepatch(
			btn_pressed if btn_pressed else btn_normal, BUTTON_MARGIN)
		pressed.expand_margin_top    = -2.0
		pressed.expand_margin_bottom = -2.0
		theme.set_stylebox("normal",   "Button", normal)
		theme.set_stylebox("hover",    "Button", normal)
		theme.set_stylebox("pressed",  "Button", pressed)
		theme.set_stylebox("focus",    "Button", normal)
		theme.set_stylebox("disabled", "Button", normal)

	theme.set_color("font_color",         "Button", Color.WHITE)
	theme.set_color("font_hover_color",   "Button", Color(0.9, 0.95, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(0.75, 0.75, 0.75))

	# ── Slider ────────────────────────────────────────────────────────────────
	var slider_bg      := _try_load("slide_horizontal_grey.png")
	var slider_fill    := _try_load("slide_horizontal_color.png")
	var slider_grabber := _try_load("slide_horizontal_color_section_wide.png")
	
	if slider_bg:
		var bg                          := StyleBoxTexture.new()
		bg.texture                       = slider_bg
		bg.texture_margin_left           = 16
		bg.texture_margin_right          = 16
		bg.texture_margin_top            = 4
		bg.texture_margin_bottom         = 4
		theme.set_stylebox("background", "HSlider", bg)

	if slider_fill:
		var fill                         := StyleBoxTexture.new()
		fill.texture                      = slider_fill
		fill.texture_margin_left          = 16
		fill.texture_margin_right         = 16
		fill.texture_margin_top           = 4
		fill.texture_margin_bottom        = 4
		theme.set_stylebox("grabber_area",           "HSlider", fill)
		theme.set_stylebox("grabber_area_highlight", "HSlider", fill)

	if slider_grabber:
		theme.set_icon("grabber",           "HSlider", slider_grabber)
		theme.set_icon("grabber_highlight", "HSlider", slider_grabber)
		theme.set_icon("grabber_disabled",  "HSlider", slider_grabber)
	
	# ── CheckButton (prevent inheriting slider style) ─────────────────────────
	theme.set_stylebox("normal",   "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox("pressed",  "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox("hover",    "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox("focus",    "CheckButton", StyleBoxEmpty.new())
	
	return theme
	
	
func _make_ninepatch(tex: Texture2D, margin: int) -> StyleBoxTexture:
	var style                  := StyleBoxTexture.new()
	style.texture               = tex
	style.texture_margin_left   = margin
	style.texture_margin_right  = margin
	style.texture_margin_top    = margin
	style.texture_margin_bottom = margin
	return style


func _try_load(filename: String) -> Texture2D:
	var path := ASSETS_PATH + filename
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("[UITheme] Asset not found: %s" % path)
	return null
	
