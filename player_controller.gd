extends CharacterBody3D
## Controller for the supplied animated GLB character. Add the imported model
## as a child named CharacterModel; its AnimationPlayer is discovered recursively.

@export var run_speed := 8.0
@export var jump_velocity := 9.0
@export var attack_range := 2.5
var gravity := 24.0
var animation_player: AnimationPlayer
var attack_names := ["MutantPunch", "MmaKick", "PunchCombo", "FlyingKick", "HurricaneKick", "ElbowUppercutCombo", "Armada"]
var attack_index := 0
var attack_locked := false
var auto_run_animation := true

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
		_play_first(["Running", "Run", "mixamo.com", "Idle"])

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
	# The runner stays in the gameplay lane while the level scrolls past.
	velocity.x = 0.0
	move_and_slide()
	if animation_player and not attack_locked and is_on_floor():
		_play_first(["Running", "Run", "mixamo.com", "Idle"])

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
		_play_first(["Jumping(1)", "Jumping", "Jump"])

func attack() -> void:
	if attack_locked or animation_player == null:
		return
	var enemy := _find_nearby_villain()
	var chosen := "Kicking"
	if enemy != null:
		for offset in attack_names.size():
			var candidate: String = attack_names[(attack_index + offset) % attack_names.size()]
			if animation_player.has_animation(candidate):
				chosen = candidate
				attack_index = (attack_index + offset + 1) % attack_names.size()
				break
	attack_locked = true
	if animation_player.has_animation(chosen):
		animation_player.play(chosen)
	else:
		attack_locked = false

func _find_nearby_villain() -> Node3D:
	for enemy in get_tree().get_nodes_in_group("villain"):
		if enemy is Node3D and global_position.distance_to(enemy.global_position) <= attack_range:
			return enemy
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

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

