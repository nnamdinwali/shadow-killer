extends CharacterBody3D

# --- SETTINGS ---
@export var run_speed: float = 2.5 # Reduced speed for a "slow, normal" feel
@export var gravity: float = 9.8
@export var lane_width: float = 3.0 # Width for switching lanes later
@export var animation_name: String = "mixamo_com"

@onready var animation_player = $Running/AnimationPlayer

func _ready():
	# Start the animation immediately
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# 2. Automatic Forward Movement
	# If your character is facing the X-axis (right), use velocity.x
	# If your character is facing the Z-axis (forward), use velocity.z
	# Based on your video, he is running to the right (X-axis)
	velocity.x = run_speed
	
	# 3. Apply Movement

	# 4. Keep him "On his line"
	# This ensures he doesn't drift away from the center of the track (Z = 0)
	global_position.z = lerp(global_position.z, 0.0, 5.0 * delta)
