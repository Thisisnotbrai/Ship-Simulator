extends Control

# ─────────────────────────────────────────────────────────────────────────────
#  Main Menu — Kenney Classic UI Pack
#  Godot 4.x
#
#  Change ASSETS_PATH to wherever you placed your Kenney assets.
#  Expected files:
#    grey_panel.png        → background panel
#    blue_button00.png     → button normal / hover state
#    blue_button01.png     → button pressed state
#
#  If your files are named differently (e.g. "buttonLong_blue.png"),
#  update the names in _load_kenney_textures() below.
# ─────────────────────────────────────────────────────────────────────────────

const ASSETS_PATH := "res://assets/kenney_ui_pack/"
const GAME_SCENE = preload("res://scenes/water.tscn")
const SETTINGS_SCENE = preload("res://scenes/Settings.tscn")

# 9-slice margins (pixels) — tweak if your buttons look stretched or cut off
const PANEL_MARGIN  := 12
const BUTTON_MARGIN := 5

# Node references
@onready var panel            : PanelContainer = $CenterContainer/PanelContainer
@onready var title_label      : Label  = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label   : Label  = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var play_button      : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton
@onready var achievements_btn : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AchievementsButton
@onready var settings_button  : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton



func _ready() -> void:
	print("MainMenu loaded, size: ", size)  # Should NOT be (0, 0)
	_apply_kenney_theme()
	_connect_signals()


# ── Theme Setup ───────────────────────────────────────────────────────────────

func _apply_kenney_theme() -> void:
	var textures := _load_kenney_textures()
	var theme    := Theme.new()

	# Panel style
	if textures.panel:
		theme.set_stylebox("panel", "PanelContainer",
			_make_ninepatch(textures.panel, PANEL_MARGIN))

	# Button styles
	if textures.btn_normal:
		var normal  := _make_ninepatch(textures.btn_normal, BUTTON_MARGIN)
		var pressed := _make_ninepatch(
			textures.btn_pressed if textures.btn_pressed else textures.btn_normal,
			BUTTON_MARGIN
		)
		# Shrink pressed state slightly to simulate a physical press
		pressed.expand_margin_top    = -2.0
		pressed.expand_margin_bottom = -2.0

		theme.set_stylebox("normal",   "Button", normal)
		theme.set_stylebox("hover",    "Button", normal)
		theme.set_stylebox("pressed",  "Button", pressed)
		theme.set_stylebox("focus",    "Button", normal)
		theme.set_stylebox("disabled", "Button", normal)

	# Colors
	theme.set_color("font_color",          "Button", Color.WHITE)
	theme.set_color("font_hover_color",    "Button", Color(0.9, 0.95, 1.0))
	theme.set_color("font_pressed_color",  "Button", Color(0.75, 0.75, 0.75))
	theme.set_color("font_color",          "Label",  Color(0.2, 0.45, 0.85))
	theme.set_color("font_color",          "Label",  Color(0.2, 0.45, 0.85))

	# Apply theme to the panel container (cascades to children)
	panel.theme = theme

	# Subtitle color override separately (doesn't inherit Label color well)
	subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))


func _load_kenney_textures() -> Dictionary:
	# ── Change filenames here if your pack uses different names ──────────────
	# Common alternatives:
	#   "buttonLong_blue.png" / "buttonLong_blue_pressed.png"
	#   "blue_button00.png"   / "blue_button01.png"
	return {
		"panel"      : _try_load("grey_panel.png"),
		"btn_normal" : _try_load("blue_button00.png"),
		"btn_pressed": _try_load("blue_button01.png"),
	}


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
	push_warning("[MainMenu] Kenney asset not found: %s" % path)
	return null


# ── Button Signals ────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	achievements_btn.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_achievements_pressed() -> void:
	print("[MainMenu] Achievements pressed")
	# get_tree().change_scene_to_file("res://scenes/achievements.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_packed(SETTINGS_SCENE)
