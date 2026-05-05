extends Control

const SAVE_PATH := "user://settings.cfg"

@onready var master_slider     : HSlider     = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MasterSlider
@onready var fullscreen_toggle : CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenToggle
@onready var hud_toggle        : CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HUDToggle
@onready var back_button       : Button      = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

var config := ConfigFile.new()


func _ready() -> void:
	$CenterContainer/PanelContainer.theme = UITheme.kenney_theme
	_load_settings()
	_connect_signals()


func _load_settings() -> void:
	config.load(SAVE_PATH)
	master_slider.value              = config.get_value("audio",    "master_volume", 100.0)
	fullscreen_toggle.button_pressed = config.get_value("display",  "fullscreen",    false)
	hud_toggle.button_pressed        = config.get_value("gameplay", "show_hud",      true)
	_apply_master_volume(master_slider.value)
	_apply_fullscreen(fullscreen_toggle.button_pressed)


func _save_settings() -> void:
	config.set_value("audio",    "master_volume", master_slider.value)
	config.set_value("display",  "fullscreen",    fullscreen_toggle.button_pressed)
	config.set_value("gameplay", "show_hud",      hud_toggle.button_pressed)
	config.save(SAVE_PATH)


func _apply_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))


func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	hud_toggle.toggled.connect(_on_hud_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _on_master_changed(value: float) -> void:
	_apply_master_volume(value)
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_save_settings()


func _on_hud_toggled(_enabled: bool) -> void:
	_save_settings()


func _on_back_pressed() -> void:
	_save_settings()
	get_tree().change_scene_to_file("res://main_menu.tscn")
