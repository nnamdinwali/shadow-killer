extends CanvasLayer
## Minimal touch HUD for the side-scrolling rooftop game.

var paused := false
var coins := 16
var lives := 3
var coin_label: Label
var life_label: Label
var pause_button: Button
var player: Node

func _ready() -> void:
	layer = 10
	player = get_tree().get_first_node_in_group("player")
	_build_hud()
	get_tree().node_added.connect(_on_node_added)

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 20)
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)
	life_label = Label.new()
	life_label.text = "♥ ♥ ♥"
	life_label.add_theme_font_size_override("font_size", 30)
	life_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.28))
	top.add_child(life_label)
	coin_label = Label.new()
	coin_label.text = "🟡 %d" % coins
	coin_label.add_theme_font_size_override("font_size", 28)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	top.add_child(coin_label)
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.custom_minimum_size = Vector2(76, 64)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-100, 18)
	pause_button.add_theme_font_size_override("font_size", 30)
	pause_button.pressed.connect(_toggle_pause)
	root.add_child(pause_button)
	var jump_button := Button.new()
	jump_button.text = "JUMP"
	jump_button.custom_minimum_size = Vector2(130, 88)
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	jump_button.position = Vector2(28, -112)
	jump_button.add_theme_font_size_override("font_size", 24)
	jump_button.pressed.connect(_jump)
	root.add_child(jump_button)
	var attack_button := Button.new()
	attack_button.text = "ATTACK"
	attack_button.custom_minimum_size = Vector2(150, 88)
	attack_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.position = Vector2(-178, -112)
	attack_button.add_theme_font_size_override("font_size", 24)
	attack_button.pressed.connect(_attack)
	root.add_child(attack_button)
	var move_left := Button.new()
	move_left.text = "◀"
	move_left.custom_minimum_size = Vector2(72, 64)
	move_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	move_left.position = Vector2(170, -102)
	move_left.button_down.connect(func(): Input.action_press("move_left"))
	move_left.button_up.connect(func(): Input.action_release("move_left"))
	root.add_child(move_left)
	var move_right := Button.new()
	move_right.text = "▶"
	move_right.custom_minimum_size = Vector2(72, 64)
	move_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	move_right.position = Vector2(248, -102)
	move_right.button_down.connect(func(): Input.action_press("move_right"))
	move_right.button_up.connect(func(): Input.action_release("move_right"))
	root.add_child(move_right)

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		player = node

func _jump() -> void:
	if is_instance_valid(player) and player.has_method("jump"):
		player.jump()

func _attack() -> void:
	if is_instance_valid(player) and player.has_method("attack"):
		player.attack()

func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	pause_button.text = "▶" if paused else "Ⅱ"

func set_coins(value: int) -> void:
	coins = maxi(0, value)
	if is_instance_valid(coin_label):
		coin_label.text = "🟡 %d" % coins

func set_lives(value: int) -> void:
	lives = clampi(value, 0, 3)
	if is_instance_valid(life_label):
		life_label.text = "♥ ".repeat(lives).strip_edges()
