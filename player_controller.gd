extends CharacterBody3D
## Physics controller for the supplied animated GLB character.
## The player runs along the rooftop route while the camera follows, making
## the city move past him. Touch zones call jump() and attack().

@export var run_speed := 5.5
@export var jump_velocity := 8.0
@export var double_tap_velocity := 10.5
@export var attack_range := 2.5
@export var gravity := 24.0
@export var double_tap_window := 0.32

var animation_player: AnimationPlayer
var attack_names := ["MutantPunch", "MmaKick", "MmaKick(1)", "PunchCombo", "FlyingKick", "HurricaneKick", "ElbowUppercutCombo", "Armada", "Kicking"]
var attack_index := 0
var attack_locked := false
var double_jump_used := false
var last_jump_time := -10.0

func _ready() -> void:
	add_to_group("player")
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null:
		shape = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.42
		capsule.height = 1.9
		shape.shape = capsule
		shape.position.y = 0.95
		add_child(shape)
	animation_player = _find_animation_player(self)
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_run_animation()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		double_jump_used = false

	# Forward motion is real CharacterBody3D motion; the follow camera keeps
	# the player framed while the city and rooftops pass behind him.
	velocity.x = run_speed
	move_and_slide()

	if animation_player and not attack_locked and is_on_floor():
		_play_run_animation()

func jump() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var is_double_tap := now - last_jump_time <= double_tap_window
	if is_on_floor():
		velocity.y = jump_velocity
		double_jump_used = false
		_play_first(["Jumping(1)"])
	elif is_double_tap and not double_jump_used:
		# A bounded mid-air boost makes the second tap higher without sending
		# the character off-screen.
		velocity.y = double_tap_velocity
		double_jump_used = true
		_play_first(["Jumping(1)"])
	last_jump_time = now

func attack() -> void:
	if attack_locked or animation_player == null:
		return
	attack_locked = true
	var chosen := "Kicking"
	for offset in attack_names.size():
		var candidate: String = attack_names[(attack_index + offset) % attack_names.size()]
		if animation_player.has_animation(candidate):
			chosen = candidate
			attack_index = (attack_index + offset + 1) % attack_names.size()
			break
	if animation_player.has_animation(chosen):
		animation_player.play(chosen)
	else:
		attack_locked = false

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _play_run_animation() -> void:
	_play_first(["mixamo_com", "Running", "Run", "Idle"])

func _play_first(names: Array) -> void:
	if animation_player == null or attack_locked:
		return
	for animation_name in names:
		if animation_player.has_animation(animation_name):
			if animation_player.current_animation != animation_name:
				animation_player.play(animation_name)
			return

func _on_animation_finished(_animation_name: StringName) -> void:
	attack_locked = false
