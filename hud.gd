extends CanvasLayer

## Minimal code-driven HUD for the rooftop runner.
## Uses only native Godot Controls and text; no generated images, icons, hearts,
## health bars, progress bars, or external UI assets are loaded.

@export var max_health: float = 100.0
@export var starting_coins: int = 16
@export var distance_goal: float = 1000.0

var health: float
var coins: int
var distance_m: float = 0.0
var is_paused := false
var health_value: Label
var coin_value: Label
var distance_value: Label
var health_bar: ProgressBar
var distance_bar: ProgressBar
var pause_button: Button
var player: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	health = max_health
	coins = starting_coins
	player = get_tree().get_first_node_in_group("player")
	get_tree().node_added.connect(_on_node_added)
	_build_hud()
	_refresh_hud()

func _process(delta: float) -> void:
	if not is_paused:
		distance_m = min(distance_goal, distance_m + delta * 3.0)
		_refresh_hud()

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	return style

func _build_hud() -> void:
	# All visible status information is created as native Godot Labels.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var pixel_theme := load("res://addons/pixel_ui/themes/wood.tres") as Theme
	if pixel_theme:
		root.theme = pixel_theme
	add_child(root)

	var status := Control.new()
	status.position = Vector2(24, 22)
	status.size = Vector2(320, 70)
	root.add_child(status)

	health_value = _label("HP 100", 19, Color(0.9, 0.95, 1.0))
	health_value.position = Vector2(0, 0)
	health_value.size = Vector2(100, 36)
	status.add_child(health_value)
	health_bar = ProgressBar.new()
	health_bar.theme = pixel_theme
	health_bar.theme_type_variation = "RedBar"
	health_bar.show_percentage = false
	health_bar.position = Vector2(0, 28)
	health_bar.size = Vector2(160, 16)
	status.add_child(health_bar)

	coin_value = _label("● 16", 19, Color(1.0, 0.8, 0.25))
	coin_value.position = Vector2(105, 0)
	coin_value.size = Vector2(100, 36)
	status.add_child(coin_value)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://addons/pixel_ui/icons/coin.png")
	coin_icon.position = Vector2(90, 8)
	coin_icon.size = Vector2(16, 16)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status.add_child(coin_icon)

	distance_value = _label("0 m", 19, Color(1.0, 0.88, 0.5))
	distance_value.anchor_left = 0.5
	distance_value.anchor_right = 0.5
	distance_value.offset_left = -45
	distance_value.offset_right = 45
	distance_value.position.y = 24
	distance_value.size.y = 34
	distance_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(distance_value)

	distance_bar = ProgressBar.new()
	distance_bar.theme = pixel_theme
	distance_bar.theme_type_variation = "GoldBar"
	distance_bar.show_percentage = false
	distance_bar.anchor_left = 0.5
	distance_bar.anchor_right = 0.5
	distance_bar.offset_left = -150
	distance_bar.offset_right = 150
	distance_bar.position.y = 52
	distance_bar.size.y = 16
	root.add_child(distance_bar)

	pause_button = Button.new()
	pause_button.text = ""
	pause_button.icon = load("res://addons/pixel_ui/icons/pause.png")
	pause_button.expand_icon = true
	pause_button.tooltip_text = "Pause game"
	pause_button.position = Vector2(-120, 16)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.size = Vector2(96, 72)
	pause_button.theme = pixel_theme
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.z_index = 20
	pause_button.pressed.connect(_toggle_pause)
	root.add_child(pause_button)

	# Invisible native input zones: left half jumps, right half attacks.
	var jump_zone := Button.new()
	jump_zone.name = "JumpTouchZone"
	jump_zone.anchor_right = 0.5
	jump_zone.anchor_bottom = 1.0
	jump_zone.offset_top = 180.0
	jump_zone.offset_bottom = -12.0
	jump_zone.focus_mode = Control.FOCUS_NONE
	jump_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jump_zone.add_theme_stylebox_override("normal", _transparent_style())
	jump_zone.add_theme_stylebox_override("pressed", _transparent_style())
	root.add_child(jump_zone)

	var attack_zone := Button.new()
	attack_zone.name = "AttackTouchZone"
	attack_zone.anchor_left = 0.5
	attack_zone.anchor_right = 1.0
	attack_zone.anchor_bottom = 1.0
	attack_zone.offset_top = 180.0
	attack_zone.offset_bottom = -12.0
	attack_zone.focus_mode = Control.FOCUS_NONE
	attack_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_zone.add_theme_stylebox_override("normal", _transparent_style())
	attack_zone.add_theme_stylebox_override("pressed", _transparent_style())
	root.add_child(attack_zone)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_W, KEY_UP]:
			_on_jump_pressed()
		elif event.keycode in [KEY_J, KEY_X, KEY_ENTER]:
			_on_attack_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_action_position(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_action_position(event.position)

func _handle_action_position(screen_position: Vector2) -> void:
	if screen_position.y < 180.0:
		return
	if screen_position.x < get_viewport().get_visible_rect().size.x * 0.5:
		_on_jump_pressed()
	else:
		_on_attack_pressed()

func _refresh_hud() -> void:
	if health_value:
		health_value.text = "HP %d" % roundi(health)
		health_bar.max_value = max_health
		health_bar.value = health
		coin_value.text = "● %d" % coins
		distance_bar.max_value = distance_goal
		distance_bar.value = distance_m
		distance_value.text = "%d m" % roundi(distance_m)

func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_button.text = "▶" if is_paused else "Ⅱ"

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		player = node

func _on_jump_pressed() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("jump"):
		player.jump()

func _on_attack_pressed() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("attack"):
		player.attack()
