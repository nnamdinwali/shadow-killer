extends CanvasLayer

## Native Godot HUD for the rooftop runner.
## The interface is built from Godot Controls at runtime; no generated images are used.

@export var max_health: float = 100.0
@export var starting_coins: int = 16
@export var distance_goal: float = 1000.0

var health: float
var coins: int
var distance_m: float = 0.0
var is_paused := false

var health_bar: ProgressBar
var health_value: Label
var coin_value: Label
var distance_bar: ProgressBar
var distance_value: Label
var pause_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	health = max_health
	coins = starting_coins
	_build_hud()
	_refresh_hud()

func _process(delta: float) -> void:
	if not is_paused:
		distance_m = min(distance_goal, distance_m + delta * 3.0)
		_refresh_hud()

func _panel_style(color: Color, radius: int = 12, border_color := Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Top-left hero status, matching the reference layout.
	var status_panel := Panel.new()
	status_panel.position = Vector2(24, 22)
	status_panel.size = Vector2(420, 166)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.06, 0.11, 0.93), 18, Color(0.35, 0.78, 1.0, 0.7), 2))
	root.add_child(status_panel)

	var hero_label := _label("HERO STATUS", 17, Color(0.68, 0.9, 1.0))
	hero_label.position = Vector2(22, 12)
	status_panel.add_child(hero_label)

	var health_caption := _label("HEALTH", 14, Color(0.65, 0.74, 0.82))
	health_caption.position = Vector2(22, 43)
	status_panel.add_child(health_caption)

	var hearts := _label("♥ ♥ ♥", 28, Color(1.0, 0.22, 0.25))
	hearts.position = Vector2(18, 66)
	status_panel.add_child(hearts)

	health_bar = ProgressBar.new()
	health_bar.position = Vector2(132, 70)
	health_bar.size = Vector2(264, 32)
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.12, 0.16, 0.21, 1.0), 10, Color(0.38, 0.48, 0.58, 0.7), 1))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.9, 0.16, 0.2, 1.0), 10))
	status_panel.add_child(health_bar)

	health_value = _label("100 / 100", 17, Color.WHITE)
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_value.position = Vector2(132, 73)
	health_value.size = Vector2(264, 26)
	status_panel.add_child(health_value)

	# Large readable coin counter with a native Godot-drawn coin badge.
	var coin_badge := Panel.new()
	coin_badge.position = Vector2(18, 120)
	coin_badge.size = Vector2(218, 36)
	coin_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.18, 0.95), 10, Color(1.0, 0.74, 0.18, 0.75), 2))
	status_panel.add_child(coin_badge)

	var coin_icon := _label("●", 27, Color(1.0, 0.72, 0.08))
	coin_icon.add_theme_color_override("font_shadow_color", Color(0.35, 0.18, 0.02, 0.9))
	coin_icon.add_theme_constant_override("shadow_offset_x", 2)
	coin_icon.add_theme_constant_override("shadow_offset_y", 2)
	coin_icon.position = Vector2(12, 0)
	coin_icon.size = Vector2(34, 34)
	coin_badge.add_child(coin_icon)

	var coin_caption := _label("COINS", 13, Color(1.0, 0.86, 0.42))
	coin_caption.position = Vector2(52, 3)
	coin_badge.add_child(coin_caption)
	coin_value = _label("16", 23, Color.WHITE)
	coin_value.position = Vector2(52, 13)
	coin_badge.add_child(coin_value)

	# Top-center distance meter.
	var distance_panel := Panel.new()
	distance_panel.anchor_left = 0.5
	distance_panel.anchor_right = 0.5
	distance_panel.offset_left = -235
	distance_panel.offset_right = 235
	distance_panel.position.y = 22
	distance_panel.size.y = 88
	distance_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.06, 0.11, 0.93), 18, Color(1.0, 0.74, 0.2, 0.65), 2))
	root.add_child(distance_panel)

	var distance_title := _label("CITY RUN   •   DISTANCE", 16, Color(1.0, 0.87, 0.5))
	distance_title.position = Vector2(20, 10)
	distance_panel.add_child(distance_title)

	distance_bar = ProgressBar.new()
	distance_bar.position = Vector2(20, 46)
	distance_bar.size = Vector2(352, 20)
	distance_bar.show_percentage = false
	distance_bar.add_theme_stylebox_override("background", _panel_style(Color(0.1, 0.14, 0.19, 1.0), 8))
	distance_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.98, 0.58, 0.08, 1.0), 8))
	distance_panel.add_child(distance_bar)

	distance_value = _label("0 m", 16, Color.WHITE)
	distance_value.position = Vector2(385, 42)
	distance_panel.add_child(distance_value)

	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause game"
	pause_button.position = Vector2(-110, 24)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.size = Vector2(82, 60)
	pause_button.add_theme_font_size_override("font_size", 27)
	pause_button.add_theme_color_override("font_color", Color.WHITE)
	pause_button.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.06, 0.11, 0.94), 15, Color(0.45, 0.84, 1.0, 0.8), 2))
	pause_button.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.3, 0.42, 0.98), 15, Color(0.85, 0.96, 1.0, 0.95), 2))
	pause_button.pressed.connect(_toggle_pause)
	root.add_child(pause_button)

func _refresh_hud() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_value.text = "%d / %d" % [roundi(health), roundi(max_health)]
		coin_value.text = "%d" % coins
		distance_bar.max_value = distance_goal
		distance_bar.value = distance_m
		distance_value.text = "%d m" % roundi(distance_m)

func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_button.text = "▶" if is_paused else "Ⅱ"
	pause_button.tooltip_text = "Resume game" if is_paused else "Pause game"
